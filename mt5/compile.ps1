# Script de compilation PowerShell pour Fx_robot.mq5
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  COMPILATION FX_ROBOT.MQ5" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Chemin vers MetaEditor
$metaEditorPath = "D:\Program Files\MetaTrader 5\metaeditor.exe"
$sourceFile = "Fx_robot.mq5"
$logFile = "compile_log.txt"

# Vérifier si MetaEditor existe
if (-not (Test-Path $metaEditorPath)) {
    Write-Host "❌ ERREUR: MetaEditor non trouvé à: $metaEditorPath" -ForegroundColor Red
    Write-Host "Vérifiez que MetaTrader 5 est bien installé à cet emplacement." -ForegroundColor Yellow
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

# Vérifier si le fichier source existe
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ ERREUR: Fichier source non trouvé: $sourceFile" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

Write-Host "✅ MetaEditor trouvé: $metaEditorPath" -ForegroundColor Green
Write-Host "✅ Fichier source trouvé: $sourceFile" -ForegroundColor Green
Write-Host ""

# Lancer la compilation
Write-Host "🔨 Compilation en cours..." -ForegroundColor Yellow
Write-Host ""

try {
    # Préparer les arguments
    $arguments = @("/compile:$sourceFile", "/log:$logFile")
    
    # Lancer MetaEditor
    $process = Start-Process -FilePath $metaEditorPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    
    # Vérifier le résultat
    if ($process.ExitCode -eq 0) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✅ COMPILATION RÉUSSIE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Le fichier $sourceFile a été compilé avec succès." -ForegroundColor White
        Write-Host "L'Expert Advisor est prêt à être utilisé dans MetaTrader 5." -ForegroundColor White
        Write-Host ""
        
        # Vérifier si le fichier .ex5 a été créé
        $ex5File = $sourceFile.Replace(".mq5", ".ex5")
        if (Test-Path $ex5File) {
            Write-Host "✅ Fichier compilé créé: $ex5File" -ForegroundColor Green
            $fileInfo = Get-Item $ex5File
            Write-Host "   Taille: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
            Write-Host "   Créé: $($fileInfo.CreationTime)" -ForegroundColor Gray
        }
        
    } else {
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "❌ ERREUR DE COMPILATION!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Code d'erreur: $($process.ExitCode)" -ForegroundColor Yellow
        Write-Host ""
        
        # Afficher le log si disponible
        if (Test-Path $logFile) {
            Write-Host "Contenu du fichier de log:" -ForegroundColor Yellow
            Write-Host "----------------------------------------" -ForegroundColor Gray
            Get-Content $logFile | ForEach-Object { Write-Host $_ -ForegroundColor White }
            Write-Host "----------------------------------------" -ForegroundColor Gray
        } else {
            Write-Host "Fichier de log non trouvé: $logFile" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "❌ ERREUR lors de l'exécution de MetaEditor:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Read-Host "Appuyez sur Entrée pour quitter"
