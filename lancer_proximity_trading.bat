@echo off
echo ========================================
echo   SYSTEME DE TRADING PAR PROXIMITE
echo   Supports/Resistances - Boom/Crash
echo ========================================
echo.

echo [INFO] Demarrage du systeme de trading par proximite...
echo [INFO] Le systeme execute des trades quand le prix est proche:
echo [INFO]   - D'une RESISTANCE pour un SELL (Crash)
echo [INFO]   - D'un SUPPORT pour un BUY (Boom)
echo.

python proximity_trading_system.py

echo.
echo [INFO] Systeme arrete.
pause
