# PowerShell script to test the new endpoint
Write-Host "🔧 Testing Dynamic Symbol Discovery Endpoint" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

# Check if ai_server.py is running
$port = 8000
$processName = "python"

Write-Host "Step 1: Checking if ai_server is running on port $port..." -ForegroundColor Yellow

# Try to connect
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "✅ Server is running" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Server not responding. Instructions:" -ForegroundColor Yellow
    Write-Host "  1. Open terminal in D:\Dev\TradBOT"
    Write-Host "  2. Run: python ai_server.py"
    Write-Host "  3. Wait for 'Application startup complete'"
    Write-Host "  4. Then run this test script again"
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "Step 2: Testing /symbols/daily-candidates endpoint..." -ForegroundColor Yellow
Write-Host ""

# Run the test
python test_daily_candidates.py
$testResult = $LASTEXITCODE

Write-Host ""
if ($testResult -eq 0) {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: Test morning_scan.py" -ForegroundColor Cyan
    Write-Host "  Run: python Python/morning_scan.py"
} else {
    Write-Host "❌ Test failed" -ForegroundColor Red
}

exit $testResult
