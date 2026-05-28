# SL/TP Bi-Directional Sync — Test Plan

## Setup

1. Start AI Server
   ```bash
   python ai_server.py --port 8000
   ```
   Expected: Server starts at http://127.0.0.1:8000

2. Verify health
   ```bash
   curl http://127.0.0.1:8000/health
   ```
   Expected: {"ok": true, ...}

3. Start TV Drawing Sync Service
   ```bash
   python Python/tv_drawing_sync_service.py --symbol XAUUSD
   ```
   Expected: Logs show "🚀 Starting TradingView Drawing Sync for XAUUSD"

4. Compile and attach TradeManager to XAUUSD M1

---

## Test 1: Server Persistence

### Scenario: Pending orders survive server restart

**Steps**:
1. POST order to AI server
   ```bash
   curl -X POST http://127.0.0.1:8000/pending-order \
     -H "Content-Type: application/json" \
     -d '{
       "symbol": "XAUUSD",
       "action": "BUY",
       "entry_price": 4450.00,
       "stop_loss": 4440.00,
       "take_profit": 4460.00,
       "lot": 0.01
     }'
   ```

2. Verify stored:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD
   ```
   Expected: Returns order with stop_loss=4440.00

3. Stop ai_server (Ctrl+C)

4. Restart ai_server
   ```bash
   python ai_server.py --port 8000
   ```
   Check logs for: "[PendingOrders] Loaded 1 orders from disk"

5. Verify order still there:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD
   ```
   Expected: Order persisted, shows stop_loss=4440.00

**Result**: ✅ PASS if order survives restart

---

## Test 2: TradingView → AI Server (Manual Update)

### Scenario: User draws SL line on chart, sync service detects and PATCHes

**Prerequisites**:
- TV Drawing Sync service running
- TradingView XAUUSD chart open
- GOM KOLA indicator visible
- Pending order exists in AI server

**Steps**:
1. On TradingView, draw horizontal line at 4445.00
2. Right-click line → Edit → Label field → type "SL XAUUSD"
3. Watch TV Sync logs (terminal)

**Expected Logs**:
```
🆕 New SL line detected at 4445.00
✅ Synced SL=4445.00 to XAUUSD (source=tv_manual)
```

4. Move line up to 4446.00
5. Expected: After 5 seconds:
```
📍 SL moved: 4445.00 → 4446.00
✅ Synced SL=4446.00 to XAUUSD (source=tv_manual)
```

6. Verify AI server has new value:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD | jq '.order.stop_loss'
   ```
   Expected: 4446.00

**Result**: ✅ PASS if line moves sync to server with correct values

---

## Test 3: MT5 Auto SL/TP → AI Server

### Scenario: EA sets SL/TP via AutoSetSLTP, calls SyncSLTPToServer

**Prerequisites**:
- TradeManager attached to XAUUSD M1
- BUY order can execute

**Steps**:
1. Create pending order with entry=4450, no SL/TP initially
2. Price touches entry (or manually trigger)
3. EA executes trade
4. AutoSetSLTP() fires (or manual PositionModify)
5. Watch TradeManager logs:
   ```
   ✅ AUTO SL/TP XAUUSD SL=4440 TP=4460
   ✅ SL/TP synced to server: symbol=XAUUSD ticket=123456 SL=4440 TP=4460 source=ea_auto
   ```

6. Verify AI server updated:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD | jq '.order.stop_loss, .order.take_profit'
   ```
   Expected: 4440 and 4460

7. Check sync metadata:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD | jq '.order | {last_sl_update, sl_update_source, mt5_ticket}'
   ```
   Expected: Shows sl_update_source="ea_auto", mt5_ticket=123456

**Result**: ✅ PASS if EA SL/TP reaches server with correct source

---

## Test 4: MT5 Trailing Stop → AI Server

### Scenario: Position profit increases, trailing stop tightens SL

**Prerequisites**:
- Position open on XAUUSD BUY at 4450
- SL=4440, TP=4460, Profit=$50+
- UseTrailing=true

**Steps**:
1. Price moves to 4465 (profit=$150)
2. TradeManager trailing stop activates
3. Watch logs for:
   ```
   📈 XAUUSD Trailing SL 4440→4450 (profit=$150 peak=$150)
   ✅ SL/TP synced to server: symbol=XAUUSD ticket=123456 SL=4450 TP=4460 source=ea_trailing
   ```

4. Verify peak_profit in server:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD | jq '.order.metadata'
   ```
   Expected: trailing_active=true, peak_profit=150

**Result**: ✅ PASS if trailing SL syncs with source="ea_trailing"

---

## Test 5: Conflict Detection (GOM vs Manual)

### Scenario: User draws TP that contradicts GOM verdict

**Note**: This is Phase 5 future work, but can verify no crashes

**Steps**:
1. GOM verdict is "GOOD SELL" (score_sell=6.0)
2. User draws "TP XAUUSD" line
3. Service detects and syncs
4. Check AI server logs — should log but not crash
   ```
   [SLTPSync] Updated XAUUSD: SL=... TP=... source=tv_manual
   [Warning] Manual TP may conflict with GOM SELL verdict (optional log)
   ```

**Result**: ✅ PASS if no 500 errors, sync completes

---

## Test 6: Multiple Symbols (Scalability)

### Scenario: Run service with multiple symbols

**Steps**:
1. Prepare pending orders for XAUUSD and BTCUSD in AI server
2. Modify TV Sync service to run dual instance (or write test script)
3. Draw SL lines on both charts
4. Verify each syncs independently:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD | jq '.order.stop_loss'
   curl http://127.0.0.1:8000/pending-order?symbol=BTCUSD | jq '.order.stop_loss'
   ```
   Expected: Each shows correct SL

**Result**: ✅ PASS if no crosstalk between symbols

---

## Performance Targets

| Metric | Target | Result |
|--------|--------|--------|
| TV poll latency | <500ms | |
| Sync PATCH latency | <200ms | |
| MT5 SyncSLTPToServer latency | <1s | |
| Persistence save time | <100ms | |
| Memory (TV service) | <50MB | |
| Memory (AI server delta) | <10MB | |

---

## Rollback Plan

If tests fail:

1. **AI Server won't start**: Check syntax with `python -m py_compile ai_server.py`
2. **TV Sync crashes**: Run with `--server http://127.0.0.1:8000` verbose mode, check MCP CLI path
3. **TradeManager compilation fails**: Check SyncSLTPToServer() function for typos
4. **Pending orders not persisting**: Ensure `data/` dir exists, check file permissions

**Rollback steps**:
1. Revert ai_server.py to previous git version
2. Delete Python/tv_drawing_sync_service.py
3. Recompile TradeManager with original SyncSLTPToServer

---

## Sign-Off

After all 6 tests pass:
- [ ] Performance targets met
- [ ] No crashes or 500 errors
- [ ] All logs clean (warnings OK, errors NOT OK)
- [ ] Ready for production

