@echo off
REM Démarre le pipeline TradBOT auto Good/Perfect + rapports Word
REM Usage: start_pipeline_auto_goodperfect.bat [top-n] [--dry-run]

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ================================
echo Pipeline Auto Good/Perfect
echo ================================
echo Time: %date% %time%
echo.

REM Vérifier ai_server
echo Vérification ai_server...
timeout /t 2 /nobreak >nul

python Python\pipeline_auto_goodperfect.py --top-n 3 %*

pause
