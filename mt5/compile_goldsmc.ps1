$metaeditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$ea_file = "D:\Dev\TradBOT\mt5\GoldSMC_EA.mq5"

if (!(Test-Path $metaeditor)) {
    Write-Host "MetaEditor64.exe not found at: $metaeditor"
    exit 1
}

Write-Host "Compiling GoldSMC_EA.mq5..."
Write-Host "EA File: $ea_file"
Write-Host "MetaEditor: $metaeditor"
Write-Host ""

& $metaeditor /compile:"$ea_file" /exit

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Compilation successful"
    exit 0
} else {
    Write-Host "❌ Compilation failed (exit code: $LASTEXITCODE)"
    exit 1
}
