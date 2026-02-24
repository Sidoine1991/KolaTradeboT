@echo off
echo ========================================
echo   Démarrage du Serveur IA TradBOT
echo ========================================
echo.

REM Vérifier si l'environnement virtuel existe
if not exist "venv\Scripts\python.exe" (
    echo ❌ Environnement virtuel venv non trouvé!
    echo 💡 Créez-le avec:
    echo    python -m venv venv
    echo    venv\Scripts\activate
    echo    pip install fastapi uvicorn pandas numpy requests joblib
    echo.
    pause
    exit /b 1
)

echo ✅ Environnement virtuel trouvé
echo 🚀 Démarrage du serveur IA...
echo.

REM Activer l'environnement virtuel et démarrer le serveur
call venv\Scripts\activate.bat
python ai_server.py

echo.
echo 🛑 Serveur IA arrêté
pause
