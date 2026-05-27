# SL/TP Bi-Directional Sync — Test Plan (Phase 5)

**Date**: 2026-05-26  
**Status**: Ready for Testing  
**Components**: 
- ✅ ai_server.py (Phase 1)
- ✅ tv_drawing_sync_service.py (Phase 2)
- ✅ TradeManager.mq5 (Phase 3)
- ✅ start_tv_drawing_sync.bat (Phase 4)

---

## Pre-Test Checklist

Before running tests:

- [ ] AI server running: `python ai_server.py` (should respond on http://127.0.0.1:8000)
- [ ] TradingView Desktop launched with MCP enabled
- [ ] TradingView chart set to XAUUSD on TradingView
- [ ] MetaTrader 5 terminal running with E6E3D0917DD641581E4779524EB3B1AA
- [ ] TradeManager.mq5 compiled in MT5 with 0 errors
- [ ] All Python dependencies installed: `pip install aiohttp`
- [ ] Logs directory writable: `D:\Dev\TradBOT\tv_drawing_sync.log`

---

## Test Scenarios

### Test 1: AI Server → TradingView (Pending Order Creates Chart Levels)

**Objective**: When a pending order is created via AI server, the tv_drawing_sync_service should automatically draw 3 horizontal lines on the TradingView chart.

**Prerequisites**:
- [ ] AI server running
- [ ] TradingView chart on XAUUSD visible
- [ ] tv_drawing_sync_service NOT yet running

**Steps**:

1. Start tv_drawing_sync_service:
   ```bash
   python Python/tv_drawing_sync_service.py --symbol XAUUSD --interval 5
   ```

2. In a separate terminal, create a pending order:
   ```bash
   curl -X POST http://127.0.0.1:8000/pending-order \
     -H "Content-Type: application/json" \
     -d '{
       "symbol": "XAUUSD",
       "action": "buy",
       "entry_price": 2650.50,
       "stop_loss": 2645.00,
       "take_profit": 2660.00,
       "lot": 0.01
     }'
   ```

3. Observe TradingView chart for 5-10 seconds

**Expected Results**:
- [ ] Three horizontal lines appear on XAUUSD chart
- [ ] Line labels: "ENTRY XAUUSD" (blue @ 2650.50), "SL XAUUSD" (red @ 2645.00), "TP XAUUSD" (green @ 2660.00)
- [ ] Console output shows: `📍 Drew SL XAUUSD @ 2645.00` etc.
- [ ] Logs file contains timestamp and line creation

**Logs to check**:
```
# tv_drawing_sync.log
2026-05-26 XX:XX:XX [INFO] 🆕 New order detected: <order_uuid>
2026-05-26 XX:XX:XX [INFO] 📍 Drew ENTRY XAUUSD @ 2650.50
2026-05-26 XX:XX:XX [INFO] 📍 Drew SL XAUUSD @ 2645.00
2026-05-26 XX:XX:XX [INFO] 📍 Drew TP XAUUSD @ 2660.00
```

---

### Test 2: TradingView Manual Change → AI Server (User Drags Line)

**Objective**: When user manually drags an SL/TP line on TradingView chart, the service detects the change and updates the pending order via PATCH /pending-order/{order_id}.

**Prerequisites**:
- [ ] Pending order exists in AI server (from Test 1 or new)
- [ ] 3 lines drawn on TradingView chart
- [ ] tv_drawing_sync_service running

**Steps**:

1. On TradingView, manually drag the "SL XAUUSD" line (red) to 2640.00

2. Wait 5-10 seconds for next poll interval

3. Check server logs and pending order state:
   ```bash
   curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD | jq '.orders[0] | {stop_loss, sl_update_source, last_sl_update}'
   ```

4. Verify:
   - [ ] `stop_loss` changed to 2640.00
   - [ ] `sl_update_source` is "tv_manual"
   - [ ] `last_sl_update` timestamp updated

**Expected Logs**:
```
2026-05-26 XX:XX:XX [INFO] ✅ Synced SL = 2640.00 to order <order_id>
```

---

### Test 3: MT5 Auto SL/TP → AI Server → TradingView

**Objective**: When TradeManager.mq5 executes AutoSetSLTP() for a manual position, it calls SyncSLTPToServer which updates the pending order, and tv_drawing_sync_service redraw chart lines.

**Prerequisites**:
- [ ] TradeManager.mq5 loaded in MT5 and running (not just compiled)
- [ ] `UseMCPSignals = true` and `AutoAssignSLTP = true` in inputs
- [ ] tv_drawing_sync_service running

**Steps**:

1. Manually create a position in MT5:
   - Symbol: XAUUSD
   - Type: BUY (or SELL)
   - Lot: 0.01
   - **Leave SL and TP EMPTY** (this triggers AutoSetSLTP)

2. Wait for TradeManager to detect the position (check interval ~5 sec)

3. AutoSetSLTP() should execute and call SyncSLTPToServer()

4. Check MT5 logs:
   ```
   [TradeManager] ✅ AUTO SL/TP XAUUSD SL=2645.00 TP=2660.00
   [TradeManager] ✅ Synced SL/TP to server: orderId=<uuid> SL=2645.00 TP=2660.00
   ```

5. Verify TradingView lines moved (should redraw 3 lines at new prices)

**Expected Results**:
- [ ] Position now has SL and TP in MT5
- [ ] MT5 logs show "AUTO SL/TP" and "Synced SL/TP to server"
- [ ] TradingView lines move to new SL/TP levels (or drawn if new)
- [ ] API server shows `stop_loss`, `take_profit`, `sl_update_source="ea_auto"`

---

### Test 4: MT5 Trailing Stop → AI Server → TradingView

**Objective**: When TradeManager.mq5 trailing stop triggers and calls PositionModify(), it calls SyncSLTPToServer with "ea_trailing" source, and lines redraw on chart.

**Prerequisites**:
- [ ] Position open in MT5 with SL/TP
- [ ] `UseTrailing = true` in inputs
- [ ] Price moving in profit direction (so trailing stop activates)
- [ ] tv_drawing_sync_service running

**Steps**:

1. Open a BUY position on XAUUSD:
   - Entry: 2650.00
   - SL: 2645.00
   - TP: 2660.00

2. Wait for price to move up (into profit)
   - Trailing stop should activate when profit > TrailActivatePct % of SL distance
   - TradeManager will call PositionModify() with new SL

3. Check MT5 logs for trailing update:
   ```
   [TradeManager] 📈 XAUUSD Trailing SL 2645.00→2647.00 (profit=$50 peak=$50)
   [TradeManager] ✅ Synced SL/TP to server: ... update_source=ea_trailing
   ```

4. Verify on TradingView that SL line (red) moved up to 2647.00

**Expected Results**:
- [ ] SL line on chart moves closer to entry as profit grows
- [ ] Logs show "Trailing SL" and "update_source=ea_trailing"
- [ ] AI server shows `sl_update_source="ea_trailing"`
- [ ] No manual line drag detected (real-time sync working)

---

### Test 5: Server Order Update → TradingView (Redraw Consistency)

**Objective**: When pending order is updated via PATCH /pending-order/{id}, and order status hasn't changed, the tv_drawing_sync_service should redraw lines at new prices.

**Prerequisites**:
- [ ] Pending order exists with 3 lines on chart
- [ ] tv_drawing_sync_service running

**Steps**:

1. Update pending order SL/TP via API:
   ```bash
   curl -X PATCH http://127.0.0.1:8000/pending-order/<order_id> \
     -H "Content-Type: application/json" \
     -d '{
       "stop_loss": 2643.00,
       "take_profit": 2665.00,
       "update_source": "server"
     }'
   ```

2. Wait 5-10 seconds for next service poll

3. Check TradingView chart for line movement

**Expected Results**:
- [ ] SL line moved to 2643.00
- [ ] TP line moved to 2665.00
- [ ] ENTRY line unchanged (unless also updated)
- [ ] Logs show order change detected and lines redrawn

---

## Conflict Resolution Tests

### Test 6: Avoid Feedback Loop (TV Manual → Server → TV Draw)

**Objective**: Ensure that when user updates line on TV, the service doesn't re-sync it back causing a feedback loop.

**Steps**:

1. Drag SL line from 2645.00 to 2640.00 on TradingView

2. Wait for first sync (should see "✅ Synced SL = 2640.00")

3. Continue watching TradingView for next 30 seconds

**Expected Results**:
- [ ] Line stays at 2640.00 (doesn't jump around)
- [ ] No repeated sync logs for the same change
- [ ] No "📍 Drew SL" immediately after sync (that would indicate loop)

**Rationale**: Source tracking ("tv_manual") prevents re-drawing the line it just synced.

---

### Test 7: Order Executed → Stop Syncing Drawings

**Objective**: Once an order is executed, the service should not try to sync SL/TP changes (only pending orders sync).

**Steps**:

1. Create pending order and draw lines

2. Manually execute the order in MT5:
   - Open position at entry price
   - Mark order status as "executed"

3. Update SL/TP on the pending order

4. Wait for next poll cycle

**Expected Results**:
- [ ] Service checks order status
- [ ] If status="executed", service skips sync attempts
- [ ] Logs show appropriate status check

---

## Performance & Stress Tests

### Test 8: Multiple Symbols Poll Rate

**Objective**: Verify service handles polling multiple symbols without lag.

**Steps**:

1. Create pending orders for: XAUUSD, BTCUSD, EURUSD

2. Run service with default 5-second interval

3. Check response time:
   ```bash
   time curl http://127.0.0.1:8000/pending-order?symbol=XAUUSD
   ```

**Expected Results**:
- [ ] Each symbol polled within 5 second window
- [ ] No timeout errors (timeout is 10s per request)
- [ ] Logs show all symbols checked each cycle

---

### Test 9: Network Hiccup Recovery

**Objective**: Service should gracefully handle temporary network issues.

**Steps**:

1. Service running normally

2. Temporarily stop AI server

3. Wait 10-20 seconds

4. Restart AI server

5. Check logs

**Expected Results**:
- [ ] Logs show WebRequest failed (HTTP code != 200)
- [ ] Service continues polling (doesn't crash)
- [ ] When server comes back online, normal operation resumes
- [ ] No orphaned connections or resource leaks

---

## Integration Tests

### Test 10: Full E2E Flow (Order → Chart → MT5 → Chart Update)

**Objective**: Complete end-to-end verification of all 4 sync directions.

**Steps**:

1. **Start services**:
   - `python ai_server.py`
   - `python tv_drawing_sync_service.py --symbol XAUUSD --interval 5`
   - Load TradeManager.mq5 in MT5

2. **Create pending order**:
   ```bash
   curl -X POST http://127.0.0.1:8000/pending-order \
     -H "Content-Type: application/json" \
     -d '{"symbol":"XAUUSD","action":"BUY","entry_price":2650,"stop_loss":2645,"take_profit":2660,"lot":0.01}'
   ```
   - Check TradingView for 3 lines ✓ (Test 1)

3. **Manual TV change**:
   - Drag SL line to 2640 on TradingView
   - Wait 5-10 seconds
   - Verify API shows stop_loss=2640 ✓ (Test 2)

4. **MT5 Auto SL/TP**:
   - Create position manually without SL/TP
   - Wait for AutoSetSLTP
   - Verify sync logs show "ea_auto" ✓ (Test 3)

5. **MT5 Trailing Stop**:
   - Wait for price to profit
   - Trailing stop triggers
   - Verify SL line moved on chart ✓ (Test 4)

6. **Check final state**:
   - All lines on chart match pending order SL/TP
   - No sync errors in any logs
   - All 4 directions worked seamlessly

**Expected Results**:
- [ ] All sub-tests pass
- [ ] No conflicts or feedback loops
- [ ] Data consistency maintained across all systems

---

## Cleanup & Validation

After all tests:

- [ ] Delete test pending orders: `DELETE /pending-order?symbol=XAUUSD`
- [ ] Close test positions in MT5
- [ ] Clear TradingView drawings: `draw_clear` via MCP or manually
- [ ] Collect logs:
  - `tv_drawing_sync.log`
  - MT5 terminal logs (Journal)
  - Console output
- [ ] Archive logs for review: `logs/2026-05-26-sltp-sync-tests.zip`

---

## Sign-Off

| Component | Test Status | Notes |
|-----------|-------------|-------|
| Phase 1 (AI Server endpoints) | ⏳ Pending | PATCH + POST endpoints ready |
| Phase 2 (TV Drawing Sync) | ⏳ Pending | Service ready, MCP wrappers verified |
| Phase 3 (MT5 Sync Calls) | ⏳ Pending | Code added, file copied to Terminal |
| Phase 4 (Automation) | ✅ Ready | start_tv_drawing_sync.bat created |
| **Overall Sync** | ⏳ Ready for Testing | All components in place |

---

**Next**: Run tests 1-10 sequentially, updating sign-off as each passes.
