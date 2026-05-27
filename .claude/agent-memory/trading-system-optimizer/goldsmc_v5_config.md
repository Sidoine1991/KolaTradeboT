---
name: goldsmc-v5-config
description: GoldSMC EA v5 architecture — W1 regime detection (EMA50/200), partial TP at RR=1.5, adaptive entry logic per regime
metadata:
  type: project
---

GoldSMC EA v5 deployed 2026-05-25. Major evolution from v4: automatic market regime detection replaces static BuyBiasOnly flag.

**Why:** v4 achieved PF=6.49 on 2024-2025 (bull market) but -13.1% on 2022-2023 (bear market) because BuyBiasOnly=TRUE made it blind to bear conditions.

**How to apply:** v5 now detects regime automatically using EMA50/200 on W1 timeframe:
- BULL (EMA50_W1 > EMA200_W1 * 1.005): BUY only, bullHTF required
- BEAR (EMA50_W1 < EMA200_W1 * 0.995): SELL only, bearish HTF required
- TRANSITION (between thresholds): strict LTF+HTF alignment, lot reduced 50%

Key new features:
- Partial TP: 50% closed at RR=1.5, SL moved to BE, trailing on remaining 50% to RR=3.0
- BuyBiasOnly input removed entirely (replaced by UseRegimeFilter)
- Dashboard shows regime in color: green/red/orange
- MagicNumber changed to 20260525 for v5

All v4 fixes preserved: separated OB zones, daily limit flag, circuit breaker flag, OrderCalcMargin check, PrintOnce 1800s, canSell HTF, no post-win gate.

Compilation: 0 errors, 0 warnings on both T1 (E6E3) and T2 (F016).
Validated backup: `D:\Dev\TradBOT\Validated_EA\GoldSMC_EA_v5_validated_20260525.mq5`

Related: [[goldsmc-v4-config]], [[project-capital-profile]]
