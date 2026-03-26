@echo off
:: ============================================================
::  View-Logs.bat  —  Open the log folder (and today's log)
:: ============================================================

set "LOG_DIR=%USERPROFILE%\ProcessMonitorLogs"

if not exist "%LOG_DIR%" (
    echo No log folder found yet.
    echo Start the monitor first with Start-Monitor.bat
    echo.
    pause
    exit /b 0
)

:: Open the folder in Explorer
explorer "%LOG_DIR%"

:: Also open today's log file in Notepad if it exists
for /f "tokens=1-3 delims=/-" %%a in ("%DATE%") do (
    set "TODAY_LOG=%LOG_DIR%\process_%%c-%%a-%%b.log"
    set "TODAY_ERR=%LOG_DIR%\errors_%%c-%%a-%%b.log"
)

if exist "%TODAY_LOG%" (
    echo Opening today's process log...
    start notepad "%TODAY_LOG%"
)

if exist "%TODAY_ERR%" (
    echo Opening today's error log...
    start notepad "%TODAY_ERR%"
)

exit /b 0
