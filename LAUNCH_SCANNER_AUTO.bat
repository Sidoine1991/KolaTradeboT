@echo off
REM Auto-detect Python from actual system and launch scanner

setlocal enabledelayedexpansion

title Perfect Scanner Launcher

cls

echo.
echo =========================================================
echo PERFECT OPPORTUNITIES SCANNER — AUTO LAUNCH
echo =========================================================
echo.
echo Detecting Python...
echo.

REM Try the most reliable Python paths found on this system
set PYTHON_PATH=

REM Check 1: Python 3.14 via uv
if exist "C:\Users\USER\AppData\Roaming\uv\python\cpython-3.14.0-windows-x86_64-none\python.exe" (
    set PYTHON_PATH=C:\Users\USER\AppData\Roaming\uv\python\cpython-3.14.0-windows-x86_64-none\python.exe
    echo [OK] Found Python 3.14 (uv)
    goto :LAUNCH
)

REM Check 2: Python 3.12 via uv
if exist "C:\Users\USER\AppData\Roaming\uv\python\cpython-3.12.13-windows-x86_64-none\python.exe" (
    set PYTHON_PATH=C:\Users\USER\AppData\Roaming\uv\python\cpython-3.12.13-windows-x86_64-none\python.exe
    echo [OK] Found Python 3.12 (uv)
    goto :LAUNCH
)

REM Check 3: Python 3.11 via uv
if exist "C:\Users\USER\AppData\Roaming\uv\python\cpython-3.11.15-windows-x86_64-none\python.exe" (
    set PYTHON_PATH=C:\Users\USER\AppData\Roaming\uv\python\cpython-3.11.15-windows-x86_64-none\python.exe
    echo [OK] Found Python 3.11 (uv)
    goto :LAUNCH
)

REM Check 4: Python 3.11 embedded
if exist "C:\Python311_embedded\python.exe" (
    set PYTHON_PATH=C:\Python311_embedded\python.exe
    echo [OK] Found Python 3.11 (embedded)
    goto :LAUNCH
)

REM Check 5: Try 'python' in PATH
for /f "delims=" %%i in ('where python 2^>nul') do (
    set PYTHON_PATH=%%i
    echo [OK] Found Python in PATH
    goto :LAUNCH
)

REM If we get here, Python not found
echo [ERROR] Python not found!
echo.
echo Please install Python from: https://www.python.org/downloads/
echo.
pause
exit /b 1

:LAUNCH

echo Path: %PYTHON_PATH%
echo.

REM Verify Python works
echo Verifying Python...
"%PYTHON_PATH%" --version
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python verification failed!
    pause
    exit /b 1
)

echo.

REM Create logs directory
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

echo =========================================================
echo LAUNCHING SERVICES
echo =========================================================
echo.

REM Check if scripts exist
if not exist "D:\Dev\TradBOT\Python\ai_server.py" (
    echo [ERROR] ai_server.py not found!
    pause
    exit /b 1
)

if not exist "D:\Dev\TradBOT\Python\perfect_opportunity_scanner.py" (
    echo [ERROR] perfect_opportunity_scanner.py not found!
    pause
    exit /b 1
)

echo [1] Starting AI Server (port 8000)...
start "TradBOT AI Server" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo AI SERVER RUNNING && ^
     echo ========================================== && ^
     echo Python: %PYTHON_PATH% && ^
     echo. && ^
     "%PYTHON_PATH%" ai_server.py && ^
     pause"

timeout /t 5

echo [2] Starting Perfect Scanner...
start "TradBOT Perfect Scanner" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo PERFECT OPPORTUNITIES SCANNER RUNNING && ^
     echo ========================================== && ^
     echo Python: %PYTHON_PATH% && ^
     echo. && ^
     "%PYTHON_PATH%" perfect_opportunity_scanner.py && ^
     pause"

timeout /t 3

echo [3] Opening Dashboard in browser...
start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo =========================================================
echo SUCCESS! SCANNER LAUNCHED
echo =========================================================
echo.
echo Python: %PYTHON_PATH%
echo.
echo 3 Windows opened:
echo   [1] AI Server Console
echo   [2] Perfect Scanner Console
echo   [3] Dashboard Browser
echo.
echo Monitoring:
echo   Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   Logs: D:\Dev\TradBOT\logs\scanner.log
echo   API: http://localhost:8000/perfect-opportunities
echo.
echo WhatsApp Alerts:
echo   Sent every 2 minutes when perfect opportunities exist
echo.

pause
