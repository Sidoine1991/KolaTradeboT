@echo off
title Sync GOM_Enhanced_Dashboard.mqh to MT5
color 0A

echo ========================================
echo  SYNC DASHBOARD MQH TO MT5 TERMINALS
echo ========================================
echo.

set SOURCE=D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh

REM Terminal 1
set TERM1=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5

REM Terminal 2
set TERM2=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5

echo [1/6] Copy to Terminal 1 Scripts...
copy /Y "%SOURCE%" "%TERM1%\Scripts\" >nul
if %errorlevel% equ 0 (echo   [OK] Scripts) else (echo   [FAIL] Scripts)

echo [2/6] Copy to Terminal 1 Include...
copy /Y "%SOURCE%" "%TERM1%\Include\" >nul
if %errorlevel% equ 0 (echo   [OK] Include) else (echo   [FAIL] Include)

echo [3/6] Copy to Terminal 1 Experts\Free Robots\SMC_Universal...
copy /Y "%SOURCE%" "%TERM1%\Experts\Free Robots\SMC_Universal\" >nul
if %errorlevel% equ 0 (echo   [OK] SMC_Universal) else (echo   [FAIL] SMC_Universal)

echo [4/6] Copy to Terminal 2 Scripts...
copy /Y "%SOURCE%" "%TERM2%\Scripts\" >nul
if %errorlevel% equ 0 (echo   [OK] Scripts) else (echo   [FAIL] Scripts)

echo [5/6] Copy to Terminal 2 Include...
copy /Y "%SOURCE%" "%TERM2%\Include\" >nul
if %errorlevel% equ 0 (echo   [OK] Include) else (echo   [FAIL] Include)

echo [6/6] Copy to Terminal 2 Experts\Free Robots\SMC_Universal...
if not exist "%TERM2%\Experts\Free Robots\SMC_Universal" mkdir "%TERM2%\Experts\Free Robots\SMC_Universal"
copy /Y "%SOURCE%" "%TERM2%\Experts\Free Robots\SMC_Universal\" >nul
if %errorlevel% equ 0 (echo   [OK] SMC_Universal) else (echo   [FAIL] SMC_Universal)

echo.
echo ========================================
echo  SYNC COMPLETE
echo ========================================
echo.
echo Vous pouvez maintenant compiler:
echo - GOM_KOLA_SIDO_Script.mq5
echo - SMC_Universal.mq5
echo.
pause
