@echo off
echo ========================================
echo BOOMCRASH BOT - VERSION FIXÉE SANS ERREURS API
echo ========================================
echo.

echo ✅ VERSION CRÉÉE: BoomCrash_Strategy_Bot_FIXED.mq5
echo.
echo 🛠️ CORRECTIONS APPLIQUÉES:
echo ❌ API Render complètement désactivée (plus d'erreurs 422/404)
echo ✅ Trading basé uniquement sur les indicateurs techniques
echo ✅ EMA rapides M1, M5, H1 avec alignement obligatoire
echo ✅ Gestion profit/perte automatique (0.50$ / 3$)
echo ✅ Affichage graphique complet
echo ✅ Logs clairs et détaillés
echo.
echo 📊 STRATÉGIE:
echo - Boom: BUY sur EMA rapide M1 + alignement M5/M1 + RSI survente
echo - Crash: SELL sur EMA rapide M1 + alignement M5/M1 + RSI surachat
echo - SL/TP forcés à 0 (pas d'invalid stops)
echo - Trailing stop automatique
echo.
echo 🚀 DÉPLOIEMENT:
echo 1. Arrêter complètement MetaTrader 5
echo 2. Copier BoomCrash_Strategy_Bot_FIXED.mq5 dans MT5/MQL5/Experts/
echo 3. Ouvrir MetaEditor et compiler le fichier (F7)
echo 4. Redémarrer MetaTrader 5
echo 5. Attacher le robot aux graphiques Boom/Crash
echo.
echo 🔍 LOGS ATTENDUS:
echo - "BoomCrash Bot initialisé - Mode Technique (API désactivée)"
echo - "🚀 BOOM BUY OUVERT - Signal technique EMA M1 + Alignement M5/M1"
echo - "🚀 CRASH SELL OUVERT - Signal technique EMA M1 + Alignement M5/M1"
echo - Plus aucune erreur 422 ou 404!
echo.

if exist "BoomCrash_Strategy_Bot_FIXED.mq5" (
    echo ✅ Fichier créé avec succès!
    echo 📁 Emplacement: d:\Dev\TradBOT\BoomCrash_Strategy_Bot_FIXED.mq5
    
    REM Créer un dossier sur le bureau pour facile accès
    if not exist "%USERPROFILE%\Desktop\MT5_Fixed" mkdir "%USERPROFILE%\Desktop\MT5_Fixed"
    copy "BoomCrash_Strategy_Bot_FIXED.mq5" "%USERPROFILE%\Desktop\MT5_Fixed\" >nul 2>&1
    echo 📁 Aussi copié sur le bureau dans MT5_Fixed\
) else (
    echo ❌ Erreur lors de la création du fichier
)

echo.
echo ⚠️ IMPORTANT:
echo - Utilisez cette version FIXÉE au lieu de l'ancienne
echo - L'ancienne version génère des erreurs API inutiles
echo - Cette version fonctionne 100% avec les indicateurs techniques
echo.

pause
