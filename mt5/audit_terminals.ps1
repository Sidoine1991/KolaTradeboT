# Audit MT5 terminals vs repo — modules + SMC_Universal.mq5
$srcRoot = Join-Path $PSScriptRoot "."
$srcMq5  = Join-Path $srcRoot "SMC_Universal.mq5"
$srcMod  = Join-Path $srcRoot "modules"
$mqBase  = Join-Path $env:APPDATA "MetaQuotes\Terminal"

$required = @(
    "SMC_TradeJournal.mqh", "GOM_Graphics.mqh", "SMC_GOM_Pipeline.mqh", "MT5_Candles_Uploader.mqh",
    "SMC_FuturePath.mqh", "SMC_PreSpikeGuard.mqh", "LossCooldownManager.mqh", "SMC_PerformancePause.mqh",
    "SMC_ProbabilityGate.mqh", "OrderflowGraphics.mqh", "SMC_ExitManagement.mqh", "SMC_MarketIntelligence.mqh",
    "SMC_MasterScore.mqh", "SMC_PredictivePanel.mqh", "SMC_PathTrailBonus.mqh", "SMC_PatternSignals.mqh"
)

$targets = Get-ChildItem -Path $mqBase -Recurse -Directory -Filter "Experts" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\MQL5\\Experts$" } |
    ForEach-Object { $_.FullName } | Sort-Object -Unique

$srcHashMq5 = (Get-FileHash $srcMq5 -Algorithm SHA256).Hash

Write-Host "=== SOURCE REPO ==="
Write-Host ("SMC_Universal.mq5  " + (Get-Item $srcMq5).LastWriteTime + "  " + $srcHashMq5.Substring(0, 12))
foreach ($m in $required) {
    $p = Join-Path $srcMod $m
    if (Test-Path $p) {
        $h = (Get-FileHash $p -Algorithm SHA256).Hash
        Write-Host ("  OK " + $m + "  " + (Get-Item $p).LastWriteTime + "  " + $h.Substring(0, 12))
    }
    else {
        Write-Host ("  MISSING " + $m)
    }
}

Write-Host ""
Write-Host ("=== TERMINALS (" + $targets.Count + ") ===")
$allOk = $true
foreach ($t in $targets) {
    $termId = ($t -split [regex]::Escape("Terminal\"))[1] -split "\\" | Select-Object -First 1
    $mq5    = Join-Path $t "SMC_Universal.mq5"
    $modDir = Join-Path $t "modules"
    Write-Host ("--- " + $termId + " ---")
    if (-not (Test-Path $mq5)) {
        Write-Host "  MISSING SMC_Universal.mq5"
        $allOk = $false
        continue
    }
    $hMq5  = (Get-FileHash $mq5 -Algorithm SHA256).Hash
    $mq5Ok = ($hMq5 -eq $srcHashMq5)
    Write-Host ("  SMC_Universal.mq5 " + $(if ($mq5Ok) { "SYNC" } else { "STALE" }) + " " + (Get-Item $mq5).LastWriteTime)
    if (-not $mq5Ok) { $allOk = $false }

    $missing = @()
    $stale   = @()
    foreach ($m in $required) {
        $dest = Join-Path $modDir $m
        $src  = Join-Path $srcMod $m
        if (-not (Test-Path $dest)) { $missing += $m; continue }
        if ((Get-FileHash $dest -Algorithm SHA256).Hash -ne (Get-FileHash $src -Algorithm SHA256).Hash) {
            $stale += $m
        }
    }
    if ($missing.Count -eq 0 -and $stale.Count -eq 0 -and $mq5Ok) {
        Write-Host "  ALL OK (mq5 + 16 modules)"
    }
    else {
        $allOk = $false
        if ($missing.Count) { Write-Host ("  MISSING: " + ($missing -join ", ")) }
        if ($stale.Count)   { Write-Host ("  STALE: " + ($stale -join ", ")) }
    }

    foreach ($m in $required) {
        Get-ChildItem -Path $mqBase -Recurse -Filter $m -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like ("*" + $termId + "*") -and $_.FullName -notmatch "\\Experts\\modules\\" } |
            ForEach-Object { Write-Host ("  DUPLICATE (remove): " + $_.FullName) }
    }
}

Write-Host ""
if ($allOk) { Write-Host "RESULT: ALL TERMINALS IN SYNC" }
else { Write-Host "RESULT: SYNC REQUIRED - run sync_to_mt5.ps1"; exit 1 }
