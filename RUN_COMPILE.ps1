#!/usr/bin/env powershell
# Compilation directe vers MT5 Experts

$SOURCE = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
$EXPERTS = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts"
$METAEDITOR = "D:\Program Files\MetaTrader 5\MetaEditor64.exe"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      COMPILATION FINALE DE SMC_Universal.mq5                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Vérifications
Write-Host "[1/4] Vérification des chemins..." -ForegroundColor Yellow
if (-not (Test-Path $SOURCE)) {
    Write-Host "❌ Source introuvable: $SOURCE" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Source trouvée" -ForegroundColor Green

if (-not (Test-Path $METAEDITOR)) {
    Write-Host "❌ MetaEditor introuvable: $METAEDITOR" -ForegroundColor Red
    exit 1
}
Write-Host "✓ MetaEditor trouvé" -ForegroundColor Green

if (-not (Test-Path $EXPERTS)) {
    Write-Host "Création du dossier Experts..."
    New-Item -Path $EXPERTS -ItemType Directory -Force | Out-Null
}
Write-Host "✓ Dossier Experts accessible" -ForegroundColor Green

Write-Host ""
Write-Host "[2/4] Suppression des anciens binaires..." -ForegroundColor Yellow
Remove-Item -Path "$EXPERTS\SMC_Universal.ex5" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Dev\TradBOT\mt5\SMC_Universal.ex5" -Force -ErrorAction SilentlyContinue
Write-Host "✓ Ancien binaire supprimé" -ForegroundColor Green

Write-Host ""
Write-Host "[3/4] Lancement de la compilation..." -ForegroundColor Yellow
Write-Host "      Veuillez patienter (30-60 secondes)..." -ForegroundColor Cyan
Write-Host ""

& $METAEDITOR $SOURCE /compile 2>&1

Write-Host ""
Write-Host "[4/4] Vérification du résultat..." -ForegroundColor Yellow
Write-Host ""

# Vérifier le résultat
if (Test-Path "$EXPERTS\SMC_Universal.ex5") {
    $File = Get-Item "$EXPERTS\SMC_Universal.ex5"
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          ✅ COMPILATION RÉUSSIE!                             ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 Binaire créé dans Experts:" -ForegroundColor Green
    Write-Host "   $EXPERTS\SMC_Universal.ex5" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Détails:" -ForegroundColor Cyan
    Write-Host "   Taille: $('{0:F2}' -f ($File.Length / 1024)) KB" -ForegroundColor Gray
    Write-Host "   Timestamp: $($File.LastWriteTime)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🎉 LE ROBOT EST CHARGÉ DANS MT5!" -ForegroundColor Green
    Write-Host ""
    Write-Host "    Attachez le robot à un graphique:" -ForegroundColor Cyan
    Write-Host "    1. Clic droit sur graphique" -ForegroundColor Gray
    Write-Host "    2. Sélectionnez: Attach EA" -ForegroundColor Gray
    Write-Host "    3. Choisissez: SMC_Universal" -ForegroundColor Gray
    Write-Host "    4. Cliquez: OK" -ForegroundColor Gray
} elseif (Test-Path "D:\Dev\TradBOT\mt5\SMC_Universal.ex5") {
    $File = Get-Item "D:\Dev\TradBOT\mt5\SMC_Universal.ex5"
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║   ✅ COMPILATION RÉUSSIE (Local)!                            ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📁 Binaire créé:" -ForegroundColor Yellow
    Write-Host "   D:\Dev\TradBOT\mt5\SMC_Universal.ex5" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📊 Détails:" -ForegroundColor Cyan
    Write-Host "   Taille: $('{0:F2}' -f ($File.Length / 1024)) KB" -ForegroundColor Gray
    Write-Host "   Timestamp: $($File.LastWriteTime)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⚠️  Pour charger dans MT5:" -ForegroundColor Yellow
    Write-Host "   1. Copiez le fichier vers Experts" -ForegroundColor Gray
    Write-Host "   2. Redémarrez MT5" -ForegroundColor Gray
    Write-Host "   3. Attachez le robot" -ForegroundColor Gray
} else {
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║          ❌ COMPILATION ÉCHOUÉE                              ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Vérifiez:" -ForegroundColor Yellow
    Write-Host "  - Que MetaEditor est complètement fermé" -ForegroundColor Gray
    Write-Host "  - Les messages d'erreur ci-dessus" -ForegroundColor Gray
    Write-Host "  - Que le chemin MT5 est correct" -ForegroundColor Gray
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Read-Host "Appuyez sur ENTRÉE pour fermer"
