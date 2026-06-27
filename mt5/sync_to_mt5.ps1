# Sync SMC_Universal.mq5 + modules from repo to all MT5 terminal Experts folders.
$src = Join-Path $PSScriptRoot "."
$mqBase = Join-Path $env:APPDATA "MetaQuotes\Terminal"
$targets = @(
    (Join-Path $mqBase "F016FF5B93786543B564E81A925D7066\MQL5\Experts"),
    (Join-Path $mqBase "E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts"),
    (Join-Path $mqBase "MQL5\Experts")
)

foreach ($t in $targets) {
    if (-not (Test-Path $t)) { Write-Warning "Skip missing: $t"; continue }
    $mod = Join-Path $t "modules"
    if (-not (Test-Path $mod)) { New-Item -ItemType Directory -Path $mod | Out-Null }
    Copy-Item -Force (Join-Path $src "SMC_Universal.mq5") (Join-Path $t "SMC_Universal.mq5")
    Copy-Item -Force -Recurse (Join-Path $src "modules\*") $mod
    Write-Host "OK -> $t"
}

# Remove stale Include copies (wrong location — causes compile from old file)
$includeCopies = Get-ChildItem -Path $mqBase -Recurse -Filter "SMC_Universal.mq5" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\Include\\" }
foreach ($f in $includeCopies) {
    Remove-Item -Force $f.FullName
    Write-Host "Removed stale Include copy: $($f.FullName)"
}

Write-Host "Done. Compile from MQL5\Experts\SMC_Universal.mq5 in MetaEditor (F7)."
