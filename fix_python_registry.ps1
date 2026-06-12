# Fix Python 3.11 registry corruption
# Issue: sys.base_prefix points to D:\Dev\TradBOT instead of Python install directory

Write-Host "Fixing Python 3.11 registry corruption..."

# Find Python install path
$pythonPath = "C:\Users\USER\AppData\Local\Programs\Python\Python311_9"

# Check if Python exists
if (!(Test-Path $pythonPath)) {
    Write-Host "ERROR: Python not found at $pythonPath"
    exit 1
}

Write-Host "Python path: $pythonPath"

# Remove any registry entries that might have TradBOT path
# Note: This requires admin privileges
$regPath = "HKCU:\SOFTWARE\Python\PythonCore\3.11\PythonPath"

try {
    if (Test-Path $regPath) {
        Write-Host "Clearing Python registry path: $regPath"
        Remove-Item $regPath -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "WARNING: Could not modify registry (may need admin privileges)"
}

# Alternative: Create a python.bat that resets environment
$pythonBat = @"
@echo off
REM Python launcher - bypasses registry corruption
setlocal
set PYTHONHOME=
set PYTHONPATH=
"$pythonPath\python.exe" %*
"@

$pythonBat | Out-File -FilePath "D:\Dev\TradBOT\python.bat" -Encoding ASCII

Write-Host "Created python.bat wrapper at D:\Dev\TradBOT\python.bat"
Write-Host "Usage: python.bat script.py"

Write-Host "`nFix complete!"
