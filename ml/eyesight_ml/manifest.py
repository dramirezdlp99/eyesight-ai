"""Manifiesto del modelo empaquetado en la aplicación.

La aplicación verifica el resumen SHA-256 antes de ejecutar el modelo
(STRIDE: manipulación, numeral 4.1.7).
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

MODEL_FILE = "eyesight_yolov8n.tflite"
LABELS_FILE = "labels.txt"
MANIFEST_FILE = "model_manifest.json"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def install_model(
    model: Path,
    labels: list[str],
    assets_dir: Path,
    name: str,
    quantization: str,
    source: str,
    input_size: int = 320,
) -> dict:
    """Copia el modelo a assets/models y escribe etiquetas y manifiesto."""
    if not labels:
        raise ValueError("La lista de etiquetas está vacía")
    assets_dir.mkdir(parents=True, exist_ok=True)
    target = assets_dir / MODEL_FILE
    shutil.copy2(model, target)
    (assets_dir / LABELS_FILE).write_text("\n".join(labels) + "\n", encoding="utf-8")
    manifest = {
        "name": name,
        "file": MODEL_FILE,
        "labels": LABELS_FILE,
        "sha256": sha256_file(target),
        "input_size": input_size,
        "quantization": quantization,
        "source": source,
    }
    (assets_dir / MANIFEST_FILE).write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return manifest
