# Multi-Broker Support Guide - SMC_Universal

## Supported Brokers & Equivalents

### 1. **Deriv (Primary)**
- **Boom/Crash**: `Boom 300/500/600/900/1000 Index`, `Crash 300/500/600/900/1000 Index`
- **Volatility**: `Volatility 75 Index`
- **Direction Rules**:
  - **Boom**: BUY only (unidirectional)
  - **Crash**: SELL only (unidirectional)
  - **Volatility**: Both BUY and SELL allowed

---

### 2. **Weltrade**
- **PAINX** ≡ Boom (Deriv) — BUY only
- **GAINX** ≡ Crash (Deriv) — SELL only
- **FXVOL** ≡ Volatility (Deriv)

**Key Differences**:
- Single symbol = variable direction (auto-detect via analysis)
- Must use direction gates to enforce BUY-only (PAINX) / SELL-only (GAINX)

---

### 3. **XTrade / XT**
- **PAINX** ≡ Boom
- **GAINX** ≡ Crash
- **FXVOL** or **SFV_VOL** ≡ Volatility

---

### 4. **Forex & Metals (Multi-Broker)**
- `XAUUSD` (Gold/Spot)
- `XAGUSD` (Silver)
- `EURUSD`, `GBPUSD`, `USDJPY`, etc.
- **Available on**: Deriv, Weltrade, XTrade, OANDA

---

## Symbol Normalization Flow

```
Raw MT5 Symbol
        ↓
[symbol_mapper.py] resolve_mt5_symbol()
        ↓
Canonical MT5 Name (e.g., "Boom 500 Index" or "PAINX")
        ↓
[SMC_Universal.mq5] GetSymbolCategory()
        ↓
Direction Gate Applied
  - Boom/PAINX → BUY only
  - Crash/GAINX → SELL only
  - Volatility/FXVOL → Both
        ↓
Order Placement
```

---

## EA Configuration by Broker

### Deriv Setup
```
Terminal: Default Deriv
Symbols: Boom 300/500/600/900/1000 Index
         Crash 300/500/600/900/1000 Index
         Volatility 75 Index
         XAUUSD, XAGUSD, EURUSD, etc.
Direction Gates: ACTIVE (strict enforcement)
```

### Weltrade Setup
```
Terminal: Weltrade
Symbols: PAINX (treats as Boom)
         GAINX (treats as Crash)
         FXVOL (treats as Volatility)
         XAUUSD, EURUSD, etc.
Direction Gates: ACTIVE (critical!)
  - PAINX: Force BUY only via gate
  - GAINX: Force SELL only via gate
```

### XTrade Setup
```
Terminal: XTrade
Symbols: PAINX, GAINX, FXVOL
         XAUUSD, EURUSD, etc.
Direction Gates: ACTIVE
```

---

## Code Examples

### Detect Symbol Category
```mql5
#include "symbol_mapper.py"

ENUM_SYMBOL_CATEGORY category = SMC_GetSymbolCategory(_Symbol);

if (category == SYM_BOOM_CRASH)
{
   if (is_boom(_Symbol))
      Print("BUY only - Boom/PAINX");
   else if (is_crash(_Symbol))
      Print("SELL only - Crash/GAINX");
}
else if (category == SYM_VOLATILITY)
   Print("Both BUY and SELL allowed");
```

### Convert Between Brokers
```python
from symbol_mapper import get_equivalent_symbol, get_broker_from_symbol

# My trade was on Deriv Boom 500
deriv_signal = "Boom 500 Index"

# Convert to Weltrade equivalent
weltrade_symbol = get_equivalent_symbol(deriv_signal, "weltrade")
print(f"Trade on {weltrade_symbol}")  # Output: "PAINX"

# Auto-detect which broker a symbol is from
broker = get_broker_from_symbol("PAINX")
print(f"Broker: {broker}")  # Output: "weltrade"
```

---

## Direction Enforcement Rules

| Symbol | Broker | BUY | SELL | Rule |
|--------|--------|-----|------|------|
| Boom 500 Index | Deriv | ✅ | ❌ | Synthetic unidirectional |
| PAINX | Weltrade | ✅ | ❌ | Gate enforces BUY only |
| Crash 500 Index | Deriv | ❌ | ✅ | Synthetic unidirectional |
| GAINX | Weltrade | ❌ | ✅ | Gate enforces SELL only |
| Volatility 75 Index | Deriv | ✅ | ✅ | Normal trading |
| FXVOL | Weltrade | ✅ | ✅ | Normal trading |
| XAUUSD | Any | ✅ | ✅ | Normal trading |

---

## Troubleshooting

### Issue: "Symbol not found in MT5"
**Solution**: Verify symbol name matches exact broker naming:
- Deriv: `Boom 500 Index` (with spaces)
- Weltrade: `PAINX` (no spaces)

### Issue: Illegal trades (BUY on Crash, etc.)
**Solution**: Ensure direction gates are ACTIVE:
```mql5
input bool UseDirectionGates = true;  // MUST be TRUE
```

### Issue: Price discrepancies between brokers
**Solution**: Each broker has different pricing. Use broker-specific SL/TP calculations:
```mql5
double sl = CalculateBrokerSpecificSL(_Symbol, direction);
```

---

## Test Checklist

- [ ] EA loads all symbols correctly on Deriv
- [ ] EA loads all symbols correctly on Weltrade
- [ ] PAINX direction gate forces BUY only
- [ ] GAINX direction gate forces SELL only
- [ ] FXVOL allows both BUY and SELL
- [ ] Cross-broker conversion works (Boom ↔ PAINX)
- [ ] XAUUSD trades on multiple brokers
- [ ] Spreadsheet reports use correct symbol names

---

## Multi-Terminal Setup

### Terminal 1 (Deriv - Primary)
```
MetaTrader 5 - Deriv
Account: Active trading
Symbols: Boom/Crash/Volatility Index + Forex
EA: SMC_Universal.mq5
```

### Terminal 2 (Weltrade - Secondary)
```
MetaTrader 5 - Weltrade (Copy)
Account: Backup / Parallel trading
Symbols: PAINX, GAINX, FXVOL + Forex
EA: SMC_Universal.mq5
Direction Gates: ACTIVE (critical)
```

---

## Live Trading Notes

⚠️ **CRITICAL**: When trading across brokers:
1. Monitor direction gates on EACH terminal
2. Verify SL/TP calculations match broker spreads
3. Test with small lots first (0.05-0.1)
4. Cross-check WhatsApp alerts for symbol naming
5. Keep separate position logs per broker

✅ **GO LIVE**: Once verified for 2-3 hours with 0 violations
