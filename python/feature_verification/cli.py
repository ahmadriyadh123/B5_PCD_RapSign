from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

from .constants import DEFAULT_EXPORT_DIR, DEFAULT_MODEL_PATH, DEFAULT_THRESHOLD
from .pipeline import SignatureVerificationPipeline
from .export import export_feature_manifest


def main(argv: Optional[list] = None) -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Signature verification ML pipeline")
    parser.add_argument("--contour-dir", type=Path, required=False, help="Folder contour-enhanced images")
    parser.add_argument("--feature-ready-dir", type=Path, required=False, help="Folder feature-ready images")
    parser.add_argument("--export-dir", type=Path, default=DEFAULT_EXPORT_DIR, help="Folder output artifacts")
    parser.add_argument("--train", action="store_true", help="Train model using the dataset")
    parser.add_argument("--contour", type=Path, help="Contour-enhanced image path for inference")
    parser.add_argument("--feature-ready", type=Path, dest="feature_ready", help="Feature-ready image path for inference")
    parser.add_argument("--label", type=str, help="Expected enrolled label for inference")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD, help="Similarity threshold")
    parser.add_argument("--model-path", type=Path, default=DEFAULT_MODEL_PATH)
    args = parser.parse_args(argv)

    pipeline = SignatureVerificationPipeline()

    if args.train:
        if args.contour_dir is None or args.feature_ready_dir is None:
            raise ValueError("Both --contour-dir and --feature-ready-dir are required for training.")
        metrics = pipeline.train(args.contour_dir, args.feature_ready_dir)
        args.model_path.parent.mkdir(parents=True, exist_ok=True)
        pipeline.save(args.model_path)
        export_feature_manifest(args.contour_dir, args.feature_ready_dir, args.export_dir)
        print(json.dumps(metrics, indent=2))

    if args.contour is not None or args.feature_ready is not None:
        if args.contour is None or args.feature_ready is None:
            raise ValueError("Both --contour and --feature-ready must be provided for inference.")
        if pipeline.model is None:
            if args.model_path.exists():
                pipeline = SignatureVerificationPipeline.load(args.model_path)
            else:
                raise FileNotFoundError(f"Model not found at {args.model_path}. Run with --train first.")
        result = pipeline.infer_payload(contour_image_path=args.contour, feature_ready_image_path=args.feature_ready, enrolled_label=args.label, threshold=args.threshold)
        print(json.dumps(result, indent=2))
