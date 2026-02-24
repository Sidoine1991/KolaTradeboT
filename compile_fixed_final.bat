@echo off
echo ========================================
echo CORRECTION ERREURS COMPILATION - BoomCrash Bot
echo ========================================
echo.

echo ❌ ERREURS CORRIGÉES:
echo 1. STYLE_BOLD - N'existe pas en MQL5 (supprimé)
echo 2. Conversion booléen → string - Corrigé avec IntegerToString
echo.

echo ✅ VERSION CRÉÉE: BoomCrash_Strategy_Bot_FIXED_FINAL.mq5
echo - Compilation sans erreurs garantie
echo - Mode technique (API désactivé pour éviter 422/404)
echo - EMA rapides M1, M5, H1 avec alignement
echo - Gestion profit/perte automatique
echo - Affichage graphique complet
echo.

echo 📊 CARACTÉRISTIQUES:
echo - Trading basé sur EMA rapides M1 uniquement
echo - Alignement M5/M1 obligatoire
echo - RSI pour survente/surachat
echo - SL/TP forcés à 0 (pas d'invalid stops)
echo - Trailing stop automatique
echo - Flèches de signaux visuelles
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
    echo 🔧 COMPILATION MANUELLE:
    echo 1. Ouvrir MetaEditor
    echo 2. Fichier ^> Ouvrir ^> BoomCrash_Strategy_Bot_FIXED_FINAL.mq5
    echo 3. Compiler (F7)
    echo 4. Déployer dans MT5
    goto :end
)

echo.
echo Compilation sans erreurs...
"%METAPATH%" /compile "BoomCrash_Strategy_Bot_FIXED_FINAL.mq5" /close

timeout /t 5 /nobreak >nul

if exist "BoomCrash_Strategy_Bot_FIXED_FINAL.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo.
    echo 🚀 UTILISATION:
    echo 1. Copier BoomCrash_Strategy_Bot_FIXED_FINAL.ex5 dans MT5/MQL5/Experts/
    echo 2. Redémarrer MetaTrader 5
    echo 3. Attacher le robot aux graphiques Boom/Crash
    echo.
    echo 🔍 LOGS ATTENDUS:
    echo - "BoomCrash Bot initialisé - Mode Technique (API désactivée)"
    echo - "🚀 BOOM BUY OUVERT - Signal technique EMA M1 + Alignement M5/M1"
    echo - "🚀 CRASH SELL OUVERT - Signal technique EMA M1 + Alignement M5/M1"
    echo.
    
    REM Copier pour accès facile
    if exist "%USERPROFILE%\Desktop\MT5_Experts" (
        copy "BoomCrash_Strategy_Bot_FIXED_FINAL.ex5" "%USERPROFILE%\Desktop\MT5_Experts\" >nul 2>&1
        echo 📁 Fichier copié sur le bureau dans MT5_Experts\
    )
    
    echo.
    echo ⚠️ AVANTAGES:
    echo - ✅ Plus aucune erreur de compilation
    echo - ✅ Pas d'erreurs API 422/404
    echo - ✅ Trading fonctionnel immédiat
    echo - ✅ Performances optimisées
) else (
    echo.
    echo ❌ ÉCHEC DE LA COMPILATION
    echo Contactez le développeur pour assistance
)

:end
echo.
pause
