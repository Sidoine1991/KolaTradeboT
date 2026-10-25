@echo off
echo 🚀 AngelOfSpike avec Boom Rising Channel Display
echo ================================================
echo.

echo 📋 Vérification des dépendances...
python -c "import MetaTrader5, requests, threading; print('✅ Dépendances installées')" 2>nul
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
echo 🔍 Vérification de MT5...
python -c "import MetaTrader5 as mt5; mt5.initialize(); print('✅ MT5 connecté' if mt5.terminal_info().connected else '❌ MT5 non connecté')" 2>nul
if errorlevel 1 (
    echo ❌ MetaTrader 5 n'est pas accessible
    echo    Ouvrez MT5 et connectez-vous au broker
    pause
    exit /b 1
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
echo 🚀 Démarrage du système complet AngelOfSpike avec Boom Display...
echo.

echo 📊 Vérification de l'EA...
if not exist "AngelOfSpike_WithBoomDisplay.mq5" (
    echo ❌ Fichier EA non trouvé: AngelOfSpike_WithBoomDisplay.mq5
    echo    Compilez d'abord l'EA dans MetaEditor
    pause
    exit /b 1
)

echo ✅ EA AngelOfSpike_WithBoomDisplay.mq5 trouvé
echo ✅ API Boom Rising Channel Predictor accessible
echo ✅ MT5 connecté et prêt

echo.
echo 🎯 Instructions pour utiliser le système:
echo 1. Ouvrez MetaTrader 5
echo 2. Ouvrez le graphique 'Boom 1000 Index'
echo 3. Attachez l'EA 'AngelOfSpike_WithBoomDisplay'
echo 4. Configurez les paramètres selon vos besoins
echo 5. Activez le trading automatique
echo 6. Le cadran d'analyse Boom apparaîtra en bas à droite

echo.
echo 📊 Fonctionnalités disponibles:
echo ✅ Trading automatique AngelOfSpike
echo ✅ Affichage dynamique Boom Rising Channel
echo ✅ Prédictions en temps réel
echo ✅ Gestion des risques avancée
echo ✅ Interface utilisateur complète

echo.
echo 🔧 Configuration recommandée:
echo - Enable Trading: true
echo - Enable Boom Display: true
echo - Boom API URL: http://localhost:8002/angelofspike/trend
echo - Boom Symbol: Boom 1000 Index
echo - Boom Update Interval: 5 secondes

echo.
echo ⏹️ Le système est prêt! Attachez l'EA au graphique pour commencer.
pause
