# Integration Guide: Dashboard into SMC_Universal

## Option A: Use Standalone SMC_Dashboard_Pro (RECOMMENDED)
**Simplest approach - just attach both EAs to the same chart**

1. Attach SMC_Universal (main EA with trading logic)
2. Attach SMC_Dashboard_Pro (dashboard only, no trading logic)
3. Both run independently - dashboard updates every 1000ms

**Pros:**
- Clean separation of concerns
- Dashboard won't interfere with trading logic
- Easy to toggle dashboard on/off
- No compilation of main EA needed

**Cons:**
- Two EAs running (minimal CPU impact though)


## Option B: Integrate Dashboard into SMC_Universal
**If you prefer single EA approach**

### Step 1: Add Dashboard Code Block

Find line 14437 in SMC_Universal.mq5:
```
void UpdateDashboard()
```

Add BEFORE this function (around line 14430):

```cpp
//+------------------------------------------------------------------+
//| PROFESSIONAL DASHBOARD DISPLAY (NEW)                             |
//+------------------------------------------------------------------+

void DrawProfessionalDashboard()
{
   if(!ShowAdvancedProfitDashboard) return;
   
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 1) return; // Update every 1 second
   lastUpdate = TimeCurrent();
   
   // Get stats
   double totalPL = 0, dailyPL = 0;
   int posCount = 0, winTrades = 0, lossTrades = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      totalPL += PositionGetDouble(POSITION_PROFIT) + 
                 PositionGetDouble(POSITION_COMMISSION) + 
                 PositionGetDouble(POSITION_SWAP);
      posCount++;
   }
   
   // Build dashboard text
   string dash = "════════════════════════════════════════════════════════\n";
   dash += "  🤖 TRADBOT IA | PROFESSIONAL DASHBOARD\n";
   dash += "════════════════════════════════════════════════════════\n\n";
   dash += "┌─ 💰 PORTFOLIO P&L ─────────────────────────────────────┐\n";
   dash += "│ Total P&L:     " + (totalPL >= 0 ? "+" : "") + DoubleToString(totalPL, 2) + "$ " + 
          (totalPL >= 0 ? "🟢" : "🔴") + "\n";
   dash += "│ Positions:     " + IntegerToString(posCount) + " open | ";
   dash += IntegerToString(winTrades) + " wins | " + IntegerToString(lossTrades) + " losses\n";
   dash += "└────────────────────────────────────────────────────────┘\n";
   
   // Update label
   if(ObjectFind(0, "PRO_DASH") == -1)
      ObjectCreate(0, "PRO_DASH", OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, "PRO_DASH", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "PRO_DASH", OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, "PRO_DASH", OBJPROP_YDISTANCE, 300); // Below existing dashboard
   ObjectSetInteger(0, "PRO_DASH", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "PRO_DASH", OBJPROP_TEXT, dash);
}
```

### Step 2: Add Input Parameter

Find the input section (around line 85-260) and add:

```cpp
input bool ShowAdvancedProfitDashboard = true;  // Show professional P&L dashboard
```

### Step 3: Call Function in OnTick

In the `OnTick()` function (around line 13736), after line 13785 add:

```cpp
// Call professional dashboard (integrated version)
DrawProfessionalDashboard();
```

### Step 4: Recompile

Press F5 to compile, should have no errors.


## Option C: Use Full SMC_Dashboard_Pro Integration
**For complete replacement of dashboard system**

Replace the entire `UpdateDashboard()` function content with the code from `SMC_Dashboard_Pro.mq5`.

This would completely overhaul the dashboard system.


## Recommendation: **Use Option A (Standalone)**

### Why?
1. ✅ No risk of breaking main EA
2. ✅ Easier to debug
3. ✅ Can be attached/detached independently
4. ✅ Dashboard development separate from trading logic
5. ✅ Minimal performance impact

### How to Use Option A:
1. Attach `SMC_Universal.ex5` to your chart
2. Attach `SMC_Dashboard_Pro.ex5` to the SAME chart
3. Both run independently
4. Dashboard displays in top-left, main EA trades normally

---

**Decision:** Using Option A (Standalone approach recommended)
