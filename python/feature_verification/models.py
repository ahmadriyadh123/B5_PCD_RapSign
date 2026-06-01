from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import torch


@dataclass(frozen=True)
class SignatureSample:
    image_path: Path
    label: str


@dataclass(frozen=True)
class SignatureFeatures:
    label: str
    image_path: Path
    bbox: Tuple[int, int, int, int]
    image_tensor: torch.Tensor
    contour_image: np.ndarray
    feature_ready_image: np.ndarray

    def to_dict(self) -> Dict[str, object]:
        return {
            "label": self.label,
            "image_path": str(self.image_path),
            "bbox": list(self.bbox),
            "tensor_shape": list(self.image_tensor.shape),
        }


@dataclass(frozen=True)
class SignatureArtifacts:
    contour_image: np.ndarray
    feature_ready_image: np.ndarray
    bbox: Tuple[int, int, int, int]


@dataclass(frozen=True)
class VerificationResult:
    label: str
    predicted_label: str
    similarity_score: float
    verification_result: str
    detection_coordinate: Tuple[int, int, int, int]

    def to_dict(self) -> Dict[str, object]:
        return {
            "label": self.label,
            "predicted_label": self.predicted_label,
            "similarity_score": self.similarity_score,
            "verification_result": self.verification_result,
            "detection_coordinate": list(self.detection_coordinate),
        }
