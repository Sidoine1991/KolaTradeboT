@echo off
echo ========================================
echo    INSTALLATION DÉPENDANCES AI SERVER
echo ========================================
echo.
echo ⚠️  Installation manuelle des dépendances
echo.
echo 📦 Installation de FastAPI...
pip install fastapi==0.104.1
echo.
echo 📦 Installation de Uvicorn...
pip install uvicorn==0.24.0
echo.
echo 📦 Installation de Pydantic...
pip install pydantic==1.10.13
echo.
echo 📦 Installation de Requests...
pip install requests==2.31.0
echo.
echo ✅ Installation terminée!
echo.
echo 🚀 Pour démarrer le serveur:
echo    python ai_server.py
echo.
echo 🧪 Pour tester le serveur:
echo    python debug_local_ai_server_simple.py
echo.
pause
