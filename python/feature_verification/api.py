from pathlib import Path
import tempfile
import uvicorn
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse

# Add repository root to path if needed
import sys
from pathlib import Path as _P
sys.path.insert(0, str(_P(__file__).resolve().parents[2]))

from python.feature_verification.pipeline import SignatureVerificationPipeline

MODEL_PATH = Path(__file__).resolve().parents[1] / 'model.joblib'

app = FastAPI(title="Signature Verification API")

@app.on_event("startup")
def load_model():
    global pipeline
    print(f"[API] Loading model from {MODEL_PATH}")
    pipeline = SignatureVerificationPipeline.load(MODEL_PATH)
    print("[API] Model loaded")

@app.post("/infer")
async def infer(contour: UploadFile = File(...), feature_ready: UploadFile = File(...), enrolled_label: str | None = Form(None), threshold: float = Form(0.75)):
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(contour.filename).suffix) as f1:
            f1.write(await contour.read())
            p1 = Path(f1.name)
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(feature_ready.filename).suffix) as f2:
            f2.write(await feature_ready.read())
            p2 = Path(f2.name)

        result = pipeline.infer_payload(p1, p2, enrolled_label=enrolled_label, threshold=threshold)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8000)
