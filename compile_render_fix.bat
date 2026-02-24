@echo off
echo ========================================
echo CORRECTION ENDPOINTS RENDER - BoomCrash Bot
echo ========================================
echo.

echo 🔍 ANALYSE DES ERREURS:
echo ❌ Erreur 422 sur /decision (format JSON incorrect)
echo ❌ Erreur 404 sur /predict et /trend (endpoints inexistants)
echo.

echo ✅ CORRECTIONS APPLIQUÉES:
echo 1. URLs des endpoints 404 vidées (désactivation complète)
echo 2. Format JSON corrigé pour /decision avec fallback
echo 3. Gestion d'erreur robuste avec retry automatique
echo 4. Messages informatifs uniques pour éviter spam
echo.

echo 📝 MODIFICATIONS:
echo - TrendAPIURL = "" (désactivé)
echo - AI_PredictURL = "" (désactivé) 
echo - AI_ServerURL conservé (seul endpoint fonctionnel)
echo - Format JSON: symbol, bid, ask, action, confidence
echo - Fallback format simple si 422
echo.

REM Supprimer l'ancien .ex5
if exist "BoomCrash_Strategy_Bot.ex5" (
    del "BoomCrash_Strategy_Bot.ex5"
    echo ✅ Ancien .ex5 supprimé
)

REM Chercher MetaEditor
set METAPATH=""
for %%f in (
    "C:\Program Files\MetaTrader 5\metaeditor64.exe"
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
) do (
    if exist %%f (
        set METAPATH=%%f
        echo ✅ MetaEditor trouvé: %%f
        goto :compile
    )
)

:compile
if "%METAPATH%"=="" (
    echo ❌ MetaEditor non trouvé
    echo.
    echo 🔧 COMPILATION MANUELLE REQUISE:
    echo 1. Ouvrir MetaEditor
    echo 2. Fichier ^> Ouvrir ^> BoomCrash_Strategy_Bot.mq5
    echo 3. Compiler (F7)
    echo 4. Copier le .ex5 dans MT5/Experts/
    goto :end
)

echo.
echo Compilation en cours...
"%METAPATH%" /compile "BoomCrash_Strategy_Bot.mq5" /close

timeout /t 5 /nobreak >nul

if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo.
    echo 🚀 DÉPLOIEMENT:
    echo 1. Arrêter MT5 complètement
    echo 2. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/MQL5/Experts/
    echo 3. Redémarrer MT5
    echo 4. Attacher le robot aux graphiques
    echo.
    echo 🔍 LOGS ATTENDUS APRÈS CORRECTION:
    echo - ✅ /decision succès: [réponse JSON]
    echo - ℹ️ /predict désactivé - endpoint non disponible (404)
    echo - ℹ️ /trend-analysis désactivé - endpoint non disponible (404)
    echo - Plus aucune erreur 422 ou 404 excessive!
    echo.
    
    REM Copier pour accès facile
    if exist "%USERPROFILE%\Desktop\MT5_Experts" (
        copy "BoomCrash_Strategy_Bot.ex5" "%USERPROFILE%\Desktop\MT5_Experts\" >nul 2>&1
        echo 📁 Fichier copié sur le bureau dans MT5_Experts\
    )
) else (
    echo.
    echo ❌ ÉCHEC DE LA COMPILATION
    echo Vérifiez les erreurs dans MetaEditor
)

:end
echo.
pause
