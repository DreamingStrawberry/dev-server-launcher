#Requires -Version 5.1
<#
.SYNOPSIS  Dev Server Launcher - System Tray
.VERSION   1.0.0
.NOTES     DevLauncher.bat 더블클릭으로 실행
           트레이 아이콘 우클릭 → 서비스 시작/중지
           각 서비스는 별도 cmd 창에서 실행 (로그 확인 가능)
#>

$script:AppVersion = "1.0.0"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Win32 API for Show/Hide console windows
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32Window {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("shell32.dll", SetLastError=true)]
    public static extern int SetCurrentProcessExplicitAppUserModelID(
        [MarshalAs(UnmanagedType.LPWStr)] string AppID);

    // CreateProcess for bypassing Windows Terminal
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool CreateProcess(
        string lpApp, string lpCmd, IntPtr pa, IntPtr ta,
        bool bInherit, uint dwFlags, IntPtr lpEnv, string lpDir,
        ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr h);

    public const int SW_HIDE = 0;
    public const int SW_SHOW = 5;
    public const int SW_MINIMIZE = 6;
    public const int SW_RESTORE = 9;
    public const uint CREATE_NEW_CONSOLE = 0x00000010;

    // EnumWindows for partial title search (Windows Terminal changes titles)
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);

    private static IntPtr _found;
    public static IntPtr FindWindowByTitle(string sub) {
        _found = IntPtr.Zero;
        EnumWindows((hWnd, lp) => {
            int len = GetWindowTextLength(hWnd);
            if (len > 0) {
                StringBuilder sb = new StringBuilder(len + 1);
                GetWindowText(hWnd, sb, sb.Capacity);
                if (sb.ToString().IndexOf(sub, StringComparison.OrdinalIgnoreCase) >= 0) {
                    _found = hWnd;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return _found;
    }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb; public string lpReserved, lpDesktop, lpTitle;
        public int dwX,dwY,dwXSize,dwYSize,dwXCountChars,dwYCountChars,dwFillAttribute,dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }
}
"@

# Hide own console window
[Win32Window]::ShowWindow([Win32Window]::GetConsoleWindow(), [Win32Window]::SW_HIDE) | Out-Null
# Separate from PowerShell in taskbar (use own icon instead of PS icon)
[Win32Window]::SetCurrentProcessExplicitAppUserModelID("Dogen.DevServerLauncher") | Out-Null

# ═══════════════════════════════════════════════
# Single Instance (Mutex)
# ═══════════════════════════════════════════════
$mutexName = "Global\DevServerLauncher_SingleInstance"
$script:mutex = New-Object System.Threading.Mutex($false, $mutexName)
$acquired = $false
try {
    $acquired = $script:mutex.WaitOne(0, $false)
} catch [System.Threading.AbandonedMutexException] {
    # Previous instance crashed without releasing → we now own it
    $acquired = $true
} catch {
    $acquired = $true
}
if (-not $acquired) {
    [System.Windows.Forms.MessageBox]::Show(
        "Dev Server Launcher가 이미 실행 중입니다.`n트레이 아이콘을 확인하세요.",
        "Dev Server Launcher", "OK", "Information")
    exit
}

# ═══════════════════════════════════════════════
# First-run: Generate .ico + Desktop shortcut
# ═══════════════════════════════════════════════
$icoPath = Join-Path $PSScriptRoot "DevLauncher.ico"
if (-not (Test-Path $icoPath)) {
    $sz = 64
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "HighQuality"
    $g.TextRenderingHint = "AntiAliasGridFit"

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = New-Object System.Drawing.Rectangle(0, 0, ($sz-1), ($sz-1))
    $d = 14
    $path.AddArc($r.X, $r.Y, $d, $d, 180, 90)
    $path.AddArc($r.Right - $d, $r.Y, $d, $d, 270, 90)
    $path.AddArc($r.Right - $d, $r.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($r.X, $r.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(37, 99, 235))), $path)

    $font = New-Object System.Drawing.Font("Segoe UI", 34, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
    $g.DrawString("D", $font, [System.Drawing.Brushes]::White,
        (New-Object System.Drawing.RectangleF(-2, 0, $sz, $sz)), $sf)

    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(34, 197, 94))),
        ($sz - 18), 4, 13, 13)
    $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)),
        ($sz - 18), 4, 13, 13)

    $g.Dispose(); $font.Dispose(); $sf.Dispose()

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    $fs = [System.IO.FileStream]::new($icoPath, [System.IO.FileMode]::Create)
    $icon.Save($fs)
    $fs.Close()
    $icon.Dispose(); $bmp.Dispose()
    try {
        Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class WinIcon{[DllImport("user32.dll")]public static extern bool DestroyIcon(IntPtr h);}' -ErrorAction SilentlyContinue
        [WinIcon]::DestroyIcon($hIcon) | Out-Null
    } catch {}
}

$lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Dev Server Launcher.lnk"
if (-not (Test-Path $lnkPath)) {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath = Join-Path $PSScriptRoot "DevLauncher.bat"
    $sc.WorkingDirectory = $PSScriptRoot
    $sc.IconLocation = "$icoPath,0"
    $sc.WindowStyle = 7
    $sc.Description = "Dev Server Launcher"
    $sc.Save()
}

[System.Windows.Forms.Application]::EnableVisualStyles()

# ═══════════════════════════════════════════════
# Configuration (from DevLauncher.config.json)
# ═══════════════════════════════════════════════
$script:configPath = Join-Path $PSScriptRoot "DevLauncher.config.json"

# Generate default config if missing
if (-not (Test-Path $script:configPath)) {
    $defaultConfig = @(
        [ordered]@{ key = "my-backend";  label = "My Backend :8080";  short = "Back";  port = 8080; dir = "C:\Projects\my-app"; cmd = "mvnw.cmd spring-boot:run" }
        [ordered]@{ key = "my-frontend"; label = "My Frontend :5173"; short = "Front"; port = 5173; dir = "C:\Projects\my-app\frontend"; cmd = "npm run dev" }
    )
    $defaultConfig | ConvertTo-Json -Depth 3 | Set-Content $script:configPath -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show(
        "DevLauncher.config.json created with example services.`nEdit it to add your own services, then restart.",
        "Dev Server Launcher", "OK", "Information")
    exit
}

# Load config
$script:services = [ordered]@{}
try {
    $configJson = Get-Content $script:configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($svc in $configJson) {
        $script:services[$svc.key] = @{
            Label = $svc.label
            Short = $svc.short
            Port  = [int]$svc.port
            Dir   = $svc.dir
            Cmd   = $svc.cmd
        }
    }
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to load DevLauncher.config.json`n$($_.Exception.Message)",
        "Dev Server Launcher", "OK", "Error")
    exit
}

if ($script:services.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "No services defined in DevLauncher.config.json",
        "Dev Server Launcher", "OK", "Warning")
    exit
}

$script:cmdPids = @{}
$script:cmdTitles = @{}    # window title per service (for FindWindow)
$script:cmdHandles = @{}   # stored window handles (IntPtr)
$script:cmdVisible = @{}   # visibility state per service
$script:startingSet = @{}  # services currently in startup queue
$script:startTimes = @{}   # timestamp when Start-Svc was called
$script:errorSet = @{}         # services in error state
$script:wasRunning = @{}       # services that had port active (for port-drop detection)
$script:pulseState = $false    # pulse animation toggle

# Load startup history (average durations per service)
$script:historyPath = Join-Path $PSScriptRoot "DevLauncher.history.json"
$script:startHistory = @{}
if (Test-Path $script:historyPath) {
    try {
        $json = Get-Content $script:historyPath -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $script:startHistory[$prop.Name] = [int]$prop.Value
        }
    } catch {}
}

# ═══════════════════════════════════════════════
# Port-based process management
# ═══════════════════════════════════════════════
function Get-PortPid([int]$port) {
    $lines = & netstat -ano 2>$null | Select-String ":${port}\s.*LISTENING"
    foreach ($line in $lines) {
        $parts = $line.Line.Trim() -split '\s+'
        $procId = [int]$parts[-1]
        if ($procId -gt 0) { return $procId }
    }
    return 0
}

function Test-PortActive([int]$port) { return (Get-PortPid $port) -gt 0 }

function Stop-ByPort([int]$port) {
    $procId = Get-PortPid $port
    if ($procId -gt 0) {
        & taskkill /F /T /PID $procId 2>$null | Out-Null
        return $true
    }
    return $false
}

# Lightweight: only update tray icon color + tooltip (no menu rebuild)
function Update-TrayIcon {
    $hasRunning = $false; $hasError = $false
    foreach ($k in $script:services.Keys) {
        if ($script:errorSet[$k]) { $hasError = $true }
        if (Test-PortActive $script:services[$k].Port) { $hasRunning = $true }
    }
    $state = if ($hasError) { "error" } elseif ($hasRunning) { "running" } else { "stopped" }
    $script:tray.Icon = New-TrayIcon $state

    $n = 0; $e = 0; $total = $script:services.Count
    foreach ($k in $script:services.Keys) {
        if (Test-PortActive $script:services[$k].Port) { $n++ }
        if ($script:errorSet[$k]) { $e++ }
    }
    $errText = if ($e -gt 0) { " ${e} error" } else { "" }
    $script:tray.Text = "Dev Launcher [$n/$total running]$errText"
}

function Start-Svc([string]$key, [bool]$quiet = $false) {
    $svc = $script:services[$key]
    $script:errorSet.Remove($key)
    $script:wasRunning.Remove($key)

    # Kill tracked cmd window first
    if ($script:cmdPids[$key]) {
        try { & taskkill /F /T /PID $script:cmdPids[$key] 2>$null | Out-Null } catch {}
        $script:cmdPids[$key] = $null
    }

    # Kill by port (non-blocking — port release is checked by timer)
    if (Test-PortActive $svc.Port) {
        Stop-ByPort $svc.Port
    }

    $title = "DevLauncher_$($svc.Short)_$($svc.Port)"
    $fullCmd = "title $title && cd /d $($svc.Dir) && $($svc.Cmd)"

    # CreateProcess: CREATE_NEW_CONSOLE + STARTF_USESHOWWINDOW(SW_HIDE)
    # → 윈도우가 생성 시점부터 숨겨진 상태 (Windows Terminal에서도 동작)
    $si = New-Object Win32Window+STARTUPINFO
    $si.cb = [System.Runtime.InteropServices.Marshal]::SizeOf([type][Win32Window+STARTUPINFO])
    $si.lpTitle = $title
    $si.dwFlags = 1      # STARTF_USESHOWWINDOW
    $si.wShowWindow = 0  # SW_HIDE
    $pi = New-Object Win32Window+PROCESS_INFORMATION
    $cmdLine = "cmd.exe /k $fullCmd"
    $cpOk = [Win32Window]::CreateProcess(
        $null, $cmdLine, [IntPtr]::Zero, [IntPtr]::Zero, $false,
        [Win32Window]::CREATE_NEW_CONSOLE,
        [IntPtr]::Zero, $null, [ref]$si, [ref]$pi)
    if ($cpOk) {
        $script:cmdPids[$key] = $pi.dwProcessId
        [Win32Window]::CloseHandle($pi.hProcess) | Out-Null
        [Win32Window]::CloseHandle($pi.hThread) | Out-Null
    } else {
        # CreateProcess 실패 시 Start-Process 폴백 (WindowStyle Hidden)
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/k $fullCmd" -WindowStyle Hidden -PassThru
        $script:cmdPids[$key] = $proc.Id
    }
    $script:cmdTitles[$key] = $title
    $script:startingSet[$key] = $true
    $script:startTimes[$key] = [DateTime]::Now
    $script:cmdVisible[$key] = $false  # 숨긴 상태로 시작
    $script:cmdHandles[$key] = [IntPtr]::Zero  # Get-ConsoleHandle will find it lazily

    # Only update icon/tooltip, NOT the menu (menu is rebuilt on next click)
    Update-TrayIcon
    if (-not $quiet) {
        $script:tray.ShowBalloonTip(2000, "Started", $svc.Label, [System.Windows.Forms.ToolTipIcon]::Info)
    }
}

function Stop-Svc([string]$key, [bool]$quiet = $false) {
    $svc = $script:services[$key]

    if (Test-PortActive $svc.Port) { Stop-ByPort $svc.Port }
    if ($script:cmdPids[$key]) {
        try { & taskkill /F /T /PID $script:cmdPids[$key] 2>$null | Out-Null } catch {}
        $script:cmdPids[$key] = $null
    }
    $script:cmdTitles[$key] = $null
    $script:cmdHandles[$key] = [IntPtr]::Zero
    $script:cmdVisible[$key] = $false
    $script:errorSet.Remove($key)
    $script:wasRunning.Remove($key)

    Update-TrayIcon
    if (-not $quiet) {
        $script:tray.ShowBalloonTip(1500, "Stopped", $svc.Label, [System.Windows.Forms.ToolTipIcon]::Warning)
    }
}

# ═══════════════════════════════════════════════
# Show / Hide Console Windows
# ═══════════════════════════════════════════════
function Get-ConsoleHandle([string]$key) {
    $hWnd = $script:cmdHandles[$key]
    if (-not $hWnd -or $hWnd -eq [IntPtr]::Zero) {
        $t = $script:cmdTitles[$key]
        if ($t) {
            # EnumWindows 부분 검색 (Windows Terminal이 타이틀을 수정해도 동작)
            $hWnd = [Win32Window]::FindWindowByTitle($t)
            if ($hWnd -and $hWnd -ne [IntPtr]::Zero) {
                $script:cmdHandles[$key] = $hWnd
            }
        }
    }
    return $hWnd
}

function Show-Console([string]$key) {
    $hWnd = Get-ConsoleHandle $key
    if ($hWnd -and $hWnd -ne [IntPtr]::Zero) {
        [Win32Window]::ShowWindow($hWnd, [Win32Window]::SW_SHOW) | Out-Null
        [Win32Window]::ShowWindow($hWnd, [Win32Window]::SW_RESTORE) | Out-Null
        $script:cmdVisible[$key] = $true
    }
}

function Hide-Console([string]$key) {
    $hWnd = Get-ConsoleHandle $key
    if ($hWnd -and $hWnd -ne [IntPtr]::Zero) {
        [Win32Window]::ShowWindow($hWnd, [Win32Window]::SW_HIDE) | Out-Null
        Start-Sleep -Milliseconds 50
        if ([Win32Window]::IsWindowVisible($hWnd)) {
            [Win32Window]::ShowWindow($hWnd, [Win32Window]::SW_MINIMIZE) | Out-Null
        }
        $script:cmdVisible[$key] = $false
    }
}

function Toggle-Console([string]$key) {
    if ($script:cmdVisible[$key]) { Hide-Console $key } else { Show-Console $key }
}

function Show-AllConsoles {
    foreach ($k in $script:services.Keys) {
        if ($script:cmdPids[$k]) { Show-Console $k }
    }
}

function Hide-AllConsoles {
    foreach ($k in $script:services.Keys) {
        if ($script:cmdPids[$k]) { Hide-Console $k }
    }
}

# ═══════════════════════════════════════════════
# Tray Icon (green/gray circle with "D")
# ═══════════════════════════════════════════════
$script:trayIconCache = @{}
function New-TrayIcon([string]$state) {
    if ($script:trayIconCache.ContainsKey($state)) {
        return $script:trayIconCache[$state]
    }
    try {
        $bmp = New-Object System.Drawing.Bitmap(16, 16)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = "AntiAlias"
        $color = switch ($state) {
            "running" { [System.Drawing.Color]::FromArgb(34, 197, 94) }
            "error"   { [System.Drawing.Color]::FromArgb(220, 38, 38) }
            default   { [System.Drawing.Color]::FromArgb(156, 163, 175) }
        }
        $brush = New-Object System.Drawing.SolidBrush($color)
        $font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
        $g.FillEllipse($brush, 1, 1, 14, 14)
        $g.DrawString("D", $font, [System.Drawing.Brushes]::White, -0.5, 0.5)
        $font.Dispose(); $brush.Dispose(); $g.Dispose()
        $hIcon = $bmp.GetHicon()
        $script:trayIconCache[$state] = [System.Drawing.Icon]::FromHandle($hIcon)
    } catch {
        # GDI+ fallback: use pre-generated .ico file
        $icoFile = Join-Path $PSScriptRoot "DevLauncher.ico"
        if (Test-Path $icoFile) {
            $script:trayIconCache[$state] = New-Object System.Drawing.Icon($icoFile, 16, 16)
        } else {
            $script:trayIconCache[$state] = [System.Drawing.SystemIcons]::Application
        }
    }
    return $script:trayIconCache[$state]
}

# ═══════════════════════════════════════════════
# Build Context Menu (called only on tray click)
# ═══════════════════════════════════════════════
function Build-TrayMenu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $menu.RenderMode = "System"

    # Header
    $header = New-Object System.Windows.Forms.ToolStripLabel "Dev Server Launcher"
    $header.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $header.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
    $menu.Items.Add($header) | Out-Null
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # MEDIWELL
    $mwH = New-Object System.Windows.Forms.ToolStripLabel "  MEDIWELL"
    $mwH.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $mwH.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $menu.Items.Add($mwH) | Out-Null
    Add-ServiceMenuItems $menu "mw-back"
    Add-ServiceMenuItems $menu "mw-react"

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # CRM+
    $crmH = New-Object System.Windows.Forms.ToolStripLabel "  CRM+"
    $crmH.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $crmH.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
    $menu.Items.Add($crmH) | Out-Null
    Add-ServiceMenuItems $menu "crm-back"
    Add-ServiceMenuItems $menu "crm-react"

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # All Start — uses timer to avoid blocking UI + menu disposal crash
    $allStart = New-Object System.Windows.Forms.ToolStripMenuItem
    $allStart.Text = [char]0x25B6 + "  All Start"
    $allStart.Enabled = ($script:startQueue.Count -eq 0 -and $script:startingSet.Count -eq 0)
    $allStart.Add_Click({
        if ($script:startQueue.Count -gt 0 -or $script:startingSet.Count -gt 0) { return }
        $script:startQueue = [System.Collections.ArrayList]@($script:services.Keys)
        $script:startTotal = $script:startQueue.Count
        $script:startingSet = @{}
        foreach ($k in $script:services.Keys) { $script:startingSet[$k] = $true }
        $script:tray.Text = "Starting... [0/$script:startTotal]"
        $script:startTimer.Start()
    })
    $menu.Items.Add($allStart) | Out-Null

    # Toggle Cmd windows
    $anyVis = $false
    foreach ($k in $script:services.Keys) { if ($script:cmdVisible[$k]) { $anyVis = $true; break } }
    $toggleCmd = New-Object System.Windows.Forms.ToolStripMenuItem
    $toggleCmd.Text = if ($anyVis) { [char]0x2612 + "  Hide Cmd" } else { [char]0x2610 + "  Show Cmd" }
    $toggleCmd.Add_Click({
        $av = $false
        foreach ($k in $script:services.Keys) { if ($script:cmdVisible[$k]) { $av = $true; break } }
        if ($av) { Hide-AllConsoles } else { Show-AllConsoles }
    })
    $menu.Items.Add($toggleCmd) | Out-Null

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # All Stop
    $allStop = New-Object System.Windows.Forms.ToolStripMenuItem
    $allStop.Text = [char]0x25A0 + "  All Stop"
    $allStop.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
    $allStop.Add_Click({
        foreach ($k in $script:services.Keys) { Stop-Svc $k $true }
        $script:tray.ShowBalloonTip(2000, "All Stopped", "모든 서비스 종료됨", [System.Windows.Forms.ToolTipIcon]::Warning)
    })
    $menu.Items.Add($allStop) | Out-Null

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # Exit
    $exit = New-Object System.Windows.Forms.ToolStripMenuItem
    $exit.Text = "Exit"
    $exit.Add_Click({
        $script:exiting = $true
        [System.Windows.Forms.Application]::Exit()
    })
    $menu.Items.Add($exit) | Out-Null

    return $menu
}

function Add-ServiceMenuItems($menu, [string]$key) {
    $svc = $script:services[$key]
    $active = Test-PortActive $svc.Port
    $isStarting = $script:startingSet[$key] -eq $true

    $isError = $script:errorSet[$key] -eq $true

    if ($isError) {
        $dot = [char]0x2716     # X mark
        $statusText = "Error - Cmd 확인"
        $dotColor = [System.Drawing.Color]::FromArgb(220, 38, 38)   # red
    } elseif ($isStarting -and -not $active) {
        $dot = [char]0x25E6     # hollow bullet
        $statusText = "Starting..."
        $dotColor = [System.Drawing.Color]::FromArgb(234, 179, 8)   # yellow
    } elseif ($active) {
        $dot = [char]0x25CF     # filled circle
        $statusText = "Running"
        $dotColor = [System.Drawing.Color]::FromArgb(22, 163, 74)   # green
    } else {
        $dot = [char]0x25CB     # open circle
        $statusText = "Stopped"
        $dotColor = [System.Drawing.Color]::FromArgb(156, 163, 175) # gray
    }

    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = "  $dot  $($svc.Short)  :$($svc.Port)   [$statusText]"
    $item.Font = New-Object System.Drawing.Font("Consolas", 9)
    $item.ForeColor = $dotColor

    $startItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $startItem.Text = if ($active) { "Restart" } else { "Start" }
    $startItem.Tag = $key
    $startItem.Add_Click({ Start-Svc $this.Tag })

    $stopItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $stopItem.Text = "Stop"
    $stopItem.Tag = $key
    $stopItem.Enabled = $active
    $stopItem.Add_Click({ Stop-Svc $this.Tag })

    # Show/Hide Console toggle
    $hasWindow = ($script:cmdPids[$key] -and $script:cmdPids[$key] -gt 0)
    $isVisible = $script:cmdVisible[$key]
    $consoleItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $consoleItem.Tag = $key
    if ($hasWindow) {
        $consoleItem.Text = if ($isVisible) { "Hide Cmd" } else { "Show Cmd" }
        $consoleItem.Add_Click({ Toggle-Console $this.Tag })
    } else {
        $consoleItem.Text = "Show Cmd"
        $consoleItem.Enabled = $false
    }

    $item.DropDownItems.Add($startItem) | Out-Null
    $item.DropDownItems.Add($stopItem) | Out-Null
    $item.DropDownItems.Add($consoleItem) | Out-Null
    $menu.Items.Add($item) | Out-Null
}

# ═══════════════════════════════════════════════
# Dashboard Form (double-click tray to open)
# ═══════════════════════════════════════════════
$script:dashboard = New-Object System.Windows.Forms.Form
$script:dashboard.Text = "Dev Server Launcher v$($script:AppVersion)"
if (Test-Path $icoPath) {
    $script:dashboard.Icon = New-Object System.Drawing.Icon($icoPath)
}
$script:dashContentHeight = 10 + ($script:services.Count * 34) + 6 + 30 + 16  # rows + gap + buttons + padding
$script:dashboard.Size = New-Object System.Drawing.Size(510, ($script:dashContentHeight + 40))  # +40 for title bar
$script:dashboard.StartPosition = "CenterScreen"
$script:dashboard.FormBorderStyle = "FixedSingle"
$script:dashboard.MaximizeBox = $false
$script:dashboard.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$script:exiting = $false
$script:dashboard.Add_FormClosing({
    param($s, $e)
    if (-not $script:exiting) {
        $e.Cancel = $true    # hide, don't close
        $script:dashboard.Hide()
    }
})

# Store label/button refs for updates
$script:dashLabels = @{}
$script:dashBtns = @{}

$y = 10
foreach ($key in $script:services.Keys) {
    $svc = $script:services[$key]

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(14, ($y + 4))
    $lbl.Size = New-Object System.Drawing.Size(310, 20)
    $lbl.Font = New-Object System.Drawing.Font("Consolas", 9)
    $script:dashboard.Controls.Add($lbl)
    $script:dashLabels[$key] = $lbl

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Location = New-Object System.Drawing.Point(325, $y)
    $btnStart.Size = New-Object System.Drawing.Size(55, 26)
    $btnStart.Text = "Start"
    $btnStart.Tag = $key
    $btnStart.FlatStyle = "Flat"
    $btnStart.Add_Click({ Start-Svc $this.Tag; Update-Dashboard })
    $script:dashboard.Controls.Add($btnStart)

    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Location = New-Object System.Drawing.Point(385, $y)
    $btnStop.Size = New-Object System.Drawing.Size(50, 26)
    $btnStop.Text = "Stop"
    $btnStop.Tag = $key
    $btnStop.FlatStyle = "Flat"
    $btnStop.Add_Click({ Stop-Svc $this.Tag; Update-Dashboard })
    $script:dashboard.Controls.Add($btnStop)

    $btnCon = New-Object System.Windows.Forms.Button
    $btnCon.Location = New-Object System.Drawing.Point(440, $y)
    $btnCon.Size = New-Object System.Drawing.Size(45, 26)
    $btnCon.Text = "Cmd"
    $btnCon.Tag = $key
    $btnCon.FlatStyle = "Flat"
    $btnCon.Add_Click({ Toggle-Console $this.Tag; Update-Dashboard })
    $script:dashboard.Controls.Add($btnCon)

    $script:dashBtns[$key] = @{ Start = $btnStart; Stop = $btnStop; Console = $btnCon }

    $y += 34
}

# Bottom buttons
$y += 6
$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Location = New-Object System.Drawing.Point(14, $y)
$btnAll.Size = New-Object System.Drawing.Size(80, 30)
$btnAll.Text = "All Start"
$btnAll.FlatStyle = "Flat"
$btnAll.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnAll.Add_Click({
    if ($script:startQueue.Count -gt 0 -or $script:startingSet.Count -gt 0) { return }
    $script:startQueue = [System.Collections.ArrayList]@($script:services.Keys)
    $script:startTotal = $script:startQueue.Count
    $script:startingSet = @{}
    foreach ($k in $script:services.Keys) { $script:startingSet[$k] = $true }
    $script:startTimer.Start()
    Update-Dashboard
})
$script:dashboard.Controls.Add($btnAll)
$script:btnAllStart = $btnAll

$btnStopAll = New-Object System.Windows.Forms.Button
$btnStopAll.Location = New-Object System.Drawing.Point(100, $y)
$btnStopAll.Size = New-Object System.Drawing.Size(80, 30)
$btnStopAll.Text = "All Stop"
$btnStopAll.FlatStyle = "Flat"
$btnStopAll.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
$btnStopAll.Add_Click({
    foreach ($k in $script:services.Keys) { Stop-Svc $k $true }
    Update-Dashboard
})
$script:dashboard.Controls.Add($btnStopAll)

$script:btnToggleCmd = New-Object System.Windows.Forms.Button
$script:btnToggleCmd.Location = New-Object System.Drawing.Point(210, $y)
$script:btnToggleCmd.Size = New-Object System.Drawing.Size(90, 30)
$script:btnToggleCmd.Text = "Show Cmd"
$script:btnToggleCmd.FlatStyle = "Flat"
$script:btnToggleCmd.Add_Click({
    $anyVisible = $false
    foreach ($k in $script:services.Keys) {
        if ($script:cmdVisible[$k]) { $anyVisible = $true; break }
    }
    if ($anyVisible) { Hide-AllConsoles } else { Show-AllConsoles }
    Update-Dashboard
})
$script:dashboard.Controls.Add($script:btnToggleCmd)

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Location = New-Object System.Drawing.Point(420, $y)
$btnSettings.Size = New-Object System.Drawing.Size(60, 30)
$btnSettings.Text = [char]0x2699 + " Edit"
$btnSettings.FlatStyle = "Flat"
$btnSettings.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
$btnSettings.Add_Click({ Show-SettingsForm })
$script:dashboard.Controls.Add($btnSettings)

# ═══════════════════════════════════════════════
# Settings Form
# ═══════════════════════════════════════════════
function Show-SettingsForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Service Settings"
    $form.Size = New-Object System.Drawing.Size(820, 420)
    $form.StartPosition = "CenterParent"
    $form.FormBorderStyle = "Sizable"
    $form.MinimumSize = New-Object System.Drawing.Size(700, 350)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(10, 10)
    $grid.Size = New-Object System.Drawing.Size(785, 300)
    $grid.Anchor = "Top,Left,Right,Bottom"
    $grid.AllowUserToResizeRows = $false
    $grid.RowHeadersVisible = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.AutoSizeColumnsMode = "Fill"
    $grid.ScrollBars = "Both"
    $grid.BackgroundColor = [System.Drawing.Color]::White
    $grid.BorderStyle = "Fixed3D"
    $grid.DefaultCellStyle.Font = New-Object System.Drawing.Font("Consolas", 9)
    $grid.DefaultCellStyle.WrapMode = "NoSet"
    $grid.AllowUserToAddRows = $false

    # Double-click cell → edit full content in popup
    $grid.Add_CellDoubleClick({
        param($s, $e)
        if ($e.RowIndex -lt 0 -or $e.ColumnIndex -lt 0) { return }
        $cell = $grid.Rows[$e.RowIndex].Cells[$e.ColumnIndex]
        $colName = $grid.Columns[$e.ColumnIndex].HeaderText

        $editForm = New-Object System.Windows.Forms.Form
        $editForm.Text = "Edit: $colName"
        $editForm.Size = New-Object System.Drawing.Size(500, 160)
        $editForm.StartPosition = "CenterParent"
        $editForm.FormBorderStyle = "FixedDialog"
        $editForm.MaximizeBox = $false
        $editForm.MinimizeBox = $false
        $editForm.Font = New-Object System.Drawing.Font("Consolas", 10)

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location = New-Object System.Drawing.Point(10, 10)
        $tb.Size = New-Object System.Drawing.Size(465, 24)
        $tb.Text = "$($cell.Value)"
        $tb.Anchor = "Top,Left,Right"
        $editForm.Controls.Add($tb)

        $btnOk = New-Object System.Windows.Forms.Button
        $btnOk.Location = New-Object System.Drawing.Point(310, 50)
        $btnOk.Size = New-Object System.Drawing.Size(75, 30)
        $btnOk.Text = "OK"
        $btnOk.DialogResult = "OK"
        $btnOk.FlatStyle = "Flat"
        $editForm.Controls.Add($btnOk)
        $editForm.AcceptButton = $btnOk

        $btnCn = New-Object System.Windows.Forms.Button
        $btnCn.Location = New-Object System.Drawing.Point(395, 50)
        $btnCn.Size = New-Object System.Drawing.Size(75, 30)
        $btnCn.Text = "Cancel"
        $btnCn.DialogResult = "Cancel"
        $btnCn.FlatStyle = "Flat"
        $editForm.Controls.Add($btnCn)
        $editForm.CancelButton = $btnCn

        if ($editForm.ShowDialog() -eq "OK") {
            $cell.Value = $tb.Text
        }
    })

    # Columns
    $colKey = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colKey.Name = "key"; $colKey.HeaderText = "Key"; $colKey.FillWeight = 12
    $colShort = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colShort.Name = "short"; $colShort.HeaderText = "Short"; $colShort.FillWeight = 10
    $colPort = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPort.Name = "port"; $colPort.HeaderText = "Port"; $colPort.FillWeight = 8
    $colDir = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDir.Name = "dir"; $colDir.HeaderText = "Dir"; $colDir.FillWeight = 35
    $colCmd = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCmd.Name = "cmd"; $colCmd.HeaderText = "Cmd"; $colCmd.FillWeight = 35

    $grid.Columns.Add($colKey) | Out-Null
    $grid.Columns.Add($colShort) | Out-Null
    $grid.Columns.Add($colPort) | Out-Null
    $grid.Columns.Add($colDir) | Out-Null
    $grid.Columns.Add($colCmd) | Out-Null
    $form.Controls.Add($grid)

    # Load current config
    try {
        $json = Get-Content $script:configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($svc in $json) {
            $grid.Rows.Add($svc.key, $svc.short, $svc.port, $svc.dir, $svc.cmd) | Out-Null
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to load config: $($_.Exception.Message)",
            "Settings", "OK", "Error")
    }

    # Bottom buttons (anchored to bottom)
    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Location = New-Object System.Drawing.Point(10, 320)
    $btnAdd.Size = New-Object System.Drawing.Size(70, 30)
    $btnAdd.Text = "+ Add"
    $btnAdd.FlatStyle = "Flat"
    $btnAdd.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnAdd.Anchor = "Bottom,Left"
    $btnAdd.Add_Click({ $grid.Rows.Add("new-svc", "New", "3000", "C:\", "echo hello") | Out-Null })
    $form.Controls.Add($btnAdd)

    $btnDel = New-Object System.Windows.Forms.Button
    $btnDel.Location = New-Object System.Drawing.Point(85, 320)
    $btnDel.Size = New-Object System.Drawing.Size(80, 30)
    $btnDel.Text = "- Remove"
    $btnDel.FlatStyle = "Flat"
    $btnDel.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
    $btnDel.Anchor = "Bottom,Left"
    $btnDel.Add_Click({
        foreach ($row in @($grid.SelectedRows)) {
            if (-not $row.IsNewRow) { $grid.Rows.Remove($row) }
        }
    })
    $form.Controls.Add($btnDel)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Location = New-Object System.Drawing.Point(170, 320)
    $btnBrowse.Size = New-Object System.Drawing.Size(80, 30)
    $btnBrowse.Text = "Browse..."
    $btnBrowse.FlatStyle = "Flat"
    $btnBrowse.Anchor = "Bottom,Left"
    $btnBrowse.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = "Select service directory"
        if ($fbd.ShowDialog() -eq "OK" -and $grid.CurrentRow) {
            $grid.CurrentRow.Cells["dir"].Value = $fbd.SelectedPath
        }
    })
    $form.Controls.Add($btnBrowse)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Location = New-Object System.Drawing.Point(620, 320)
    $btnSave.Size = New-Object System.Drawing.Size(70, 30)
    $btnSave.Text = "Save"
    $btnSave.FlatStyle = "Flat"
    $btnSave.ForeColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
    $btnSave.Anchor = "Bottom,Right"
    $btnSave.Add_Click({
        $newConfig = @()
        foreach ($row in $grid.Rows) {
            if ($row.IsNewRow) { continue }
            $k = "$($row.Cells['key'].Value)".Trim()
            $s = "$($row.Cells['short'].Value)".Trim()
            $p = "$($row.Cells['port'].Value)".Trim()
            $d = "$($row.Cells['dir'].Value)".Trim()
            $c = "$($row.Cells['cmd'].Value)".Trim()
            if (-not $k -or -not $p) { continue }
            $label = "$s :$p"
            $newConfig += [ordered]@{ key=$k; label=$label; short=$s; port=[int]$p; dir=$d; cmd=$c }
        }
        if ($newConfig.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("At least one service is required.", "Settings", "OK", "Warning")
            return
        }
        $newConfig | ConvertTo-Json -Depth 3 | Set-Content $script:configPath -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show(
            "Saved. Restart DevLauncher to apply changes.",
            "Settings", "OK", "Information")
        $form.Close()
    })
    $form.Controls.Add($btnSave)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(695, 320)
    $btnCancel.Size = New-Object System.Drawing.Size(70, 30)
    $btnCancel.Text = "Cancel"
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.Anchor = "Bottom,Right"
    $btnCancel.Add_Click({ $form.Close() })
    $form.Controls.Add($btnCancel)

    $form.ShowDialog() | Out-Null
}

function Update-Dashboard {
    foreach ($key in $script:services.Keys) {
        $svc = $script:services[$key]
        $active = Test-PortActive $svc.Port
        $isStarting = $script:startingSet[$key] -eq $true

        $lbl = $script:dashLabels[$key]
        $btns = $script:dashBtns[$key]

        $isError = $script:errorSet[$key] -eq $true

        if ($isError) {
            $lbl.Text = "$([char]0x2716) $($svc.Short) :$($svc.Port) Error - Cmd 확인"
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
            $btns.Start.Text = "Restart"
            $btns.Start.Enabled = $true
            $btns.Stop.Enabled = $true
        } elseif ($isStarting -and -not $active) {
            $elapsedSec = 0
            if ($script:startTimes[$key]) {
                $elapsedSec = [int]([DateTime]::Now - $script:startTimes[$key]).TotalSeconds
            }
            $timeText = "${elapsedSec}s"
            $est = $script:startHistory[$key]
            if ($est -and $est -gt 0) {
                $remain = [Math]::Max(0, $est - $elapsedSec)
                $timeText = "${elapsedSec}s / ~${est}s (${remain}s left)"
            }
            $lbl.Text = "$([char]0x25E6) $($svc.Short) :$($svc.Port) $timeText"
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(180, 140, 0)
            $btns.Start.Text = "Start"
            $btns.Start.Enabled = $false
            $btns.Stop.Enabled = $false
        } elseif ($active) {
            $lbl.Text = "$([char]0x25CF) $($svc.Short) :$($svc.Port) Running"
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
            $btns.Start.Text = "Restart"
            $btns.Start.Enabled = $true
            $btns.Stop.Enabled = $true
        } else {
            $lbl.Text = "$([char]0x25CB) $($svc.Short) :$($svc.Port) Stopped"
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)
            $btns.Start.Text = "Start"
            $btns.Start.Enabled = $true
            $btns.Stop.Enabled = $false
        }
        $btns.Console.Enabled = ($script:cmdPids[$key] -and $script:cmdPids[$key] -gt 0)
        # Cmd button style: error(pulse) > visible(blue) > hidden(default)
        if (-not $isError) {
            if ($script:cmdVisible[$key]) {
                $btns.Console.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
                $btns.Console.ForeColor = [System.Drawing.Color]::White
                $btns.Console.Text = "Cmd"
            } else {
                $btns.Console.BackColor = [System.Drawing.SystemColors]::Control
                $btns.Console.ForeColor = [System.Drawing.SystemColors]::ControlText
                $btns.Console.Text = "Cmd"
            }
        }
    }
    # Update toggle button text
    $anyVisible = $false
    foreach ($k in $script:services.Keys) {
        if ($script:cmdVisible[$k]) { $anyVisible = $true; break }
    }
    $script:btnToggleCmd.Text = if ($anyVisible) { "Hide Cmd" } else { "Show Cmd" }
    # All Start 버튼 중복 클릭 방지
    $isStarting = ($script:startQueue.Count -gt 0 -or $script:startingSet.Count -gt 0)
    if ($script:btnAllStart) {
        $script:btnAllStart.Enabled = -not $isStarting
        $script:btnAllStart.Text = if ($isStarting) { "Starting..." } else { "All Start" }
    }
}

# ═══════════════════════════════════════════════
# Tray Setup
# ═══════════════════════════════════════════════
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Icon = New-TrayIcon "stopped"
$script:tray.Text = "Dev Server Launcher"
$script:tray.Visible = $true
$script:tray.ContextMenuStrip = Build-TrayMenu

# Double-click → open dashboard
$script:tray.Add_MouseDoubleClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Update-Dashboard
        $script:dashboard.Show()
        $script:dashboard.BringToFront()
        $script:dashboard.Activate()
    }
})
# Right-click → rebuild menu
$script:tray.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $script:tray.ContextMenuStrip = Build-TrayMenu
    }
})

# ═══════════════════════════════════════════════
# Timers
# ═══════════════════════════════════════════════

# Status refresh (icon + tooltip + dashboard + startingSet cleanup)
$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 2000
$script:timer.Add_Tick({
    # Clean up startingSet: port is now active → no longer "Starting"
    $removeKeys = @()
    foreach ($k in @($script:startingSet.Keys)) {
        if (Test-PortActive $script:services[$k].Port) {
            $removeKeys += $k
            # Save startup duration to history
            if ($script:startTimes[$k]) {
                $elapsed = ([DateTime]::Now - $script:startTimes[$k]).TotalSeconds
                $script:startHistory[$k] = [int]$elapsed
                $script:startTimes.Remove($k)
            }
        }
    }
    foreach ($k in $removeKeys) { $script:startingSet.Remove($k) }
    # Persist history if changed
    if ($removeKeys.Count -gt 0) {
        try { $script:startHistory | ConvertTo-Json | Set-Content $script:historyPath -Encoding UTF8 } catch {}
    }

    # Error detection: port drop + startup timeout
    foreach ($k in $script:services.Keys) {
        if ($script:errorSet[$k]) { continue }
        $portActive = Test-PortActive $script:services[$k].Port
        $isStarting = $script:startingSet[$k] -eq $true

        # Track "was running" (port was active at some point)
        if ($portActive) { $script:wasRunning[$k] = $true }

        # Port drop: was running but port went down
        if ($script:wasRunning[$k] -and -not $portActive -and -not $isStarting) {
            $script:errorSet[$k] = $true
            $script:wasRunning.Remove($k)
            $script:tray.ShowBalloonTip(3000, "Error",
                "$($script:services[$k].Short) :$($script:services[$k].Port) - 오류 발생. Cmd를 확인하세요.",
                [System.Windows.Forms.ToolTipIcon]::Error)
        }

        # Startup timeout: starting too long without port coming up
        if ($isStarting -and $script:startTimes[$k]) {
            $elapsed = ([DateTime]::Now - $script:startTimes[$k]).TotalSeconds
            $timeout = 180
            $hist = $script:startHistory[$k]
            if ($hist -and $hist -gt 0) { $timeout = [Math]::Max([int]($hist * 2.5), 120) }
            if ($elapsed -gt $timeout) {
                $script:errorSet[$k] = $true
                $script:startingSet.Remove($k)
                $script:startTimes.Remove($k)
                $script:tray.ShowBalloonTip(3000, "Timeout",
                    "$($script:services[$k].Short) :$($script:services[$k].Port) - 시작 시간 초과. Cmd를 확인하세요.",
                    [System.Windows.Forms.ToolTipIcon]::Error)
            }
        }
    }

    Update-TrayIcon
    if ($script:dashboard -and $script:dashboard.Visible) { Update-Dashboard }
})
$script:timer.Start()

# Sequential start timer (fires once per service, avoids UI blocking)
$script:startQueue = [System.Collections.ArrayList]::new()
$script:startTotal = 0
$script:startTimer = New-Object System.Windows.Forms.Timer
$script:startTimer.Interval = 300
$script:startTimer.Add_Tick({
    if ($script:startQueue.Count -eq 0) {
        $script:startTimer.Stop()
        $script:startTotal = 0
        # startingSet은 여기서 지우지 않음 — 2초 타이머가 포트 올라오면 자동 제거
        Update-TrayIcon
        return
    }
    $key = $script:startQueue[0]
    $script:startQueue.RemoveAt(0)
    $svc = $script:services[$key]
    $done = $script:startTotal - $script:startQueue.Count
    $script:tray.Text = "Starting $($svc.Short)... [$done/$script:startTotal]"
    Start-Svc $key $true   # quiet mode
})

# Pulse animation timer for error state (Cmd button flashing red)
$script:pulseTimer = New-Object System.Windows.Forms.Timer
$script:pulseTimer.Interval = 600
$script:pulseTimer.Add_Tick({
    $script:pulseState = -not $script:pulseState
    $hasError = $false
    foreach ($k in $script:services.Keys) {
        if ($script:errorSet[$k]) { $hasError = $true; break }
    }
    if (-not $hasError) { return }
    if ($script:dashboard -and $script:dashboard.Visible) {
        foreach ($k in $script:services.Keys) {
            $btn = $script:dashBtns[$k].Console
            if ($script:errorSet[$k]) {
                if ($script:pulseState) {
                    $btn.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
                    $btn.ForeColor = [System.Drawing.Color]::White
                } else {
                    $btn.BackColor = [System.Drawing.Color]::FromArgb(254, 226, 226)
                    $btn.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
                }
                $btn.Text = "Cmd!"
                $btn.Enabled = $true
            }
        }
    }
})
$script:pulseTimer.Start()

# ═══════════════════════════════════════════════
# Init & Run
# ═══════════════════════════════════════════════
Update-TrayIcon
Update-Dashboard
$script:dashboard.Show()
$script:dashboard.BringToFront()
$script:dashboard.Activate()

$hiddenForm = New-Object System.Windows.Forms.Form
$hiddenForm.WindowState = "Minimized"
$hiddenForm.ShowInTaskbar = $false
$hiddenForm.Opacity = 0
$hiddenForm.Add_FormClosing({
    $script:timer.Stop()
    $script:startTimer.Stop()
    $script:pulseTimer.Stop()
    # Kill all running service processes
    foreach ($k in $script:services.Keys) {
        if ($script:cmdPids[$k]) {
            try { & taskkill /F /T /PID $script:cmdPids[$k] 2>$null | Out-Null } catch {}
        }
        Stop-ByPort $script:services[$k].Port
    }
    $script:tray.Visible = $false
    $script:tray.Dispose()
    try { $script:mutex.ReleaseMutex() } catch {}
    try { $script:mutex.Dispose() } catch {}
})

[System.Windows.Forms.Application]::Run($hiddenForm)
