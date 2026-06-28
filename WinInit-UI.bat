@echo off
title WinInit Control Panel
:: ============================================================================
:: Launches the WinInit feature-toggle UI. No elevation needed just to choose
:: and save settings - the UI requests Admin only when you click "Launch".
:: ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0WinInit-UI.ps1"
if %errorLevel% neq 0 (
    echo.
    echo  The UI exited with an error. See the message above.
    pause
)
