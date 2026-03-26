@echo off
:: ============================================================
::  Test-RunVisible.bat
::  Runs the monitor visibly so you can READ the actual error.
::  This window will stay open — screenshot or copy the red text.
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%ProcessMonitor.ps1"

echo Unblocking PS1 file...
powershell.exe -Command "Unblock-File -Path '%PS1%'" 2>nul

echo.
echo Launching monitor in visible mode...
echo (Read any red error text, then close this window)
echo ============================================================
echo.

powershell.exe -ExecutionPolicy Bypass -NoExit -File "%PS1%"

echo.
echo ============================================================
echo PowerShell exited. If you saw an error above, share it.
pause
