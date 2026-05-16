@echo off
title Tests Render + AWS RDS
color 0A

echo ============================================================
echo  TESTS RENDER + AWS RDS + DASHBOARD ML
echo ============================================================
echo.

echo [TEST 1] Health Check
echo ------------------------------------------------------------
curl -s https://kolatradebot-7ofl.onrender.com/health
echo.
echo.

echo [TEST 2] Decision Endpoint (teste AWS RDS cote serveur)
echo ------------------------------------------------------------
curl -s -X POST https://kolatradebot-7ofl.onrender.com/decision ^
  -H "Content-Type: application/json" ^
  -d "{\"symbol\":\"EURUSD\",\"bid\":1.0850,\"ask\":1.0852,\"atr\":0.0015,\"rsi\":55.0,\"ema_fast_m1\":1.0851,\"ema_slow_m1\":1.0849,\"ema_fast_m5\":1.0850,\"ema_slow_m5\":1.0848,\"ema_fast_h1\":1.0845,\"ema_slow_h1\":1.0840,\"dir_rule\":1,\"timeframe\":\"M1\",\"volatility_compression\":1.0,\"price_acceleration\":0.0001,\"volume_spike\":false,\"spike_probability\":0.0}"
echo.
echo.

echo [TEST 3] ML Stats
echo ------------------------------------------------------------
curl -s https://kolatradebot-7ofl.onrender.com/ml_stats
echo.
echo.

echo [TEST 4] Fichiers Dashboard Locaux
echo ------------------------------------------------------------
if exist "GOM_Enhanced_Dashboard.mqh" (
    echo [OK] GOM_Enhanced_Dashboard.mqh
) else (
    echo [ERREUR] GOM_Enhanced_Dashboard.mqh manquant
)

if exist "SMC_Universal.mq5" (
    echo [OK] SMC_Universal.mq5
) else (
    echo [ERREUR] SMC_Universal.mq5 manquant
)

if exist "sync_ml_stats_to_mt5.py" (
    echo [OK] sync_ml_stats_to_mt5.py
) else (
    echo [ERREUR] sync_ml_stats_to_mt5.py manquant
)

if exist "start_ml_sync.bat" (
    echo [OK] start_ml_sync.bat
) else (
    echo [ERREUR] start_ml_sync.bat manquant
)

if exist "D:\Dev\TradBOT\SMC_Universal.ex5" (
    echo [OK] SMC_Universal.ex5 (Dev)
) else (
    echo [ERREUR] SMC_Universal.ex5 manquant
)

echo.
echo ============================================================
echo  PROCHAINES ETAPES
echo ============================================================
echo.
echo 1. Verifiez les logs Render pour AWS RDS:
echo    https://dashboard.render.com/web/srv-cvs93ddumphs739q5hd0/logs
echo.
echo 2. Lancez: start_ml_sync.bat
echo    (Synchronise stats ML depuis AWS RDS vers MT5)
echo.
echo 3. Attachez SMC_Universal dans MT5
echo    (UseEnhancedDashboard = true)
echo.
echo 4. Verifiez le dashboard affiche les stats ML
echo.
pause
