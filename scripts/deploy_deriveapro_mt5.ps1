# Deploy deriveapro.mq5 + GOMVerdict.mqh vers MetaTrader 5 Experts
# Usage: .\scripts\deploy_deriveapro_mt5.ps1
#        .\scripts\deploy_deriveapro_mt5.ps1 -TerminalId E6E3D0917DD641581E4779524EB3B1AA

param(
    [string]$TerminalId = "E6E3D0917DD641581E4779524EB3B1AA"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$root\mt5\deriveapro.mq5")) {
    $root = "d:\Dev\TradBOT"
}

$mt5Base = "$env:APPDATA\MetaQuotes\Terminal\$TerminalId\MQL5"
$experts = Join-Path $mt5Base "Experts"
$commonFiles = Join-Path $mt5Base "Files"

if (-not (Test-Path $experts)) {
    Write-Error "Dossier Experts introuvable: $experts`nVerifiez -TerminalId (MetaTrader: Fichier > Ouvrir le dossier de donnees)."
}

New-Item -ItemType Directory -Force -Path $experts | Out-Null
New-Item -ItemType Directory -Force -Path $commonFiles | Out-Null

Copy-Item "$root\mt5\deriveapro.mq5" "$experts\deriveapro.mq5" -Force
Copy-Item "$root\mt5\GOMVerdict.mqh" "$experts\GOMVerdict.mqh" -Force

$gomSrc = "$root\data\gom_signal.json"
$gomDst = Join-Path $commonFiles "gom_signal.json"
if (Test-Path $gomSrc) {
    Copy-Item $gomSrc $gomDst -Force
    Write-Host "gom_signal.json -> Common\Files"
} else {
    $template = @'
{
  "symbol": "XAUUSD",
  "verdict": "WAIT",
  "verdict_num": 0,
  "buy_score": 0,
  "sell_score": 0,
  "spike_pct": 0,
  "quality": 0,
  "coherence": 0,
  "kola_state": "---"
}
'@
    Set-Content -Path $gomDst -Value $template -Encoding UTF8
    Write-Host "gom_signal.json (modele) cree dans Common\Files"
}

Write-Host ""
Write-Host "Deploy OK:"
Write-Host "  $experts\deriveapro.mq5"
Write-Host "  $experts\GOMVerdict.mqh"
Write-Host "  $gomDst"
Write-Host ""
Write-Host "MetaEditor: ouvrir deriveapro.mq5 puis F7 (Compiler)."
