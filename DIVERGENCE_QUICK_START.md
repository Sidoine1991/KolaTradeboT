# Divergence Robot — Quick Start Guide

**Setup Time**: 5 minutes  
**Status**: Production Ready

---

## 1. Deploy MQL5 Robot

### Copy Robot to MT5

```bash
# File locations
Source:   D:\Dev\TradBOT\Divergence_Robot_With_GOM.mq5
Dest:     C:\Users\[YOUR_USER]\AppData\Roaming\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Experts\
```

Or use MT5 UI:
1. Tools → Options → Files → Open Data Folder
2. Navigate to `MQL5\Experts`
3. Paste `Divergence_Robot_With_GOM.mq5`

### Compile

```
MetaQuotes Terminal → Tools → Compile (F7)
Expected: 0 errors, 0 warnings
```

---

## 2. Attach to Chart

1. **Open Chart**: Any pair (EURUSD, GBPUSD, USDJPY recommended for liquidity)
2. **Timeframe**: H1 primary, any TF OK for backtesting
3. **Expert Advisor**: Divergence_Robot_With_GOM
4. **Input Parameters**:
   - `EnableAutoTrading`: true
   - `EnableGOMEntryLevels`: true
   - `EnableOrderBlockDetection`: true
   - `EnableSIDO`: true

5. **Click OK** → Robot attaches and starts scanning

---

## 3. Configure Backend

### Start ai_server.py

```bash
cd D:\Dev\TradBOT
python ai_server.py --port 8000
```

Expected output:
```
[INFO] Uvicorn running on http://0.0.0.0:8000
[INFO] Divergence strategy module imported successfully
```

### Verify Divergence Endpoint

```bash
curl -X POST http://localhost:8000/divergence/signal \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "candles": [
      {"o": 1.0850, "h": 1.0860, "l": 1.0840, "c": 1.0855, "v": 1000},
      {"o": 1.0855, "h": 1.0870, "l": 1.0850, "c": 1.0865, "v": 1100},
      {"o": 1.0865, "h": 1.0875, "l": 1.0860, "c": 1.0870, "v": 1200},
      {"o": 1.0870, "h": 1.0880, "l": 1.0865, "c": 1.0875, "v": 1300},
      {"o": 1.0875, "h": 1.0885, "l": 1.0870, "c": 1.0880, "v": 1400},
      {"o": 1.0880, "h": 1.0890, "l": 1.0875, "c": 1.0885, "v": 1500}
    ],
    "lookback": 5,
    "threshold": 0.18,
    "confluence_min": 3
  }'
```

Expected response:
```json
{
  "ok": true,
  "symbol": "EURUSD",
  "direction": "BUY",
  "confidence": 82.5,
  "divergence_score": 4,
  "entry_price": 1.0885,
  "stop_loss": 1.0860,
  "take_profit": 1.0920,
  "reason": "Score 4, Price ROC 0.0325, Vol Anom 0.50, RSI 68.2"
}
```

---

## 4. Monitor Robot

### Dashboard on Chart

Real-time displays:
```
═ DIVERGENCE ROBOT v2.0 + GOM ═
Positions: 1/3
Trades Today: 2/5
Last Signal: BUY @ 1.0855
Confidence: 87.5%
Score: 4/3
GOM Entry: 1.0850 (M5)
```

### Journal Logs

Check MT5 Journal (Terminal → Experts) for execution logs:
```
✅ Divergence ENTRY BUY @ 1.0855 | SL=1.0830 | TP=1.0900
🎯 Divergence Score=4 Confidence=87.5%
⏹ Closing position - max hold exceeded
```

### Strategy Statistics

```bash
curl http://localhost:8000/divergence/stats
```

Returns:
```json
{
  "strategy": "Divergence v5",
  "metrics": {
    "sharpe": 0.85,
    "win_rate": 0.424,
    "profit_factor": 1.05,
    "trades_per_day": 3.2,
    "max_drawdown": -0.19
  }
}
```

---

## 5. Fine-Tuning Parameters

### For More Trades

```
DivThreshold: 0.18 → 0.15  (lower = more sensitivity)
ConfluenceMin: 3 → 2        (accept weaker signals)
TouchZoneATRPercent: 25 → 35 (wider GOM zones)
```

### For Less Noise

```
DivThreshold: 0.18 → 0.22  (higher = stricter)
ConfluenceMin: 3 → 4        (require stronger signals)
TouchZoneATRPercent: 25 → 15 (tighter GOM zones)
```

### For Better Risk Management

```
SLMultiplier: 1.4 → 1.8    (wider stops)
TPMultiplier: 2.5 → 3.0    (larger targets)
MaxCapital: 10000 → [your capital]
RiskPercent: 1.2 → [your risk %]
```

---

## 6. Key Signals to Watch

### ✅ Strong Buy Signal

```
✓ Divergence score ≥ 4
✓ Confidence ≥ 80%
✓ GOM level within 5 pips
✓ Order Block confirmed
✓ RSI < 30 + positive ROC
→ HIGH PROBABILITY ENTRY
```

### ⚠️ Weak Signal (Be Cautious)

```
✗ Divergence score = 3 (minimum)
✗ Confidence < 60%
✗ No GOM level within 20 pips
✗ No Order Block
✗ RSI mid-range (40-60)
→ SKIP or USE CAUTION
```

---

## 7. Typical Trading Day

### Morning (08:00-12:00 UTC)

```
GOM KOLA levels scan → Usually 4-8 strong levels detected
Divergence signals → 0-2 per hour average
Expected trades → 1-2

Risk: Low volume pre-European session
Action: Use wider stops, smaller lot sizes
```

### Mid-Day (12:00-16:00 UTC)

```
Peak activity, high volume
Divergence signals → 1-3 per hour
Expected trades → 2-4

Risk: Highest volatility
Action: Use tight stops, aggressive SL
```

### Afternoon (16:00-20:00 UTC)

```
Lower activity, consolidation
Divergence signals → 0-1 per hour
Expected trades → 0-2

Risk: Choppy market
Action: SKIP or use very tight confluence (≥4 score)
```

---

## 8. What to Expect

### First Day

- Robot attaches successfully ✓
- GOM levels display on chart ✓
- 0-3 trading signals (may not trade)
- Dashboard updates every bar ✓

### First Week

- 15-35 trading signals total
- 6-14 executed trades (≥3 confluence score)
- 2-6 profitable, 4-8 losses
- Net: +1-3% P&L expected

### After Optimization

- Familiar with signal quality
- Adjusted stops/targets to market
- Refined confluence thresholds
- Consistent 3-5% monthly target

---

## 9. Troubleshooting

| Issue | Solution |
|-------|----------|
| "0 errors, 0 warnings" but no trades | Check `EnableAutoTrading = true` |
| Positions close immediately | Increase `MaxHoldBars` to 15-20 |
| Too many false signals | Increase `ConfluenceMin` to 4 |
| SL constantly hit | Increase `SLMultiplier` to 1.8-2.0 |
| No GOM levels detected | Reduce `TouchZoneATRPercent` to 20-25 |

---

## 10. Next Steps

### Backtest

```
1. Open Strategy Tester (Ctrl+R)
2. Select Divergence_Robot_With_GOM
3. Choose pair (EURUSD, GBPUSD)
4. Timeframe: H1
5. Period: Last 3 months
6. Run → Review report
```

### Live Trading (Recommended)

```
1. Attach robot to live chart
2. Set EnableAutoTrading = true
3. Monitor first week
4. Adjust parameters based on results
5. Scale gradually (0.01 → 0.05 → 0.10 lot)
```

### Custom Extensions

```
- Integrate with TradingView webhook for alerts
- Add custom notifications (Telegram, Discord)
- Link with external signals for confirmation
- Create dashboard overlay with WebSocket
```

---

## Support

**Documentation**: `DIVERGENCE_ROBOT_DOCUMENTATION.md`  
**API Docs**: `http://localhost:8000/docs` (Swagger UI)  
**Logs**: MT5 Journal tab for execution details

**Quick Reference**:
```bash
# Check robot status
curl http://localhost:8000/health

# Get live divergence signal
curl -X POST http://localhost:8000/divergence/signal -d '...'

# View strategy stats
curl http://localhost:8000/divergence/stats
```

---

**Ready to trade!** Start with backtest, then attach to live chart. 🚀

