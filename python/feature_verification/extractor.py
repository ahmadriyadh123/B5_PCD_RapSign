from __future__ import annotations

from pathlib import Path
from typing import Tuple

import cv2
import numpy as np

from .constants import DEFAULT_OUTPUT_SIZE
from .models import SignatureArtifacts, SignatureFeatures


class SignatureFeatureExtractor:
    def __init__(self, output_size: int = DEFAULT_OUTPUT_SIZE) -> None:
        self.output_size = output_size

    def extract_feature_vector(self, contour_image: np.ndarray) -> np.ndarray:
        binary = (contour_image > 0).astype(np.uint8)
        height, width = binary.shape[:2]
        total_pixels = float(height * width)

        ys, xs = np.where(binary > 0)
        if len(xs) == 0:
            bbox_width = 1.0
            bbox_height = 1.0
            foreground_area = 0.0
            centroid_x = 0.0
            centroid_y = 0.0
        else:
            min_x, max_x = xs.min(), xs.max()
            min_y, max_y = ys.min(), ys.max()
            bbox_width = float(max_x - min_x + 1)
            bbox_height = float(max_y - min_y + 1)
            foreground_area = float(len(xs))
            centroid_x = float(xs.mean()) / max(width, 1)
            centroid_y = float(ys.mean()) / max(height, 1)

        aspect_ratio = bbox_width / max(bbox_height, 1.0)
        area_ratio = foreground_area / max(total_pixels, 1.0)
        horizontal_coverage = bbox_width / max(float(width), 1.0)
        vertical_coverage = bbox_height / max(float(height), 1.0)

        edges = cv2.Canny(contour_image, 50, 150)
        edge_density = float(np.count_nonzero(edges)) / max(total_pixels, 1.0)

        line_profile_x = binary.sum(axis=0) / 255.0
        line_profile_y = binary.sum(axis=1) / 255.0
        line_density_x = float(np.mean(line_profile_x > 0))
        line_density_y = float(np.mean(line_profile_y > 0))
        mean_intensity = float(contour_image.mean()) / 255.0
        std_intensity = float(contour_image.std()) / 255.0

        contours, _ = cv2.findContours(binary * 255, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        contour_count = float(len(contours))
        largest_perimeter = 0.0
        largest_area = 0.0
        if contours:
            largest = max(contours, key=cv2.contourArea)
            largest_perimeter = float(cv2.arcLength(largest, True)) / max(float(width + height), 1.0)
            largest_area = float(cv2.contourArea(largest)) / max(total_pixels, 1.0)

        histogram = cv2.calcHist([contour_image], [0], None, [16], [0, 256]).flatten()
        histogram = histogram / max(float(histogram.sum()), 1.0)

        feature_vector = np.array(
            [
                aspect_ratio,
                area_ratio,
                horizontal_coverage,
                vertical_coverage,
                centroid_x,
                centroid_y,
                edge_density,
                line_density_x,
                line_density_y,
                mean_intensity,
                std_intensity,
                contour_count,
                largest_perimeter,
                largest_area,
                *histogram.tolist(),
            ],
            dtype=np.float32,
        )
        return feature_vector

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

    def summarize_feature_ready_image(self, feature_ready_image: np.ndarray) -> np.ndarray:
        if feature_ready_image.ndim == 3:
            feature_ready_image = feature_ready_image.squeeze()

        if feature_ready_image.shape != (self.output_size, self.output_size):
            feature_ready_image = cv2.resize(
                feature_ready_image,
                (self.output_size, self.output_size),
                interpolation=cv2.INTER_AREA,
            )

        image = feature_ready_image.astype(np.float32)
        histogram = cv2.calcHist([np.clip(image * 255.0, 0, 255).astype(np.uint8)], [0], None, [16], [0, 256]).flatten()
        histogram = histogram / max(float(histogram.sum()), 1.0)

        return np.array([
            float(image.mean()),
            float(image.std()),
            float(np.count_nonzero(image > 0.0)) / max(float(image.size), 1.0),
            *histogram.tolist(),
        ], dtype=np.float32)

    def compose_feature_vector(self, contour_image: np.ndarray, feature_ready_image: np.ndarray) -> np.ndarray:
        contour_features = self.extract_feature_vector(contour_image)
        ready_features = self.summarize_feature_ready_image(feature_ready_image)
        return np.concatenate([contour_features, ready_features]).astype(np.float32)

    def process_artifacts(self, contour_image_path: Path, feature_ready_image_path: Path, label: str) -> SignatureFeatures:
        artifacts = self.prepare_artifacts_from_paths(contour_image_path, feature_ready_image_path)
        feature_vector = self.compose_feature_vector(artifacts.contour_image, artifacts.feature_ready_image)
        return SignatureFeatures(
            label=label,
            image_path=contour_image_path,
            bbox=artifacts.bbox,
            feature_vector=feature_vector,
            contour_image=artifacts.contour_image,
            feature_ready_image=artifacts.feature_ready_image,
        )
