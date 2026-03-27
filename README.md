# ProcessMonitor

> A silent Windows background utility that watches every process on your system, logs exits, flags crashes, and explains what went wrong — in plain English.

![Code Scanning](https://github.com/Gnawbie/ProcessMonitor/actions/workflows/code-scanning.yml/badge.svg)

---

## What it does

ProcessMonitor runs invisibly in your system tray and tracks every program that opens and closes on your PC. When something crashes, it tells you *why* — not just an obscure exit code, but an actual explanation and what you can do about it.

- 📋 **Logs every process exit** to a daily `.log` file
- 🚨 **Flags crashes** (non-zero exit codes) to a separate `errors_` log
- 🧠 **Explains crashes in plain English** — e.g. *"The program tried to read memory it doesn't own. Usually a bad mod, plugin, or driver conflict."*
- 👪 **Identifies the parent process** that launched the crashed program
- 🔔 **Balloon notification** when a crash is detected (mute-able, persists across restarts)
- 🖥️ **System tray icon** so you always know it's running
- 🔇 Runs completely silently — no console window

---

## Screenshot

![Error log examples](https://github.com/Gnawbie/ProcessMonitor/wiki/images/error-log-examples.png)

*Real entries from a single day's log — background task failures, Chrome updater errors, Windows auth timeouts, and a Path of Exile hard crash with annotated exit codes.*

---

## Quick start

1. Clone or download this repo
2. Double-click **`Start-Monitor.bat`**
3. A green circle appears in your system tray — you're running
4. Double-click **`View-Logs.bat`** to see today's logs
5. Right-click the tray icon → **Stop Monitor** to quit

> **Requirements:** Windows 10/11, PowerShell 5.1 (built-in). No install needed.

---

## Files

| File | Purpose |
|------|---------|
| `ProcessMonitor.ps1` | The monitor itself |
| `Start-Monitor.bat` | Starts the monitor silently (no console window) |
| `Start-Monitor.vbs` | VBScript launcher used by the .bat to hide the window |
| `Stop-Monitor.bat` | Gracefully stops the monitor |
| `View-Logs.bat` | Opens today's log in Notepad |
| `Diagnose-Monitor.bat` | Troubleshooting tool — runs visibly so you can see errors |
| `Test-RunVisible.bat` | Runs the script in a visible console for debugging |
| `Convert-Log.ps1` | Utility to convert/filter existing log files |

Logs are saved to `%USERPROFILE%\ProcessMonitorLogs\`

---

## Log format

```
[HH:mm:ss] TAG    | PID: ###### | Exit: CODE                   | ProcessName  [spawned by: Parent (PID)]
           why --> Plain-English explanation of what the crash means.
```

See the **[Log Format wiki page](../../wiki/Log-Format)** for full details and exit code reference.

---

## Wiki

Full documentation lives in the [Wiki](../../wiki):

| Page | Description |
|------|-------------|
| [Installation](../../wiki/Installation) | How to set up and run for the first time |
| [Usage](../../wiki/Usage) | Starting, stopping, and viewing logs |
| [Log Format](../../wiki/Log-Format) | What the log entries mean, with real examples |
| [Tray Icon](../../wiki/Tray-Icon) | Tray icon features, mute, and right-click menu |
| [Troubleshooting](../../wiki/Troubleshooting) | Common problems and fixes |
| [File Reference](../../wiki/File-Reference) | Every file in the repo explained |

---

## About this project

I am not a programmer. I have the ideas and the use cases — **[Claude (Anthropic's AI)](https://claude.ai)** writes the code. I describe what I want, we work through it together, and Claude handles the PowerShell implementation and debugging.

Everything is tested on my real system. The crash logs in the screenshot above are genuine — including three Path of Exile crashes that we traced back to NVIDIA's `nvngx_update.exe` interfering with the game's rendering pipeline.

If you have ideas or questions, head to **[Discussions](../../discussions)** — no technical knowledge needed.

---

## Contributing

- 💡 **Ideas & feature requests** → [Discussions → Ideas](../../discussions/categories/ideas)
- 🐛 **Bug reports** → [Issues](../../issues)
- 🙏 **Questions** → [Discussions → Q&A](../../discussions/categories/q-a)

---

## License

MIT — do whatever you like with it.
