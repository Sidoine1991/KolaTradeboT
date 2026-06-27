@echo off
title Planification Rapport Agents WhatsApp (toutes les 3h)
cd /d "%~dp0"

echo.
echo  ================================================
echo   Installation tache planifiee
echo   Rapport Intelligence Agents -> WhatsApp
echo   Frequence : toutes les 3h (00h, 03h, 06h, 09h...)
echo  ================================================
echo.

:: Chercher Python disponible
set PYTHON=
for %%P in (
    "C:\Users\USER\AppData\Local\Programs\Python\Python314\python.exe"
    "C:\Python314\python.exe"
    "C:\Python311\python.exe"
    "C:\Users\USER\AppData\Local\Programs\Python\Python311\python.exe"
) do (
    if exist %%P (
        if not defined PYTHON set PYTHON=%%P
    )
)

if not defined PYTHON (
    where python >nul 2>&1
    if %errorlevel%==0 (
        for /f "tokens=*" %%i in ('where python') do if not defined PYTHON set PYTHON=%%i
    )
)

if not defined PYTHON (
    echo ERREUR: Python introuvable. Installez Python et relancez.
    pause
    exit /b 1
)

echo  Python: %PYTHON%
echo.

set SCRIPT=%~dp0Python\agents_report_whatsapp.py
set TASKNAME=TradBOT_AgentsReport_3h

:: Supprimer l'ancienne tache si elle existe
schtasks /delete /tn "%TASKNAME%" /f >nul 2>&1

:: Creer la tache toutes les 3h, de 00h a 21h (7 executions par jour)
:: On cree 8 declencheurs: 00h, 03h, 06h, 09h, 12h, 15h, 18h, 21h
echo  Creation des declencheurs toutes les 3h...

for %%H in (00 03 06 09 12 15 18 21) do (
    schtasks /create /tn "%TASKNAME%_%%H" /tr "\"%PYTHON%\" \"%SCRIPT%\"" /sc daily /st %%H:00 /f >nul 2>&1
    if %errorlevel%==0 (
        echo  OK  %%Hh00 - tache creee
    ) else (
        echo  WARN %%Hh00 - echec creation
    )
)

echo.
echo  ================================================
echo   INSTALLATION TERMINEE
echo  ================================================
echo.
echo  Le rapport sera envoye sur WhatsApp a:
echo   00h00 | 03h00 | 06h00 | 09h00
echo   12h00 | 15h00 | 18h00 | 21h00
echo.
echo  Pour tester maintenant:
echo   "%PYTHON%" "%SCRIPT%"
echo.
echo  Pour voir les taches:
echo   schtasks /query /tn TradBOT_AgentsReport_3h_06 /fo list
echo.
echo  Pour supprimer toutes les taches:
echo   for %%H in (00 03 06 09 12 15 18 21) do schtasks /delete /tn TradBOT_AgentsReport_3h_%%H /f
echo.
pause
