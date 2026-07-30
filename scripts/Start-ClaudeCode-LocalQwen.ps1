$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptDir "Start-OpenCode.ps1") -UseClaude -LocalQwen @args
