# TradBOT - Launch All Services
# Starts: AI Server, Master GOM Poller, CDP TradingView

Write-Host "`n=== TradBOT Service Launcher ===" -ForegroundColor Cyan
Write-Host "Starting all required services...`n" -ForegroundColor Green

# Change to project directory
Set-Location "D:\Dev\TradBOT"

# 1. Start AI Server
Write-Host "[1/3] Starting AI Server on port 8000..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "python ai_server.py" -WindowStyle Normal

Start-Sleep -Seconds 3

# 2. Start Master GOM Poller
Write-Host "[2/3] Starting Master GOM Poller..." -ForegroundColor Yellow
if (Test-Path "master_gom_poller_runner.ps1") {
    Start-Process powershell -ArgumentList "-NoExit", "-File", "master_gom_poller_runner.ps1" -WindowStyle Normal
} else {
    Write-Host "  Warning: master_gom_poller_runner.ps1 not found" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# 3. Start CDP TradingView (Node.js MCP server)
Write-Host "[3/3] Starting TradingView MCP Server..." -ForegroundColor Yellow
$tvMcpPath = "D:\Dev\Depot Github\tradingview-mcp_kola"
if (Test-Path $tvMcpPath) {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$tvMcpPath'; npm start" -WindowStyle Normal
} else {
    Write-Host "  Warning: TradingView MCP server not found at $tvMcpPath" -ForegroundColor Red
    Write-Host "  Clone it from: https://github.com/your-repo/tradingview-mcp_kola" -ForegroundColor Yellow
}

Write-Host "`n=== All services launched ===" -ForegroundColor Green
Write-Host "Check individual windows for status" -ForegroundColor Cyan
Write-Host "`nPress any key to exit launcher..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
