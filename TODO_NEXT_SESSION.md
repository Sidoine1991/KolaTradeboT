# TODO — Next Session (Deployment Phase)

## Status: deriveapro v10.00 Compilation COMPLETE ✅

Binary ready: `D:\Dev\TradBOT\mt5\deriveapro.ex5` (83 KB, 0 errors)

---

## Phase 1: Chart Attachment (5 min)

- [ ] Open MT5 Terminal
- [ ] Open "Boom 500 Index" M1 chart
- [ ] Right-click chart → Attach Expert Advisor
- [ ] Select: **deriveapro** (v10.00)
- [ ] Configure Inputs Tab:
  - [ ] **InpUseGHOST** = `TRUE`
  - [ ] **InpGHOSTFile** = `"gom_signal.json"`
  - [ ] **InpGHOSTPollSec** = `5`
  - [ ] **InpGHOSTMinQuality** = `40.0`
  - [ ] **InpUseRiskPercent** = `TRUE`
  - [ ] **InpRiskPercent** = `1.5`
- [ ] Click OK
- [ ] Monitor Expert Tab for logs

---

## Phase 2: Verification (10 min)

### Expected Log Messages
```
[v10] GHOST OrderFlow activé | MinQuality=40.0% | MaxAge=60s
[GHOST] verdict=BUY buypct=70.0 quality=65.0 cvd=5000.0
[SPIKE] ATR spike +0.45 (2.1x ATR_M1)
[ENTRY] ANTICIPATION 75% | ICT=68(B) + GHOST=BUY | RSI=62
```

### Expected Dashboard Panel
```
GHOST BUY           Q=65% [12s]
ICT Score           68 (B)
Spike               +0.45
```

- [ ] Verify no errors in Expert Tab
- [ ] Check GHOST panel visible on chart
- [ ] Monitor dashboard updates in real-time
- [ ] Screenshot capture for documentation

---

## Phase 3: First 5 Trades (30-60 min)

- [ ] Wait for spike detection
- [ ] Document first entry signal (copy log message)
- [ ] Verify GHOST filter decision (confluence or rejection)
- [ ] Track all 5 trades:
  - [ ] Trade 1: Signal logged, entry executed, SL/TP set
  - [ ] Trade 2: Signal logged, entry executed or rejected
  - [ ] Trade 3: Signal logged, entry executed or rejected
  - [ ] Trade 4: Signal logged, entry executed or rejected
  - [ ] Trade 5: Signal logged, entry executed or rejected

### Collect Data
- Win/Loss count
- Total pips (if available)
- Rejection reasons (if any)
- GHOST confluence examples

---

## Phase 4: 24-Hour Monitoring

- [ ] Run EA continuously for 24 hours
- [ ] Track daily metrics:
  - [ ] Total spikes detected
  - [ ] Total entries (% of spikes)
  - [ ] Wins/Losses
  - [ ] Total pips
  - [ ] Max drawdown
  - [ ] Win rate
  - [ ] GHOST confluence score

- [ ] Log rejections with reasons
- [ ] Monitor performance vs v9 baseline

---

## Phase 5: Backtest Comparison

### Setup
- [ ] Get historical data: XAUUSD 2024-2025 (BULL) + 2022-2023 (BEAR)
- [ ] Run backtest with GHOST ON
- [ ] Run backtest with GHOST OFF
- [ ] Compare results

### Metrics to Capture
- [ ] Win rate (ON vs OFF)
- [ ] Profit Factor (ON vs OFF)
- [ ] Max Drawdown (ON vs OFF)
- [ ] Sharpe Ratio (ON vs OFF)
- [ ] False signals count (ON vs OFF)

---

## Support Files

Reference documents available:
- `GHOST_BLOCS_VISUALIZATION.txt` — Visual reference of 10 blocs
- `GHOST_IMPLEMENTATION_COMPLETE.txt` — Implementation checklist
- `DEPLOYMENT_REPORT.txt` — Complete deployment guide
- `GHOST_DEPLOYMENT_COMPLETE.md` — Technical summary
- `READY_FOR_TRADING.txt` — Dashboard summary
- `EXECUTIVE_SUMMARY.txt` — High-level overview

---

## Rollback Procedures (If Needed)

**Quick Disable (No recompile):**
```
EA Properties → Inputs → InpUseGHOST = FALSE
```

**Full Revert (If critical issue):**
1. Detach deriveapro v10
2. Attach deriveapro v9 (if backup available)
3. Zero impact to strategy

---

## Success Criteria

✅ Phase 1: Attachment successful without errors
✅ Phase 2: Dashboard displays GHOST data correctly
✅ Phase 3: First 5 trades executed with confluence
✅ Phase 4: 24-hour metrics collected and analyzed
✅ Phase 5: Backtest shows +5-8% win rate improvement

---

## Expected Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| 1. Attachment | 5 min | ⏳ TODO |
| 2. Verification | 10 min | ⏳ TODO |
| 3. First trades | 30-60 min | ⏳ TODO |
| 4. 24-hour monitoring | 24 hours | ⏳ TODO |
| 5. Backtest | 2-3 hours | ⏳ TODO |
| **TOTAL** | **~1-2 days** | ⏳ TODO |

---

## Notes

- Binary is compiled and ready: `deriveapro.ex5` (83 KB)
- All integration blocs verified (10/10)
- Compilation: 0 errors, 0 warnings
- Backward compatible (InpUseGHOST toggle works)
- Expected performance: -10-15% false signals, +5-8% win rate

---

## Contacts / Support

- Questions about integration? Check `DEPLOYMENT_REPORT.txt`
- Need rollback help? Check rollback procedures above
- Performance not meeting targets? Check troubleshooting section in `DEPLOYMENT_REPORT.txt`

---

**Ready to proceed with Phase 1?** Start with chart attachment!

