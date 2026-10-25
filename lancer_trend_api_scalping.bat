@echo off
echo ========================================
echo    LANCEMENT API TREND POUR SCALPING
echo ========================================
echo.
echo Demarrage de l'API de tendance sur le port 8001...
echo Cette API fournit les donnees de tendance pour le scalping automatique.
echo.
echo Appuyez sur Ctrl+C pour arreter l'API
echo.

cd /d "D:\Dev\TradBOT"
python trend_api.py

pause
