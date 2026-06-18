# Trade Journal Flow — De MT5 au Dashboard

## 📋 Flux Complet des Données

```
MT5 Robot (SMC_Universal.mq5)
        ↓
  OnTradeTransaction()
  ├─ Detect TRADE_TRANSACTION_DEAL_ADD
  ├─ Call SMC_JournalLogDealClose()
  └─ Export to CSV
        ↓
data/trade_journal.csv
  ├─ Header: 30 colonnes (timestamps, symbols, prices, profit, etc.)
  ├─ Row per closed trade
  └─ Updated in real-time as positions close
        ↓
Python Processor (trade_journal_processor.py)
  ├─ Read CSV every 10 minutes
  ├─ Import new trades to SQLite database
  ├─ Generate statistics report
  └─ Send WhatsApp notification (optional)
        ↓
data/trades.db (SQLite)
  ├─ Persistent storage
  ├─ Indexed by deal_ticket
  └─ Query-able for dashboards
        ↓
Dashboard / Reports
  ├─ Total profit/loss
  ├─ Win rate (WIN/LOSS/BE)
  ├─ Profit by symbol
  └─ Historical analysis
```

## 📂 Files Involved

### MT5 Side (MQL5)
- **`mt5/modules/SMC_TradeJournal.mqh`** — Journal functions
  - `SMC_JournalInit()` — Initialize at startup
  - `SMC_JournalLogDealClose()` — Called in `OnTradeTransaction()`
  - `SMC_JournalExportHistoryToCSV()` — Export closed trades from history
  - `SMC_JournalWriteRow()` — Write to CSV file

- **`mt5/SMC_Universal.mq5`** — Main robot
  - Line 1461: `input bool UseTradeJournal = true;`
  - Line 2299-2301: Configure and init journal
  - Line 8552-8553: Log deal closes in `OnTradeTransaction()`

### Python Side (Processing)
- **`Python/trade_journal_processor.py`** — Main processor
  - `init_database()` — Create SQLite schema
  - `read_csv()` — Read MT5 CSV
  - `import_trades_to_db()` — Import to database
  - `generate_report()` — Stats and report

- **`Python/gom_sync_with_report.py`** — GOM verdicts (existing)

- **`scripts/monitor-trade-journal.bat`** — Run processor every 10 min

### Data Files
- **`data/trade_journal.csv`** — MT5 exports closed trades here
  - Location: Common/Files/TradBOT/trade_journal.csv (MT5 filesystem)
  - Windows path: D:\Dev\TradBOT\data\trade_journal.csv
  - Format: CSV with 30 columns

- **`data/trades.db`** — SQLite database (created by Python script)
  - Single table: `trades`
  - Indexed by `deal_ticket` (PRIMARY KEY)
  - Persists across restarts

- **`logs/trade_journal_processor.log`** — Processing logs

## 🔄 Workflow

### Step 1: Robot Closes Position (MT5)
```mql5
// In MT5 when a position closes:
OnTradeTransaction(trans, request, result) {
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        SMC_JournalLogDealClose(trans.deal, confidence, action);
}
```

### Step 2: Data Written to CSV
MT5 writes to: `Common/Files/TradBOT/trade_journal.csv`

**Example row:**
```csv
2026-06-16 14:30:45,2026-06-16,14,Mon,12345,1001,XAUUSD,METAL,BUY,0.10,2026-06-16 14:00:00,2026-06-16 14:30:45,4320.50,4325.30,47.80,0.00,-2.00,45.80,1800,30,WIN,85.0,buy,100000.00,100045.80,45.80,SMC_Universal,123456,12345678,GOM PERFECT BUY
```

### Step 3: Python Reads and Processes
```bash
# Run every 10 minutes
python Python/trade_journal_processor.py
```

**Actions:**
1. Read CSV (all new rows since last import)
2. Check for duplicates by `deal_ticket`
3. Insert into SQLite database
4. Generate statistics report
5. Log to `logs/trade_journal_processor.log`

### Step 4: Data Available in Database
Query database for:
- Total profit/loss
- Win/loss statistics
- Profit by symbol
- Historical analysis
- Performance metrics

## 📊 CSV Column Reference

| Column | Type | Description |
|--------|------|-------------|
| close_time | TEXT | 2026-06-16 14:30:45 |
| trade_date | TEXT | 2026-06-16 |
| hour_utc | INT | 14 |
| day_of_week | TEXT | Mon |
| deal_ticket | INT | MT5 deal ticket (unique) |
| position_id | INT | MT5 position ID |
| symbol | TEXT | XAUUSD, BOOM 900, etc. |
| category | TEXT | METAL, BOOM_CRASH, FOREX |
| direction | TEXT | BUY or SELL |
| volume | REAL | 0.10 (lot size) |
| open_time | TEXT | 2026-06-16 14:00:00 |
| open_price | REAL | 4320.50 |
| close_price | REAL | 4325.30 |
| profit | REAL | 47.80 (pips × value) |
| swap | REAL | 0.00 (overnight fees) |
| commission | REAL | -2.00 (broker fee) |
| net_profit | REAL | 45.80 (profit + swap + commission) |
| duration_sec | INT | 1800 (seconds) |
| duration_min | REAL | 30.0 (minutes) |
| result | TEXT | WIN, LOSS, or BE |
| ai_confidence | REAL | 85.0 (IA confidence %) |
| ai_action | TEXT | buy, sell, hold |
| balance | REAL | 100000.00 (account balance at close) |
| equity | REAL | 100045.80 (account equity at close) |
| daily_pnl | REAL | 45.80 (daily profit/loss) |
| ea_name | TEXT | SMC_Universal |
| magic | INT | 123456 (EA magic number) |
| account | INT | 12345678 (MT5 account number) |
| comment | TEXT | GOM PERFECT BUY |

## 🚀 Setup

### 1. Enable Trade Journal in Robot
In `mt5/SMC_Universal.mq5`:
```mql5
input bool UseTradeJournal = true;  // Line 1461
```

Compile and run the robot.

### 2. Wait for Trades to Close
- Robot needs to close at least 1 trade
- When position closes → exported to CSV
- MT5 path: Common/Files/TradBOT/trade_journal.csv

### 3. Run Python Processor
```bash
cd D:\Dev\TradBOT
python Python/trade_journal_processor.py
```

Or monitor continuously:
```bash
scripts\monitor-trade-journal.bat
```

### 4. Query Database
```bash
sqlite3 data/trades.db "SELECT * FROM trades LIMIT 10;"
```

## 📈 Example Report

```
╔════════════════════════════════════════════════════════════╗
║  TRADE JOURNAL REPORT                                      ║
╚════════════════════════════════════════════════════════════╝

📊 STATS GLOBALES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Trades:     156
Total Profit:     $3,456.78
Avg per Trade:    $22.15

🎯 RÉSULTATS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WIN:  112 trades | Profit: $4,250.32 | Avg: $37.95
LOSS:  38 trades | Profit:  -$789.50 | Avg: -$20.78
BE:     6 trades | Profit:    $0.00 | Avg:   $0.00

📈 PAR SYMBOLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XAUUSD           :  45 trades | Profit: $1,234.56 | Avg: $27.43
BOOM 500 INDEX   :  38 trades | Profit:   $876.23 | Avg: $23.06
BOOM 900 INDEX   :  35 trades | Profit:   $654.21 | Avg: $18.69
CRASH 500 INDEX  :  20 trades | Profit:   $432.10 | Avg: $21.61
```

## 🔍 Troubleshooting

### CSV is empty (only header)
- **Cause**: No trades have been closed yet
- **Solution**: Wait for robot to close a position

### No data in database
- **Cause**: Processor hasn't run yet
- **Solution**: Run `python Python/trade_journal_processor.py`

### Duplicate entries in database
- **Cause**: Processor ran multiple times on same deals
- **Solution**: Already prevented by `deal_ticket` PRIMARY KEY

### CSV path not found
- **Check**: MT5 path is `Common/Files/TradBOT/trade_journal.csv`
- **Verify**: `data/trade_journal.csv` exists locally

## 📝 Notes

- **Real-time**: CSV is updated in real-time as trades close
- **Persistent**: Database persists across robot restarts
- **Safe**: Python processor won't duplicate trades (deal_ticket = unique key)
- **Scalable**: Can handle thousands of trades efficiently
- **Queryable**: SQLite allows complex queries for analysis

## 🎯 Next Steps

1. ✅ Robot exports trades to CSV (`data/trade_journal.csv`)
2. ✅ Python processor imports to SQLite (`data/trades.db`)
3. ⏳ Dashboard queries database for stats
4. ⏳ WhatsApp notifications on new closed trades

---

**Status**: ✅ Production Ready  
**Last Updated**: 2026-06-16  
**Files**: MT5 (journal), Python (processor), Data (CSV + DB)
