@echo off
REM Start complete TradBOT autonomous trading system
REM Starts: GOM sync daemon + Pipeline + AI Server

cls
echo.
echo ============================================================
echo    🚀 TRADBOT AUTONOMOUS TRADING SYSTEM LAUNCHER
echo ============================================================
echo.
echo Available commands:
echo   1. Start GOM sync (10-min autonomous loop)
echo   2. Start pipeline (hourly analysis)
echo   3. Start AI server
echo   4. Start all services
echo   5. Run GOM sync once (--report)
echo   6. Run pipeline once
echo   7. Exit
echo.
set /p choice="Select option (1-7): "

if "%choice%"=="1" goto gom_sync
if "%choice%"=="2" goto pipeline
if "%choice%"=="3" goto ai_server
if "%choice%"=="4" goto all_services
if "%choice%"=="5" goto gom_once
if "%choice%"=="6" goto pipeline_once
if "%choice%"=="7" goto end
goto invalid

:gom_sync
echo.
echo [START] GOM Sync Daemon (10-minute autonomous loop)...
cd /d D:\Dev\TradBOT
start "GOM Sync Daemon" C:\Python314_old\python.exe Python/gom_sync_loop_daemon.py
echo ✅ GOM daemon started
pause
goto menu

:pipeline
echo.
echo [START] Pipeline (hourly analysis)...
cd /d D:\Dev\TradBOT
start "Pipeline" C:\Python314_old\python.exe Python/pipeline_hourly_autonomous.py
echo ✅ Pipeline started
pause
goto menu

:ai_server
echo.
echo [START] AI Server (port 8000)...
cd /d D:\Dev\TradBOT
start "AI Server" C:\Python314_old\python.exe ai_server.py
echo ✅ AI Server started
pause
goto menu

:all_services
echo.
echo [START] Starting all services...
cd /d D:\Dev\TradBOT
start "GOM Sync" C:\Python314_old\python.exe Python/gom_sync_loop_daemon.py
start "Pipeline" C:\Python314_old\python.exe Python/pipeline_hourly_autonomous.py
start "AI Server" C:\Python314_old\python.exe ai_server.py
echo ✅ All services started
echo.
echo Services:
echo   • GOM Sync Daemon: 10-min autonomous loop
echo   • Pipeline: Hourly analysis
echo   • AI Server: Port 8000
echo.
pause
goto menu

:gom_once
echo.
echo [RUN] GOM Sync (once) with report...
cd /d D:\Dev\TradBOT
C:\Python314_old\python.exe Python/gom_sync_with_report.py --report 2>&1 | tee -a logs/gom_sync.log
echo.
pause
goto menu

:pipeline_once
echo.
echo [RUN] Pipeline (once)...
cd /d D:\Dev\TradBOT
C:\Python314_old\python.exe Python/pipeline_hourly_autonomous.py --once 2>&1 | tee -a logs/pipeline.log
echo.
pause
goto menu

:invalid
echo Invalid choice
goto menu

:menu
cls
goto start

:end
exit /b 0
