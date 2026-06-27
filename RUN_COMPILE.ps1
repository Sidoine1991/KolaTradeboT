#!/usr/bin/env powershell
# Compilation et deploiement vers les 2 terminaux MT5 (Weltrade + Deriv)

$SOURCE_DIR   = "D:\Dev\TradBOT\mt5"
$SOURCE       = "$SOURCE_DIR\SMC_Universal.mq5"
$METAEDITOR   = "D:\Program Files\MetaTrader 5\MetaEditor64.exe"

$EXPERTS_WELTRADE = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts"
$EXPERTS_DERIV    = "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts"

Write-Host ""
Write-Host "=== COMPILATION SMC_Universal.mq5  ->  Weltrade + Deriv ===" -ForegroundColor Cyan
Write-Host ""

# Verifications
Write-Host "[1/5] Verification des chemins..." -ForegroundColor Yellow
if (-not (Test-Path $SOURCE)) {
    Write-Host "ERREUR: Source introuvable: $SOURCE" -ForegroundColor Red; exit 1
}
Write-Host "OK Source trouvee" -ForegroundColor Green

if (-not (Test-Path $METAEDITOR)) {
    Write-Host "ERREUR: MetaEditor introuvable: $METAEDITOR" -ForegroundColor Red; exit 1
}
Write-Host "OK MetaEditor trouve" -ForegroundColor Green

foreach ($dir in @($EXPERTS_WELTRADE, $EXPERTS_DERIV)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "  Dossier cree: $dir" -ForegroundColor Yellow
    }
}
Write-Host "OK Dossiers Experts accessibles (Weltrade + Deriv)" -ForegroundColor Green

# Suppression anciens binaires
Write-Host ""
Write-Host "[2/5] Suppression des anciens binaires + copie sources fraiches..." -ForegroundColor Yellow
Remove-Item -Path "$EXPERTS_WELTRADE\SMC_Universal.ex5" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$EXPERTS_DERIV\SMC_Universal.ex5"    -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$SOURCE_DIR\SMC_Universal.ex5"       -Force -ErrorAction SilentlyContinue

# Copier le .mq5 ET les modules vers les deux Experts (MetaEditor compile depuis le terminal)
foreach ($target in @($EXPERTS_WELTRADE, $EXPERTS_DERIV)) {
    Copy-Item -Path $SOURCE -Destination "$target\SMC_Universal.mq5" -Force
    $modSrc = "$SOURCE_DIR\modules"
    $modDst = "$target\modules"
    if (Test-Path $modSrc) {
        if (-not (Test-Path $modDst)) { New-Item -Path $modDst -ItemType Directory -Force | Out-Null }
        Copy-Item -Path "$modSrc\*" -Destination $modDst -Force -Recurse
        Write-Host "  Modules copies vers $modDst" -ForegroundColor Gray
    }
}
Write-Host "OK Sources et modules copies dans les deux terminaux" -ForegroundColor Green

# Compilation depuis le terminal Weltrade (source = $EXPERTS_WELTRADE\SMC_Universal.mq5)
$compileSource = "$EXPERTS_WELTRADE\SMC_Universal.mq5"
Write-Host ""
Write-Host "[3/5] Compilation en cours (30-60s)..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $METAEDITOR -ArgumentList "/compile:`"$compileSource`"", "/log:`"$SOURCE_DIR\compile.log`"" -Wait -PassThru
Write-Host "  MetaEditor exit code: $($proc.ExitCode)"
Start-Sleep -Seconds 5

# Localiser le .ex5 compile
Write-Host ""
Write-Host "[4/5] Recherche du binaire compile..." -ForegroundColor Yellow
$compiled = $null
# Attendre jusqu'à 70s — compilation prend ~23s + délai écriture disque
$maxWait = 70
$waited  = 0
while ($waited -lt $maxWait -and -not $compiled) {
    Start-Sleep -Seconds 3; $waited += 3
    foreach ($candidate in @("$EXPERTS_WELTRADE\SMC_Universal.ex5",
                              "$EXPERTS_DERIV\SMC_Universal.ex5",
                              "$SOURCE_DIR\SMC_Universal.ex5")) {
        if (Test-Path $candidate) { $compiled = $candidate; break }
    }
}

if (-not $compiled) {
    Write-Host "ECHEC: aucun .ex5 trouve apres compilation" -ForegroundColor Red
    $logFile = "$SOURCE_DIR\compile.log"
    if (Test-Path $logFile) {
        Write-Host "--- Log compilation ---" -ForegroundColor Yellow
        Get-Content $logFile | Select-Object -Last 30 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    Write-Host "Verifiez les erreurs dans MetaEditor (F7)" -ForegroundColor Yellow
    Read-Host "Appuyez sur ENTREE pour fermer"
    exit 1
}
$sz = [math]::Round((Get-Item $compiled).Length / 1024)
Write-Host "OK Binaire trouve: $compiled ($sz KB)" -ForegroundColor Green

# Deploiement vers les deux terminaux
Write-Host ""
Write-Host "[5/5] Deploiement vers les 2 terminaux..." -ForegroundColor Yellow

foreach ($target in @($EXPERTS_WELTRADE, $EXPERTS_DERIV)) {
    $dest = "$target\SMC_Universal.ex5"
    if ($compiled -ne $dest) {
        Copy-Item -Path $compiled -Destination $dest -Force
    }
    $f = Get-Item $dest
    $fsz = [math]::Round($f.Length / 1024)
    Write-Host "  OK $target" -ForegroundColor Green
    Write-Host "     Taille: $fsz KB  |  $($f.LastWriteTime)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== DEPLOYE SUR WELTRADE + DERIV ===" -ForegroundColor Green
Write-Host ""
Write-Host "Dans chaque terminal MT5:" -ForegroundColor Cyan
Write-Host "  Clic droit graphique -> Experts -> SMC_Universal -> OK" -ForegroundColor Gray
Write-Host ""
Read-Host "Appuyez sur ENTREE pour fermer"
