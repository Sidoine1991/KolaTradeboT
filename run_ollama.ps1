Param(
    [string]$Model = "",
    [switch]$ListModels,
    [string]$Prompt = "",
    [string]$OutFile = "",
    [int]$KeepAliveMinutes = 5,
    [switch]$Verbose,
    [switch]$ApplyGit,
    [string]$CommitMessage = "Model-generated update"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition$modelsPath = Join-Path $scriptDir 'models.json'

if ($ListModels) {    if (Test-Path $modelsPath) {        $ms = Get-Content $modelsPath | ConvertFrom-Json        foreach ($m in $ms) { Write-Host "$($m.id) - $($m.display_name) [$($m.source)]" }    } else {        Write-Host "models.json not found at $modelsPath" -ForegroundColor Yellow    }    exit 0}

if ([string]::IsNullOrWhiteSpace($Prompt)) {    Write-Host "Usage: .\run_ollama.ps1 [-Model <model>] -Prompt <text> [-OutFile <path>] [-KeepAliveMinutes <n>] [-Verbose] [-ApplyGit] [-CommitMessage <msg>] [-ListModels]" -ForegroundColor Yellow    exit 1}

# If no model provided, try to load first model from models.jsonif ([string]::IsNullOrWhiteSpace($Model)) {    if (Test-Path $modelsPath) {        try { $first = Get-Content $modelsPath | ConvertFrom-Json | Select-Object -First 1 } catch { $first = $null }        if ($first -and $first.id) { $Model = $first.id }    }    if ([string]::IsNullOrWhiteSpace($Model)) { $Model = 'qwen2.5-coder-fast:7b' }}

$keep = "${KeepAliveMinutes}m"$args = @('run', $Model, '--format', 'json', '--keepalive', $keep)if ($Verbose) { $args += '--verbose' }
$args += '--'
$args += $Prompt

$rawLines = & ollama @args
$rawText = $rawLines -join "`n"

try {    $json = $rawText | ConvertFrom-Json    $msg = $json.message} catch {    Write-Error "Failed to parse JSON from ollama output: $_"    Write-Output $rawText    exit 1}

if (-not [string]::IsNullOrWhiteSpace($OutFile)) {    try {        $dir = [System.IO.Path]::GetDirectoryName((Resolve-Path $OutFile -ErrorAction SilentlyContinue) -or $OutFile)        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }        Set-Content -Path $OutFile -Value $msg -Encoding UTF8        Write-Host "Wrote response to $OutFile"    } catch {        Write-Error "Failed to write file: $_"        exit 1    }    if ($ApplyGit) {        try {            & git add -- "$OutFile"            $fullMessage = "$CommitMessage`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"            & git commit -m $fullMessage || Write-Host "No changes to commit or commit failed." -ForegroundColor Yellow            Write-Host "Committed $OutFile"        } catch {            Write-Error "Git add/commit failed: $_"            exit 1        }    }} else {    Write-Output $msg}
