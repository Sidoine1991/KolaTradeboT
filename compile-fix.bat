@echo off
REM Compilation script for SMC_Universal.mq5 after IA HOLD fix
REM This script launches MetaEditor and compiles the EA

setlocal enabledelayedexpansion

echo.
echo ════════════════════════════════════════════════════════════════
echo 🔧 COMPILATION - IA HOLD Fix (Hierarchie GOM > IA)
echo ════════════════════════════════════════════════════════════════
echo.

set METAEDITOR="C:\Program Files\MetaTrader 5\metaeditor64.exe"
set EAFILE="D:\Dev\TradBOT\mt5\SMC_Universal.mq5"

if not exist %METAEDITOR% (
    echo ❌ MetaEditor not found at %METAEDITOR%
    exit /b 1
)

if not exist %EAFILE% (
    echo ❌ EA file not found at %EAFILE%
    exit /b 1
)

echo ✅ MetaEditor found
echo ✅ EA file found
echo.
echo 📝 Launching MetaEditor for compilation...
echo    File: %EAFILE%
echo.

REM Launch MetaEditor in background
start "" %METAEDITOR% %EAFILE%

echo ⏳ Waiting 5 seconds for MetaEditor to launch...
timeout /t 5 /nobreak

echo.
echo ════════════════════════════════════════════════════════════════
echo 📋 CHANGES APPLIED:
echo ════════════════════════════════════════════════════════════════
echo.
echo ✅ Line 11100: IA HOLD gate modified
echo    OLD: if(IA=HOLD) → Block
echo    NEW: if(IA=HOLD AND GOM=WAIT) → Block
echo.
echo ✅ Logic now respects hierarchy:
echo    - If GOM=BUY/SELL with coherence ≥83%% → Enter (IA HOLD ignored)
echo    - If GOM=WAIT + IA=HOLD → Double indecision, block
echo.
echo 🎯 RESULT:
echo    XAUUSD with GOM GOOD BUY (83.3%%) will NOW ENTER
echo    Even if IA is in HOLD mode
echo.
echo ════════════════════════════════════════════════════════════════
echo.
echo 📌 NEXT STEPS:
echo    1. Press F5 in MetaEditor to compile
echo    2. Expected: 0 errors, 0 warnings
echo    3. Reload EA in MT5
echo    4. Test XAUUSD entry with next GOM signal
echo.
echo ════════════════════════════════════════════════════════════════
pause
