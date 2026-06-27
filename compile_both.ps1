$SRC_MQ5    = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
$METAEDITOR = "D:\Program Files\MetaTrader 5\MetaEditor64.exe"
$EXPERTS_W  = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts"
$EXPERTS_D  = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts"
$LOG_W      = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\logs\metaeditor.log"
$LOG_D      = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\metaeditor.log"

Write-Host ""
Write-Host "=== COMPILE + DEPLOY -> Weltrade + Deriv ===" -ForegroundColor Cyan
Write-Host ""

# Copie la source dans les deux dossiers Experts
Write-Host "[1/3] Copie source vers les deux terminaux..." -ForegroundColor Yellow
Copy-Item $SRC_MQ5 $EXPERTS_W -Force
Copy-Item $SRC_MQ5 $EXPERTS_D -Force
Write-Host "  OK - source copiee dans Weltrade et Deriv" -ForegroundColor Green

# Note le timestamp avant compilation pour detecter les nouvelles lignes de log
$tsAvant = Get-Date

# Compile Weltrade
Write-Host ""
Write-Host "[2/3] Compilation Weltrade (attendre 30s)..." -ForegroundColor Yellow
$mq5_W = Join-Path $EXPERTS_W "SMC_Universal.mq5"
$p = Start-Process -FilePath $METAEDITOR -ArgumentList "`"$mq5_W`"" -Wait -PassThru
Write-Host "  MetaEditor exit: $($p.ExitCode)"
Start-Sleep -Seconds 8

# Lecture log Weltrade
if (Test-Path $LOG_W) {
    $lines = Get-Content $LOG_W | Where-Object { $_ -match "SMC_Universal" } | Select-Object -Last 3
    $lines | ForEach-Object { Write-Host "  LOG: $_" -ForegroundColor Gray }
    if ($lines -match "0 errors") {
        Write-Host "  OK Weltrade: 0 erreurs" -ForegroundColor Green
    } elseif ($lines -match "errors") {
        Write-Host "  ERREURS detectees dans Weltrade!" -ForegroundColor Red
    }
}

# Compile Deriv
Write-Host ""
Write-Host "[3/3] Compilation Deriv (attendre 30s)..." -ForegroundColor Yellow
$mq5_D = Join-Path $EXPERTS_D "SMC_Universal.mq5"
$p2 = Start-Process -FilePath $METAEDITOR -ArgumentList "`"$mq5_D`"" -Wait -PassThru
Write-Host "  MetaEditor exit: $($p2.ExitCode)"
Start-Sleep -Seconds 8

# Lecture log Deriv
if (Test-Path $LOG_D) {
    $lines2 = Get-Content $LOG_D | Where-Object { $_ -match "SMC_Universal" } | Select-Object -Last 3
    $lines2 | ForEach-Object { Write-Host "  LOG: $_" -ForegroundColor Gray }
    if ($lines2 -match "0 errors") {
        Write-Host "  OK Deriv: 0 erreurs" -ForegroundColor Green
    } elseif ($lines2 -match "errors") {
        Write-Host "  ERREURS detectees dans Deriv!" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== COMPILATION TERMINEE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Dans chaque terminal MT5 ouvert:" -ForegroundColor Cyan
Write-Host "  Appuyez F5 sur le graphique pour recharger l'EA" -ForegroundColor White
Write-Host "  OU: clic droit -> Expert Advisors -> Recompile" -ForegroundColor White
Write-Host ""
Read-Host "Appuyez sur ENTREE pour fermer"
