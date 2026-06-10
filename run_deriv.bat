@echo off
cd /d "D:\Dev\TradBOT"
echo.
echo  Demarrage Deriv EA Pro...
echo.

REM Verifie si le port 7860 est deja actif
netstat -ano | findstr ":7860" | findstr "LISTENING" >nul 2>&1
if %errorlevel%==0 (
  echo  Port 7860 deja actif.
  goto openbrowser
)

REM Lance le serveur en arriere-plan
start "Deriv EA Pro Server" /min node serve.js

REM Attend que le serveur soit pret
echo  Attente du serveur...
:waitloop
timeout /t 1 /nobreak >nul
netstat -ano | findstr ":7860" | findstr "LISTENING" >nul 2>&1
if %errorlevel%==0 goto openbrowser
goto waitloop

:openbrowser
echo  Serveur pret — ouverture du navigateur...

REM Chrome avec flag pour ignorer les erreurs SSL sur ws.derivws.com
set CHROME="C:\Program Files\Google\Chrome\Application\chrome.exe"
set CHROME2="C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
set FLAGS=--allow-insecure-localhost --ignore-certificate-errors --unsafely-treat-insecure-origin-as-secure=wss://ws.derivws.com

if exist %CHROME% (
  %CHROME% %FLAGS% "http://127.0.0.1:7860"
  goto end
)
if exist %CHROME2% (
  %CHROME2% %FLAGS% "http://127.0.0.1:7860"
  goto end
)

REM Edge fallback
set EDGE="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if exist %EDGE% (
  %EDGE% %FLAGS% "http://127.0.0.1:7860"
  goto end
)

REM Navigateur par defaut (sans flags)
start http://127.0.0.1:7860

:end
