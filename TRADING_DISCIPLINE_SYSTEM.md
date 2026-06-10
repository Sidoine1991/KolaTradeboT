# 🎯 Trading Discipline System — Max 7 Trades/Day + $20 Target

## Objectives
1. **Max 7 trades per day** (00:00 → 23:59)
2. **Daily profit target: $20** → STOP all new entries once reached
3. **Auto-reset every midnight** (UTC)
4. **Block entries at both limits** — no exceptions

## Implementation

### Global Variables (Lines 239-241)
```mql5
int      g_dailyTradeCount   = 0;      // Compteur trades ouverts aujourd'hui
int      g_maxDailyTrades    = 7;      // Max 7 trades par jour (DISCIPLINE)
double   g_dailyProfitTarget = 20.0;   // Cible: 20$ de profit → STOP entrées
```

### Core Functions

#### 1. **CanEnterTrade()** (Lines 640-660)
Checks BEFORE any entry if trading is allowed:
- ✅ Returns true if BOTH conditions met:
  - Daily P&L < $20 target
  - Trade count < 7
- ❌ Returns false and logs reason if:
  - Target $20 reached → "Cible profit +$20.00 atteinte"
  - 7 trades reached → "7/7 trades atteint"

```mql5
bool CanEnterTrade(const string reason = "")
{
   double closedPnl = CalcDailyClosedProfit();
   if(closedPnl >= g_dailyProfitTarget) return false;  // STOP
   if(g_dailyTradeCount >= g_maxDailyTrades) return false;  // STOP
   return true;  // ALLOWED
}
```

#### 2. **RegisterTradeEntry()** (Lines 662-668)
Called AFTER position opens successfully:
- Increments g_dailyTradeCount
- Logs: `[DISCIPLINE] ✅ TRADE #X/7 | type=SOURCE | PnL=$XX.XX | Entrées restantes: Y`
- Example: `[DISCIPLINE] ✅ TRADE #3/7 | type=GOM-AutoEntry | PnL=$12.34 | Entrées restantes: 4`

```mql5
void RegisterTradeEntry(const int direction, const string entryType = "")
{
   g_dailyTradeCount++;
   double closedPnl = CalcDailyClosedProfit();
   int remaining = g_maxDailyTrades - g_dailyTradeCount;
   Print(StringFormat("[DISCIPLINE] ✅ TRADE #%d/%d | ... | Entrées restantes: %d",
         g_dailyTradeCount, g_maxDailyTrades, remaining));
}
```

#### 3. **DisplayDisciplineStatus()** (Lines 670-688)
Displays status every 30 minutes in logs:
```
[DISCIPLINE STATUS] ═══════════════════════════════════════════
  Trades: 3/7 (✅ OK) | Cible: $12.34/$20.00 (...) | Entrées restantes: 4
  Status Global: 🟢 TRADING ACTIF — NORMAL
═══════════════════════════════════════════════════════════════════
```

When limits reached:
```
[DISCIPLINE STATUS] ═══════════════════════════════════════════
  Trades: 7/7 (❌ MAXED) | Cible: $22.50/$20.00 (✅ ATTEINT) | Entrées restantes: 0
  Status Global: 🛑 TRADING DESACTIF — MAX TRADES ET CIBLE
═══════════════════════════════════════════════════════════════════
```

#### 4. **CheckDailyProfitTarget()** (Lines 3870-3878)
Enhanced at midnight:
- Resets g_dailyTradeCount = 0
- Prints: `[DISCIPLINE] Nouveau jour — balance=$10000 | Objectif: +0% | Max 7 trades | Cible: +$20`

### Entry Points Protected (4 Main Routes)

#### ✅ GOM Auto-Entry (Line 5503)
```mql5
if(!CanEnterTrade("GOM-AutoEntry")) return;
```
After position opens → RegisterTradeEntry(dir, "GOM-AutoEntry")

#### ✅ GOM Re-Entry (Line 5713)
```mql5
if(!CanEnterTrade("GOM-ReEntry")) return;
```
After position opens → RegisterTradeEntry(dir, "GOM-ReEntry")

#### ✅ GOM Re-Entry Trailing (Line 5807)
```mql5
RegisterTradeEntry(dir, "GOM-ReEntry");  // Inside success block
```

#### ✅ MCP Signal Entry (Line 4531)
```mql5
if(!CanEnterTrade("MCP-Signal")) return;
```
After position opens → RegisterTradeEntry(dir, "MCP-Signal")

### Daily Reset Logic (Line 3853)
```mql5
datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
if(today != g_dailyResetDate)
{
   g_dailyResetDate = today;
   g_dailyTargetHit = false;
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyTradeCount = 0;  // 🆕 RESET COUNTER
   // ...print new day stats
}
```

## Log Examples

### Normal Trading Day
```
2026-06-09 00:00:05 [DISCIPLINE] Nouveau jour — balance=$10000 | Objectif: +0% ($0) | Max 7 trades | Cible: +$20
2026-06-09 08:15:30 [DISCIPLINE] ✅ TRADE #1/7 | direction=BUY type=GOM-AutoEntry | PnL=$5.20 | Entrées restantes: 6
2026-06-09 08:45:15 [DISCIPLINE] ✅ TRADE #2/7 | direction=SELL type=GOM-AutoEntry | PnL=$12.30 | Entrées restantes: 5
2026-06-09 09:30:00 [DISCIPLINE STATUS] ═══════════════════════════════════════════
  Trades: 2/7 (✅ OK) | Cible: $12.30/$20.00 (...) | Entrées restantes: 5
  Status Global: 🟢 TRADING ACTIF — NORMAL
```

### Target Reached → Stop Entries
```
2026-06-09 14:20:10 [DISCIPLINE] ✅ TRADE #3/7 | direction=BUY type=MCP-Signal | PnL=$20.50 | Entrées restantes: 4
2026-06-09 14:20:11 [DISCIPLINE] ❌ BLOQUE: Cible profit +$20.50 atteinte | raison: GOM-AutoEntry
2026-06-09 14:20:12 [DISCIPLINE] ❌ BLOQUE: Cible profit +$20.50 atteinte | raison: GOM-AutoEntry
```

### Max Trades Reached → Stop Entries
```
2026-06-09 16:45:30 [DISCIPLINE] ✅ TRADE #7/7 | direction=SELL type=GOM-ReEntry | PnL=$18.75 | Entrées restantes: 0
2026-06-09 16:45:31 [DISCIPLINE] ❌ BLOQUE: 7/7 trades atteint | raison: GOM-AutoEntry
2026-06-09 17:00:00 [DISCIPLINE STATUS] ═══════════════════════════════════════════
  Trades: 7/7 (❌ MAXED) | Cible: $18.75/$20.00 (...) | Entrées restantes: 0
  Status Global: 🛑 TRADING DESACTIF — MAX TRADES
```

### End of Day Summary
```
2026-06-09 23:59:55 [DISCIPLINE STATUS] ═══════════════════════════════════════════
  Trades: 5/7 (✅ OK) | Cible: $19.87/$20.00 (PROCHE!) | Entrées restantes: 2
  Status Global: 🟢 TRADING ACTIF — NORMAL (FIN DE JOUR)
```

## Behavior Matrix

| Status | Trades | P&L | Can Enter? | Action |
|--------|--------|-----|----------|--------|
| Morning | 0/7 | $0 | ✅ YES | Trade normally |
| Mid-day | 3/7 | $15 | ✅ YES | Trade normally |
| Limit 1 | 7/7 | $18 | ❌ NO | BLOCK all entries |
| Limit 2 | 2/7 | $20+ | ❌ NO | BLOCK all entries |
| Both | 7/7 | $25 | ❌ NO | BLOCK all entries |
| Midnight | 5/7 | $19 | ✅ YES | Reset counter → Trade (new day) |

## Configuration

To modify limits, edit:
```mql5
// Line 241
int      g_maxDailyTrades    = 7;      // Change to 5, 10, etc.

// Line 242
double   g_dailyProfitTarget = 20.0;   // Change to 25.0, 15.0, etc.
```

## Files Modified
- `TradeManager.mq5`
  - Lines 239-241: Global variables
  - Lines 640-688: Core discipline functions
  - Line 756: DisplayDisciplineStatus() in OnTimer()
  - Lines 3853: Daily reset counter
  - Lines 5503, 5713: GOM guards
  - Lines 4531, 4751, 5807: Entry registration

## Status: 🟢 Ready for Testing
- ✅ All 4 entry points guarded
- ✅ Daily reset at midnight
- ✅ Status display every 30 min
- ✅ Logs track every trade and limit hit

## Testing Checklist
- [ ] Compile → 0 errors
- [ ] Trade 3 times → verify counter increments
- [ ] Reach $20 → verify entries block
- [ ] Reach 7 trades → verify entries block
- [ ] Check logs → verify [DISCIPLINE] messages
- [ ] Wait until midnight → verify counter resets to 0
- [ ] Check status display → verify every 30 min

