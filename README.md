# EyeSight AI

Aplicación Android de apoyo a la movilidad autónoma de personas con discapacidad visual en
Pasto, Nariño. Trabajo de grado de Ingeniería de Software, Universidad Cooperativa de Colombia
(autor: David Fernando Ramírez de la Parra; director: PhD Cristian Camilo Ordoñez Quintero).

| | |
|---|---|
| Plataforma | Android 8.0 (API 26) o superior, 2 GB de RAM como mínimo |
| Framework | Flutter (Dart 3), gestión de estado con GetX |
| IA | YOLOv8n (Ultralytics) exportado a LiteRT, ejecutado en el teléfono |
| Datos | Hive cifrado con AES-256, clave en el Android Keystore |
| Conectividad | Ninguna función crítica usa internet; solo el mapa del acompañante descarga teselas de OpenStreetMap |
| Licencia | AGPL-3.0 (software libre, heredada de Ultralytics) |

## Arquitectura

Monolito modular ejecutado en el teléfono (informe, numerales 2.2.5 y 4.3). El código sigue el
diagrama de desarrollo por capas del numeral 4.3.5:

```
lib/
  core/          IA (decodificador YOLO, letterbox), seguridad, métricas, configuración
  domain/        entidades, interfaces de repositorios y reglas de negocio (sin plugins)
  data/          repositorios Hive cifrados
  presentation/  inyección de dependencias (bindings); vistas y controladores GetX (Bloques 3 y 4)
test/            pruebas unitarias, de widgets y con el modelo real
ml/              entrenamiento y exportación del modelo en Python   (Bloque 2)
```

Las reglas del dominio no dependen del teléfono, por lo que cada criterio de aceptación de las
historias de usuario tiene una prueba automática que lo verifica.

## Plan de construcción por bloques

| Bloque | Contenido | Historias |
|---|---|---|
| **0** | Núcleo y dominio: entidades, cercanía, estabilidad, alertas, zonas, comandos de voz, decodificador YOLO, PIN, validaciones y métricas | Lógica de HU01–HU15 |
| 1 | Datos y seguridad: Hive cifrado, Keystore, PIN del acompañante, repositorios, borrado total | HU11, HU12, HU14 |
| 2 | IA en el dispositivo: modelo LiteRT, cámara, hilo aislado, entrenamiento en `ml/` | HU02, HU03 |
| 3 | Usuario final: perfiles, escáner, voz, vibración, comandos, gestos, zonas automáticas y manuales | HU01–HU09 |
| 4 | Acompañante e investigador: mapa, edición, historial, ajustes, privacidad, modo de pruebas | HU10–HU15 |
| 5 | Entrega: copia cifrada de zonas, hilos configurables, vibración reforzada, ícono, firma y ofuscación, página web y documentación | HU10, HU14, HU15, RNF15 |

## Desarrollo local (PowerShell)

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Con un teléfono conectado por USB (depuración USB activada):

```powershell
flutter devices
flutter run
```

## Modelo de visión artificial

`assets/models/` contiene el modelo, sus etiquetas y `model_manifest.json` con su SHA-256. La app
verifica ese resumen antes de ejecutar el modelo y, si no coincide, no lo carga (STRIDE:
manipulación). Hoy se incluye YOLOv8n **preentrenado en COCO** (modelo base de la hipótesis); el
modelo **ajustado e INT8** se produce con `ml/` y se instala con `ml/scripts/export.py`.

La inferencia corre con LiteRT en un hilo aislado que hace la conversión YUV, la inferencia y la
NMS; la interfaz solo recibe las cajas. El **modo de pruebas** (Ajustes → Modo de pruebas)
muestra en vivo los cuadros por segundo y los tiempos de inferencia y de captura a alerta
(RNF01 a RNF03), y exporta cada cuadro a CSV (HU15).

El modelo propio se evalúa con imágenes de Pasto. `ml/GUIA-GRABACION.md` explica cómo grabarlas y
`ml/scripts/extract_frames.py` extrae los cuadros nítidos de los videos.

## Identidad visual y accesibilidad: «Barniz de Pasto»

Diseño propio inspirado en el barniz de Pasto (mopa-mopa) y en las grecas escalonadas de Nariño,
sin elementos de terceros. La base es blanca y sobria, y cada color tiene un solo significado:

| Color | Hex | Significado |
|---|---|---|
| Cobalto | `#2340D9` | Marca y acciones; perfil de ceguera total |
| Carmín | `#D11F3A` | Peligro cercano |
| Oro | `#F2B705` | Atención: media distancia, avisos de zona y perfil de baja visión |
| Esmeralda | `#00875A` | Acompañante y confirmaciones (zona guardada) |
| Tinta | `#17171C` | Texto |

- **Tipografías** (licencia OFL, incluidas en `assets/fonts` para funcionar sin internet):
  Atkinson Hyperlegible Next, creada por el Braille Institute para personas con baja visión,
  para el texto; Bricolage Grotesque para los títulos.
- **Temas** en `lib/presentation/theme/`: claro, oscuro y alto contraste. El de alto contraste se
  usa siempre en el perfil de baja visión (HU05) y pone oro y blanco sobre negro, con texto de
  24 sp o más.
- **Animaciones** en `lib/presentation/widgets/`:
  - el ojo del logotipo parpadea y mira a los lados;
  - la greca avanza en la bienvenida;
  - una línea recorre la cámara mientras el modelo analiza;
  - unos puntos laten con los pulsos de vibración;
  - unas ondas acompañan el aviso de zona;
  - una cuenta regresiva marca los 8 s para responder.

  Con «Quitar animaciones» activado en Android, todo queda quieto.
- Todos los pares de texto y fondo cumplen al menos 4,5:1 (RNF07, WCAG 2.1). Lo verifica
  `test/presentation/theme/app_theme_test.dart`. Los botones miden 56 dp o más.
- La app trata al usuario de «usted».

Al abrir la app por primera vez, se anuncian los perfiles por voz y se pueden elegir hablando o
con las tarjetas (HU01). El perfil de acompañante pide crear o ingresar un PIN.

## Escáner (HU02 a HU09)

`ScannerController` une la cámara, el modelo, el filtro de estabilidad, la política de alertas,
el `AlertManager` (voz y vibración), el GPS y los comandos. La pantalla muestra la cámara con las
cajas detectadas, la tarjeta de la última alerta con el color de su cercanía, el aviso de zona y
el resumen de la sesión al detenerse. Inicia solo al abrir la app en los perfiles de
usuario final, anuncia «Escáner activo» y recuerda que la herramienta complementa el bastón
(RNF16).

| Acción | Voz | Gesto (ceguera total) | Botón (baja visión) |
|---|---|---|---|
| Repetir la última alerta | «repetir» | Doble toque | Repetir |
| Silenciar la voz 10 s (lo cercano sigue vibrando) | «silencio» | Deslizar a un lado | Silenciar |
| Marcar una zona de riesgo | «marcar zona» | Mantener presionado 2 s | Marcar zona |
| Terminar (pide confirmación) | «terminar» y luego «sí» | — | Terminar |

Con TalkBack activo, las mismas acciones están en el menú de acciones del área del escáner.
Las alertas siguen el formato «Poste, cerca, al frente» y vibran con 3, 2 o 1 pulsos según la
cercanía; las zonas registradas avisan con un pulso largo y «Atención: hueco a 15 metros».
Los obstáculos fijos peligrosos que se detectan cerca, con GPS de 20 m o mejor, se registran
como zonas automáticas, y cada alerta queda en el historial cifrado.

## Acompañante (HU10 a HU15)

Después del PIN, el acompañante tiene cuatro pestañas:

| Pestaña | Qué hace | Historia |
|---|---|---|
| Mapa | Zonas en un mapa de OpenStreetMap y en una lista filtrable por origen; tocar una zona la edita (tipo, radio, nota) o la elimina | HU10, HU11 |
| Historial | Alertas por fecha (hoy, 7 días, 30 días, todo) y tipo, con la gráfica de la semana; se borran solas a los 90 días | HU12 |
| Ajustes | Velocidad y volumen de la voz con frase de ejemplo, vibración, zonas automáticas, radio, confianza mínima, cámara y modo de pruebas | HU13, HU15 |
| Privacidad | Datos guardados, permisos, cambio de PIN, copia de seguridad cifrada de zonas (exportar e importar) y borrado total escribiendo «ELIMINAR» | HU14 |

Sin internet todo funciona; solo el plano del mapa no carga (HU10, CA2). El modo de pruebas
registra cada cuadro con el caso de prueba (CP-02 a CP-07) y la etiqueta real elegida por el
investigador, y exporta el CSV sin coordenadas salvo que se activen (HU15).

## Pruebas

`flutter test` ejecuta las pruebas de todas las capas. La prueba
`test/core/ai/yolo_decoder_test.dart` decodifica una salida real de YOLOv8n (imagen `bus.jpg` de
Ultralytics) y compara el resultado con una referencia calculada en Python con LiteRT, de modo
que el decodificador de la aplicación queda verificado contra el modelo real.

## Seguridad (módulo `lib/core/security`, informe numeral 4.3.7)

| Componente | Función | Amenaza STRIDE |
|---|---|---|
| `SecureKeyService` | Genera la clave AES-256 y la guarda en el Android Keystore | Divulgación |
| `EncryptedStorage` | Abre las colecciones de Hive cifradas con esa clave | Divulgación, manipulación |
| `PinGuard` | PIN del acompañante con PBKDF2 y bloqueo de 60 s tras 5 fallos | Suplantación |
| `DataWipeService` | Borra colecciones, clave y PIN | Divulgación |
| `AuditRepository` | Registra creación, edición y eliminación de zonas | Repudio |
| `AndroidManifest.xml` | Sin copia de seguridad, sin tráfico HTTP, permisos mínimos | Divulgación, elevación de privilegios |

- Sin claves de API, sin archivos `.env` y sin servidores.
- Las claves de firma (`*.jks`, `key.properties`) están excluidas del repositorio.
- El PIN del acompañante se guarda como resumen PBKDF2-HMAC-SHA256 con sal.
- Las exportaciones CSV neutralizan fórmulas de hoja de cálculo.
- La copia de zonas se cifra con AES-256-CBC y se autentica con HMAC-SHA256; la clave sale de
  una contraseña del acompañante (PBKDF2, 100 000 iteraciones). Lo hace `ZoneBackup`.

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/decisiones-de-diseno.md`](docs/decisiones-de-diseno.md) | Decisiones de arquitectura: local-first, Hive, por qué no hay nube, OpenStreetMap, despliegue, cámara USB y rendimiento |
| [`docs/manual-de-usuario.md`](docs/manual-de-usuario.md) | Manual para usuarios y acompañantes |
| [`docs/politica-de-privacidad.md`](docs/politica-de-privacidad.md) | Política de privacidad (Ley 1581 de 2012) |
| [`docs/resultados-pruebas.md`](docs/resultados-pruebas.md) | Resultados medidos en el teléfono (CP-02, CP-04) |
| [`docs/kit-validacion.md`](docs/kit-validacion.md) | Guion, tareas, SUS y clasificación de comentarios para la validación con usuarios |
| [`docs/publicacion.md`](docs/publicacion.md) | Firma, APK de producción, GitHub Releases, GitHub Pages y Google Play |

## Página web y descarga

- Página: <https://dramirezdlp99.github.io/eyesight-ai/> (carpeta `website/`, publicada por
  `.github/workflows/pages.yml`).
- APK: <https://github.com/dramirezdlp99/eyesight-ai/releases/latest/download/EyeSight-AI.apk>.
- `website/manual.html` y `website/privacidad.html` se generan a partir de los archivos de `docs/`.
  `website/tailwind.css` se compila con
  `npx tailwindcss@3.4.17 -i tailwind.src.css -o tailwind.css --minify` desde `website/`.
