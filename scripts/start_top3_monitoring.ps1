# Top 3 Monitoring — symboles du scan matinal (PAS XAUUSD seul)
#
# Usage:
#   .\scripts\start_top3_monitoring.ps1
#   .\scripts\start_top3_monitoring.ps1 -Interval 600

param(
    [int]$Interval = 1200,
    [string]$Python = "python"
)

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

@("logs", "reports", "data\state") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

$symbolsLine = "Top 3 scan matinal (morning_top3.json)"
$activeFile = "data\active_symbols.txt"
$stateFile = "data\state\morning_top3.json"
if (Test-Path $stateFile) {
    try {
        $j = Get-Content $stateFile -Raw | ConvertFrom-Json
        $syms = ($j.top3 | ForEach-Object { $_.symbol }) -join ", "
        if ($syms) { $symbolsLine = $syms }
    } catch { }
} elseif (Test-Path $activeFile) {
    $symbolsLine = ((Get-Content $activeFile | Select-Object -First 3) -join ", ")
}

Write-Host "Demarrage suivi Top 3 (Deriv/Weltrade)" -ForegroundColor Cyan
Write-Host "  Symboles: $symbolsLine" -ForegroundColor Gray
Write-Host "  Intervalle: $($Interval / 60) min" -ForegroundColor Gray
Write-Host "  Script: scripts/unified_top3_daemon.py" -ForegroundColor Gray
Write-Host ""
Write-Host "Scan matinal si pas encore fait:" -ForegroundColor Yellow
Write-Host "  python python\morning_scan.py" -ForegroundColor Gray
Write-Host ""

& $Python "scripts\unified_top3_daemon.py"
