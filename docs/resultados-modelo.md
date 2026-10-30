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

## Experimento 3

**Cambio único frente al experimento 2:** la validación tiene **solo videos de Pasto**. COCO queda
85 % en entrenamiento y 15 % en prueba, para medir el olvido. Así la mejor época se elige por las
clases nuevas, en sectores no vistos.

**Resultados:** pendientes.
