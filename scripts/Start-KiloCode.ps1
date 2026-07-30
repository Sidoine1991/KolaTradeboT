$ErrorActionPreference = "Stop"
$targetDir = Split-Path -Parent $PSScriptRoot

& (Join-Path $targetDir "scripts\Warm-Ollama-Qwen.ps1")

Set-Location $targetDir
Write-Host "[Start-KiloCode] Kilo -> Ollama qwen2.5-coder-fast:7b" -ForegroundColor Green
Write-Host "  explore/light : ollama/qwen2.5-coder:1.5b" -ForegroundColor Cyan
& kilocode @args
