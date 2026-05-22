from pathlib import Path

SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}

DEFAULT_OUTPUT_SIZE = 128
DEFAULT_MODEL_PATH = Path("python_outputs/signature_model.joblib")
DEFAULT_EXPORT_DIR = Path("python_outputs")
DEFAULT_DATASET_DIR = Path("Dataset")
DEFAULT_THRESHOLD = 0.75
