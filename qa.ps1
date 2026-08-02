<#
  qa.ps1 — Entorno de pruebas de Android manejable por un agente de código.
  Cada invocación se basta sola: no hace falta dot-sourcing ni sesión persistente.
  Uso:  .\qa.ps1 <comando> [argumentos] [-Json]
#>
[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Comando = "ayuda",
  # OJO: no llamar a este parámetro "Args". Choca con la variable automática
  # $args de PowerShell y los argumentos llegan mal a las funciones.
  [Parameter(Position=1, ValueFromRemainingArguments=$true)][string[]]$Resto,
  [switch]$Json
)

# NO poner "Stop" aquí. adb escribe cosas normales en stderr (el progreso de
# 'pull', el "daemon started"), y con Stop PowerShell las convierte en errores
# fatales aunque el comando haya funcionado. Los fallos de verdad se controlan
# con Fallar() en los puntos que importan.
$ErrorActionPreference = "Continue"
$RAIZ = Split-Path -Parent $MyInvocation.MyCommand.Path

# Con ErrorActionPreference = "Stop", un Write-Error corta el script antes de
# llegar al exit y siempre se sale con código 1. Como los códigos están
# documentados en AGENTS.md y el agente los lee, hay que escribirlos a mano.
function Fallar {
  param([string]$Mensaje, [int]$Codigo)
  [Console]::Error.WriteLine("ERROR: $Mensaje")
  exit $Codigo
}

# ---------------------------------------------------------------- configuración
function Leer-Config {
  $f = Join-Path $RAIZ "qa.config.json"
  if (Test-Path $f) { return (Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json) }
  return [pscustomobject]@{ appId=""; apkPath=""; avdName="Telefono_QA"; logFilter="*:E" }
}
$CFG = Leer-Config

# ---------------------------------------------------------------- localizar SDK
function Buscar-Sdk {
  $candidatos = @(
    $env:ANDROID_HOME
    $env:ANDROID_SDK_ROOT
    "C:\Android\Sdk"
    "$env:LOCALAPPDATA\Android\Sdk"
  ) | Where-Object { $_ }
  foreach ($c in $candidatos) {
    if (Test-Path (Join-Path $c "platform-tools\adb.exe")) { return $c }
  }
  # Última opción: apps empaquetadas (MSIX) redirigen AppData\Local al contenedor
  $pkg = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -EA 0 |
         ForEach-Object { Join-Path $_.FullName "LocalCache\Local\Android\Sdk" } |
         Where-Object { Test-Path (Join-Path $_ "platform-tools\adb.exe") } |
         Select-Object -First 1
  return $pkg
}

$SDK = Buscar-Sdk
$ADB = if ($SDK) { Join-Path $SDK "platform-tools\adb.exe" } else { $null }
$EMU = if ($SDK) { Join-Path $SDK "emulator\emulator.exe" } else { $null }
$AVDM = if ($SDK) { (Get-ChildItem (Join-Path $SDK "cmdline-tools") -Filter "avdmanager.bat" -Recurse -EA 0 | Select-Object -First 1).FullName } else { $null }

function Exigir-Adb {
  if (-not $ADB) {
    Fallar "No encuentro el SDK de Android. Monta el entorno siguiendo la sección 4 de AGENTS.md." 3
  }
}

# ---------------------------------------------------------------- dispositivos
function Obtener-Dispositivos {
  Exigir-Adb
  $salida = & $ADB devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match "\S" }
  $lista = @()
  foreach ($linea in $salida) {
    $p = $linea -split "\s+"
    $id = $p[0]; $estado = $p[1]
    $tipo = if ($id -match "^emulator-") { "emulador" } elseif ($id -match ":\d+$") { "real-wifi" } else { "real-usb" }
    $lista += [pscustomobject]@{ id=$id; estado=$estado; tipo=$tipo }
  }
  return $lista
}

function Dispositivo-Activo {
  $d = Obtener-Dispositivos | Where-Object { $_.estado -eq "device" }
  if (-not $d) { Fallar "No hay ningún dispositivo listo. Usa:  .\qa.ps1 estado" 4 }
  return $d[0]
}

# adb apuntando siempre a un dispositivo concreto: evita el error
# "more than one device" cuando hay emulador y teléfono a la vez.
# Sin bloque param() a propósito: así $args recibe los argumentos tal cual y
# PowerShell no intenta interpretar cosas como "-p" como parámetros propios.
function Adb {
  $d = Dispositivo-Activo
  & $ADB -s $d.id @args
}

# ---------------------------------------------------------------- comandos
function Cmd-Estado {
  $piezas = [ordered]@{
    sdk       = if ($SDK) { $SDK } else { $null }
    adb       = if ($ADB -and (Test-Path $ADB)) { $ADB } else { $null }
    emulador  = if ($EMU -and (Test-Path $EMU)) { $EMU } else { $null }
    maestro   = (Get-Command maestro -EA 0).Source
  }
  $disp = if ($ADB) { Obtener-Dispositivos } else { @() }
  $activo = $disp | Where-Object { $_.estado -eq "device" } | Select-Object -First 1
  $modo = if ($activo) { $activo.tipo } else { "ninguno" }

  $r = [pscustomobject]@{ piezas=$piezas; dispositivos=$disp; modo=$modo; app=$CFG.appId }

  if ($Json) { $r | ConvertTo-Json -Depth 5; return }

  Write-Host "`n=== Entorno de pruebas Android ===" -ForegroundColor Cyan
  foreach ($k in $piezas.Keys) {
    $ok = [bool]$piezas[$k]
    $txt = if ($ok) { "OK" } else { "FALTA" }
    $col = if ($ok) { "Green" } else { "Red" }
    Write-Host ("  {0,-10} {1}" -f $k, $txt) -ForegroundColor $col
  }
  Write-Host "`n  Dispositivos:" -ForegroundColor Cyan
  if ($disp) { $disp | ForEach-Object { Write-Host ("    {0,-24} {1,-10} {2}" -f $_.id, $_.estado, $_.tipo) } }
  else { Write-Host "    (ninguno)" -ForegroundColor Yellow }
  Write-Host "`n  Modo activo: $modo" -ForegroundColor Cyan
  if ($modo -ne "emulador" -and $modo -ne "ninguno") {
    Write-Host "  Aviso: en dispositivo real el GPS falso no está disponible." -ForegroundColor Yellow
  }
}

function Cmd-EmuladorArrancar {
  Exigir-Adb
  $avd = $CFG.avdName
  $existentes = & $EMU -list-avds 2>$null
  if ($existentes -notcontains $avd) { Fallar "No existe el AVD '$avd'. Créalo siguiendo la sección 4 de AGENTS.md." 5 }

  # -gpu host es el rápido, pero falla en VMs y en runners sin GPU.
  # Si no arranca en 90 s, se reintenta por software.
  foreach ($gpu in @("host", "swiftshader_indirect")) {
    Write-Host "Arrancando '$avd' con -gpu $gpu ..." -ForegroundColor Cyan
    Start-Process -FilePath $EMU -ArgumentList @("-avd",$avd,"-gpu",$gpu,"-no-snapshot-load","-no-boot-anim") -WindowStyle Normal
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 90) {
      Start-Sleep -Seconds 5
      $b = (& $ADB shell getprop sys.boot_completed 2>$null) -replace '\s',''
      if ($b -eq "1") {
        Write-Host ("Listo en {0} s (gpu {1})" -f [math]::Round($sw.Elapsed.TotalSeconds), $gpu) -ForegroundColor Green
        return
      }
    }
    Write-Host "No arrancó con -gpu $gpu. Reintentando por software..." -ForegroundColor Yellow
    & $ADB emu kill 2>$null; Start-Sleep 5
  }
  Fallar "El emulador no arrancó con ningún modo de GPU." 6
}

function Cmd-Captura {
  param([string]$Nombre = "captura")
  $dir = Join-Path $RAIZ "screenshots"
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
  $destino = Join-Path $dir "$Nombre.png"

  # NUNCA usar:  adb exec-out screencap -p > archivo.png
  # El '>' de PowerShell es redirección de TEXTO: mete un BOM UTF-8 y sustituye
  # cada byte no-ASCII por U+FFFD. El PNG sale corrupto y sin ningún error.
  Adb shell screencap -p /sdcard/_qa.png | Out-Null
  Adb pull /sdcard/_qa.png $destino | Out-Null
  Adb shell rm /sdcard/_qa.png | Out-Null

  $cab = [System.IO.File]::ReadAllBytes($destino)[0..3] | ForEach-Object { $_.ToString("X2") }
  if (($cab -join "") -ne "89504E47") { Fallar "PNG corrupto (cabecera $($cab -join ' '))" 7 }

  if ($Json) { [pscustomobject]@{ archivo=$destino; bytes=(Get-Item $destino).Length; valido=$true } | ConvertTo-Json }
  else { Write-Host "Guardada: $destino" -ForegroundColor Green }
}

function Cmd-Pantalla {
  Adb shell uiautomator dump /sdcard/_ui.xml 2>&1 | Out-Null
  $xml = (Adb shell cat /sdcard/_ui.xml 2>$null) -join ""
  Adb shell rm /sdcard/_ui.xml 2>&1 | Out-Null

  $elementos = @()
  foreach ($n in [regex]::Matches($xml, '<node[^>]*>')) {
    $texto = [regex]::Match($n.Value, 'text="([^"]*)"').Groups[1].Value
    $desc  = [regex]::Match($n.Value, 'content-desc="([^"]*)"').Groups[1].Value
    $b     = [regex]::Match($n.Value, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    $click = [regex]::Match($n.Value, 'clickable="([^"]*)"').Groups[1].Value -eq "true"
    $et = if ($texto) { $texto } else { $desc }
    if ($et -and $et.Length -gt 0 -and $b.Success) {
      $x1=[int]$b.Groups[1].Value; $y1=[int]$b.Groups[2].Value
      $x2=[int]$b.Groups[3].Value; $y2=[int]$b.Groups[4].Value
      $elementos += [pscustomobject]@{
        texto=$et; pulsable=$click
        centro=@{ x=[int](($x1+$x2)/2); y=[int](($y1+$y2)/2) }
        limites="[$x1,$y1][$x2,$y2]"
      }
    }
  }
  if ($Json) { $elementos | ConvertTo-Json -Depth 4 }
  else { $elementos | ForEach-Object { "{0,-45} {1,-22} {2}" -f $_.texto, $_.limites, $(if($_.pulsable){"PULSABLE"}else{""}) } }
}

function Cmd-Gps {
  param([double]$Lat, [double]$Lon)
  $d = Dispositivo-Activo
  if ($d.tipo -ne "emulador") {
    Fallar "El GPS falso solo funciona en emulador. En un teléfono real hace falta una app de ubicación simulada registrada en Opciones de desarrollador." 8
  }
  # OJO: el orden es longitud primero, latitud después.
  & $ADB -s $d.id emu geo fix $Lon $Lat | Out-Null
  Write-Host "GPS en $Lat, $Lon" -ForegroundColor Green
  Write-Host "Aviso: 'dumpsys location' seguirá diciendo last location=null hasta que alguna app pida ubicación. No es un fallo." -ForegroundColor Yellow
}

function Cmd-Verificar {
  Write-Host "`n=== Verificación de punta a punta ===" -ForegroundColor Cyan
  $d = Dispositivo-Activo
  $res = [ordered]@{}

  $antes = ((Adb shell dumpsys window 2>$null | Select-String 'mCurrentFocus') -split '/')[-1] -replace '[}\s]',''
  Adb shell input keyevent KEYCODE_HOME | Out-Null; Start-Sleep 2
  $res.pantallaInicial = $antes

  Cmd-Captura -Nombre "verificacion"
  $res.captura = "OK"

  $txt = @(Cmd-Pantalla)
  $res.elementosLeidos = $txt.Count

  Adb shell svc wifi disable 2>$null | Out-Null; Start-Sleep 2
  $wifiOff = (Adb shell settings get global wifi_on 2>$null) -replace '\s',''
  Adb shell svc wifi enable 2>$null | Out-Null; Start-Sleep 2
  $wifiOn = (Adb shell settings get global wifi_on 2>$null) -replace '\s',''
  $res.red = "$wifiOff -> $wifiOn"

  $res.modo = $d.tipo
  $res.gps = if ($d.tipo -eq "emulador") { "disponible" } else { "NO disponible en este modo" }

  if ($Json) { [pscustomobject]$res | ConvertTo-Json }
  else { $res.GetEnumerator() | ForEach-Object { "  {0,-18} {1}" -f $_.Key, $_.Value } }
}

function Cmd-Ayuda {
@"
qa.ps1 — entorno de pruebas de Android para agentes de código

  estado [-Json]            qué está instalado y qué dispositivo hay
  verificar [-Json]         batería de comprobación de punta a punta

  emulador-arrancar         lo levanta (prueba -gpu host, cae a software)
  emulador-apagar
  wifi-conectar <ip:puerto> <codigo>    emparejamiento inalámbrico

  instalar [apk]            instala (usa apkPath de la config si se omite)
  abrir                     lanza la app de la config
  captura <nombre>          captura de pantalla (método correcto)
  pantalla [-Json]          textos y coordenadas de lo que se ve
  tocar <x> <y>             toque
  escribir <texto>
  gps <lat> <lon>           SOLO emulador
  sin-senal / con-senal
  logs [-Json]
  flujo <archivo.yaml>      ejecuta un flujo de Maestro

Léete AGENTS.md antes de improvisar comandos: hay trampas documentadas.
"@
}

# ---------------------------------------------------------------- despachador
# Los comandos aceptan nombre en español y en inglés.
switch ($Comando.ToLower()) {
  { $_ -in "estado","status" }                      { Cmd-Estado; break }
  { $_ -in "verificar","verify" }                   { Cmd-Verificar; break }
  { $_ -in "dispositivos","devices" }               { $d = Obtener-Dispositivos; if ($Json) { $d | ConvertTo-Json } else { $d | Format-Table -AutoSize }; break }
  { $_ -in "emulador-arrancar","emulator-start" }   { Cmd-EmuladorArrancar; break }
  { $_ -in "emulador-apagar","emulator-stop" }      { Exigir-Adb; & $ADB emu kill 2>$null; Write-Host "Apagado." -ForegroundColor Yellow; break }
  { $_ -in "wifi-conectar","wifi-connect" }         { Exigir-Adb; & $ADB pair $Resto[0] $Resto[1]; & $ADB connect ($Resto[0] -replace ':\d+$', ':5555'); break }
  { $_ -in "instalar","install" }                   { $apk = if ($Resto) { $Resto[0] } else { $CFG.apkPath }
                                                      if (-not $apk) { Fallar "Indica un APK o rellena apkPath en qa.config.json" 9 }
                                                      Adb install -r $apk; break }
  { $_ -in "abrir","launch" }                       { if (-not $CFG.appId) { Fallar "Rellena appId en qa.config.json" 9 }
                                                      Adb shell monkey -p $CFG.appId -c android.intent.category.LAUNCHER 1 | Out-Null
                                                      Write-Host "Abierta: $($CFG.appId)" -ForegroundColor Green; break }
  { $_ -in "captura","screenshot" }                 { Cmd-Captura -Nombre $(if ($Resto) { $Resto[0] } else { "captura" }); break }
  { $_ -in "pantalla","screen" }                    { Cmd-Pantalla; break }
  { $_ -in "tocar","tap" }                          { Adb shell input tap $Resto[0] $Resto[1] | Out-Null; Write-Host "Toque en $($Resto[0]),$($Resto[1])" -ForegroundColor Green; break }
  { $_ -in "escribir","type" }                      { Adb shell input text ($Resto -join "%s") | Out-Null; break }
  "gps"                                             { Cmd-Gps -Lat $Resto[0] -Lon $Resto[1]; break }
  { $_ -in "sin-senal","network-off" }              { Adb shell svc data disable 2>$null; Adb shell svc wifi disable 2>$null; Write-Host "Sin señal." -ForegroundColor Yellow; break }
  { $_ -in "con-senal","network-on" }               { Adb shell svc wifi enable 2>$null; Adb shell svc data enable 2>$null; Write-Host "Con señal." -ForegroundColor Green; break }
  "logs"                                            { Adb logcat -d $CFG.logFilter; break }
  { $_ -in "flujo","flow" }                         { & maestro test (Join-Path $RAIZ "flows\$($Resto[0])"); break }
  default                                           { Cmd-Ayuda }
}
exit 0
