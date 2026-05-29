# 🔐 MCP TradingView — Safe Usage Rules (M1 Lock)

## Problem
MCP TradingView commands can change the chart timeframe, breaking M1 lock:
- `chart_set_timeframe()` → Changes TF directly
- `batch_run()` with mixed TFs → Cycles through different TFs
- `chart_set_symbol()` → May change TF
- Auto-refresh → May trigger TF reset

## Solution: Safe MCP Command List

### ✅ SAFE Commands (Read-Only, No TF Change)
**These commands are safe to use — they don't change timeframe:**

```
READ-ONLY COMMANDS:
✅ chart_get_state() — Get current chart state (symbol, TF, indicators)
✅ data_get_study_values() — Read all indicator values
✅ data_get_ohlcv() — Get OHLCV bars (no TF change)
✅ data_get_pine_tables() — Read Pine Script tables/labels
✅ data_get_pine_labels() — Get annotation labels
✅ data_get_pine_lines() — Get price level lines
✅ data_get_pine_boxes() — Get zone boxes
✅ quote_get() — Get real-time quote (symbol specified)
✅ symbol_info() — Get symbol metadata
✅ symbol_search() — Search for symbols
✅ data_get_indicator() — Read specific indicator values
✅ data_get_equity() — Get equity curve (strategy tester)
✅ data_get_strategy_results() — Get backtest results
✅ data_get_trades() — Get trade list
```

### ❌ FORBIDDEN Commands (TF-Changing)
**These commands change timeframe — NEVER use them:**

```
FORBIDDEN COMMANDS:
❌ chart_set_timeframe() → Changes TF (breaks M1 lock)
❌ chart_set_symbol() → May change TF to default
❌ batch_run(..., timeframes: [...]) → Cycles TF (breaks lock)
❌ pane_set_layout() → May reset chart TF
❌ tab_new() → Opens new tab with default TF
```

### ⚠️ CONDITIONAL Commands
**Use only if M1 is preserved:**

```
CONDITIONAL COMMANDS:
⚠️ chart_set_type() — Safe (changes chart type, not TF)
⚠️ chart_manage_indicator() — Safe (adds/removes indicators, not TF)
⚠️ indicator_set_inputs() — Safe (edits indicator, not TF)
⚠️ draw_shape() — Safe (drawing only, not TF)
⚠️ indicator_toggle_visibility() — Safe (show/hide, not TF)
```

---

## Implementation: Memory Note

Add to your `.claude/projects/D--Dev-TradBOT/memory/`:

```markdown
---
name: mcp-tradingview-m1-safe-usage
description: MCP TradingView safe commands — never change TF from M1
metadata:
  type: feedback
---

**Rule:** MCP TradingView must NEVER change chart timeframe from M1.

**Safe:** chart_get_state, data_get_study_values, data_get_ohlcv, quote_get
**Forbidden:** chart_set_timeframe, batch_run (mixed TF), chart_set_symbol
**Reason:** Trading depends on M1 stability; TF changes break EAs and signal detection

**How to apply:** Before using any MCP TradingView command, check if it's in SAFE list. If not, skip it.
```

---

## Enforcement: Claude Code Settings

Add to `.claude/settings.json`:

```json
{
  "mcp_tradingview_m1_lock": {
    "enabled": true,
    "strict_mode": true,
    "allowed_commands": [
      "chart_get_state",
      "data_get_study_values",
      "data_get_ohlcv",
      "quote_get",
      "data_get_pine_tables",
      "data_get_pine_labels"
    ],
    "blocked_commands": [
      "chart_set_timeframe",
      "batch_run",
      "chart_set_symbol",
      "tab_new"
    ],
    "on_violation": "warn"  # or "block"
  }
}
```

---

## Usage Examples

### ✅ GOOD: Read chart state (M1 preserved)
```
mcp__tradingview-kola__chart_get_state()
→ Returns: symbol=XAUUSD, timeframe=M1, ...
→ TF stays M1 ✓
```

### ✅ GOOD: Get indicator values (M1 preserved)
```
mcp__tradingview-kola__data_get_study_values()
→ Returns: RSI, MACD, EMA values on current (M1) timeframe
→ TF stays M1 ✓
```

### ❌ BAD: Change timeframe (M1 broken)
```
mcp__tradingview-kola__chart_set_timeframe(timeframe="M5")
→ Chart changes to M5
→ TradeManager loses M1 data
→ EAs stop working ✗
```

### ❌ BAD: Batch run with mixed TFs (M1 broken)
```
mcp__tradingview-kola__batch_run(
  symbols: ["XAUUSD", "EURUSD"],
  timeframes: ["M1", "M5", "H1"]  ← Multiple TFs!
)
→ Chart cycles M1 → M5 → H1 → M1
→ Breaks M1 lock ✗
```

---

## Checklist: Before Using MCP

- [ ] Is the command in the SAFE list?
- [ ] Does it only read data (no write/change)?
- [ ] Does it preserve M1 as current timeframe?
- [ ] Have I tested it on a dummy chart first?

**If ANY answer is NO → Don't use the command**

---

## Testing M1 Lock

After making MCP calls:

```bash
# Check if M1 is still active
mcp__tradingview-kola__chart_get_state()

# Expected output:
# {
#   "symbol": "XAUUSD",
#   "resolution": "1",  ← "1" = M1
#   "chartType": 1,
#   ...
# }

# If resolution ≠ "1" → Someone changed the TF!
```

---

## Emergency Reset: Force M1 via EA

If TF drifts, force it back:

**In MT5 (F2 console):**
```mql5
// Force M1 on current chart
ChartSetSymbolPeriod(0, _Symbol, PERIOD_M1);
Print("M1 locked");
```

Or restart MT5 (will restore M1 from TradingView default).

---

## Summary

| Aspect | Rule |
|--------|------|
| **Default TF** | M1 (TradingView setting) |
| **EA Enforcement** | TradeManager + SpikeRider force M1 every tick |
| **MCP Safe** | Read-only commands only (chart_get_state, data_get_*) |
| **MCP Forbidden** | chart_set_timeframe, batch_run (mixed TF) |
| **Monitoring** | Watchdog checks every 10s (optional) |
| **If drift occurs** | EA auto-reverts to M1 at next tick |

**Result:** M1 stays stable, no chart drifting, EAs work reliably.
