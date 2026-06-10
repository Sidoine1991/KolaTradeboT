# Deploy SMC_Universal.mq5 + modules vers MetaTrader 5 Experts
# Usage: .\scripts\deploy_smc_universal_mt5.ps1
#        .\scripts\deploy_smc_universal_mt5.ps1 -TerminalId E6E3D0917DD641581E4779524EB3B1AA

param(
    [string]$TerminalId = "E6E3D0917DD641581E4779524EB3B1AA"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$root\mt5\SMC_Universal.mq5")) {
    $root = "d:\Dev\TradBOT"
}

$mt5Base = "$env:APPDATA\MetaQuotes\Terminal\$TerminalId\MQL5"
$experts = Join-Path $mt5Base "Experts"
$modules = Join-Path $experts "modules"

if (-not (Test-Path $experts)) {
    Write-Error "Dossier Experts introuvable: $experts`nVerifiez -TerminalId (MetaTrader: Fichier > Ouvrir le dossier de donnees)."
}

New-Item -ItemType Directory -Force -Path $modules | Out-Null

Copy-Item "$root\mt5\SMC_Universal.mq5" "$experts\SMC_Universal.mq5" -Force
Copy-Item "$root\mt5\modules\SMC_GOM_Pipeline.mqh" "$modules\SMC_GOM_Pipeline.mqh" -Force

Write-Host ""
Write-Host "Deploy OK:"
Write-Host "  $experts\SMC_Universal.mq5"
Write-Host "  $modules\SMC_GOM_Pipeline.mqh"
Write-Host ""
Write-Host "MetaEditor: ouvrir SMC_Universal.mq5 puis F7 (Compiler)."
Write-Host "WebRequest: autoriser http://127.0.0.1:8000 dans Outils > Options > Expert Advisors."
