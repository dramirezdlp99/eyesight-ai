"""Une las exportaciones de Roboflow (formato YOLOv8) en un solo conjunto.

Uso:
    python scripts/prepare_dataset.py --sources datasets/raw/* --output datasets/eyesight
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from eyesight_ml.dataset import merge_sources  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("datasets/eyesight"))
    parser.add_argument(
        "--resplit",
        action="store_true",
        help="ignora las particiones de las fuentes y reparte 70/15/15",
    )
    args = parser.parse_args()

    sources = [s for s in args.sources if (s / "data.yaml").exists()]
    if not sources:
        raise SystemExit("No encontré carpetas con data.yaml en --sources")
    report = merge_sources(sources, args.output, keep_splits=not args.resplit)
    print(f"Imágenes por partición: {report.images}")
    print("Cajas por clase:")
    for name, count in report.boxes_per_class.items():
        print(f"  {name:14s} {count}")
    print(f"Cajas descartadas: {report.dropped_boxes}")
    print(f"Imágenes sin clases útiles: {report.skipped_images}")
    print(f"Configuración: {args.output / 'eyesight.yaml'}")


if __name__ == "__main__":
    main()
