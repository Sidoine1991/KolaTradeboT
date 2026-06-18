@echo off
REM Find Python installation and launch scanner

setlocal enabledelayedexpansion

title Scanner Launcher — Finding Python

cls

echo.
echo =========================================================
echo PERFECT SCANNER LAUNCHER
echo =========================================================
echo.
echo Searching for Python installation...
echo.

REM Try different common Python paths
set PYTHON_FOUND=0
set PYTHON_PATH=

REM Check 1: Python 3.14
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\python.exe" (
    set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\python.exe
    set PYTHON_FOUND=1
    goto :FOUND
)

REM Check 2: Python 3.13
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python313\python.exe" (
    set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python313\python.exe
    set PYTHON_FOUND=1
    goto :FOUND
)

REM Check 3: Python 3.12
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python312\python.exe" (
    set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python312\python.exe
    set PYTHON_FOUND=1
    goto :FOUND
)

REM Check 4: Python 3.11
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python311\python.exe" (
    set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python311\python.exe
    set PYTHON_FOUND=1
    goto :FOUND
)

REM Check 5: Python in C:\Python
if exist "C:\Python\python.exe" (
    set PYTHON_PATH=C:\Python\python.exe
    set PYTHON_FOUND=1
    goto :FOUND
)

REM Check 6: Python in Program Files
if exist "C:\Program Files\Python314\python.exe" (
    set PYTHON_PATH=C:\Program Files\Python314\python.exe
    set PYTHON_FOUND=1
    goto :FOUND
)

REM Check 7: Try 'python' in PATH
for /f "delims=" %%i in ('where python 2^>nul') do (
    set PYTHON_PATH=%%i
    set PYTHON_FOUND=1
    goto :FOUND
)

:FOUND

if %PYTHON_FOUND% EQU 1 (
    echo [OK] Found Python!
    echo Path: %PYTHON_PATH%
    echo.
    echo Version:
    "%PYTHON_PATH%" --version
    echo.
) else (
    echo [ERROR] Python not found!
    echo.
    echo Checked:
    echo   - C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\
    echo   - C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python313\
    echo   - C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python312\
    echo   - C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python311\
    echo   - C:\Python\
    echo   - C:\Program Files\Python314\
    echo.
    echo Please install Python from: https://www.python.org/downloads/
    echo.
    echo Or if Python is installed elsewhere, run manually:
    echo   cd D:\Dev\TradBOT\Python
    echo   python ai_server.py
    echo   (in another window)
    echo   python perfect_opportunity_scanner.py
    echo.
    pause
    exit /b 1
)

REM Create logs directory
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

echo.
echo =========================================================
echo LAUNCHING SERVICES
echo =========================================================
echo.

echo [1] Starting AI Server...
start "TradBOT AI Server" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo AI SERVER RUNNING && ^
     echo ========================================== && ^
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
     echo. && ^
     "%PYTHON_PATH%" perfect_opportunity_scanner.py && ^
     pause"

timeout /t 3

echo [3] Opening Dashboard...
start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo =========================================================
echo SUCCESS! SCANNER LAUNCHED
echo =========================================================
echo.
echo Python Path: %PYTHON_PATH%
echo.
echo Services started:
echo   [1] AI Server (port 8000)
echo   [2] Perfect Scanner
echo   [3] Dashboard (browser)
echo.
echo Monitoring:
echo   Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   Logs: D:\Dev\TradBOT\logs\scanner.log
echo   API: http://localhost:8000/perfect-opportunities
echo.
echo WhatsApp alerts will be sent every 2 minutes when opportunities exist.
echo.

pause
