# Script de compilation SMC_Universal - détection automatique MT5

$eaFile = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"

# Chemins possibles de MetaEditor
$possiblePaths = @(
    "C:\Program Files\MetaTrader 5\metaeditor64.exe",
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe",
    "D:\MetaTrader 5\metaeditor64.exe",
    "C:\MT5\metaeditor64.exe"
)

# Chercher le premier chemin qui existe
$metaEditor = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $metaEditor = $path
        Write-Host "✅ MetaEditor trouvé: $path" -ForegroundColor Green
        break
    }
}

if (-not $metaEditor) {
    Write-Host "❌ MetaEditor64.exe non trouvé" -ForegroundColor Red
    Write-Host ""
    Write-Host "Chemins testés:"
    foreach ($path in $possiblePaths) {
        Write-Host "  - $path"
    }
    Write-Host ""
    Write-Host "Comment corriger:"
    Write-Host "  1. Ouvrir MetaTrader 5"
    Write-Host "  2. Trouver le dossier d'installation"
    Write-Host "  3. Ou utiliser MetaEditor depuis MT5 directement (Tools > Edit Script)"
    exit 1
}

if (-not (Test-Path $eaFile)) {
    Write-Host "❌ Fichier EA non trouvé: $eaFile" -ForegroundColor Red
    exit 1
}

Write-Host "🔄 Compilation en cours..." -ForegroundColor Yellow
Write-Host ""

# Compiler
& $metaEditor "/compile:$eaFile" /exit

Write-Host ""
Write-Host "✅ Compilation terminée!" -ForegroundColor Green
Write-Host "Vérifiez les erreurs dans MetaEditor (onglet Errors)"
