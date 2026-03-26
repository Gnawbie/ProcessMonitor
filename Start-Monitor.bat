@echo off
:: ============================================================
::  Start-Monitor.bat  -  Launch the process monitor silently
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "PID_FILE=%USERPROFILE%\ProcessMonitorLogs\.monitor.pid"
set "VBS=%SCRIPT_DIR%Start-Monitor.vbs"

echo ============================================================
echo  ProcessMonitor - Start
echo ============================================================
echo.
echo  PID file path : %PID_FILE%
echo  PID file exists?

if exist "%PID_FILE%" (
    echo  YES - reading contents...
    echo  Raw contents:
    type "%PID_FILE%"
    echo.
    echo  PowerShell-trimmed contents:
    for /f "usebackq delims=" %%A in (`powershell -Command "(Get-Content '%PID_FILE%').Trim()"`) do set "RUNNING_PID=%%A"
    echo  [%RUNNING_PID%]
    echo.
    echo  Is that PID actually alive?
    powershell -Command "$p = Get-Process -Id %RUNNING_PID% -ErrorAction SilentlyContinue; if ($p) { Write-Host ('  YES - ' + $p.Name + ' is running') } else { Write-Host '  NO - that PID is dead/stale' }"
    echo.
    echo  Any PowerShell running ProcessMonitor.ps1?
    powershell -Command "$r = Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like '*ProcessMonitor.ps1*' }; if ($r) { Write-Host ('  YES - PID ' + $r.ProcessId + ' : ' + $r.CommandLine) } else { Write-Host '  NO - not found' }"
    echo.
    pause
    exit /b 0
)

echo  NO - proceeding to launch...
echo.

:: Launch silently via VBScript (no console window)
wscript.exe "%VBS%"

:: Wait up to 6 seconds for the PID file to appear
set WAITED=0
:WAIT_FOR_PID
if exist "%PID_FILE%" goto STARTED
timeout /t 1 /nobreak >nul
set /a WAITED+=1
if %WAITED% lss 6 goto WAIT_FOR_PID

echo WARNING: Monitor did not start - PID file never appeared.
goto END

:STARTED
for /f "usebackq delims=" %%A in (`powershell -Command "(Get-Content '%PID_FILE%').Trim()"`) do set "NEW_PID=%%A"
echo ProcessMonitor started successfully!
echo  PID      : %NEW_PID%
echo  Log dir  : %USERPROFILE%\ProcessMonitorLogs\

:END
echo.
pause
