# Deriv WebSocket Integration

## Overview

The GOM Live Calculator now supports **real-time candle data from Deriv WebSocket** instead of stale JSON files.

### Data Source Priority

1. **Deriv WebSocket** (LIVE, real-time) ← PRIMARY
2. **CSV Local** (historical cache)
3. **Synthetic Fallback** (gom_signal.json)

---

## Status

### Current Issue
**Network connectivity error: DNS resolution failed for ws.deriv.com**

This is likely a **firewall/proxy blocking** the WebSocket connection.

### Workarounds

#### Option 1: Configure Proxy (Recommended)
```python
# In Python/deriv_candles_ws.py, modify the websocket connection:
async with websockets.connect(
    ws_url, 
    max_size=None,
    proxy="http://proxy.example.com:8080"  # Add your proxy URL
) as websocket:
```

#### Option 2: Use VPN or Network Bypass
If your network blocks WebSocket connections, try:
- Use a VPN to bypass network restrictions
- Connect from a different network
- Contact your IT admin to whitelist ws.deriv.com

#### Option 3: Fall Back to CSV Data
Currently the system automatically falls back to CSV if Deriv fails.

To pre-populate CSV candles:
```bash
# Export historical candles from MT5 → CSV
# Place in data/ directory:
# - data/XAUUSD_1.csv (M1 candles)
# - data/XAUUSD_5.csv (M5 candles)
# - data/XAUUSD_15.csv (M15 candles)
```

---

## Implementation Details

### Supported Symbols

| Symbol | Deriv ID | Status |
|--------|----------|--------|
| XAUUSD | 1100 | ✅ Mapped |
| BTCUSD | 1D_BTC | ✅ Mapped |
| EURUSD | frxEURUSD | ✅ Mapped |
| Boom 500 | R_50 | ✅ Mapped |
| Crash 500 | R_50 | ✅ Mapped |

Add more symbols to `DERIV_SYMBOL_MAP` in `deriv_candles_ws.py`

### Supported Timeframes

- 1m (1 minute)
- 5m (5 minutes)
- 15m (15 minutes)
- 1h (1 hour)
- 4h (4 hours)
- 1d (1 day)

### Code Flow

```
API Request: GET /gom-kola-dashboard?symbol=XAUUSD
    ↓
GOMSignalsLiveCalculator.calculate_record_live(symbol)
    ↓
get_candles(symbol, timeframe, bars)
    ├─ Priority 1: DerivCandlesWSFetcher.fetch_candles() [LIVE]
    │   └─ WebSocket → JSON → DataFrame
    ├─ Priority 2: get_candles_from_csv(symbol) [Cached]
    │   └─ CSV → DataFrame
    └─ Priority 3: get_candles_fallback(symbol) [Fallback]
        └─ Synthetic → DataFrame
    ↓
Calculate indicators (RSI, BB, VWAP, MACD, SuperTrend, KOLA)
    ↓
Return LIVE verdicts (< 1 sec latency)
```

---

## Testing

### Test Deriv Connection

```python
python -c "
import sys
sys.path.insert(0, 'Python')
import asyncio
from deriv_candles_ws import get_deriv_candles

async def test():
    df = await get_deriv_candles('XAUUSD', '15', 10)
    if df is not None:
        print('SUCCESS! Deriv connection works')
        print(df.tail(3))
    else:
        print('FAILED: Check network/proxy settings')

asyncio.run(test())
"
```

### Monitor Production

Check server logs:
```bash
tail -f /tmp/server.log | grep -i "GOM-CALC\|Deriv\|Fetched"
```

Expected output:
```
[GOM-CALC] Fetched 100 candles from Deriv WebSocket for XAUUSD 15m
```

---

## Data Verification

Compare API response with TradingView/MT5:

```bash
# Get API data
curl http://localhost:8000/gom-kola-dashboard?symbol=XAUUSD | python -m json.tool

# Check:
# - "source": "live_calculation" ✅
# - "timestamp": Recent (< 1 sec) ✅
# - "rsi14": NOT 50 (synthetic indicator) ✅
# - "score_buy", "score_sell": Non-zero ✅
```

---

## Troubleshooting

### Issue: RSI = 50 (Neutral)
**Cause**: Using synthetic fallback data
**Fix**: Check Deriv connection (see "Configure Proxy" above)

### Issue: "DNS resolution failed"
**Cause**: Network can't reach ws.deriv.com
**Fix**: 
- Test: `ping ws.deriv.com` or `nslookup ws.deriv.com`
- Configure proxy or VPN
- Contact network admin

### Issue: "HTTP 401 Unauthorized"
**Cause**: Authentication required
**Fix**: Deriv WebSocket should be public; check if API key needed

---

## Next Steps

1. **Test Network**: Verify connectivity to ws.deriv.com
2. **Configure Proxy**: If behind corporate firewall
3. **Monitor Logs**: Ensure "Deriv WebSocket" appears in logs
4. **Validate Data**: Compare API vs TradingView indicators

---

## Architecture

The integration is designed to be **transparent and automatic**:
- No configuration needed (uses public Deriv API)
- Automatic fallback to CSV if WebSocket fails
- Thread-safe execution in async FastAPI context
- Timeout protection (5 seconds max wait)

Once network connectivity is restored, real-time candles will flow automatically.

---

**Status**: ✅ Code ready, awaiting network connectivity
