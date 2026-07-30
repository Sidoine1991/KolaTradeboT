param(
    [switch]$UseClaude,
    [switch]$Native,
    [switch]$LocalQwen
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

& (Join-Path $targetDir "scripts\Warm-Ollama-Qwen.ps1")

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
    if ($LocalQwen) {
        Write-Host "[Start-OpenCode] Claude Code -> Ollama qwen2.5-coder-fast:7b (proxy local)" -ForegroundColor Green
    } else {
        Write-Host "[Start-OpenCode] Claude Code -> proxy 8082 (MODEL dans free-claude-code\.env)" -ForegroundColor Cyan
    }
    & claude
    exit $LASTEXITCODE
}

Set-Location $targetDir
if (-not $LocalQwen) {
    # OpenCode parle directement a Ollama (.opencode/opencode.json) — pas besoin du proxy 8082
    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
}
Write-Host "[Start-OpenCode] OpenCode -> Ollama direct (qwen2.5-coder-fast:7b)" -ForegroundColor Green
Write-Host "  build : ollama/qwen2.5-coder-fast:7b | explore : ollama/qwen2.5-coder:1.5b" -ForegroundColor Cyan
Write-Host "  Claude Code : scripts\Start-OpenCode.ps1 -UseClaude" -ForegroundColor DarkGray
& opencode
