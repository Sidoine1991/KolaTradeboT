# SMC_Universal.mq5 Compilation Test Guide

## Prerequisites

- MetaTrader 5 terminal installed
- MetaEditor 5 available (comes with MT5)
- Source files verified:
  - `mt5/SMC_Universal.mq5` (main EA)
  - `mt5/modules/SMC_TradeJournal.mqh` (trade journal module)
  - All other dependent modules present

## Compilation Steps

### Option 1: Via MetaEditor GUI

1. **Open MetaEditor**
   ```batch
   C:\Program Files\MetaTrader 5\metaeditor64.exe
   ```

2. **Open SMC_Universal.mq5**
   - File → Open → `D:\Dev\TradBOT\mt5\SMC_Universal.mq5`

3. **Compile**
   - Press `F5` or Build → Compile
   - Or: File → Compile

4. **Review Output**
   - Toolbox → Errors tab
   - Should show: `0 errors, 3 warnings`

### Option 2: Via Command Line

```batch
cd D:\Dev\TradBOT

REM Compile with detailed log
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:mt5\SMC_Universal.mq5 /log:logs\compile.log

REM Wait for compilation to complete
timeout /t 5

REM Check log file
type logs\compile.log | find "error"
```

### Option 3: Via PowerShell

```powershell
cd D:\Dev\TradBOT

$metaeditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"

if (Test-Path $metaeditor) {
    & $metaeditor /compile:mt5\SMC_Universal.mq5 /log:logs\compile.log
    Write-Host "Compilation started..."
    Start-Sleep -Seconds 5
    
    # Display compilation log
    if (Test-Path logs\compile.log) {
        Get-Content logs\compile.log
    }
} else {
    Write-Host "MetaEditor not found at $metaeditor"
}
```

## Expected Results

### Success State

```
Compilation completed successfully
   Time: 00:02.345
   Errors: 0
   Warnings: 3
   Compiled: mt5/SMC_Universal.ex5
```

### Output Files Generated

```
mt5/SMC_Universal.ex5
  → Compiled Expert Advisor binary
  → Ready for deployment to MT5 terminal

mt5/SMC_Universal.map
  → Debug information (optional)
```

## Verification Checklist

After compilation, verify:

### ✅ Module Integration

- [ ] SMC_TradeJournal.mqh functions resolve
  - SMC_JournalConfigure()
  - SMC_JournalInit()
  - SMC_JournalLogDealClose()

- [ ] Forward declarations present (lines 16-18)

- [ ] Include order correct (line 41)

### ✅ Configuration Parameters

- [ ] UseTradeJournal input exists
- [ ] TradeJournalBackfillDays input exists

### ✅ CSV Output

- [ ] Journal creates daily CSV files
- [ ] Format: SMC_Universal_Trade_Journal_YYYY_MM_DD.csv
- [ ] Headers: 17 columns as specified

### ✅ Function Calls

- [ ] OnInit() calls SMC_JournalConfigure() at line 2298
- [ ] OnInit() calls SMC_JournalInit() at line 2300
- [ ] OnTradeTransaction() calls SMC_JournalLogDealClose() at line 8552

## Deployment

Once compiled successfully:

1. **Copy Binary**
   ```batch
   copy mt5\SMC_Universal.ex5 "C:\Program Files\MetaTrader 5\MQL5\Experts\"
   ```

2. **Restart MT5**
   - Close MetaTrader 5 terminal
   - Reopen MT5

3. **Verify in Navigator**
   - Experts → SMC_Universal should appear

4. **Test on Chart**
   - Open any symbol chart
   - Right-click → Attach Expert Advisor
   - Select: SMC_Universal
   - Accept default settings
   - Monitor EA behavior

## Troubleshooting

### Compilation Error: "file not found"

```
Error: file 'modules/SMC_TradeJournal.mqh' not found
```

**Fix**: Verify file exists at:
```
D:\Dev\TradBOT\mt5\modules\SMC_TradeJournal.mqh
```

If missing, recreate using:
```bash
cd D:\Dev\TradBOT
git checkout mt5/modules/SMC_TradeJournal.mqh
```

### Compilation Error: "undeclared identifier"

```
Error: undeclared identifier 'SMC_JournalConfigure'
```

**Fix**: Check forward declarations in SMC_Universal.mq5 (lines 16-18)

```mql5
void   SMC_JournalConfigure(bool enabled, ulong magic, string ea_name, int backfill_days = 0);
void   SMC_JournalInit();
void   SMC_JournalLogDealClose(ulong deal, double ai_confidence, string ai_action);
```

### MetaEditor Not Found

**Fix**: Install MetaTrader 5 from:
```
https://www.metatrader5.com/en/download
```

Or verify installation path:
```powershell
Get-ChildItem "C:\Program Files\MetaTrader 5" -Recurse -Name "metaeditor*"
```

## Performance Notes

- Compilation time: 2-5 seconds
- Binary size: ~500-800 KB
- Journal CSV I/O: Minimal overhead (<10ms per deal close)
- Backfill on startup: ~100-200ms for 30 days of history

## Next Steps

1. ✅ Verify compilation completes
2. ✅ Deploy to MT5 terminal
3. ✅ Test on live chart
4. ✅ Monitor CSV journal output
5. ✅ Verify AI confidence logging

---

**Last Updated**: 2026-06-16
**Module Version**: 1.0
**Status**: Ready for Testing
