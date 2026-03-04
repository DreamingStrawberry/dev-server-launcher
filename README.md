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

Edit the `$script:services` hashtable in `DevLauncher.ps1` to define your services:

```powershell
$script:services = [ordered]@{
    "my-service" = @{
        Label = "My Service :3000"
        Short = "MySvc"
        Port  = 3000
        Dir   = "C:\path\to\project"
        Cmd   = "npm start"
    }
}
```

Each service entry requires:

| Key | Description |
|-----|-------------|
| `Label` | Display name shown in balloon notifications |
| `Short` | Short name used in menu and dashboard |
| `Port` | TCP port to monitor for status detection |
| `Dir` | Working directory for the service command |
| `Cmd` | Command to execute (runs inside `cmd.exe /k`) |

## File Structure

```
DevLauncher.ps1           # Main script
DevLauncher.bat           # Launcher (kills previous instance, runs ps1)
DevLauncher.ico           # Auto-generated tray/taskbar icon
DevLauncher.history.json  # Startup time history (auto-generated, gitignored)
DevLauncher.log           # Error log (auto-generated, gitignored)
```

## License

[MIT](LICENSE)
