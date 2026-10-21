# Registro de decisiones de diseño (ADR)

Este documento reúne las decisiones de arquitectura de EyeSight AI, con su contexto, las
alternativas consideradas y sus consecuencias. Sirve de base para los capítulos 3 y 4 del informe
y para la sustentación.

| # | Decisión | Estado |
|---|---|---|
| 1 | Arquitectura local-first: sin servidor ni nube | Aceptada |
| 2 | Base de datos local Hive cifrada con AES-256 y clave en el Android Keystore | Aceptada |
| 3 | No usar una base de datos en la nube (por ejemplo, Neon) | Aceptada; trabajo futuro |
| 4 | Copia de seguridad de zonas por texto cifrado, sin servidor | Aceptada |
| 5 | El desarrollador no tiene acceso a los datos de los usuarios | Aceptada |
| 6 | Mapa con OpenStreetMap y no Google Maps | Aceptada |
| 7 | Despliegue: GitHub Releases y GitHub Pages; Google Play como fase siguiente | Aceptada |
| 8 | Cámara USB: interfaz lista, componente nativo como trabajo futuro | Aceptada |
| 9 | Monolito modular con contratos (interfaces), sin microservicios | Aceptada |
| 10 | Rendimiento: modelo INT8 e hilos configurables | Aceptada |
| 11 | Reconocimiento de voz del sistema con respaldo en botones y gestos | Aceptada |
| 12 | Levantamiento de requisitos por revisión documental y validación posterior con usuarios | Aceptada |

---

## ADR-1. Arquitectura local-first, sin servidor

**Contexto.**
- La herramienta acompaña a una persona con discapacidad visual en la calle, donde la conexión
  puede fallar.
- Los datos que maneja son sensibles: la ubicación diaria de la persona y los lugares que
  frecuenta.

**Decisión.** Todo se procesa y se guarda en el teléfono:
- la detección con YOLOv8n en LiteRT;
- la voz y la vibración;
- las zonas de riesgo y el historial.

No hay servidor, cuentas ni base de datos central. Este patrón se conoce como *local-first* u
*offline-first*, y aplica la **privacidad por diseño**.

**Consecuencias.**

| Ventajas | Costos |
|---|---|
| Funciona sin internet (RNF04) | Las zonas no se comparten automáticamente entre teléfonos (mitigado en el ADR-4) |
| La ubicación nunca sale del teléfono | Sin respaldo automático: si se pierde el teléfono o se desinstala la app, se pierden los datos (mitigado en el ADR-4) |
| Costo de operación: cero | |
| Escala sola: 2000 usuarios son 2000 teléfonos independientes; no hay un servidor que se sature | |
| Riesgo legal mínimo: no se crea una base de datos con datos personales (Ley 1581 de 2012) | |

**Respuesta a «¿y el hosting?».**
- En una aplicación cliente-servidor, el *hosting* es el servidor que recibe las peticiones, y su
  capacidad limita a cuántos usuarios atiende a la vez.
- En EyeSight AI no existe ese servidor: cada instalación es un sistema de información local y
  autónomo.
- El único «hosting» es el de distribución: Google Play o GitHub Releases para la app, y GitHub
  Pages para la página web. Esos servicios ya están preparados para tráfico masivo.

## ADR-2. Base de datos local: Hive cifrado

**Decisión.**
- Hive, una base de datos NoSQL clave-valor embebida, con cuatro colecciones: zonas, historial,
  ajustes y registro de cambios.
- Están cifradas con AES-256.
- La clave se genera al azar y se guarda en el **Android Keystore**, a través de
  `flutter_secure_storage`.
- El PIN no se guarda: se guarda su resumen PBKDF2-HMAC-SHA256 con sal.

**Tamaño de los datos.** El límite real es la memoria de cada teléfono, y es más que suficiente:

| Dato | Tamaño aproximado |
|---|---|
| Una zona de riesgo | 150 a 300 bytes |
| Una alerta del historial | Unos 100 bytes |
| 1000 zonas | Unos 300 KB |
| 90 días de historial con uso intensivo (≈ 200 alertas/día) | Unos 2 MB |
| Modelo de IA (dentro del APK) | 12,7 MB en float32; unos 3,5 MB en INT8 |

El historial se borra solo después de 90 días (HU12, CA4), así que la base no crece sin límite.

**¿Es una mala práctica?** No. Lo sería guardar en un servidor, sin necesidad, datos de ubicación
de personas con discapacidad. Las aplicaciones de IA en el dispositivo (*Edge AI*) siguen este
mismo patrón.

## ADR-3. Sin base de datos en la nube (por ejemplo, Neon)

**Alternativa evaluada.** PostgreSQL gratuito en Neon, para sincronizar zonas entre usuarios.

**Por qué no, en esta fase:**
1. **Exige un servidor intermedio (API).** La app no puede conectarse directo a la base, porque la
   contraseña quedaría dentro del APK y cualquiera podría extraerla. Es exactamente la falla de
   claves filtradas que se corrigió frente a la versión preliminar.
2. **Exige cuentas de usuario** y su seguridad: registro, contraseñas y recuperación.
3. **Convierte al proyecto en responsable del tratamiento** de datos personales sensibles, con las
   obligaciones de la Ley 1581 de 2012: autorización, políticas y registro.
4. **Hay que sincronizar** para seguir funcionando sin conexión, lo cual es complejo.
5. **Los planes gratuitos tienen límites** de uso y suspenden la base por inactividad.

**Trabajo futuro.** Un servicio opcional y anónimo para compartir zonas de riesgo con la
comunidad, con consentimiento explícito.

## ADR-4. Copia de seguridad de zonas sin servidor

**Decisión.** En Privacidad, «Exportar zonas» genera un **texto cifrado** que el acompañante
comparte por WhatsApp, correo o notas. «Importar zonas» lo pega en otro teléfono:
- Formato `EYESIGHT-ZONAS-1`.
- La clave se deriva de una contraseña elegida por el acompañante: PBKDF2-HMAC-SHA256 con
  100 000 iteraciones y sal aleatoria.
- Los datos se cifran con AES-256-CBC y se autentican con HMAC-SHA256 (cifrar y luego autenticar).
  Una contraseña incorrecta o un texto alterado se rechazan.
- Al importar se omiten las zonas que ya existen y las inválidas, y cada zona agregada queda en el
  registro de cambios.

**Consecuencia.** Cubre el respaldo y el traspaso de zonas al acompañante sin nube ni cuentas.

## ADR-5. El desarrollador no accede a los datos

Los datos de cada persona solo existen, cifrados, en su teléfono. La app no envía datos
personales, así que no hay tráfico que monitorear ni panel de administración. El desarrollador
solo distribuye actualizaciones. Esto es intencional: protege a los usuarios y simplifica el
cumplimiento legal.

## ADR-6. OpenStreetMap y no Google Maps

| Criterio | OpenStreetMap con `flutter_map` | Google Maps SDK |
|---|---|---|
| Clave de API | No | Sí, con cuenta de facturación y tarjeta |
| Privacidad | Solo se piden imágenes del plano | Envía datos de uso a Google |
| Costo | Libre (licencia ODbL) | Gratis hasta ciertos límites, con riesgo de cobro |
| Cobertura en Pasto | Calles y nombres completos | Completa |

**Limitación.** El servidor público de teselas de OpenStreetMap no está hecho para tráfico
masivo. Con muchos usuarios, se cambia a un proveedor con plan gratuito o comercial, como MapTiler
o Stadia, modificando una línea (`urlTemplate`).

Se muestra el crédito «© OpenStreetMap contributors» que exige la licencia. Sin internet, el plano
no carga, pero las zonas y la lista sí (HU10, CA2).

## ADR-7. Despliegue

**Qué es el despliegue en este proyecto.** Desplegar es poner el software en su entorno de
producción, donde los usuarios lo usan. En una aplicación cliente-servidor, ese entorno es un
servidor. En EyeSight AI, que es local-first (ADR-1), el entorno de producción es **el teléfono
de cada usuario**. El despliegue consiste en compilar, firmar, versionar y distribuir el APK, y
publicar el sitio web que lo acompaña.

**Despliegue realizado (versión 1.0.0, 21 de octubre de 2026):**

| Paso | Cómo se hizo |
|---|---|
| Compilación de producción | `flutter build apk --release --obfuscate --split-debug-info`: código Dart ofuscado y R8 para Java/Kotlin |
| Firma | Clave RSA de 2048 bits propia (`upload`), guardada fuera del repositorio; esquema APK Signature v2 verificado con `apksigner` |
| Versionado | Etiqueta Git `v1.0.0` y `version: 1.0.0+1` en `pubspec.yaml` |
| Distribución del APK | GitHub Releases: `https://github.com/dramirezdlp99/eyesight-ai/releases/latest/download/EyeSight-AI.apk` |
| Sitio web | GitHub Pages (`https://dramirezdlp99.github.io/eyesight-ai/`), publicado automáticamente por GitHub Actions en cada cambio de `website/` |
| Integración continua | GitHub Actions ejecuta formato, análisis estático y pruebas en cada *push* |
| Verificación | Instalación desde la página en el vivo Y22s |

**Diagrama de despliegue (nodos):**
- **Teléfono Android 8.0 o superior** (dispositivo). Contiene el artefacto `EyeSight-AI.apk`, que
  incluye:
  - la app Flutter;
  - el modelo YOLOv8n en LiteRT;
  - Hive cifrado, con la clave en el Android Keystore.

  Usa los servicios del sistema: cámara, GPS, TTS, reconocimiento de voz y vibración.
- **GitHub** (nube):
  - *Releases* aloja el APK;
  - *Pages* aloja el sitio (inicio, privacidad, manual);
  - *Actions* ejecuta el CI y la publicación del sitio.
- **Servidor de teselas de OpenStreetMap** (externo, HTTPS). Solo lo usa el mapa del acompañante.
- **PC del desarrollador.** Compila y firma; guarda la clave y los símbolos de depuración.

**Canales de distribución:**

| Canal | Costo | Estado |
|---|---|---|
| APK en GitHub Releases | Gratis | **Desplegado** (v1.0.0, prototipo en fase de pruebas) |
| Página web en GitHub Pages: presentación, política de privacidad y manual | Gratis | **Desplegado** |
| Google Play | USD 25, un solo pago | Fase siguiente |

Requisitos de Google Play:
- prueba cerrada con 12 testers durante 14 días;
- formato AAB;
- política de privacidad con URL pública (ya disponible);
- formulario de seguridad de los datos.

El AAB permite que Play entregue a cada teléfono solo el código de su procesador. El APK universal
pesa 83,6 MB; el AAB, unos 30 MB por dispositivo.

## ADR-8. Cámara USB

La interfaz `IVideoSource` y el selector con respaldo en la cámara del teléfono están
implementados y probados (HU13, CA3; RNF05). El componente nativo UVC para cámaras USB no se
implementó, por dos razones: no hay hardware para probarlo, y entregar código no verificado sería
un riesgo.

**Trabajo futuro:** implementar `UsbCameraSource` con una biblioteca UVC nativa. La prueba CP-07
queda parcial: se ejecuta la pérdida de GPS, y la desconexión USB queda pendiente de hardware.

## ADR-9. Monolito modular con contratos, sin microservicios

Se evaluaron Contract-First, SSOT, tRPC, GraphQL y gRPC. Sin servidor, los microservicios no
aportan nada. Los mismos principios se aplican dentro de la app:

- **Contratos:** interfaces como `IObstacleDetector`, `IVideoSource`, `IZoneRepository`,
  `ISpeechService` e `IFileExporter`.
- **Fuente única de verdad:** `AppConstants`, `ObstacleCatalog` y `AppSettings`.
- **Validación en el borde:** `InputValidators`.
- **Tipado estricto:** `strict-casts` y `strict-raw-types`.

## ADR-10. Rendimiento del modelo

**Medición real** (CP-02, vivo Y22s, YOLOv8n COCO en float32, 4 hilos):
- inferencia media de 202 ms;
- 4,2 cuadros por segundo;
- captura a alerta media de 226 ms.

RNF02 se cumple; RNF01 y RNF03 no.

**Decisiones:**
1. El modelo de producción se exporta en **INT8**, que suele ser de 2 a 3 veces más rápido en CPU
   móvil.
2. Los **hilos del procesador son configurables** (2, 4 o 6) desde el modo de pruebas, para elegir
   el valor más rápido en cada teléfono. El escáner usa ese mismo valor.
3. Si aun así no se alcanza la meta en un teléfono de gama baja, se reporta tal cual, con la
   explicación del hardware.

## ADR-11. Voz sin conexión

El reconocimiento de voz de Android necesita internet, salvo que el teléfono tenga el paquete de
español sin conexión. Cuando no está disponible, la app lo anuncia y mantiene todas las acciones
en botones (baja visión) y gestos (ceguera total). Es la tolerancia a fallos de RNF05. La síntesis
de voz (TTS) sí funciona sin conexión.

## ADR-12. Levantamiento y validación de requisitos

Los requisitos (HU01 a HU15, RF y RNF) se derivaron de cuatro fuentes:
- la revisión de literatura sobre movilidad de personas con discapacidad visual;
- el análisis de soluciones existentes (Seeing AI, Lazarillo, Be My Eyes);
- las normas WCAG 2.1 e ISO/IEC 25010;
- el criterio del equipo y del director.

Se validan con usuarios y personal de la Fundación Nueva Luz con el prototipo funcional (ver
`docs/kit-validacion.md`). Los comentarios se clasifican como crítico, mejora pequeña, trabajo
futuro o ya cubierto, y se reportan con su decisión.
