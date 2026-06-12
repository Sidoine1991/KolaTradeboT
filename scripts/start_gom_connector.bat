@echo off
REM Connecteur GOM TradingView -> ai_server -> MT5
REM Prerequis:
REM   1. ai_server.py en cours (port 8000)
REM   2. TradingView en mode CDP (scripts\Start-TradingViewCDP.ps1)
REM   3. Indicateur GOM KOLA visible sur le graphique TV
REM   4. SMC_Universal: GOMSyncSymbolToTV=ON, GOMVerdictSource=TRADINGVIEW

cd /d "%~dp0.."
echo [GOM] Demarrage connecteur TradingView...
python python\gom_verdict_poller.py --interval 5
pause
