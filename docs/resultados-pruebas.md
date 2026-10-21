# Resultados de las pruebas en el dispositivo

**Teléfono:** vivo Y22s (gama baja).
**Modelo:** YOLOv8n preentrenado en COCO, float32, entrada de 320 px (12,7 MB).
**Datos:** CSV exportados con el modo de pruebas (HU15).

Los casos marcados como «pendiente» se completan con el modelo INT8 ajustado a Pasto.

## Resumen

| Caso | Requisito | Meta | Resultado | Estado |
|---|---|---|---|---|
| CP-02 | RNF01: tiempo de inferencia | < 100 ms | Media de 202,1 ms; mediana de 193,7 ms; p95 de 283,7 ms | No cumple con el modelo base |
| CP-02 | RNF02: de la captura a la alerta | ≤ 500 ms | Media de 225,9 ms; p95 de 309 ms; máximo de 315 ms; el 100 % ≤ 500 ms | **Cumple** |
| CP-02 | RNF03: cuadros por segundo | 5 a 10 fps | Media de 4,19 fps (entre 3,05 y 4,8) | No cumple con el modelo base |
| CP-04 | RNF04: sin internet | Funciones críticas sin conexión | Detección, voz, pitidos, zonas, historial, ajustes y privacidad funcionan | **Cumple** |
| CP-04 | HU04: vibración durante el escáner | 3, 2 o 1 pulsos según la cercanía | El vivo Y22s bloquea toda vibración con la cámara activa; se compensa con pitidos | Limitación del teléfono, mitigada |
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

### CP-02b. Hilos del procesador

Medición del 21 de octubre de 2026, en el mismo lugar y con la misma luz, frente a una persona. Se
hizo una corrida por configuración (de 43 a 50 s cada una) con el modelo base en float32. La
columna `hilos` del CSV identifica cada configuración.

| Hilos | Cuadros | Inferencia media (ms) | Mediana (ms) | p95 (ms) | fps | Alertas ≤ 500 ms | Captura a alerta media (ms) | Persona detectada |
|---|---|---|---|---|---|---|---|---|
| 2 | 159 | 232,9 | 229,0 | 296,3 | 3,70 | 10 de 10 | 268,2 | 97,5 % |
| 4 | 159 | 233,5 | 227,3 | 319,7 | 3,64 | 13 de 13 | 265,2 | 93,1 % |
| 6 | 182 | 235,2 | 227,6 | 317,9 | 3,63 | 11 de 12 (máximo 517,8 ms) | 282,4 | 98,4 % |

**Análisis.**
- La diferencia entre 2, 4 y 6 hilos es menor de 3 ms en la media y de 2 ms en la mediana. Es
  menor que la variación normal entre cuadros, así que **el número de hilos no cambia el
  rendimiento** en este teléfono.
- Una explicación probable: el procesador del vivo Y22s tiene pocos núcleos rápidos, y los hilos
  extra caen en núcleos lentos que no aceleran la inferencia. El cuello de botella sería el
  cómputo en float32 del modelo, no el paralelismo.
- Se deja el valor por defecto, **4 hilos**, porque tiene la mejor mediana y ninguna alerta pasó
  de 500 ms.
- En total, 34 de 35 alertas (97,1 %) llegaron en 500 ms o menos. La única que pasó (517,8 ms)
  coincidió con una inferencia aislada de 491 ms, un pico puntual del sistema.
- Las medias, de unos 233 ms, son algo mayores que en la primera corrida de CP-02 (202 ms). La
  diferencia probablemente se debe a la temperatura del teléfono tras corridas seguidas y a otras
  apps en segundo plano. Por eso las comparaciones se hacen dentro de la misma sesión.
- **Conclusión:** la mejora de RNF01 y RNF03 no vendrá de los hilos sino del modelo **INT8**
  (CP-02c), que reduce el cómputo por cuadro.

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
| Vibración | **No se siente durante el escáner** | El teléfono bloquea la vibración mientras la cámara está activa (ver «Hallazgo: vibración bloqueada por la cámara»). Se agregaron pitidos suaves como respaldo |
| Comandos de voz | No funcionan sin el paquete de español sin conexión | La app pasa a botones y gestos (RNF05). Se repite la prueba con el paquete instalado |
| Guardar zona con GPS | Funciona | El GPS no necesita internet |
| Mapa del acompañante | El plano queda en blanco; las zonas y la lista funcionan | Esperado (HU10, CA2) |
| Historial, ajustes y privacidad | Funcionan | Datos locales cifrados |

## Hallazgo: vibración bloqueada por la cámara

Durante las pruebas del 21 de octubre de 2026, la vibración de las alertas nunca se sintió en el
vivo Y22s. Se aisló la causa paso a paso:

| Prueba | Cámara | Voz | Micrófono | ¿Vibró? |
|---|---|---|---|---|
| «Probar vibración» en Ajustes | Apagada | No | No | **Sí** |
| Escáner con la voz en silencio | Encendida | No | Sí | No |
| Escáner, marcar zona | Encendida | Sí | Sí | No |
| Modo de pruebas | Encendida | Sí | No | No |
| Modo de pruebas: 7 formas de vibrar (alarma, notificación, accesibilidad, táctil, multimedia, la del plugin y la háptica del sistema) | Encendida | No | No | No; Android las aceptó todas sin error |
| Cámara del propio teléfono abierta + notificaciones de WhatsApp | Encendida | — | — | No; solo sonó la notificación |

**Conclusión.** El fabricante bloquea toda vibración mientras cualquier app usa la cámara; incluso
las notificaciones del sistema quedan sin vibrar. El código de la app es correcto: el mismo patrón
vibra con la cámara apagada.

**Mitigación (v1.0.2).** La app repite el código de la vibración con pitidos suaves (ondas seno
cortas con entrada y salida graduales): 3 pitidos agudos si el obstáculo está cerca, 2 a media
distancia, 1 grave lejos y un tono doble descendente para las zonas. Siguen el volumen
multimedia, como la voz, y se pueden apagar en Ajustes. Así, el usuario tiene un canal no verbal
aunque el teléfono bloquee la vibración.

**Para el informe.** La limitación depende del modelo de teléfono; se recomienda verificarla en
otros equipos y mencionarla en las recomendaciones de compra (anexo de presupuesto).

## Evaluación del modelo con imágenes de Pasto (pendiente)

Se ejecuta `ml/scripts/evaluate.py --test-dir <exportación de Roboflow>`.

| Nivel | Métricas |
|---|---|
| Por objeto | Matriz de confusión con la clase «fondo», precisión, sensibilidad, F1, AP@0.5, AP@0.5:0.95 e IoU medio por clase |
| Por imagen (¿hay obstáculo peligroso?) | VP, VN, FP, FN, exactitud, especificidad y AUC-ROC |
| Umbral | Curva de F1 según la confianza, para elegir la confianza mínima de la app |

Meta: F1 ≥ 0,80 en las clases peligrosas (poste, hueco, escalón).
