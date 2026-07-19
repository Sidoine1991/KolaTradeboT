# Check for hidden chars around the error lines
$lines = Get-Content 'D:\Dev\TradBOT\mt5\SMC_Universal.mq5' -Encoding UTF8
Write-Host "Total lines: $($lines.Count)"

# Check lines 14700-14710
Write-Host "`n=== Lines 14700-14710 ==="
for ($i = 14699; $i -le 14709; $i++) {
    $line = $lines[$i]
    $hex = ($line.ToCharArray() | ForEach-Object { '{0:X2}' -f [int]$_ }) -join ' '
    Write-Host "L$($i+1): [$line]"
    if ($line.Length -gt 0) {
        Write-Host "  HEX: $hex"
    }
}

# Check lines 18865-18880
Write-Host "`n=== Lines 18865-18880 ==="
for ($i = 18864; $i -le 18879; $i++) {
    if ($i -lt $lines.Count) {
        $line = $lines[$i]
        Write-Host "L$($i+1): [$line]"
    }
}

# Check lines 14395-14420  
Write-Host "`n=== Lines 14395-14420 ==="
for ($i = 14394; $i -le 14419; $i++) {
    if ($i -lt $lines.Count) {
        $line = $lines[$i]
        Write-Host "L$($i+1): [$line]"
    }
}
