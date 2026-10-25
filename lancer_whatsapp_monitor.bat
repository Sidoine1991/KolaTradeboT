@echo off
echo 📱 TradBOT - Surveillant WhatsApp des Signaux
echo ================================================
echo.

REM Vérifier que Python est installé
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python n'est pas installé ou pas dans le PATH
    pause
    exit /b 1
)

echo ✅ Python détecté
echo.

REM Vérifier que l'API de signaux est disponible
echo 🔍 Vérification de l'API de signaux...
curl -s http://localhost:8001/health >nul 2>&1
if errorlevel 1 (
    echo ⚠️ API de signaux non disponible sur le port 8001
    echo 💡 Assurez-vous que l'API de signaux est démarrée
    echo.
)

echo 📱 Lancement du surveillant WhatsApp...
echo.
echo 📋 Instructions:
echo    - Le surveillant vérifiera les signaux toutes les 10 secondes
echo    - Seuls les signaux respectant les critères seront envoyés
echo    - Critères: SL max 10 pips, TP min 30 pips
echo    - Appuyez sur Ctrl+C pour arrêter
echo.

REM Lancer le surveillant
python start_whatsapp_monitor.py

echo.
echo 🛑 Surveillant arrêté
pause
