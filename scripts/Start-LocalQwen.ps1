param(
    [ValidateSet("opencode", "claude", "kilo")]
    [string]$Tool = "opencode"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
switch ($Tool) {
    "opencode" { & (Join-Path $scriptDir "Start-OpenCode.ps1") }
    "claude"   { & (Join-Path $scriptDir "Start-ClaudeCode-LocalQwen.ps1") }
    "kilo"     { & (Join-Path $scriptDir "Start-KiloCode.ps1") }
}
