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
| 5 | Entrega: firma, ofuscación, APK de producción y manual técnico | RNF15 |

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
NMS; la interfaz solo recibe las cajas. `Probar detección`, en la pantalla del
acompañante, muestra la cámara con las cajas, los cuadros por segundo y los tiempos de
inferencia y de captura a resultado (RNF01 a RNF03).

## Identidad visual y accesibilidad

Diseño propio, sin elementos de terceros: un ojo animado que parpadea y emite ondas
(`lib/presentation/widgets/eye_logo.dart`) y tres temas en `lib/presentation/theme/`:

| Tema | Uso | Colores |
|---|---|---|
| Claro | Ceguera total y acompañante, con el teléfono en modo claro | Azul `#1A4B8C` sobre blanco |
| Oscuro | Los mismos perfiles, con el teléfono en modo oscuro | Azul `#8DB9FF` sobre `#0D141F` |
| Alto contraste | Siempre en el perfil de baja visión (HU05) | Amarillo `#FFD600` sobre negro, texto de 24 sp o más |

Todos los pares de texto y fondo cumplen al menos 4,5:1 (RNF07), verificado por
`test/presentation/theme/app_theme_test.dart`. Con «Quitar animaciones» activado en Android, el
ojo queda quieto.

Al abrir la app por primera vez se anuncian los perfiles por voz y se pueden elegir hablando o con
los botones (HU01). El perfil de acompañante pide crear o ingresar un PIN.

## Escáner (HU02 a HU09)

`ScannerController` une la cámara, el modelo, el filtro de estabilidad, la política de alertas,
la voz, la vibración, el GPS y los comandos. Inicia solo al abrir la app en los perfiles de
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
