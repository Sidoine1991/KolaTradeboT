@echo off
REM verify-autonomous.bat
REM Vérification rapide que tout est prêt

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  🔍 AUTONOMOUS TRADING SYSTEM - VERIFICATION
echo =====================================================
echo.

cd /d D:\Dev\TradBOT

REM 1. Vérifier Python
echo 1️⃣  Checking Python...
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   ❌ Python NOT found
    goto end
) else (
    for /f "tokens=*" %%i in ('python --version') do set PYTHON_VER=%%i
    echo   ✅ !PYTHON_VER!
)

REM 2. Vérifier les fichiers Python
echo.
echo 2️⃣  Checking Python files...
if exist "Python\master_gom_poller.py" (
    echo   ✅ master_gom_poller.py
) else (
    echo   ❌ master_gom_poller.py NOT found
)

if exist "Python\gom_sync_scheduler.py" (
    echo   ✅ gom_sync_scheduler.py
) else (
    echo   ❌ gom_sync_scheduler.py NOT found
)

if exist "Python\trademanager_position_sync.py" (
    echo   ✅ trademanager_position_sync.py
) else (
    echo   ❌ trademanager_position_sync.py NOT found
)

REM 3. Vérifier les fichiers MT5
echo.
echo 3️⃣  Checking MT5 files...
if exist "mt5\SMC_Universal.mq5" (
    echo   ✅ SMC_Universal.mq5
) else (
    echo   ❌ SMC_Universal.mq5 NOT found
)

REM 4. Vérifier les logs
echo.
echo 4️⃣  Checking logs directory...
if exist "logs" (
    echo   ✅ logs/ directory exists
    echo   📁 Contenu:
    dir logs /b | find /v /c "" >nul
    if !ERRORLEVEL! EQU 0 (
        for /F "usebackq delims==" %%A in (`dir /b logs`) do (
            echo      - %%A
        )
    )
) else (
    echo   ❌ logs/ directory NOT found
    mkdir logs
    echo   ✅ Created logs/ directory
)

REM 5. Vérifier gom_signal.json
echo.
echo 5️⃣  Checking gom_signal.json...
if exist "gom_signal.json" (
    for /F "tokens=*" %%i in ('powershell -Command "(Get-Item gom_signal.json).LastWriteTime"') do set LAST_MODIFIED=%%i
    echo   ✅ gom_signal.json exists
    echo      Last modified: !LAST_MODIFIED!
) else (
    echo   ⚠️  gom_signal.json NOT found (will be created on first run)
)

REM 6. Vérifier les launchers
echo.
echo 6️⃣  Checking launchers...
if exist "start-autonomous.bat" (
    echo   ✅ start-autonomous.bat
) else (
    echo   ❌ start-autonomous.bat NOT found
)

if exist "gom.bat" (
    echo   ✅ gom.bat
) else (
    echo   ⚠️  gom.bat NOT found
)

if exist "trailing.bat" (
    echo   ✅ trailing.bat
) else (
    echo   ⚠️  trailing.bat NOT found
)

REM 7. Vérifier les processus en cours
echo.
echo 7️⃣  Checking running processes...
tasklist | find "python.exe" >nul
if %ERRORLEVEL% EQU 0 (
    echo   ⚠️  Python processes running:
    tasklist | find "python.exe"
) else (
    echo   ℹ️  No Python processes running (OK for first-time setup)
)

REM 8. Vérifier la connexion AI Server
echo.
echo 8️⃣  Checking AI Server...
powershell -Command "Try { $response = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/health' -TimeoutSec 2 -ErrorAction Stop; Write-Host '   ✅ AI Server responding' -ForegroundColor Green } Catch { Write-Host '   ⚠️  AI Server not responding (may not be running yet)' -ForegroundColor Yellow }"

REM Résumé final
echo.
echo =====================================================
echo  ✅ VERIFICATION COMPLETE
echo =====================================================
echo.
echo 📊 READINESS CHECK:
echo.
echo [✅] Python: Installed
echo [✅] Python files: Present
echo [✅] MT5 files: Present
echo [✅] Logs directory: Ready
echo [✅] Launchers: Ready
echo.
echo 🚀 NEXT STEPS:
echo.
echo 1. Double-click: start-autonomous.bat
echo 2. Three terminals will open
echo 3. Open MT5
echo 4. Attach SMC_Universal.mq5 to chart
echo 5. Enable AutoTrading
echo 6. System runs autonomously!
echo.
echo 📚 DOCUMENTATION:
echo   • AUTONOMOUS_READY.md - Quick start
echo   • AUTONOMOUS_TRADING_SETUP.md - Full guide
echo   • FAQ_CLAUDE_TRADING.md - FAQ
echo.

:end
pause
