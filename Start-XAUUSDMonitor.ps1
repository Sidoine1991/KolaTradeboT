# Start XAUUSD 20-min WhatsApp surveillance system
# Run with: powershell -ExecutionPolicy Bypass -File Start-XAUUSDMonitor.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "xauusd_monitor.py"
$LogFile = Join-Path $ScriptDir "xauusd_monitor.log"
$PidFile = Join-Path $ScriptDir ".xauusd_monitor.pid"

Write-Host "🚀 Starting XAUUSD 20-min WhatsApp Monitor..." -ForegroundColor Green
Write-Host "📝 Logs: $LogFile"
Write-Host "📋 Config: $(Join-Path $ScriptDir 'xauusd_monitor_config.json')"

# Check Python
try {
    $version = python3 --version 2>&1
    Write-Host "✅ Found Python: $version"
} catch {
    Write-Host "❌ Python 3 not found" -ForegroundColor Red
    exit 1
}

# Check httpx
python3 -c "import httpx" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Installing httpx..."
    pip install httpx -q
}

# Start monitor in background
Write-Host "Starting monitor process..."
$process = Start-Process python3 -ArgumentList $PythonScript `
    -WorkingDirectory $ScriptDir `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError ($LogFile + ".err") `
    -PassThru `
    -NoNewWindow

$process.Id | Out-File $PidFile

Write-Host "✅ Monitor started with PID $($process.Id)" -ForegroundColor Green
Write-Host "🛑 To stop: Stop-Process -Id $($process.Id)"
Write-Host ""

# Show first few lines of logs
Start-Sleep -Seconds 2
Write-Host "📊 Recent logs:" -ForegroundColor Cyan
Get-Content $LogFile -Tail 5

Write-Host ""
Write-Host "Monitor running. Press Ctrl+C to exit (monitor will continue in background)."
Read-Host "Press Enter to close this window"
