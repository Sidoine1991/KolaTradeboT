@echo off
echo ========================================
echo   DIAGNOSTIC TRADING BOT - SANS PYTHON
echo ========================================
echo.

echo 1. Verification fichiers de base...
if exist ".env" (
    echo    [OK] .env present
) else (
    echo    [ERREUR] .env manquant
)

if exist "ai_server.py" (
    echo    [OK] ai_server.py present
) else (
    echo    [ERREUR] ai_server.py manquant
)

if exist "SMC_Universal.mq5" (
    echo    [OK] SMC_Universal.mq5 present
) else (
    echo    [ERREUR] SMC_Universal.mq5 manquant
)

if exist "SMC_Universal.ex5" (
    echo    [OK] SMC_Universal.ex5 compile
) else (
    echo    [ERREUR] SMC_Universal.ex5 manquant - compilation requise
)

echo.
echo 2. Verification configuration .env...
findstr /C:"MT5_LOGIN=" .env >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] MT5_LOGIN configure
) else (
    echo    [ERREUR] MT5_LOGIN manquant
)

findstr /C:"MT5_PASSWORD=" .env >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] MT5_PASSWORD configure
) else (
    echo    [ERREUR] MT5_PASSWORD manquant
)

findstr /C:"MT5_SERVER=" .env >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] MT5_SERVER configure
) else (
    echo    [ERREUR] MT5_SERVER manquant
)

echo.
echo 3. Verification logs recents...
if exist "*.log" (
    echo    [INFO] Fichiers log trouves:
    dir *.log /b 2>nul
) else (
    echo    [INFO] Aucun fichier log trouve
)

echo.
echo 4. Verification serveur IA...
netstat -an | findstr ":8000" >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] Serveur ecoute sur port 8000
) else (
    echo    [ERREUR] Serveur IA non demarre sur port 8000
)

echo.
echo 5. Verification MetaTrader 5...
tasklist | findstr "terminal64.exe" >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] MetaTrader 5 en cours d'execution
) else (
    echo    [ERREUR] MetaTrader 5 non demarre
)

echo.
echo ========================================
echo   ACTIONS RECOMMANDEES
echo ========================================
echo.
echo 1. Si .env manquant: copier .env.example vers .env
echo 2. Si SMC_Universal.ex5 manquant: compiler le fichier .mq5
echo 3. Si serveur IA non demarre: python ai_server.py
echo 4. Si MT5 non demarre: lancer MetaTrader 5
echo 5. Attacher le robot au graphique MT5
echo 6. Activer AutoTrading dans MT5
echo.
echo ========================================

pause
