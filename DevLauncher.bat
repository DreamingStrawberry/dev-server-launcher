@echo off
REM CLI mode: pass args directly (no instance kill, no log redirect)
if not "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DevLauncher.ps1" %*
    exit /b %ERRORLEVEL%
)
REM GUI mode: kill previous instances, then launch
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"name='powershell.exe'\" -EA SilentlyContinue | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match 'DevLauncher\.ps1' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }" 2>nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DevLauncher.ps1" 2>"%~dp0DevLauncher.log"
if %ERRORLEVEL% NEQ 0 (
    echo [오류] 종료코드: %ERRORLEVEL% >> "%~dp0DevLauncher.log"
)
