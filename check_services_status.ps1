# TradBOT - Service Status Checker

Write-Host ""
Write-Host "=== TradBOT Service Status ===" -ForegroundColor Cyan
Write-Host ""

# Check AI Server
Write-Host "[1/3] AI Server (port 8000)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
    $health = $response.Content | ConvertFrom-Json
    Write-Host " OK RUNNING" -ForegroundColor Green
    Write-Host "      Status: $($health.status)" -ForegroundColor Gray
    Write-Host "      Version: $($health.version)" -ForegroundColor Gray
}
catch {
    Write-Host " NOT RUNNING" -ForegroundColor Red
}

# Check Master GOM Poller
Write-Host ""
Write-Host "[2/3] Master GOM Poller..." -NoNewline
$pythonProcs = Get-Process -Name "python" -ErrorAction SilentlyContinue
$gomFound = $false
foreach ($proc in $pythonProcs) {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdLine -like "*master_gom_poller*") {
            Write-Host " OK RUNNING" -ForegroundColor Green
            Write-Host "      PID: $($proc.Id)" -ForegroundColor Gray
            $gomFound = $true
            break
        }
    }
    catch {}
}
if (-not $gomFound) {
    Write-Host " NOT RUNNING" -ForegroundColor Red
}

# Check TradingView MCP
Write-Host ""
Write-Host "[3/3] TradingView MCP Server..." -NoNewline
$nodeProcs = Get-Process -Name "node" -ErrorAction SilentlyContinue
$tvFound = $false
foreach ($proc in $nodeProcs) {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdLine -like "*tradingview*") {
            Write-Host " OK RUNNING" -ForegroundColor Green
            Write-Host "      PID: $($proc.Id)" -ForegroundColor Gray
            $tvFound = $true
            break
        }
    }
    catch {}
}
if (-not $tvFound) {
    Write-Host " NOT RUNNING" -ForegroundColor Yellow
    Write-Host "      Note: TradingView MCP is optional" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$aiRunning = $false
try {
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -TimeoutSec 1 -UseBasicParsing -ErrorAction Stop
    $aiRunning = $true
}
catch {}

if ($aiRunning -and $gomFound) {
    Write-Host "Core services: OPERATIONAL" -ForegroundColor Green
}
elseif ($aiRunning) {
    Write-Host "Core services: PARTIAL (AI Server only)" -ForegroundColor Yellow
}
else {
    Write-Host "Core services: DOWN" -ForegroundColor Red
}

Write-Host ""
