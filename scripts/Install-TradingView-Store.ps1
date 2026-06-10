# Installe TradingView version Microsoft Store (MSIX) — compatible CDP.
# winget n'est pas requis.

param(
    [switch]$OpenStoreOnly
)

$StoreUrl = "ms-windows-store://pdp/?ProductId=9ndjwkstbt25"
$MsixUrl  = "https://tvd-packages.tradingview.com/stable/latest/win32/TradingView.msix"

Write-Host "=== TradingView — installation version Store (CDP) ===" -ForegroundColor Cyan
Write-Host ""

if ($OpenStoreOnly) {
    Write-Host "Ouverture du Microsoft Store..."
    Start-Process $StoreUrl
    Write-Host "Dans le Store : cliquez Installer, puis relancez Start-TradingViewCDP.ps1"
    exit 0
}

# Deja installe sous WindowsApps ?
$storeExe = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Filter "TradingView.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($storeExe) {
    Write-Host "Version Store deja presente : $($storeExe.FullName)" -ForegroundColor Green
    Write-Host "Lancez : .\scripts\Start-TradingViewCDP.ps1 -ForceRestart"
    exit 0
}

Write-Host "Option A — Microsoft Store (recommande)" -ForegroundColor Yellow
Write-Host "  1. Ouvrez le Store et installez TradingView"
Write-Host "  2. Ou executez : .\scripts\Install-TradingView-Store.ps1 -OpenStoreOnly"
Write-Host ""

$open = Read-Host "Ouvrir le Microsoft Store maintenant ? (O/n)"
if ($open -ne "n" -and $open -ne "N") {
    Start-Process $StoreUrl
    Write-Host "Apres installation dans le Store, fermez l'ancienne version AppData si besoin,"
    Write-Host "puis : .\scripts\Start-TradingViewCDP.ps1 -ForceRestart"
    exit 0
}

Write-Host ""
Write-Host "Option B — Package MSIX officiel (sans winget)" -ForegroundColor Yellow
Write-Host "  URL : $MsixUrl"
$msix = Read-Host "Telecharger et installer le MSIX maintenant ? (O/n)"
if ($msix -eq "n" -or $msix -eq "N") {
    Write-Host "Annule. Utilisez Option A ou installez App Installer depuis le Store."
    exit 0
}

$dest = Join-Path $env:TEMP "TradingView.msix"
Write-Host "Telechargement..."
try {
    Invoke-WebRequest -Uri $MsixUrl -OutFile $dest -UseBasicParsing
} catch {
    Write-Error "Echec telechargement : $_"
    Write-Host "Essayez Option A (Microsoft Store)."
    exit 1
}

Write-Host "Installation MSIX (peut demander confirmation)..."
try {
    Add-AppxPackage -Path $dest
    Write-Host "OK — Relancez : .\scripts\Start-TradingViewCDP.ps1 -ForceRestart" -ForegroundColor Green
} catch {
    Write-Error "Echec Add-AppxPackage : $_"
    Write-Host "Ouvrez le fichier manuellement : $dest"
    Write-Host "Ou installez 'App Installer' depuis le Microsoft Store puis reessayez."
    exit 1
}
