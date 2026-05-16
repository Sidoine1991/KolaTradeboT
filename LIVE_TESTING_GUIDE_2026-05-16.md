# Live Testing Guide - All 4 Options
**Date:** 2026-05-16  
**Status:** Ready to test  
**Commit:** 9469aa6

---

## Quick Summary

All 4 test configurations have been applied to SMC_Universal.mq5:

| Option | Change | Expected Effect |
|--------|--------|-----------------|
| 1 | Lower AI confidence | More trades execute |
| 2 | Disable AI direction check | Trades despite IA disagreement |
| 3 | Ignore PropiceTop filter | Trade any symbol |
| 4 | All above combined | Maximum trade volume |

---

## How to Run Each Test

### Test Option 1: Lower AI Confidence (SAFEST)

**Already Applied:** ✅ Lines 8933-8935 updated

**Current Settings:**
```
MinAIConfidencePercent = 45.0% (was 62%)
MinAIConfidencePercentBoomCrash = 40.0% (was 58%)
MinAIConfidencePercentVolatility = 35.0% (was 55%)
```

**To Test:**
1. Compile SMC_Universal.mq5 in MetaEditor
2. Attach to Deriv chart
3. Watch logs for trades at confidence 40-45%
4. Monitor: Do these trades make money?

**Expected:** 
- Trades execute when confidence > 35-45%
- More frequent trading
- Test if confidence threshold matters

**Duration:** 1 hour

---

### Test Option 2: Disable AI Direction Check (MEDIUM RISK)

**Already Applied:** ✅ Line 26926-26931 disabled

**What It Does:**
```
BEFORE: Blocks BUY if AI says SELL
AFTER:  Allows BUY even if AI says SELL
```

**To Test:**
1. Compile SMC_Universal.mq5
2. Attach to chart
3. Watch logs for trades where AI direction differs from technical
4. Monitor: Do conflicting signals still win?

**Expected:**
- Trades execute on technical signals ONLY
- IA direction ignored
- More trades when technical signal fires

**Duration:** 1 hour

**Caution:** This tests if AI direction is even useful

---

### Test Option 3: Ignore PropiceTop Filter (LOW RISK)

**Already Applied:** ✅ Line 8915 changed to `false`

**What It Does:**
```
BEFORE: Only trade top propice symbols
AFTER:  Trade any symbol (propice ranking ignored)
```

**To Test:**
1. Compile SMC_Universal.mq5
2. Attach to chart
3. Watch logs for trades on non-top symbols
4. Monitor: Does PropiceTop ranking matter?

**Expected:**
- Trades on any symbol, not just top ranked
- More frequent trades
- Test value of PropiceTop filtering

**Duration:** 1 hour

---

### Test Option 4: Full Debug Mode (ALL THREE) (AGGRESSIVE)

**Already Applied:** ✅ All three above

**This Combines:**
- Lower confidence (35-45%)
- Ignore AI direction
- Ignore PropiceTop ranking

**To Test:**
1. Compile SMC_Universal.mq5
2. Attach to chart
3. Watch logs for HIGH volume of trades
4. Monitor: Equity curve carefully

**Expected:**
- 3-4x more trades than current
- Many trades from technical signals
- Can determine if filters are necessary

**Duration:** 1 hour (watch equity closely)

**Caution:** Most aggressive - may generate many losing trades

---

## Testing Workflow

### Step 1: Preparation
```bash
# Compile the code
1. Open MetaEditor
2. File → Open → D:\Dev\TradBOT\SMC_Universal.mq5
3. Compile (Ctrl+Shift+F9)
4. Expected: 0 errors, 0 warnings
```

### Step 2: Choose Test
- **Conservative:** Start with Option 1 only
- **Moderate:** Try Option 1 → Option 2 → Option 3 sequentially
- **Aggressive:** Test Option 4 directly

### Step 3: Deploy
```
1. Open Deriv MT5 Terminal
2. Attach SMC_Universal.mq5 to chart
3. Set inputs (if customizing)
4. Click OK
```

### Step 4: Monitor
```
Terminal → Expert tab (F7)
Watch logs for:
- Trade executions
- Confidence levels
- Direction conflicts
- P&L
```

### Step 5: Measure Results (After 1 Hour)
- Count trades
- Calculate win rate %
- Check profit/loss
- Note equity drawdown

### Step 6: Revert If Needed
```bash
git checkout SMC_Universal.mq5
# Recompiles with original settings
```

---

## What to Watch In Logs

### Looking for Confidence Changes
```
"?? TRADE BLOQUÉ - Confiance IA insuffisante sur Step Index | Zone: Premium | 51.1% < 75.0%"
```
With Option 1, this should disappear (51.1% > 45.0% now)

### Looking for Direction Override
```
"🚫 BOOM+IA - BUY refusé sur Boom 900 Index | IA=SELL"
```
With Option 2, this should disappear (check ignored)

### Looking for PropiceTop Impact
```
"⚠️ PropiceTop - Réponse vide ou invalide"
```
With Option 3, trades should execute anyway

---

## Measurements to Capture

For each test, record:

| Metric | Option 1 | Option 2 | Option 3 | Option 4 |
|--------|----------|----------|----------|----------|
| Trades executed | ? | ? | ? | ? |
| Win rate % | ? | ? | ? | ? |
| Profit/Loss $ | ? | ? | ? | ? |
| Avg profit per trade | ? | ? | ? | ? |
| Max drawdown | ? | ? | ? | ? |
| Trades blocked | ? | ? | ? | ? |

---

## Interpretation Guide

### If Option 1 Works (Low Confidence = Profitable)
✅ Lower confidence threshold is OK  
→ Can reduce MinAIConfidencePercent further  
→ Safe to deploy

### If Option 1 Fails (Low Confidence = Losses)
❌ Confidence threshold is important  
→ Revert to higher threshold  
→ Improve AI model instead

### If Option 2 Works (AI Direction Irrelevant)
✅ Can remove AI direction check  
→ Technical signals sufficient  
→ Simplify logic

### If Option 2 Fails (Loses money without AI guidance)
❌ AI direction is critical  
→ Keep direction check  
→ Focus on AI model quality

### If Option 3 Works (PropiceTop Irrelevant)
✅ Can trade any symbol  
→ Remove PropiceTop filtering  
→ Simplify logic

### If Option 3 Fails (Performance drops)
❌ PropiceTop ranking is important  
→ Keep PropiceTop filtering  
→ Ensure PropiceTop endpoint is reliable

### If Option 4 Works (All Combined = Profitable)
✅ All filters may be unnecessary  
→ System is self-protective  
→ Deploy with full debug settings

### If Option 4 Fails (Big losses)
❌ Filters are necessary  
→ Test each individually (Options 1-3)  
→ Find which filters are critical

---

## Risk Management

**Starting Account:** $20 USD  
**Max Risk Per Trade:** $0.20  
**Position Size:** Conservative  

**Safety Limits:**
- Stop loss if drawdown exceeds $5 (25% of account)
- Stop if win rate drops below 40%
- Stop if any single loss exceeds $2

---

## Success Criteria

**Test is SUCCESSFUL if:**
- Trades execute as expected
- Win rate ≥ 50%
- Profit per trade > 0
- No catastrophic drawdown

**Test is FAILED if:**
- Trades don't execute
- Win rate < 40%
- Big losses on first trades
- Drawdown exceeds $5

---

## Next Steps After Testing

### If Tests Reveal Issues:
1. Document findings
2. Identify which filter is critical
3. Fix the root cause (e.g., improve AI model)
4. Re-test

### If Tests Are Successful:
1. Document optimal settings
2. Commit final configuration
3. Deploy to production
4. Monitor live performance

---

## Revert Instructions

If test goes wrong:

```bash
# Quick revert to previous version
git checkout HEAD~1 SMC_Universal.mq5

# Full revert to pre-test state
git log --oneline | grep "test: apply all 4"
git revert <commit-hash>

# Or manually restore
sed -i 's/45.0/62.0/g' SMC_Universal.mq5  # Restore confidence
sed -i 's/if(false)/if(true)/g' SMC_Universal.mq5  # Restore direction check
```

---

## Documentation

All test configurations documented in:
- `TEST_CONFIG_OPTION1.txt`
- `TEST_CONFIG_OPTION2.txt`
- `TEST_CONFIG_OPTION3.txt`
- `TEST_CONFIG_OPTION4_FULL_DEBUG.txt`

---

**Status:** 🟢 READY TO TEST  
**Risk Level:** MEDIUM (Conservative position sizing)  
**Expected Duration:** 1-4 hours (1 hour per test)  
**Measurement:** Logs will show trade outcomes in real-time
