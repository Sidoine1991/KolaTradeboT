# Crée les tags Ollama optimisés pour agents (OpenCode / Claude Code / Kilo Code).
$ErrorActionPreference = "Stop"

function New-OllamaFastModel {
    param(
        [string]$Modelfile,
        [string]$Tag,
        [int]$NumCtx,
        [int]$NumPredict = 8
    )
    if (-not (Test-Path $Modelfile)) {
        Write-Error "Modelfile introuvable: $Modelfile"
    }
    Write-Host "[Setup-Ollama] Creation $Tag (num_ctx=$NumCtx)..." -ForegroundColor Cyan
    & ollama create $Tag -f $Modelfile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $body = @{
        model      = $Tag
        prompt     = "ok"
        stream     = $false
        keep_alive = "30m"
        options    = @{ num_ctx = $NumCtx; num_predict = $NumPredict }
    } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body $body -ContentType "application/json" | Out-Null
}

New-OllamaFastModel -Modelfile (Join-Path $PSScriptRoot "ollama\Modelfile.qwen-coder-fast") -Tag "qwen2.5-coder-fast:7b" -NumCtx 8192
New-OllamaFastModel -Modelfile (Join-Path $PSScriptRoot "ollama\Modelfile.qwen-coder-fast-1.5b") -Tag "qwen2.5-coder-fast:1.5b" -NumCtx 2048

Write-Host "[Setup-Ollama] OK - utiliser ollama/qwen2.5-coder-fast:7b ou ollama/qwen2.5-coder-fast:1.5b" -ForegroundColor Green
ollama list
