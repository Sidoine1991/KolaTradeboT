param(
    [switch]$UseClaude,
    [switch]$Native
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptDir "Start-OpenCode.ps1") @PSBoundParameters
