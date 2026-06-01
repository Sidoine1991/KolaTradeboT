# FIX: Candle Divergence Between TradingView & TradeManager

## 🔴 ROOT CAUSE

**AI Server `/gom-verdict` endpoint is NOT returning:**
- `pred_path` (predicted candle path)
- `atr` (Average True Range)

These are **essential** for the EA to draw the predicted candles correctly.

## ✅ SOLUTION

### Option 1: Add to AI Server (RECOMMENDED)

Update `ai_server.py` `/gom-verdict` endpoint to include:

```python
@app.get("/gom-verdict")
def get_gom_verdict(symbol: str = "XAUUSD"):
    # ... existing code ...
    
    return {
        "ok": True,
        "symbol": symbol,
        "verdict": verdict,
        "message": message,
        # ADD THESE:
        "pred_path": pred_path,  # String like "DBDBDUUDUD..."
        "atr": atr_value,         # Float like 15.32
        "path_step": 0.16,        # Sync value
    }
```

### Option 2: Calculate in TradeManager

If AI server cannot be modified, TradeManager can calculate locally:

```mql5
// In TradeManager.mq5
double GetATR() {
    return iATR(Symbol(), PERIOD_M1, 10);  // Should match Pine: ta.atr(10)
}

string GetPredPath() {
    // Calculate from bar direction prediction
    // Using the same logic as Pine Script
    // ... implementation ...
}
```

## 🔄 SYNC PARAMETERS

Both systems MUST have identical values:

| Parameter | Pine Script | TradeManager | Value |
|-----------|------------|--------------|--------|
| path_step | path_step | GOMPathStepAtr | 0.16 |
| ATR period | ta.atr(10) | iATR(..., 10) | 10 |
| Timeframe | M1 | PERIOD_M1 | M1 |
| Lookback | 200 bars | GOMPathDrawBars | 200 |

## 📋 ACTION PLAN

1. **Check AI Server** - Does `/gom-verdict` return `pred_path` and `atr`?
   ```bash
   curl -s "http://127.0.0.1:8000/gom-verdict?symbol=XAUUSD"
   ```

2. **If Missing** - Modify `ai_server.py` to include these fields

3. **Recompile Both**:
   - GOM_KOLA_SIDO.pine (TradingView)
   - TradeManager.mq5 (MetaEditor)

4. **Restart MT5** - Restart MetaTrader 5 to load new EA

5. **Compare** - Candles in TradingView should now match EA drawing

## 🧪 VERIFICATION

After fix, verify with:

```python
import requests
resp = requests.get("http://127.0.0.1:8000/gom-verdict?symbol=XAUUSD")
data = resp.json()
print(f"Has pred_path: {'pred_path' in data}")
print(f"Has atr: {'atr' in data}")
print(f"Path step: {data.get('path_step', 'MISSING')}")
```

Expected output:
```
Has pred_path: True
Has atr: True
Path step: 0.16
```

## 📝 NOTES

- The divergence is NOT a bug, it's missing data
- Once `pred_path` and `atr` are included, both systems will align
- The `path_step = 0.16` value must be synchronized in code
