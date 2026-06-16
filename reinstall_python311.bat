@echo off
REM Reinstall Python 3.11.9 — Fix registry corruption

setlocal enabledelayedexpansion

echo.
echo ============================================================
echo   🔧 PYTHON 3.11.9 REINSTALLATION
echo ============================================================
echo.

set "PYTHON_PATH=C:\Users\USER\AppData\Local\Programs\Python\Python311_9"

echo Step 1: Backup existing installation...
if exist "%PYTHON_PATH%" (
    echo Found: %PYTHON_PATH%
    for /f %%A in ('dir /-s /b "%PYTHON_PATH%" 2^>nul ^| find /c /v ""') do set COUNT=%%A
    echo Files: !COUNT!
) else (
    echo Python 3.11.9 not found at %PYTHON_PATH%
)

echo.
echo Step 2: Remove corrupted installation...
if exist "%PYTHON_PATH%" (
    rmdir /s /q "%PYTHON_PATH%"
    echo Removed: %PYTHON_PATH%
) else (
    echo Already removed or not present
)

echo.
echo Step 3: Download Python 3.11.9 from python.org...
echo.
echo URL: https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
echo.
echo ⚠️  Manual Step Required:
echo   1. Download the installer from the URL above
echo   2. Run: python-3.11.9-amd64.exe
echo   3. ✅ Check: "Add Python 3.11 to PATH"
echo   4. Choose: "Customize installation"
echo   5. Enable: pip, tcl/tk, py launcher
echo   6. Choose install location (or default)
echo   7. Click Install
echo.
echo Step 4: After installation, run:
echo   python -m pip install --upgrade pip
echo   pip install -r requirements.txt
echo.
echo ============================================================
pause
