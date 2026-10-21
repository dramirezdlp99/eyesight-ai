# Política de privacidad de EyeSight AI

Última actualización: 21 de octubre de 2026.

EyeSight AI es una aplicación Android de apoyo a la movilidad de personas con discapacidad
visual, desarrollada como trabajo de grado de Ingeniería de Software en la Universidad
Cooperativa de Colombia, sede Pasto.

Esta política explica qué datos usa la aplicación y cómo los protege, conforme a la Ley 1581 de
2012 y el Decreto 1377 de 2013.

## Resumen

- **No recopilamos sus datos.** La aplicación no tiene servidores, cuentas ni base de datos en la
  nube.
- Todo se procesa y se guarda **en su teléfono**, cifrado con AES-256.
- **Nadie más puede ver su información**, ni siquiera el desarrollador.
- **No hay publicidad, analítica ni rastreadores.**

## Datos que usa la aplicación y dónde quedan

| Dato | Para qué | Dónde queda | ¿Sale del teléfono? |
|---|---|---|---|
| Imágenes de la cámara | Detectar obstáculos con el modelo de inteligencia artificial | Solo en la memoria, mientras se analizan; no se guardan | No |
| Audio del micrófono | Reconocer los comandos de voz | Lo procesa el servicio de reconocimiento de voz de Android | Depende de Android (ver abajo) |
| Ubicación (GPS) | Avisar las zonas de riesgo y registrar las nuevas | Base de datos cifrada en el teléfono | No |
| Zonas de riesgo | Avisar lugares peligrosos | Base de datos cifrada en el teléfono | Solo si usted las exporta |
| Historial de alertas | Que el acompañante vea las alertas recientes | Base de datos cifrada; se borra a los 90 días | No |
| Ajustes y PIN | Personalizar la app y proteger el perfil de acompañante | Teléfono; el PIN se guarda como resumen irreversible (PBKDF2) | No |

## Servicios de terceros

- **Reconocimiento de voz de Android (Google).** Si su teléfono no tiene el paquete de español
  sin conexión, Android puede enviar el audio del comando a Google para convertirlo en texto. Se
  rige por la política de privacidad de Google. Si instala el paquete sin conexión, el audio no
  sale del teléfono. También puede usar botones y gestos en lugar de la voz.
- **Mapas de OpenStreetMap.** En el perfil de acompañante, el mapa descarga las imágenes del
  plano desde los servidores de OpenStreetMap, que reciben la dirección IP y la zona del mapa
  solicitada, como ocurre con cualquier página web. Las zonas de riesgo **no** se envían. Se rige
  por la [política de privacidad de la Fundación OpenStreetMap](https://osmfoundation.org/wiki/Privacy_Policy).

## Exportación de zonas

El acompañante puede exportar las zonas como un texto cifrado con una contraseña que él mismo
elige (AES-256 y HMAC-SHA256). Ese texto solo se comparte si usted lo envía, por ejemplo por
WhatsApp o por correo. Sin la contraseña, el contenido no se puede leer.

## Modo de pruebas

El modo de pruebas, de uso del investigador, exporta un archivo CSV con tiempos de respuesta y
detecciones. Por defecto **no** incluye coordenadas, y solo se comparte si el investigador lo
envía.

## Sus derechos

Usted puede conocer, actualizar y suprimir su información en cualquier momento, desde la propia
aplicación:
- **Ver** cuántos datos hay guardados y qué permisos están activos (Acompañante → Privacidad).
- **Editar o eliminar** cada zona de riesgo.
- **Borrar todo** escribiendo «ELIMINAR»: se borran las zonas, el historial, los ajustes, el PIN y
  la clave de cifrado.
- **Retirar los permisos** desde los ajustes de Android.
- **Desinstalar** la aplicación, lo que elimina todos sus datos.

## Menores de edad

La aplicación no está dirigida específicamente a menores y no recopila datos de ninguna persona.

## Cambios en esta política

Si esta política cambia, se publicará aquí con la nueva fecha de actualización.

## Contacto

Responsable: David Fernando Ramírez de la Parra, Universidad Cooperativa de Colombia, sede Pasto.
Para preguntas, escriba en
<https://github.com/dramirezdlp99/eyesight-ai/issues>.
