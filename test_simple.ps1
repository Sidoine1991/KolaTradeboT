$json = '{"symbol":"Boom 300 Index","timeframe":"H1","request_type":"fibonacci_analysis"}'
$headers = @{
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/analysis" -Method Post -Body $json -Headers $headers
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Erreur: $($_.Exception.Message)"
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
}
