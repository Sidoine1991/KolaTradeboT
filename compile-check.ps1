#!/usr/bin/env powershell
# Compile and check for errors

$MetaEditorPath = "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
$SourceFile = "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
$OutputLog = "D:\Dev\TradBOT\compile_output.txt"

if (!(Test-Path $MetaEditorPath)) {
    Write-Host "MetaEditor not found at: $MetaEditorPath" -ForegroundColor Red
    exit 1
}

Write-Host "Starting compilation..." -ForegroundColor Green
& $MetaEditorPath $SourceFile /compile 2>&1 | Tee-Object -FilePath $OutputLog

Write-Host "`nCompilation complete. Check $OutputLog for details." -ForegroundColor Green
