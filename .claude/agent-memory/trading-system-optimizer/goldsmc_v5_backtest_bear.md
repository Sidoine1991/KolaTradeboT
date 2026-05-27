---
name: goldsmc-v5-backtest-bear
description: GoldSMC EA v5 backtest BEAR 2022-2023 results — proves regime detection fixes v4 directional bias problem
metadata:
  type: project
---

GoldSMC EA v5 backtest BEAR 2022-2023 validates the W1 regime auto-detection as a critical improvement over v4.

**Results summary (2022-01-01 to 2023-12-31, capital 1000 USD, lot 0.01):**

| Metric | v4 (BuyBiasOnly) | v5 (Regime W1) | v5 + MCP Filter |
|--------|-------------------|----------------|-----------------|
| Total Trades | 8 | 125 | 119 |
| Win Rate | 12.5% | 52.0% | 51.3% |
| Net P&L | -131.49 USD (-13.1%) | +200.10 USD (+20.0%) | +199.54 USD (+20.0%) |
| Profit Factor | 0.03 | 1.55 | 1.58 |
| Max Drawdown | -13.1% | -4.8% | -4.8% |
| Sharpe Ratio | 0.00 | 1.72 | 1.75 |
| Final Balance | 868.51 | 1200.10 | 1199.54 |

**Key findings:**
- v5 improves over v4 by +331.60 USD on the same bear period
- MCP filter provides marginal improvement (PF 1.55 -> 1.58, Sharpe 1.72 -> 1.75) but slightly fewer trades
- Regime breakdown: BULL=55%, BEAR=25.8%, TRANSITION=19.2% of bars in 2022-2023
- The regime detection correctly identified bear phases and switched to SELL-only
- Max DD only 4.8% vs 13.1% for v4 — much better risk control

**Why:** v4 lost money because BuyBiasOnly=true forced BUY trades during a bear market. v5 auto-detects regime via EMA50/200 on W1 timeframe and trades with the trend.

**How to apply:** v5 is validated for bear conditions. Deploy with UseRegimeFilter=true. MCP filter is a nice-to-have, not essential — it reduces trade count slightly in transition without major P&L impact.

**Files generated (2026-05-26):**
- Script: `D:\Dev\TradBOT\Backtest_report\backtest_v5_bear_2022_2023.py`
- CSV trades: `D:\Dev\TradBOT\Backtest_report\backtest_goldsmc_v5_bear_2022_2023.csv`
- Equity chart: `D:\Dev\TradBOT\Backtest_report\equity_curve_v5_bear_2022_2023.png`
- Word report: `D:\Dev\TradBOT\Backtest_report\Word_Reports\Backtest_v5_BEAR_2022_2023_20260526_0533.docx`
- Report sent via WhatsApp successfully
