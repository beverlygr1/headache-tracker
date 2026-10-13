@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_flutter.ps1" -RunApp
set "task_app_exit=%ERRORLEVEL%"
echo.
pause
exit /b %task_app_exit%
