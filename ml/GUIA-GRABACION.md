# Guía de grabación en Pasto (versión definitiva)

Los videos de Pasto cumplen dos funciones:

1. **Entrenar.** El modelo ya aprende de miles de fotos públicas de Roboflow. Con las imágenes de
   Pasto, además, se acostumbra a cómo se ven los andenes, postes, gradas y huecos de la ciudad:
   su luz, sus colores y sus materiales.
2. **Evaluar.** Se mide qué tan bien funciona en Pasto con objetos que el modelo **nunca vio**
   (objetivo específico 3, caso de prueba CP-01). Esos son los resultados del capítulo 4 del
   informe.

## 1. La regla más importante: separar por sector

Evaluar un modelo con imágenes que ya vio al entrenar es como darle a un estudiante las mismas
preguntas del examen para que estudie: saca 5,0 sin haber aprendido. Esto se llama **fuga de
datos**, e infla los resultados.

Dos cuadros seguidos de un mismo video son casi idénticos. Por eso **no** se reparten cuadros
sueltos entre entrenamiento y prueba. Se reparten **sectores completos**:

| Conjunto | Sectores | Parte del total | Para qué |
|---|---|---|---|
| Entrenamiento | 2 o 3 sectores, por ejemplo su barrio y dos barrios cercanos | 70 a 75 % | El modelo aprende de ellos |
| Prueba | 1 sector distinto, por ejemplo los alrededores de la universidad o el centro | 25 a 30 % | Se mide el modelo; nunca se usa para entrenar |

Elija para la prueba un sector donde haya **de todo**: postes, gradas, huecos, bolardos o conos,
y alguna obra. Así hay resultados para todas las clases.

## 2. Qué necesita

- El teléfono con al menos 8 GB libres.
- Una cinta o arnés de pecho para celular (unos $25.000 a $40.000). Si no tiene, sostenga el
  teléfono con las dos manos contra el pecho.
- De 3 a 5 salidas de unos 30 a 40 minutos, en días y horas distintas.
- Opcional, pero recomendado: otra persona que camine a su lado.

## 3. Cómo grabar

1. **Altura del pecho y en vertical**, como se usará la app: a unos 1,2 a 1,4 m del suelo,
   apuntando al frente y un poco hacia abajo, de modo que el suelo ocupe la mitad inferior de la
   imagen.
2. **1080p a 30 cuadros por segundo.** No use 4K.
3. **Camine despacio**, unos 3 a 4 km/h. Al acercarse a un obstáculo, deténgase 2 segundos a
   unos 5 m, luego a 3 m y luego a 1 m. Así quedan imágenes lejos, a media distancia y cerca.
4. **Videos de 1 a 3 minutos**, cada uno nombrado con su sector y un número:
   `barrio-1.mp4`, `barrio-2.mp4`, `universidad-1.mp4`.
5. **En total, 30 a 40 minutos de video**, repartidos según la tabla del punto 1.

### Horarios y luz

| Momento | Proporción aproximada | Por qué |
|---|---|---|
| Mañana | 1 de cada 3 videos | Luz suave y sombras largas |
| Mediodía con sol | 1 de cada 3 videos | Sombras duras que confunden al modelo |
| Tarde nublada o con piso mojado | 1 de cada 4 videos | Así es Pasto buena parte del año |
| Noche, en calles iluminadas | 1 de cada 5 videos como máximo | La cámara pierde detalle; en el informe se reporta aparte |

Haga que **el sector de prueba también tenga varias luces**, no solo un horario.

### Variedad: lo que más ayuda

- **Muchos objetos distintos de cada clase**:
  - gradas de varias casas, de concreto, de baldosa, altas y bajas;
  - postes de luz, de teléfono y de señales;
  - huecos grandes, pequeños, secos y con agua.
- **No grabe el mismo objeto muchas veces.** Diez tomas de la misma grada no enseñan nada nuevo.
  Pase una vez, con las tres paradas, y siga.
- **Puede grabar cerca de su casa** y por donde más anda. Lo que importa es la variedad, no la
  distancia.

## 4. Qué grabar: las 13 clases y cuántas imágenes buscar

Las 6 clases nuevas son las más importantes, porque el modelo base de COCO no las conoce:

| Clase | En español | Ejemplos | Entrenamiento | Prueba |
|---|---|---|---|---|
| `pole` | Poste | Postes de luz, de teléfono, señales verticales | 60 a 80 | 30 a 40 |
| `bollard` | Bolardo | Bolardos de andén y de plazas | 40 a 60 | 20 a 30 |
| `traffic_cone` | Cono | Conos de obra y de tránsito | 40 a 60 | 20 a 30 |
| `step` | Escalón | Gradas, bordillos, desniveles del andén | 60 a 80 | 30 a 40 |
| `pothole` | Hueco | Huecos en andén y calle, sumideros sin tapa | 60 a 80 | 30 a 40 |
| `construction` | Obra | Vallas, cintas, zanjas, materiales en el andén | 40 a 60 | 20 a 30 |

Las cantidades son de **imágenes donde aparece la clase**. Las clases comunes (persona,
bicicleta, automóvil, motocicleta, bus, camión y perro) salen solas en cualquier calle; con 20 a
40 imágenes de cada una basta.

En total quedarán unas **600 a 800 imágenes** revisadas: unas 450 a 550 para entrenar y unas
150 a 250 para la prueba.

## 5. Seguridad y privacidad

- **Su seguridad primero.** No grabe cruzando la calle ni en lugares solos de noche.
- **No grabe a nadie de cerca a propósito.** El script difumina las caras (`--blur-faces`).
  Revise igual las imágenes y borre las que tengan caras sin difuminar o placas legibles. Así se
  cumple la Ley 1581 de 2012 de protección de datos personales.
- En el plan gratuito de Roboflow los proyectos son **públicos**. Por eso solo se suben imágenes
  ya revisadas, nunca los videos.
- El `.gitignore` excluye `ml/videos/`, `ml/datasets/` y `ml/.venv/`: nada de esto llega a
  GitHub.

## 6. Del video a las imágenes

Una sola vez, en PowerShell:

```powershell
cd C:\dev\eyesight-ai\ml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install opencv-python-headless numpy
```

Copie los videos del teléfono a `C:\dev\eyesight-ai\ml\videos\`. Luego extraiga **cada sector en
su propia carpeta**:

```powershell
python scripts\extract_frames.py --videos videos\barrio-*.mp4 --place barrio --output datasets\pasto\entrenamiento\barrio --blur-faces
python scripts\extract_frames.py --videos videos\otro-*.mp4 --place otro --output datasets\pasto\entrenamiento\otro --blur-faces
python scripts\extract_frames.py --videos videos\universidad-*.mp4 --place universidad --output datasets\pasto\prueba --blur-faces
```

- Guarda **1 cuadro por segundo** y descarta los movidos.
- Si quedan muchas imágenes movidas, use `--min-sharpness 100`. Si descarta demasiadas, use `40`.
- Para tener más cuadros cerca de los obstáculos, use `--every 0.5`.

Después **revise las imágenes**. Borre las que no tengan ningún obstáculo, las casi repetidas y
las que tengan datos personales.

## 7. Etiquetar en Roboflow: dos proyectos

Cree una cuenta en `https://roboflow.com` y **dos** proyectos de tipo **Object Detection**:

| Proyecto | Qué subir | Partición al generar la versión |
|---|---|---|
| `eyesight-pasto-entrenamiento` | `datasets\pasto\entrenamiento\` | 85 % Train, 15 % Valid, 0 % Test |
| `eyesight-pasto-prueba` | `datasets\pasto\prueba\` | 100 % Test |

En los dos proyectos:

1. Etiquete con **cajas** usando exactamente estos nombres en inglés:

   ```
   person  bicycle  car  motorcycle  bus  truck  dog
   pole  bollard  traffic_cone  step  pothole  construction
   ```

   - La caja se ajusta al objeto, sin mucho borde.
   - En un escalón o un hueco, encierre solo el desnivel o el hueco visible.
   - Si el objeto está tapado más de la mitad, no lo etiquete.
   - El *Label Assist* de Roboflow puede proponer cajas para personas y vehículos. Revise cada
     una antes de aceptarla.
2. Al generar la versión:
   - En el proyecto de **prueba**, no active aumentos (*augmentations*).
   - En el de **entrenamiento**, puede activar «Flip: Horizontal» y «Brightness ±20 %».
3. Para descargarlos, use **Download Dataset → YOLOv8 → show download code** y anote el
   `workspace`, el nombre del proyecto y la versión de cada uno.

Puede repartir el etiquetado en varios días: Roboflow guarda el avance. Calcule unas 4 a 6 horas
en total.

## 8. Entrenar y evaluar en Google Colab

Abra `ml/notebooks/EyeSight_entrenamiento.ipynb` en Colab, con GPU T4.

1. En el paso 2 del cuaderno:
   - En `FUENTES` van los conjuntos públicos y `eyesight-pasto-entrenamiento`.
   - En `PRUEBA_PASTO` va `eyesight-pasto-prueba`. Se descarga aparte, para que nunca se mezcle
     con el entrenamiento.
2. Ejecute todas las celdas. El entrenamiento tarda de 1 a 3 horas.
3. La carpeta `results_pasto` trae los resultados del informe, en dos niveles:
   - **Nivel objeto**:
     - la matriz de confusión con la clase «fondo»;
     - precisión, recall y F1;
     - AP@0,5, AP@0,5:0,95 e IoU medio.
   - **Nivel imagen**: exactitud, precisión, recall, F1, especificidad y AUC-ROC por clase, con
     su curva ROC.
   - **Umbral de confianza**: la F1 según el umbral y el umbral recomendado para la app.
   - **Hipótesis**: la comparación entre el modelo base y el ajustado, con bootstrap pareado.
4. Descargue el zip del final y envíelo para escribir el capítulo 4.

## 9. Lista para cada día de grabación

- [ ] Teléfono cargado y con espacio; 1080p a 30 fps
- [ ] Cámara en el pecho, vertical, al frente y un poco hacia abajo
- [ ] Paradas a 5 m, 3 m y 1 m de cada obstáculo nuevo, una sola vez por objeto
- [ ] Anotar el horario y la luz de cada video
- [ ] Nombre de cada video con su sector: `sector-número.mp4`
- [ ] Al volver:
  - copiar los videos a `ml\videos\`;
  - extraer cada sector en su carpeta;
  - revisar y borrar las imágenes con datos personales.
