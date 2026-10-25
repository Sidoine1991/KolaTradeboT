@echo off
echo ========================================
echo CORRECTION COMPLÈTE DES ERREURS API
echo ========================================
echo.

echo 🔍 PROBLÈMES IDENTIFIÉS:
echo ❌ Erreur 422 sur /decision (format JSON incorrect)
echo ❌ Erreur 404 sur /predict et /trend-analysis (endpoints inexistants)
echo ❌ Logs d'erreur excessifs toutes les secondes
echo.

echo 🛠️ SOLUTIONS À APPLIQUER:
echo 1. Corriger le format JSON pour /decision
echo 2. Désactiver complètement les endpoints 404
echo 3. Réduire la fréquence des appels API
echo 4. Améliorer la gestion des erreurs
echo.

REM Étape 1: Trouver MetaEditor
echo Recherche de MetaEditor...
set METAPATH=""
for %%f in (
    "C:\Program Files\MetaTrader 5\metaeditor64.exe"
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
    "C:\MetaTrader 5\metaeditor64.exe"
) do (
    if exist %%f (
        set METAPATH=%%f
        echo ✅ MetaEditor trouvé: %%f
        goto :found
    )
)

:found
if "%METAPATH%"=="" (
    echo ❌ MetaEditor non trouvé. Installation MT5 requise.
    pause
    exit /b 1
)

REM Étape 2: Supprimer l'ancien .ex5
echo.
echo Nettoyage des anciens fichiers...
if exist "BoomCrash_Strategy_Bot.ex5" (
    del "BoomCrash_Strategy_Bot.ex5"
    echo ✅ Ancien .ex5 supprimé
)

REM Étape 3: Compiler
echo.
echo Compilation du robot corrigé...
"%METAPATH%" /compile "BoomCrash_Strategy_Bot.mq5" /close /s

REM Attendre la compilation
echo Attente de la compilation...
timeout /t 10 /nobreak >nul

REM Étape 4: Vérifier
echo.
echo Vérification de la compilation...
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo ✅ COMPILATION RÉUSSIE!
    echo.
    echo 📋 MODIFICATIONS APPLIQUÉES:
    echo.
    echo 1. FORMAT JSON (/decision):
    echo    - JSON simplifié avec champs essentiels seulement
    echo    - Ajout timestamp et User-Agent
    echo    - Gestion d'erreur 422 avec fallback HOLD
    echo.
    echo 2. ENDPOINTS 404:
    echo    - /predict complètement désactivé
    echo    - /trend-analysis complètement désactivé
    echo    - Messages informatifs uniques
    echo.
    echo 3. FRÉQUENCE API:
    echo    - Intervalles augmentés pour éviter spam
    echo    - Logs réduits au minimum
    echo.
    echo 🚀 DÉPLOIEMENT:
    echo 1. Arrêter MT5 complètement
    echo 2. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/MQL5/Experts/
    echo 3. Redémarrer MT5
    echo 4. Attacher le robot aux graphiques
    echo 5. Surveiller les logs (devrait être silencieux maintenant)
    echo.
    echo 🔍 LOGS ATTENDUS APRÈS CORRECTION:
    echo - ℹ️ /predict désactivé temporairement (endpoint 404)
    echo - ℹ️ /trend-analysis désactivé temporairement (endpoint 404)
    echo - ✅ /decision succès: [réponse JSON] OU message d'erreur détaillé
    echo.
    
    REM Copier vers le bureau pour facile accès
    if exist "%USERPROFILE%\Desktop\MT5_Experts" (
        copy "BoomCrash_Strategy_Bot.ex5" "%USERPROFILE%\Desktop\MT5_Experts\" >nul 2>&1
        echo 📁 Fichier copié sur le bureau dans MT5_Experts\
    )
    
) else (
    echo ❌ ÉCHEC DE LA COMPILATION!
    echo.
    echo 🔧 DÉBOGAGE:
    echo 1. Vérifiez que le fichier .mq5 n'a pas d'erreurs de syntaxe
    echo 2. Ouvrez MetaEditor manuellement et compilez
    echo 3. Vérifiez les logs de compilation dans MetaEditor
    echo.
    echo 📝 Commande manuelle:
    echo    Ouvrez MetaEditor ^> Fichier ^> Ouvrir ^> BoomCrash_Strategy_Bot.mq5
    echo    Puis: Compilez (F7)
    echo.
)

echo.
pause
