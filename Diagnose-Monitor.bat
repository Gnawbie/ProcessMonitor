@echo off
:: ============================================================
::  Diagnose-Monitor.bat  —  Run the monitor visibly to see errors
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%ProcessMonitor.ps1"

echo ============================================================
echo  ProcessMonitor Diagnostics
echo ============================================================
echo.

:: ── Check 1: Does the PS1 file exist? ────────────────────────
if not exist "%PS1%" (
    echo [FAIL] ProcessMonitor.ps1 not found at:
    echo        %PS1%
    echo.
    echo  Make sure all files are in the same folder.
    goto END
)
echo [OK]   ProcessMonitor.ps1 found

:: ── Check 2: Unblock the PS1 (fixes "downloaded file" block) ─
echo [....] Unblocking PS1 file...
powershell.exe -Command "Unblock-File -Path '%PS1%'" >nul 2>&1
echo [OK]   Unblock-File ran (safe even if not needed)

:: ── Check 3: Show current execution policy ───────────────────
echo.
echo Current execution policies:
powershell.exe -Command "Get-ExecutionPolicy -List | Format-Table -AutoSize"
echo.

:: ── Check 4: Test-run in a VISIBLE window ────────────────────
echo [....] Launching monitor in a visible window for 10 seconds.
echo        Watch for any red error text...
echo.
echo  (Close the window manually if it doesn't auto-close)
echo.

start "ProcessMonitor TEST" powershell.exe ^
  -ExecutionPolicy Bypass ^
  -NoExit ^
  -File "%PS1%"

echo After confirming no errors, close that window and run Start-Monitor.bat normally.
echo.

:END
pause
