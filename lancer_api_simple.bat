@echo off
echo 🚀 Lancement de l'API de Tendance TradBOT...
echo.

set PYTHONPATH=D:\Dev\TradBOT
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1

echo 📁 Répertoire: %CD%
echo 🔧 PYTHONPATH: %PYTHONPATH%
echo.

echo 🌐 Lancement de l'API sur http://localhost:8000
echo 📚 Documentation: http://localhost:8000/docs
echo.

.\.venv\Scripts\python -m uvicorn backend.api.main:app --host 0.0.0.0 --port 8000 --reload

pause
