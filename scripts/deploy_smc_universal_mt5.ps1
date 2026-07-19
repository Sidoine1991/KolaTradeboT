# Deploy SMC_Universal.mq5 + modules vers MetaTrader 5 Experts
# Usage: .\scripts\deploy_smc_universal_mt5.ps1
#        .\scripts\deploy_smc_universal_mt5.ps1 -TerminalId E6E3D0917DD641581E4779524EB3B1AA
#        .\scripts\deploy_smc_universal_mt5.ps1 -AllTradBotTerminals

param(
    [string]$TerminalId = "",
    [switch]$AllTradBotTerminals
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$root\mt5\SMC_Universal.mq5")) {
    $root = "d:\Dev\TradBOT"
}

$defaultTerminals = @(
    "F016FF5B93786543B564E81A925D7066",
    "415DD75DEF29D458F52EB44204841A9C",
    "E6E3D0917DD641581E4779524EB3B1AA"
)

$terminalIds = @()
if ($AllTradBotTerminals) {
    $terminalIds = $defaultTerminals
} elseif ($TerminalId -ne "") {
    $terminalIds = @($TerminalId)
} else {
    $terminalIds = @("E6E3D0917DD641581E4779524EB3B1AA")
}

foreach ($tid in $terminalIds) {
    $mt5Base = "$env:APPDATA\MetaQuotes\Terminal\$tid\MQL5"
    $experts = Join-Path $mt5Base "Experts"
    $modules = Join-Path $experts "modules"
    $scripts = Join-Path $mt5Base "Scripts"

    if (-not (Test-Path $experts)) {
        Write-Warning "Skip missing terminal: $tid"
        continue
    }

    New-Item -ItemType Directory -Force -Path $modules | Out-Null
    New-Item -ItemType Directory -Force -Path $scripts | Out-Null

    Copy-Item "$root\mt5\SMC_Universal.mq5" "$experts\SMC_Universal.mq5" -Force
    Get-ChildItem "$root\mt5\modules\*.mqh" | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $modules $_.Name) -Force
    }
    if (Test-Path "$root\mt5\scripts\ResetGivebackAll.mq5") {
        Copy-Item "$root\mt5\scripts\ResetGivebackAll.mq5" "$scripts\ResetGivebackAll.mq5" -Force
    }
    if (Test-Path "$root\mt5\scripts\ResetGiveback.mq5") {
        Copy-Item "$root\mt5\scripts\ResetGiveback.mq5" "$scripts\ResetGiveback.mq5" -Force
    }

    $deployedEa = Join-Path $experts "SMC_Universal.mq5"
    $line9 = (Get-Content $deployedEa -TotalCount 9)[-1]
    if ($line9 -match 'Trade\.mqh>A' -or $line9 -notmatch 'Trade\.mqh>$') {
        Write-Error "Deploy verification FAILED [$tid]: ligne 9 invalide -> $line9"
    }
    $hasSymbolCategory = Select-String -Path $deployedEa -Pattern 'SMC_SymbolCategory\.mqh' -Quiet
    if (-not $hasSymbolCategory) {
        Write-Error "Deploy verification FAILED [$tid]: SMC_SymbolCategory.mqh manquant"
    }

    Write-Host ""
    Write-Host "Deploy OK [$tid]:"
    Write-Host "  $experts\SMC_Universal.mq5"
    Write-Host "  $modules\ (tous les .mqh)"
    Write-Host "  $scripts\ResetGivebackAll.mq5"
}

Write-Host ""
Write-Host "MetaEditor: ouvrir SMC_Universal.mq5 puis F7 (Compiler)."
Write-Host "Giveback reset: Scripts > ResetGivebackAll sur un graphique par terminal."
Write-Host "WebRequest: autoriser http://127.0.0.1:8000 dans Outils > Options > Expert Advisors."
