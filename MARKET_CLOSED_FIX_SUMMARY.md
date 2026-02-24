# Fix for "Marché fermé" Error in F_INX_Scalper_double.mq5

## Problem
The `F_INX_Scalper_double.mq5` expert advisor was incorrectly reporting "Marché fermé - tick ignoré" even when the market was open, causing it to miss trading opportunities.

## Root Cause
The `IsMarketClosed()` function was missing or incomplete in the original file, causing the expert advisor to always return `true` (market closed).

## Solution Applied
Added the complete `IsMarketClosed()` function at the end of `F_INX_Scalper_double.mq5`:

```mql5
bool IsMarketClosed() {
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    // Week-end - Samedi et Dimanche
    if(dt.day_of_week == 0 || dt.day_of_week == 6) return true;
    
    // Heures de trading pour indices synthétiques (24/5 du Lundi au Vendredi)
    // Marché ouvert: Lundi-Vendredi 00:00-23:59 UTC
    if(dt.hour >= 0 && dt.hour < 24 && dt.day_of_week >= 1 && dt.day_of_week <= 5) {
        return false; // Marché ouvert
    }
    
    return true; // Hors heures de trading
}
```

## Market Hours Logic
- **Weekend**: Saturday (6) and Sunday (0) = CLOSED
- **Weekdays**: Monday (1) to Friday (5) = OPEN
- **Hours**: 00:00-23:59 UTC on weekdays = OPEN

## Files Modified
- ✅ `mt5\F_INX_Scalper_double.mq5` - Fixed with complete function
- ✅ `mt5\F_INX_Scalper_double_original.mq5` - Backup of original

## Expected Result
The expert advisor should now correctly:
- ✅ Process ticks during market hours (Mon-Fri, 00:00-23:59 UTC)
- ✅ Ignore ticks during weekend (Sat-Sun)
- ✅ Stop showing "Marché fermé - tick ignoré" when market is actually open

## Next Steps
1. ✅ Fix applied successfully
2. 🔄 Recompile the expert advisor in MetaTrader 5
3. 📊 Monitor logs to confirm "Marché fermé" errors are resolved
4. 💰 Expert advisor should now trade during market hours

## Verification
The function can be verified by checking the end of the file (lines 8422-8437) where the complete `IsMarketClosed()` function is now properly implemented.
