# Dev Server Launcher

A lightweight PowerShell system tray application for managing multiple development servers. Start, stop, restart, and monitor all your dev services from a single tray icon.

## Features

- **System Tray Control** — Right-click the tray icon to start/stop individual services or all at once
- **Dashboard Window** — Double-click the tray icon to open a status dashboard with per-service controls
- **Console Management** — Show/hide each service's console window on demand
- **Port-based Monitoring** — Automatically detects service status by checking listening ports
- **Error Detection** — Alerts when a running service goes down unexpectedly or exceeds startup timeout
- **Startup History** — Tracks average startup times and shows estimated remaining time
- **Single Instance** — Mutex-based lock prevents duplicate launcher instances
- **Auto Icon Generation** — Creates its own `.ico` file and desktop shortcut on first run

## Requirements

- Windows 10/11
- PowerShell 5.1+

## Installation

1. Download or clone this repository
2. Place the files in any directory (e.g., `C:\DevLauncher\`)
3. Double-click `DevLauncher.bat` to launch

A desktop shortcut is created automatically on first run.

## Usage

### Tray Icon

| Action | Result |
|--------|--------|
| Right-click | Open service menu (Start/Stop/Restart per service) |
| Double-click | Open dashboard window |

### Tray Icon Colors

| Color | Meaning |
|-------|---------|
| Green | At least one service is running |
| Red | A service encountered an error |
| Gray | All services are stopped |

### Dashboard

The dashboard shows real-time status for each service:
- `Start` / `Restart` — Launch or restart a service
- `Stop` — Stop a running service
- `Cmd` — Toggle the service's console window (flashes red on error)
- `All Start` — Start all services sequentially
- `All Stop` — Stop all services
- `Show/Hide Cmd` — Toggle all console windows

## Configuration

On first run, a `DevLauncher.config.json` file is created with example services. Edit it to define your own:

```json
[
  {
    "key": "my-backend",
    "group": "MyApp",
    "short": "Back",
    "port": 8080,
    "dir": "C:\\Projects\\my-app",
    "cmd": "mvnw.cmd spring-boot:run"
  },
  {
    "key": "my-frontend",
    "group": "MyApp",
    "short": "Front",
    "port": 5173,
    "dir": "C:\\Projects\\my-app\\frontend",
    "cmd": "npm run dev"
  }
]
```

| Field | Description |
|-------|-------------|
| `key` | Unique identifier for the service |
| `group` | Group header in tray menu (services with same group are grouped together) |
| `short` | Short name used in menu and dashboard |
| `port` | TCP port to monitor for status detection |
| `dir` | Working directory for the service command |
| `cmd` | Command to execute (runs inside `cmd.exe /k`) |

## File Structure

```
DevLauncher.ps1           # Main script
DevLauncher.bat           # Launcher (kills previous instance, runs ps1)
DevLauncher.ico           # Auto-generated tray/taskbar icon
DevLauncher.config.json   # Service definitions (auto-generated, gitignored)
DevLauncher.history.json  # Startup time history (auto-generated, gitignored)
DevLauncher.log           # Error log (auto-generated, gitignored)
```

## License

[MIT](LICENSE)
