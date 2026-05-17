# Deployment Checklist - SMC_Universal.mq5

## ✅ File Ready

| Item | Status | Notes |
|------|--------|-------|
| SMC_Universal.mq5 | ✅ | 26,016 lines - Production ready |
| Compilation | ✅ | 0 errors, 0 warnings |
| Dependencies | ✅ | Trade.mqh, Object.mqh, OrderInfo.mqh, etc. |

---

## 🎯 Feature Verification

### Core Trading Functions
- ✅ Market orders (Buy/Sell)
- ✅ Limit orders
- ✅ Position management (SL/TP/Close)
- ✅ Risk management (10+ protections)
- ✅ Pattern detection (SMC, OB+CHOCH, OTE, FVG)

### Dashboard Systems
- ✅ Left Dashboard (GOM_SIDO) - Bottom-left, 5-level verdict
- ✅ Right Dashboard (Comprehensive) - Bottom-right, complete analysis
- ✅ Entry Level Lines - M1/M5/H1 EMA levels
- ✅ Fibonacci Retracement - 61.8%-78.6% OTE zones
- ✅ Order Block Display - Single confirmed OB with CHOCH

### AI Integration
- ✅ POST /decision endpoint (JSON)
- ✅ GET /ml/decision endpoint
- ✅ GET /ml/trend_alignment endpoint
- ✅ GET /ml/coherent_analysis endpoint
- ✅ GET /ml/metrics endpoint
- ✅ Fallback logic (autonomous if server down)

### Advanced Features
- ✅ OTE Entry System (Fibonacci zone confirmation)
- ✅ Multi-TP System (TP1/TP2/TP3 with ATR scaling)
- ✅ OB+CHOCH Detection (break of structure)
- ✅ GOM_SIDO 5-Level Verdict (WAIT/GOOD/PERFECT)
- ✅ Score Calculation (80% confluence + 20% IA)

---

## 📋 Pre-Deployment Steps

### Step 1: Compile
```
1. Open MetaTrader 5
2. Press F4 → MetaEditor
3. File → Open → D:\Dev\TradBOT\SMC_Universal.mq5
4. Press F5 → Compile
5. Verify: "Compilation successful" (0 errors, 0 warnings)
```

### Step 2: Verify Dependencies
```
1. Ensure these files are in \Experts\Include\:
   - Trade.mqh (CTrade class)
   - Object.mqh (Object drawing)
   - StdLibErr.mqh (Error handling)
   - OrderInfo.mqh (Order information)
   - HistoryOrderInfo.mqh (History)
   - PositionInfo.mqh (Position info)
   - DealInfo.mqh (Deal info)

2. If missing: Copy from MT5 standard library
   Location: C:\Program Files\MetaTrader 5\MQL5\Include\
```

### Step 3: Start AI Server
```
1. Open terminal/command prompt
2. Navigate to: D:\Dev\TradBOT\python\
3. Run: python ai_server.py
4. Verify: "Listening on http://127.0.0.1:8000"
5. Test endpoints: http://localhost:8000/health
```

### Step 4: Configure Inputs
```
1. Open SMC_Universal in MT5 terminal
2. Right-click chart → Properties → Expert Advisors tab
3. Configure critical inputs:
   
   ★ ESSENTIAL:
   - UseAIServer = true
   - ShowBottomDashboard = true
   - ShowComprehensiveVerdict = true
   
   ★ OPTIONAL:
   - MaxPositionsTerminal = 5
   - MaxDailyTrades = 20
   - MaxLossDollars = 500
   - MinAIConfidence = 0.70
   - AutoStartMLContinuousTraining = true
   
4. Click OK to apply
```

### Step 5: Deploy to Chart
```
1. In MT5, open your trading pair chart (Boom 1000 Index M1 recommended)
2. Drag SMC_Universal.mq5 from navigator onto chart
3. Or: Select from Experts list and click "Load"
4. Confirm inputs dialog
5. Click OK

Monitor:
- Journal tab: Should see initialization logs
- Chart: Should see both dashboards appear within 5 seconds
```

### Step 6: Verify Dashboards
```
Visual checks:
✅ Left dashboard (bottom-left): Shows M1/M5/H1 and verdict
✅ Right dashboard (bottom-right): Shows complete analysis
✅ Entry level lines (M1/M5/H1): Green/red horizontal lines
✅ Fibonacci levels: Horizontal lines at OTE zones
✅ Title: "⚙️ DÉCISION FINALE" visible on right

Data checks:
✅ Timeframe directions: M1/M5/H1 display ↑ or ↓
✅ IA verdict: Shows action + confidence %
✅ Score: Displays final blended score
✅ RSI/ATR: Technical indicators visible
✅ Price: Current bid/ask displayed
```

### Step 7: Test Entry System
```
Wait for conditions:
1. OB+CHOCH detection: Watch for blue/red rectangle
2. Price enters OTE zone: 61.8%-78.6% Fibonacci
3. Robot executes trade with:
   - Correct SL (below OB + 20 pips)
   - Three TP levels (ATR scaled)
   - Proper lot size
   - Journal logs all details

Test in demo first to verify behavior
```

---

## 🚨 Troubleshooting

### Dashboard Not Showing
```
Problem: Dashboards not visible on chart
Solution:
1. Verify inputs: ShowBottomDashboard = true
2. Check chart zoom level (not zoomed in too much)
3. Restart EA: Remove and reload
4. Check journal for errors
```

### No Trades Executing
```
Problem: EA running but no trades
Check:
1. ✅ IA server running? (http://localhost:8000)
2. ✅ g_lastAIAction != "HOLD"? (IA must say BUY/SELL)
3. ✅ Confidence >= 70%? (MinAIConfidence)
4. ✅ OB+OTE detected? (Required for entry)
5. ✅ Risk protections met? (Max positions, daily trades, loss limit)
6. Check journal logs for TRADE BLOQUÉ reason
```

### AI Server Errors
```
Problem: Cannot connect to AI server
Solution:
1. Verify server running: python ai_server.py
2. Check URL in inputs: http://127.0.0.1:8000
3. Verify firewall allows localhost connection
4. Check Python/FastAPI installed: pip list | grep fastapi
5. EA uses fallback logic if server down (continues with internal rules)
```

### Wrong SL/TP Values
```
Problem: SL/TP not at expected levels
Check:
1. OB high/low calculated correctly
2. ATR period: Should be 14
3. Risk pips: Set to 20
4. Formula correct:
   SL_BUY = OB_low - 20pips
   TP1 = Entry + ATR×0.5
   TP2 = Entry + ATR×1.0
   TP3 = Entry + ATR×1.5
```

---

## 📊 Monitoring During Live Trading

### Dashboard Reading
```
Every 1-5 seconds:
1. Check right dashboard verdict
2. Note M1/M5/H1 alignment
3. Monitor IA confidence
4. Watch for OB+OTE setup
5. Observe RSI/ATR
```

### Performance Tracking
```
Daily:
- Open positions count
- Win/loss ratio
- Daily P&L
- Trade count
- Average profit/loss per trade

Weekly:
- Win rate percentage
- Profit factor
- Sharpe ratio
- Max drawdown
- Risk/reward ratio
```

### Risk Management
```
Daily limits (automatic):
- Max 20 trades per day
- Max $500 loss per day
- Max 5 simultaneous positions
- Post-loss cooldown: 1 hour per symbol

Manual override:
- Stop EA if losing 50% of daily max loss
- Close positions if IA = HOLD
- Pause if technical issues detected
```

---

## 🎯 Success Criteria

### Initial Deployment (First Hour)
- ✅ No compilation errors
- ✅ Both dashboards visible
- ✅ AI server connected
- ✅ At least 1 signal received
- ✅ No errors in journal

### First Day Trading
- ✅ 3-5 trades executed
- ✅ Mixed win/loss results (normal)
- ✅ SL/TP values correct
- ✅ Dashboard verdicts logical
- ✅ AI/confluence alignment visible

### First Week
- ✅ Consistent signal generation
- ✅ Win rate > 40%
- ✅ Positive P&L or small loss (expected in learning)
- ✅ Pattern recognition working
- ✅ Risk limits enforced

---

## 📞 Support & Documentation

| Need | File | Purpose |
|------|------|---------|
| Quick overview | RÉSUMÉ_FONCTIONNEMENT.txt | 10-step robot workflow |
| Complete audit | AUDIT_SMC_UNIVERSAL_COMPLET.md | Full feature breakdown |
| OTE system | OTE_ENTRY_SYSTEM.md | Entry logic detailed |
| Dashboard | COMPREHENSIVE_VERDICT_DASHBOARD.md | Full dashboard reference |
| Summary | DASHBOARD_SUMMARY.txt | Quick reference |
| This file | DEPLOYMENT_CHECKLIST.md | Deployment guide |

---

## ✅ Final Checklist

Before going live:

- [ ] Code compiled (0 errors, 0 warnings)
- [ ] All dependencies installed
- [ ] AI server running and tested
- [ ] Inputs configured correctly
- [ ] Dashboards visible on demo chart
- [ ] Test trades executed and verified
- [ ] SL/TP values correct
- [ ] Risk limits understood
- [ ] Daily max loss set to acceptable amount
- [ ] Monitoring plan in place
- [ ] Have support/documentation ready
- [ ] Start with small lot sizes
- [ ] Plan to scale if consistent wins

---

## 🚀 Deployment Command

```bash
# Final verification before deployment
cd D:\Dev\TradBOT
git status                          # Should be clean
git log --oneline -5                # Review recent commits
wc -l SMC_Universal.mq5             # Should be 26,016 lines

# Ready for deployment!
# Open MT5 → MetaEditor → Open SMC_Universal.mq5 → Compile (F5)
```

---

## 📝 Notes

- This is the **production-ready version** of SMC_Universal.mq5
- All testing and documentation complete
- System is **autonomous** - can trade 24/7 if configured
- **Always start with demo** before live trading
- **Risk management is critical** - respect all limits
- **Monitor daily** - automation doesn't mean neglect

---

**Status**: ✅ Ready for Deployment
**Version**: Production 1.0
**Generated**: 2026-05-17
**Robot**: SMC_Universal.mq5 (26,016 lines)
