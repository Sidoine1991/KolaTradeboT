@echo off
echo 🤖 TradBOT - Exécuteur Automatique de Signaux
echo ================================================
echo.

REM Vérifier que Python est installé
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python n'est pas installé ou pas dans le PATH
    pause
    exit /b 1
)

echo ✅ Python détecté
echo.

REM Vérifier que l'API de signaux est disponible
echo 🔍 Vérification de l'API de signaux...
curl -s http://localhost:8001/health >nul 2>&1
if errorlevel 1 (
    echo ⚠️ API de signaux non disponible sur le port 8001
    echo 💡 Assurez-vous que l'API de signaux est démarrée
    echo.
)

echo 🚀 Lancement de l'exécuteur automatique...
echo.
echo 📋 Instructions:
echo    - L'exécuteur surveillera automatiquement les signaux
echo    - Les ordres seront exécutés sur MetaTrader 5
echo    - Appuyez sur Ctrl+C pour arrêter
echo.

REM Lancer l'exécuteur
python start_auto_executor.py

echo.
echo 🛑 Exécuteur arrêté
pause
