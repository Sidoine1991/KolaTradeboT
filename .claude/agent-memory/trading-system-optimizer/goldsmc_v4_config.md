---
name: goldsmc-v4-config
description: GoldSMC EA v4 configuration — base v2 logic + 8 critical v3 fixes, optimized OOS params SL=1.5 RR=3.0
metadata:
  type: project
---

GoldSMC EA v4 deployed 2026-05-24 on both terminals (E6E3, F016).

**Base**: v2 logic (OB+BOS + EMA multi-TF), proven in OOS backtest with PF=1.385, WR=42%.

**Optimal params from backtest_best_params_v2.json**:
- SL_ATRMult = 1.5
- TP_RR = 3.0
- BuyBiasOnly = true
- ATR_RangeFilterMult = 0.3
- SwingLookback = 5
- OB_LookbackBars = 12
- CooldownMinutes = 60
- MaxSpreadPoints = 350

**8 critical fixes from v3 integrated**:
1. Risk-based lot sizing (UseRiskBasedLot=true, tickValue/tickSize calculation)
2. OrderCalcMargin() check before every trade (skip if insufficient)
3. DisableBreakerInTester=true (circuit breaker OFF in Strategy Tester)
4. Separate g_obZoneWasOutsideBuy / g_obZoneWasOutsideSell variables
5. Post-win gate removed (g_waitForKeyLevel was blocking indefinitely)
6. PrintOnce intervals set to 1800s to reduce journal spam
7. canSell = !bullHTF (HTF bearish suffices, no LTF requirement)
8. MaxSpreadPoints = 350 (XAUUSD_i high spread)

**NOT included** (caused problems in v3):
- RequireCHOCH (blocked all trades)
- AdaptiveRR (unnecessary complexity)
- MaxWeeklyLossPct (not in v2)
- BOS_MinBodyATR (too restrictive)
- Post-win key level gate

**Why:** v2 had the best backtest performance; v3 added useful safety features but also broke trading with CHOCH/AdaptiveRR. v4 cherry-picks only proven improvements.

**How to apply:** For future parameter changes, verify against backtest_best_params_v2.json. Don't add CHOCH or AdaptiveRR back without dedicated testing.
