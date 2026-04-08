# Dev Server Launcher

Windows development server process manager with system tray GUI and full CLI.  
Manage Spring Boot, Vite, Node.js, npm, and any dev server from one place.

**AI-ready**: Full CLI interface for [Claude Code](https://claude.ai/claude-code), [Cursor](https://cursor.com), GitHub Copilot, and other AI coding assistants. Start/stop servers, read logs, edit config — all from the command line without opening the GUI.

[![GitHub release](https://img.shields.io/github/v/release/DreamingStrawberry/dev-server-launcher)](https://github.com/DreamingStrawberry/dev-server-launcher/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Quick Start

```
# Download latest release
# https://github.com/DreamingStrawberry/dev-server-launcher/releases

# Double-click to open GUI
DevLauncher.bat

# Or use CLI
DevLauncher.bat status
DevLauncher.bat start all
DevLauncher.bat logs my-backend
```

## CLI Reference

> **For AI Assistants (Claude Code, Cursor, etc.):**  
> All commands are available via `cmd.exe /c "C:\path\to\DevLauncher.bat <command>"`.  
> Use `status` to check services, `start`/`stop` to control them, `logs` to read output, and `config`/`add`/`edit`/`remove` to manage configuration — all without opening the GUI.

### Service Control

```bash
DevLauncher.bat status              # Show all service statuses (Running/Stopped)
DevLauncher.bat start <key>         # Start a service
DevLauncher.bat start all           # Start all services
DevLauncher.bat stop <key>          # Stop a service
DevLauncher.bat stop all            # Stop all services
DevLauncher.bat restart <key>       # Restart a service
DevLauncher.bat restart all         # Restart all services
DevLauncher.bat list                # List service keys
```

### Log Viewing

All service stdout/stderr is captured to `logs/<key>.log`.

```bash
DevLauncher.bat logs                # Show recent output for all services
DevLauncher.bat logs <key>          # Show last 50 lines of a service log
DevLauncher.bat logs <key> 200      # Show last 200 lines
```

### Configuration Management

```bash
DevLauncher.bat config              # Show full config with live status

# Add a new service
DevLauncher.bat add <key> <group> <short> <port> <dir> <cmd>
DevLauncher.bat add my-api MyApp API 8080 "C:\Projects\api" "mvnw.cmd spring-boot:run"

# Edit a service field (group, short, port, dir, cmd)
DevLauncher.bat edit <key> <field> <value>
DevLauncher.bat edit my-api port 8090
DevLauncher.bat edit my-api cmd "mvnw.cmd spring-boot:run -DskipTests"

# Remove a service (stops it if running)
DevLauncher.bat remove <key>
```

### System

```bash
DevLauncher.bat version             # Show version + check for updates
DevLauncher.bat update              # Download and apply latest release
DevLauncher.bat quit                # Stop the running GUI instance
DevLauncher.bat help                # Show all commands
```

## GUI Features

- **System Tray** — Right-click for service menu, double-click for dashboard
- **Dashboard** — Real-time status, Start/Stop/Restart, Show/Hide console windows
- **Hot-reload Settings** — Edit config in GUI, applies instantly without restart
- **Error Detection** — Alerts when a service goes down or exceeds startup timeout
- **Auto-update** — Checks GitHub releases on startup, auto-downloads new versions

### Tray Icon Colors

| Color | Meaning |
|-------|---------|
| Green | At least one service running |
| Red | Error detected |
| Gray | All stopped |

## Configuration

On first run, `DevLauncher.config.json` is created with example services:

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
| `key` | Unique identifier |
| `group` | Group name (services with same group are grouped in tray menu) |
| `short` | Short display name |
| `port` | TCP port to monitor for status detection |
| `dir` | Working directory |
| `cmd` | Command to execute |

## AI / Claude Code Integration

Dev Server Launcher is designed to be fully controllable by AI coding assistants.  
No GUI interaction needed — every operation is available via CLI.

### Why this matters

When AI assistants (Claude Code, Cursor, Copilot) work on your code, they often need to:
- **Start a backend** before testing API changes
- **Read server logs** to diagnose build errors or runtime exceptions
- **Restart services** after modifying configuration
- **Check if a port is in use** before starting a new server

Dev Server Launcher gives AI assistants a **single CLI interface** to do all of this.

### Example: Claude Code on WSL

```bash
# Check what's running
cmd.exe /c "C:\Users\YOU\DevLauncher.bat status"
# ● mw-back    MW-Back   :8080  Running
# ○ mw-react   MW-React  :5190  Stopped

# Start the backend
cmd.exe /c "C:\Users\YOU\DevLauncher.bat start my-backend"

# Read Spring Boot startup logs to check for errors
cmd.exe /c "C:\Users\YOU\DevLauncher.bat logs my-backend 100"

# Add a new service
cmd.exe /c "C:\Users\YOU\DevLauncher.bat add new-api NewProject API 8090 D:\Projects\new ""mvnw.cmd spring-boot:run"""

# Edit config
cmd.exe /c "C:\Users\YOU\DevLauncher.bat edit my-backend port 8081"

# Restart after config change
cmd.exe /c "C:\Users\YOU\DevLauncher.bat restart my-backend"

# Self-update to latest version
cmd.exe /c "C:\Users\YOU\DevLauncher.bat update"
```

### Example: PowerShell / CMD

```powershell
DevLauncher.bat status
DevLauncher.bat start all
DevLauncher.bat logs my-backend
DevLauncher.bat stop all
```

### Tip for AI assistant users

Add DevLauncher's path to your project's AI instructions (e.g., `CLAUDE.md`):

```markdown
## Dev Server
Use `cmd.exe /c "C:\Users\YOU\DevLauncher.bat <command>"` to manage dev servers.
Available commands: status, start, stop, restart, logs, config, add, edit, remove, update, quit
```

## Requirements

- Windows 10/11
- PowerShell 5.1+

## Installation

1. Download the latest [release](https://github.com/DreamingStrawberry/dev-server-launcher/releases)
2. Extract to any directory (e.g., `C:\DevLauncher\`)
3. Double-click `DevLauncher.bat` — desktop shortcut is created on first run

## File Structure

```
DevLauncher.bat             # Entry point (GUI or CLI based on args)
DevLauncher.ps1             # Main script
DevLauncher.ico             # Auto-generated icon
DevLauncher.config.json     # Service config (auto-generated, gitignored)
DevLauncher.history.json    # Startup time history (gitignored)
logs/                       # Service output logs (gitignored)
  <key>.log                 # Per-service log file
```

## License

[MIT](LICENSE)

