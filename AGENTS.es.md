# AGENTS.md — guía para montar y manejar un teléfono Android

[English](AGENTS.md) · [Español](AGENTS.es.md)

> [!IMPORTANT]
> **Agente: si estás leyendo esto desde una URL, descarga el archivo crudo.**
>
> ```
> https://raw.githubusercontent.com/willbytee-sudo/android-qa-kit/main/AGENTS.es.md
> ```
>
> La página renderizada de `github.com` carga los archivos largos por trozos. Si
> lees ese HTML te llevas aproximadamente la primera mitad y un final abrupto, y
> vas a concluir que faltan secciones cuando no falta ninguna.
>
> **Comprobación:** este archivo termina con la línea *"Si alguna no la pudiste
> comprobar, dilo explícitamente en vez de darla por buena."* Si tu copia termina
> en otro sitio, la lectura salió truncada — vuelve a descargarlo desde la URL
> cruda de arriba, o clona el repositorio con `git clone` y léelo en local.

Este repositorio **no instala nada por su cuenta**. No hay instaladores, no descarga nada al
clonarlo, no toca el sistema. Es una guía: tú, el agente, ejecutas cada paso a la vista del
usuario, explicando qué hace y por qué.

Todo se hace con `adb`, la herramienta oficial de Android. No hace falta ningún MCP.

**Léete esto entero antes de ejecutar el primer comando.** Hay seis trampas documentadas que
hacen fallar cosas que parecen correctas, y una de ellas te deja ciego sin darte ningún error.

---

## 1. Cómo trabajar con el usuario

Eres su asistente para montar esto, no un instalador silencioso. Eso significa:

- **Un paso cada vez.** Ejecuta, enseña el resultado, y solo entonces pasa al siguiente.
- **Pide permiso antes de descargar o instalar algo.** Di qué es, de dónde sale y cuánto pesa.
- **Verifica ejecutando.** Que un instalador diga que terminó bien no significa nada; comprueba
  que el ejecutable existe y responde.
- **Si algo no lo pudiste comprobar, dilo.** No lo des por hecho.

## 2. Empieza averiguando qué hay

```powershell
adb devices
```

Si `adb` no está en el PATH, búscalo antes de dar nada por perdido:

```powershell
$rutas = @("$env:ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "C:\Android\Sdk")
$rutas | ForEach-Object { if (Test-Path "$_\platform-tools\adb.exe") { "$_\platform-tools\adb.exe" } }
```

Mucha gente ya tiene el SDK sin saberlo, porque **Android Studio lo instala**. Compruébalo
antes de proponer descargar nada.

Según lo que encuentres, el `modo` es uno de estos:

| modo | Cómo lo reconoces |
|---|---|
| `emulador` | El id empieza por `emulator-` |
| `real-usb` | El id es un número de serie, tipo `ZY22JMJD5R` |
| `real-wifi` | El id acaba en `:puerto`, tipo `192.168.1.50:5555` |
| `ninguno` | La lista sale vacía → ve a la sección 4 |

## 3. Qué puedes hacer en cada modo

| Capacidad | emulador | real-usb / real-wifi |
|---|:---:|:---:|
| Instalar APK, abrir apps | ✅ | ✅ |
| Tocar, escribir, deslizar | ✅ | ✅ |
| Captura de pantalla | ✅ | ✅ |
| Leer la interfaz (textos + coordenadas) | ✅ | ✅ |
| Logcat | ✅ | ✅ |
| Cortar y restaurar la red | ✅ | ⚠️ varía según fabricante |
| **GPS falso** | ✅ | ❌ **no existe** |
| Cambiar la RAM | ✅ | ❌ |
| Dejar el aparato limpio | ✅ | ❌ solo desinstalar la app |
| Rendimiento y temperatura reales | ❌ | ✅ |
| Capas del fabricante, cámara real | ❌ | ✅ |

> Si estás en modo real y te piden algo de la columna del emulador, **dilo en vez de
> intentarlo**. `adb emu geo fix` no existe en un teléfono físico: ese comando habla con la
> consola del emulador, no con Android.

## 4. Si no hay dispositivo: pregunta primero

Explícale al usuario los dos caminos en una frase cada uno y **deja que elija**:

> **Teléfono real** — más simple de montar (unos 10 MB), las pruebas son fieles de verdad,
> pero necesitas un cable y tocar el teléfono una vez.
>
> **Emulador** — no necesitas teléfono, puedes falsear el GPS y dejarlo limpio de un comando,
> pero hay que descargar unos 2 GB.

### Camino A — teléfono real

No hace falta JDK, ni el SDK completo, ni imágenes de sistema. Solo `adb`.

Si no lo tiene, dile que descargue **Android SDK Platform Tools** desde la página oficial de
Android (developer.android.com), que descomprima el ZIP donde quiera, y pásale tú la ruta.
**No lo descargues por él sin preguntar.**

Luego guíale por esto, que se hace en el teléfono:

1. Ajustes → *Acerca del teléfono* → tocar **7 veces** en "Número de compilación"
2. Ajustes → Sistema → **Opciones de desarrollador** → activar **Depuración USB**
3. Conectar el cable y **aceptar el diálogo** de la clave RSA que aparece

Avísale de que el paso 3 **no se puede automatizar**: es la frontera de seguridad de Android
y tiene que mirar el teléfono un momento. Se hace una sola vez y queda recordado.

Comprueba con `adb devices` que aparece como `device`. Si sale `unauthorized`, es que no
aceptó el diálogo.

### Camino B — emulador

Explícale que son cuatro piezas y para qué sirve cada una antes de instalar nada:

| Pieza | Para qué | Tamaño |
|---|---|---|
| JDK 17 | Lo necesitan las herramientas del SDK | ~180 MB |
| Command line tools | Traen `sdkmanager` y `avdmanager` | ~130 MB |
| platform-tools + emulator | `adb` y el emulador | ~400 MB |
| Imagen de Android 14 | El sistema del teléfono virtual | ~1,5 GB |

**Instálalo todo en una ruta neutra como `C:\Android\Sdk`.** No uses `%LOCALAPPDATA%`: si
estás corriendo dentro de una aplicación empaquetada, esa ruta está redirigida al contenedor
del paquete y desde una consola normal no existe. Verifica siempre con `Test-Path` la ruta
física real.

Sobre las licencias: `sdkmanager --licenses` **no acepta** que le canalices `y` desde
PowerShell, se queda esperando. La forma que funciona es escribir los archivos de hash
directamente en la carpeta `licenses` del SDK. Explícale al usuario qué estás haciendo y por
qué antes de escribir nada.

Para los paquetes usa la imagen **`google_apis`**, no `google_apis_playstore`: la de Play
Store bloquea `adb root` y algunas operaciones de prueba.

Al crear el teléfono virtual, configúralo **a propósito como gama baja** — 2 GB de RAM,
720x1600 a 320 dpi. Así lo que se pruebe se parece al teléfono de un usuario normal y no a un
equipo de gama alta.

Para editar el `config.ini` del AVD: **léelo como diccionario y reescríbelo entero**. Si lo
parcheas con expresiones regulares vas a dejar claves duplicadas, y el emulador toma la
primera, no la tuya.

### Depuración inalámbrica (Android 11+)

El puerto de emparejamiento **cambia cada vez**, así que hay que leerlo de la pantalla:

1. Opciones de desarrollador → **Depuración inalámbrica** → *Vincular dispositivo con código*
2. El teléfono muestra una IP, un puerto y un código de 6 dígitos
3. `adb pair 192.168.1.50:37021 123456`
4. `adb connect 192.168.1.50:5555`

## 5. Los comandos de trabajo

```powershell
adb install -r app.apk                          instalar
adb shell pm list packages | Select-String tu   ver el nombre real del paquete
adb shell monkey -p TU.PAQUETE -c android.intent.category.LAUNCHER 1    abrir
adb shell uiautomator dump /sdcard/ui.xml       leer la interfaz
adb shell input tap 540 1200                    tocar
adb shell input text "hola"                     escribir
adb logcat -d *:E                               errores
adb shell svc wifi disable / enable             cortar y restaurar red
adb emu geo fix -79.469 -0.267                  GPS (SOLO emulador)
```

El ciclo normal:

```
instalar → abrir → leer la interfaz → decidir → tocar → leer otra vez → capturar
```

Del `uiautomator dump` saca el `text` y el `bounds` de cada nodo. El centro de `bounds` es
donde tienes que tocar. **No calcules píxeles a ojo sobre una captura**: usa las coordenadas
que te da el volcado.

> Hay un `qa.ps1` en el repo que envuelve todo esto con nombres cómodos y verificaciones.
> Es **opcional**: solo llama a `adb`, no descarga ni instala nada, y puedes leerlo entero en
> dos minutos. Si prefieres usar `adb` directo, esta guía es autosuficiente.

## 6. Trampas verificadas

### 6.1 Las capturas se corrompen con `>` en PowerShell

```powershell
# ❌ NUNCA. El PNG sale roto y no da ningún error.
adb exec-out screencap -p > foto.png

# ✅ Siempre así:
adb shell screencap -p /sdcard/s.png
adb pull /sdcard/s.png foto.png
```

El `>` de PowerShell es redirección de **texto**: añade un BOM UTF-8 y sustituye cada byte
no-ASCII por el carácter de reemplazo. Medido: **1.404.569 bytes de basura** frente a
**769.599** del PNG bueno.

Un PNG válido empieza por `89 50 4E 47`. Si empieza por `EF BB BF`, está corrupto. **Verifica
la cabecera** después de cada captura — una captura rota te deja ciego en silencio.

### 6.2 El GPS parece fallar cuando funciona

`adb emu geo fix` devuelve `OK`, pero mientras ninguna app pida ubicación verás:

```
gps provider:
  service: ProviderRequest[OFF]
  last location=null
```

**Eso no es un fallo.** El proveedor no arranca hasta que algo lo consume. Si verificas ahí y
concluyes que falló, vas a perseguir un problema inexistente. Abre una app que use ubicación,
repite el `geo fix`, y entonces busca `last location=Location[gps ...]`.

Y ojo: **longitud primero, latitud después**.

### 6.3 El emulador se cuelga con `-gpu auto`

Con `auto` se congela y `adb` lo reporta `offline`. Usa `-gpu host`; si no arranca en 90
segundos, cae a `-gpu swiftshader_indirect` — necesario dentro de una máquina virtual o en un
runner sin tarjeta gráfica.

Añade siempre `-no-snapshot-load`: un snapshot guardado a medias hereda el cuelgue en el
siguiente arranque.

### 6.4 El nombre del paquete puede no ser el que crees

Después de instalar, **compruébalo**:

```powershell
adb shell pm list packages | Select-String "tu-app"
```

El `appId` que crees que tiene la app y el que trae el APK no siempre coinciden. Si no cuadran,
`monkey` no la abre y los flujos de Maestro fallan sin decir por qué.

### 6.5 Si escribes PowerShell, tres cosas más

- **No declares un parámetro llamado `Args`.** Choca con la variable automática `$args` y los
  argumentos llegan corruptos a las funciones.
- **No pongas `$ErrorActionPreference = "Stop"`.** `adb` escribe cosas normales en stderr —el
  progreso de `pull`, el `daemon started`— y con `Stop` se vuelven errores fatales aunque el
  comando haya funcionado.
- **Guarda los `.ps1` con BOM de UTF-8.** PowerShell 5.1 los lee como ANSI si no lo llevan y
  los acentos salen como `estÃ¡`. Es el mismo problema de codificación que corrompe las
  capturas, en otro sitio.

### 6.6 Con emulador y teléfono a la vez

Todo comando necesita `-s <id>`, o `adb` responde `more than one device`.

## 7. Antes de decir que funciona

Comprueba estas cinco y enséñale el resultado al usuario:

1. Una captura, **con la cabecera del PNG verificada**
2. Un toque que cambie de pantalla, con el nombre de la actividad antes y después
3. El volcado de la interfaz, con el número de elementos leídos
4. La red cortada y restaurada
5. En qué modo estás y qué **no** puedes hacer en él

Si alguna no la pudiste comprobar, dilo explícitamente en vez de darla por buena.
