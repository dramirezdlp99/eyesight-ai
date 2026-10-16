# Guía de grabación en Pasto: conjunto de prueba del modelo

Esta guía explica cómo grabar los videos de Pasto que sirven para **evaluar** el modelo ajustado
(objetivo específico 3, caso de prueba CP-01). El modelo se **entrena** con conjuntos públicos de
Roboflow. Sus videos solo se usan para medir qué tan bien funciona en las calles de Pasto, y por
eso no tienen que ser muchos.

## 1. Qué necesita

- El teléfono (vivo Y22s) con al menos 5 GB libres.
- Una cinta para colgar el teléfono en el pecho, o un arnés de pecho para celular, que cuesta unos
  $25.000 a $40.000. Si no tiene arnés, sostenga el teléfono con las dos manos contra el pecho.
- De 2 a 3 salidas de unos 40 minutos, en días y horas distintas.
- Opcional: otra persona que camine a su lado para cuidar su seguridad mientras graba.

## 2. Cómo grabar

1. **Altura del pecho y en vertical.** Así se usará la app: con la cámara a unos 1,2 a 1,4 m del
   suelo, apuntando al frente y un poco hacia abajo, de modo que el suelo ocupe la mitad inferior
   de la imagen.
2. **Resolución 1080p a 30 cuadros por segundo.** No use 4K, porque pesa mucho y no aporta nada.
   Desactive el estabilizador "súper" si hace zoom.
3. **Camine despacio**, a paso normal de una persona con bastón (unos 3 a 4 km/h). Al acercarse a
   un obstáculo, deténgase 2 segundos a unos 5 m, luego a 3 m y luego a 1 m. Así quedan imágenes
   de las tres cercanías: lejos, a media distancia y cerca.
4. **Videos cortos**, de 1 a 3 minutos cada uno, con un nombre por lugar, por ejemplo
   `centro-carrera25.mp4` o `parque-narino.mp4`. Los videos cortos son más fáciles de revisar y de
   repartir entre entrenamiento y prueba.
5. **Varíe la luz.** Grabe en la mañana, al mediodía, en la tarde nublada y, si es posible, con la
   calle mojada. En Pasto llueve mucho, y el modelo debe funcionar así.

## 3. Qué grabar (las 13 clases)

Lo más importante son las 6 clases nuevas, porque el modelo base de COCO no las conoce:

| Clase | En español | Ejemplos en Pasto | Meta de imágenes de prueba |
|---|---|---|---|
| `pole` | Poste | Postes de luz y de teléfono, señales verticales | 40 a 50 |
| `bollard` | Bolardo | Bolardos del centro y de la Plaza de Nariño | 30 a 40 |
| `traffic_cone` | Cono | Conos de obra y de tránsito | 30 a 40 |
| `step` | Escalón | Bordillos, escalones de andén, rampas con desnivel | 40 a 50 |
| `pothole` | Hueco | Huecos en andenes y calles, sumideros sin tapa | 40 a 50 |
| `construction` | Obra | Vallas, cintas, zanjas, materiales en el andén | 30 a 40 |

Las clases comunes (persona, bicicleta, automóvil, motocicleta, bus, camión y perro) aparecen
solas en cualquier calle. Basta con unas 20 a 30 imágenes de cada una.

Lugares recomendados:

- El centro: carreras 24 a 27 entre calles 16 y 20.
- Los alrededores de la Plaza de Nariño.
- La avenida Panamericana, con andenes anchos y obras.
- Un barrio con andenes en mal estado.
- Los alrededores de la Universidad Cooperativa.

## 4. Seguridad y privacidad

- **Su seguridad primero.** No grabe cruzando la calle ni de noche en lugares solos. Si va con
  el teléfono en la mano, guárdelo al cruzar.
- **No grabe a nadie de cerca a propósito.** Si una persona sale de cerca en un cuadro, el script
  difumina las caras con `--blur-faces`. Revise igual las imágenes y borre las que muestren
  placas de vehículos legibles o caras sin difuminar. Así se cumple la Ley 1581 de 2012 de
  protección de datos personales.
- No suba los videos originales a ningún sitio público. Suba solo los cuadros ya revisados.

## 5. Del video a las imágenes

En su computador, una sola vez:

```powershell
cd C:\dev\eyesight-ai\ml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install opencv-python-headless numpy
```

Copie los videos del teléfono a `C:\dev\eyesight-ai\ml\videos\`. Esa carpeta no se sube a GitHub;
vea el paso 7. Luego, por cada lugar:

```powershell
python scripts\extract_frames.py --videos videos\centro-*.mp4 --place centro --output datasets\pasto\centro --blur-faces
```

- El script guarda **1 cuadro por segundo** y descarta los movidos. Un minuto de video produce
  unas 50 imágenes útiles.
- Si quedan muchas imágenes movidas, suba el umbral con `--min-sharpness 100`. Si descarta
  demasiadas, bájelo a `40`.
- Para tener más cuadros cerca de los obstáculos, use `--every 0.5`.

Después **revise las imágenes** y borre las que no tengan ningún obstáculo útil o las repetidas.
Con 300 a 400 imágenes en total es suficiente.

## 6. Etiquetar en Roboflow (gratis)

1. Cree una cuenta en `https://roboflow.com` y un proyecto **Object Detection** llamado
   `eyesight-pasto`.
2. Suba las imágenes de `datasets\pasto\`.
3. Etiquete con **cajas** usando exactamente estos nombres en inglés: `person`, `bicycle`, `car`,
   `motorcycle`, `bus`, `truck`, `dog`, `pole`, `bollard`, `traffic_cone`, `step`, `pothole`,
   `construction`.
   - La caja debe ajustarse al objeto, sin dejar mucho borde.
   - En un escalón o un hueco, encierre solo el desnivel o el hueco visible.
   - Si un objeto está tapado más de la mitad, no lo etiquete.
4. Al generar la versión, **no** aplique aumentos (*augmentations*) a este proyecto, porque es
   el conjunto de prueba. Póngalo todo en **Test** (100 % test).
5. Exporte en formato **YOLOv8** y descargue el zip.

> El etiquetado asistido de Roboflow (*Label Assist*) puede proponer cajas para las clases
> comunes. Revise cada una antes de aceptarla.

## 7. Qué subir a GitHub y qué no

- **No** suba los videos ni las imágenes. Pesan mucho y tienen datos personales.
- Sí puede subir un archivo de texto con cuántas imágenes y cajas hay por clase. El script
  `evaluate.py` lo genera para el informe.
- El `.gitignore` ya excluye `ml/videos/`, `ml/datasets/` y `ml/.venv/`.

## 8. Cómo se usa en la evaluación

En Google Colab (cuaderno `ml/notebooks/EyeSight_entrenamiento.ipynb`):

1. Se entrena con los conjuntos públicos de Roboflow (pasos 1 y 2 del cuaderno).
2. Se sube el zip de `eyesight-pasto` como conjunto de prueba.
3. `evaluate.py` compara el modelo base (COCO) con el modelo ajustado en **las mismas imágenes de
   Pasto**. Calcula precisión, recall, F1 y mAP@0,5 por clase, y la prueba de hipótesis con
   bootstrap pareado (numeral 2.3).
4. Esos resultados reales reemplazan los valores esperados del capítulo 4 del informe.

## 9. Lista rápida para el día de grabación

- [ ] Teléfono cargado y con espacio; 1080p a 30 fps
- [ ] Arnés o cinta de pecho; cámara en vertical, al frente y un poco hacia abajo
- [ ] Paradas a 5 m, 3 m y 1 m de cada obstáculo nuevo
- [ ] Al menos dos condiciones de luz (soleado y nublado o mojado)
- [ ] Videos cortos con el nombre del lugar
- [ ] Al volver: copiar a `ml\videos\`, extraer, revisar y borrar las imágenes con datos personales
