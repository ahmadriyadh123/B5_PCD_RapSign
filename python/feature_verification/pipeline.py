from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from .constants import SUPPORTED_EXTENSIONS, DEFAULT_OUTPUT_SIZE
from .models import SignatureFeatures, SignatureSample, VerificationResult
from .extractor import SignatureFeatureExtractor


class SignatureVerificationPipeline:
    def __init__(self, output_size: int = DEFAULT_OUTPUT_SIZE) -> None:
        self.extractor = SignatureFeatureExtractor(output_size=output_size)
        self.model: Optional[Pipeline] = None
        self.class_prototypes: Dict[str, np.ndarray] = {}

    def discover_sample_pairs(self, contour_dir: Path, feature_ready_dir: Path) -> List[Tuple[SignatureSample, Path]]:
        samples: List[Tuple[SignatureSample, Path]] = []
        for contour_class_dir in sorted(contour_dir.iterdir()):
            if not contour_class_dir.is_dir():
                continue
            label = contour_class_dir.name
            feature_class_dir = feature_ready_dir / label
            if not feature_class_dir.exists():
                continue
            for contour_image_path in sorted(contour_class_dir.iterdir()):
                if contour_image_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
                    continue
                feature_ready_image_path = feature_class_dir / contour_image_path.name
                if not feature_ready_image_path.exists():
                    continue
                samples.append((SignatureSample(image_path=contour_image_path, label=label), feature_ready_image_path))
        if not samples:
            raise ValueError(f"No paired contour/feature-ready samples found in {contour_dir} and {feature_ready_dir}")
        return samples

    def build_feature_table(self, contour_dir: Path, feature_ready_dir: Path) -> List[SignatureFeatures]:
        samples = self.discover_sample_pairs(contour_dir, feature_ready_dir)
        features: List[SignatureFeatures] = []
        for contour_sample, feature_ready_image_path in samples:
            features.append(self.extractor.process_artifacts(contour_sample.image_path, feature_ready_image_path, contour_sample.label))
        return features

    def train(self, contour_dir: Path, feature_ready_dir: Path) -> Dict[str, float]:
        feature_rows = self.build_feature_table(contour_dir, feature_ready_dir)
        x = np.stack([row.feature_vector for row in feature_rows])
        y = np.array([row.label for row in feature_rows])

        labels, counts = np.unique(y, return_counts=True)
        can_stratify = len(labels) > 1 and int(counts.min()) >= 2 and len(feature_rows) >= 4

        if can_stratify:
            x_train, x_test, y_train, y_test = train_test_split(
                x,
                y,
                test_size=0.2,
                random_state=42,
                stratify=y,
            )
        else:
            x_train, x_test, y_train, y_test = x, np.empty((0, x.shape[1]), dtype=x.dtype), y, np.array([])

        self.model = Pipeline(
            steps=[
                ("scaler", StandardScaler()),
                (
                    "classifier",
                    RandomForestClassifier(n_estimators=250, random_state=42, class_weight="balanced"),
                ),
            ]
        )
        self.model.fit(x_train, y_train)

        train_accuracy = float(self.model.score(x_train, y_train))
        test_accuracy = float(self.model.score(x_test, y_test)) if len(x_test) else train_accuracy

        self.class_prototypes = self._build_class_prototypes(feature_rows)
        return {
            "train_accuracy": train_accuracy,
            "test_accuracy": test_accuracy,
            "num_samples": float(len(feature_rows)),
            "num_classes": float(len(self.class_prototypes)),
        }

    def _build_class_prototypes(self, feature_rows: Sequence[SignatureFeatures]) -> Dict[str, np.ndarray]:
        grouped: Dict[str, List[np.ndarray]] = {}
        for row in feature_rows:
            grouped.setdefault(row.label, []).append(row.feature_vector)
        return {label: np.mean(np.stack(vectors), axis=0) for label, vectors in grouped.items()}

    def save(self, path: Path) -> None:
        if self.model is None:
            raise ValueError("Model is not trained yet.")
        payload = {"model": self.model, "class_prototypes": self.class_prototypes, "output_size": self.extractor.output_size}
        joblib.dump(payload, path)

    @classmethod
    def load(cls, path: Path) -> "SignatureVerificationPipeline":
        payload = joblib.load(path)
        pipeline = cls(output_size=int(payload.get("output_size", DEFAULT_OUTPUT_SIZE)))
        pipeline.model = payload["model"]
        pipeline.class_prototypes = payload.get("class_prototypes", {})
        return pipeline

    def infer(self, contour_image_path: Path, feature_ready_image_path: Path, enrolled_label: Optional[str] = None, threshold: float = 0.75) -> VerificationResult:
        if self.model is None:
            raise ValueError("Model is not trained or loaded.")

        sample = self.extractor.process_artifacts(contour_image_path, feature_ready_image_path, label=enrolled_label or "unknown")
        predicted_label = str(self.model.predict(sample.feature_vector.reshape(1, -1))[0])

        similarity_score = self._similarity_to_enrolled(sample.feature_vector, enrolled_label)
        if enrolled_label is None:
            enrolled_label = predicted_label
            similarity_score = self._similarity_to_enrolled(sample.feature_vector, enrolled_label)

        verification_result = "valid" if similarity_score >= threshold and predicted_label == enrolled_label else "invalid"

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
