param(
    [string]$MessageFile = "D:\Dev\TradBOT\whatsapp_current_alert.txt"
)

# Lire le message depuis le fichier
if (-not (Test-Path $MessageFile)) {
    Write-Host "❌ Fichier message non trouvé: $MessageFile"
    exit 1
}

$message = Get-Content -Path $MessageFile -Raw -Encoding UTF8

# Construire le JSON payload
$payload = @{
    phone = "+2290196911346"
    message = $message
} | ConvertTo-Json

# Envoyer via PsychoBot
try {
    $response = Invoke-RestMethod -Uri "https://psychobot-1si7.onrender.com/send-message" `
        -Method Post `
        -ContentType "application/json" `
        -Body $payload `
        -TimeoutSec 10

    Write-Host "✅ Message WhatsApp envoyé avec succès"
    Write-Host "Réponse: $($response | ConvertTo-Json)"
}
catch {
    Write-Host "⚠️ Erreur d'envoi: $_"
    # Fallback : sauvegarder dans le log
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = "D:\Dev\TradBOT\whatsapp_alerts.log"
    "[${timestamp}] ERREUR - Message non envoyé`n${message}`n━━━━━━━━━━━━━━━━━`n" | Add-Content -Path $logPath
    Write-Host "💾 Message sauvegardé dans $logPath"
}
