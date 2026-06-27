# Weltrade Configuration - Trade Execution Gates

## Problem
Trades are blocked despite valid signals because:
- **IA Confidence** too low (50-52%) vs threshold (55% min)
- **GOM Verdict** = WAIT (needs stronger signal vn >= 2)

## Solution: Weltrade-Specific Gates

### Gate Adjustments

```mql5
// In SMC_Universal.mq5, add Weltrade profile:

input bool UseWeltradeLoweredGates = true;      // Lower thresholds for Weltrade
input double WeltradeBrokerMinAIConfidence = 0.45;  // Deriv: 0.55 → Weltrade: 0.45
input int WeltradeBrokerGOMMinVerdictNum = 1;   // Deriv: 2 → Weltrade: 1 (accept GOOD signals)

bool IsWeltradeBroker(const string symbol)
{
   return (StringFind(symbol, "PAINX") >= 0 || 
           StringFind(symbol, "GAINX") >= 0 || 
           StringFind(symbol, "FXVOL") >= 0);
}

// In decision gate:
double minConfidence = IsWeltradeBroker(_Symbol) ? WeltradeBrokerMinAIConfidence : 0.55;
int minGOM = IsWeltradeBroker(_Symbol) ? WeltradeBrokerGOMMinVerdictNum : 2;
```

### Recommended Settings by Broker

| Parameter | Deriv | Weltrade | XTrade |
|-----------|-------|----------|--------|
| Min IA Confidence | 0.55 (55%) | 0.45 (45%) | 0.50 (50%) |
| Min GOM Verdict | vn >= 2 (PERFECT) | vn >= 1 (GOOD) | vn >= 1 (GOOD) |
| Min Setup Score | 75 | 65 | 70 |
| Max Correction Block | 30% | 40% | 35% |

### Why Lower Gates?

1. **Weltrade pricing** more volatile → signals appear less "perfect"
2. **Less historical data** on Weltrade indices → GOM coherence lower
3. **Different broker execution** → need to catch earlier entries
4. **Direction gates still active** → PAINX BUY-only, GAINX SELL-only protection remains

### Current Weltrade Blockages

✅ **GAINX 400**: READY (65% confidence, PERFECT_SELL)
🚫 **PainX 400**: BLOCKED (50% confidence < 55% threshold)
🚫 **FX Vol 20**: BLOCKED (52% confidence < 55% threshold)

**Fix**: Set `WeltradeBrokerMinAIConfidence = 0.45` → 50% >= 45% ✅ READY

## Implementation Steps

1. Update SMC_Universal.mq5 with Weltrade gate functions
2. Recompile on F016 terminal
3. Reload EA on PAINX/GAINX/FXVOL charts
4. Monitor logs for "Weltrade lowered gates active" message
5. Verify trades execute on next signal

## Testing Checklist

- [ ] PAINX 400: HOLD → READY after threshold adjustment
- [ ] FX Vol 20: HOLD → READY after threshold adjustment
- [ ] GAINX 400: Remains READY (no change needed)
- [ ] Direction gates still enforced (PAINX BUY-only, GAINX SELL-only)
- [ ] First trade executes within 5 minutes of signal
- [ ] WhatsApp alert sent on trade execution

## Rollback Plan

If trades execute too aggressively:
```mql5
WeltradeBrokerMinAIConfidence = 0.50;  // Back to 50%
WeltradeBrokerGOMMinVerdictNum = 2;    // Back to PERFECT_BUY/SELL only
```

Restart EA and monitor for 10 minutes.
