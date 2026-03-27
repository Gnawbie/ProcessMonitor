@echo off
:: ============================================================
::  Start-Monitor.bat  -  Launch the process monitor silently
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "PID_FILE=%USERPROFILE%\ProcessMonitorLogs\.monitor.pid"
set "VBS=%SCRIPT_DIR%Start-Monitor.vbs"
set "TMPPS=%TEMP%\start_monitor_tmp.ps1"

echo ============================================================
echo  ProcessMonitor - Start
echo ============================================================
echo.

:: Write all logic to a temp PS1 and execute it (avoids cmd quoting issues)
echo $PidFile = "%PID_FILE%" > "%TMPPS%"
echo $VbsPath = "%VBS%" >> "%TMPPS%"
echo. >> "%TMPPS%"
echo # Check if the monitor is actually running right now >> "%TMPPS%"
echo $mon = Get-WmiObject Win32_Process ^| Where-Object { $_.CommandLine -like '*ProcessMonitor.ps1*' } >> "%TMPPS%"
echo if ($mon) { >> "%TMPPS%"
echo     Write-Host "  Monitor is already running (PID: $($mon.ProcessId))" >> "%TMPPS%"
echo     Write-Host "  Nothing to do." >> "%TMPPS%"
echo     exit 0 >> "%TMPPS%"
echo } >> "%TMPPS%"
echo. >> "%TMPPS%"
echo # Not running - remove stale PID file if present >> "%TMPPS%"
echo if (Test-Path $PidFile) { >> "%TMPPS%"
echo     Write-Host "  Stale PID file found - removing..." >> "%TMPPS%"
echo     Remove-Item $PidFile -Force >> "%TMPPS%"
echo } >> "%TMPPS%"
echo. >> "%TMPPS%"
echo # Launch silently via VBScript >> "%TMPPS%"
echo Write-Host "  Starting ProcessMonitor..." >> "%TMPPS%"
echo $shell = New-Object -ComObject WScript.Shell >> "%TMPPS%"
echo $null = $shell.Run("""$VbsPath""", 0, $false) >> "%TMPPS%"
echo. >> "%TMPPS%"
echo # Wait up to 6 seconds for the PID file to appear >> "%TMPPS%"
echo $waited = 0 >> "%TMPPS%"
echo while (-not (Test-Path $PidFile) -and $waited -lt 6) { >> "%TMPPS%"
echo     Start-Sleep -Seconds 1 >> "%TMPPS%"
echo     $waited++ >> "%TMPPS%"
echo } >> "%TMPPS%"
echo. >> "%TMPPS%"
echo if (Test-Path $PidFile) { >> "%TMPPS%"
echo     $newPid = (Get-Content $PidFile -Raw).Trim() >> "%TMPPS%"
echo     Write-Host "  ProcessMonitor started successfully!" >> "%TMPPS%"
echo     Write-Host "  PID     : $newPid" >> "%TMPPS%"
echo     Write-Host "  Log dir : $env:USERPROFILE\ProcessMonitorLogs\" >> "%TMPPS%"
echo } else { >> "%TMPPS%"
echo     Write-Host "  WARNING: Monitor did not start - PID file never appeared." >> "%TMPPS%"
echo } >> "%TMPPS%"

powershell -ExecutionPolicy Bypass -File "%TMPPS%"
del "%TMPPS%" >nul 2>&1

echo.
echo ============================================================
pause
