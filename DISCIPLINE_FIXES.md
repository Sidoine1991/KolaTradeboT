# StringFormat Fixes — MQL5 Compilation

## Issue
MQL5 StringFormat() doesn't support nested ternary operators (? :) directly as parameters.

## Root Cause
Lines with patterns like:
```mql5
Print(StringFormat("...", (condition ? "THEN" : "ELSE")))
```

Cause: `wrong parameters count` error 199 because the compiler can't parse the ternary inside the parameter list.

## Solution
Extract ternaries to separate string variables BEFORE StringFormat():

### Before (❌ ERROR)
```mql5
Print(StringFormat("[DISCIPLINE] ✅ TRADE #%d/%d | direction=%s | ...",
      g_dailyTradeCount, g_maxDailyTrades, (direction > 0 ? "BUY" : "SELL"), ...));
```

### After (✅ FIXED)
```mql5
string dirStr = (direction > 0) ? "BUY" : "SELL";
Print(StringFormat("[DISCIPLINE] TRADE #%d/%d | direction=%s | ...",
      g_dailyTradeCount, g_maxDailyTrades, dirStr, ...));
```

## Changes Made

### 1. RegisterTradeEntry() — Line 669
**Before:**
```mql5
(direction > 0 ? "BUY" : "SELL")
```
**After:**
```mql5
string dirStr = (direction > 0) ? "BUY" : "SELL";
// Use dirStr in StringFormat
```

### 2. DisplayDisciplineStatus() — Lines 696-698
**Before:**
```mql5
Print(StringFormat("  Trades: %d/%d (%s) | ...",
      g_dailyTradeCount, g_maxDailyTrades, (tradesMaxed ? "MAXED" : "OK"),
      closedPnl, g_dailyProfitTarget, (targetReached ? "ATTEINT" : "..."), ...));
```
**After:** Converted to string concatenation (safer):
```mql5
Print("[DISCIPLINE STATUS] Trades: " + IntegerToString(g_dailyTradeCount) + "/" + 
      IntegerToString(g_maxDailyTrades) + " (" + tradesStatus + ")");
```

### 3. RunDerivEngine() — Line 3712
**Before:**
```mql5
string cmt = StringFormat("TM_DRV|%s|ICT%d", isBuy?"BUY":"SELL", g_drvICTScore);
```
**After:**
```mql5
string dirStr = isBuy ? "BUY" : "SELL";
string cmt = StringFormat("TM_DRV|%s|ICT%d", dirStr, g_drvICTScore);
```

### 4. TryExecuteMCPSignal() — Line 4608
**Before:**
```mql5
Print(StringFormat("[TradeManager] ...", sym, (execNow?"YES":"NO"), priceDistance, tol));
```
**After:**
```mql5
string execStr = execNow ? "YES" : "NO";
Print(StringFormat("[TradeManager] ...", execStr, priceDistance, tol));
```

## Result
✅ All StringFormat() calls now have clean parameter lists
✅ Ternary operators evaluated first, then passed as strings
✅ Expected compilation: 0 errors, 0 warnings

## MQL5 Best Practice
Always pre-compute complex expressions before passing to StringFormat():
```mql5
// ✅ GOOD
bool isBuy = SomeCondition();
string dir = isBuy ? "BUY" : "SELL";
Print(StringFormat("Direction: %s", dir));

// ❌ BAD
Print(StringFormat("Direction: %s", SomeCondition() ? "BUY" : "SELL"));
```
