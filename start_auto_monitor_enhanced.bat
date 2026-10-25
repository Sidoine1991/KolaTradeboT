@echo off
chcp 65001 >nul
echo.
echo ========================================
echo    🤖 TRADBOT AUTO MONITOR ENHANCED
echo ========================================
echo.

REM Vérifier si l'environnement virtuel existe
if not exist ".venv\Scripts\activate.bat" (
    echo ❌ Environnement virtuel non trouvé
    echo Veuillez créer l'environnement virtuel d'abord
    pause
    exit /b 1
)

REM Activer l'environnement virtuel
echo 🔧 Activation de l'environnement virtuel...
call .venv\Scripts\activate.bat

REM Vérifier les dépendances
echo 📦 Vérification des dépendances...
python -c "import streamlit, requests, plotly, pandas" 2>nul
if errorlevel 1 (
    echo ❌ Dépendances manquantes
    echo Installation des dépendances...
    pip install streamlit requests plotly pandas
)

REM Créer le dossier logs s'il n'existe pas
if not exist "logs" mkdir logs

echo.
echo 🚀 Démarrage du système TradBOT...
echo.

REM Démarrer l'API en arrière-plan
echo 📡 Démarrage de l'API FastAPI...
start "TradBOT API" cmd /k "cd backend && python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload"

REM Attendre que l'API démarre
echo ⏳ Attente du démarrage de l'API...
timeout /t 5 /nobreak >nul

REM Démarrer le moniteur automatique
echo 🤖 Démarrage du moniteur automatique...
curl -X POST http://localhost:8000/auto_monitor/start

echo.
echo ✅ Configuration par défaut:
echo    - Intervalle de scan: 5 minutes
echo    - Confiance minimale: 75%%
echo    - Limite: 10 signaux/heure
echo    - Symboles prioritaires: 40+
echo.

REM Afficher le statut
echo 📊 Statut du moniteur:
curl http://localhost:8000/auto_monitor/status

echo.
echo 🌐 Interfaces disponibles:
echo    - API: http://localhost:8000
echo    - Dashboard: http://localhost:8501
echo    - Documentation API: http://localhost:8000/docs
echo.

REM Démarrer le dashboard
echo 📊 Démarrage du dashboard...
start "TradBOT Dashboard" cmd /k "streamlit run frontend/dashboard_modern/auto_monitor_dashboard.py --server.port 8501"

echo.
echo 🎉 Système TradBOT démarré avec succès!
echo.
echo 📋 Commandes utiles:
echo    - Voir le statut: curl http://localhost:8000/auto_monitor/status
echo    - Configurer: curl -X PUT http://localhost:8000/auto_monitor/config -H "Content-Type: application/json" -d "{\"scan_interval\": 3, \"min_confidence\": 80}"
echo    - Scan manuel: curl -X POST http://localhost:8000/auto_monitor/scan_now
echo    - Arrêter: curl -X POST http://localhost:8000/auto_monitor/stop
echo.
echo 💡 Le dashboard est accessible sur: http://localhost:8501
echo.
pause 