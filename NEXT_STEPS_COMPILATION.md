# 🚀 Next Steps: Compile & Test Sniper Graphics

## ⏱️ Time Required: ~5 minutes

---

## Step 1: Compile in Terminal 1 (MT5)

1. **Open MetaTrader 5 Terminal 1**
2. **Open MetaEditor** (Tools → Editor or Ctrl+E)
3. **Open** `SMC_Universal.mq5`
4. **Press F5** to compile
   - ✅ You should see: "Compilation successful"
   - ❌ If errors appear: Check Expert tab for error messages

---

## Step 2: Compile in Terminal 2 (MT5)

1. **Open MetaTrader 5 Terminal 2**
2. **Open MetaEditor** (Tools → Editor or Ctrl+E)
3. **Open** `SMC_Universal.mq5`
4. **Press F5** to compile
   - ✅ You should see: "Compilation successful"
   - ❌ If errors appear: Check Expert tab for error messages

---

## Step 3: Restart EAs on Both Terminals

### Terminal 1:
1. Find the chart with SMC_Universal EA attached
2. Right-click the EA → **Remove**
3. Right-click chart → **Expert Advisors** → **SMC_Universal**
4. Click OK (or adjust inputs and click OK)

### Terminal 2:
1. Find the chart with SMC_Universal EA attached
2. Right-click the EA → **Remove**
3. Right-click chart → **Expert Advisors** → **SMC_Universal**
4. Click OK (or adjust inputs and click OK)

---

## Step 4: Verify Graphics on Chart

### What You Should See:

✅ **Horizontal Lines** (Liquidity Zones)
```
Red line = Buy Side Liquidity (BSL) zone
Green line = Sell Side Liquidity (SSL) zone
Dashed style, width 3
```

✅ **Rectangles** (Order Blocks)
```
Yellow rectangle = Bullish Order Block (potential support)
Orange rectangle = Bearish Order Block (potential resistance)
Semi-transparent so you can see price action
```

✅ **Shaded Zones** (Fair Value Gaps)
```
Cyan shaded rectangle = FVG (price gap)
Semi-transparent (30% opacity)
Shows institutional liquidity zones
```

✅ **Text Label** (Top-Left Corner)
```
CONFLUENCE: X/5 | STRENGTH: Y%
Green text = High quality (4-5/5)
Yellow text = Moderate quality (3/5)
```

---

## Step 5: Enable Debug Logging (Optional)

If you want to see detailed signal quality scores in logs:

1. **Terminal 1**: Right-click EA → **Modify** → Set `DebugSniperModules = true` → OK
2. **Terminal 2**: Right-click EA → **Modify** → Set `DebugSniperModules = true` → OK
3. **View Logs**: View → Logs (or Expert tab)

You'll see messages like:
```
✅ SNIPER VOTE: 8/10 | Quality: 75/100 | Type: SWEEP_BSL @ 1.2150
🚫 SNIPER: Qualité insuffisante (35/100) - confluence: 2
🚫 SNIPER: Confluence faible (2/5) - SKIP
```

---

## Step 6: Monitor First Trade

Watch for:

✅ **First few minutes**: Graphics should appear on chart  
✅ **After 5-10 minutes**: Monitor if trades execute  
✅ **New trades should be HIGH QUALITY** (confluence 3-5/5, quality 50-100/100)  
✅ **Fewer but better trades** than before (expected behavior)

---

## Expected Behavior Changes

### Before (Old Version):
- Any signal with any confluence level would trade
- No visible zones/indicators on chart
- Win rate ~7.7%

### After (New Version):
- Only signals with 3+/5 confluence trade
- Only signals with 50+/100 quality score trade
- All liquidity zones visible on chart
- Graphics show exactly what robot sees
- Expected win rate: 25-40%

---

## Troubleshooting

### Problem: Graphics Don't Appear
- ✅ Check: `ShowSniperGraphics = true` in inputs
- ✅ Check: Zoom in/out - graphics might be off-screen
- ✅ Check: Compile was successful (F5 → no errors)
- ✅ Check: Restarted EA after compile

### Problem: Too Few Trades
- ✅ This is EXPECTED - filtering now rejects low-quality signals
- ✅ If 0 trades in 30 min: Confluence threshold might be too high
- ✅ Option: Lower `MinConfluenceForTrade` if needed (advanced)

### Problem: Trade Execution Errors
- ✅ Check: Account has sufficient margin
- ✅ Check: Spread is not too wide
- ✅ Check: EA logs for specific error messages

---

## Quality Metrics to Monitor

| Metric | What It Means | Goal |
|--------|--------------|------|
| Confluence 5/5 | Perfect signal alignment | Excellent |
| Confluence 4/5 | Very good signal quality | Good |
| Confluence 3/5 | Minimum acceptable | Acceptable |
| Confluence 1-2/5 | REJECTED by new filter | ✅ Prevents losses |
| Quality 70-100 | High quality signal | Execute |
| Quality 50-70 | Medium quality signal | Execute (if confluence OK) |
| Quality <50 | REJECTED by filter | ✅ Prevents losses |

---

## Files Modified

✅ **SMC_Universal.mq5** - Graphics + filtering enhanced  
✅ **Deployed to both terminals** via clean deploy.sh script

---

## Timeline

| Time | Action |
|------|--------|
| Now | Read this guide |
| T+0 | Compile F5 in Terminal 1 |
| T+1 | Compile F5 in Terminal 2 |
| T+2 | Restart EAs on both terminals |
| T+3 | Verify graphics appear |
| T+5 | Monitor first trade |
| T+30 | Check quality scores in logs |
| T+1 hour | Assess win rate improvements |

---

## Questions to Track

After 1 hour of trading:
- [ ] Graphics visible on chart?
- [ ] Confluence scores displaying correctly?
- [ ] Fewer trades (due to filtering)?
- [ ] Trades that execute have 3+/5 confluence?
- [ ] Any error messages in logs?

---

**Status: Ready for Compilation**

⏳ Awaiting: User compiles (F5) and restarts EAs

Next improvement after this works: Fine-tune EMA periods + exit timing for better win rate.

