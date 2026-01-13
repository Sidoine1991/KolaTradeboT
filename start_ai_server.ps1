# Script PowerShell pour démarrer le serveur IA TradBOT en arrière-plan
Write-Host "Démarrage du serveur IA TradBOT..." -ForegroundColor Green

cd 'D:\Dev\TradBOT'

# Lancer le serveur en arrière-plan
Start-Process -FilePath ".\.venv\Scripts\python.exe" `
    -ArgumentList "ai_server.py" `
    -WindowStyle Hidden `
    -PassThru | Out-Null

Write-Host "Serveur IA démarré en arrière-plan sur http://127.0.0.1:8000/" -ForegroundColor Green
Write-Host "Pour arrêter le serveur, utilisez: Get-Process python | Where-Object {$_.Path -like '*TradBOT*'} | Stop-Process" -ForegroundColor Yellow

