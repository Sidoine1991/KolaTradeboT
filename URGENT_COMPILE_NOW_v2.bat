@echo off
echo ========================================
echo    URGENT - COMPILATION ROBOT
echo ========================================
echo.
echo Le robot GoldRush_basic.mq5 doit etre recompile
echo avec les corrections des Stop Loss pour Volatility
echo.
echo Appuyez sur une touche pour compiler...
pause
echo.
echo Lancement de MetaEditor...
start "" "C:\Program Files\MetaTrader 5\metaeditor64.exe" "d:\Dev\TradBOT\GoldRush_basic.mq5"
echo.
echo ATTENTION: Dans MetaEditor:
echo 1. Appuyez sur F7 pour compiler
echo 2. Corrigez les erreurs si necessaire
echo 3. Le robot doit afficher "0 errors, 0 warnings"
echo.
pause
