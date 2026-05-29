# Read message
$msg = Get-Content -Path 'D:\Dev\TradBOT\whatsapp_xauusd_latest.txt' -Raw -Encoding UTF8

# Create JSON payload
$payload = @{
    phone = '+2290196911346'
    message = $msg
} | ConvertTo-Json

# Send to PsychoBot
try {
    $response = Invoke-RestMethod -Uri 'https://psychobot-1si7.onrender.com/send-message' `
        -Method Post `
        -ContentType 'application/json' `
        -Body $payload `
        -TimeoutSec 15 `
        -ErrorAction Stop

    Write-Host "Message sent successfully"
    Write-Host $response
    exit 0
}
catch {
    Write-Host "Error: $_"

    # Fallback: save to log
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $log = "[$ts] XAUUSD Market Alert`n$msg`n" + ("="*60) + "`n`n"
    Add-Content -Path 'D:\Dev\TradBOT\whatsapp_alerts.log' -Value $log -Encoding UTF8

    Write-Host "Saved to log"
    exit 1
}
