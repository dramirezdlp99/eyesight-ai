"""Extrae cuadros nítidos de los videos grabados en Pasto para etiquetarlos.

Guarda un cuadro por segundo (configurable), descarta los movidos, reduce el
tamaño y, si se pide, difumina las caras que encuentre (privacidad, Ley 1581
de 2012).

Uso:
    pip install opencv-python-headless numpy
    python scripts/extract_frames.py --videos videos/*.mp4 \
        --place centro --output datasets/pasto/centro --blur-faces
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from eyesight_ml.frames import (  # noqa: E402
    frame_indices,
    frame_name,
    resized_dims,
    sharpness,
    to_gray,
)


def blur_faces(cv2, image, detector):
    """Difumina las caras detectadas en la imagen (la modifica en su lugar)."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    faces = detector.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
    for x, y, w, h in faces:
        roi = image[y : y + h, x : x + w]
        k = max(15, (w // 3) | 1)
        image[y : y + h, x : x + w] = cv2.GaussianBlur(roi, (k, k), 0)
    return len(faces)


def extract(cv2, video: Path, args, detector) -> tuple[int, int]:
    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        print(f"  No pude abrir {video}")
        return 0, 0
    fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
    total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    wanted = set(frame_indices(fps, total, args.every))
    saved = blurry = 0
    index = 0
    while True:
        ok = capture.grab()
        if not ok:
            break
        if index in wanted:
            ok, image = capture.retrieve()
            if ok:
                score = sharpness(to_gray(image))
                if score < args.min_sharpness:
                    blurry += 1
                else:
                    h, w = image.shape[:2]
                    nw, nh = resized_dims(w, h, args.max_side)
                    if (nw, nh) != (w, h):
                        image = cv2.resize(image, (nw, nh), interpolation=cv2.INTER_AREA)
                    if detector is not None:
                        blur_faces(cv2, image, detector)
                    name = frame_name(args.place, video.stem, index / fps)
                    cv2.imwrite(
                        str(args.output / name),
                        image,
                        [cv2.IMWRITE_JPEG_QUALITY, 92],
                    )
                    saved += 1
        index += 1
    capture.release()
    return saved, blurry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--videos", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("datasets/pasto/frames"))
    parser.add_argument("--place", default="pasto", help="barrio o calle del video")
    parser.add_argument("--every", type=float, default=1.0, help="segundos entre cuadros")
    parser.add_argument(
        "--min-sharpness",
        type=float,
        default=60.0,
        help="varianza mínima del laplaciano; súbala si quedan cuadros movidos",
    )
    parser.add_argument("--max-side", type=int, default=1280)
    parser.add_argument("--blur-faces", action="store_true")
    args = parser.parse_args()

    try:
        import cv2  # noqa: PLC0415
    except ImportError as error:
        raise SystemExit("Instale OpenCV: pip install opencv-python-headless") from error

    args.output.mkdir(parents=True, exist_ok=True)
    detector = None
    if args.blur_faces:
        detector = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
    total_saved = total_blurry = 0
    for video in args.videos:
        saved, blurry = extract(cv2, video, args, detector)
        print(f"{video.name}: {saved} cuadros guardados, {blurry} descartados por movidos")
        total_saved += saved
        total_blurry += blurry
    print(f"Total: {total_saved} cuadros en {args.output} ({total_blurry} movidos)")


if __name__ == "__main__":
    main()
