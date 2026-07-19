# Sync repo -> terminal F016 uniquement (fermer MetaEditor avant!)
$terminal = "F016FF5B93786543B564E81A925D7066"
$dst = Join-Path $env:APPDATA "MetaQuotes\Terminal\$terminal\MQL5\Experts"
$src = Join-Path $PSScriptRoot "."

if (-not (Test-Path $dst)) {
    Write-Error "Terminal introuvable: $dst"
    exit 1
}

Copy-Item -Force (Join-Path $src "SMC_Universal.mq5") (Join-Path $dst "SMC_Universal.mq5")
$modDst = Join-Path $dst "modules"
if (-not (Test-Path $modDst)) { New-Item -ItemType Directory -Path $modDst | Out-Null }
Copy-Item -Force -Recurse (Join-Path $src "modules\*") $modDst

$sh = (Get-FileHash (Join-Path $src "SMC_Universal.mq5")).Hash
$dh = (Get-FileHash (Join-Path $dst "SMC_Universal.mq5")).Hash
if ($sh -ne $dh) {
    Write-Error "Hash mismatch — MetaEditor a peut-etre le fichier ouvert. Fermez SMC_Universal.mq5 puis relancez."
    exit 1
}

Write-Host "OK F016 synchronise (hash identique au repo)."
Write-Host "Ouvrez MQL5\Experts\SMC_Universal.mq5 dans MetaEditor puis F7."
