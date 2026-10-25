$json = '{"symbol":"Boom 300 Index","bid":1000.0,"ask":1001.0,"rsi":50.0,"ema_fast_h1":1000.5,"ema_slow_h1":999.5,"ema_fast_m1":1000.2,"ema_slow_m1":999.8,"atr":5.0,"dir_rule":1,"is_spike_mode":false}'
$headers = @{
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/decision/Boom%20300%20Index" -Method Post -Body $json -Headers $headers
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Erreur: $($_.Exception.Message)"
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
}
