<div align="center">

# android-qa-kit

**Turn your coding agent into your Android QA engineer.**

Let it install your APK, walk every screen, verify the text, capture evidence and read the
crash logs — while you do something else.

[![Claude Code](https://img.shields.io/badge/Claude_Code-native-D97757?style=flat-square)](https://claude.com/claude-code)
[![Codex](https://img.shields.io/badge/Codex-supported-000000?style=flat-square)](https://openai.com/codex)
[![OpenCode](https://img.shields.io/badge/OpenCode-supported-0EA5E9?style=flat-square)](https://opencode.ai)
[![Cursor](https://img.shields.io/badge/Cursor-supported-6366F1?style=flat-square)](https://cursor.com)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Windows-PowerShell_5.1-0078D4?style=flat-square)](#requirements)
[![No install](https://img.shields.io/badge/installers-zero-success?style=flat-square)](#this-installs-nothing-on-its-own)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](#contributing)

**English** · [Español](README.es.md)

</div>

---

> **No MCP. No paid tools. No installers.**
> Just `adb`, a guide your agent reads, and **6 verified traps** that would otherwise cost you
> an afternoon each.

## Why this exists

There are dozens of tools to **control** an Android device. There is nothing that helps you
**set up the environment** on your own machine and leaves your agent instructions to use it
properly.

That gap is the whole project — the bridge between *"I have a Windows PC"* and *"my agent can
test my app."*

And it ships the traps you only find by breaking things. Example: in PowerShell, the natural
way to take a screenshot **produces a corrupted PNG and reports no error at all.** Your agent
goes blind and never finds out.

```powershell
# ❌ Silently corrupts the PNG — 1,404,569 bytes of garbage
adb exec-out screencap -p > shot.png

# ✅ 769,599 bytes, valid PNG
adb shell screencap -p /sdcard/s.png
adb pull /sdcard/s.png shot.png
```

## This installs nothing on its own

No installers. Cloning downloads nothing, runs nothing, touches nothing on your system.
**This is knowledge, not automation.**

What you get is a guide — [`AGENTS.md`](AGENTS.md) — written so your agent reads it and walks
you through: it asks which path you want, explains each piece *before* installing it, runs
commands in the open, and verifies results with you watching.

You can read this entire repository in ten minutes and see exactly what it does. That's the
point.

## Quick start

```bash
git clone https://github.com/willbytee-sudo/android-qa-kit
```

Then tell your agent:

> Read `AGENTS.md` and help me set up an Android test environment.

It takes over from there. Once you're set up:

> Test my app. The APK is at `build/app-release.apk`.

## Two paths — your agent asks which you want

| | 📱 Real device | 🖥️ Emulator |
|---|---|---|
| Download size | **~10 MB** | ~2 GB |
| Needs JDK + SDK | no | yes |
| Test fidelity | **real hardware** | approximate |
| Fake GPS, wipe to clean | ❌ | ✅ |
| Needs a phone + cable | yes | no |

The real-device path is surprisingly simpler. You can set up both.

## What your agent can do

| Capability | Emulator | Real device |
|---|:---:|:---:|
| Install APK, launch apps | ✅ | ✅ |
| Tap, type, swipe | ✅ | ✅ |
| Screenshots | ✅ | ✅ |
| **Read the UI** (text + coordinates) | ✅ | ✅ |
| Logcat | ✅ | ✅ |
| Toggle network | ✅ | ⚠️ vendor-dependent |
| **Fake GPS** | ✅ | ❌ |
| Change RAM, wipe clean | ✅ | ❌ |
| Real performance + thermals | ❌ | ✅ |
| Vendor skins, real camera | ❌ | ✅ |

`AGENTS.md` encodes this matrix so your agent **tells you** when something isn't possible in
your current mode, instead of trying it and then debugging a ghost.

## Verified, not claimed

Every command here was run against a real phone. This is actual output:

```
=== End-to-end verification ===
  initialScreen      com.android.launcher3.CustomizationPanelLauncher
  screenshot         OK          (PNG header verified: 89 50 4E 47)
  elementsRead       15
  network            0 -> 1
  mode               real-usb
  gps                NOT available in this mode
exit 0
```

## The 6 traps

| # | Trap | Why it hurts |
|---|---|---|
| 1 | `>` corrupts screenshots in PowerShell | Agent goes blind, **zero error output** |
| 2 | Fake GPS looks broken when it works | Agent chases a bug that doesn't exist |
| 3 | `-gpu auto` freezes the emulator | Reports `offline`, looks like a driver issue |
| 4 | Package name ≠ what you assumed | Maestro flows fail with no clear reason |
| 5 | PowerShell `$Args`, `Stop`, missing BOM | Three separate silent failures |
| 6 | Two devices connected | Every command needs `-s <id>` |

Full explanations with reproductions in [`AGENTS.md`](AGENTS.md).

## What's inside

| File | What it is |
|---|---|
| **[`AGENTS.md`](AGENTS.md)** | **The guide. Everything important lives here** |
| [`CLAUDE.md`](CLAUDE.md) | Points to `AGENTS.md` |
| [`qa.ps1`](qa.ps1) | **Optional.** Wraps `adb` with friendly names + checks |
| `qa.config.example.json` | Config template for your app |
| `flujos/` | Example [Maestro](https://maestro.mobile.dev) flow |

`qa.ps1` is sugar: it calls `adb` and nothing else, never downloads or installs anything, and
reads end-to-end in two minutes. Prefer raw `adb`? `AGENTS.md` is self-sufficient.

## Requirements

- Windows 10/11 with PowerShell 5.1 (ships with the OS)
- Emulator path only: ~8 GB free and virtualization enabled in BIOS
- Optional: [Maestro](https://maestro.mobile.dev) for repeatable YAML test flows

## Is USB debugging safe?

**It cannot damage your phone.** `adb` runs as the `shell` user — **no root privileges** — and
there is no path from there to the bootloader, which is the only thing that could brick a
device. Bricking requires fastboot and flashing, an entirely separate mode.

Real risks, honestly: installing an APK you don't trust, and leaving debugging enabled with
"always allow" on a phone someone else can physically reach. Turn it off when you're done
travelling.

## Contributing

PRs welcome. Especially: macOS and Linux ports, more verified traps, and translations.

Found a trap we missed? Open an issue with the reproduction — that's the most valuable thing
you can contribute here.

## License

MIT
