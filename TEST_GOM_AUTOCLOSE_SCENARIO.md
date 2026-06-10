# Test: GOM Auto-Close Feature

## Pre-Test Checklist
- [ ] TradeManager.mq5 compiled successfully (0 errors)
- [ ] MetaTrader 5 terminal running with live/demo data
- [ ] GOM_KOLA_script indicator visible on chart
- [ ] TradingView chart showing GOM verdict updates
- [ ] EA attached to XAUUSD M1 chart

## Scenario 1: GOM Good → WAIT Transition (Position Closes)

### Setup
1. Start with market trending: XAUUSD @ 2534.50
2. GOM verdict: GOOD (vnum=-2 for SELL setup)
3. Manually open SELL position @ 2534.50 (or let EA open it)

### Expected Behavior
1. Position open in Terminal with profit/loss
2. Observe GOM on TradingView:
   - Table shows "GOOD" with vnum=-2
3. Trigger condition: GOM shifts to WAIT:
   - Table shows "WAIT" with vnum=0
4. EA OnTick() fires:
   - Calls PollGOMScalpVerdict() → updates g_lastGOMVerdictNum = 0
   - Calls MonitorGOMWaitClosePositions()
   - Detects position open + GOM=WAIT
   - Closes position immediately
5. Check Terminal Log:
   ```
   [GOM-WAIT-CLOSE] ✅ XAUUSD fermée | entry=2534.50 pnl=-15.45 | verdict=WAIT (vnum=0)
   ```

### Pass Criteria
- ✅ Position closed within 5 seconds of GOM transition to WAIT
- ✅ Log message appears with correct entry price and P&L
- ✅ Position no longer shows in Terminal

---

## Scenario 2: GOM Stays WAIT → Multiple Calls, No Error

### Setup
1. GOM verdict steady: WAIT (vnum=0)
2. No positions open

### Expected Behavior
1. MonitorGOMWaitClosePositions() is called every OnTick()
2. Function detects: IsGOMVerdictWait() = true
3. Loop through positions: PositionsTotal() = 0
4. No positions to close → returns cleanly

### Pass Criteria
- ✅ No error messages in Terminal
- ✅ No crash or hang
- ✅ Function runs silently when no positions

---

## Scenario 3: WAIT → PERFECT Transition (No Close Needed)

### Setup
1. GOM verdict: WAIT (vnum=0)
2. No positions open
3. Condition: GOM improves to PERFECT (vnum=-3 for SELL)

### Expected Behavior
1. PollGOMScalpVerdict() updates: g_lastGOMVerdictNum = -3
2. MonitorGOMWaitClosePositions() called
3. IsGOMVerdictWait() returns false (vnum=-3 != 0)
4. Function exits early without attempting to close positions

### Pass Criteria
- ✅ CheckGOMAutoEntry() can now place NEW positions (PERFECT verdict)
- ✅ CheckGOMReEntry() can resume re-entry logic
- ✅ No spurious closes

---

## Scenario 4: Multiple Symbols, One Per Chart

### Setup
1. Attach TradeManager to XAUUSD M1 chart
2. Open SELL @ 2534.50
3. Switch to BTCUSD H1 chart
4. GOM shows WAIT on BTCUSD H1
5. Question: Should close XAUUSD position?

### Expected Behavior
- ❌ NO — because MonitorGOMWaitClosePositions() checks `if(posSymbol != _Symbol)`
- Line 647: `if(posSymbol != _Symbol) continue;`
- Only closes positions on current chart symbol (_Symbol = XAUUSD)

### Pass Criteria
- ✅ XAUUSD position remains open (different chart)
- ✅ No cross-chart interference

---

## Scenario 5: GOM=WAIT, Two Positions Open (Same Symbol)

### Setup
1. XAUUSD M1 with 2 open positions:
   - Position #1: BUY @ 2534.00, PnL +$25
   - Position #2: SELL @ 2535.00, PnL -$10
2. GOM verdict: GOOD (vnum=-2)
3. GOM transitions to WAIT (vnum=0)

### Expected Behavior
1. MonitorGOMWaitClosePositions() iterates backward (i--):
   - Closes Position #2 first
   - Log: `[GOM-WAIT-CLOSE] ✅ XAUUSD fermée | entry=2535.00 pnl=-10.00 | ...`
   - Closes Position #1 next
   - Log: `[GOM-WAIT-CLOSE] ✅ XAUUSD fermée | entry=2534.00 pnl=25.00 | ...`
2. Both positions closed

### Pass Criteria
- ✅ Both positions close
- ✅ Correct entry prices in logs
- ✅ P&L values accurate

---

## Scenario 6: Close Fails Due to Market Close (Rare)

### Setup
1. Market closed (weekend / early morning)
2. GOM verdict: WAIT (vnum=0)
3. Position open from previous session

### Expected Behavior
1. MonitorGOMWaitClosePositions() attempts: `tradeClose.PositionClose(ticket, 50)`
2. MT5 returns error: "Market closed" or similar
3. Condition: `if(tradeClose.PositionClose(ticket, 50))` = false
4. Log error message:
   ```
   [GOM-WAIT-CLOSE] ❌ XAUUSD erreur fermeture | ticket=12345 | ...
   ```

### Pass Criteria
- ✅ Error logged with ticket number
- ✅ Position persists (cannot close on closed market)
- ✅ No crash — EA continues running

---

## Live Test Procedure

1. **Compile & Deploy**
   ```bash
   # MetaEditor64.exe compiles TradeManager.mq5
   # Deploy to MT5 MQL5/Experts/
   ```

2. **Attach to Chart**
   - XAUUSD M1
   - Right-click → Expert Advisors → TradeManager

3. **Monitor**
   - Open Terminal → Experts tab
   - Watch for [GOM-WAIT-CLOSE] logs

4. **Trigger GOM Transition**
   - On TradingView, observe GOM_KOLA_script table
   - Wait for natural market movement that changes verdict
   - Or manually test by temporarily modifying chart timeframe to refresh

5. **Verify**
   - Position closes
   - Log message appears
   - P&L captured correctly

---

## Logging Reference

### Success Format
```
[GOM-WAIT-CLOSE] ✅ SYMBOL fermée | entry=PRICE pnl=PROFIT | verdict=WAIT (vnum=0)
```

### Error Format
```
[GOM-WAIT-CLOSE] ❌ SYMBOL erreur fermeture | ticket=TICKET | ERROR_MESSAGE
```

### Example Real Logs
```
2026-06-09 12:34:56.123 [GOM-WAIT-CLOSE] ✅ XAUUSD fermée | entry=2534.520 pnl=12.34 | verdict=WAIT (vnum=0)
2026-06-09 12:35:02.456 [GOM-WAIT-CLOSE] ✅ BTCUSD fermée | entry=67500.00 pnl=-45.67 | verdict=WAIT (vnum=0)
2026-06-09 12:35:45.789 [GOM-WAIT-CLOSE] ❌ XAUUSD erreur fermeture | ticket=987654 | Market closed
```

---

## Rollback Plan
If issues occur:
1. Detach EA from chart
2. Revert TradeManager.mq5 to previous version
3. Re-attach and verify

Changes are isolated to:
- Lines 636-667: New function
- Line 737: One additional call in OnTick()
