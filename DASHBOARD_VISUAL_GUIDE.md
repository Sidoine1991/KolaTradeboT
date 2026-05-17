# 📺 Dashboard Visual Guide - Complete Reference

**Date:** 2026-05-18  
**Version:** 1.07  

---

## 🎯 Dashboard Layout Map

```
┌──────────────────────────────────────────────────────────────┐
│                        CHART AREA                            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🤖 IA: BUY [72.5%]                    (Y=20)      │   │ GREEN
│  │ 💲 Price: 10045.23                    (Y=46)      │   │ WHITE
│  │ 📈 Trend: UPTREND                     (Y=72)      │   │ GREEN
│  │ 🔮 Prediction: UP [68%]               (Y=98)      │   │ GREEN
│  │   └─ Strong EMA↑ + RSI↑ | Conf=+2     (Y=124)     │   │ GRAY
│  │   EMA:75% | RSI:70% | ATR:80%        (Y=150)     │   │ GRAY
│  │                                                     │   │
│  │                                                     │   │
│  │ [ENTRY LEVELS - GREEN/RED DASHED LINES ON CHART]  │   │
│  │                                                     │   │
│  │                                                     │   │
│  │ 📊 ML: 70.8% | random_forest         (Y=650)      │   │ BLUE
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 📍 Position Reference

### Vertical Position (Y-axis)
```
Y=20   → 🤖 AI Signal (top of dashboard)
Y=46   → 💲 Current Price
Y=72   → 📈 Trend Direction
Y=98   → 🔮 Price Prediction (NEW)
Y=124  → └─ Reasoning (NEW)
Y=150  → Signal Breakdown EMA|RSI|ATR (NEW)
Y=650  → 📊 ML Metrics (bottom of dashboard)
```

### Horizontal Position (X-axis)
```
X=10   → All dashboard text starts 10 pixels from left edge
X=N/A  → Entry level lines drawn on chart (not dashboard)
```

---

## 🎨 Color Reference

### Text Colors
```
🤖 AI Signal:
   ├─ clrLimeGreen (0, 255, 0)     when BUY
   ├─ clrRed (255, 0, 0)           when SELL
   └─ clrYellow (255, 255, 0)      when HOLD

💲 Price:
   └─ clrWhite (255, 255, 255)     (neutral)

📈 Trend:
   ├─ clrLimeGreen                  when UPTREND
   ├─ clrRed                        when DOWNTREND
   └─ clrYellow                     when SIDEWAYS

🔮 Prediction:
   ├─ clrLimeGreen                  when UP
   ├─ clrRed                        when DOWN
   └─ clrYellow                     when CONSOLIDATE

Reasoning:
   └─ clrDarkGray (64, 64, 64)      (dark gray)

Signal Breakdown:
   └─ C'150,150,150'                (medium gray)

📊 ML Metrics:
   └─ clrSkyBlue (135, 206, 250)    (light blue)
```

### Entry Level Lines (on chart)
```
BUY Level:
   ├─ Color: clrLimeGreen (GREEN)
   ├─ Style: STYLE_DASH (dashed line)
   ├─ Width: 2 pixels
   └─ Type: Horizontal line (OBJ_HLINE)

SELL Level:
   ├─ Color: clrRed (RED)
   ├─ Style: STYLE_DASH (dashed line)
   ├─ Width: 2 pixels
   └─ Type: Horizontal line (OBJ_HLINE)
```

---

## 📝 Font Settings

### Dashboard Text
```
AI Signal line:     Font size 9
Price line:         Font size 9
Trend line:         Font size 9
Prediction line:    Font size 9 (BOLD style)
Reasoning line:     Font size 8 (smaller - detail)
Breakdown line:     Font size 8 (smaller - detail)
ML Metrics line:    Font size 9
```

### Font Name
```
All text: Default font (no specific font specified in code)
Uses system default chart font
```

---

## 🔄 Update Frequency

### Real-time Updates (Every Tick)
```
🤖 AI Signal          → Updates if new AI decision
💲 Price              → Updates every tick (BID price)
📈 Trend              → Updates every tick (EMA recalculated)
🔮 Prediction         → Updates every tick (full re-analysis)
  └─ Reasoning        → Updates every tick (new signals)
  └─ Breakdown        → Updates every tick (new scores)
📊 ML Metrics         → Updates periodically or when model changes
```

---

## 📊 Example Dashboard States

### State 1: BULLISH ALIGNMENT
```
Colors: GREEN, GREEN, GREEN, GREEN
Position: All elements visible, aligned perfectly

🤖 IA: BUY [72.5%]                    GREEN
💲 Price: 10045.23                    WHITE
📈 Trend: UPTREND                     GREEN ✓
🔮 Prediction: UP [78%]               GREEN ✓
  └─ Strong EMA↑ + RSI↑ | Conf=+2
  EMA:75% | RSI:70% | ATR:80%
📊 ML: 70.8% | random_forest          BLUE

Interpretation: STRONG BUY SIGNAL - All systems aligned
Entry: ✅ LIMIT ORDER PLACED
```

### State 2: BEARISH ALIGNMENT
```
Colors: RED, RED, RED, RED
Position: All elements visible, aligned perfectly

🤖 IA: SELL [68%]                     RED
💲 Price: 10048.95                    WHITE
📈 Trend: DOWNTREND                   RED ✓
🔮 Prediction: DOWN [75%]             RED ✓
  └─ Strong EMA↓ + RSI↓ | Conf=-2
  EMA:25% | RSI:30% | ATR:85%
📊 ML: 72.1% | gradient_boost         BLUE

Interpretation: STRONG SELL SIGNAL - All systems aligned
Entry: ✅ LIMIT ORDER PLACED
```

### State 3: NEUTRAL/CONSOLIDATION
```
Colors: YELLOW, WHITE, YELLOW, YELLOW
Position: All elements visible, mixed signals

🤖 IA: HOLD [55%]                     YELLOW
💲 Price: 10046.50                    WHITE
📈 Trend: SIDEWAYS                    YELLOW
🔮 Prediction: CONSOLIDATE [52%]      YELLOW
  └─ Mixed EMA/RSI | Low confluence
  EMA:50% | RSI:50% | ATR:40%
📊 ML: 68.3% | neural_net             BLUE

Interpretation: NO CLEAR SIGNAL - Wait for alignment
Entry: ❌ ENTRY BLOCKED (low confidence)
```

### State 4: MISALIGNED SIGNALS
```
Colors: GREEN, WHITE, RED, RED (mismatch!)
Position: Conflicting colors highlight the issue

🤖 IA: BUY [65%]                      GREEN
💲 Price: 10045.00                    WHITE
📈 Trend: DOWNTREND                   RED ✗ CONFLICT!
🔮 Prediction: DOWN [62%]             RED ✗ CONFLICT!
  └─ Strong EMA↓ + RSI↓ | Conf=-2
  EMA:25% | RSI:30% | ATR:82%
📊 ML: 71.5% | random_forest          BLUE

Interpretation: CONFLICTING SIGNALS - Trend against trade
Entry: ❌ ENTRY BLOCKED (trend protection)
```

---

## 🎯 Reading the Dashboard

### Step 1: Scan the Colors
```
All GREEN?       → STRONG BUY SIGNAL
All RED?         → STRONG SELL SIGNAL
Mixed colors?    → Weak signal or consolidation
```

### Step 2: Check the Prediction Probability
```
Prediction > 70%?     → High confidence
Prediction 50-70%?    → Medium confidence
Prediction < 50%?     → Low confidence (may be blocked)
```

### Step 3: Read the Reasoning Line
```
Example: "Strong EMA↑ + RSI↑ | Conf=+2"

Strong?        → Shows alignment quality
EMA↑ or ↓?     → Which direction EMA points
RSI↑ or ↓?     → Which direction RSI points
Conf=±N?       → How many signals aligned
```

### Step 4: Analyze the Breakdown Scores
```
Example: "EMA:75% | RSI:70% | ATR:80%"

EMA:75%  → Bullish (high score)
RSI:70%  → Bullish (high score)
ATR:80%  → High volatility (good for trends)

→ ALL HIGH = Strong setup
→ Mixed = Weak setup
```

---

## 📱 Mobile/Tablet View

If using mobile terminal (MT5 on mobile device):

```
Same dashboard, adapted for smaller screen:
- Text may be smaller
- Y-positions scaled to window size
- Colors remain the same
- All 7 lines should still be visible
- May need to scroll to see ML metrics line
```

---

## 🖥️ Desktop View

Standard 1920×1080 or higher:

```
All dashboard elements visible:
✓ AI Signal at Y=20
✓ Price at Y=46
✓ Trend at Y=72
✓ Prediction at Y=98
✓ Reasoning at Y=124
✓ Breakdown at Y=150
✓ ML Metrics at Y=650

No overlapping text
Clear color differentiation
Easy to read and analyze
```

---

## ⚙️ Customization Notes

### Default Positioning
```
Current: X=10 (left edge), various Y positions
Could be adjusted to:
- X=50 for right margin
- Y adjusted for different spacing
- But DO NOT change during live trading!
```

### Font Size Options
```
Current: 9 for main, 8 for details
Could be adjusted to:
- Larger: 10-11 for visibility on small monitors
- Smaller: 7-8 for more density
- But consistency is important!
```

### Color Customization
```
Current: Standard MQL5 colors
Could be adjusted to:
- Hex colors: C'R,G,B' format
- But GREEN/RED/YELLOW pattern should stay
```

---

## 🔍 Troubleshooting Visual Issues

### Issue: Text Overlapping
```
Solution: Check Y-positions in code
All should increment by lineHeight (26) + gaps
If Y positions collide, spacing is wrong
```

### Issue: Colors Not Showing
```
Solution: Chart background color
If dashboard background is same as text, add OBJPROP_BACK
Check: ObjectSetInteger(chartID, label, OBJPROP_BACK, false)
```

### Issue: Dashboard Not Updating
```
Solution: Check if DrawEnhancedDashboard() is called
Should be called every tick from OnTick()
Check: No compilation errors in function
```

### Issue: Some Lines Missing
```
Solution: Check Y-positions
If Y > window height, line won't be visible
Example: Y=650 for ML metrics assumes tall chart window
Reduce if needed for smaller windows
```

---

## 📊 Dashboard Statistics

```
Total Lines Displayed: 7
Total Information Items: 13
Update Frequency: Every tick
Colors Used: 7 distinct colors
Font Sizes: 2 different sizes (9 and 8)
Horizontal Spacing: 10 pixels from left
Vertical Spacing: 26 pixels per line (average)
Overlap Risk: None (positions carefully calculated)
```

---

**Version:** 1.07  
**Status:** ✅ COMPLETE  
**Last Updated:** 2026-05-18
