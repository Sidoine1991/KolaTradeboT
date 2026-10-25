@echo off
echo ========================================
echo    LANCEMENT TRADBOT PROFESSIONAL
echo ========================================
echo.

REM Configuration de l'encodage UTF-8
chcp 65001 | Out-Null
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1
set PYTHONPATH=D:\Dev\TradBOT

echo Configuration de l'environnement...
echo PYTHONPATH: %PYTHONPATH%
echo.

REM Vérifier si l'environnement virtuel existe
if not exist ".venv\Scripts\python.exe" (
    echo ERREUR: Environnement virtuel non trouvé!
    echo Veuillez d'abord créer l'environnement virtuel avec:
    echo python -m venv .venv
    echo .venv\Scripts\activate
    echo pip install -r requirements.txt
    pause
    exit /b 1
)

echo Activation de l'environnement virtuel...
call .venv\Scripts\activate

echo.
echo Lancement de l'application Streamlit Professional...
echo URL: http://localhost:8502
echo.

REM Lancer l'application sur le port 8502
.venv\Scripts\python -X utf8 -m streamlit run frontend/app_professional.py --server.port 8502 --server.headless true

echo.
echo Application fermée.
pause
