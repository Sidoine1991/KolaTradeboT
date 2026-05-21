$body = @{
    symbol         = "EURUSD"
    action         = "sell"
    execution_type = "limit"
    entry_price    = 1.1625
    stop_loss      = 1.1685
    take_profit    = 1.1550
    lot            = 0.01
    confidence     = 0.70
    source         = "manual"
    comment        = "TA_BRIDGE"
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri "http://127.0.0.1:8000/pending-order" -ContentType "application/json" -Body $body
