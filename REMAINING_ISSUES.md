# TradBOT — Remaining Issues After v5.07 GOM Fix

**Status:** SpikeRider v5.07 complete + tested. Now parking issues for next phase.

---

## Issue #1: Symbol Mapping Mismatch (CRITICAL)

### Problem
- TradingView symbols ≠ MT5 symbols
- Example: TradingView sends signal for "Boom500" but MT5 expects "Boom 500 Index"
- System always sends "XAUUSD" in reports regardless of actual trading symbol
- **Impact:** Signals may be matched to wrong instrument, causing wrong direction trades

### Location
- `ai_server.py` — symbol mapping/normalization
- `Python/morning_scan.py` — XAUUSD hardcoded in reports
- `SpikeRiderEA.mq5` — symbol encoding in HTTP requests
- `send_unified_report.py` — symbol name in WhatsApp messages

### Test Case
```
TradingView signal: Boom500Index (actual data + price)
MT5 symbol expected: Boom 500 Index (with spaces)
Current behavior: "Boom500Index" sent, MT5 doesn't recognize, trade fails or triggers on wrong symbol
```

### Validation Needed
1. Map TradingView canonical names → MT5 exact symbol strings
2. Normalize symbols in all HTTP requests (ai_server ↔ SpikeRider)
3. Verify WhatsApp reports show ACTUAL trading symbol, not hardcoded "XAUUSD"
4. Add symbol validation middleware

---

## Issue #2: Signal/Price Symbol Divergence

### Problem
- Entry signals for symbol A but price/analysis for symbol B
- Example:
  - Signal: "BUY Boom600" (from GOM)
  - Prices: XAUUSD last close
  - Entry: Uses wrong ATR/SL/TP calibration

### Location
- `ai_server.py` — `/spike-tv-state` response
- `SpikeRiderEA.mq5` — EnterSpikeTrade() uses chart symbol, not signal symbol

### Impact
- Wrong SL/TP distances (ATR from wrong instrument)
- Micro-losses on entry due to misaligned risk calculation
- Reports show "Trade XAUUSD" when actually on Boom

---

## Issue #3: TradingView MCP Bridge Symbol Encoding

### Problem
- `/spike-tv-state?symbol=Boom%20500%20Index` (URL encoded with spaces)
- But TradingView internal may expect `Boom500Index` or `BOOM500INDEX`
- Encoding issues lose data in JSON responses

### Location
- `SpikeRiderEA.mq5` lines ~793-794, ~1030
- `ai_server.py` — receives symbol from EA, doesn't normalize before TradingView query

### Test Case
```
Request: /spike-tv-state?symbol=Boom%20500%20Index
Response: Empty or 404 because TradingView doesn't recognize encoded name
```

---

## Issue #4: Multi-Symbol Tracking (Panel 2) — Symbols Not Tracked Correctly

### Problem
- SpikeRider's multi-symbol panel (bottom-left) shows bars since spike
- But symbols may not match actual Market Watch names
- Counters don't reset properly for wrong symbol names

### Location
- `SpikeRiderEA.mq5` lines ~2911-2937 (ScanMarketWatchSymbols)
- `SymbolCtx` struct — barsSince tracking per symbol

### Impact
- Dashboard shows wrong progress for some symbols
- May skip spikes because counter isn't reset

---

## Issue #5: WhatsApp Reports Hardcoded to XAUUSD

### Problem
- `send_unified_report.py` always reports on "XAUUSD"
- Even if actual trades were on "Boom500Index" or "Crash300"
- Historical reports in Telegram/WhatsApp all show wrong symbol name

### Location
- `send_unified_report.py` — line with `_Symbol = "XAUUSD"`
- `send_xauusd_full_report.py` — hardcoded in filename
- `morning_scan.py` — may have same issue

### Test Case
```
Actual trade: BUY Boom500Index @ 10245.50, profit $2.15
Report sent: "XAUUSD trade BUY @ 1950.25, profit $2.15" ← WRONG
```

---

## Priority Order for Next Phase

1. **HIGH:** Fix symbol mapping → prevents wrong-instrument trades
2. **HIGH:** Fix WhatsApp symbol reporting → prevents confusion
3. **MEDIUM:** Fix signal/price divergence → improves SL/TP accuracy
4. **MEDIUM:** Fix TradingView MCP encoding → ensures correct GOM data
5. **LOW:** Fix multi-symbol tracking → better diagnostics

---

## Quick Reference: Symbol Mappings Needed

| TradingView (MCP) | MT5 Terminal | Notes |
|-------------------|--------------|-------|
| `Boom 500 Index` | `Boom 500 Index` (exact) | Need to verify exact spacing/case |
| `Boom 600 Index` | `Boom 600 Index` | Same |
| `Crash 500 Index` | `Crash 500 Index` | Same |
| `XAUUSD` | `XAUUSD` | Direct match |
| `EURUSD` | `EURUSD` | Direct match |

---

## Files to Audit

- [ ] `ai_server.py` — symbol validation, normalization
- [ ] `SpikeRiderEA.mq5` — symbol URL encoding, multi-symbol tracking
- [ ] `send_unified_report.py` — hardcoded XAUUSD → dynamic symbol
- [ ] `Python/morning_scan.py` — symbol references
- [ ] `Python/generate_morning_report.py` — symbol reporting
- [ ] TradeManager.mq5 — symbol handling in orders

---

## Success Criteria for Next Phase

- [x] SpikeRider v5.07 GOM verdict working (DONE)
- [ ] Symbol mapping 100% accurate (TradingView ↔ MT5)
- [ ] Reports show actual trading symbol, not "XAUUSD"
- [ ] All signals match prices/analysis of same symbol
- [ ] Multi-symbol dashboard accurate
- [ ] No trade executed on wrong instrument

---

## Parking This for Later

**DO NOT** attempt to fix these while v5.07 GOM rollout is happening.

After deployment stabilizes (24-48 hours), open new branch:
```bash
git checkout -b fix/symbol-mapping
```

And work through issues in priority order.

---

**Date Noted:** 2026-05-30  
**v5.07 Status:** Complete & Tested  
**Next Phase:** Symbol Mapping Fix  
**ETA:** After v5.07 production validation
