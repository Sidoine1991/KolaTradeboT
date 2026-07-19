param(
    [switch]$UseClaude,
    [switch]$Native
)

$ErrorActionPreference = "Stop"
$targetDir = Split-Path -Parent $PSScriptRoot
$fccRoot = "C:\Users\USER\free-claude-code"
$fccEnv = Join-Path $fccRoot ".env"

function Import-DotEnv {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"?([^"#]*)"?\s*(#.*)?$') {
            $name = $Matches[1]
            $value = $Matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

function Ensure-ProxyRunning {
    param([string]$Root)
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8082/health" -TimeoutSec 3
        if ($resp.status -eq "healthy") { return $true }
    } catch {}
    Write-Host "[Start-OpenCode] Proxy 8082 down — demarrage..." -ForegroundColor Yellow
    & (Join-Path $Root "scripts\Restart-Proxy.ps1")
    return $true
}

Import-DotEnv $fccEnv
$tradbotEnv = Join-Path $targetDir ".env"
Import-DotEnv $tradbotEnv

# Alias OpenCode -> cles API
if ($env:NVIDIA_NIM_API_KEY -and -not $env:NVIDIA_API_KEY) {
    $env:NVIDIA_API_KEY = $env:NVIDIA_NIM_API_KEY
}
if ($env:CEREBRAS_API_KEY -and -not $env:OPENAI_API_KEY) {
    $env:OPENAI_API_KEY = $env:CEREBRAS_API_KEY
}

if ($UseClaude) {
    if (-not $Native) {
        Ensure-ProxyRunning $fccRoot | Out-Null
        $env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8082"
        $env:CLAUDE_CODE_USE_VERTEX = "0"
        Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    } else {
        Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    }
    Set-Location $targetDir
    & claude
    exit $LASTEXITCODE
}

# OpenCode — proxy anthropic optionnel pour mode anthropic/kimi-k2.6-nim
Ensure-ProxyRunning $fccRoot | Out-Null
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8082"
$env:CLAUDE_CODE_USE_VERTEX = "0"

Set-Location $targetDir
Write-Host "[Start-OpenCode] TradBOT | /models pour la liste complete" -ForegroundColor Cyan
Write-Host "  Cerebras (defaut) : cerebras/qwen-3-coder-480b  (1M tok/jour)" -ForegroundColor Green
Write-Host "  Cloudflare        : cloudflare-workers-ai/@cf/openai/gpt-oss-120b" -ForegroundColor DarkGray
Write-Host "  GitHub Models     : github-models/meta/llama-3.3-70b-instruct" -ForegroundColor DarkGray
Write-Host "  Ollama local      : ollama/gpt-oss:20b" -ForegroundColor DarkGray
Write-Host "  Groq backup       : groq/llama-3.3-70b-versatile" -ForegroundColor DarkGray
Write-Host "  OR free backup    : openrouter/qwen/qwen3-coder:free" -ForegroundColor DarkGray
& opencode
