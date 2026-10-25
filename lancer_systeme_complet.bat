@echo off
echo 🚀 Boom Rising Channel Predictor - Système Complet
echo ====================================================
echo.

echo 📋 Vérification des dépendances...
python -c "import streamlit, plotly, pandas, numpy, matplotlib, MetaTrader5; print('✅ Toutes les dépendances sont installées')" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes, installation...
    echo.
    pip install streamlit plotly pandas numpy matplotlib MetaTrader5
    if errorlevel 1 (
        echo ❌ Erreur lors de l'installation des dépendances
        pause
        exit /b 1
    )
    echo ✅ Dépendances installées avec succès
)

echo.
echo 🔧 Test du système...
python test_boom_system.py
if errorlevel 1 (
    echo ❌ Tests échoués, vérifiez les erreurs ci-dessus
    pause
    exit /b 1
)

echo.
echo 🚀 Démarrage de l'interface Streamlit...
start /B python boom_streamlit_app.py
timeout /t 3 /nobreak >nul

echo.
echo 🤖 Démarrage du bot de trading...
start /B python boom_trading_bot.py

echo.
echo ✅ Système Boom Rising Channel Predictor démarré!
echo.
echo 🌐 Interface Web: http://localhost:8501
echo 🤖 Bot de Trading: Actif
echo 📊 Prédictions: En cours
echo.
echo ⏹️ Appuyez sur une touche pour arrêter le système...
pause >nul

echo.
echo ⏹️ Arrêt du système...
taskkill /f /im python.exe 2>nul
echo ✅ Système arrêté
pause
