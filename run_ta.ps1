$ta = Join-Path $env:USERPROFILE "..\..\..\D:\Dev\Depot Github\TradingAgents-main"
$ta = "D:\Dev\Depot Github\TradingAgents-main"
$py = Join-Path $ta ".venv\Scripts\python.exe"
$main = Join-Path $ta "main.py"
& $py $main
