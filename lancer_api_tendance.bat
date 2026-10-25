@echo off
chcp 65001 | Out-Null
echo 🚀 Lancement de l'API de Tendance TradBOT...
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
.\.venv\Scripts\python -c "import fastapi, uvicorn; print('✅ FastAPI et Uvicorn disponibles')" 2>nul
if errorlevel 1 (
    echo ❌ FastAPI ou Uvicorn non installés
    echo 📦 Installation des dépendances...
    .\.venv\Scripts\pip install fastapi uvicorn
)

echo.
echo 🌐 Lancement de l'API sur http://localhost:8000
echo 📚 Documentation disponible sur http://localhost:8000/docs
echo 🔄 Endpoints disponibles:
echo    - GET  /trend_summary?symbol=EURUSD
echo    - POST /trend_summary/generate
echo    - GET  /trend_summary/batch
echo.

REM Lancer l'API
.\.venv\Scripts\python -X utf8 -m uvicorn backend.api.main:app --host 0.0.0.0 --port 8000 --reload

pause
