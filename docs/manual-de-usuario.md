# Manual de usuario de EyeSight AI

Versión 1.0.0 · Android 8.0 o superior

EyeSight AI avisa con voz y vibración los obstáculos que tiene al frente: personas, vehículos,
bicicletas, bancas, semáforos y otros. También le avisa cuando se acerca a zonas de riesgo que usted o su
acompañante registraron.

> **Importante.** EyeSight AI complementa el bastón y el perro guía; no los reemplaza. Úsela
> siempre junto con sus ayudas de movilidad habituales.

---

## 1. Instalación

1. Descargue el archivo `EyeSight-AI.apk` desde la página del proyecto:
   <https://dramirezdlp99.github.io/eyesight-ai/>.
2. Ábralo. Si Android lo pide, permita «Instalar aplicaciones desconocidas» para el navegador o
   el gestor de archivos.
3. Toque **Instalar** y luego **Abrir**.

La app pide tres permisos, y cada uno tiene una razón:

| Permiso | Para qué se usa |
|---|---|
| Cámara | Ver los obstáculos. Las imágenes se analizan en el teléfono y no se guardan. |
| Micrófono | Escuchar los comandos de voz. |
| Ubicación | Avisar las zonas de riesgo y guardar las nuevas. La ubicación no sale del teléfono. |

## 2. Elegir el perfil

La primera vez, la app anuncia los perfiles en voz alta. Puede decir el nombre del perfil o tocar
la tarjeta correspondiente:

| Perfil | Para quién | Cómo se controla |
|---|---|---|
| **Ceguera total** | Personas que no ven | Voz y gestos en toda la pantalla |
| **Baja visión** | Personas con resto visual | Botones grandes en alto contraste (amarillo y blanco sobre negro) |
| **Acompañante** | Familiar o cuidador | Mapa, historial, ajustes y privacidad, protegidos con PIN |

La app recuerda el perfil. Para cambiarlo, termine el escáner y toque **Cambiar de perfil** en el
resumen, o use **Cambiar de perfil** en el mapa del acompañante.

## 3. Uso del escáner

Sostenga el teléfono a la altura del pecho, con la cámara trasera mirando hacia adelante. Puede
usar un soporte o un cordón. El escáner arranca solo y dice «Escáner activo».

### Qué significan los avisos

| Cercanía | Voz | Vibración | Color en pantalla |
|---|---|---|---|
| Cerca | «Poste, cerca, al frente» | 3 pulsos fuertes | Rojo |
| Media distancia | «Persona, a media distancia, a la izquierda» | 2 pulsos | Amarillo |
| Lejos | «Banca, lejos, a la derecha» | 1 pulso | Gris |
| Zona de riesgo | «Atención: hueco a 15 metros» | 1 pulso largo | Ondas |

### Comandos

| Acción | Diga | Gesto (ceguera total) | Botón (baja visión) |
|---|---|---|---|
| Repetir la última alerta | «repetir» | Doble toque | Repetir |
| Silenciar la voz 10 segundos | «silencio» | Deslizar a un lado | Silenciar |
| Marcar una zona de riesgo aquí | «marcar zona» | Mantener presionado 2 segundos | Marcar zona |
| Terminar | «terminar» y luego «sí» | — | Terminar |

- Mientras la voz está en silencio, los obstáculos cercanos siguen vibrando.
- Con TalkBack activo, las mismas acciones están en el menú de acciones.

**Sin internet.** El escáner, la voz y la vibración funcionan sin conexión. Los comandos de voz
necesitan el **paquete de español sin conexión** de Google. Para instalarlo, vaya a Ajustes de
Android → Sistema → Idioma → Reconocimiento de voz → Idiomas sin conexión → Español. Si no está
instalado, la app lo anuncia y usted sigue usando gestos o botones.

## 4. Perfil de acompañante

La primera vez, cree un PIN de 4 a 6 dígitos. Si se equivoca 5 veces, la app espera 60 segundos
antes de dejarle intentar otra vez.

### Mapa

- Muestra las zonas de riesgo en un mapa de OpenStreetMap y en una lista:
  - **pin rojo:** zona automática, registrada por la app al detectar un obstáculo fijo cercano;
  - **pin verde:** zona manual, marcada por el usuario o por usted;
  - **punto azul:** su ubicación.
- Filtre la lista con **Todas**, **Automáticas** o **Manuales**.
- Toque una zona para cambiar su tipo, su radio de aviso o su nota, o para eliminarla.
- Sin internet, el plano no carga, pero la lista sí.

### Historial

Muestra las alertas de hoy, de los últimos 7 o 30 días, o todas, filtradas por tipo, con la
gráfica de la semana. Se borran solas a los 90 días.

### Ajustes

Le permite cambiar:
- la velocidad y el volumen de la voz, con una frase de ejemplo;
- la vibración;
- las zonas automáticas y el radio de aviso;
- la confianza mínima del modelo;
- la cámara.

También da acceso al modo de pruebas.

### Privacidad

- **Datos guardados y permisos:** cuántas zonas y alertas hay, y qué permisos están activos.
- **Cambiar PIN.**
- **Copia de seguridad de zonas:**
  - **Exportar zonas:** elija una contraseña de 6 caracteres o más. La app genera un texto
    cifrado y abre el menú de compartir (WhatsApp, correo o notas). Sin la contraseña, nadie
    puede leer ese texto.
  - **Importar zonas:** copie el texto completo, toque **Pegar**, escriba la contraseña e
    importe. Las zonas que ya existen no se duplican.
- **Borrar todo:** escriba **ELIMINAR** para borrar zonas, historial, ajustes y PIN. Esto no se
  puede deshacer.

## 5. Preguntas frecuentes

**¿La app envía mis datos a internet?**
No. Todo se guarda cifrado en el teléfono. Solo el plano del mapa se descarga de OpenStreetMap.

**¿Cuánta batería gasta?**
La cámara y el modelo trabajan todo el tiempo, así que el consumo es parecido al de grabar video.
Termine el escáner cuando no lo use.

**¿Detecta huecos y escaleras?**
El modelo de esta versión reconoce objetos comunes de la calle: personas, vehículos, bicicletas,
perros, semáforos y bancas. Los postes, huecos, escalones y obras se agregan con el modelo
ajustado con imágenes de Pasto. Mientras tanto, esos peligros se avisan con las zonas de riesgo
registradas.

**Se me olvidó el PIN.**
Desinstale y vuelva a instalar la app. Se perderán los datos; por eso conviene exportar las zonas
de vez en cuando.

## 6. Contacto

Autor: David Fernando Ramírez de la Parra. Universidad Cooperativa de Colombia, sede Pasto.
Proyecto: <https://github.com/dramirezdlp99/eyesight-ai>
