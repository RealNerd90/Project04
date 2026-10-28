@echo off
title "Start Attendance Backend & Mobile App"
cd /d "%~dp0"

echo [1/2] Setting up ADB Reverse Port Forwarding for Android Emulator / Devices...
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
)

echo [2/2] Starting Django Backend in a new window...
start "Django Backend Server" cmd /k "cd /d "%~dp0backend_api" && python manage.py runserver 0.0.0.0:8000"

echo.
echo Backend server is running at http://127.0.0.1:8000 (accessible on emulator via 10.0.2.2:8000 and localhost:8000).
echo Now starting Flutter mobile app...
cd /d "%~dp0mobile_app"
call flutter run
pause
