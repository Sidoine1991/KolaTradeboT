@echo off
REM ===========================================================================
REM  TradBOT WhatsApp Server Watchdog
REM  - Keep ai_server.py alive on port 8000 (WhatsApp notify endpoint)
REM  - Auto-restart if it crashes / port stops responding
REM  - Launch at Windows startup (place a shortcut to this .bat in shell:startup)
REM ===========================================================================
setlocal enabledelayedexpansion

set PYTHON="C:\Python314_old\python.exe"
set SERVER="D:\Dev\TradBOT\ai_server.py"
set PORT=8000
set LOG="D:\Dev\TradBOT\watchdog_ai_server.log"
set CHECK_URL=http://127.0.0.1:8000/notify-whatsapp

echo [%date% %time%] Watchdog demarre >> %LOG%

:loop
    REM --- Health check: POST a tiny probe, ignore result, just need HTTP 200 ---
    powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%CHECK_URL%' -Method POST -ContentType 'application/json' -Body '{\"event\":\"CUSTOM\",\"symbol\":\"WATCHDOG\",\"message\":\"ping\"}' -TimeoutSec 5 -ErrorAction Stop; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }"
    set RC=%ERRORLEVEL%

    if !RC! NEQ 0 (
        echo [%date% %time%] SERVEUR DOWN (port %PORT%) - tentative de relance... >> %LOG%
        REM Kill any stale python holding the port (best effort)
        for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTEN"') do (
            taskkill /PID %%p /F >nul 2>&1
        )
        start "" /MIN %PYTHON% -B %SERVER%
        echo [%date% %time%] Relance demandee (nouveau process python) >> %LOG%
        REM Give it time to boot (cold start can take ~30s with ML models)
        timeout /t 35 /nobreak >nul
    ) else (
        echo [%date% %time%] OK - serveur repond sur %PORT% >> %LOG%
    )

    REM Wait before next check
    timeout /t 30 /nobreak >nul
goto loop
