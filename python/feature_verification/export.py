from __future__ import annotations

from pathlib import Path

import json

from .pipeline import SignatureVerificationPipeline


def export_feature_manifest(contour_dir: Path, feature_ready_dir: Path, output_dir: Path) -> Path:
    pipeline = SignatureVerificationPipeline()
    feature_rows = pipeline.build_feature_table(contour_dir, feature_ready_dir)
    manifest = {
        "contour_dir": str(contour_dir),
        "feature_ready_dir": str(feature_ready_dir),
        "samples": [row.to_dict() for row in feature_rows],
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "feature_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest_path
