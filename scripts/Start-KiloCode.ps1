$ErrorActionPreference = "Stop"
$targetDir = Split-Path -Parent $PSScriptRoot

& (Join-Path $targetDir "scripts\Warm-Ollama-Qwen.ps1") -Model "qwen2.5-coder-fast:7b" -FallbackModel "qwen2.5-coder:7b"

Set-Location $targetDir
Write-Host "[Start-KiloCode] Kilo -> Ollama qwen2.5-coder-fast:7b (agent)" -ForegroundColor Green
Write-Host "  chat rapide : ollama/qwen2.5-coder-fast:1.5b (sans tools)" -ForegroundColor Cyan
& kilocode @args
