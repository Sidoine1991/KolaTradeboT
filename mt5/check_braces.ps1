# Count braces to find mismatches
$content = Get-Content 'D:\Dev\TradBOT\mt5\SMC_Universal.mq5' -Raw -Encoding UTF8
$lines = $content -split "`r?`n"

$depth = 0
$inString = $false
$inComment = $false
$inLineComment = $false
$prevChar = ''

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    for ($j = 0; $j -lt $line.Length; $j++) {
        $ch = $line[$j]
        
        if ($inLineComment) {
            if ($ch -eq "`n") { $inLineComment = $false }
            continue
        }
        if ($inComment) {
            if ($prevChar -eq '*' -and $ch -eq '/') { $inComment = $false }
            $prevChar = $ch
            continue
        }
        
        # Check for // comment
        if ($ch -eq '/' -and ($j + 1) -lt $line.Length -and $line[$j + 1] -eq '/') {
            $inLineComment = $true
            continue
        }
        # Check for /* comment */
        if ($ch -eq '/' -and ($j + 1) -lt $line.Length -and $line[$j + 1] -eq '*') {
            $inComment = $true
            $prevChar = '*'
            $j++ # skip the *
            continue
        }
        
        # Skip strings
        if ($ch -eq '"' -and $prevChar -ne '\') {
            $inString = -not $inString
            $prevChar = $ch
            continue
        }
        if ($inString) {
            $prevChar = $ch
            continue
        }
        
        if ($ch -eq '{') {
            $depth++
        } elseif ($ch -eq '}') {
            $depth--
            if ($depth -lt 0) {
                Write-Host "EXTRA } at line $($i+1): $line"
            }
        }
        $prevChar = $ch
    }
}
Write-Host "Final brace depth: $depth"
Write-Host "Total lines: $($lines.Count)"
