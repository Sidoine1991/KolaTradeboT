# Top 3 Monitoring System Launcher
# Suivi autonome toutes les 20 minutes avec rapport Word généré à chaque cycle
#
# Usage:
#   .\start_top3_monitoring.ps1
#   .\start_top3_monitoring.ps1 -Interval 600  (10 min pour test)

param(
    [int]$Interval = 1200,  # 20 minutes
    [string]$Python = "python"
)

Write-Host "🚀 Démarrage Top 3 Monitoring System" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Ensure directories exist
@("logs", "reports") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ | Out-Null
        Write-Host "📁 Créé: $_" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "📊 Configuration:" -ForegroundColor Yellow
Write-Host "  • Symboles: XAUUSD, EURUSD, BTCUSD (Top 3)" -ForegroundColor Gray
Write-Host "  • Intervalle: $Interval secondes ($(($Interval / 60)) minutes)" -ForegroundColor Gray
Write-Host "  • Sorties:" -ForegroundColor Gray
Write-Host "    - Messages WhatsApp via PsychoBot" -ForegroundColor Gray
Write-Host "    - Rapports Word: reports/" -ForegroundColor Gray
Write-Host "    - Logs: logs/top3_monitor.log" -ForegroundColor Gray
Write-Host "    - Fallback: whatsapp_alerts.log" -ForegroundColor Gray
Write-Host ""

# Launch
$script = "python/xauusd_top3_monitor.py"
$args = @("--interval", $Interval)

Write-Host "▶️  Lancement du monitoring..." -ForegroundColor Cyan
Write-Host ""

& $Python $script @args

Write-Host ""
Write-Host "🛑 Monitoring arrêté" -ForegroundColor Yellow
