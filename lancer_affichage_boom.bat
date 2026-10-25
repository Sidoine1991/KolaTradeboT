@echo off
echo 🚀 Affichage Dynamique Boom Rising Channel Predictor
echo ====================================================
echo.

echo 📋 Vérification des dépendances...
python -c "import MetaTrader5, requests, threading; print('✅ Dépendances affichage installées')" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes, installation...
    echo.
    pip install MetaTrader5 requests
    if errorlevel 1 (
        echo ❌ Erreur lors de l'installation des dépendances
        pause
        exit /b 1
    )
    echo ✅ Dépendances installées avec succès
)

echo.
echo 🔍 Vérification de l'API Boom...
python -c "import requests; r=requests.get('http://localhost:8002/health', timeout=5); print('✅ API Boom accessible' if r.status_code==200 else '❌ API non accessible')" 2>nul
if errorlevel 1 (
    echo ❌ L'API Boom Rising Channel Predictor n'est pas accessible
    echo    Démarrez d'abord l'API: python boom_api.py
    echo    ou utilisez: lancer_api_boom.bat
    pause
    exit /b 1
)

echo.
echo 🚀 Démarrage de l'affichage dynamique...
echo.
echo 📊 Le cadran d'analyse apparaîtra en bas à droite du graphique MT5
echo 🔄 Mise à jour automatique toutes les 5 secondes
echo ⏹️ Appuyez sur Ctrl+C pour arrêter
echo.

python boom_display_mt5.py

echo.
echo ⏹️ Affichage arrêté
pause
