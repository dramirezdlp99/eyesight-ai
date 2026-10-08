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
