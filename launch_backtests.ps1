# Script pour lancer les backtests SMC Universal
# Nécessite MT5 avec terminal_id configuré

$ConfigFile = "D:\Dev\TradBOT\backtest_config.txt"
$ResultsDir = "D:\Dev\TradBOT\backtest_results"

# Créer le répertoire de résultats
if (-not (Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir | Out-Null
}

# Lire la configuration
$Config = Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#' -and $_ -trim -ne '' }

Write-Host "=== Lancement des backtests SMC Universal ===" -ForegroundColor Green
Write-Host "Configuration: $ConfigFile" -ForegroundColor Yellow
Write-Host "Résultats: $ResultsDir" -ForegroundColor Yellow
Write-Host ""

# Pour chaque symbole dans la configuration
foreach ($Line in $Config) {
    $Parts = $Line -split '\|'
    $Symbol = $Parts[0].Trim()
    $Timeframe = $Parts[1].Trim()
    $StartDate = $Parts[2].Trim()
    $EndDate = $Parts[3].Trim()
    $Deposit = $Parts[4].Trim()
    $Leverage = $Parts[5].Trim()
    
    Write-Host "Backtest: $Symbol ($Timeframe) du $StartDate au $EndDate" -ForegroundColor Cyan
    Write-Host "  Dépôt initial: $Deposit | Levier: $Leverage" -ForegroundColor Gray
    
    # NOTE: MT5 n'a pas d'API CLI pour le Strategy Tester
    # Les backtests doivent être lancés manuellement depuis MT5
    # Ce script génère les instructions pour chaque backtest
    
    $Instructions = @"
=== BACKTEST MANUEL REQUIS ===
Symbole: $Symbol
Timeframe: $Timeframe
Période: $StartDate à $EndDate
Dépôt: $Deposit
Levier: $Leverage

Instructions:
1. Ouvrir MT5
2. F4 pour ouvrir MetaEditor
3. F4 pour ouvrir Strategy Tester
4. Sélectionner SMC_Universal
5. Symbole: $Symbol
6. Timeframe: $Timeframe
7. Date: $StartDate à $EndDate
8. Dépôt: $Deposit
9. Levier: $Leverage
10. Cocher "Use date" et "Optimization" (si désiré)
11. Cliquer sur "Start"
12. Attendre la fin du backtest
13. Exporter les résultats vers: $ResultsDir\$Symbol\_backtest.html
"@
    
    Write-Host $Instructions -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=== Instructions complètes ===" -ForegroundColor Green
Write-Host "Les backtests doivent être lancés manuellement depuis MT5 Strategy Tester." -ForegroundColor Yellow
Write-Host "Une fois terminés, les résultats doivent être exportés vers: $ResultsDir" -ForegroundColor Yellow
