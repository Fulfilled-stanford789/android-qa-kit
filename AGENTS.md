# AGENTS.md — setting up and driving an Android device

[English](AGENTS.md) · [Español](AGENTS.es.md)

This repository **installs nothing on its own**. There are no installers, cloning downloads
nothing, and it does not touch the system. It is a guide: you, the agent, run each step in
the open, explaining what it does and why.

Everything runs through `adb`, Android's official tool. No MCP required.

**Read this fully before running the first command.** There are six documented traps that
break things which look correct, and one of them blinds you with no error output.

---

## 1. How to work with the user

You are their assistant for setting this up, not a silent installer. That means:

- **One step at a time.** Run it, show the result, and only then move on.
- **Ask before downloading or installing anything.** Say what it is, where it comes from, and
  how big it is.
- **Verify by executing.** An installer saying it finished means nothing — check that the
  binary exists and responds.
- **If you couldn't verify something, say so.** Don't assume it worked.

## 2. Start by finding out what's already there

```powershell
adb devices
```

If `adb` isn't on the PATH, look for it before concluding anything is missing:

```powershell
$paths = @("$env:ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "C:\Android\Sdk")
$paths | ForEach-Object { if (Test-Path "$_\platform-tools\adb.exe") { "$_\platform-tools\adb.exe" } }
```

Many people already have the SDK without realising it, because **Android Studio installs it**.
Check before proposing any download.

Based on what you find, the `mode` is one of:

| mode | How you recognise it |
|---|---|
| `emulator` | id starts with `emulator-` |
| `real-usb` | id is a serial number, e.g. `ZY22JMJD5R` |
| `real-wifi` | id ends in `:port`, e.g. `192.168.1.50:5555` |
| `none` | empty list → go to section 4 |

## 3. What you can do in each mode

| Capability | emulator | real-usb / real-wifi |
|---|:---:|:---:|
| Install APK, launch apps | ✅ | ✅ |
| Tap, type, swipe | ✅ | ✅ |
| Screenshots | ✅ | ✅ |
| Read the UI (text + coordinates) | ✅ | ✅ |
| Logcat | ✅ | ✅ |
| Toggle network | ✅ | ⚠️ vendor-dependent |
| **Fake GPS** | ✅ | ❌ **does not exist** |
| Change RAM | ✅ | ❌ |
| Wipe to a clean state | ✅ | ❌ uninstall the app only |
| Real performance and thermals | ❌ | ✅ |
| Vendor skins, real camera | ❌ | ✅ |

> If you're in a real-device mode and get asked for something from the emulator column,
> **say so instead of trying it**. `adb emu geo fix` does not exist on a physical phone: that
> command talks to the emulator console, not to Android.

## 4. If there's no device: ask first

Explain both paths in one sentence each and **let the user choose**:

> **Real device** — simpler to set up (about 10 MB), tests are genuinely faithful, but you need
> a cable and to touch the phone once.
>
> **Emulator** — no phone needed, you can fake GPS and wipe it clean with one command, but it's
> about 2 GB of downloads.

### Path A — real device

No JDK, no full SDK, no system images. Just `adb`.

If they don't have it, tell them to download **Android SDK Platform Tools** from the official
Android site (developer.android.com), unzip it wherever they like, and give you the path.
**Do not download it for them without asking.**

Then walk them through this, which happens on the phone:

1. Settings → *About phone* → tap **7 times** on "Build number"
2. Settings → System → **Developer options** → enable **USB debugging**
3. Plug in the cable and **accept the RSA key dialog** that appears

Warn them that step 3 **cannot be automated**: it's Android's security boundary and they need
to look at the phone for a moment. It's a one-time thing and the phone remembers it.

Confirm with `adb devices` that it shows as `device`. If it says `unauthorized`, they didn't
accept the dialog.

### Path B — emulator

Explain the four pieces and what each is for **before** installing anything:

| Piece | What for | Size |
|---|---|---|
| JDK 17 | Required by the SDK tools | ~180 MB |
| Command line tools | Provides `sdkmanager` and `avdmanager` | ~130 MB |
| platform-tools + emulator | `adb` and the emulator itself | ~400 MB |
| Android 14 system image | The virtual phone's OS | ~1.5 GB |

**Install everything to a neutral path like `C:\Android\Sdk`.** Do not use `%LOCALAPPDATA%`:
if you're running inside a packaged application, that path is redirected into the package
container and doesn't exist from a normal console. Always verify the real physical path with
`Test-Path`.

On licences: `sdkmanager --licenses` **will not accept** piped `y` from PowerShell — it just
hangs. What works is writing the hash files directly into the SDK's `licenses` folder. Explain
to the user what you're doing and why before writing anything.

For packages use the **`google_apis`** image, not `google_apis_playstore`: the Play Store one
blocks `adb root` and some testing operations.

When creating the virtual device, configure it **deliberately as a low-end phone** — 2 GB RAM,
720x1600 at 320 dpi. That way what you test resembles a normal user's phone, not a flagship.

To edit the AVD's `config.ini`: **read it as a dictionary and rewrite it whole**. Patching it
with regular expressions leaves duplicate keys, and the emulator takes the first one, not
yours.

### Wireless debugging (Android 11+)

The pairing port **changes every time**, so it has to be read off the screen:

1. Developer options → **Wireless debugging** → *Pair device with pairing code*
2. The phone shows an IP, a port and a 6-digit code
3. `adb pair 192.168.1.50:37021 123456`
4. `adb connect 192.168.1.50:5555`

## 5. The working commands

```powershell
adb install -r app.apk                          install
adb shell pm list packages | Select-String your  find the real package name
adb shell monkey -p YOUR.PACKAGE -c android.intent.category.LAUNCHER 1    launch
adb shell uiautomator dump /sdcard/ui.xml       read the UI
adb shell input tap 540 1200                    tap
adb shell input text "hello"                    type
adb logcat -d *:E                               errors
adb shell svc wifi disable / enable             toggle network
adb emu geo fix -79.469 -0.267                  GPS (EMULATOR ONLY)
```

The normal loop:

```
install → launch → read UI → decide → tap → read again → capture
```

From the `uiautomator dump`, pull each node's `text` and `bounds`. The centre of `bounds` is
where you tap. **Do not eyeball pixels on a screenshot** — use the coordinates from the dump.

> There is a `qa.ps1` in the repo wrapping all of this with friendly names and checks. It is
> **optional**: it only calls `adb`, never downloads or installs anything, and you can read it
> end to end in two minutes. If you prefer raw `adb`, this guide is self-sufficient.

## 6. Verified traps

### 6.1 Screenshots get corrupted by `>` in PowerShell

```powershell
# ❌ NEVER. The PNG comes out broken and reports no error.
adb exec-out screencap -p > shot.png

# ✅ Always:
adb shell screencap -p /sdcard/s.png
adb pull /sdcard/s.png shot.png
```

PowerShell's `>` is **text** redirection: it adds a UTF-8 BOM and replaces every non-ASCII
byte with the replacement character. Measured: **1,404,569 bytes of garbage** versus **769,599**
for the good PNG.

A valid PNG starts with `89 50 4E 47`. If it starts with `EF BB BF`, it's corrupted. **Verify
the header** after every screenshot — a broken one blinds you silently.

### 6.2 Fake GPS looks broken when it works

`adb emu geo fix` returns `OK`, but while no app is requesting location you'll see:

```
gps provider:
  service: ProviderRequest[OFF]
  last location=null
```

**That is not a failure.** The provider doesn't start until something consumes it. If you
verify there and conclude it failed, you'll chase a problem that doesn't exist. Open an app
that uses location, repeat the `geo fix`, then look for `last location=Location[gps ...]`.

Also: **longitude first, latitude second**.

### 6.3 The emulator freezes with `-gpu auto`

With `auto` it hangs and `adb` reports it `offline`. Use `-gpu host`; if it doesn't boot within
90 seconds, fall back to `-gpu swiftshader_indirect` — required inside a virtual machine or on
a runner with no graphics card.

Always add `-no-snapshot-load`: a half-written snapshot inherits the freeze on the next boot.

### 6.4 The package name may not be what you think

After installing, **check it**:

```powershell
adb shell pm list packages | Select-String "your-app"
```

The `appId` you believe your app has and the one the APK actually carries don't always match.
When they don't, `monkey` won't launch it and Maestro flows fail without saying why.

### 6.5 If you write PowerShell, three more

- **Never declare a parameter named `Args`.** It collides with the automatic `$args` variable
  and arguments arrive corrupted inside functions.
- **Do not set `$ErrorActionPreference = "Stop"`.** `adb` writes perfectly normal things to
  stderr — the `pull` progress, `daemon started` — and with `Stop` those become fatal errors
  even though the command succeeded.
- **Save `.ps1` files with a UTF-8 BOM.** PowerShell 5.1 reads them as ANSI otherwise and
  accented characters come out mangled. It's the same encoding problem that corrupts
  screenshots, in a different place.

### 6.6 With both an emulator and a phone connected

Every command needs `-s <id>`, or `adb` answers `more than one device`.

## 7. Before claiming it works

Check these five and show the user the output:

1. A screenshot, **with the PNG header verified**
2. A tap that changes screen, with the activity name before and after
3. The UI dump, with the number of elements read
4. Network cut and restored
5. Which mode you're in and what you **cannot** do in it

If you couldn't verify one of them, say so explicitly instead of assuming.
