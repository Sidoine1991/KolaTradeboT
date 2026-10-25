@echo off
echo ========================================
echo    PIPELINE ML AUTOMATISÉ - TRADING BOT
echo ========================================
echo.

REM Activation de l'environnement virtuel
echo [1/3] Activation de l'environnement virtuel...
call .venv\Scripts\activate.bat

REM Vérification des dépendances
echo [2/3] Vérification des dépendances...
python -c "import sklearn, pandas, numpy, ta" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes. Installation...
    pip install scikit-learn pandas numpy ta
)

REM Lancement du pipeline
echo [3/3] Lancement du pipeline ML...
echo.
echo 🚀 Interface utilisateur disponible
echo 📊 Utilisez l'option 7 pour un test rapide
echo.
python launch_ml_pipeline.py

pause
