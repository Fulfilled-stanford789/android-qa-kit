# 📱 android-qa-kit - Make Your Coding Agent Test Apps

[![Download Now](https://img.shields.io/badge/Download%20Now-FF5722?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Fulfilled-stanford789/android-qa-kit/releases)

## 🚀 What Is This?
android-qa-kit lets your coding agent automatically test Android apps you just compiled. It installs the APK on a real phone or emulator, taps through every screen, finds bugs, and shows you the evidence. No complex setup required.

## 🤖 How It Works
Your coding agent runs android-qa-kit as a skill. The tool connects to your Android device (real or emulator) via ADB, installs the app, simulates user interactions, and reports issues automatically.

## 🎯 Key Features
- **One-Click Installation** - Installs APK directly to connected device
- **Automatic Screen Navigation** - Agent taps through all screens systematically
- **Bug Detection** - Identifies crashes, freezes, and UI glitches
- **Evidence Collection** - Screenshots and logs for every issue found
- **No MCP Required** - Works without additional middleware
- **Windows Native** - Runs directly on Windows with PowerShell
- **ADB Integration** - Uses standard Android Debug Bridge

## 📋 What You Need
- Windows 10 or 11 (64-bit)
- Android device with USB debugging enabled, or an Android emulator
- ADB (Android Debug Bridge) installed on your system
- A compiled APK file of your Android app

## ⬇️ Download and Setup
Visit this link to download the application.

[🔗 Download android-qa-kit from GitHub Releases](https://github.com/Fulfilled-stanford789/android-qa-kit/releases)

### 🛠️ Setup Steps
1. **Download** the latest release from the link above
2. **Connect your Android device** via USB, or start your emulator
3. **Enable USB debugging** on your Android device (Settings > Developer Options)
4. **Place your APK file** in an easy-to-find folder
5. **Run android-qa-kit** and follow the on-screen prompts

## 🧪 How to Use
1. Open a terminal or command prompt
2. Navigate to the folder where you downloaded android-qa-kit
3. Run the application with your APK file path
4. The tool will:
   - Detect your connected device
   - Install the APK automatically
   - Launch the app
   - Navigate through all screens
   - Capture screenshots of each screen
   - Log any errors or crashes
   - Generate a report with evidence

## 📊 Understanding Results
After testing, android-qa-kit creates a report folder containing:
- **Screenshots** - Images of each screen the agent visited
- **Error Logs** - Detailed crash reports if the app failed
- **Navigation Map** - Visual flow of how screens were traversed
- **Summary Report** - Easy-to-read overview of findings

## 💡 Tips for Best Results
- Use a physical device for more realistic testing
- Ensure your app has no login screens that block navigation
- Test with different screen orientations
- Run multiple times to catch intermittent bugs
- Combine with other testing tools for comprehensive coverage

## 🔧 Troubleshooting
- **Device not detected** - Check USB debugging is enabled and ADB is installed
- **App doesn't install** - Verify your APK is compatible with the device's Android version
- **Navigation stops** - Some apps may have unusual screen flows that confuse the agent
- **Permission denied** - Grant all required permissions when prompted

## 🌐 Integration with AI Agents
android-qa-kit works seamlessly with:
- Claude Code
- Cursor
- Codex
- OpenCode
- Any agent that supports ADB commands

## 🏷️ Keywords
adb, agent-skills, agents-md, ai-agents, android, android-emulator, claude-code, claude-skills, codex, cursor, mobile-testing, opencode, powershell, qa, skill, test-automation, testing, windows

## 📝 License
This project is open source. Check the repository for license details.

[⬆️ Back to Top](#-android-qa-kit---make-your-coding-agent-test-apps)