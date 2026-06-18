@echo off
REM Exécute GOM Sync + WhatsApp Report — appelé par Task Scheduler
REM Exit code: 0=OK, 1=ERROR
REM Logs: D:\Dev\TradBOT\logs\gom_sync.log

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

REM Détecte le chemin complet de python.exe
for /f "delims=" %%A in ('where python') do set PYTHON_EXE=%%A

if not defined PYTHON_EXE (
    echo [ERROR] Python not found in PATH
    exit /b 1
)

REM Logs
set LOG_DIR=D:\Dev\TradBOT\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set SCRIPT=%CD%\Python\gom_sync_with_report.py

REM Exécute en mode --report (exécution unique)
"%PYTHON_EXE%" "%SCRIPT%" --report

REM Capture code de sortie
if %ERRORLEVEL% neq 0 (
    echo [ERROR] GOM Sync failed with exit code %ERRORLEVEL% >> "%LOG_DIR%\gom_sync.log"
    exit /b %ERRORLEVEL%
)

exit /b 0
