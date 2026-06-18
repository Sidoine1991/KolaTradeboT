#!/usr/bin/env powershell
# Direct compilation script for SMC_Universal.mq5

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     COMPILATION DE SMC_Universal.mq5                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$MetaEditorPath = "D:\Program Files\MetaTrader 5\MetaEditor64.exe"
$SourceFile = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
$ExePath = "D:\Dev\TradBOT\mt5\SMC_Universal.ex5"

# Verify paths
Write-Host "Vérification des chemins..." -ForegroundColor Yellow
if (-not (Test-Path $MetaEditorPath)) {
    Write-Host "❌ ERREUR: MetaEditor introuvable à: $MetaEditorPath" -ForegroundColor Red
    Write-Host "   Vérifiez l'installation de MetaTrader 5 sur le disque D:" -ForegroundColor Red
    exit 1
}
Write-Host "✅ MetaEditor trouvé: $MetaEditorPath" -ForegroundColor Green

if (-not (Test-Path $SourceFile)) {
    Write-Host "❌ ERREUR: Fichier source introuvable: $SourceFile" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Fichier source trouvé" -ForegroundColor Green
Write-Host ""

# Delete old binary
Write-Host "Suppression de l'ancien binaire..." -ForegroundColor Yellow
Remove-Item -Path $ExePath -Force -ErrorAction SilentlyContinue
Write-Host "✅ Ancien binaire supprimé" -ForegroundColor Green
Write-Host ""

# Compile
Write-Host "Lancement de la compilation..." -ForegroundColor Yellow
Write-Host "This may take 30-60 seconds..." -ForegroundColor Cyan
Write-Host ""

& $MetaEditorPath $SourceFile /compile 2>&1

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Check result
if (Test-Path $ExePath) {
    $FileInfo = Get-Item $ExePath
    $Size = "{0:F2}" -f ($FileInfo.Length / 1024)

    Write-Host "✅ COMPILATION RÉUSSIE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 Binaire créé: $ExePath" -ForegroundColor Green
    Write-Host "📊 Taille: ${Size} KB" -ForegroundColor Green
    Write-Host "🕐 Timestamp: $($FileInfo.LastWriteTime)" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 PRÊT POUR DEPLOYMENT!" -ForegroundColor Green
} else {
    Write-Host "❌ COMPILATION ÉCHOUÉE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Vérifiez les messages d'erreur ci-dessus." -ForegroundColor Yellow
    Write-Host "Erreurs courantes:" -ForegroundColor Yellow
    Write-Host "  - MetaEditor fermé incomplètement" -ForegroundColor Gray
    Write-Host "  - Cache MetaEditor obsolète" -ForegroundColor Gray
    Write-Host "  - Chemin incorrect" -ForegroundColor Gray
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Read-Host "Appuyez sur ENTRÉE pour fermer"
