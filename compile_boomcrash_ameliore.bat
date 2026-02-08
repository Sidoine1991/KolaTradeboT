@echo off
echo ========================================
echo   COMPILATION BOOMCRASH STRATEGY BOT AMÉLIORÉ
echo ========================================
echo.

REM Supprimer l'ancien fichier compilé
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo Suppression de l'ancien fichier .ex5...
    del "BoomCrash_Strategy_Bot.ex5"
)

REM Compiler le robot amélioré
echo Compilation en cours...
metaeditor.exe /compile "BoomCrash_Strategy_Bot.mq5" /close

if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo ✅ Fichier BoomCrash_Strategy_Bot.ex5 créé
    echo.
    echo 🔥 FONCTIONNALITÉS AJOUTÉES:
    echo    📊 Indicateurs MA + RSI graphiques
    echo    🤖 Signaux IA depuis Render (/decision, /predict, /trend-analysis)
    echo    📈 Prédictions sur 100 bougies
    echo    🚨 Flèches de spike clignotantes
    echo    💰 Gestion profit/perte automatique
    echo.
    echo 🔥 REDÉMARRER LE ROBOT MANUELLEMENT DANS MT5!
    echo 🔥 UTILISER LE NOUVEAU FICHIER .ex5 AMÉLIORÉ
) else (
    echo.
    echo ❌ COMPILATION ÉCHOUÉE!
    echo ❌ Vérifier les erreurs dans MetaEditor
)

echo.
pause
