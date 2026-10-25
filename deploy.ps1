# deploy.ps1 - Deploiement + compilation SMC_Universal vers les terminaux MT5
# Usage:
#   .\deploy.ps1                          -> tous les terminaux connus
#   .\deploy.ps1 -Targets F016,E6E3       -> terminaux specifies (prefixe d'ID)
#   .\deploy.ps1 -NoCompile               -> copie sans compiler

param(
    [string[]]$Targets = @(),
    [switch]$NoCompile
)

# Support "F016,E6E3" passe depuis la ligne de commande (powershell -File ne split pas)
if ($Targets.Count -eq 1 -and $Targets[0] -match '[,\s]') {
    $Targets = $Targets[0] -split '[,\s]+' | Where-Object { $_ }
}

$ErrorActionPreference = 'Stop'

# ---- Configuration ----
$SourceDir  = "D:\Dev\TradBOT\mt5"
$SourceMq5  = Join-Path $SourceDir "SMC_Universal.mq5"
$SourceMods = Join-Path $SourceDir "modules"
$MetaEditor = "D:\Program Files\MetaTrader 5\metaeditor64.exe"

# Prefixes d'ID des terminaux (dossier %APPDATA%\MetaQuotes\Terminal\<ID>)
$KnownTerminals = @{
    "F016"  = "F016FF5B93786543B564E81A925D7066"
    "E6E3"  = "E6E3D0917DD641581E4779524EB3B1AA"
    "62DE"  = "62DE0881527B5F589A310F71C9C0578C"
    "8ABF"  = "8ABF1BCD076EFAE2676A22BD36186723"
    "415DD" = "415DD75DEF29D458F52EB44204841A9C"
}

# ---- Resolution des cibles ----
if ($Targets.Count -eq 0) {
    $ResolvedIds = $KnownTerminals.Values
} else {
    $ResolvedIds = foreach ($t in $Targets) {
        $key = ($KnownTerminals.Keys | Where-Object { $_ -like "$t*" } | Select-Object -First 1)
        if (-not $key) { Write-Warning "Terminal inconnu: $t (connus: $($KnownTerminals.Keys -join ', '))" }
        else { $KnownTerminals[$key] }
    }
}
if (-not $ResolvedIds) { Write-Error "Aucune cible valide."; exit 1 }

# ---- Garde-fous source ----
if (-not (Test-Path $SourceMq5)) { Write-Error "Source introuvable: $SourceMq5"; exit 1 }
if (-not (Test-Path $MetaEditor)) { Write-Error "MetaEditor introuvable: $MetaEditor"; exit 1 }

# Detection de strays connus dans la source (appels colles dans le bloc prototypes)
$stray = Select-String -Path $SourceMq5 -Pattern '^\s{3,}[A-Za-z_]\w*\(\);\s*$' -ErrorAction SilentlyContinue |
         Where-Object { $_.LineNumber -lt 700 }
# Appels legitimes dans des corps de fonction avant L700 (pas des prototypes orphelins).
# On ignore ResetWhipsawTracker() quel que soit le numéro de ligne (légitime dans ClosePosition*).
$strayBad = $stray | Where-Object {
    $_.LineNumber -ne 625 -and
    $_.Line.Trim() -ne 'ResetWhipsawTracker();'
}
if ($strayBad) {
    Write-Warning "SOURCE SUSPECTE - appels isoles avant L700:"
    $strayBad | ForEach-Object { Write-Warning ("  L{0}: {1}" -f $_.LineNumber, $_.Line.Trim()) }
    Write-Warning "Deploiement annule. Corrige d'abord D:\Dev\TradBOT\mt5."
    exit 1
}

# Avertissement MetaEditor ouvert (risque de buffer obsolete)
$meProcs = @(Get-Process -Name "metaeditor64" -ErrorAction SilentlyContinue)
if ($meProcs.Count -gt 0) {
    Write-Warning "$($meProcs.Count) MetaEditor ouvert(s). Si SMC_Universal.mq5 est affiche dans un onglet, ferme l'onglet SANS sauver avant de continuer (sinon l'ancien contenu sera re-sauvegarde par-dessus)."
}

Write-Output "=== Source: $SourceMq5 (mod $((Get-Item $SourceMq5).LastWriteTime.ToString('HH:mm:ss'))) ==="

$results = @()
foreach ($id in $ResolvedIds) {
    $experts = Join-Path $env:APPDATA "MetaQuotes\Terminal\$id\MQL5\Experts"
    if (-not (Test-Path $experts)) { Write-Warning "Experts introuvable pour ${id}: skip"; continue }

    # 1. Copie du fichier principal (on retire la lecture seule posee en protection)
    $dstMq5 = Join-Path $experts "SMC_Universal.mq5"
    if (Test-Path $dstMq5) { Set-ItemProperty -LiteralPath $dstMq5 -Name IsReadOnly -Value $false }
    Copy-Item -LiteralPath $SourceMq5 -Destination $dstMq5 -Force

    # 2. Copie des modules
    if (Test-Path $SourceMods) {
        $dstMods = Join-Path $experts "modules"
        if (-not (Test-Path $dstMods)) { New-Item -ItemType Directory -Path $dstMods | Out-Null }
        Get-ChildItem $SourceMods -Filter "*.mqh" | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstMods $_.Name) -Force
        }
    }

    if ($NoCompile) {
        Set-ItemProperty -LiteralPath $dstMq5 -Name IsReadOnly -Value $true
        Write-Output "[${id}] copie OK (sans compilation)"
        continue
    }

    # 3. Compilation headless
    $targetFile = Join-Path $experts "SMC_Universal.mq5"
    $log = Join-Path $env:TEMP "smc_deploy_$($id.Substring(0,4)).log"
    if (Test-Path $log) { Remove-Item $log -Force }
    Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$targetFile`"","/log:`"$log`"" -Wait | Out-Null

    $resultLine = "?"
    if (Test-Path $log) {
        $resultLine = (Get-Content $log -Encoding Unicode | Where-Object { $_ -match 'Result:' } |
                       Select-Object -First 1) -replace '^.*Result:\s*',''
    }
    $ex5 = [IO.Path]::ChangeExtension($targetFile, ".ex5")
    $ex5Info = if (Test-Path $ex5) { "EX5 $((Get-Item $ex5).LastWriteTime.ToString('HH:mm:ss'))" } else { "PAS DE EX5" }
    $ok = $resultLine -match '^0 errors'
    # Reprotection : la copie ne doit pas etre modifiable par les editeurs
    Set-ItemProperty -LiteralPath $targetFile -Name IsReadOnly -Value $true
    Write-Output ("[{0}] {1} | {2}" -f $id.Substring(0,4), $(if ($ok) {'OK '} else {'FAIL'}), $resultLine)
    Write-Output ("       {0}" -f $ex5Info)
    $results += [pscustomobject]@{ Terminal = $id.Substring(0,4); Ok = $ok; Result = $resultLine }
}

# ---- Resume ----
$fails = @($results | Where-Object { -not $_.Ok })
Write-Output "=== Resume: $($results.Count - $fails.Count)/$($results.Count) compilent ==="
if ($fails.Count -gt 0) { exit 1 }
