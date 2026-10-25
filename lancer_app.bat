@echo off
echo ========================================
echo    TRADBOT - APPLICATION TEMPS REEL
echo ========================================
echo.
echo Lancement de l'application...
echo.

cd /d "%~dp0frontend"
streamlit run app_real_time.py

pause 