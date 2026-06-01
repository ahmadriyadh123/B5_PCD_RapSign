from __future__ import annotations

from pathlib import Path
from typing import Tuple

import cv2
import numpy as np
import torch

from .constants import DEFAULT_OUTPUT_SIZE
from .models import SignatureArtifacts, SignatureFeatures


class SignatureFeatureExtractor:
    def __init__(self, output_size: int = DEFAULT_OUTPUT_SIZE) -> None:
        self.output_size = output_size

    def load_artifact_image(self, image_path: Path) -> np.ndarray:
        image = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
        if image is None:
            raise ValueError(f"Unable to read artifact image: {image_path}")
        return image

    def prepare_artifacts_from_paths(self, contour_image_path: Path, feature_ready_image_path: Path) -> SignatureArtifacts:
        contour_image = self.load_artifact_image(contour_image_path)
        feature_ready_image = self.load_artifact_image(feature_ready_image_path).astype(np.float32) / 255.0

        if feature_ready_image.shape[:2] != (self.output_size, self.output_size):
            feature_ready_image = cv2.resize(
                feature_ready_image,
                (self.output_size, self.output_size),
                interpolation=cv2.INTER_AREA,
            )

        contours, _ = cv2.findContours((contour_image > 0).astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            largest = max(contours, key=cv2.contourArea)
            x, y, w, h = cv2.boundingRect(largest)
            bbox = (int(x), int(y), int(w), int(h))
        else:
            height, width = contour_image.shape[:2]
            bbox = (0, 0, width, height)

        return SignatureArtifacts(
            contour_image=contour_image,
            feature_ready_image=feature_ready_image,
            bbox=bbox,
        )

    def process_artifacts(self, contour_image_path: Path, feature_ready_image_path: Path, label: str) -> SignatureFeatures:
        artifacts = self.prepare_artifacts_from_paths(contour_image_path, feature_ready_image_path)
        
        # Prepare the input tensor for the CNN (1 channel, H, W)
        image_tensor = torch.from_numpy(artifacts.feature_ready_image).unsqueeze(0)
        
        return SignatureFeatures(
            label=label,
            image_path=contour_image_path,
            bbox=artifacts.bbox,
            image_tensor=image_tensor,
            contour_image=artifacts.contour_image,
            feature_ready_image=artifacts.feature_ready_image,
        )

    def prepare_artifact_from_raw_image(self, raw_image_path: Path) -> SignatureArtifacts:
        # Load raw image
        image = self.load_artifact_image(raw_image_path)
        
        # 1. Apply thresholding (Otsu's binarization) to separate signature from background
        # Assume background is light and signature is dark. Invert so signature becomes white (foreground)
        _, thresh = cv2.threshold(image, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        contour_image = thresh.astype(np.uint8)
        
        # 2. Resize and normalize for CNN input
        feature_ready_image = cv2.resize(
            contour_image.astype(np.float32) / 255.0,
            (self.output_size, self.output_size),
            interpolation=cv2.INTER_AREA,
        )
        
        # 3. Find bounding box
        contours, _ = cv2.findContours(contour_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            largest = max(contours, key=cv2.contourArea)
            x, y, w, h = cv2.boundingRect(largest)
            bbox = (int(x), int(y), int(w), int(h))
        else:
            height, width = contour_image.shape[:2]
            bbox = (0, 0, width, height)
            
        return SignatureArtifacts(
            contour_image=contour_image,
            feature_ready_image=feature_ready_image,
            bbox=bbox,
        )

    def process_raw_image(self, raw_image_path: Path, label: str) -> SignatureFeatures:
        artifacts = self.prepare_artifact_from_raw_image(raw_image_path)
        image_tensor = torch.from_numpy(artifacts.feature_ready_image).unsqueeze(0)
        return SignatureFeatures(
            label=label,
            image_path=raw_image_path,
            bbox=artifacts.bbox,
            image_tensor=image_tensor,
            contour_image=artifacts.contour_image,
            feature_ready_image=artifacts.feature_ready_image,
        )
