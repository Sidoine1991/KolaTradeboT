# Compilation script for IA HOLD Hierarchy Fix
# This script launches MetaEditor and compiles SMC_Universal.mq5

Write-Host "════════════════════════════════════════════════════════════════"
Write-Host "🔧 COMPILATION - IA HOLD Hierarchy Fix"
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host ""

$metaeditorPath = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$eaFilePath = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
$mt5DataPath = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA"

Write-Host "✅ Checking files..."
if (Test-Path $metaeditorPath) {
    Write-Host "   ✅ MetaEditor found at: $metaeditorPath"
} else {
    Write-Host "   ❌ MetaEditor NOT found"
    exit 1
}

if (Test-Path $eaFilePath) {
    Write-Host "   ✅ EA file found at: $eaFilePath"
} else {
    Write-Host "   ❌ EA file NOT found"
    exit 1
}

Write-Host ""
Write-Host "📋 CHANGES TO BE COMPILED:"
Write-Host "   • Line 11026: HIÉRARCHIE: GOM > IA HOLD"
Write-Host "   • Line 11030: if(IA=HOLD AND GOM=WAIT) → BLOCK"
Write-Host "   • Line 11037: if(IA=HOLD AND GOM≠WAIT) → ALLOW"
Write-Host ""

Write-Host "🚀 Launching MetaEditor..."
Start-Process -FilePath $metaeditorPath -ArgumentList $eaFilePath -WindowStyle Normal

Write-Host ""
Write-Host "⏳ MetaEditor launching..."
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host "📌 NEXT STEPS (in MetaEditor):"
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "1. Wait for file to load (may take 5-10 seconds)"
Write-Host "2. Press: F5"
Write-Host "3. Wait for: 'Compilation successful'"
Write-Host "4. Expected: 0 errors, 0 warnings"
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host "✅ AFTER COMPILATION:"
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "1. Close MetaEditor"
Write-Host "2. Reload MT5 Terminal (or EA will reload automatically)"
Write-Host "3. Monitor logs for: '✅ IA HOLD mais GOM prime'"
Write-Host "4. Next XAUUSD/Forex signal should ENTER (if GOM strong)"
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════"
