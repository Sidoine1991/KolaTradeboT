$metaeditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$ea_file = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"

if (!(Test-Path $metaeditor)) {
    Write-Host "MetaEditor64.exe not found"
    exit 1
}

Write-Host "Compiling SMC_Universal.mq5..."
& $metaeditor /compile:"$ea_file" /exit
Write-Host "Done"
