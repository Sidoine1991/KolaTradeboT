@echo off
echo ========================================
echo CORRECTION ERREURS API - BoomCrash Bot
echo ========================================
echo.

echo 🔧 CORRECTIONS APPLIQUÉES:
echo ✅ Amélioration format JSON pour /decision (erreur 422)
echo ✅ Désactivation temporaire /predict (erreur 404)
echo ✅ Désactivation temporaire /trend-analysis (erreur 404)
echo ✅ Gestion d'erreurs robuste avec debug détaillé
echo.

REM Supprimer l'ancien fichier .ex5
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo Suppression de l'ancien .ex5...
    del "BoomCrash_Strategy_Bot.ex5"
)

REM Nettoyer les objets
del /Q *.ex5 2>nul

REM Compiler
echo Compilation en cours...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile "BoomCrash_Strategy_Bot.mq5" /close

REM Attendre
timeout /t 5 /nobreak >nul

REM Vérifier
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo.
    echo 📋 RÉSUMÉ DES CORRECTIONS:
    echo.
    echo 1. ERREUR 422 (/decision):
    echo    - Format JSON simplifié avec champs essentiels
    echo    - Ajout headers User-Agent
    echo    - Gestion détaillée des erreurs
    echo.
    echo 2. ERREUR 404 (/predict et /trend-analysis):
    echo    - Désactivation temporaire des endpoints
    echo    - Messages informatifs dans les logs
    echo    - Code conservé pour réactivation future
    echo.
    echo 3. AMÉLIORATIONS:
    echo    - Debug détaillé pour diagnostiquer
    echo    - Signaux par défaut en cas d'erreur
    echo    - Logs clairs pour identifier les problèmes
    echo.
    echo 🚀 UTILISATION:
    echo 1. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/Experts/
    echo 2. Redémarrer MetaTrader 5
    echo 3. Attacher le robot à Boom/Crash
    echo 4. Surveiller les logs pour /decision
    echo.
    echo 🔍 LOGS ATTENDUS:
    echo - ✅ /decision succès: [réponse JSON]
    echo - ℹ️ /predict désactivé temporairement (endpoint 404)
    echo - ℹ️ /trend-analysis désactivé temporairement (endpoint 404)
    echo.
) else (
    echo.
    echo ❌ ERREUR DE COMPILATION!
    echo Vérifiez les erreurs dans MetaEditor.
    echo.
)

pause
