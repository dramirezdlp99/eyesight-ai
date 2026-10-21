# Resultados de las pruebas en el dispositivo

**Teléfono:** vivo Y22s (gama baja).
**Modelo:** YOLOv8n preentrenado en COCO, float32, entrada de 320 px (12,7 MB).
**Datos:** CSV exportados con el modo de pruebas (HU15).

Los casos marcados como «pendiente» se completan con el modelo INT8 ajustado a Pasto y con la
medición de hilos del Bloque 5.

## Resumen

| Caso | Requisito | Meta | Resultado | Estado |
|---|---|---|---|---|
| CP-02 | RNF01: tiempo de inferencia | < 100 ms | Media de 202,1 ms; mediana de 193,7 ms; p95 de 283,7 ms | No cumple con el modelo base |
| CP-02 | RNF02: de la captura a la alerta | ≤ 500 ms | Media de 225,9 ms; p95 de 309 ms; máximo de 315 ms; el 100 % ≤ 500 ms | **Cumple** |
| CP-02 | RNF03: cuadros por segundo | 5 a 10 fps | Media de 4,19 fps (entre 3,05 y 4,8) | No cumple con el modelo base |
| CP-04 | RNF04: sin internet | Funciones críticas sin conexión | Detección, voz, vibración, zonas, historial, ajustes y privacidad funcionan | **Cumple** |
| CP-04 | RNF05: tolerancia a fallos | Respaldo cuando falla un servicio | Sin el paquete de voz, los comandos pasan a botones y gestos | **Cumple** |

## CP-02. Rendimiento (modelo base, 4 hilos)

| Dato | Valor |
|---|---|
| Duración | 90 s |
| Cuadros analizados | 377 |
| Cuadros con persona detectada | 370 de 377 (98,1 %) |
| Confianza media de la detección de persona | 0,954 |
| Alertas emitidas | 22 |

| Tiempo de inferencia | ms |
|---|---|
| Media | 202,1 |
| Mediana | 193,7 |
| Percentil 95 | 283,7 |

| De la captura a la alerta | ms |
|---|---|
| Media | 225,9 |
| Percentil 95 | 309 |
| Máximo | 315 |

**Análisis.**
- El tiempo de captura a alerta, que es lo que siente el usuario, está muy por debajo del límite
  de 500 ms. Por eso la experiencia es fluida aun con 4 fps.
- RNF01 y RNF03 no se cumplen con el modelo float32 en este teléfono de gama baja.
- Acciones tomadas:
  1. Selector de hilos (2, 4 o 6) en el modo de pruebas, para elegir el más rápido.
  2. Modelo INT8, que suele ser de 2 a 3 veces más rápido en CPU móvil.

### CP-02b. Hilos del procesador (pendiente)

Se repite la prueba con 60 s por configuración, frente a una escena con personas, y se exporta un
CSV por cada una. La columna `hilos` del CSV identifica la configuración.

| Hilos | Inferencia media (ms) | p95 (ms) | fps | Captura a alerta media (ms) |
|---|---|---|---|---|
| 2 | | | | |
| 4 | | | | |
| 6 | | | | |

### CP-02c. Modelo INT8 ajustado (pendiente)

| Modelo | Tamaño | Inferencia media (ms) | fps | mAP@0.5 (Pasto) |
|---|---|---|---|---|
| YOLOv8n COCO float32 | 12,7 MB | 202,1 | 4,19 | — |
| YOLOv8n Pasto INT8 | | | | |

## CP-04. Modo avión

| Función | Resultado | Observación |
|---|---|---|
| Detección de obstáculos | Funciona | El modelo corre en el teléfono |
| Alertas por voz (TTS) | Funciona | Síntesis de voz sin conexión |
| Vibración | Funciona | Se sentía débil; en el Bloque 5 se reforzaron los patrones y la intensidad |
| Comandos de voz | No funcionan sin el paquete de español sin conexión | La app pasa a botones y gestos (RNF05). Se repite la prueba con el paquete instalado |
| Guardar zona con GPS | Funciona | El GPS no necesita internet |
| Mapa del acompañante | El plano queda en blanco; las zonas y la lista funcionan | Esperado (HU10, CA2) |
| Historial, ajustes y privacidad | Funcionan | Datos locales cifrados |

## Evaluación del modelo con imágenes de Pasto (pendiente)

Se ejecuta `ml/scripts/evaluate.py --test-dir <exportación de Roboflow>`.

| Nivel | Métricas |
|---|---|
| Por objeto | Matriz de confusión con la clase «fondo», precisión, sensibilidad, F1, AP@0.5, AP@0.5:0.95 e IoU medio por clase |
| Por imagen (¿hay obstáculo peligroso?) | VP, VN, FP, FN, exactitud, especificidad y AUC-ROC |
| Umbral | Curva de F1 según la confianza, para elegir la confianza mínima de la app |

Meta: F1 ≥ 0,80 en las clases peligrosas (poste, hueco, escalón).
