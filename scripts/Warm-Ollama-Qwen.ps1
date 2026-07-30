param(
    [string]$Model = "qwen2.5-coder-fast:7b",
    [string]$FallbackModel = "qwen2.5-coder:7b"
)

$ErrorActionPreference = "SilentlyContinue"
$tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5
$names = @($tags.models.name)
$pick = if ($names -contains $Model) { $Model } else { $FallbackModel }

$body = @{
    model      = $pick
    prompt     = "ping"
    stream     = $false
    keep_alive = "30m"
    options    = @{ num_predict = 4 }
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120 | Out-Null
    Write-Host "[Warm-Ollama] $pick charge (keep_alive=30m)" -ForegroundColor Green
} catch {
    Write-Host "[Warm-Ollama] Echec prechauffage ($pick): $_" -ForegroundColor Yellow
}
