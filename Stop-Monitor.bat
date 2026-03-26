@echo off
:: ============================================================
::  Stop-Monitor.bat  -  Stop the process monitor
:: ============================================================

set "PID_FILE=%USERPROFILE%\ProcessMonitorLogs\.monitor.pid"
set "TMPPS=%TEMP%\stop_monitor_tmp.ps1"

echo ============================================================
echo  ProcessMonitor - Stop
echo ============================================================
echo.

:: Write a temp PS1 so we avoid all ^ escaping issues
echo $PidFile = "%PID_FILE%" > "%TMPPS%"
echo. >> "%TMPPS%"
echo Write-Host "PID file path : $PidFile" >> "%TMPPS%"
echo if (Test-Path $PidFile) { >> "%TMPPS%"
echo     $raw = Get-Content $PidFile >> "%TMPPS%"
echo     Write-Host "PID file exists : YES" >> "%TMPPS%"
echo     Write-Host "Raw contents    : [$raw]" >> "%TMPPS%"
echo     $trimmed = $raw.Trim() >> "%TMPPS%"
echo     Write-Host "Trimmed PID     : [$trimmed]" >> "%TMPPS%"
echo } else { >> "%TMPPS%"
echo     Write-Host "PID file exists : NO" >> "%TMPPS%"
echo } >> "%TMPPS%"
echo. >> "%TMPPS%"
echo Write-Host "" >> "%TMPPS%"
echo Write-Host "All powershell.exe processes:" >> "%TMPPS%"
echo $psList = Get-WmiObject Win32_Process ^| Where-Object { $_.Name -like '*powershell*' } >> "%TMPPS%"
echo foreach ($p in $psList) { Write-Host "  PID: $($p.ProcessId) | $($p.CommandLine)" } >> "%TMPPS%"
echo. >> "%TMPPS%"
echo Write-Host "" >> "%TMPPS%"
echo Write-Host "Searching for ProcessMonitor.ps1..." >> "%TMPPS%"
echo $mon = Get-WmiObject Win32_Process ^| Where-Object { $_.CommandLine -like '*ProcessMonitor.ps1*' } >> "%TMPPS%"
echo if ($mon) { >> "%TMPPS%"
echo     Write-Host "  FOUND - PID: $($mon.ProcessId)" >> "%TMPPS%"
echo     Write-Host "  Killing..." >> "%TMPPS%"
echo     Stop-Process -Id $mon.ProcessId -Force -ErrorAction SilentlyContinue >> "%TMPPS%"
echo     Start-Sleep -Seconds 1 >> "%TMPPS%"
echo     $check = Get-WmiObject Win32_Process ^| Where-Object { $_.CommandLine -like '*ProcessMonitor.ps1*' } >> "%TMPPS%"
echo     if ($check) { Write-Host "  WARNING: Still alive after kill!" } >> "%TMPPS%"
echo     else { Write-Host "  SUCCESS: Stopped." } >> "%TMPPS%"
echo } else { >> "%TMPPS%"
echo     Write-Host "  NOT FOUND - not running." >> "%TMPPS%"
echo } >> "%TMPPS%"
echo. >> "%TMPPS%"
echo if (Test-Path $PidFile) { Remove-Item $PidFile -Force; Write-Host "PID file deleted." } >> "%TMPPS%"
echo Write-Host "" >> "%TMPPS%"
echo Write-Host "Done." >> "%TMPPS%"

powershell -ExecutionPolicy Bypass -File "%TMPPS%"
del "%TMPPS%" >nul 2>&1

echo.
echo ============================================================
pause
