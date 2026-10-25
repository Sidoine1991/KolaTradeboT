@echo off
setlocal
cd /d %~dp0

where python >nul 2>nul
if %errorlevel% neq 0 (
  echo Python not found in PATH.
  pause
  exit /b 1
)

echo Starting Autoscan Mock API on http://localhost:8502 ...
set PORT=8502
python autoscan_mock_api.py

endlocal

