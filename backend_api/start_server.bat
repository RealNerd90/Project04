@echo off
title Django Backend Server (Port 8000)
echo Starting Django Backend Server for Attendance System...
cd /d "%~dp0"

REM Try to set up adb reverse port forward if adb is found
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000 >nul 2>&1
)

python manage.py runserver 0.0.0.0:8000
pause
