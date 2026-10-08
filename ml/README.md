# ml/ — Entrenamiento del modelo de EyeSight AI

Código en Python para el modelo de visión artificial (informe, numerales 2.2.1, 2.2.2, 2.3,
3.13.2 y 4.4.2). La aplicación **no** depende de esta carpeta para funcionar: incluye el modelo
YOLOv8n preentrenado en COCO como modelo base. Esta carpeta produce el modelo ajustado.

| Archivo | Función |
|---|---|
| `eyesight_ml/classes.py` | Las 13 clases del modelo ajustado (7 comunes con COCO + 6 nuevas) y sinónimos de Roboflow |
| `eyesight_ml/dataset.py` | Une exportaciones YOLOv8 de Roboflow y reasigna clases |
| `eyesight_ml/metrics.py` | Precisión, recall, F1, AP@0,5 (101 puntos) y bootstrap pareado para la hipótesis |
| `eyesight_ml/manifest.py` | Copia el modelo a `assets/models` con su SHA-256 |
| `scripts/prepare_dataset.py` | Paso 1: arma el conjunto de datos |
| `scripts/train.py` | Paso 2: ajuste fino de YOLOv8n a 320 px |
| `scripts/evaluate.py` | Paso 3: caso de prueba CP-01 y tabla para el numeral 4.4.2 |
| `scripts/export.py` | Paso 4: exporta a LiteRT INT8 e instala en la app |
| `notebooks/EyeSight_entrenamiento.ipynb` | Todo el proceso en Google Colab (GPU gratuita) |

## Dónde se ejecuta

El entrenamiento necesita GPU: se hace en **Google Colab** con el cuaderno. Abre
`https://colab.research.google.com`, pestaña **GitHub**, pega la URL del repositorio y elige
`ml/notebooks/EyeSight_entrenamiento.ipynb`.

## Pruebas (en tu computador, sin GPU)

```powershell
cd ml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install pyyaml numpy pytest
python -m pytest -q
```

## Hipótesis (numeral 2.3)

`evaluate.py` compara los dos modelos sobre el **mismo** conjunto de prueba y solo en las clases
comunes (persona, bicicleta, automóvil, motocicleta, bus, camión, perro). Calcula la diferencia
de mAP@0,5, su intervalo de confianza del 95 % y el valor p unilateral por bootstrap pareado por
imágenes. Si p < 0,05 se rechaza H0. Las clases nuevas se reportan de forma descriptiva.
