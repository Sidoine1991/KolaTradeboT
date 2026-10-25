@echo off
echo ========================================
echo NETTOYAGE DUPLICATE DECLARATIONS
echo ========================================
echo.

echo ✅ Suppression des déclarations en double...
echo.

REM Créer une version nettoyée du fichier
powershell -Command "
$content = Get-Content 'BoomCrash_Strategy_Bot.mq5'
$cleaned = @()
$skipLines = $false
$lineNumber = 0

foreach ($line in $content) {
    $lineNumber++
    
    # Skip duplicate AISignal struct (lines 690-697)
    if ($lineNumber -ge 690 -and $lineNumber -le 697) {
        continue
    }
    
    # Skip duplicate current_ai_signal (line 699)
    if ($lineNumber -eq 699) {
        continue
    }
    
    # Skip duplicate UpdateFromDecision function (start at line 704)
    if ($line -match 'void UpdateFromDecision') {
        $skipLines = $true
        continue
    }
    
    # Skip until we find the next function after UpdateFromDecision
    if ($skipLines -and $line -match 'void ParseAIResponse') {
        $skipLines = $false
        continue
    }
    
    # Skip duplicate ParseAIResponse function
    if ($line -match 'void ParseAIResponse' -and $lineNumber -gt 810) {
        $skipLines = $true
        continue
    }
    
    # Stop skipping at the next function after ParseAIResponse
    if ($skipLines -and $line -match '//\+------------------------------------------------------------------\+' -and $lineNumber -gt 1400) {
        $skipLines = $false
        $cleaned += $line
        continue
    }
    
    if (-not $skipLines) {
        $cleaned += $line
    }
}

# Save cleaned version
$cleaned | Out-File -FilePath 'BoomCrash_Strategy_Bot_cleaned.mq5' -Encoding UTF8
Write-Host '✅ Fichier nettoyé créé: BoomCrash_Strategy_Bot_cleaned.mq5'
"

echo.
echo 📋 Nettoyage terminé!
echo.
pause
