@echo off
echo 🚀 Boom Rising Channel Predictor - Interface Seulement
echo ======================================================
echo.

echo 📋 Vérification des dépendances...
python -c "import streamlit, plotly, pandas, numpy, matplotlib; print('✅ Dépendances interface installées')" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes, installation...
    echo.
    pip install streamlit plotly pandas numpy matplotlib
    if errorlevel 1 (
        echo ❌ Erreur lors de l'installation des dépendances
        pause
        exit /b 1
    )
    echo ✅ Dépendances installées avec succès
)

echo.
echo 🚀 Démarrage de l'interface Streamlit...
echo.
echo 🌐 L'interface sera disponible sur: http://localhost:8501
echo ⏹️ Appuyez sur Ctrl+C pour arrêter
echo.

python boom_streamlit_app.py

echo.
echo ⏹️ Interface arrêtée
pause
