# Reset giveback + deploy ResetGivebackAll.mq5 sur plusieurs terminaux MT5
# Usage: .\scripts\Reset-GivebackTerminals.ps1
#        .\scripts\Reset-GivebackTerminals.ps1 -DeployEA -TerminalId 415DD75DEF29D458F52EB44204841A9C

param(
    [string[]]$TerminalIds = @(
        "F016FF5B93786543B564E81A925D7066",
        "415DD75DEF29D458F52EB44204841A9C",
        "E6E3D0917DD641581E4779524EB3B1AA"
    ),
    [switch]$DeployEA
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$srcMq5 = Join-Path $root "mt5"
$resetScript = Join-Path $srcMq5 "scripts\ResetGivebackAll.mq5"
$resetLegacy = Join-Path $srcMq5 "scripts\ResetGiveback.mq5"

if (-not (Test-Path $resetScript)) {
    Write-Error "Script introuvable: $resetScript"
}

foreach ($tid in $TerminalIds) {
    $base = Join-Path $env:APPDATA "MetaQuotes\Terminal\$tid\MQL5"
    if (-not (Test-Path $base)) {
        Write-Warning "Terminal ignoré (introuvable): $tid"
        continue
    }

    $scriptsDir = Join-Path $base "Scripts"
    $expertsDir = Join-Path $base "Experts"
    $modulesDir = Join-Path $expertsDir "modules"
    New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null

    Copy-Item $resetScript (Join-Path $scriptsDir "ResetGivebackAll.mq5") -Force
    if (Test-Path $resetLegacy) {
        Copy-Item $resetLegacy (Join-Path $scriptsDir "ResetGiveback.mq5") -Force
    }
    Write-Host "[OK] Reset scripts -> $scriptsDir"

    if ($DeployEA -or $tid -eq "415DD75DEF29D458F52EB44204841A9C") {
        New-Item -ItemType Directory -Force -Path $modulesDir | Out-Null
        Copy-Item (Join-Path $srcMq5 "SMC_Universal.mq5") (Join-Path $expertsDir "SMC_Universal.mq5") -Force
        Get-ChildItem (Join-Path $srcMq5 "modules\*.mqh") | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $modulesDir $_.Name) -Force
        }
        Write-Host "[OK] SMC_Universal + modules -> $expertsDir"
    }
}

Write-Host ""
Write-Host "=== Giveback reset (manuel, MT5 ouvert) ==="
Write-Host "Sur CHAQUE terminal:"
Write-Host "  1. Ouvrir n'importe quel graphique avec SMC_Universal actif"
Write-Host "  2. Navigateur > Scripts > ResetGivebackAll > glisser sur le graphique"
Write-Host "  3. Verifier le log: [RESET-GIVEBACK-ALL] Terminal reset"
Write-Host "  4. Verifier EA: [GIVEBACK-GUARD] Reset manuel — pic journalier repart"
Write-Host ""
Write-Host "Terminal 415DD75: compiler SMC_Universal.mq5 (F7) puis attacher l'EA."
