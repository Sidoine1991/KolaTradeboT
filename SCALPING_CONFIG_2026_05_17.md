# 🎯 Configuration Scalping Agressif - May 17, 2026

**Status:** ✅ IMPLEMENTED  
**Mode:** Spike Capture + Scalping Tight  
**Symbols:** Boom/Crash, PAINX/GAINX  
**Strategy:** Close quickly after spike capture (50% gain = close position)

---

## 📊 Changed Parameters

### OLD Configuration (Swing Trading)
```
SL_ATRMult        = 2.5    // Stop Loss (x ATR)
TP_ATRMult        = 5.0    // Take Profit (x ATR) - TOO FAR
TrailingStop_ATRMult = 3.0
TrailingStartProfitDollars = 0.50
```

### NEW Configuration (Scalping)
```
SL_ATRMult        = 0.8    // Stop Loss (x ATR) - VERY TIGHT
TP_ATRMult        = 1.2    // Take Profit (x ATR) - CLOSE, SCALP
TrailingStop_ATRMult = 1.5 // Trailing tighter
TrailingStartProfitDollars = 0.10 // Start protecting at $0.10 gain
EnableSpikeScalping = true  // NEW: Spike capture mode
SpikeCloseProfitPct = 0.5   // NEW: Close at 50% of gain target
```

---

## 🚀 How It Works

### 1. Entry
- Get support/resistance levels (entry levels)
- Place BUY at GREEN level (support) or SELL at RED level (resistance)
- Entry with tight SL: `entry ± (ATR × 0.8)`
- Profit target: `entry ± (ATR × 1.2)`

### 2. Spike Capture
On Boom/Crash and PAINX/GAINX:
- Monitor position profit in real-time
- When profit reaches **50% of TP** → **CLOSE immediately**
- Don't wait for full TP
- Lock in spike gains fast

### 3. Risk/Reward Ratio
- OLD: 1:5 ratio (too long exposure)
- NEW: 1:1.5 ratio (quick in/out)

**Example:**
```
BID = 10045.00
ATR = 10 points

BUY Entry: 10045.00
SL: 10045.00 - (10 × 0.8) = 10037 (8 points risk)
TP: 10045.00 + (10 × 1.2) = 10057 (12 points gain)
Scalp Close: profit ≥ 50% × 12 = 6 points → EXIT

Result: Risk 8 points, Gain 6 points (tight, profitable)
```

---

## 🎯 Symbols Affected

✅ **Boom 300** - Scalping enabled
✅ **Crash 300** - Scalping enabled
✅ **Volatility 25** - Scalping enabled
✅ **PAINX** - Scalping enabled (when available)
✅ **GAINX** - Scalping enabled (when available)

Other symbols: Normal TP/SL rules still apply

---

## 📈 Trade Flow

```
1. AI Signal: BUY/SELL ✓
2. Trend Check: Aligned ✓
3. Entry: Place at level (GREEN/RED line) ✓
4. Monitor: Check profit every tick ✓
5. Spike Detected: Profit ≥ 50% of TP ✓
6. AUTO CLOSE: Position closed ✓
7. Result: Gain locked, move to next trade ✓
```

---

## 🔐 Safety Measures

### 1. Always Tight SL
- SL = ATR × 0.8 (not negotiable)
- Protects against false breakouts

### 2. Profit Lock
- Trailing stop still active
- Locks best price if spike continues

### 3. Position Rotation
- Auto-rotate to new symbol after close
- Avoid over-trading same pair

### 4. AI Hold Override
- If IA = HOLD, close all positions
- Clean slate for next signal

---

## 📋 Configuration Checklist

- [x] SL_ATRMult reduced to 0.8
- [x] TP_ATRMult reduced to 1.2
- [x] EnableSpikeScalping = true
- [x] SpikeCloseProfitPct = 0.5
- [x] ClosePositionsOnSpikeScalp() function added
- [x] Call added to OnTick()
- [x] TrailingStop tightened to 1.5
- [x] Trailing start reduced to $0.10

---

## 🧪 Testing Checklist

Before live deployment:
- [ ] Compile with 0 errors
- [ ] Attach to Boom 300 M1 chart
- [ ] Watch first spike capture
- [ ] Verify position closes at 50% gain
- [ ] Check position profit in terminal
- [ ] Verify no trailing stop conflicts
- [ ] Monitor 5-10 trades
- [ ] Check total P&L vs swing mode

---

## 💡 Expected Results

### Before (Swing Trading)
- Entry at level
- Wait for 5×ATR = distant target
- Takes 20-50 candles to close
- High exposure to reversals

### After (Spike Scalping)
- Entry at level
- Profit target very close (1.2×ATR)
- Close at 50% = fast exit
- Takes 5-15 candles to close
- Low exposure, quick profit lock

---

## ⚙️ Code Changes

**File:** SMC_Universal.mq5  
**Lines Added:** ~80 (new function + parameters)

### New Parameters (Line 2308)
```mql5
input double SL_ATRMult        = 0.8;    // Stop Loss (x ATR)
input double TP_ATRMult        = 1.2;    // Take Profit (x ATR)
input bool   EnableSpikeScalping = true;  // Spike scalping mode
input double SpikeCloseProfitPct = 0.5;   // Close at 50% of gain
```

### New Function (Line ~5880)
```mql5
void ClosePositionsOnSpikeScalp()
{
   // Monitor positions for spike capture
   // Close when profit >= 50% of TP target
   // Only on Boom/Crash and Volatility
}
```

### OnTick() Addition (Line ~6381)
```mql5
if(EnableSpikeScalping)
   ClosePositionsOnSpikeScalp();
```

---

## 🎊 Deployment

1. Compile EA
2. Backup current version
3. Deploy to MetaTrader
4. Attach to chart
5. Watch first trade
6. Monitor position closing automatically
7. Verify P&L improvement

---

**Version:** 1.03 (Spike Scalping)  
**Status:** ✅ READY FOR TESTING  
**Date:** 2026-05-17  
**Next:** Live testing on Boom/Crash M1
