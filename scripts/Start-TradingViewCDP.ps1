# Lance TradingView Desktop avec Chrome DevTools (port 9222).
# UseShellExecute evite l erreur ICU (Invalid file descriptor to ICU data).

param(
    [int]$Port = 9222,
    [switch]$ForceRestart
)

function Test-CdpPort([int]$p) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$p/json/version" -UseBasicParsing -TimeoutSec 2
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Start-TradingViewDetached([string]$ExePath, [int]$p) {
    $wd = Split-Path -Parent $ExePath
    # Start-Process (comme launch_tv_debug.bat) — plus fiable que ProcessStartInfo sur WindowsApps
    return Start-Process -FilePath $ExePath -ArgumentList "--remote-debugging-port=$p" -WorkingDirectory $wd -PassThru
}

function Find-TradingViewExe {
    foreach ($key in @("GOM_TRADINGVIEW_EXE", "TRADINGVIEW_EXE")) {
        $raw = [Environment]::GetEnvironmentVariable($key)
        if ($raw -and (Test-Path -LiteralPath $raw)) {
            return (Resolve-Path -LiteralPath $raw).Path
        }
    }

    # Préférer 31178TradingViewInc (Store winget) avant TradingView.Desktop (doublon MSIX)
    $preferOrder = @(
        "31178TradingViewInc.TradingView",
        "TradingView.Desktop"
    )
    foreach ($pkgName in $preferOrder) {
        $pkg = Get-AppxPackage -Name $pkgName -ErrorAction SilentlyContinue
        if ($pkg -and $pkg.InstallLocation) {
            $exe = Join-Path $pkg.InstallLocation "TradingView.exe"
            if (Test-Path -LiteralPath $exe) { return $exe }
        }
    }

    $appxPkgs = Get-AppxPackage *TradingView* -ErrorAction SilentlyContinue |
        Where-Object { $_.InstallLocation } |
        Sort-Object -Property Version -Descending
    foreach ($pkg in $appxPkgs) {
        $exe = Join-Path $pkg.InstallLocation "TradingView.exe"
        if (Test-Path -LiteralPath $exe) { return $exe }
    }

    $storeRoot = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $storeRoot) {
        $found = Get-ChildItem -Path $storeRoot -Filter "TradingView.exe" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "31178TradingViewInc" } |
            Select-Object -First 1
        if (-not $found) {
            $found = Get-ChildItem -Path $storeRoot -Filter "TradingView.exe" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
        }
        if ($found) { return $found.FullName }
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "TradingView\TradingView.exe"),
        "C:\Program Files\TradingView\TradingView.exe",
        "C:\Program Files (x86)\TradingView\TradingView.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

if (Test-CdpPort $Port) {
    Write-Host "CDP deja actif sur http://localhost:$Port"
    (Invoke-WebRequest -Uri "http://localhost:$Port/json/version" -UseBasicParsing).Content
    exit 0
}

$tvPath = Find-TradingViewExe
if (-not $tvPath) {
    Write-Error "TradingView.exe introuvable. Lancez Install-TradingView-Store.ps1"
    exit 1
}

Write-Host "TradingView : $tvPath"
if ($tvPath -like "*\WindowsApps\*") {
    Write-Host "Version Microsoft Store detectee."
}

if ($ForceRestart) {
    Write-Host "Fermeture des instances TradingView..."
    taskkill /F /IM TradingView.exe 2>$null | Out-Null
    Start-Sleep -Seconds 2
} elseif (Get-Process -Name TradingView -ErrorAction SilentlyContinue) {
    Write-Warning "TradingView tourne deja sans CDP. Relancez avec -ForceRestart."
}

Write-Host "Demarrage avec --remote-debugging-port=$Port ..."
try {
    $proc = Start-TradingViewDetached -ExePath $tvPath -p $Port
    if ($proc) { Write-Host "PID : $($proc.Id)" }
} catch {
    Write-Error "Echec demarrage : $_"
    exit 1
}

Write-Host "Attente CDP (max 90s)..."
for ($i = 0; $i -lt 45; $i++) {
    Start-Sleep -Seconds 2
    if (Test-CdpPort $Port) {
        Write-Host ""
        Write-Host "OK - CDP pret : http://localhost:$Port"
        (Invoke-WebRequest -Uri "http://localhost:$Port/json/version" -UseBasicParsing).Content
        Write-Host ""
        Write-Host "Sur TV : OANDA:XAUUSD, M1, indicateur GOM KOLA SIDO."
        exit 0
    }
    if (-not (Get-Process -Name TradingView -ErrorAction SilentlyContinue)) {
        Write-Warning "TradingView s est arrete. Verifiez debug.log ou reinstallez depuis le Store."
    }
}

Write-Error "CDP non disponible sur le port $Port. Relancez avec -ForceRestart ou node src/cli/index.js launch"
exit 1
