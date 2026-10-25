@echo off
chcp 65001 | Out-Null
echo 🚀 Lancement de l'API Trend Optimisée TradBOT...
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
python -c "import json, http.server, socketserver, threading, time, requests; print('✅ Modules Python disponibles')" 2>nul
if errorlevel 1 (
    echo ❌ Modules Python manquants
    echo 📦 Installation des dépendances...
    pip install requests pandas numpy
)

echo.
echo 🌐 Lancement de l'API Trend Optimisée sur http://localhost:8001
echo 📚 Endpoints disponibles:
echo    - GET  /trend?symbol=EURUSD&timeframe=M1
echo    - GET  /health
echo    - GET  /status
echo    - GET  /performance
echo.
echo ⚡ OPTIMISATIONS MT5 ACTIVÉES:
echo    - Cache intelligent: 60 secondes
echo    - Throttling API: 10 secondes minimum
echo    - Traitement en batch: Activé
echo    - Optimisation mémoire: Activée
echo    - Réduction charge CPU: Activée
echo.
echo 🎯 Cette API est optimisée pour réduire l'impact sur MetaTrader 5
echo 🔄 Appuyez sur Ctrl+C pour arrêter
echo.

REM Lancer l'API Optimisée
python trend_api_optimized.py

pause
