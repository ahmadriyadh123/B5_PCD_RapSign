"""
Script training model signature CNN.

Cara pakai:
  python python/train_model.py --dataset-dir Dataset --epochs 15

Struktur folder dataset yang diharapkan:
  Dataset/
    nama_orang_1/
      1.png
      2.png
      ...
    nama_orang_2/
      1.png
      ...

Setelah training, model tersimpan di:
  python_outputs/signature_model.joblib (atau .pt)
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from python.feature_verification.pipeline import SignatureVerificationPipeline
from python.feature_verification.constants import DEFAULT_MODEL_PATH

import argparse

def main():
    parser = argparse.ArgumentParser(description="Train Signature CNN Model")
    parser.add_argument(
        "--dataset-dir",
        type=Path,
        default=Path("Dataset"),
        help="Folder dataset berisi subfolder per identitas",
    )
    parser.add_argument(
        "--epochs", type=int, default=10,
        help="Jumlah epoch training (default: 10)",
    )
    parser.add_argument(
        "--batch-size", type=int, default=8,
        help="Batch size (default: 8)",
    )
    parser.add_argument(
        "--output", type=Path, default=DEFAULT_MODEL_PATH,
        help=f"Path output model (default: {DEFAULT_MODEL_PATH})",
    )
    args = parser.parse_args()

    if not args.dataset_dir.exists():
        print(f"[ERROR] Folder dataset tidak ditemukan: {args.dataset_dir}")
        print("Pastikan struktur folder sudah benar:")
        print("  Dataset/")
        print("    nama_orang_1/")
        print("      1.png, 2.png, ...")
        sys.exit(1)

    print(f"[TRAIN] Dataset   : {args.dataset_dir}")
    print(f"[TRAIN] Epochs    : {args.epochs}")
    print(f"[TRAIN] Batch size: {args.batch_size}")
    print(f"[TRAIN] Output    : {args.output}")
    print()

    pipeline = SignatureVerificationPipeline()
    metrics = pipeline.train(
        args.dataset_dir,
        epochs=args.epochs,
        batch_size=args.batch_size,
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    pipeline.save(args.output)

    print()
    print("=" * 50)
    print("  TRAINING SELESAI")
    print(f"  Jumlah sampel : {int(metrics['num_samples'])}")
    print(f"  Jumlah kelas  : {int(metrics['num_classes'])}")
    print(f"  Final loss    : {metrics['final_loss']:.4f}")
    print(f"  Model disimpan: {args.output}")
    print("=" * 50)
    print()
    print("Untuk menjalankan server:")
    print("  cd python/api")
    print("  uvicorn server:app --reload --port 8000")


if __name__ == "__main__":
    main()