@echo off
title Fix MetaEditor Cache - Force Reload
color 0E

echo ========================================
echo  FIX METAEDITOR CACHE
echo ========================================
echo.
echo Cette commande force MetaEditor a recharger
echo tous les fichiers .mqh modifies.
echo.
echo ETAPE 1: Fermer MetaEditor
echo ========================================
echo.
echo 1. Fermez COMPLETEMENT MetaEditor (File -^> Exit)
echo 2. Verifiez qu'il n'y a pas de processus metaeditor64.exe
echo    (Ctrl+Shift+Esc -^> Onglet Processus)
echo.
pause

echo.
echo ETAPE 2: Supprimer les caches
echo ========================================

REM Supprimer le cache de precompilation
set TERM1=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5
set TERM2=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5

echo Suppression caches Terminal 1...
if exist "%TERM1%\*.exp" del /Q "%TERM1%\*.exp" 2>nul
if exist "%TERM1%\Experts\*.exp" del /Q "%TERM1%\Experts\*.exp" 2>nul
if exist "%TERM1%\Experts\Free Robots\SMC_Universal\*.exp" del /Q "%TERM1%\Experts\Free Robots\SMC_Universal\*.exp" 2>nul

echo Suppression caches Terminal 2...
if exist "%TERM2%\*.exp" del /Q "%TERM2%\*.exp" 2>nul
if exist "%TERM2%\Experts\*.exp" del /Q "%TERM2%\Experts\*.exp" 2>nul

echo.
echo [OK] Caches supprimes
echo.

echo ETAPE 3: Recopier les fichiers mis a jour
echo ========================================

echo Copie GOM_Enhanced_Dashboard.mqh...
copy /Y D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh "%TERM1%\Experts\Free Robots\SMC_Universal\" >nul
if %errorlevel% equ 0 (echo   [OK] Terminal 1) else (echo   [FAIL] Terminal 1)

copy /Y D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh "%TERM2%\Experts\Free Robots\SMC_Universal\" >nul
if %errorlevel% equ 0 (echo   [OK] Terminal 2) else (echo   [FAIL] Terminal 2)

echo.
echo ========================================
echo  TERMINE
echo ========================================
echo.
echo Vous pouvez maintenant:
echo 1. Rouvrir MetaEditor
echo 2. Ouvrir SMC_Universal.mq5
echo 3. Compiler (F7)
echo.
echo Le cache sera reconstruit proprement.
echo.
pause
