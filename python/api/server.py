"""
FastAPI Server — Signature Verification
Endpoint:
  GET  /health          → cek status server & model
  POST /verify          → verifikasi tanda tangan dari gambar
  POST /enroll/preview  → preview kontur gambar tanpa verifikasi (untuk debugging)
"""

from __future__ import annotations

import io
import sys
import base64
import traceback
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Tambahkan root project ke sys.path agar bisa import feature_verification
ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from python.feature_verification.pipeline import SignatureVerificationPipeline
from python.feature_verification.constants import DEFAULT_MODEL_PATH, DEFAULT_THRESHOLD

# ─── App Setup ───────────────────────────────────────────────
app = FastAPI(
    title="Signature Verification API",
    description="API untuk verifikasi tanda tangan menggunakan CNN + Cosine Similarity",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Model Loading ────────────────────────────────────────────
_pipeline: Optional[SignatureVerificationPipeline] = None
MODEL_PATH = ROOT / DEFAULT_MODEL_PATH


def get_pipeline() -> SignatureVerificationPipeline:
    global _pipeline
    if _pipeline is None:
        if not MODEL_PATH.exists():
            raise HTTPException(
                status_code=503,
                detail=f"Model belum tersedia di {MODEL_PATH}. Jalankan training terlebih dahulu.",
            )
        print(f"[SERVER] Memuat model dari {MODEL_PATH}...")
        _pipeline = SignatureVerificationPipeline.load(MODEL_PATH)
        print(f"[SERVER] Model berhasil dimuat. Kelas terdaftar: {list(_pipeline.class_prototypes.keys())}")
    return _pipeline


# ─── Preprocessing (OpenCV) ───────────────────────────────────
def preprocess_to_contour(image_bytes: bytes) -> tuple[np.ndarray, np.ndarray, bytes]:
    """
    Pipeline preprocessing lengkap sesuai tugas Anggota 2:
    1. Grayscale conversion
    2. Noise reduction (Gaussian blur)
    3. Thresholding (Otsu)
    4. Edge detection (Canny)
    5. Morphological operation (dilation + closing)
    6. Contour extraction untuk bounding box
    
    Returns:
        closed (np.ndarray): gambar hasil morfologi penutup (Canny + Dilation + Closing)
        thresh (np.ndarray): gambar hasil binarisasi Otsu solid
        contour_bytes (bytes): PNG bytes untuk dikirim balik ke Flutter
    """
    # Decode gambar dari bytes
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Gambar tidak dapat dibaca. Pastikan format valid (JPEG/PNG).")

    # 1. Grayscale Conversion
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 2. Noise Reduction — Gaussian blur untuk menghilangkan noise kamera & tekstur kertas
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # 3. Thresholding — Otsu's binarization (adaptif, tidak perlu set manual)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 4. Edge Detection — Canny
    edges = cv2.Canny(thresh, threshold1=30, threshold2=100)

    # 5. Morphological Operation — dilation untuk memperkuat garis kontur
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    dilated = cv2.dilate(edges, kernel, iterations=2)

    # Closing untuk menghubungkan garis yang terputus
    closed = cv2.morphologyEx(dilated, cv2.MORPH_CLOSE, kernel, iterations=2)

    # 6. Contour Extraction — untuk mendapatkan area tanda tangan
    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Buat gambar output: overlay kontur di atas grayscale asli (lebih informatif untuk display)
    display = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    if contours:
        # Gambar semua kontur dengan warna hijau
        cv2.drawContours(display, contours, -1, (0, 200, 80), 1)

        # Gambar bounding box dari kontur terbesar
        largest = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(largest)
        cv2.rectangle(display, (x, y), (x + w, y + h), (0, 140, 255), 2)

    # Encode ke PNG bytes
    _, buffer = cv2.imencode(".png", display)
    contour_bytes = buffer.tobytes()

    return closed, thresh, contour_bytes


def prepare_feature_ready(contour_image: np.ndarray, output_size: int = 128) -> np.ndarray:
    """
    Mengubah contour image menjadi feature-ready image:
    - Resize ke output_size x output_size
    - Normalize ke [0, 1]
    """
    resized = cv2.resize(contour_image, (output_size, output_size), interpolation=cv2.INTER_AREA)
    normalized = resized.astype(np.float32) / 255.0
    return normalized


# ─── Endpoints ───────────────────────────────────────────────

@app.get("/health")
def health_check():
    """Cek status server dan apakah model sudah dimuat."""
    model_ready = MODEL_PATH.exists()
    enrolled_labels = []

    if model_ready:
        try:
            pipeline = get_pipeline()
            enrolled_labels = list(pipeline.class_prototypes.keys())
        except Exception:
            model_ready = False

    return {
        "status": "ok",
        "model_ready": model_ready,
        "model_path": str(MODEL_PATH),
        "enrolled_labels": enrolled_labels,
        "enrolled_count": len(enrolled_labels),
    }


@app.post("/verify")
async def verify_signature(
    image: UploadFile = File(..., description="Foto dokumen atau tanda tangan (JPEG/PNG)"),
    enrolled_label: Optional[str] = Form(None, description="Label pemilik ttd yang diklaim (opsional)"),
    threshold: float = Form(DEFAULT_THRESHOLD, description="Threshold kemiripan (default 0.75)"),
):
    """
    Verifikasi tanda tangan dari gambar.
    
    - Terima gambar mentah dari Flutter
    - Preprocessing: grayscale → noise reduction → threshold → edge → morphology → contour
    - Jalankan CNN untuk mengekstrak embedding
    - Hitung cosine similarity terhadap prototype
    - Return: hasil verifikasi + contour image (base64) + similarity score
    """
    try:
        # Baca bytes gambar dari upload
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="File gambar kosong.")

        print(f"[SERVER] Menerima gambar: {image.filename}, ukuran: {len(image_bytes)} bytes")
        print(f"[SERVER] enrolled_label={enrolled_label}, threshold={threshold}")

        # Preprocessing (tugas Anggota 2)
        print("[SERVER] Memulai preprocessing kontur...")
        closed_image, thresh_image, contour_bytes = preprocess_to_contour(image_bytes)
        feature_ready = prepare_feature_ready(thresh_image)
        print("[SERVER] Preprocessing selesai.")

        # Simpan ke temp file sementara agar bisa dibaca pipeline
        # (pipeline.extractor.process_artifacts masih pakai Path)
        import tempfile, os
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_contour:
            tmp_contour.write(contour_bytes)
            tmp_contour_path = Path(tmp_contour.name)

        # Feature-ready image: simpan sebagai grayscale PNG
        feature_ready_uint8 = (feature_ready * 255).astype(np.uint8)
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_feature:
            cv2.imwrite(tmp_feature.name, feature_ready_uint8)
            tmp_feature_path = Path(tmp_feature.name)

        try:
            # Jalankan pipeline inference
            pipeline = get_pipeline()
            result = pipeline.infer(
                contour_image_path=tmp_contour_path,
                feature_ready_image_path=tmp_feature_path,
                enrolled_label=enrolled_label,
                threshold=threshold,
            )
        finally:
            # Hapus temp file
            os.unlink(tmp_contour_path)
            os.unlink(tmp_feature_path)

        # Encode contour image ke base64 untuk dikirim ke Flutter
        contour_b64 = base64.b64encode(contour_bytes).decode("utf-8")

        print(f"[SERVER] Hasil verifikasi: {result.verification_result} (score: {result.similarity_score})")

        return JSONResponse({
            "success": True,
            "verification_result": result.verification_result,   # "valid" | "invalid"
            "similarity_score": result.similarity_score,          # float 0.0 - 1.0
            "predicted_label": result.predicted_label,            # label prediksi CNN
            "enrolled_label": result.label,                       # label yang diklaim
            "detection_coordinate": list(result.detection_coordinate),  # [x, y, w, h]
            "contour_image_base64": contour_b64,                  # PNG untuk ditampilkan di Flutter
            "threshold_used": threshold,
        })

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@app.post("/enroll/preview")
async def preview_contour(
    image: UploadFile = File(..., description="Gambar tanda tangan untuk preview kontur"),
):
    """
    Preview hasil preprocessing kontur tanpa verifikasi.
    Berguna untuk debugging dan memastikan kualitas gambar input.
    """
    try:
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="File gambar kosong.")

        _, _, contour_bytes = preprocess_to_contour(image_bytes)
        contour_b64 = base64.b64encode(contour_bytes).decode("utf-8")

        return JSONResponse({
            "success": True,
            "contour_image_base64": contour_b64,
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── Run ──────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 50)
    print("  Signature Verification API Server")
    print(f"  Model path : {MODEL_PATH}")
    print(f"  Docs       : http://localhost:8000/docs")
    print("=" * 50)
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)