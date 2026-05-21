# 🔧 Compile and Reload Steps

**Date**: 2026-05-17  
**EA File**: SMC_Universal.mq5  
**Expected Changes**: 
- ✅ FVG drawings removed
- ✅ Dashboard decluttered  
- ✅ Chart shows only: OTE, FIBO, Support/Resistance, Entry Levels
- ✅ All Supabase references → AWS RDS
- ✅ Automatic expired object cleanup every 10 minutes

---

## STEP 1: Compile in MetaEditor

### Option A: Using Keyboard Shortcut
1. Open MetaEditor (Ctrl+Shift+E in MT5)
2. File → Open → `D:\Dev\TradBOT\SMC_Universal.mq5`
3. Press **F7** to compile
4. Wait 10-15 seconds

### Option B: Using Menu
1. Open MetaEditor
2. File → Open → `D:\Dev\TradBOT\SMC_Universal.mq5`
3. Compile → Compile
4. Wait 10-15 seconds

### Expected Result:
```
✅ 0 errors, 0 warnings
✅ Compilation successful
✅ Output: SMC_Universal.ex5
```

---

## STEP 2: Stop Old Robot (Remove EA)

### In MetaTrader 5:
1. Locate the chart with SMC_Universal running
2. **Right-click on the chart**
3. Select: **Expert Advisors** → **Remove**
4. Wait **5 seconds** for clean shutdown

### Expected Result:
```
Journal shows:
✅ "SMC_Universal removed"
```

---

## STEP 3: Load New Robot (Add EA)

### In MetaTrader 5:
1. **Right-click on the chart again**
2. Select: **Expert Advisors** → **SMC_Universal**
3. Dialog appears: Click **OK**
4. Wait **3-5 seconds** for initialization

### Expected Result:
```
Journal shows:
✅ "SMC_Universal initialized"
✅ "Version: X.X.X"
✅ "Using Primary Server: local (127.0.0.1:8000)"
```

---

## STEP 4: Verify Chart Changes

### Look for ONLY These Drawings:
✅ **Green line (top-left)**: "🤖 ML [Symbol]: ..." - ML metrics  
✅ **Colored cells (bottom)**: M1|M5|H1|IA|VERDICT dashboard  
✅ **Entry level lines**: Horizontal lines per timeframe  
✅ **S/R lines**: Support (green dot) / Resistance (red dot)  
✅ **Yellow zones**: Fibonacci levels  
✅ **Blue zones**: OTE/Imbalance areas  
✅ **Swing markers**: High/Low points  

### NOT See These:
❌ Green/Red rectangles = FVG zones (should be gone)  
❌ Test data at top-left = Decluttered  
❌ Multiple overlapping zones = Cleaned up  

---

## STEP 5: Monitor Journal

After reload, check Journal tab for:

### Required Messages:
```
[20:30:45] ✅ SMC_Universal initialized on Boom 1000 Index, M1
[20:30:45] ✅ AI Server: http://127.0.0.1:8000
[20:30:45] ✅ Channel Valid: OK
[20:30:47] ✅ Dashboard Updated
[20:30:55] ✅ First tick processed
```

### Optional Messages (Every 10 minutes):
```
[20:40:45] ✅ Nettoyage périodique des objets dashboard effectué
[20:40:45] 🧹 Nettoyage objets expirés - X objets supprimés
```

---

## STEP 6: Test Trading (Optional)

### Verify Auto-Entry Works:
1. Wait for **GOOD** or **PERFECT** verdict
2. AI signal should align (BUY or SELL, not HOLD)
3. Check for:
   - ✅ Push notification sent
   - ✅ Order placed with SL/TP
   - ✅ Position opened correctly

### Check Dashboard:
1. Verify all 7 cells update (M1, M5, H1, IA, VERDICT)
2. Colors change based on market direction
3. IA confidence and verdict confidence visible

---

## Troubleshooting

### Issue: "0 errors but still shows old FVG"
**Solution**: 
1. Old .ex5 file cached in memory
2. Fully restart MT5 (not just remove/add EA)
3. Close MT5 completely, reopen

### Issue: "Compilation failed with errors"
**Solution**:
1. Check: `Line XXX: [error message]`
2. May need to rebuild dependencies
3. Delete any Include/*.mqh files and resync

### Issue: "Chart shows but no data updating"
**Solution**:
1. EA might not have initialized fully
2. Wait 30 seconds
3. Check Journal for error messages
4. Verify AI server is running (127.0.0.1:8000 ping)

---

## Final Checklist

After successful reload:

- [ ] Compilation: 0 errors, 0 warnings ✅
- [ ] EA removed cleanly ✅
- [ ] EA reloaded successfully ✅
- [ ] Journal shows initialization messages ✅
- [ ] Chart displays ML metrics at top-left ✅
- [ ] Bottom dashboard shows 7 cells ✅
- [ ] NO FVG rectangles visible ✅
- [ ] Entry levels visible per timeframe ✅
- [ ] Support/Resistance lines visible ✅
- [ ] Fibonacci levels visible ✅
- [ ] OTE zones visible ✅
- [ ] Auto-entry triggers on GOOD/PERFECT verdict ✅

---

## Time Required

| Step | Time |
|------|------|
| F7 Compile | 10-15 seconds |
| Remove EA | 5 seconds |
| Add EA | 3-5 seconds |
| Wait for init | 5 seconds |
| **Total** | **~30 seconds** |

---

## Important Notes

⚠️ **Do NOT**:
- ❌ Try to just recompile without removing/reloading
- ❌ Compile and immediately check chart (need reload)
- ❌ Edit EA while market is trading important setup

✅ **DO**:
- ✅ Compile during non-trading hours if possible
- ✅ Have AI server (127.0.0.1:8000) running
- ✅ Wait full 5 seconds after removing EA

---

**Ready to compile?** 🚀 Press **F7** in MetaEditor!
