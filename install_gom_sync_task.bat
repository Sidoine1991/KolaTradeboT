@echo off
REM ============================================================================
REM Installation GOM Sync Task — Tâche Windows Scheduler
REM Exécute la synchronisation GOM toutes les 10 minutes
REM ============================================================================
REM Usage:
REM   - Admin: install_gom_sync_task.bat install
REM   - Admin: install_gom_sync_task.bat uninstall
REM   - Admin: install_gom_sync_task.bat status
REM ============================================================================

setlocal enabledelayedexpansion

set TASK_NAME=TradBOT-GOM-Sync-10min
set TASK_DESC=GOM Sync avec rapport WhatsApp toutes les 10 minutes
set SCRIPT_PATH=D:\Dev\TradBOT\gom_sync_loop.ps1
set PYTHON_CMD=python
set WORK_DIR=D:\Dev\TradBOT
set LOG_DIR=%WORK_DIR%\logs

REM Vérifier si exécuté en admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Droit administrateur requis!
    echo Relancez avec: runas /user:Administrator "cmd.exe"
    pause
    exit /b 1
)

if "%1"=="install" goto INSTALL
if "%1"=="uninstall" goto UNINSTALL
if "%1"=="status" goto STATUS
if "%1"=="" goto USAGE

:USAGE
echo.
echo Installation GOM Sync Task — Windows Scheduler
echo.
echo Usage:
echo   %0 install    — Installer la tâche (exécution toutes les 10 min)
echo   %0 uninstall  — Désinstaller la tâche
echo   %0 status     — Afficher le statut de la tâche
echo.
goto END

:INSTALL
echo.
echo [*] Installation tâche Windows Scheduler...
echo    Nom: %TASK_NAME%
echo    Script: %SCRIPT_PATH%
echo    Intervalle: 10 minutes
echo.

REM Créer dossier logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Supprimer tâche existante si présente
tasklist /FI "TASKSCHED.EXE" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

REM Créer nouvelle tâche
schtasks /create ^
  /tn "%TASK_NAME%" ^
  /tr "powershell.exe -ExecutionPolicy Bypass -File \"%SCRIPT_PATH%\"" ^
  /sc minute /mo 10 ^
  /ru SYSTEM ^
  /f

if %errorLevel% equ 0 (
    echo [OK] Tâche créée avec succès!
    echo [OK] Première exécution dans 10 minutes
    echo [OK] Logs: %LOG_DIR%\gom_sync_loop.log
) else (
    echo [ERROR] Erreur lors de la création de la tâche
    exit /b 1
)

REM Afficher config
echo.
echo Détails tâche:
schtasks /query /tn "%TASK_NAME%" /v /fo list
goto END

:UNINSTALL
echo.
echo [*] Désinstallation tâche Windows Scheduler...
echo    Nom: %TASK_NAME%
echo.

schtasks /delete /tn "%TASK_NAME%" /f

if %errorLevel% equ 0 (
    echo [OK] Tâche supprimée
) else (
    echo [WARNING] Tâche introuvable ou erreur de suppression
)
goto END

:STATUS
echo.
echo [*] Statut tâche Windows Scheduler...
echo    Nom: %TASK_NAME%
echo.

schtasks /query /tn "%TASK_NAME%" /v /fo list

if %errorLevel% equ 0 (
    echo.
    echo Logs récents:
    if exist "%LOG_DIR%\gom_sync_loop.log" (
        echo.
        tail -20 "%LOG_DIR%\gom_sync_loop.log" 2>nul || type "%LOG_DIR%\gom_sync_loop.log" | findstr /r ".*" | tail -20
    ) else (
        echo Aucun log trouvé
    )
) else (
    echo [ERROR] Tâche introuvable
)
goto END

:END
echo.
pause
