@echo off
echo ========================================
echo    URGENT - COMPILATION IMMÉDIATE
echo ========================================
echo.
echo ⚠️  PROBLÈME CRITIQUE DÉTECTÉ ⚠️
echo.
echo Le robot utilise encore l'ancienne version compilée
echo Les corrections SL ne sont pas appliquées
echo.
echo ❌ Erreurs actuelles: "SL trop proche du prix actuel"
echo ✅ Solution: Recompiler avec les nouvelles corrections
echo.
echo ÉTAPES OBLIGATOIRES:
echo 1. Appuyez sur une touche pour ouvrir MetaEditor
echo 2. Dans MetaEditor, appuyez sur F7
echo 3. Vérifiez: "0 errors, 0 warnings"
echo 4. Fermez MetaEditor
echo 5. Attachez le robot aux graphiques
echo.
echo Après compilation, vous devriez voir:
echo "🔧 SYMBOLE VOLATILITY - Validation SL désactivée"
echo.
pause
echo.
echo 🚀 Lancement de MetaEditor...
start "" "C:\Program Files\MetaTrader 5\metaeditor64.exe" "d:\Dev\TradBOT\GoldRush_basic.mq5"
echo.
echo ⏳ Attendez la fin de la compilation...
pause
echo.
echo ✅ Si compilation réussie, le robot peut maintenant trader !
echo ❌ Si erreurs, notez-les et contactez-moi
echo.
pause
