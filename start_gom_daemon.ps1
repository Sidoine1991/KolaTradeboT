# GOM Sync Daemon Launcher — Boucle 10 minutes autonome
# Exécution: powershell -ExecutionPolicy Bypass -File start_gom_daemon.ps1

Set-Location D:\Dev\TradBOT
$logDir = "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$logDir\gom_sync_daemon_$timestamp.log"

"=" * 70 | Out-File -FilePath $logFile -Encoding UTF8
"🚀 GOM SYNC DAEMON — Démarrage" | Out-File -FilePath $logFile -Append -Encoding UTF8
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logFile -Append -Encoding UTF8
"=" * 70 | Out-File -FilePath $logFile -Append -Encoding UTF8

# Boucle infinie
$iteration = 0
while ($true) {
    $iteration++
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    "[$now] ⏳ Cycle $iteration — Exécution GOM Sync..." | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Exécuter GOM Sync
    & python Python/gom_sync_with_report.py --report 2>&1 | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Afficher dans console aussi
    "[$now] ✅ Sync complété. Prochain dans 10 min..."

    # Attendre 10 minutes (600 secondes)
    Start-Sleep -Seconds 600
}
