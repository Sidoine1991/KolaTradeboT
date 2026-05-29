$messagePath = 'D:\Dev\TradBOT\whatsapp_current_alert_v2.txt'
$logPath = 'D:\Dev\TradBOT\whatsapp_alerts.log'

if (-not (Test-Path $messagePath)) {
    Write-Host "Message file not found"
    exit 1
}

$message = Get-Content -Path $messagePath -Raw -Encoding UTF8

$payload = @{
    phone = '+2290196911346'
    message = $message
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri 'https://psychobot-1si7.onrender.com/send-message' `
        -Method Post `
        -ContentType 'application/json' `
        -Body $payload `
        -TimeoutSec 10

    Write-Host "Message sent successfully"
    exit 0
}
catch {
    Write-Host "Error: $_"

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[{0}] Failed to send`n{1}`n{'='*50}`n`n" -f $timestamp, $message | Add-Content -Path $logPath -Encoding UTF8

    Write-Host "Saved to log"
    exit 1
}
