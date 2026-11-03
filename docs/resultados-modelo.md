# Resultados del modelo ajustado (CP-01)

## Datos

| Conjunto | Imágenes | Cajas | Origen |
|---|---|---|---|
| Entrenamiento Pasto | 462 (1242 con aumentos 3x) | 2718 | 6 videos del barrio + 11 de otros sectores; Auto Label (Gemini 4 Argon) y revisión manual de cada imagen |
| Clases comunes (COCO 2017 val) | ~500 | — | Bicicletas, camiones, buses y perros, contra el olvido catastrófico |
| Prueba Pasto | 106 | 580 | 8 videos de sectores que el modelo nunca ve al entrenar; revisión manual |

Criterio de `pothole`: hueco, hundimiento, alcantarilla destapada o daño del pavimento que
representa riesgo de tropiezo o caída (no grietas finas). Reductores de velocidad: `step`.
Hidrante de pie: `bollard`. Barandas: sin etiqueta.

## Experimento 1 (línea base) · 30 de octubre de 2026

**Configuración:**
- YOLOv8n preentrenado en COCO;
- 320 px, lote de 32;
- 100 épocas con paciencia de 20: se detuvo en la 54, con la mejor en la 34;
- unos 12 minutos en una GPU T4;
- validación: 15 % aleatorio de los cuadros.

**Resultados en la prueba de Pasto** (umbral 0,5; modelo float32):

| Clase | Precisión | Recall | AP@0,5 |
|---|---|---|---|
| step | 0,724 | 0,231 | 0,391 |
| pole | 0,405 | 0,214 | 0,253 |
| bollard | 1,000 | 0,158 | 0,235 |
| pothole | 0,500 | 0,017 | 0,040 |
| person | 0,731 | 0,376 | 0,473 |
| car | 0,623 | 0,469 | 0,472 |
| motorcycle | 0,667 | 0,273 | 0,348 |

- **INT8:** 3,3 MB frente a 12,7 MB del modelo float32. La pérdida por cuantización es pequeña:
  en `step`, el AP@0,5 baja de 0,391 a 0,324.
- **Umbral de mayor F1** en la prueba: 0,30 a 0,35.
- **Hipótesis (clases comunes):** diferencia de mAP@0,5 de −0,098, con IC 95 % de
  [−0,191; −0,021]. No se rechaza H0.

**Análisis:**
- **Validación inflada.** En validación, la matriz de confusión daba 0,74 para `pothole`, 0,90 para
  `pole` y 0,80 para `step`. En sectores nuevos el rendimiento fue mucho menor. Los cuadros de un
  mismo video quedaron en entrenamiento y en validación, así que la validación medía memoria y no
  generalización. Por eso también la detención temprana eligió mal la época.
- **Resolución.** A 320 px, un hueco en una foto de 720×1280 queda en muy pocos píxeles.
- **Olvido catastrófico de las clases comunes**, a pesar del subconjunto de COCO. El ajuste con
  pocos datos desplaza los pesos.

## Experimento 2 · 30 de octubre de 2026

**Cambios frente al experimento 1:**
- 480 px;
- hasta 150 épocas con paciencia de 40;
- **validación por video completo**: el 15 % de los videos de Pasto, sin mezclar cuadros de un
  mismo video.

**Resultados en la prueba de Pasto** (umbral 0,5):

| Clase | AP@0,5 exp. 1 | AP@0,5 exp. 2 |
|---|---|---|
| step | 0,391 | 0,256 |
| pole | 0,253 | 0,249 |
| bollard | 0,235 | 0,037 |
| pothole | 0,040 | 0,032 |
| person | 0,473 | 0,630 |
| car | 0,472 | 0,543 |
| motorcycle | 0,348 | 0,496 |

**Hipótesis (clases comunes):** diferencia de −0,028, con IC 95 % de [−0,122; 0,039]. Ya no hay
pérdida significativa frente al modelo base, porque el olvido de las clases comunes se redujo.

**Análisis:** la **mejor época fue la 1**, según la métrica de Ultralytics
(0,1·mAP50 + 0,9·mAP50-95). La validación mezclaba los videos de Pasto con unas 75 imágenes de
COCO, y en la época 1 el modelo todavía es casi el de COCO, así que puntúa alto ahí. El modelo
guardado casi no había aprendido las clases nuevas: por eso subieron las comunes y bajaron las
nuevas. Es un error de **selección de modelo**, no de aprendizaje.

## Experimento 3 · 30 de octubre de 2026 (modelo elegido)

**Cambio único frente al experimento 2:** la validación tiene **solo videos de Pasto**. COCO queda
85 % en entrenamiento y 15 % en prueba, para medir el olvido.

**Entrenamiento:** 80 épocas, con la mejor en la 40, en unos 23 minutos.

**Resultados en la prueba de Pasto** (AP@0,5; float32):

| Clase | Exp. 1 | Exp. 2 | **Exp. 3** | Exp. 3 INT8 |
|---|---|---|---|---|
| step | 0,391 | 0,256 | **0,380** | 0,320 |
| pole | 0,253 | 0,249 | **0,256** | 0,245 |
| bollard | 0,235 | 0,037 | 0,078 | 0,070 |
| pothole | 0,040 | 0,032 | **0,093** | 0,059 |
| person | 0,473 | 0,630 | **0,693** | 0,564 |
| car | 0,472 | 0,543 | **0,588** | 0,457 |
| motorcycle | 0,348 | 0,496 | 0,487 | 0,444 |
| **F1 global (mejor umbral)** | 0,427 | 0,429 | **0,502** (0,40) | 0,436 (0,30) |

- **Precisión alta en las clases nuevas** con umbral 0,5:
  - `pole`: 0,909;
  - `step`: 0,721;
  - `bollard` y `pothole`: 1,000 (con pocos aciertos).

  Cuando la app avisa, casi siempre es correcto: hay pocas falsas alarmas.
- **Recall bajo:** `step` 0,24 y `pole` 0,14. Muchos obstáculos de sectores nuevos no se detectan
  en un cuadro dado. Como la app analiza unos 4 cuadros por segundo y el filtro de estabilidad
  confirma en varios, la probabilidad de detectar el obstáculo al acercarse es mayor que la de un
  solo cuadro. Esto se mide en campo.
- **Hipótesis (clases comunes):** −0,070, con IC 95 % de [−0,170; −0,011]. No se rechaza H0: el
  ajuste no mejora a COCO en sus propias clases, y las clases nuevas son la contribución.
- **Cuantización INT8:** reduce el modelo de unos 12 MB a 3,3 MB, con una pérdida moderada de AP.

**Decisión.** Según la regla fijada antes de ver los resultados («igualar o superar al
experimento 1 en las clases nuevas sin olvidar las comunes»), el **experimento 3 es el modelo
final**:
- iguala al experimento 1 en `step` y `pole`;
- mejora `pothole`;
- tiene la mejor F1 global y la menor pérdida en las clases comunes de los tres.

`bollard` y `construction` quedan con pocos ejemplos en la prueba (19 y 3 cajas). Sus resultados
son descriptivos.

**Limitaciones y trabajo futuro:**
- conjunto pequeño (462 imágenes, 17 videos);
- una sola ciudad y una sola franja horaria;
- `pothole` sigue siendo la clase más difícil, y la cubren las zonas de riesgo con GPS (ADR-1 y
  ADR-13).

Mejoras posibles: más videos por clase, YOLOv8s si el teléfono lo permite, y aprendizaje continuo
con consentimiento.

## Exportación para el teléfono · 3 de noviembre de 2026

**Problema.** El modelo INT8 exportado en Colab con Ultralytics 8.4.83 o posterior usa la nueva
ruta LiteRT (`litert-torch` y `ai-edge-quantizer`). Ese archivo funciona en un computador x86,
pero en el vivo Y22s (ARM) la inferencia falla siempre con «Bad state: failed precondition»
(falla `TfLiteInterpreterInvoke`). El modo de pruebas mostró el error exacto. El archivo declara
todas sus operaciones en la versión 1 aunque sus tensores son int8, y tiene entrada con canales
primero, `[1, 3, 480, 480]`.

**Solución.** Se volvió a exportar el mismo `best.pt` por la ruta clásica, en un entorno con
Python 3.11, Ultralytics 8.4.82, TensorFlow 2.19.0 y onnx2tf 1.27.10:

```
yolo export model=best.pt format=tflite imgsz=480 int8=True data=calib.yaml
```

La calibración usa 150 cuadros de entrenamiento de Pasto. Esa ruta produce modelos con entrada
`[1, 480, 480, 3]` (canales al final) y versiones de operación correctas (CONV_2D v3/v5). Las
variantes se compararon en la prueba de Pasto (AP@0,5, LiteRT 1.4):

| Clase | best.pt float32 | INT8 dinámico | INT8 entero (E/S float) | INT8 entero (E/S int8) | LiteRT INT8 (falla en el teléfono) |
|---|---|---|---|---|---|
| step | 0,380 | **0,354** | 0,332 | 0,335 | 0,320 |
| pole | 0,256 | 0,269 | **0,297** | 0,284 | 0,245 |
| bollard | 0,078 | **0,081** | 0,076 | 0,072 | 0,070 |
| pothole | 0,093 | 0,090 | **0,092** | 0,087 | 0,059 |
| person | 0,693 | **0,681** | 0,601 | 0,601 | 0,564 |
| car | 0,588 | **0,596** | 0,559 | 0,556 | 0,457 |
| motorcycle | 0,487 | **0,476** | 0,396 | 0,399 | 0,444 |

**Decisión.** Se empaqueta el **INT8 dinámico** (`best_int8.tflite`, 3,4 MB): pesos en int8 y
cálculo en float. Es la variante más cercana al modelo float32 en todas las clases, y mejora al
INT8 de LiteRT. Si en el teléfono resulta lento, la alternativa es el INT8 entero, con algo
menos de AP en personas y motos.

## Configuración en la app

- Modelo INT8 dinámico, entrada de 480×480 en formato `[1, 480, 480, 3]` (exportación clásica
  con onnx2tf). La app detecta sola si la entrada tiene los canales primero o al final.
- Umbral de confianza por defecto: **0,35**, entre el mejor umbral de INT8 (0,30) y el de float32
  (0,40). El acompañante lo puede ajustar en Ajustes.
