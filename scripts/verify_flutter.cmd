@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_flutter.ps1"
set "task_check_exit=%ERRORLEVEL%"
echo.
pause
exit /b %task_check_exit%
