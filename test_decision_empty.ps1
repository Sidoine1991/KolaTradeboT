$headers = @{
    "Content-Type" = "application/json"
}

try {
    # Test avec corps vide (comme l'EA MT5)
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/decision/Boom%20300%20Index" -Method Post -Headers $headers
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Erreur: $($_.Exception.Message)"
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
}
