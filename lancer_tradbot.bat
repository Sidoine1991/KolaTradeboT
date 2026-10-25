@echo off
REM === Active l'environnement virtuel si besoin ===
if exist .venv\Scripts\activate (
    call .venv\Scripts\activate
)

REM === Lance FastAPI dans un terminal séparé ===
start "FastAPI" cmd /k "uvicorn backend.api.main:app --reload"

REM === Attends 3 secondes pour que FastAPI démarre ===
timeout /t 3 > nul

REM === Lance ngrok dans un terminal séparé ===
start "ngrok" cmd /k "ngrok http 8000"

REM === Ouvre le dashboard ngrok dans le navigateur ===
start http://127.0.0.1:4040

REM === Affiche un rappel pour Twilio ===
echo.
echo -------------------------------------------------
echo TradBOT backend et ngrok sont en cours d'execution.
echo Ouvre le dashboard ngrok pour recuperer l'URL publique :
echo     http://127.0.0.1:4040
echo Mets cette URL dans Twilio (sans slash final) :
echo     https://xxxxxx.ngrok-free.app/whatsapp_webhook
echo -------------------------------------------------
pause 