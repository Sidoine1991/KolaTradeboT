# Script PowerShell pour arrêter le serveur IA TradBOT
Write-Host "Arrêt du serveur IA TradBOT..." -ForegroundColor Yellow

$processes = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like '*TradBOT*\.venv*'
}

if ($processes) {
    $processes | Stop-Process -Force
    Write-Host "Serveur IA arrêté." -ForegroundColor Green
} else {
    Write-Host "Aucun serveur IA trouvé en cours d'exécution." -ForegroundColor Yellow
}

