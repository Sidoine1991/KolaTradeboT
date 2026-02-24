@echo off
echo ========================================
echo INTEGRATION BOOM/CRASH - DERIV ARROWS
echo ========================================
echo.

echo ✅ FONCTIONNALITÉS INTÉGRÉES:
echo - Détection des flèches DERIV sur le graphique
echo - Signaux forts (ACHAT FORT / VENTE FORTE)
echo - Restrictions Boom/Crash (pas de vente Boom, pas d'achat Crash)
echo - Exécution immédiate avec SL/TP dynamiques
echo - Notifications et logs détaillés
echo.

echo 🎯 LOGIQUE DE TRADING:
echo 1. Détection symbole Boom/Crash
echo 2. Vérification flèche DERIV présente
echo 3. Recherche signal fort (IA confiance ≥ 70%% ou RSI+EMA)
echo 4. Validation direction autorisée
echo 5. Exécution trade avec SL/TP basés sur ATR
echo.

echo 📊 SIGNAUX FORTS DÉTECTÉS:
echo - ACHAT FORT (IA): Signal IA BUY + confiance ≥ 70%%
echo - VENTE FORTE (IA): Signal IA SELL + confiance ≥ 70%%
echo - ACHAT FORT (RSI+EMA): EMA M1 > EMA Lent + RSI < 30
echo - VENTE FORTE (RSI+EMA): EMA M1 < EMA Lent + RSI > 70
echo.

echo 🚀 EXÉCUTION DES TRADES:
echo - SL: 2x ATR
echo - TP: 3-4x ATR
echo - Notifications MT5
echo - Logs avec émojis pour identification facile
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
    echo 2. Fichier ^> Ouvrir ^> BoomCrash_Strategy_Bot.mq5
    echo 3. Compiler (F7)
    echo 4. Déployer dans MT5
    goto :end
)

echo.
echo Compilation avec logique Boom/Crash + DERIV...
"%METAPATH%" /compile "BoomCrash_Strategy_Bot.mq5" /close

timeout /t 5 /nobreak >nul

if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo.
    echo 🚀 DÉPLOIEMENT:
    echo 1. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/MQL5/Experts/
    echo 2. Redémarrer MetaTrader 5
    echo 3. Activer UseSpikeDetection = true
    echo 4. Attacher aux graphiques Boom/Crash
    echo.
    echo 🔍 LOGS ATTENDUS:
    echo - "🚀 ACHAT exécuté sur Boom 600 Index - ACHAT FORT (IA)"
    echo - "🚀 VENTE exécutée sur Crash 600 Index - VENTE FORTE (RSI + EMA)"
    echo - "Flèche DERIV détectée sur bougie actuelle"
    echo.
    echo 📊 UTILISATION:
    echo - Le robot surveille les flèches DERIV en temps réel
    echo - Détecte automatiquement les signaux forts
    echo - Exécute les trades immédiatement
    echo - Respecte les restrictions Boom/Crash
    echo.
    
    REM Copier pour accès facile
    if exist "%USERPROFILE%\Desktop\MT5_Experts" (
        copy "BoomCrash_Strategy_Bot.ex5" "%USERPROFILE%\Desktop\MT5_Experts\" >nul 2>&1
        echo 📁 Fichier copié sur le bureau dans MT5_Experts\
    )
    
    echo.
    echo ⚠️ CONFIGURATION REQUISE:
    echo - UseSpikeDetection = true (activé)
    echo - UseRenderAPI = true (pour signaux IA)
    echo - Notifications activées dans MT5
    echo - Autoriser WebRequest pour https://kolatradebot.onrender.com
    echo.
) else (
    echo.
    echo ❌ ÉCHEC DE LA COMPILATION
    echo Vérifiez les erreurs dans MetaEditor
)

:end
echo.
pause
