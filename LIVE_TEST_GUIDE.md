# Live Testing Guide - Step by Step

## PRE-DEPLOYMENT CHECKLIST

### Step 1: Compilation
```
1. Ouvrir MetaTerminal 5
2. Appuyer sur F4 (MetaEditor)
3. File → Open → D:\Dev\TradBOT\SMC_Universal.mq5
4. Appuyer sur F5 (Compile)
5. Vérifier: "Compilation successful" (0 errors, 0 warnings)
```

✅ **Expected**: 0 errors, 0 warnings

---

## DEPLOYMENT STEPS

### Step 2: Start AI Server
```bash
1. Ouvrir terminal/CMD
2. cd D:\Dev\TradBOT\python
3. python ai_server.py
4. Attendre: "Listening on http://127.0.0.1:8000"
5. Tester endpoints:
   - http://localhost:8000/docs (Swagger API docs)
   - http://localhost:8000/health
```

✅ **Expected**: Server running, all endpoints available

---

### Step 3: Load EA into MT5

```
1. MetaTerminal 5 → Navigateur (F4)
2. Experts folder → SMC_Universal
3. Double-click ou drag onto chart
4. Confirm inputs dialog
5. Click OK
```

⚠️ **If not in Experts folder**:
```
Copy: D:\Dev\TradBOT\SMC_Universal.mq5
To: C:\Program Files\MetaTrader 5\MQL5\Experts\
Then: Refresh expert list in MT5
```

✅ **Expected**: EA loads, no errors in Journal

---

## INITIAL VERIFICATION (First 30 seconds)

### Step 4: Check Initialization Logs

**Open Journal tab (View → Toolbox → Experts)**

You should see:
```
[Time] SMC_Universal: OnInit() - Robot initialized
[Time] ✅ ML continuous training démarré/relancé.
[Time] 🟢 GOM_SIDO UNIFIED - Score: 0.825
[Time] ???? IA: premier sync /decision (démarrage EA)…
```

❌ **If errors appear**:
- Check AI server running
- Check Symbol exists (Boom 1000 Index recommended)
- Check inputs configured

✅ **Expected**: No errors, training started message

---

### Step 5: Visual Checks on Chart

**Look for these dashboards:**

#### Left Dashboard (Bottom-Left)
```
┌────────────────────────────────────┐
│ GOM_SIDO UNIFIED - Score: 0.825    │
├────────────────────────────────────┤
│ M1  │ M5  │ H1  │ IA CONF │ VERDICT│
│ 🟢  │ 🟢  │ 🟢  │ 87%    │PERFECT│
│ BUY │ BUY │ BUY │        │ BUY   │
└────────────────────────────────────┘
```

#### Right Dashboard (Bottom-Right, 200px from right edge)
```
⚙️ DÉCISION FINALE
🚀 PERFECT BUY
Score: 0.825 | Align: 3/3
M1:↑ M5:↑ H1:↑
IA: BUY (87%)
RSI:65.2 ATR:12.5
OB: Waiting...
Positions: 0 | Price: 10346.82
📊 80% Confluence + 20% IA
```

#### Entry Level Lines
```
- Green horizontal line (M1 EMA Fast)
- Green horizontal line (M5 EMA Fast)
- Green horizontal line (H1 EMA Fast)
```

#### ML Metrics (Top-Left)
```
ML (Boom/Crash, Boom 1000 Index): Accuracy: 87% | Model: XGBoost_v2.1
| Samples: 2,847 | Status: Active | Feedback: 156W/89L | Canal: OK
```

✅ **Expected**: All dashboards visible + entry lines visible

---

## SIGNAL & ENTRY VERIFICATION (Next 10 minutes)

### Step 6: Wait for OB+CHOCH Signal

**Monitor chart for:**
- Blue or red rectangle appearing (OB detection)
- Rectangle indicates CHOCH confirmed

**Journal logs:**
```
✅ OB+CHOCH Detected: Bullish (or Bearish)
```

⏳ **If nothing happens**: 
- Wait up to 10 minutes for pattern
- Check timeframe: Use M1 for faster signals
- Try different symbol (Volatility 75, 100)

✅ **Expected**: OB rectangle appears within 10 min

---

### Step 7: Watch for Limit Order Placement

**When OB+CHOCH detected + verdict GOOD/PERFECT:**

**Chart shows:**
- OB rectangle (blue/red)
- Entry level lines highlighted

**Journal logs:**
```
✅ LIMIT BUY Order Placed | Level: 10362.50
   SL: 10340.00
   TP1: 10370.00
   TP2: 10377.50
   TP3: 10385.00
```

✅ **Expected**: Limit order placed at EMA M1 level

---

## TRADE EXECUTION VERIFICATION (5-30 minutes)

### Step 8: Await Order Fill

**Price must touch entry level (EMA M1):**

**Journal logs:**
```
✅ Order Filled: BUY 0.2 @ 10362.50
✅ Position Opened: Ticket 123456789
```

**Chart shows:**
- Position line at entry price
- Green line for buy (or red for sell)
- SL line below entry
- TP line above entry

✅ **Expected**: Order fills when price touches entry level

---

### Step 9: Monitor Position Management

**TP1 Hit (First Target):**
```
✅ TP1 Target Hit: +7.50 pips
   Close 33% (0.067 lot)
   Remaining: 0.133 lot
```

**TP2 Hit (Second Target):**
```
✅ TP2 Target Hit: +15.00 pips
   Close 33% (0.067 lot)
   Remaining: 0.066 lot
```

**TP3 Hit (Final Close):**
```
✅ TP3 Target Hit: +22.50 pips
   Close 100% (0.066 lot)
   Position Closed: Profit +45.67$
```

✅ **Expected**: Position closes in 3 partial closes

---

## FEEDBACK & LEARNING VERIFICATION (10-15 minutes after close)

### Step 10: Verify Feedback Sent

**Journal logs (after position closes):**
```
?? ENVOI FEEDBACK IA - URL1: http://127.0.0.1:8000/trades/feedback
?? ENVOI FEEDBACK IA - Données: symbol=Boom 1000 Index profit=45.67 ai_conf=0.87
? FEEDBACK IA ENVOYÉ: Boom 1000 Index BUY Profit: 45.67 IA Conf: 0.87
```

✅ **Expected**: Feedback HTTP 200 response

---

### Step 11: Verify ML Metrics Updated

**Check ML dashboard (every 5 seconds):**
```
Before: Samples: 2,847 | Feedback: 156W/89L
After:  Samples: 2,848 | Feedback: 157W/89L
```

**Journal logs (every 5 minutes):**
```
✅ ML continuous training vérifié - Statut: RUNNING
GET /ml/metrics → Accuracy: 87.2% (was 87.1%)
```

✅ **Expected**: Sample count increases, accuracy improves

---

## FULL TEST CYCLE CHECKLIST

- [ ] **Code compiles**: 0 errors, 0 warnings
- [ ] **Server running**: ai_server.py active
- [ ] **EA loads**: OnInit completes without errors
- [ ] **Training starts**: "ML continuous training démarré" in journal
- [ ] **Left dashboard visible**: GOM_SIDO verdict shown
- [ ] **Right dashboard visible**: Comprehensive decision shown
- [ ] **Entry lines visible**: M1/M5/H1 EMA lines on chart
- [ ] **ML metrics visible**: Accuracy + model info on chart
- [ ] **OB+CHOCH detected**: Rectangle appears on chart
- [ ] **Limit order placed**: "Order Placed" message in journal
- [ ] **Order fills**: Position opens at entry level
- [ ] **Position monitored**: SL and TPs visible
- [ ] **TP1 hits**: Partial close 33%
- [ ] **TP2 hits**: Partial close 33%
- [ ] **TP3 hits**: Final close 33%
- [ ] **Feedback sent**: "FEEDBACK IA ENVOYÉ" in journal
- [ ] **Metrics updated**: Sample count increases
- [ ] **Accuracy improves**: Small increase over time

---

## COMMON ISSUES & SOLUTIONS

### Issue: "Cannot connect to AI server"
```
Solution:
1. Verify server running: python ai_server.py
2. Check URL in inputs: http://127.0.0.1:8000
3. Firewall: Allow Python/localhost
4. Restart EA (unload/reload)
```

### Issue: "No OB+CHOCH detected"
```
Solution:
1. Wait 10-15 minutes (pattern not always present)
2. Try different timeframe (M1 best for quick signals)
3. Try different symbol (Volatility 75 or 100)
4. Pattern requires specific market conditions
```

### Issue: "Limit order not placed"
```
Solution:
1. Check verdict: Must be GOOD or PERFECT
2. Check M1/M5 direction: Must align
3. Check H1: Must confirm direction
4. If WAIT/HOLD: No order placed (correct behavior)
```

### Issue: "Order placed but doesn't fill"
```
Solution:
1. Price must EXACTLY touch entry level
2. Market conditions may push price away
3. Wait for next signal (normal)
4. Position will fill when price returns to level
```

### Issue: "No feedback sent"
```
Solution:
1. Check server running: /trades/feedback endpoint
2. Check journal: Look for "ENVOI FEEDBACK" messages
3. If HTTP error: Check server logs
4. Restart EA to reconnect
```

### Issue: "ML metrics not updating"
```
Solution:
1. Check ShowMLMetrics = true
2. Check AutoStartMLContinuousTraining = true
3. Need at least 1 closed trade for feedback
4. Wait 5 minutes for next status check
5. Watch accuracy in metrics line
```

---

## EXPECTED RESULTS AFTER 1 HOUR

| Metric | Expected | Range |
|--------|----------|-------|
| Signals Generated | 2-5 | 1-10 depending on market |
| Orders Placed | 1-3 | 0-5 depending on verdict quality |
| Trades Executed | 0-2 | 0-3 depending on price action |
| Feedback Samples Sent | 0-2 | 0-3 trade results |
| Model Accuracy Displayed | 85-90% | Varies by model |
| Dashboard Updates | Continuous | Every tick |

---

## EXPECTED RESULTS AFTER 1 DAY

| Metric | Expected |
|--------|----------|
| Total Trades | 5-20 |
| Win Rate | 40-60% (normal) |
| Total P&L | -$200 to +$300 |
| Feedback Samples | 5-20 |
| Model Accuracy Change | +0.5% to +2% |
| System Stability | No crashes |

---

## MONITORING DASHBOARD

**Watch these in real-time:**

**Chart Level**:
- Entry lines (green/red)
- Position lines (open price)
- SL line (below entry)
- TP lines (above entry)

**Left Dashboard**:
- Timeframe directions (M1/M5/H1)
- Verdict level (WAIT/GOOD/PERFECT)
- Score value

**Right Dashboard**:
- Final decision
- IA confidence
- RSI/ATR values
- OB+OTE status

**Journal**:
- Order placements
- Feedback sends
- Error messages
- Training status

---

## TEST SUCCESS CRITERIA

✅ **Phase 1: Startup (0-1 min)**
- [ ] EA loads without errors
- [ ] Training initializes
- [ ] Dashboards appear

✅ **Phase 2: Signal (1-15 min)**
- [ ] OB+CHOCH detected
- [ ] Verdict calculated
- [ ] Limit order placed

✅ **Phase 3: Execution (15-30 min)**
- [ ] Price touches entry
- [ ] Order fills
- [ ] Position opens with SL/TP

✅ **Phase 4: Management (30-60 min)**
- [ ] Targets hit
- [ ] Position closes
- [ ] P&L recorded

✅ **Phase 5: Learning (60+ min)**
- [ ] Feedback sent
- [ ] Metrics updated
- [ ] Accuracy displayed

---

## FINAL VERIFICATION

Run for **1 full hour** and verify:

```
✅ No crashes
✅ All dashboards visible
✅ At least 1 signal generated
✅ At least 1 order placed
✅ Journal shows normal flow
✅ No errors repeated
✅ ML metrics display
✅ Feedback sending
```

**If all ✅**: System is READY for extended trading

**If any ❌**: Investigate error and fix before extended trading

---

**Status**: Ready for Live Test
**Recommendation**: Test on DEMO first (1 hour), then LIVE if successful
**Next Step**: Follow the steps above and monitor closely
