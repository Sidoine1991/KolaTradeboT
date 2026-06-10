@echo off
REM Launch TradingView Desktop with CDP debug port enabled
REM Run this BEFORE bridge.bat if TradingView is not already open

title TradingView CDP Launcher

echo Killing existing TradingView instances...
taskkill /F /IM TradingView.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo Starting TradingView with --remote-debugging-port=9222...
powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\WindowsApps\TradingView.Desktop_3.1.0.7818_x64__n534cwy3pjxzj\TradingView.exe' -ArgumentList '--remote-debugging-port=9222' -WorkingDirectory 'C:\Program Files\WindowsApps\TradingView.Desktop_3.1.0.7818_x64__n534cwy3pjxzj'"

echo Waiting for CDP...
:wait
timeout /t 3 /nobreak >nul
curl -s http://localhost:9222/json/version >nul 2>&1
if %errorlevel% neq 0 goto wait

echo CDP ready! TradingView is running with debug port 9222.
echo You can now run bridge.bat
pause
