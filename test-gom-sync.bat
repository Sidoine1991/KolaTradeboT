@echo off
REM test-gom-sync.bat
REM Test rapide du GOM Sync (une exécution)

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  🧪 GOM SYNC TEST — ONE-SHOT EXECUTION
echo =====================================================
echo.

cd /d D:\Dev\TradBOT

REM Créer le répertoire logs s'il n'existe pas
if not exist logs mkdir logs

echo 📌 Test: Charge les verdicts GOM et envoie le rapport
echo.
echo Démarrage: %date% %time%
echo Répertoire: %cd%
echo.

REM Exécuter le GOM sync une fois
echo 🚀 Exécution du GOM Sync...
echo.

python Python/gom_sync_with_report.py --report 2>&1 | tee -a logs/gom_sync_test.log

REM Vérifier le résultat
if %ERRORLEVEL% equ 0 (
    echo.
    echo ✅ TEST RÉUSSI
    echo.
    echo 📊 Résultats du test:
    echo    • Verdicts chargés
    echo    • Rapport envoyé
    echo    • Logs stockés
    echo.
    echo 📁 Logs: logs/gom_sync_test.log
    echo.
) else (
    echo.
    echo ❌ TEST ÉCHOUÉ
    echo.
    echo Erreur: %ERRORLEVEL%
    echo.
    echo 🔍 Vérifiez:
    echo    • AI Server tourne (http://127.0.0.1:8000)
    echo    • Python est installé
    echo    • Dépendances sont installées
    echo.
)

echo ========================================================
echo.
echo 💡 Si le test réussit, lancer le scheduler:
echo    Double-click: start-gom-sync-10min.bat
echo.
pause
