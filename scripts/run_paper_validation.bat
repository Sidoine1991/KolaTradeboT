@echo off
REM Paper Trading Validation Launcher pour TradBOT
REM Usage: scripts\run_paper_validation.bat

cd /d "%~dp0.."

echo ============================================
echo  🚀 TradBOT - PAPER TRADING VALIDATION
echo ============================================
echo.
echo Configuration:
echo   - Mode: PAPER (simulation uniquement)
echo   - Scan interval: 15s
echo   - GOM min coherence: 70%%
echo   - Dow blocking: ACTIF (80 pips, 70%% coherence)
echo   - Daily loss cap: 20$
echo   - Max trades/jour: 12
echo   - Consecutive losses stop: 3
echo.
echo ⚠️  AUCUN ORDRE RÉEL NE SERA ENVOYÉ AU BROKER
echo ⚠️  Assurez-vous que MT5 est ouvert sur compte DEMO
echo ⚠️  ai_server.py doit être démarré séparément (port 8000)
echo.
echo Appuyez sur une touche pour commencer...
pause >nul

echo.
echo Démarrage de la validation paper...
python scripts\paper_validation.py

echo.
echo Validation terminée.
pause