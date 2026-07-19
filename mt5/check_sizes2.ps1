$files = @(
    'D:\Dev\TradBOT\mt5\SMC_Universal.mq5',
    'D:\Dev\TradBOT\mt5\SMC_Universal.mq5.before_fix',
    'D:\Dev\TradBOT\mt5\SMC_Universal.mq5.broken',
    'D:\Dev\TradBOT\mt5\SMC_Universal_PROD.mq5',
    'D:\Dev\TradBOT\mt5\SMC_Universal_FIXED.mq5'
)
foreach ($f in $files) {
    if (Test-Path $f) {
        $item = Get-Item $f
        $lc = (Get-Content $f -Encoding UTF8).Count
        Write-Host "$($item.Name): $($item.Length) bytes, $lc lines"
    }
}
