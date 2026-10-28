@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0LaunchDoorSkip.ps1"
if errorlevel 1 (
  echo.
  echo The launcher could not finish. See the message above.
  pause
)
