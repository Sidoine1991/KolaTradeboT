@echo off
echo ========================================
echo   COMPILATION FORCEE BoomCrash
echo ========================================
echo.

REM Supprimer l'ancien fichier compilé
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo Suppression de l'ancien fichier .ex5...
    del "BoomCrash_Strategy_Bot.ex5"
)

REM Compiler le robot
echo Compilation en cours...
metaeditor.exe /compile "BoomCrash_Strategy_Bot.mq5" /close

if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION REUSSIE!
    echo ✅ Fichier BoomCrash_Strategy_Bot.ex5 créé
    echo.
    echo 🔥 REDÉMARRER LE ROBOT MANUELLEMENT DANS MT5!
    echo 🔥 UTILISER LE NOUVEAU FICHIER .ex5
) else (
    echo.
    echo ❌ COMPILATION ÉCHOUÉE!
    echo ❌ Vérifier les erreurs dans MetaEditor
)

echo.
pause
