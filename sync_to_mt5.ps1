# Sync SMC_Universal.mq5 and modules to all MT5 terminal directories
$terminals = @(
    "D:\Dev\MT5\Trading\TradBOT"
)

$source = "D:\Dev\TradBOT\mt5"

foreach ($term in $terminals) {
    # Paths to remove stale files from
    $includeDir = "$term\Include"
    $modulesDir = "$term\modules"

    # Create directories if they don't exist
    if (-not (Test-Path $modulesDir)) { New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null }

    # Remove stale module copies from Include
    if (Test-Path $includeDir) {
        Remove-Item -LiteralPath "$includeDir\SMC_DowTrendline.mqh" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$includeDir\SMC_SignalGates.mqh" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$includeDir\SMC_GOM_Pipeline.mqh" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$includeDir\SMC_DataStructs.mqh" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$includeDir\SMC_ArrayHelpers.mqh" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$includeDir\SMC_PriceAction.mqh" -Force -ErrorAction SilentlyContinue
    }

    # Copy main EA
    Copy-Item -LiteralPath "$source\SMC_Universal.mq5" -Destination "$term\SMC_Universal.mq5" -Force

    # Copy all modules
    Get-ChildItem -Path "$source\modules\*.mqh" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination "$modulesDir\$($_.Name)" -Force
    }

    Write-Host "✓ Synced $term"
}
