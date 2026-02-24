@echo off
echo ========================================
echo ACTIVATION API RENDER - BoomCrash Bot
echo ========================================
echo.

echo ✅ FICHIER MIS À JOUR: BoomCrash_Strategy_Bot.mq5
echo 🔄 API Render activée avec communication complète
echo 📊 Signaux IA intégrés pour ouverture des trades
echo.

echo 📋 FONCTIONNALITÉS AJOUTÉES:
echo - UpdateFromDecision() - Envoie données complètes au serveur
echo - ParseAIResponse() - Reçoit et traite les signaux IA
echo - Variables globales pour les signaux IA
echo - Logique d'ouverture basée sur signaux IA + EMA
echo - Dashboard avec état de l'API
echo.

echo 🌐 ENDPOINTS UTILISÉS:
echo ✅ /decision - https://kolatradebot.onrender.com/decision
echo ❌ /predict - Désactivé (404)
echo ❌ /trend-analysis - Désactivé (404)
echo.

echo 📊 DONNÉES ÉCHANGÉES:
echo - MT5 → Render: symbol, bid, ask, rsi, atr, ema_fast/slow, dir_rule
echo - Render → MT5: action, confidence, reason
echo - Affichage temps réel sur le graphique
echo.

echo 🎯 LOGIQUE D'OUVERTURE:
echo - Boom: BUY si EMA M1 + Alignement M5/M1 + Signal IA BUY
echo - Crash: SELL si EMA M1 + Alignement M5/M1 + Signal IA SELL
echo - Confiance IA minimale: 50%%
echo - SL/TP forcés à 0 (pas d'invalid stops)
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
echo Compilation avec API Render activée...
"%METAPATH%" /compile "BoomCrash_Strategy_Bot.mq5" /close

timeout /t 5 /nobreak >nul

if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo.
    echo 🚀 DÉPLOIEMENT IMMÉDIAT:
    echo 1. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/MQL5/Experts/
    echo 2. Redémarrer MetaTrader 5
    echo 3. Attacher le robot aux graphiques Boom/Crash
    echo 4. Vérifier les logs MT5
    echo.
    echo 🔍 LOGS ATTENDUS:
    echo - "✅ /decision succès: {action: 'BUY', confidence: 0.85, ...}"
    echo - "🤖 Signal IA reçu: BUY | Confiance: 85.2% | EMA alignement..."
    echo - "🚀 BOOM BUY OUVERT - Signal technique EMA M1 + Alignement M5/M1 + IA FORTE"
    echo.
    echo 📊 TABLEAU DE BORD:
    echo - IA: BUY 85.2%
    echo - Tendance: HAUSS. 75.0%
    echo - Position: Type: BUY | Vol: 0.20 | P&L: +1.25 USD
    echo.
    
    REM Copier pour accès facile
    if exist "%USERPROFILE%\Desktop\MT5_Experts" (
        copy "BoomCrash_Strategy_Bot.ex5" "%USERPROFILE%\Desktop\MT5_Experts\" >nul 2>&1
        echo 📁 Fichier copié sur le bureau dans MT5_Experts\
    )
    
    echo.
    echo ⚠️ IMPORTANT:
    echo - Le serveur AI doit être en ligne sur Render
    echo - Vérifiez: https://kolatradebot.onrender.com/health
    echo - Autorisez WebRequest pour https://kolatradebot.onrender.com
    echo - Surveillez les logs pour les signaux IA en temps réel
    echo.
) else (
    echo.
    echo ❌ ÉCHEC DE LA COMPILATION
    echo Vérifiez les erreurs dans MetaEditor
)

:end
echo.
pause
