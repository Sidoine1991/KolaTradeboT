#!/usr/bin/env powershell
# Force MetaEditor to compile SMC_Universal.mq5

$MetaEditorPath = "D:\Program Files\MetaTrader 5\MetaEditor64.exe"
$SourceFile = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"

# Step 1: Delete any existing compiled files
Write-Host "Step 1: Cleaning compiled files..." -ForegroundColor Green
Remove-Item -Path "$PSScriptRoot\mt5\*.ex5" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$PSScriptRoot\mt5\*.ex4" -Force -ErrorAction SilentlyContinue
Write-Host "✓ Cleaned" -ForegroundColor Green

# Step 2: Update file timestamp to force recompile
Write-Host "Step 2: Updating file timestamp..." -ForegroundColor Green
(Get-Item $SourceFile).LastWriteTime = Get-Date
Write-Host "✓ Updated" -ForegroundColor Green

# Step 3: Compile
Write-Host "Step 3: Compiling SMC_Universal.mq5..." -ForegroundColor Green
& $MetaEditorPath $SourceFile /compile 2>&1

# Step 4: Check for success
if (Test-Path "$PSScriptRoot\mt5\SMC_Universal.ex5") {
    Write-Host "✅ COMPILATION SUCCESSFUL!" -ForegroundColor Green
    Write-Host "Binary created at: $PSScriptRoot\mt5\SMC_Universal.ex5" -ForegroundColor Green
} else {
    Write-Host "❌ Compilation may have failed. Check MetaEditor output above." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Cyan
[void][System.Console]::ReadKey($true)
