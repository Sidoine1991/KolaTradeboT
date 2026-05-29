# ════════════════════════════════════════════════════════════════
# 🔨 AUTO-COMPILE EAs via MetaEditor CMD
# ════════════════════════════════════════════════════════════════

$MetaEditorPath = "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
$TradeManagerPath = "D:\Dev\TradBOT\TradeManager.mq5"
$SpikeRiderPath = "D:\Dev\TradBOT\SpikeRiderEA.mq5"

if (-not (Test-Path $MetaEditorPath)) {
    Write-Host "❌ MetaEditor non trouvé à: $MetaEditorPath" -ForegroundColor Red
    exit 1
}

Write-Host "🔨 Compilation TradeManager.mq5..." -ForegroundColor Cyan
& $MetaEditorPath /compile:"$TradeManagerPath" /log:"D:\Dev\TradBOT\compile_trademanager.log"
Start-Sleep -Seconds 5

Write-Host "🔨 Compilation SpikeRiderEA.mq5..." -ForegroundColor Cyan
& $MetaEditorPath /compile:"$SpikeRiderPath" /log:"D:\Dev\TradBOT\compile_spiderider.log"
Start-Sleep -Seconds 5

# Vérifier les résultats
Write-Host "`n📋 Résultats de compilation:" -ForegroundColor Green

if (Test-Path "D:\Dev\TradBOT\compile_trademanager.log") {
    Write-Host "`n--- TradeManager ---"
    Get-Content "D:\Dev\TradBOT\compile_trademanager.log" | Select-String -Pattern "error|Error|ERROR|warning|done" | Select-Object -First 20
}

if (Test-Path "D:\Dev\TradBOT\compile_spderider.log") {
    Write-Host "`n--- SpikeRiderEA ---"
    Get-Content "D:\Dev\TradBOT\compile_spderider.log" | Select-String -Pattern "error|Error|ERROR|warning|done" | Select-Object -First 20
}

Write-Host "`n✅ Compilation terminée!" -ForegroundColor Green
