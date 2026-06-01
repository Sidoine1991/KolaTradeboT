# Script pour lancer un backtest MT5 automatise
# Configuration Boom 1000, M1, 7 derniers jours, deriveapro.mq5

$TerminalPath = "D:\Program Files\MetaTrader 5\terminal.exe"
$ProfileID = "E6E3D0917DD641581E4779524EB3B1AA"

Write-Host "Demarrage MT5 avec backtest..." -ForegroundColor Green

# Lancer MT5 avec le profile
& $TerminalPath /profile:$ProfileID | Out-Null

# Attendre le demarrage
Start-Sleep -Seconds 15

Write-Host "MT5 lance" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration backtest :" -ForegroundColor Cyan
Write-Host "   Symbol: Boom 1000"
Write-Host "   Timeframe: M1"
Write-Host "   EA: deriveapro.mq5"
Write-Host "   Period: Last 7 days"
Write-Host "   Signal Quality: 60%"
Write-Host "   Max Positions/Day: 7"
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Ouvrez Strategy Tester (F4 ou View > Strategy Tester)"
Write-Host "2. Selectionnez 'deriveapro' dans Expert Advisor"
Write-Host "3. Selectionnez 'Boom 1000' comme symbol"
Write-Host "4. Timeframe = M1"
Write-Host "5. Cliquez START pour lancer le backtest"
Write-Host ""
Write-Host "Observez :" -ForegroundColor Cyan
Write-Host "- Dashboard affiche Symbol: X/7 ET Global: Y/7"
Write-Host "- Robot s'arrete quand Global atteint 7"
Write-Host "- SL remonte au breakeven a 50% du chemin vers TP"
Write-Host "- Win rate et P&L"
Write-Host ""

Write-Host "Appuyez sur ENTREE pour fermer ce script..." -ForegroundColor Gray
Read-Host
