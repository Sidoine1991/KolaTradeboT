@echo off
echo 🚀 API Boom Rising Channel Predictor - AngelOfSpike Integration
echo ================================================================
echo.

echo 📋 Vérification des dépendances...
python -c "import fastapi, uvicorn, pandas, numpy, matplotlib, plotly; print('✅ Dépendances API installées')" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes, installation...
    echo.
    pip install fastapi uvicorn pandas numpy matplotlib plotly
    if errorlevel 1 (
        echo ❌ Erreur lors de l'installation des dépendances
        pause
        exit /b 1
    )
    echo ✅ Dépendances installées avec succès
)

echo.
echo 🚀 Démarrage de l'API Boom Rising Channel Predictor...
echo.
echo 🌐 L'API sera disponible sur: http://localhost:8002
echo 🤖 Endpoint AngelOfSpike: http://localhost:8002/angelofspike/trend
echo 📚 Documentation: http://localhost:8002/docs
echo.
echo ⏹️ Appuyez sur Ctrl+C pour arrêter
echo.

python boom_api.py

echo.
echo ⏹️ API arrêtée
pause
