@echo off
echo ========================================
echo INTÉGRATION COMPLÈTE MT5_AI_CLIENT + AI_SERVER
echo ========================================
echo.

echo ✅ AMÉLIORATIONS INTÉGRÉES:
echo 📊 Données complètes de mt5_ai_client.py vers ai_server.py
echo 🔄 Format JSON DecisionRequest complet avec indicateurs
echo 📈 Affichage temps réel des signaux IA sur le graphique
echo 🎯 Dashboard avec données réelles des positions
echo 🚨 Flèches de spike dynamiques
echo.

echo 📝 DONNÉES ÉCHANGÉES:
echo - MT5 → Render: symbol, bid, ask, rsi, atr, ema_fast/slow (M1/M5/H1)
echo - Render → MT5: action, confidence, reason, prediction, stop_loss, take_profit
echo - Affichage graphique: signal IA, confiance, prédiction, timestamp
echo - Dashboard: prix, RSI, EMA, état API, positions, P&L
echo.

echo 🔍 ENDPOINTS UTILISÉS:
echo ✅ /decision - Format complet avec tous les indicateurs
echo ❌ /predict - Désactivé (404)
echo ❌ /trend-analysis - Désactivé (404)
echo.

echo 🎨 AFFICHAGE TEMPS RÉEL:
echo - Signal IA: "🤖 IA: BUY | Conf: 85.2% | EMA alignement M5/M1"
echo - Prédiction: "📊 Prédiction: 1234.56"
echo - Timestamp: "⏰ MAJ: 14:30:25"
echo - Couleurs dynamiques selon signal (VERT/ROUGE/JAUNE)
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
echo Compilation avec intégration IA complète...
"%METAPATH%" /compile "BoomCrash_Strategy_Bot.mq5" /close

timeout /t 5 /nobreak >nul

if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ INTÉGRATION RÉUSSIE!
    echo.
    echo 🚀 DÉPLOIEMENT IMMÉDIAT:
    echo 1. Arrêter MT5 complètement
    echo 2. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/MQL5/Experts/
    echo 3. Démarrer ai_server.py (python ai_server.py)
    echo 4. Démarrer mt5_ai_client.py (python mt5_ai_client.py)
    echo 5. Redémarrer MT5
    echo 6. Attacher le robot aux graphiques Boom/Crash
    echo.
    echo 📊 RÉSULTATS ATTENDUS:
    echo - ✅ Communication MT5 ↔ Render sans erreurs 422/404
    echo - 📈 Données IA en temps réel sur le graphique
    echo - 🎯 Dashboard avec informations complètes
    echo - 🚨 Flèches de spike synchronisées
    echo - 💰 Positions basées sur signaux IA forts
    echo.
    echo 🔍 LOGS DE VÉRIFICATION:
    echo - "✅ /decision succès: {action: 'BUY', confidence: 0.85, ...}"
    echo - "🤖 Signal IA reçu: BUY | Confiance: 85.2% | EMA alignement..."
    echo - "🚀 BOOM BUY OUVERT - Signal technique EMA M1 + Alignement M5/M1 + IA FORTE"
    echo.
    
    REM Copier pour accès facile
    if exist "%USERPROFILE%\Desktop\MT5_Experts" (
        copy "BoomCrash_Strategy_Bot.ex5" "%USERPROFILE%\Desktop\MT5_Experts\" >nul 2>&1
        echo 📁 Fichier copié sur le bureau dans MT5_Experts\
    )
    
    echo.
    echo ⚠️ IMPORTANT:
    echo - Assurez-vous que ai_server.py est en cours d'exécution
    echo - Vérifiez que mt5_ai_client.py communique bien avec Render
    echo - Surveillez les logs MT5 pour les signaux IA en temps réel
    echo.
) else (
    echo.
    echo ❌ ÉCHEC DE LA COMPILATION
    echo Vérifiez les erreurs dans MetaEditor
    echo.
    echo 🔧 CONSEILS:
    echo - Vérifiez la syntaxe MQL5
    echo - Assurez-vous que tous les handles sont corrects
    echo - Consultez les logs de compilation MetaEditor
)

:end
echo.
pause
