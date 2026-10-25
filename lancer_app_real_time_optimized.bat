@echo off
echo ========================================
echo    TradBOT - App Real Time Optimized
echo ========================================
echo.

REM Activer l'environnement virtuel si il existe
if exist "venv\Scripts\activate.bat" (
    echo Activation de l'environnement virtuel...
    call venv\Scripts\activate.bat
)

REM Vérifier que Python est disponible
python --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Python n'est pas installe ou pas dans le PATH
    pause
    exit /b 1
)

echo Lancement de l'application real time optimisee...
echo.
echo L'application va s'ouvrir dans votre navigateur
echo Appuyez sur Ctrl+C pour arreter l'application
echo.

REM Lancer l'application Streamlit optimisée
streamlit run frontend/app_real_time.py --server.port 8503 --server.address localhost

pause
