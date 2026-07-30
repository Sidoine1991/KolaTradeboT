# Crée le tag Ollama optimisé pour agents (OpenCode / Claude Code / Kilo Code).
$ErrorActionPreference = "Stop"
$modelfile = Join-Path $PSScriptRoot "ollama\Modelfile.qwen-coder-fast"
$tag = "qwen2.5-coder-fast:7b"

if (-not (Test-Path $modelfile)) {
    Write-Error "Modelfile introuvable: $modelfile"
}

Write-Host "[Setup-Ollama] Creation $tag (num_ctx=8192)..." -ForegroundColor Cyan
& ollama create $tag -f $modelfile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[Setup-Ollama] Prechauffage..." -ForegroundColor Cyan
$body = @{
    model  = $tag
    prompt = "ok"
    stream = $false
    keep_alive = "30m"
    options = @{ num_ctx = 8192; num_predict = 8 }
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body $body -ContentType "application/json" | Out-Null

Write-Host "[Setup-Ollama] OK - utiliser ollama/$tag" -ForegroundColor Green
ollama list
