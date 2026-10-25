@echo off
echo ========================================
echo    LANCEMENT API TREND REELLE
echo ========================================
echo.
echo Demarrage de l'API de tendance avec donnees REELLES sur le port 8001...
echo Cette API fournit des donnees de tendance realistes pour le scalping automatique.
echo.
echo Appuyez sur Ctrl+C pour arreter l'API
echo.

cd /d "D:\Dev\TradBOT"
python trend_api_real.py

pause
