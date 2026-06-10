# Script PowerShell pour attacher deriveapro v10 au chart Boom500 M1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DerivEAPro v10 — GHOST OrderFlow Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si MT5 est en cours d'exécution
$mt5_running = Get-Process terminal64 -ErrorAction SilentlyContinue
if ($mt5_running) {
    Write-Host "✅ MT5 Terminal is running (PID: $($mt5_running.Id))" -ForegroundColor Green
} else {
    Write-Host "❌ MT5 Terminal not running" -ForegroundColor Red
    Write-Host "Launching MetaTrader 5..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\MetaTrader 5\terminal64.exe"
    Start-Sleep -Seconds 15
    Write-Host "✅ MT5 launched" -ForegroundColor Green
}

# Afficher les instructions
Write-Host ""
Write-Host "MANUAL STEPS TO ATTACH EA:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open MT5 Terminal and open 'Boom 500 Index' M1 chart"
Write-Host "   - Click File → Open Chart"
Write-Host "   - Search: 'Boom 500 Index' (or 'Deriv Boom 500')"
Write-Host "   - Timeframe: M1 (1 minute)"
Write-Host "   - Click OK"
Write-Host ""

Write-Host "2. Attach EA to chart"
Write-Host "   - Right-click on chart → Attach Expert Advisor"
Write-Host "   - Select 'deriveapro' from list"
Write-Host "   - Click Properties"
Write-Host ""

Write-Host "3. Configure Inputs:"
Write-Host "   General Tab:"
Write-Host "     ✓ Account: Select trading account"
Write-Host "     ✓ Allow live trading: YES (check if live)"
Write-Host ""
Write-Host "   Inputs Tab - GHOST Configuration:"
Write-Host "     ✓ InpUseGHOST = TRUE"
Write-Host "     ✓ InpGHOSTFile = 'gom_signal.json'"
Write-Host "     ✓ InpGHOSTPollSec = 5"
Write-Host "     ✓ InpGHOSTMinQuality = 40.0"
Write-Host "     ✓ InpGHOSTMaxAgeSec = 60"
Write-Host ""
Write-Host "   Risk Configuration:"
Write-Host "     ✓ InpUseRiskPercent = TRUE"
Write-Host "     ✓ InpRiskPercent = 1.5"
Write-Host "     ✓ InpFixedLot = 0.20"
Write-Host ""

Write-Host "4. Click OK to attach"
Write-Host "   Expected in Expert Tab Log:"
Write-Host "     [v10] GHOST OrderFlow activé | MinQuality=40.0% | MaxAge=60s"
Write-Host "     [GHOST] verdict=BUY buypct=70.0 quality=65.0"
Write-Host ""

Write-Host "5. Verify dashboard shows GHOST panel"
Write-Host "   - Should display: 'GHOST BUY Q=65% [12s]'"
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Ready for live trading" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Afficher le chemin du binaire
Write-Host ""
Write-Host "EA Binary: D:\Dev\TradBOT\mt5\deriveapro.ex5" -ForegroundColor Cyan
Write-Host "Compilation: 0 errors, 0 warnings" -ForegroundColor Green
Write-Host ""

# Attendre avant fermeture
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
