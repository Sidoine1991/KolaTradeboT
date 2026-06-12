# Install fresh Python 3.11 without corruption

Write-Host "Installing Python 3.11.9..."

$installer = "C:\Users\USER\AppData\Local\Temp\python-3.11.9-installer.exe"
$installDir = "C:\Users\USER\AppData\Local\Programs\Python\Python311_9"

if (!(Test-Path $installer)) {
    Write-Host "ERROR: Installer not found at $installer"
    exit 1
}

Write-Host "Running installer from: $installer"
Write-Host "Target directory: $installDir"

# Run with silent mode - prepend to PATH, install for current user
& $installer /quiet InstallAllUsers=0 PrependPath=1 TargetPath=$installDir

$exitCode = $LASTEXITCODE
Write-Host "Installer exit code: $exitCode"

if ($exitCode -eq 0) {
    Write-Host "`n✅ Installation successful!"
    Start-Sleep 2

    # Test installation
    $pythonExe = "$installDir\python.exe"
    if (Test-Path $pythonExe) {
        Write-Host "Testing Python..."
        & $pythonExe --version

        Write-Host "`n✅ Python is working!"
        Write-Host "Path: $pythonExe"
    } else {
        Write-Host "ERROR: python.exe not found at $pythonExe"
        exit 1
    }
} else {
    Write-Host "ERROR: Installation failed"
    exit 1
}

# Cleanup
if (Test-Path $installer) {
    Remove-Item $installer -Force
    Write-Host "Cleaned up installer"
}

Write-Host "`n✅ Done!"
