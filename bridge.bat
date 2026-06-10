@echo off
REM TradBOT Bridge Launcher
REM Starts all required services: AI Server + GOM Verdict Poller
REM Usage: bridge.bat

title TradBOT Bridge

SET PYTHON=C:\Users\USER\AppData\Local\Programs\Python\Python311\python.exe
SET TRADBOT=D:\Dev\TradBOT

echo ========================================
echo   TradBOT Bridge Launcher
echo ========================================
echo.

REM --- Kill any existing instances ---
taskkill /F /IM python.exe /FI "WINDOWTITLE eq TradBOT*" >nul 2>&1

REM --- Check TradingView CDP ---
echo [1/3] Checking TradingView MCP connection...
curl -s http://localhost:9222/json/version >nul 2>&1
if %errorlevel% neq 0 (
    echo       TradingView not in debug mode. Launch manually with:
    echo       bridge-tv.bat
    echo.
) else (
    echo       TradingView CDP: OK
)

REM --- Start AI Server ---
echo [2/3] Starting AI Server on port 8000...
taskkill /F /FI "WINDOWTITLE eq AI Server" >nul 2>&1
start "AI Server" /D "%TRADBOT%" cmd /c "%PYTHON% ai_server.py --port 8000 2>&1 | findstr /V DEBUG"
timeout /t 6 /nobreak >nul

curl -s http://127.0.0.1:8000/health >nul 2>&1
if %errorlevel% neq 0 (
    echo       AI Server: FAILED - check window "AI Server"
) else (
    echo       AI Server: OK (http://127.0.0.1:8000)
)

REM --- Start GOM Verdict Poller ---
echo [3/3] Starting GOM Verdict Poller (30s interval)...
start "GOM Poller" /D "%TRADBOT%" cmd /c "%PYTHON% Python\gom_verdict_poller.py --interval 30"
timeout /t 3 /nobreak >nul
echo       GOM Poller: started

echo.
echo ========================================
echo   Bridge running. Close windows to stop.
echo ========================================
echo.
echo   AI Server  : http://127.0.0.1:8000
echo   GOM Poller : 30s interval
echo   Logs       : whatsapp_alerts.log
echo.
pause
