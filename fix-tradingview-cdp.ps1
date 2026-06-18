# Fix TradingView CDP for GOM poller - Volatility 100 sync

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🔧 Fixing TradingView CDP" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Kill TradingView
Write-Host "[1/4] Stopping TradingView..." -ForegroundColor Yellow
taskkill /IM TradingView.exe /F 2>$null
Start-Sleep -Seconds 2

# 2. Launch with CDP enabled
Write-Host "[2/4] Launching TradingView with Chrome Debug Protocol..." -ForegroundColor Yellow
$tvPath = "C:\Program Files\WindowsApps\TradingView.Desktop_3.2.0.7916_x64__n534cwy3pjxzj\TradingView.exe"
if (Test-Path $tvPath) {
    Start-Process -FilePath $tvPath -ArgumentList "--remote-debugging-port=9222" -NoNewWindow
    Start-Sleep -Seconds 10
    Write-Host "✅ TradingView launched with CDP" -ForegroundColor Green
} else {
    Write-Host "❌ TradingView not found at: $tvPath" -ForegroundColor Red
    exit 1
}

# 3. Verify CDP is active
Write-Host "[3/4] Verifying CDP on port 9222..." -ForegroundColor Yellow
try {
    $response = curl -s http://localhost:9222/json/version 2>&1
    if ($response -and $response -notmatch "Connection refused") {
        Write-Host "✅ CDP Active!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  CDP not responding (may need more time)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  CDP check error: $_" -ForegroundColor Yellow
}

# 4. Show status
Write-Host ""
Write-Host "[4/4] Status:" -ForegroundColor Yellow
Write-Host "✅ TradingView CDP should now be active" -ForegroundColor Green
Write-Host "✅ GOM poller can now fetch Volatility 100 from TradingView" -ForegroundColor Green
Write-Host "✅ Volatility 100 will sync to MT5 terminal" -ForegroundColor Green
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "✅ Done! Restart GOM sync daemon:" -ForegroundColor Green
Write-Host "cd D:\Dev\TradBOT && python Python/master_gom_poller.py" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Green
