@echo off
cd /d "%~dp0"
if exist "build\RAVAGE-0.02-Windows\RAVAGE.exe" (
  start "" "build\RAVAGE-0.02-Windows\RAVAGE.exe"
) else (
  echo Please build the game with tools\build_windows.ps1 first.
  pause
)
