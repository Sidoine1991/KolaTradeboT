# Install Python 3.11 fresh (no corruption)

$pythonVersion = "3.11.9"
$installDir = "C:\Users\USER\AppData\Local\Programs\Python\Python311_9"
$downloadUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"

Write-Host "Installing Python $pythonVersion to $installDir..."

# Create directory
New-Item -ItemType Directory -Force -Path (Split-Path $installDir) | Out-Null

# Download installer
$tempFile = "$env:TEMP\python-$pythonVersion-amd64.exe"
Write-Host "Downloading Python installer..."

try {
    # Use curl as fallback if WebClient fails
    curl -L -o $tempFile $downloadUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Host "curl failed, trying alternative method..."
        (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $tempFile)
    }
} catch {
    Write-Host "ERROR: Could not download Python: $_"
    exit 1
}

if (!(Test-Path $tempFile)) {
    Write-Host "ERROR: Download failed"
    exit 1
}

Write-Host "Installer downloaded: $tempFile"
Write-Host "Running installer..."

# Run installer in silent mode with custom path
& $tempFile /quiet InstallAllUsers=1 PrependPath=1 TargetPath=$installDir

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Python installed successfully"
    Write-Host "Path: $installDir"

    # Test installation
    & "$installDir\python.exe" --version
} else {
    Write-Host "❌ Installation failed with exit code $LASTEXITCODE"
    exit 1
}

# Cleanup
Remove-Item $tempFile -Force
Write-Host "`n✅ Installation complete!"
