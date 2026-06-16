# Automatic Python 3.11.9 Reinstallation Script
# Run as Administrator

param(
    [switch]$Force
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  PYTHON 3.11.9 AUTOMATIC REINSTALLATION                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if running as Administrator
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544"
if (-not $isAdmin) {
    Write-Host "❌ ERROR: This script must run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell → Run as Administrator, then run this script again"
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Step 2: Stop any running Python processes
Write-Host "Step 1: Stopping Python processes..."
Get-Process python* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Write-Host "✅ Done" -ForegroundColor Green
Write-Host ""

# Step 3: Uninstall Python 3.11.9
Write-Host "Step 2: Uninstalling Python 3.11.9..."
$pythonInstall = "C:\Users\USER\AppData\Local\Programs\Python\Python311_9"

if (Test-Path $pythonInstall) {
    Write-Host "Found: $pythonInstall"

    # Try to find installer first
    $uninstallers = @(
        "C:\Program Files\Python311\Uninstall.exe",
        "C:\Program Files (x86)\Python311\Uninstall.exe",
        "$pythonInstall\Uninstall.exe"
    )

    $found = $false
    foreach ($uninstaller in $uninstallers) {
        if (Test-Path $uninstaller) {
            Write-Host "  Running: $uninstaller"
            & $uninstaller /quiet
            Start-Sleep 3
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Host "  No official uninstaller found, removing directory..."
        Remove-Item $pythonInstall -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $pythonInstall) {
        Write-Host "  ⚠️  Some files remain (may be in use)"
    } else {
        Write-Host "✅ Uninstalled successfully" -ForegroundColor Green
    }
} else {
    Write-Host "✅ Python 3.11.9 not found at $pythonInstall" -ForegroundColor Green
}

Write-Host ""

# Step 4: Download Python 3.11.9 installer
Write-Host "Step 3: Downloading Python 3.11.9 installer..."
$installerUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
$installerPath = "$env:TEMP\python-3.11.9-amd64.exe"

if (Test-Path $installerPath) {
    Write-Host "  Already cached: $installerPath"
} else {
    Write-Host "  Downloading from: $installerUrl"
    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
        Write-Host "✅ Downloaded" -ForegroundColor Green
    } catch {
        Write-Host "❌ Download failed: $_" -ForegroundColor Red
        Write-Host "Manual download: $installerUrl"
        exit 1
    }
}

Write-Host ""

# Step 5: Run installer with proper options
Write-Host "Step 4: Installing Python 3.11.9..."
Write-Host "  Options: Add to PATH, Include pip, tcl/tk, py launcher"
Write-Host ""

$installArgs = @(
    "/quiet",
    "InstallAllUsers=0",
    "DefaultAllUsers=0",
    "Include_doc=0",
    "Include_launcher=1",
    "Include_test=0",
    "Include_tcltk=1",
    "PrependPath=1"
)

try {
    Write-Host "  Running installer (this may take 2-3 minutes)..."
    & $installerPath @installArgs -Wait
    Write-Host "✅ Installation complete" -ForegroundColor Green
} catch {
    Write-Host "❌ Installation failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Verify installation
Write-Host "Step 5: Verifying installation..."
Start-Sleep 2

$pythonExe = "C:\Users\USER\AppData\Local\Programs\Python\Python311_9\python.exe"
if (Test-Path $pythonExe) {
    $version = & $pythonExe --version 2>&1
    Write-Host "  Found: $pythonExe"
    Write-Host "  Version: $version"
    Write-Host "✅ Python 3.11.9 installed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Python executable not found at $pythonExe" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Test environment
Write-Host "Step 6: Testing Python environment..."
$testCode = @"
import sys
print(f'sys.prefix: {sys.prefix}')
print(f'sys.executable: {sys.executable}')
print(f'Version: {sys.version}')
"@

try {
    $output = & $pythonExe -c $testCode 2>&1
    Write-Host $output
    Write-Host "✅ Environment looks good" -ForegroundColor Green
} catch {
    Write-Host "❌ Environment test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Step 8: Install pip packages
Write-Host "Step 7: Upgrading pip and installing requirements..."
try {
    & $pythonExe -m pip install --upgrade pip -q
    Write-Host "  ✅ pip upgraded"

    if (Test-Path "D:\Dev\TradBOT\requirements.txt") {
        & $pythonExe -m pip install -r "D:\Dev\TradBOT\requirements.txt" -q
        Write-Host "  ✅ requirements.txt installed"
    }
} catch {
    Write-Host "  ⚠️  pip installation had issues: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ PYTHON 3.11.9 REINSTALLATION COMPLETE                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Test Python 3.11:"
Write-Host '   python --version'
Write-Host ""
Write-Host "2. Run GOM sync:"
Write-Host '   cd D:\Dev\TradBOT && python Python/gom_sync_with_report.py --report'
Write-Host ""
