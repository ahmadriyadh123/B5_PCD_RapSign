from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.model_selection import train_test_split

from .constants import SUPPORTED_EXTENSIONS, DEFAULT_OUTPUT_SIZE
from .models import SignatureFeatures, SignatureSample, VerificationResult
from .extractor import SignatureFeatureExtractor
from .cnn_model import SignatureCNN


class SignatureVerificationPipeline:
    def __init__(self, output_size: int = DEFAULT_OUTPUT_SIZE, embedding_dim: int = 128) -> None:
        self.extractor = SignatureFeatureExtractor(output_size=output_size)
        self.model: Optional[SignatureCNN] = None
        self.class_prototypes: Dict[str, np.ndarray] = {}
        self.label_to_idx: Dict[str, int] = {}
        self.idx_to_label: Dict[int, str] = {}
        self.embedding_dim = embedding_dim
        self.device = torch.device("cpu") # Use CPU for simplicity in student project

    def discover_raw_samples(self, dataset_dir: Path) -> List[SignatureSample]:
        print(f"[LOG] Memindai folder dataset: {dataset_dir} ...")
        samples: List[SignatureSample] = []
        for class_dir in sorted(dataset_dir.iterdir()):
            if not class_dir.is_dir():
                continue
            label = class_dir.name
            for image_path in sorted(class_dir.iterdir()):
                if image_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
                    continue
                samples.append(SignatureSample(image_path=image_path, label=label))
        if not samples:
            raise ValueError(f"No samples found in {dataset_dir}")
        print(f"[LOG] Berhasil menemukan {len(samples)} gambar dari {len(set(s.label for s in samples))} kelas/identitas.")
        return samples

    def build_raw_feature_table(self, dataset_dir: Path) -> List[SignatureFeatures]:
        print("[LOG] Memulai ekstraksi matriks gambar (on-the-fly preprocessing)...")
        samples = self.discover_raw_samples(dataset_dir)
        features: List[SignatureFeatures] = []
        for sample in samples:
            features.append(self.extractor.process_raw_image(sample.image_path, sample.label))
        return features

    def train(self, dataset_dir: Path, epochs: int = 10, batch_size: int = 8) -> Dict[str, float]:
        feature_rows = self.build_raw_feature_table(dataset_dir)
        
        # Prepare labels
        unique_labels = sorted(list(set(row.label for row in feature_rows)))
        self.label_to_idx = {label: idx for idx, label in enumerate(unique_labels)}
        self.idx_to_label = {idx: label for label, idx in self.label_to_idx.items()}
        num_classes = len(unique_labels)
        
        # Initialize model
        print("[LOG] Menginisialisasi arsitektur SignatureCNN (PyTorch)...")
        self.model = SignatureCNN(embedding_dim=self.embedding_dim).to(self.device)
        
        # To train the CNN, we attach a temporary classification head
        classifier = nn.Linear(self.embedding_dim, num_classes).to(self.device)
        
        criterion = nn.CrossEntropyLoss()
        optimizer = optim.Adam(list(self.model.parameters()) + list(classifier.parameters()), lr=0.001)
        
        # Prepare data tensors
        x = torch.stack([row.image_tensor for row in feature_rows])
        y = torch.tensor([self.label_to_idx[row.label] for row in feature_rows], dtype=torch.long)
        
        dataset = torch.utils.data.TensorDataset(x, y)
        dataloader = torch.utils.data.DataLoader(dataset, batch_size=batch_size, shuffle=True)
        
        self.model.train()
        classifier.train()
        
        print(f"[LOG] Memulai proses training selama {epochs} epoch dengan arsitektur CNN...")
        print(f"[LOG] Konfigurasi: Batch Size = {batch_size}, Optimizer = Adam, Learning Rate = 0.001")
        total_batches = len(dataloader)
        
        for epoch in range(epochs):
            total_loss = 0.0
            for batch_idx, (batch_x, batch_y) in enumerate(dataloader):
                batch_x, batch_y = batch_x.to(self.device), batch_y.to(self.device)
                
                optimizer.zero_grad()
                embeddings = self.model(batch_x)
                outputs = classifier(embeddings)
                
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                
                total_loss += loss.item()
                
                # Log setiap 50 batch atau di akhir epoch
                if (batch_idx + 1) % 50 == 0 or (batch_idx + 1) == total_batches:
                    print(f"      [Iterasi ML] Epoch {epoch+1:02d}/{epochs} | Batch {batch_idx+1:03d}/{total_batches:03d}")
                    print(f"                   -> Forward Pass (Ekstraksi) -> Hitung Error (Cross-Entropy) -> Backprop (Adam)")
                    print(f"                   -> Batch Loss: {loss.item():.4f}")
                
            avg_loss = total_loss / total_batches
            print(f"      >>> [Ringkasan Epoch {epoch+1}] Rata-rata Loss: {avg_loss:.4f} <<<\n")
                
        self.model.eval()
        
        # Build class prototypes using the trained embeddings
        print("[LOG] Menyusun purwarupa kelas (class prototypes) dari embeddings...")
        self.class_prototypes = self._build_class_prototypes(feature_rows)
        
        print("[LOG] Proses training selesai!")
        
        return {
            "num_samples": float(len(feature_rows)),
            "num_classes": float(num_classes),
            "final_loss": total_loss / len(dataloader)
        }

    def _build_class_prototypes(self, feature_rows: Sequence[SignatureFeatures]) -> Dict[str, np.ndarray]:
        grouped: Dict[str, List[torch.Tensor]] = {}
        for row in feature_rows:
            grouped.setdefault(row.label, []).append(row.image_tensor)
        
        prototypes = {}
        with torch.no_grad():
            for label, tensors in grouped.items():
                batch = torch.stack(tensors).to(self.device)
                embeddings = self.model(batch) # shape: (N, embedding_dim)
                mean_embedding = embeddings.mean(dim=0).cpu().numpy()
                prototypes[label] = mean_embedding
                
        return prototypes

    def save(self, path: Path) -> None:
        if self.model is None:
            raise ValueError("Model is not trained yet.")
        payload = {
            "model_state_dict": self.model.state_dict(),
            "class_prototypes": self.class_prototypes,
            "output_size": self.extractor.output_size,
            "embedding_dim": self.embedding_dim,
            "label_to_idx": self.label_to_idx,
            "idx_to_label": self.idx_to_label
        }
        torch.save(payload, path)

    @classmethod
    def load(cls, path: Path) -> "SignatureVerificationPipeline":
        payload = torch.load(path, map_location="cpu", weights_only=False)
        
        pipeline = cls(
            output_size=int(payload.get("output_size", DEFAULT_OUTPUT_SIZE)),
            embedding_dim=int(payload.get("embedding_dim", 128))
        )
        pipeline.model = SignatureCNN(embedding_dim=pipeline.embedding_dim)
        pipeline.model.load_state_dict(payload["model_state_dict"])
        pipeline.model.eval()
        pipeline.model.to(pipeline.device)
        
        pipeline.class_prototypes = payload.get("class_prototypes", {})
        pipeline.label_to_idx = payload.get("label_to_idx", {})
        pipeline.idx_to_label = payload.get("idx_to_label", {})
        
        return pipeline

    def infer(self, contour_image_path: Path, feature_ready_image_path: Path, enrolled_label: Optional[str] = None, threshold: float = 0.75) -> VerificationResult:
        if self.model is None:
            raise ValueError("Model is not trained or loaded.")

        print(f"[LOG] Mengekstrak matriks piksel dari gambar: {contour_image_path.name}")
        sample = self.extractor.process_artifacts(contour_image_path, feature_ready_image_path, label=enrolled_label or "unknown")
        
        # Extract embedding for the query image
        print("[LOG] Menjalankan forward-pass CNN untuk menghasilkan vektor fitur (embeddings)...")
        self.model.eval()
        with torch.no_grad():
            input_tensor = sample.image_tensor.unsqueeze(0).to(self.device) # Add batch dimension
            query_embedding = self.model(input_tensor).cpu().numpy()[0]
            
        # If we need to predict the label (e.g. no enrolled_label provided), find the closest prototype
        predicted_label = "unknown"
        max_sim = -1.0
        
        if not self.class_prototypes:
            return VerificationResult(
                label=enrolled_label,
                predicted_label="unknown",
                similarity_score=0.0,
                verification_result="invalid",
                detection_coordinate=sample.bbox,
            )
            
        # Calculate similarities against all prototypes
        print(f"[LOG] Menghitung jarak kemiripan (Cosine Similarity) vektor (dimensi: {query_embedding.shape[0]}) terhadap {len(self.class_prototypes)} purwarupa kelas di memori...")
        prototype_labels = list(self.class_prototypes.keys())
        prototype_matrix = np.stack([self.class_prototypes[l] for l in prototype_labels])
        scores = cosine_similarity(query_embedding.reshape(1, -1), prototype_matrix)[0]
        
        # Get top 3 predictions for logging
        top_indices = np.argsort(scores)[::-1][:3]
        
        print("      [Detail Peringkat Prediksi CNN]:")
        for i, idx in enumerate(top_indices):
            print(f"        {i+1}. Kelas '{prototype_labels[idx]}' -> Skor Kemiripan: {scores[idx]:.4f}")
            
        best_idx = top_indices[0]
        predicted_label = prototype_labels[best_idx]
        predicted_score = scores[best_idx]

        similarity_score = self._similarity_to_enrolled(query_embedding, enrolled_label)
        if enrolled_label is None:
            enrolled_label = predicted_label
            similarity_score = predicted_score

        print(f"\n      - Label Identitas Target (Klaim) : {enrolled_label}")
        print(f"      - Prediksi Terdekat oleh CNN     : {predicted_label}")
        print(f"      - Nilai Cosine Similarity        : {similarity_score:.4f} (Ambang Batas/Threshold: {threshold})")

        print(f"[LOG] Mengevaluasi keputusan akhir (Verifikasi)...")
        verification_result = "valid" if similarity_score >= threshold and predicted_label == enrolled_label else "invalid"
        if verification_result == "valid":
            print("      -> HASIL: TANDA TANGAN VALID (ASLI) ✓")
        else:
            print("      -> HASIL: TANDA TANGAN INVALID (PALSU/TIDAK COCOK) ✗")

        return VerificationResult(
            label=enrolled_label,
            predicted_label=predicted_label,
            similarity_score=round(float(similarity_score), 4),
            verification_result=verification_result,
            detection_coordinate=sample.bbox,
        )

    def infer_payload(self, contour_image_path: Path, feature_ready_image_path: Path, enrolled_label: Optional[str] = None, threshold: float = 0.75):
        result = self.infer(contour_image_path=contour_image_path, feature_ready_image_path=feature_ready_image_path, enrolled_label=enrolled_label, threshold=threshold)
        return result.to_dict()

    def _similarity_to_enrolled(self, feature_vector: np.ndarray, enrolled_label: Optional[str]) -> float:
        if enrolled_label is None or enrolled_label not in self.class_prototypes:
            if not self.class_prototypes:
                return 0.0
            prototype_matrix = np.stack(list(self.class_prototypes.values()))
            scores = cosine_similarity(feature_vector.reshape(1, -1), prototype_matrix)[0]
            return float(np.max(scores))

        prototype = self.class_prototypes[enrolled_label].reshape(1, -1)
        score = cosine_similarity(feature_vector.reshape(1, -1), prototype)[0][0]
        return float(score)
