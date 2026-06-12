@echo off
REM Python wrapper - uses working Python 3.14 installation
REM Python 3.11_9 is corrupted (registry issue), so we use Python 3.14

setlocal enabledelayedexpansion

REM Use working Python 3.14 installation
set "PYTHON_PATH=C:\Python314_old\python.exe"

REM Reset environment to avoid corruption
set PYTHONHOME=
set PYTHONPATH=

if not exist "%PYTHON_PATH%" (
    echo ERROR: Python not found at %PYTHON_PATH%
    exit /b 1
)

"%PYTHON_PATH%" %*
exit /b %ERRORLEVEL%
