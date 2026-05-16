@echo off
title Sync Dashboard to ALL MT5 Terminals
color 0A

echo ========================================
echo  SYNC DASHBOARD - TOUS TERMINAUX MT5
echo ========================================
echo.

set SOURCE=D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh

REM Terminal 1
set T1=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5
REM Terminal 2
set T2=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5

echo [TERMINAL 1]
echo -------------------------------------------
copy /Y "%SOURCE%" "%T1%\Scripts\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] Scripts) else (echo [--] Scripts)

copy /Y "%SOURCE%" "%T1%\Include\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] Include) else (echo [--] Include)

copy /Y "%SOURCE%" "%T1%\Experts\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] Experts) else (echo [--] Experts)

copy /Y "%SOURCE%" "%T1%\Experts\Free Robots\SMC_Universal\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] SMC_Universal) else (echo [--] SMC_Universal)

echo.
echo [TERMINAL 2]
echo -------------------------------------------
copy /Y "%SOURCE%" "%T2%\Scripts\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] Scripts) else (echo [--] Scripts)

copy /Y "%SOURCE%" "%T2%\Include\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] Include) else (echo [--] Include)

copy /Y "%SOURCE%" "%T2%\Experts\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] Experts) else (echo [--] Experts)

if not exist "%T2%\Experts\Free Robots\SMC_Universal" mkdir "%T2%\Experts\Free Robots\SMC_Universal"
copy /Y "%SOURCE%" "%T2%\Experts\Free Robots\SMC_Universal\" >nul 2>&1
if %errorlevel% equ 0 (echo [OK] SMC_Universal) else (echo [--] SMC_Universal)

echo.
echo ========================================
echo  TERMINE
echo ========================================
echo.
echo Fichier synchronise vers TOUS les emplacements
echo des deux terminaux MT5.
echo.
echo IMPORTANT: Fermez MetaEditor COMPLETEMENT
echo puis rouvrez-le pour vider le cache.
echo.
pause
