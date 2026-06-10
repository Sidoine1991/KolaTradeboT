# Enable GHOST OrderFlow Visual Dashboard on TradingView

## Problem
GHOST OrderFlow data is being captured but not visually displayed on the chart.

## Solution
Add two indicators to your Boom500 M1 chart:

---

## Step 1: Add GHOST_Dashboard_Visual Pine Script

### File Location
```
D:\Dev\TradBOT\mt5\GHOST_Dashboard_Visual.pine
```

### Instructions
1. **Open TradingView Desktop**
2. **Open Boom 500 Index M1 chart**
3. **Open Pine Script Editor** (Alt+E)
4. **Create New Script** → Indicator
5. **Copy-paste entire content** from `GHOST_Dashboard_Visual.pine`
6. **Save** (Ctrl+S)
7. **Click "Add to Chart"** button
8. **Confirm** → Indicator appears on chart

### What You'll See
```
👻 GHOST OrderFlow v10
──────────────────────
BUY:  ██████████ 72.5%
SELL: ███ 27.5%

Δ: 🟢 +1245.8
CVD: ▲ +8932.1

Compass: NE↗ (45.0°)
Quality: 72.0% | Age: ⏱ 3s

✅ BUY CONFLUENCE
• GOM: BUY (2.5)
• GHOST: Buyers 72.5% + CVD bullish
• ICT: Grade B (Score 68)
• RSI: 62 (bullish)

ENTRY SETUP
Entry: 1845.32
SL: 1844.87 (−45 pips)
TP1: 1846.50 (−118 pips)
R/R: 1:1.8
```

### Color Coding
- **Green** = Bullish sentiment (BUY signals)
- **Red** = Bearish sentiment (SELL signals)
- **Yellow** = Neutral (HOLD)
- **White text** = Labels and info

---

## Step 2: Verify gom_signal.json is Updated

The GHOST panel reads from: `D:\Dev\TradBOT\data\gom_signal.json`

### Current Data (Test)
```json
{
  "ghost_delta": 1245.8,
  "ghost_cvd": 8932.1,
  "ghost_compass": 45,
  "ghost_buypct": 72.5,
  "ghost_sellpct": 27.5,
  "ghost_available": true,
  "quality": 72.0
}
```

### When gom_verdict_poller.py runs live
This file will auto-update every 5 seconds with real GHOST data from TradingView MCP.

---

## Step 3: Attach DerivEAPro EA to Same Chart

1. **Right-click chart** → Attach Expert Advisor
2. **Select: DerivEAPro (v10.00)**
3. **Properties → Inputs:**
   - InpUseGHOST = **TRUE**
   - InpRiskPercent = 1.5
4. **Click OK**

### What EA Does (Behind the Scenes)
- Reads gom_signal.json every 5 seconds
- Applies GHOST filter to entry logic
- Logs GHOST verdict in every trade reason
- Displays GHOST panel on dashboard

---

## Step 4: Monitor Real-Time Updates

### Expected Behavior
1. **Pine indicator** shows GHOST dashboard
2. **EA logs** include "[GHOST] verdict=..." messages
3. **Entry signals** logged with GHOST confidence
4. **Dashboard** shows GHOST panel on EA

### Example Log Output
```
[v10] GHOST OrderFlow activé | MinQuality=40.0% | MaxAge=60s
[GHOST] verdict=BUY buypct=72.5 quality=72.0 cvd=8932.1
[SPIKE] ATR spike +0.45 (2.1x ATR_M1)
[ENTRY] ANTICIPATION 75% | ICT=68(B) + GHOST=BUY | RSI=62
[TRADE] BUY 0.20 lot @ 1845.32 | SL=1844.87 TP=1846.85
```

---

## Step 5: Data Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│ TradingView Desktop (Chrome DevTools Protocol)           │
│ • GHOST_OrderFlow.pine indicator                         │
│ • Calculates: Delta, CVD, Sentiment, Compass             │
│ • Plots to Data Window                                   │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓ (MCP capture via gom_verdict_poller.py)
┌──────────────────────────────────────────────────────────┐
│ D:\Dev\TradBOT\data\gom_signal.json                      │
│ Updated every 5 seconds with:                            │
│ • ghost_delta: +1245.8                                   │
│ • ghost_cvd: +8932.1                                     │
│ • ghost_buypct: 72.5%                                    │
│ • ghost_compass: 45° (NE bullish)                        │
│ • quality: 72.0%                                         │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ↓                     ↓
   Pine Indicator        DerivEAPro EA v10
   (Visual)              (Logic)
   
   👻 GHOST Panel ----→ GHOST Filter in EvaluateEntry()
   Shows sentiment      Blocks trades on divergence
   Displays data age    Logs GHOST verdict
   Color codes trend    Calculates confidence
```

---

## Troubleshooting

### Issue 1: Pine Indicator Not Showing
**Solution:**
1. Alt+E to open Pine Script editor
2. Search for "GHOST_Dashboard_Visual"
3. Click chart icon to add to chart
4. Check "Show on Chart" in indicator settings

### Issue 2: All Values Show as 0 or "N/A"
**Solution:**
1. Verify gom_signal.json exists: `D:\Dev\TradBOT\data\gom_signal.json`
2. Check file contains GHOST fields (ghost_delta, ghost_cvd, ghost_buypct)
3. If using live: Start gom_verdict_poller.py to populate real data

### Issue 3: EA Not Logging GHOST Messages
**Solution:**
1. Verify DerivEAPro is attached: Check Expert tab
2. Set InpUseGHOST = TRUE in EA inputs
3. Search Expert log for "[GHOST]" to see messages
4. If blank: gom_signal.json file stale (>60s old)

### Issue 4: Panel Shows Old Data (Not Updating)
**Solution:**
1. Restart gom_verdict_poller.py
2. Check file timestamp: `gom_signal.json` should update every 5s
3. Verify TradingView Desktop has GHOST_OrderFlow.pine attached
4. Refresh chart: F5 or close/reopen chart

---

## Expected Visual Output

### Dashboard on Chart
```
┌─────────────────────────────────────┐
│ 👻 GHOST OrderFlow v10              │
├─────────────────────────────────────┤
│ BUY:  ██████████ 72.5%              │
│ SELL: ███ 27.5%                     │
│                                     │
│ Δ: 🟢 +1245.8 (buyers pushing)      │
│ CVD: ▲ +8932.1 (bullish accum)      │
│                                     │
│ Compass: NE↗ (45.0°) [Bullish]      │
│ Quality: 72.0% | Age: ⏱ 3s [Fresh]  │
│                                     │
│ ✅ BUY CONFLUENCE                   │
│ • GOM: BUY (2.5)                    │
│ • GHOST: Buyers 72.5% + CVD+        │
│ • ICT: Grade B (Score 68)           │
│ • RSI: 62 (bullish)                 │
│                                     │
│ ENTRY SETUP                         │
│ Entry: 1845.32                      │
│ SL: 1844.87 (−45 pips)              │
│ TP1: 1846.50 (−118 pips)            │
│ R/R: 1:1.8 (excellent)              │
└─────────────────────────────────────┘
```

### Entry Lines on Chart
```
1846.50 ━━━━━━━━━━━ (TP1 line)
1845.32 ━━━━━━━━━━━ (Entry line, green dashed)
1844.87 ━━━━━━━━━━━ (SL line, red dotted)
```

---

## Production Checklist

- [ ] GHOST_Dashboard_Visual.pine added to chart
- [ ] DerivEAPro v10 EA attached to chart
- [ ] InpUseGHOST = TRUE configured
- [ ] gom_signal.json exists with GHOST fields
- [ ] gom_verdict_poller.py running (for live updates)
- [ ] Dashboard visible with GHOST data
- [ ] Expert log shows "[GHOST]" messages
- [ ] Entry lines visible on chart
- [ ] First 5 trades logged with GHOST confluence

---

## Files Required

| File | Location | Purpose |
|------|----------|---------|
| GHOST_Dashboard_Visual.pine | D:\Dev\TradBOT\mt5\ | Visual Pine indicator |
| DerivEAPro_v10.ex5 | MT5 Experts\ | EA binary |
| gom_signal.json | D:\Dev\TradBOT\data\ | GHOST signal cache |
| GOMVerdict.mqh | MT5 Include\ | GHOST parser |

---

## Next Steps

1. ✅ Add Pine indicator to chart (Visual)
2. ✅ Attach EA to chart (Logic)
3. ✅ Monitor first 5 trades
4. ✅ Backtest GHOST ON vs OFF
5. ✅ Scale to production

---

**Status:** Visual indicators ready for deployment  
**Date:** 2026-06-06 17:15 UTC  
**Version:** v10.00 GHOST OrderFlow Integration
