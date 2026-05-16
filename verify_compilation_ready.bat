@echo off
title Verification Pre-Compilation
color 0B

echo ========================================
echo  VERIFICATION AVANT COMPILATION
echo ========================================
echo.

set T1=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts\Free Robots\SMC_Universal
set T2=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\Free Robots\SMC_Universal

echo [1/4] Verification fichiers source
echo -------------------------------------------
if exist "D:\Dev\TradBOT\SMC_Universal.mq5" (
    echo [OK] SMC_Universal.mq5 existe
) else (
    echo [ERREUR] SMC_Universal.mq5 introuvable
)

if exist "D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh" (
    echo [OK] GOM_Enhanced_Dashboard.mqh existe
) else (
    echo [ERREUR] GOM_Enhanced_Dashboard.mqh introuvable
)

echo.
echo [2/4] Verification Terminal 1
echo -------------------------------------------
if exist "%T1%\GOM_Enhanced_Dashboard.mqh" (
    echo [OK] Fichier .mqh present
    findstr /C:"GOM_DrawEnhancedDashboardV2" "%T1%\GOM_Enhanced_Dashboard.mqh" >nul
    if %errorlevel% equ 0 (
        echo [OK] Fonction V2 detectee
    ) else (
        echo [ERREUR] Fonction V2 manquante
    )
) else (
    echo [ERREUR] Fichier .mqh absent
)

echo.
echo [3/4] Verification Terminal 2
echo -------------------------------------------
if exist "%T2%\GOM_Enhanced_Dashboard.mqh" (
    echo [OK] Fichier .mqh present
    findstr /C:"GOM_DrawEnhancedDashboardV2" "%T2%\GOM_Enhanced_Dashboard.mqh" >nul
    if %errorlevel% equ 0 (
        echo [OK] Fonction V2 detectee
    ) else (
        echo [ERREUR] Fonction V2 manquante
    )
) else (
    echo [ERREUR] Fichier .mqh absent
)

echo.
echo [4/4] Verification processus MetaEditor
echo -------------------------------------------
tasklist /FI "IMAGENAME eq metaeditor64.exe" 2>nul | find /I "metaeditor64.exe" >nul
if %errorlevel% equ 0 (
    echo [ATTENTION] MetaEditor64 en cours d'execution
    echo             Fermez-le pour vider le cache!
) else (
    echo [OK] MetaEditor64 non actif
)

tasklist /FI "IMAGENAME eq metaeditor.exe" 2>nul | find /I "metaeditor.exe" >nul
if %errorlevel% equ 0 (
    echo [ATTENTION] MetaEditor en cours d'execution
    echo             Fermez-le pour vider le cache!
) else (
    echo [OK] MetaEditor non actif
)

echo.
echo ========================================
echo  RESUME
echo ========================================
echo.
echo Si tous les [OK] sont affiches:
echo 1. Ouvrez MetaEditor
echo 2. Ouvrez SMC_Universal.mq5
echo 3. Compilez (F7)
echo.
echo Si des [ERREUR] ou [ATTENTION]:
echo - Fermez MetaEditor completement
echo - Relancez sync_all_terminals.bat
echo - Re-executez cette verification
echo.
pause
