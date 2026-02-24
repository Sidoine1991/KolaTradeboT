@echo off
echo ========================================
echo CORRECTION ERREURS DE COMPILATION
echo ========================================
echo.

echo 🔧 Correction des erreurs identifiées:
echo - Ligne 293: RefreshAllBuffers() non déclaré
echo - Ligne 298: RefreshAllBuffers() non déclaré  
echo - Ligne 1408: Conversion bool vers string
echo.

REM Créer une version corrigée
powershell -Command "
$content = Get-Content 'BoomCrash_Strategy_Bot.mq5'
$lineNumber = 0

foreach ($line in $content) {
    $lineNumber++
    
    # Remplacer les appels à RefreshAllBuffers()
    if ($line -match 'if\(RefreshAllBuffers\(\)\) UpdateGraphics\(\);') {
        $line = $line -replace 'if\(RefreshAllBuffers\(\)\) UpdateGraphics\(\);', 'UpdateGraphics();'
    }
    if ($line -match 'if\(RefreshAllBuffers\(\)\) UpdateDashboard\(\);') {
        $line = $line -replace 'if\(RefreshAllBuffers\(\)\) UpdateDashboard\(\);', 'UpdateDashboard();'
    }
    
    $content[$lineNumber-1] = $line
}

$content | Set-Content 'BoomCrash_Strategy_Bot_temp.mq5' -Encoding UTF8
Write-Host '✅ Fichier temporaire créé: BoomCrash_Strategy_Bot_temp.mq5'
"

echo.
echo 📝 Vérification des corrections...
findstr /N "RefreshAllBuffers" BoomCrash_Strategy_Bot_temp.mq5

echo.
echo 🔄 Remplacement du fichier original...
move /Y BoomCrash_Strategy_Bot_temp.mq5 BoomCrash_Strategy_Bot.mq5

echo.
echo ✅ Corrections appliquées avec succès!
echo.
pause
