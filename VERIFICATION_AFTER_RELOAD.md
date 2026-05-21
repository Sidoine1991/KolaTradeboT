# ✅ VERIFICATION CHECKLIST AFTER RELOAD

**After you compile (F7) and reload the EA in MT5, use this checklist to verify all changes:**

---

## STEP 1: Verify Boom/Crash Protection ✅

### On Boom 1000 Index:
1. Run the EA on a Boom chart
2. **Check Journal for**:
   ```
   ✅ "SMC_Universal initialized"
   ✅ "Boom symbol detected - BUY only"
   ✅ All BUY signals allowed in logs
   ```
3. **Force test SELL signal** (should block):
   - Should see: `❌ OTE Entry SELL BLOCKED on Boom 1000 Index`
   - Should see: `❌ Auto-Entry BLOCKED on Boom 1000 Index`

### On Crash 1000 Index:
1. Switch EA to a Crash chart
2. **Check Journal for**:
   ```
   ✅ "SMC_Universal initialized"
   ✅ "Crash symbol detected - SELL only"
   ✅ All SELL signals allowed in logs
   ```
3. **Force test BUY signal** (should block):
   - Should see: `❌ OTE Entry BUY BLOCKED on Crash 1000 Index`
   - Should see: `❌ Auto-Entry BLOCKED on Crash 1000 Index`

---

## STEP 2: Verify Chart Appearance ✅

### Check These Elements:

#### ❌ Should NOT See:
- [ ] No green/red FVG rectangles
- [ ] No horizontal dotted lines (EMA M1/M5/H1)
- [ ] No horizontal support/resistance lines
- [ ] No horizontal SuperTrend lines
- [ ] No horizontal swing high/low lines
- [ ] No cluttered "test data" at top-left

#### ✅ Should See:
- [ ] ML Metrics text at top-left: "🤖 ML [Symbol]: ..."
- [ ] 7 colored cells at bottom: M1|M4|M5|H1|D1|IA|VERDICT
- [ ] Entry level TEXT labels: "M5 Entry: 1234.56 (BUY)"
- [ ] Blue rectangles for OTE zones
- [ ] Yellow zones for Fibonacci levels
- [ ] Clean, uncluttered chart

---

## STEP 3: Verify Entry Level Labels ✅

### Entry Level Display Format:

Look for text labels like these on your chart:

```
M1 Entry: 1234.42 (BUY)     ← Green text for bullish
M5 Entry: 1234.56 (SELL)    ← Red text for bearish
H1 Entry: 1235.10 (BUY)     ← Green/Red per direction
```

**Check**:
- [ ] All three timeframes (M1, M5, H1) show entry prices
- [ ] Direction (BUY/SELL) displayed correctly
- [ ] Prices update every tick
- [ ] No horizontal lines, only text

---

## STEP 4: Monitor OTE + FIBO Entries ✅

### When OTE Setup Detected:

**Look in Journal for**:
```
✅ "OB Confirmée détectée"          → Order Block found
✅ "OTE Setup BUY at 1234.56"       → Entry level calculated
✅ "SL: 1230.10, TP1: 1240.20"      → Stops calculated
✅ "LIMIT BUY placed @ 1234.56"     → Order placed
```

### Watch Chart for:
- [ ] Blue/Red rectangle appears = OTE zone
- [ ] Yellow zones appear = Fibonacci 0.618, 0.786
- [ ] Entry text label updates
- [ ] LIMIT order appears in "Trades" tab

---

## STEP 5: Test Auto-Entry Trigger ✅

### Wait for GOOD or PERFECT Verdict:

**When verdict becomes GOOD/PERFECT**:
1. Check Dashboard (bottom) - verdict cell should show "GOOD" or "PERFECT"
2. **Check for**:
   ```
   ✅ Push notification sent to phone
   ✅ Journal shows: "Auto-Entry triggered on GOOD verdict"
   ✅ Order placed automatically
   ✅ Position shows in "Positions" tab
   ```

### If AI is aligned (BUY/SELL, not HOLD):
- [ ] Entry happens immediately
- [ ] Push notification sent
- [ ] SL/TP placed automatically
- [ ] Position opened with correct direction

### If AI is HOLD:
- [ ] Check if verdict is strong enough to override
- [ ] Entry may still happen if PERFECT + strong confluence
- [ ] Check Journal for decision logic

---

## STEP 6: Performance Check ✅

### System Resource Usage:

**Compare to before reload**:
- [ ] Chart rendering smoother (fewer lines = less GPU)
- [ ] EA tick processing same or faster
- [ ] No lag when drawing (no excessive lines)
- [ ] Dashboard updates smoothly

---

## STEP 7: Journal Message Reference ✅

**Normal operational messages** (expected):
```
✅ "SMC_Universal initialized"
✅ "Dashboard Updated"
✅ "Nettoyage périodique des objets dashboard effectué"
✅ "First tick processed"
```

**Protection messages** (when triggered):
```
❌ "OTE Entry BUY BLOCKED on Crash 1000 Index"
❌ "OTE Entry SELL BLOCKED on Boom 1000 Index"
❌ "Auto-Entry BLOCKED on [Symbol]"
```

**Entry messages** (when OTE setup detected):
```
✅ "OB Confirmée détectée"
✅ "OTE Setup [BUY/SELL] at [price]"
✅ "LIMIT [BUY/SELL] placed @ [price]"
```

---

## STEP 8: If Something is Wrong ✅

### Issue: Horizontal lines still visible

**Solution**:
1. Check: EA fully reloaded? (Remove and Add again)
2. F7 compile again in MetaEditor
3. Restart MT5 completely
4. Check: ObjectFind("SMC_Limit_") returns -1 (deleted)

### Issue: Boom/Crash protection not working

**Debug**:
1. Check Journal for "BLOCKED" messages
2. Verify function IsDirectionAllowedForBoomCrash() called
3. Check: Is it really a Boom/Crash symbol?
4. Test with Boom 1000 Index or Crash 1000 Index

### Issue: Entry levels not showing as text

**Debug**:
1. Check Dashboard cells display (proves EA is running)
2. Verify OBJ_TEXT objects created (not OBJ_HLINE)
3. Check: Are Fibonacci levels visible? (yellow zones)
4. Look for label names: "SMC_EntryLevel_M1_Label"

### Issue: OTE entries not triggering

**Debug**:
1. Check: Is verdict GOOD or PERFECT?
2. Check: Is AI aligned (not HOLD)?
3. Check: Is IA confidence > 50%?
4. Check: Is spread < 1500 points?
5. Check: UTC trading window open?
6. Check: No existing position on symbol?

---

## FINAL VERIFICATION SUMMARY

**All checks passed?**

✅ Boom symbol: Only BUY allowed (SELL blocked)
✅ Crash symbol: Only SELL allowed (BUY blocked)
✅ Chart: No SMC lines, only text labels
✅ Entry levels: Displayed as text (M1/M5/H1)
✅ OTE zones: Blue rectangles visible
✅ Fibonacci: Yellow zones visible
✅ Dashboard: 7 cells at bottom
✅ ML Metrics: Text at top-left
✅ Performance: Chart renders smoothly

**If YES**: ✅ Everything working perfectly! Ready to trade
**If NO**: Check the "If Something is Wrong" section above

---

## Quick Command Reference

**In MT5 if you need to reload again**:
1. Right-click chart → Expert Advisors → Remove (wait 5 sec)
2. Right-click chart → Expert Advisors → SMC_Universal (click OK)

**In MetaEditor to recompile**:
1. Ctrl+Shift+E (open MetaEditor)
2. Ctrl+O (open SMC_Universal.mq5)
3. F7 (compile)
4. Wait for "0 errors, 0 warnings"

---

**Status**: Ready for verification 🚀

Test each step and report any issues!
