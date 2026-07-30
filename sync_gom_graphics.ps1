$src = 'D:\Dev\TradBOT\mt5\modules\GOM_Graphics.mqh'
$instances = @(
    'C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\415DD75DEF29D458F52EB44204841A9C\MQL5\Experts\modules',
    'C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\62DE0881527B5F589A310F71C9C0578C\MQL5\Experts\modules',
    'C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\modules',
    'C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts\modules'
)
foreach($inst in $instances) {
    if(!(Test-Path $inst)) {
        New-Item -ItemType Directory -Path $inst -Force | Out-Null
        Write-Host "Created: $inst"
    }
    Copy-Item $src "$inst\GOM_Graphics.mqh" -Force
    Write-Host "OK: $inst"
}
Copy-Item $src 'D:\Dev\MT5\Trading\TradBOT\modules\GOM_Graphics.mqh' -Force -ErrorAction SilentlyContinue
Write-Host "Sync complete"