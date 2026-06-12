# Update PATH to use working Python 3.14 instead of corrupted 3.11_9

$pythonWorks = "C:\Python314_old\python.exe"
$pythonCorrupted = "C:\Users\USER\AppData\Local\Programs\Python\Python311_9\python.exe"

if (!(Test-Path $pythonWorks)) {
    Write-Host "ERROR: Working Python not found at $pythonWorks"
    exit 1
}

Write-Host "Updating PATH to use Python 3.14..."

# Get current PATH
$path = [Environment]::GetEnvironmentVariable("Path", "User")

# Remove corrupted Python from PATH
$pathNew = $path -replace [regex]::Escape("C:\Users\USER\AppData\Local\Programs\Python\Python311_9;"), ""
$pathNew = $pathNew -replace [regex]::Escape("C:\Users\USER\AppData\Local\Programs\Python\Python311_9"), ""
$pathNew = $pathNew -replace [regex]::Escape("C:\Users\USER\AppData\Local\Programs\Python\Python311_9\Scripts;"), ""

# Add working Python to PATH (at the front for priority)
$pathNew = "C:\Python314_old;C:\Python314_old\Scripts;$pathNew"

# Remove duplicates
$pathNew = ($pathNew -split ';' | Select-Object -Unique) -join ';'

# Set new PATH
[Environment]::SetEnvironmentVariable("Path", $pathNew, "User")

Write-Host "✅ PATH updated"
Write-Host "Old Python: $pythonCorrupted (REMOVED)"
Write-Host "New Python: $pythonWorks (ADDED)"

# Test
Write-Host "`nTesting new PATH..."
& $pythonWorks --version

Write-Host "`n✅ Done! Open new terminal for changes to take effect"
