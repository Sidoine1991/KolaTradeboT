@echo off
echo 🤖 Boom Rising Channel Predictor - Trading Seulement
echo ====================================================
echo.

echo 📋 Vérification des dépendances...
python -c "import MetaTrader5, pandas, numpy; print('✅ Dépendances trading installées')" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes, installation...
    echo.
    pip install MetaTrader5 pandas numpy
    if errorlevel 1 (
        echo ❌ Erreur lors de l'installation des dépendances
        pause
        exit /b 1
    )
    echo ✅ Dépendances installées avec succès
)

echo.
echo 🤖 Démarrage du bot de trading...
echo.
echo ⚠️ ATTENTION: Le trading automatique est activé!
echo ⏹️ Appuyez sur Ctrl+C pour arrêter
echo.

python boom_trading_bot.py

echo.
echo ⏹️ Bot de trading arrêté
pause
