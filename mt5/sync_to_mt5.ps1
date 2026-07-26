# Sync SMC_Universal.mq5 + modules from repo to ALL MT5 Experts folders.
$src = Split-Path -Parent $MyInvocation.MyCommand.Definition
$mqBase = Join-Path $env:APPDATA "MetaQuotes\Terminal"

$targets = @()
Get-ChildItem -Path $mqBase -Recurse -Directory -Filter "Experts" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\MQL5\\Experts$" } |
    ForEach-Object { $targets += $_.FullName }

$targets = $targets | Sort-Object -Unique
if ($targets.Count -eq 0) {
    Write-Warning "No MQL5\Experts folders found under $mqBase"
    exit 1
}

$srcMq5 = Join-Path $src "SMC_Universal.mq5"
$srcMod = Join-Path $src "modules"
if (-not (Test-Path $srcMq5)) { Write-Error "Missing $srcMq5"; exit 1 }

foreach ($t in $targets) {
    $mod = Join-Path $t "modules"
    if (-not (Test-Path $mod)) { New-Item -ItemType Directory -Path $mod | Out-Null }

    # EA source (depot SMC_Universal.mq5) -> copie sous les deux noms utilises
    Copy-Item -Force $srcMq5 (Join-Path $t "SMC_Universal.mq5")
    Copy-Item -Force $srcMq5 (Join-Path $t "SMC_smart_Trader.mq5")

    # EX5 compilé (si present) -> copie sous les deux noms pour pouvoir trader direct
    $srcEx5 = [System.IO.Path]::ChangeExtension($srcMq5, ".ex5")
    if (Test-Path $srcEx5) {
        Copy-Item -Force $srcEx5 (Join-Path $t "SMC_Universal.ex5")
        Copy-Item -Force $srcEx5 (Join-Path $t "SMC_smart_Trader.ex5")
    }

    # Modules complets
    Copy-Item -Force -Recurse (Join-Path $srcMod "*") $mod

    # Dossier Modele_spike (SpikeChainPredictor.mqh)
    $srcSpike = Join-Path $src "Modele_spike"
    if (Test-Path $srcSpike) {
        $dstSpike = Join-Path $t "Modele_spike"
        if (-not (Test-Path $dstSpike)) { New-Item -ItemType Directory -Path $dstSpike | Out-Null }
        Copy-Item -Force -Recurse (Join-Path $srcSpike "*") $dstSpike
    }

    Write-Host "OK -> $t"
}

# Remove stale Include copies (wrong location — compiler may pick corrupted duplicate)
$includeCopies = Get-ChildItem -Path $mqBase -Recurse -Filter "SMC_Universal.mq5" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\Include\\" }
foreach ($f in $includeCopies) {
    Remove-Item -Force $f.FullName
    Write-Host "Removed stale Include copy: $($f.FullName)"
}

$staleModuleNames = @(
    "SMC_GOM_Pipeline.mqh",
    "SMC_PredictivePanel.mqh",
    "SMC_FuturePath.mqh",
    "SMC_PreSpikeGuard.mqh",
    "SMC_ExitManagement.mqh",
    "SMC_MarketIntelligence.mqh",
    "SMC_MasterScore.mqh",
    "SMC_PerformancePause.mqh",
    "SMC_ProbabilityGate.mqh",
    "SMC_TradeJournal.mqh",
    "GOM_Graphics.mqh",
    "MT5_Candles_Uploader.mqh",
    "OrderflowGraphics.mqh",
    "SMC_PatternSignals.mqh",
    "SMC_PathTrailBonus.mqh",
    "LossCooldownManager.mqh"
)
foreach ($name in $staleModuleNames) {
    Get-ChildItem -Path $mqBase -Recurse -Filter $name -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\Experts\\modules\\" } |
        ForEach-Object {
            Remove-Item -Force $_.FullName
            Write-Host "Removed stale module copy: $($_.FullName)"
        }
}

# Nested modules/modules from bad past syncs
Get-ChildItem -Path $mqBase -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\Experts\\modules\\modules$" } |
    ForEach-Object {
        Remove-Item -Recurse -Force $_.FullName
        Write-Host "Removed nested modules folder: $($_.FullName)"
    }

Write-Host "Synced $($targets.Count) terminal(s). Compile MQL5\Experts\SMC_Universal.mq5 (F7)."
