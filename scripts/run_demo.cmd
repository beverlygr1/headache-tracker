@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_flutter.ps1" -RunDemo
set "task_demo_exit=%ERRORLEVEL%"
echo.
pause
exit /b %task_demo_exit%
