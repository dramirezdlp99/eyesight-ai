# Publicación de EyeSight AI

Este documento cubre tres pasos:
1. firmar la versión de producción;
2. publicarla en GitHub Releases;
3. publicar la página web en GitHub Pages.

Al final se resume lo que pide Google Play para la fase siguiente.

> **Regla de seguridad.** Ni el archivo `.jks` ni `android/key.properties` se suben a GitHub. Ya
> están en `.gitignore`. Si se pierde la clave, no se puede actualizar la app en Google Play;
> guárdela también en una memoria USB.

## 1. Crear la clave de firma (una sola vez)

`keytool` viene con el Java de Android Studio. En PowerShell:

```powershell
New-Item -ItemType Directory -Force C:\dev\eyesight-keys
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore C:\dev\eyesight-keys\upload-keystore.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Pide una contraseña. Use la misma para el almacén y para la clave, y anótela en un lugar
  seguro.
- Pide nombre, unidad y organización: responda con sus datos, por ejemplo
  `CN=David Fernando Ramirez de la Parra, OU=Ingenieria de Software, O=Universidad Cooperativa de Colombia, L=Pasto, C=CO`.
- Si `keytool.exe` no está en esa ruta, ejecute `flutter doctor -v` y busque la línea `Java
  binary at:`. `keytool.exe` está en la misma carpeta.

## 2. Crear `android/key.properties`

Cree el archivo `C:\dev\eyesight-ai\android\key.properties` con este contenido, poniendo su
contraseña:

```properties
storePassword=SU_CONTRASENA
keyPassword=SU_CONTRASENA
keyAlias=upload
storeFile=C:/dev/eyesight-keys/upload-keystore.jks
```

- Use barras `/` en la ruta, no `\`.
- Compruebe que Git lo ignora: `git status` **no** debe mostrar `key.properties`.

Si este archivo no existe, la versión release se firma con la clave de depuración. Así las
pruebas siguen funcionando, pero ese APK no sirve para publicar.

## 3. Construir la versión de producción

```powershell
cd C:\dev\eyesight-ai
flutter clean
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build\symbols
```

- El APK queda en `build\app\outputs\flutter-apk\app-release.apk`.
- `--obfuscate` oculta los nombres del código Dart.
- `--split-debug-info` guarda los símbolos aparte en `build\symbols`, para poder leer los errores
  más adelante. Guarde esa carpeta junto con cada versión publicada.

Verifique la firma. La línea de «Signer #1» debe mostrar su nombre, no `Android Debug`:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\35.0.0\apksigner.bat" verify --print-certs build\app\outputs\flutter-apk\app-release.apk
```

Si su versión de build-tools es otra, cambie `35.0.0` por la carpeta que tenga en
`%LOCALAPPDATA%\Android\Sdk\build-tools`.

Para Google Play se construye un AAB:

```powershell
flutter build appbundle --release --obfuscate --split-debug-info=build\symbols
```

Queda en `build\app\outputs\bundle\release\app-release.aab`.

## 4. Publicar en GitHub Releases

1. Copie el APK con un nombre claro:
   `Copy-Item build\app\outputs\flutter-apk\app-release.apk C:\dev\EyeSight-AI.apk`
2. En GitHub, abra el repositorio → **Releases** → **Draft a new release**.
3. En **Choose a tag**, escriba `v1.0.0` y elija **Create new tag**.
4. Título: `EyeSight AI 1.0.0 (prototipo)`. En la descripción, ponga los cambios y el aviso
   «Complementa el bastón; no lo reemplaza».
5. Arrastre `EyeSight-AI.apk` a **Attach binaries**.
6. Toque **Publish release**.

La página web enlaza a
`https://github.com/dramirezdlp99/eyesight-ai/releases/latest/download/EyeSight-AI.apk`. Ese
enlace siempre descarga el APK de la última versión, siempre que el archivo se llame exactamente
`EyeSight-AI.apk`.

Para cada versión nueva, suba `version:` en `pubspec.yaml` (por ejemplo, `1.0.1+2`) y repita los
pasos 3 y 4.

## 5. Publicar la página web (GitHub Pages)

La página está en `website/` y se publica sola con `.github/workflows/pages.yml` cada vez que hay
un *push* a `main` que cambia esa carpeta.

Para activarla (una sola vez):
1. Vaya al repositorio → **Settings** → **Pages**.
2. En **Build and deployment** → **Source**, elija **GitHub Actions**.
3. Vaya a **Actions** → **Página web** → **Run workflow**, o haga un *push*.

La página queda en <https://dramirezdlp99.github.io/eyesight-ai/>, con:
- presentación;
- descarga del APK;
- política de privacidad (`privacidad.html`);
- manual (`manual.html`).

## 6. Google Play (fase siguiente)

| Requisito | Detalle |
|---|---|
| Cuenta de desarrollador | USD 25, un solo pago; verificación de identidad |
| Prueba cerrada | 12 testers durante 14 días seguidos (para cuentas personales nuevas) |
| Formato | AAB firmado (paso 3); Play App Signing administra la clave de distribución |
| Política de privacidad | URL pública: `https://dramirezdlp99.github.io/eyesight-ai/privacidad.html` |
| Seguridad de los datos | Declarar que la app **no recopila ni comparte** datos. Todo se procesa y guarda en el teléfono |
| Permisos | Justificar la cámara, el micrófono y la ubicación (ver el manual) |
| Clasificación de contenido | Cuestionario IARC |
| Accesibilidad | Ficha con capturas, descripción y mención de TalkBack |
