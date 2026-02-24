@echo off
echo ========================================
echo Compilation BoomCrash Strategy Bot AMELIORE
echo ========================================
echo.

REM Supprimer l'ancien fichier .ex5 pour forcer recompilation propre
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo Suppression de l'ancien .ex5...
    del "BoomCrash_Strategy_Bot.ex5"
)

REM Nettoyer les objets graphiques précédents
echo Nettoyage des objets graphiques...
del /Q *.ex5 2>nul

REM Compiler avec MetaEditor
echo Lancement de la compilation...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile "BoomCrash_Strategy_Bot.mq5" /close

REM Attendre un peu pour la compilation
timeout /t 5 /nobreak >nul

REM Vérifier si le fichier .ex5 a été créé
if exist "BoomCrash_Strategy_Bot.ex5" (
    echo.
    echo ✅ COMPILATION REUSSIE!
    echo Fichier BoomCrash_Strategy_Bot.ex5 créé avec succès.
    echo.
    echo 🚀 AMELIORATIONS INTEGREES:
    echo ✅ EMA rapides M1, M5, H1 (10, 50 périodes)
    echo ✅ Logique d'entrée basée sur EMA rapides M1
    echo ✅ Alignement M5/M1 obligatoire
    echo ✅ Signaux IA depuis Render (/decision, /predict, /trend-analysis)
    echo ✅ Affichage graphique complet
    echo ✅ Flèches de spike clignotantes
    echo ✅ Gestion profit/perte automatique
    echo.
    echo 📊 UTILISATION:
    echo 1. Copier BoomCrash_Strategy_Bot.ex5 dans MT5/Experts/
    echo 2. Redémarrer MetaTrader 5
    echo 3. Attacher le robot à un graphique Boom/Crash
    echo 4. Configurer les URLs API Render dans les paramètres
    echo.
) else (
    echo.
    echo ❌ ERREUR DE COMPILATION!
    echo Vérifiez les erreurs dans MetaEditor.
    echo.
    echo 🔧 CONSEILS:
    echo - Assurez-vous que MetaEditor est bien installé
    echo - Vérifiez les chemins d'installation
    echo - Consultez les logs d'erreurs dans MetaEditor
    echo.
)

pause
