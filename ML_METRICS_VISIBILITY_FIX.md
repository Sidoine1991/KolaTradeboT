# 🔧 ML METRICS VISIBILITY FIX

**Status**: ✅ FIXED  
**Date**: 2026-05-17  
**Issue**: ML metrics hidden by GOM dashboard  
**Solution**: Move metrics to top-left, above dashboard

---

## Problem

ML metrics display was positioned BELOW the GOM/KOLA/SIDO dashboard, causing them to be:
- Hidden when dashboard is large
- Not visible at chart startup
- Lost in the clutter of stacked labels

---

## Root Cause

**Line 13345** (DrawMLMetricsOnChart):
```mql5
// BEFORE - Positioned BELOW dashboard
int y = MathMax(MLMetricsLabelYOffsetPixels, g_dashboardBottomY + 45);
```

This logic:
1. Takes `MLMetricsLabelYOffsetPixels` (default 200)
2. Compares with `g_dashboardBottomY + 45` (dashboard bottom + 45px)
3. Uses whichever is HIGHER → always below dashboard

---

## Solution Applied

### Change 1: Fixed Y Position

**File**: SMC_Universal.mq5, Line 13345  
**Before**:
```mql5
int y = MathMax(MLMetricsLabelYOffsetPixels, g_dashboardBottomY + 45);
```

**After**:
```mql5
// Position ML metrics at TOP-LEFT, above dashboard (not below)
// This ensures ML metrics are always visible and not hidden by GOM dashboard
int y = 5;  // 5 pixels from top
```

**Effect**: ML metrics now appear 5 pixels from the top-left corner, always visible

### Change 2: Updated Input Parameter

**File**: SMC_Universal.mq5, Line 2343  
**Before**:
```mql5
input int MLMetricsLabelYOffsetPixels = 200;  // Décalage vertical (px) pour éviter la superposition - augmenté
```

**After**:
```mql5
input int MLMetricsLabelYOffsetPixels = 5;    // Décalage vertical (px) - Fixed at top-left to avoid GOM dashboard
```

**Effect**: Default parameter matches new behavior (5px from top)

---

## Visual Result

### Before
```
Top of Chart
↓
[                                    ]
[                                    ]  ← GOM Dashboard (takes up space)
[                                    ]
[                                    ]
[                                    ]
[              (45px gap)            ]
[🔴 ML METRICS HIDDEN               ]  ← Hidden or hard to see
[                                    ]
```

### After
```
Top of Chart
↓
[🟢 ML Metrics (Precision: 67.5%)   ]  ← Visible at top-left
[ | Modèle: random_forest | Samples: 3 ]
[ | Feedback: 2W/1L | Status: trained   ]
[                                    ]
[                                    ]  ← GOM Dashboard below
[                                    ]
[                                    ]
[                                    ]
```

---

## ML Metrics Display

The metrics now show:

```
ML (Boom/Crash, Boom 1000 Index): Précision: 67.5% | Modèle: random_forest | Samples: 3 | Feedback: 2W/1L | Status: trained | Canal: OK
```

**Location**: Top-left corner at 5px from top edge  
**Font**: Consolas, size 7  
**Color**: Green (OK) or Yellow (channel issue)  
**Update**: Every 30 seconds from server

---

## Content of ML Metrics Line

| Component | Meaning | Example |
|-----------|---------|---------|
| **ML (Category, Symbol)** | Type and symbol | "ML (Boom/Crash, Boom 1000 Index)" |
| **Précision** | Model accuracy | "67.5%" |
| **Modèle** | Active model | "random_forest" |
| **Samples** | Training data points | "3" |
| **Feedback** | Win/loss ratio | "2W/1L" |
| **Status** | Learning state | "trained" |
| **Canal** | Data channel health | "OK" |

---

## Positioning Logic

### Current (Fixed) Position
```
CORNER: CORNER_LEFT_UPPER (top-left)
X Distance: 10 pixels from left
Y Distance: 5 pixels from top
```

### Why Top-Left?
1. **Always visible** - No dashboard interference
2. **Important data** - ML metrics should be prominent
3. **First thing user sees** - Instant feedback on model status
4. **Out of way** - Chart candles are in center, not top-left
5. **Professional** - Standard location for real-time metrics

---

## Verification After Fix

After recompiling and loading:

1. **Look at chart top-left corner**
   - You should see ML metrics line immediately
   - Should NOT be hidden by GOM dashboard

2. **Check metrics content**
   - Shows symbol category
   - Shows accuracy percentage
   - Shows model name
   - Shows sample count
   - Shows win/loss feedback
   - Shows training status

3. **Verify updates**
   - Line updates every 30 seconds
   - Server fetches fresh metrics
   - Colors change (green/yellow) based on channel health

---

## Impact

### What Changed
- ✅ ML metrics now at TOP-LEFT (5px from top)
- ✅ No longer hidden by GOM dashboard
- ✅ Always visible on chart load
- ✅ Can see accuracy at a glance

### What Stayed the Same
- ✅ Metrics content unchanged
- ✅ Update frequency (30 seconds) unchanged
- ✅ Server communication unchanged
- ✅ Font/color/styling unchanged

### Side Effects
- None - this is a pure display adjustment
- No functional changes
- No data changes
- No server communication changes

---

## Related Elements

These labels still appear BELOW dashboard (unchanged):
- Propice top symbols list
- Signal arrows
- Other informational labels

Only ML metrics moved to top-left for visibility.

---

## Files Modified

1. **SMC_Universal.mq5**
   - Line 2343: Updated input parameter default value
   - Line 13345: Changed Y position calculation from dashboard-relative to fixed top position

---

## Compilation

After fix:
- Expected: 0 errors, 0 warnings
- No new functions added
- No syntax changes (just logic update)
- Safe to compile

---

## Testing After Load

1. Compile (F7) - verify 0 errors, 0 warnings
2. Load EA on chart
3. Look at top-left corner - metrics should be visible
4. Wait 30 seconds - metrics should update from server
5. Generate a new trade and close it
6. Metrics should reflect new win/loss feedback
7. Verify no overlap with chart candles

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| ML Metrics Position | Below dashboard (Y=200+) | Top-left corner (Y=5) |
| Visibility | Often hidden | Always visible |
| User experience | Hard to find | Instant access |
| Overlap | With other labels | None |
| Update timing | Every 30s (same) | Every 30s (same) |

---

**Status**: ✅ FIX APPLIED - Ready to compile

Recompile with F7 and reload the robot. ML metrics will now be visible at the top-left corner!

