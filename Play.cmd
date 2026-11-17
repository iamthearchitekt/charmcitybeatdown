@echo off
setlocal
cd /d "%~dp0"
if exist "build\CharmCityBeatdown.exe" (
    start "" "build\CharmCityBeatdown.exe"
    exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch.ps1"
if errorlevel 1 pause
