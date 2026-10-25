@echo off
chcp 65001 | Out-Null
echo 🚀 Lancement de l'API Trend TradBOT sur le port 8001...
echo.

REM Activer l'encodage UTF-8
$env:PYTHONIOENCODING='utf-8'
$env:PYTHONUTF8='1'
$env:PYTHONPATH='D:\Dev\TradBOT'

echo 📁 Répertoire de travail: %CD%
echo 🔧 Configuration Python:
echo    - PYTHONPATH: %PYTHONPATH%
echo    - PYTHONIOENCODING: %PYTHONIOENCODING%
echo    - PYTHONUTF8: %PYTHONUTF8%
echo.

echo 🔍 Vérification des dépendances...
python -c "import json, http.server, socketserver; print('✅ Modules Python disponibles')" 2>nul
if errorlevel 1 (
    echo ❌ Modules Python manquants
    echo 📦 Installation des dépendances...
    pip install pandas numpy requests
)

echo.
echo 🌐 Lancement de l'API Trend sur http://localhost:8001
echo 📚 Endpoints disponibles:
echo    - GET  /trend?symbol=EURUSD&timeframe=M1
echo    - GET  /health
echo    - GET  /status
echo.
echo 🎯 Cette API fournit des données de tendance pour l'EA SpikeHunter
echo 🔄 Appuyez sur Ctrl+C pour arrêter
echo.

REM Lancer l'API Trend
python trend_api.py

pause
