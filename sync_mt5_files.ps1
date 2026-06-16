#Requires -Version 3.0
<#
.SYNOPSIS
    Synchronize TradBOT MT5 files to MetaTrader 5 terminal for compilation
.DESCRIPTION
    Copies SMC_Universal.mq5 and all dependent modules to the MT5 terminal
    directory for MetaEditor compilation
.EXAMPLE
    .\sync_mt5_files.ps1
#>

# Configuration
$TerminalPath = 'C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA'
$ProjectPath = 'D:\Dev\TradBOT\mt5'
$ExpertsPath = "$TerminalPath\MQL5\Experts"
$ModulesPath = "$ExpertsPath\modules"

# Required files
$Files = @(
    @{ src = 'SMC_Universal.mq5'; dest = 'SMC_Universal.mq5'; dir = $ExpertsPath }
)

$Modules = @(
    'GOM_Graphics.mqh',
    'LossCooldownManager.mqh',
    'OrderflowGraphics.mqh',
    'SMC_GOM_Pipeline.mqh',
    'SMC_PerformancePause.mqh',
    'SMC_ProbabilityGate.mqh',
    'SMC_TradeJournal.mqh'
)

function Write-Status {
    param([string]$Status, [string]$Color = "Gray")
    Write-Host "[$Status]" -ForegroundColor $Color -NoNewline
    Write-Host " "
}

# Verify terminal exists
Write-Host "SMC_Universal MT5 Sync Tool" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $TerminalPath)) {
    Write-Status "ERROR" "Red"
    Write-Host "Terminal not found: $TerminalPath"
    exit 1
}

Write-Status "OK" "Green"
Write-Host "Terminal found: $TerminalPath"

# Verify directories
if (-not (Test-Path $ExpertsPath)) {
    Write-Status "WARN" "Yellow"
    Write-Host "Experts directory not found, creating..."
    New-Item -ItemType Directory -Path $ExpertsPath -Force | Out-Null
}

if (-not (Test-Path $ModulesPath)) {
    Write-Status "INFO" "Blue"
    Write-Host "Modules directory not found, creating..."
    New-Item -ItemType Directory -Path $ModulesPath -Force | Out-Null
}

Write-Host ""

# Copy EA file
Write-Status "COPY" "Cyan"
Write-Host "EA File"

foreach ($file in $Files) {
    $src = Join-Path $ProjectPath $file.src
    $dst = Join-Path $file.dir $file.dest

    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Status "OK" "Green"
        Write-Host "$($file.src) → $($file.dest)"
    } else {
        Write-Status "SKIP" "Yellow"
        Write-Host "$($file.src) not found"
    }
}

Write-Host ""

# Copy modules
Write-Status "COPY" "Cyan"
Write-Host "Modules ($($Modules.Count) files)"

$copied = 0
foreach ($module in $Modules) {
    $src = Join-Path $ProjectPath "modules\$module"
    $dst = Join-Path $ModulesPath $module

    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Status "OK" "Green"
        Write-Host "$module"
        $copied++
    } else {
        Write-Status "SKIP" "Yellow"
        Write-Host "$module not found"
    }
}

Write-Host ""
Write-Status "DONE" "Green"
Write-Host "Sync complete: $copied/$($Modules.Count) modules copied"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open MetaEditor 5"
Write-Host "  2. Open: File → Open → mt5/SMC_Universal.mq5"
Write-Host "  3. Compile: Press F5 or Build → Compile"
Write-Host "  4. Check: Toolbox → Errors tab"
Write-Host ""
