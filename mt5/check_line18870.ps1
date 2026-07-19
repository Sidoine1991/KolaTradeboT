$c = Get-Content 'D:\Dev\TradBOT\mt5\SMC_Universal.mq5' -Encoding UTF8
# Line 18870 (0-indexed = 18869)
$line = $c[18869]
Write-Host "Line 18870 length: $($line.Length)"
Write-Host "Line 18870 chars: [$line]"
# Show char by char around position 20
for ($i = [Math]::Max(0,15); $i -lt [Math]::Min($line.Length,30); $i++) {
    Write-Host "  pos $($i+1): char=[$($line[$i])] code=$([int]$line[$i])"
}
