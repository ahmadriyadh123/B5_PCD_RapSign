Param(
  [string]$ModelSrc = "python_outputs/dummy_other_group/model.joblib",
  [string]$ModelDst = "python/model.joblib",
  [string]$VenvDir = ".venv",
  [int]$Port = 8000,
  [string]$BindHost = "127.0.0.1"
)

Write-Host "[run_inference_server] Starting helper script..."

if (Test-Path $ModelSrc) {
  $dstDir = Split-Path $ModelDst -Parent
  if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
  Copy-Item $ModelSrc $ModelDst -Force
  Write-Host "[run_inference_server] Copied model: $ModelSrc -> $ModelDst"
} else {
  Write-Warning "[run_inference_server] Model source not found: $ModelSrc"
  Write-Warning "[run_inference_server] Please supply a model file or change the -ModelSrc parameter. Server will attempt to start but may fail if model is required at startup."
}

if (-not (Test-Path $VenvDir)) {
  Write-Host "[run_inference_server] Creating virtual environment at $VenvDir"
  python -m venv $VenvDir
}

Write-Host "[run_inference_server] Activating virtual environment"
& "$VenvDir\Scripts\Activate.ps1"

Write-Host "[run_inference_server] Installing dependencies (from python/requirements.txt if available)"
if (Test-Path python\requirements.txt) {
  pip install --upgrade pip
  pip install -r python\requirements.txt
} else {
  Write-Warning "[run_inference_server] requirements.txt not found; installing minimal deps"
  pip install --upgrade pip
  pip install uvicorn fastapi python-multipart numpy opencv-python scikit-learn joblib torch torchvision
}

Write-Host "[run_inference_server] Launching FastAPI server (uvicorn) on ${BindHost}:${Port}"
python -m uvicorn python.feature_verification.api:app --host $BindHost --port $Port --reload
