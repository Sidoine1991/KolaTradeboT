# Fix Python 3.11.9 Registry Corruption
# Run as Administrator

Write-Host "🔧 Fixing Python 3.11.9 Registry Corruption..."
Write-Host ""

# Find and remove incorrect registry entries
$regPath = "HKLM:\Software\Python\PythonCore\3.11"
$regPath64 = "HKLM:\Software\WOW6432Node\Python\PythonCore\3.11"

Write-Host "Checking registry paths..."

# Check 64-bit registry
if (Test-Path $regPath) {
    Write-Host "Found: $regPath"
    $installPath = (Get-ItemProperty $regPath\InstallPath -ErrorAction SilentlyContinue).InstallPath
    Write-Host "  Install path: $installPath"

    if ($installPath -like "*D:\Dev\TradBOT*") {
        Write-Host "  ❌ CORRUPTED - Points to TradBOT"
        Write-Host "  Removing corrupted entries..."
        Remove-Item "$regPath\InstallPath" -Force -ErrorAction SilentlyContinue
    }
}

# Check 32-bit registry
if (Test-Path $regPath64) {
    Write-Host "Found: $regPath64"
    $installPath = (Get-ItemProperty $regPath64\InstallPath -ErrorAction SilentlyContinue).InstallPath
    Write-Host "  Install path: $installPath"

    if ($installPath -like "*D:\Dev\TradBOT*") {
        Write-Host "  ❌ CORRUPTED - Points to TradBOT"
        Write-Host "  Removing corrupted entries..."
        Remove-Item "$regPath64\InstallPath" -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Registry cleanup complete."
Write-Host ""
Write-Host "⚠️  MANUAL STEP REQUIRED:"
Write-Host "1. Uninstall Python 3.11.9 via Control Panel"
Write-Host "2. Download fresh Python 3.11.9 from python.org"
Write-Host "3. Reinstall to: C:\Users\USER\AppData\Local\Programs\Python\Python311_9"
Write-Host ""
