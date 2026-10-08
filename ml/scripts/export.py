"""Exporta el modelo ajustado a LiteRT con cuantización INT8 y lo instala en
la aplicación (assets/models) junto con sus etiquetas y su manifiesto.

Uso:
    python scripts/export.py --weights runs/eyesight/yolov8n_ajustado/weights/best.pt \
        --data datasets/eyesight/eyesight.yaml
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from eyesight_ml.classes import EYESIGHT_CLASSES  # noqa: E402
from eyesight_ml.manifest import install_model  # noqa: E402

ASSETS = Path(__file__).resolve().parents[2] / "assets" / "models"


def main() -> None:
    from ultralytics import YOLO

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True, help="calibración INT8")
    parser.add_argument("--imgsz", type=int, default=320)
    parser.add_argument("--assets", type=Path, default=ASSETS)
    args = parser.parse_args()

    model = YOLO(str(args.weights))
    names = [model.names[i] for i in sorted(model.names)]
    if names != EYESIGHT_CLASSES:
        raise SystemExit(f"Las clases del modelo no coinciden: {names}")

    exported = Path(
        model.export(format="tflite", imgsz=args.imgsz, int8=True, data=str(args.data))
    )
    if exported.is_file() and exported.suffix == ".tflite":
        tflite = exported
    else:
        folder = exported if exported.is_dir() else exported.parent
        candidates = sorted(folder.glob("*int8*.tflite"))
        tflite = candidates[0] if candidates else None
    if tflite is None:
        raise SystemExit(f"No encontré el archivo .tflite exportado en {exported}")

    manifest = install_model(
        tflite,
        EYESIGHT_CLASSES,
        args.assets,
        name="yolov8n-eyesight-ajustado-int8",
        quantization="int8",
        source=f"YOLOv8n ajustado con el conjunto ampliado de EyeSight AI ({args.weights.name})",
        input_size=args.imgsz,
    )
    print(f"Modelo instalado en {args.assets}")
    print(f"SHA-256: {manifest['sha256']}")


if __name__ == "__main__":
    main()
