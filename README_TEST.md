# 🚀 SMC_Universal Live Testing Guide

> **Status**: ✅ **READY FOR DEPLOYMENT**  
> **Date**: 2026-05-17  
> **Time to First Test**: ~5 minutes setup + 60 minutes live testing

---

## 📍 Where to Start

Pick one based on your needs:

### 👋 **New to the system?**
Start with **[START_HERE.md](START_HERE.md)** - 5-minute overview with FAQ

### ⚡ **Just want to start?**
Read **[READY.txt](READY.txt)** - 2-minute quick reference with exact steps

### 📋 **Need detailed deployment?**
Follow **[TEST_DEPLOYMENT.md](TEST_DEPLOYMENT.md)** - Step-by-step guide with verification

### 📊 **Want to test everything?**
Use **[LIVE_TEST_GUIDE.md](LIVE_TEST_GUIDE.md)** - Complete 1-hour test with success criteria

### 📖 **Technical deep dive?**
See **[SYSTEM_STATE.txt](SYSTEM_STATE.txt)** - Complete system architecture and state

---

## 🎯 The 5-Minute Start

```bash
# Step 1: Compile (2 min)
# Open MetaTerminal 5 → F4 → File → Open SMC_Universal.mq5 → F7 Compile
# Expect: "0 errors, 0 warnings"

# Step 2: Start Server (1 min)
cd D:\Dev\TradBOT\python
python ai_server.py
# Expect: "Uvicorn running on http://127.0.0.1:8000"

# Step 3: Load Robot (1 min)
# MT5 → Experts → SMC_Universal → Double-click
# Confirm inputs → Click OK

# Step 4: Verify (1 min)
# View → Toolbox → Experts → Check Journal
# Expect: "ML continuous training démarré/relancé"
```

**Then** follow [LIVE_TEST_GUIDE.md](LIVE_TEST_GUIDE.md) for the 60-minute test.

---

## 📚 Documentation Map

```
TradBOT/
├── README_TEST.md                    ← YOU ARE HERE
├── READY.txt                         ← Quick reference (2 min read)
├── START_HERE.md                     ← Overview & FAQ (5 min read)
├── TEST_DEPLOYMENT.md                ← Detailed steps (detailed checklist)
├── LIVE_TEST_GUIDE.md                ← Full test procedure (complete guide)
├── SYSTEM_STATE.txt                  ← Architecture & state (reference)
├── DEPLOYMENT_READY.txt              ← Checklist (quick validation)
│
├── SMC_Universal.mq5                 ← Main trading robot
├── python/ai_server.py               ← AI backend server
│
├── Figure chartiste/GOM_SIDO/        ← Visual reference
│   └── GOM_SIDO_unifie.pdf
└── Include/                          ← Trading logic modules
    ├── SMC_AutoTrader.mqh
    ├── SMC_OpportunityScanner.mqh
    └── ML_Scanner.mqh
```

---

## ✅ System Components Status

| Component | Status | Purpose |
|-----------|--------|---------|
| **SMC_Universal.mq5** | ✅ Ready | Main trading robot |
| **ai_server.py** | ✅ Ready | AI decision backend |
| **Dashboards** | ✅ Complete | GOM_SIDO verdict display |
| **Entry System** | ✅ Complete | Limit order placement |
| **ML Training** | ✅ Complete | Continuous learning |
| **Documentation** | ✅ Complete | Testing guides |

---

## 🎬 Quick Test Phases

### **Phase 1: Startup** (0-5 min)
- [ ] Code compiles
- [ ] Server starts
- [ ] Robot loads
- [ ] Dashboards appear

### **Phase 2: Signal** (5-20 min)
- [ ] OB+CHOCH detected
- [ ] Verdict calculated
- [ ] Limit order placed
- [ ] Waiting for fill

### **Phase 3: Execution** (20-45 min)
- [ ] Price touches entry
- [ ] Order fills
- [ ] Position manages to profit
- [ ] Position closes

### **Phase 4: Learning** (45-60 min)
- [ ] Feedback sent
- [ ] Metrics updated
- [ ] Accuracy displayed
- [ ] System ready for next signal

---

## 🔧 Configuration (Already Set)

These are pre-configured in MT5 Inputs:
```
AutoStartMLContinuousTraining = true
ShowMLMetrics = true
VerdictThresholdGOOD = 0.35
VerdictThresholdPERFECT = 0.65
AIServerURL = "http://127.0.0.1:8000"
```

---

## ❓ FAQs

**Q: How long before first trade?**  
A: 1-20 minutes. OB+CHOCH pattern needs to form first. M1 timeframe generates signals faster.

**Q: What if no signals appear?**  
A: This is normal. Patterns aren't guaranteed every minute. Try M1 timeframe, or different symbol (Volatility 75/100).

**Q: Where's the robot code?**  
A: `SMC_Universal.mq5` (26,902 lines). Functions are named clearly: `DisplayMTFDashboard()`, `DetectConfirmedOBWithCHOCH()`, etc.

**Q: Can I adjust settings?**  
A: Yes. Open MT5, right-click chart → Expert Advisors → Settings. But defaults are tested.

**Q: What symbols work?**  
A: Boom 1000 Index (primary test), Volatility 75/100 also tested.

**Q: Is the ML learning actually happening?**  
A: Yes. Check the metrics line on chart - you'll see samples count increase and accuracy value. After enough trades, accuracy should improve.

---

## 🚨 Troubleshooting

| Problem | Solution | Docs |
|---------|----------|------|
| Compilation error | Check syntax errors in SMC_Universal.mq5 | [SYSTEM_STATE.txt](SYSTEM_STATE.txt) |
| Can't connect to server | Verify ai_server.py running, check localhost:8000 | [START_HERE.md](START_HERE.md) |
| No signals after 30 min | Wait longer, try M1, try different symbol | [LIVE_TEST_GUIDE.md](LIVE_TEST_GUIDE.md) |
| Order placed but doesn't fill | Price must touch entry level exactly | [READY.txt](READY.txt) |
| Dashboard overlap | Already fixed (positions verified) | [SYSTEM_STATE.txt](SYSTEM_STATE.txt) |

See full troubleshooting in [START_HERE.md](START_HERE.md#troubleshooting-quick-reference).

---

## 📞 Reading Order

**For deployment:**
1. [READY.txt](READY.txt) - 2 min
2. [TEST_DEPLOYMENT.md](TEST_DEPLOYMENT.md) - 10 min
3. Start the test

**For understanding:**
1. [START_HERE.md](START_HERE.md) - 5 min
2. [SYSTEM_STATE.txt](SYSTEM_STATE.txt) - 10 min
3. [LIVE_TEST_GUIDE.md](LIVE_TEST_GUIDE.md) - reference during test

**For troubleshooting:**
See [START_HERE.md#troubleshooting-quick-reference](START_HERE.md#troubleshooting-quick-reference)

---

## 🎓 Key Concepts

### **OB+CHOCH Pattern**
Order Block + Change of Character = reversal pattern recognition

### **GOM_SIDO Verdict**
5-level system: WAIT/HOLD, BUY/SELL, GOOD, PERFECT (based on timeframe confluence)

### **Limit Orders**
Instead of market orders - enters at marked EMA M1 level for better price control

### **Multi-TP**
Position closes in 3 partial closes instead of all at once (TP1 33%, TP2 33%, TP3 33%)

### **ML Continuous Learning**
After each trade closes, feedback sent to server → model retrains → accuracy improves

---

## 🏁 Success Looks Like

After 1 hour:
- ✅ 2-5 signals generated
- ✅ 1-3 orders placed
- ✅ 0-2 trades executed
- ✅ Feedback sent to server
- ✅ Metrics displaying
- ✅ No errors or crashes

---

## 📊 Expected Results

| Timeframe | Metric | Expected |
|-----------|--------|----------|
| 0-5 min | System startup | No errors |
| 5-20 min | Signal detection | At least 1 pattern |
| 20-45 min | Trade execution | 0-2 trades |
| 45-60 min | Learning | Metrics updated |
| 1+ hour | Stability | System running smoothly |

---

## 🚀 Ready?

Start with **[READY.txt](READY.txt)** for the exact next steps.

Good luck! 🎯

---

**Status**: ✅ System ready for testing  
**Last Updated**: 2026-05-17 16:50 UTC
