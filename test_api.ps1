$body = @{
    symbol = "EURUSD"
    timeframe = "H1"
    request_type = "fibonacci_analysis"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/analysis" -Method Post -Body $body -ContentType "application/json"
    Write-Host "Réponse reçue :"
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Erreur lors de l'appel API :"
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Message: $($_.Exception.Message)"
    Write-Host "Détails: $($_.ErrorDetails.Message)"
}
