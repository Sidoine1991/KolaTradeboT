# 🎯 GOM VERDICT CALCULATION LOGIC — PURE PINE SCRIPT

## CORE PRINCIPLE

The GOM verdict is calculated using **ONLY TWO COMPONENTS**:

```
1. Gap = |score_buy - score_sell|  (distance between signals)
2. Coherence = filter_ratio >= 0.40 OR gap >= 4.5  (indicator alignment)
```

Everything else (RSI, MACD, VWAP, etc.) contributes to the **scores**, not the verdict classification.

---

## THE FOUR SACRED THRESHOLDS

| Gap Range | Verdict Type | Confidence | Coherence Required? |
|-----------|--------------|------------|-------------------|
| gap < 1.2 | **WAIT** | Insufficient | N/A |
| 1.2 ≤ gap < 2.5 | **BUY / SELL** | Medium | YES (coherence_ok=True) |
| 2.5 ≤ gap < 4.0 | **GOOD BUY / GOOD SELL** | High | YES (coherence_ok=True) |
| gap ≥ 4.0 | **PERFECT BUY / PERFECT SELL** | Maximum | YES (coherence_ok=True) |

---

## DECISION TREE

```
┌─ Calculate gap = |score_buy - score_sell|
├─ Calculate coherence_ok = (filter_ratio >= 0.40) OR (gap >= 4.5)
│
├─ IF gap < 1.2
│  └─ Verdict = WAIT  (no conviction)
│
├─ IF 1.2 ≤ gap < 2.5
│  ├─ IF coherence_ok
│  │  ├─ IF score_buy > score_sell  → BUY (vn=1)
│  │  └─ ELSE  → SELL (vn=-1)
│  └─ ELSE  → WAIT  (not confirmed)
│
├─ IF 2.5 ≤ gap < 4.0
│  ├─ IF coherence_ok
│  │  ├─ IF score_buy > score_sell  → GOOD BUY (vn=2)
│  │  └─ ELSE  → GOOD SELL (vn=-2)
│  └─ ELSE  → WAIT  (not confirmed)
│
└─ IF gap ≥ 4.0
   ├─ IF coherence_ok
   │  ├─ IF score_buy > score_sell  → PERFECT BUY (vn=3)
   │  └─ ELSE  → PERFECT SELL (vn=-3)
   └─ ELSE  → WAIT  (contradiction detected)
```

---

## EXAMPLES

### Example 1: PERFECT BUY ✅
```
score_buy  = 12.3
score_sell = 7.8
gap = 4.5
filter_ratio = 0.60 (60%)
coherence_ok = True

Result: gap >= 4.0 AND coherence_ok → PERFECT BUY (vn=3)
Confidence: 🟢🟢🟢 Maximum
```

### Example 2: GOOD SELL ✅
```
score_buy  = 7.1
score_sell = 10.2
gap = 3.1
filter_ratio = 0.50 (50%)
coherence_ok = True

Result: gap >= 2.5 AND coherence_ok → GOOD SELL (vn=-2)
Confidence: 🟢🟢 High
```

### Example 3: BUY (Regular) ✅
```
score_buy  = 8.5
score_sell = 7.0
gap = 1.5
filter_ratio = 0.45 (45%)
coherence_ok = True

Result: gap >= 1.2 AND coherence_ok → BUY (vn=1)
Confidence: 🟢 Medium
```

### Example 4: WAIT (No Conviction) ❌
```
score_buy  = 8.0
score_sell = 7.5
gap = 0.5
filter_ratio = 0.50 (50%)

Result: gap < 1.2 → WAIT
Reason: Market undecided
```

### Example 5: WAIT (Contradictory) ⚠️
```
score_buy  = 10.0
score_sell = 7.0
gap = 3.0
filter_ratio = 0.20 (20%)
coherence_ok = False

Result: gap in valid range BUT coherence_ok=False → WAIT
Reason: Indicators contradict the score gap
```

---

## VERDICT_NUM ENCODING

```
vn =  3  →  PERFECT BUY    (highest confidence buy)
vn =  2  →  GOOD BUY       (high confidence buy)
vn =  1  →  BUY            (medium confidence buy)
vn =  0  →  WAIT           (no signal / contradiction)
vn = -1  →  SELL           (medium confidence sell)
vn = -2  →  GOOD SELL      (high confidence sell)
vn = -3  →  PERFECT SELL   (highest confidence sell)
```

---

## COHERENCE_OK LOGIC

Coherence is checked to ensure **indicator alignment**.

```python
coherence_ok = (filter_ratio >= 0.40) OR (gap >= 4.5)
```

**What is filter_ratio?**

Each of 6 filters votes:
- SuperTrend direction
- VWAP proximity
- MACD alignment
- RSI overbought/oversold
- Keltner Channel position
- Donchian Channel breakout

`filter_ratio = passes / 6` (0.0 to 1.0)

- If ≥ 40%: Indicators **mostly agree** → coherence_ok = True
- If < 40% but gap ≥ 4.5: Gap is **so strong** it overrides coherence → coherence_ok = True
- Otherwise: Contradictory signals → Wait for better alignment

---

## IMPLEMENTATION IN ai_server.py

The verdict is recalculated EVERY TIME `/gom-verdict` is called:

```python
def calculate_gom_verdict(score_buy, score_sell, filter_ratio):
    gap = abs(score_buy - score_sell)
    coherence_ok = (filter_ratio >= 0.40) or (gap >= 4.5)

    if gap < 1.2:
        return 0, "WAIT"
    elif gap < 2.5:
        if coherence_ok:
            return (1 if score_buy > score_sell else -1), ("BUY" if score_buy > score_sell else "SELL")
        return 0, "WAIT"
    elif gap < 4.0:
        if coherence_ok:
            return (2 if score_buy > score_sell else -2), ("GOOD BUY" if score_buy > score_sell else "GOOD SELL")
        return 0, "WAIT"
    else:  # gap >= 4.0
        if coherence_ok:
            return (3 if score_buy > score_sell else -3), ("PERFECT BUY" if score_buy > score_sell else "PERFECT SELL")
        return 0, "WAIT"
```

---

## CURRENT STATUS (2026-06-10 16:40:55 UTC)

✅ **5 Active Signals:**
- 🟢 XAUUSD: PERFECT BUY (gap=5.87, coherence=60%)
- 🟢 Boom 1000: PERFECT BUY (gap=6.0, coherence=60%)
- 🔴 Crash 300: PERFECT SELL (gap=6.0, coherence=60%)
- 🔴 Crash 500: PERFECT SELL (gap=6.0, coherence=60%)
- 🔴 Crash 1000: GOOD SELL (gap=3.0, coherence=55%)

✅ **6 In WAIT:**
- All others: gap < 1.2 or contradictory signals

---

## KEY TAKEAWAY

**The GOM verdict is DETERMINISTIC.**

Given any score_buy, score_sell, and filter_ratio, the verdict ALWAYS follows this logic.
No randomness. No magic. Pure mathematics.

This makes it:
- ✅ Reproducible (same inputs → same output)
- ✅ Auditable (every step is visible)
- ✅ Stable (no drift over time)
- ✅ Automatable (can run 24/7 daemon)
