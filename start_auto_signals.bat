@echo off
echo 🤖 LANCEMENT AUTO-SIGNALS TRADBOT
echo ===================================
echo.

REM Activer l'environnement virtuel
call .venv\Scripts\activate.bat

REM Créer le dossier logs s'il n'existe pas
if not exist "logs" mkdir logs

echo ✅ Environnement activé
echo ✅ Dossier logs créé
echo.
echo 🚀 Démarrage du moniteur automatique...
echo 💡 Le bot va scanner les marchés toutes les 5 minutes
echo 💡 Seuls les signaux de qualité professionnelle seront envoyés
echo 💡 Limite: 10 signaux maximum par heure
echo.
echo ⏹️  Pour arrêter: Ctrl+C
echo.

REM Lancer le moniteur automatique
python backend/auto_signal_monitor.py

pause 