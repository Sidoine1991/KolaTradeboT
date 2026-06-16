# GOM Sync + WhatsApp Report System

**Autonomous 10-minute synchronization loop** for live MT5 trading signals → WhatsApp notifications.

## Overview

Every 10 minutes, the system:
1. **Loads** GOM verdicts from MT5 live dashboard (`/gom-kola-dashboard`)
2. **Applies gates** (RSI, M15 trend, session windows, Boom/Crash direction rules)
3. **Processes changes** (WAIT→close, GOOD→PERFECT→market order)
4. **Places orders** (if coherence ≥85% and no position exists)
5. **Builds report** (formatted with TF directions + ML scores)
6. **Sends WhatsApp** (AI server → PsychoBot fallback)

## Quick Start

### Option A: Windows Task Scheduler (Recommended)

**Setup** (one-time):
```powershell
# Run as Administrator
cd D:\Dev\TradBOT
.\schedule_gom_sync_10min.ps1
```

**Verify**:
```powershell
Get-ScheduledTask -TaskName "TradBOT-GOM-Sync-10min"
```

### Option B: Python Daemon (Best for Server)

**Start**:
```cmd
# Terminal 1 (stays open, Ctrl+C to stop)
cd D:\Dev\TradBOT
python Python/gom_sync_with_report.py
```

**Or via batch**:
```cmd
start_gom_daemon.bat
```

### Option C: Manual Loop

```cmd
# Terminal
cd D:\Dev\TradBOT
start_gom_sync_10min_loop.bat
```

## Architecture

```
┌─────────────────────────────────────────┐
│   GOM SYNC DAEMON (10 min loop)         │
├─────────────────────────────────────────┤
│ 1. GET /gom-kola-dashboard (MT5 live)   │
│    - Fallback: GET /gom-verdicts         │
│    - Fallback: Load gom_signal.json      │
├─────────────────────────────────────────┤
│ 2. GATES                                │
│    - RSI > 78 (BUY) or < 22 (SELL)      │
│    - M15 trend coherence                │
│    - Session trading windows            │
│    - Boom=BUY only, Crash=SELL only     │
│    - Coherence >= 85% to place          │
├─────────────────────────────────────────┤
│ 3. ACTIONS                              │
│    - WAIT (prev verdict) → close pos    │
│    - GOOD → PERFECT → market order      │
│    - Place market orders                │
├─────────────────────────────────────────┤
│ 4. REPORT                               │
│    - Build: symbol, verdict, SL/TP      │
│    - Add: TF directions (M1-D1)         │
│    - Add: ML scores (if available)      │
├─────────────────────────────────────────┤
│ 5. NOTIFY                               │
│    - POST /notify-whatsapp (AI server)  │
│    - Fallback: PsychoBot Render         │
├─────────────────────────────────────────┤
│ 6. LOG                                  │
│    - Write: logs/gom_sync.log           │
│    - Timestamps + verdicts + errors     │
└─────────────────────────────────────────┘
```

## Configuration

### Environment Variables

```bash
# .env or system env
AI_SERVER=http://127.0.0.1:8000
PSYCHOBOT_URL=https://psychobot-1si7.onrender.com
WHATSAPP_PHONE_NUMBER=+2290196911346
```

### Gates (Hardcoded)

```python
# From gom_sync_with_report.py

RSI_OVERBOUGHT = 78      # BUY rejected if RSI > 78
RSI_OVERSOLD = 22        # SELL rejected if RSI < 22

MIN_COHERENCE = 85%      # Orders placed only if coherence >= 85%

SESSION_WINDOWS = {
    "XAUUSD": (7, 17),      # UTC hours
    "BTCUSD": (8, 22),
    "ETHUSD": (8, 22),
    "NAS100": (13, 20),
    "US30": (13, 20),
}

# Boom/Crash: unidirectional
BOOM: BUY only (vn > 0)
CRASH: SELL only (vn < 0)
```

## Report Format

```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 BOOM 900 INDEX — GOOD BUY | Entry: 9145.91 | SL: 9143.34 | TP: 9158.94 | Coh: 67%
  🟢M1 🟢M5 🟢M15 ⚪H1 🟢H4 🔴D1
  🤖 ML: 🟢BUY 92% | acc=68%

🔴 CRASH 500 INDEX — GOOD SELL | Entry: 2986.12 | SL: 2989.92 | TP: 2978.51 | Coh: 67%
  ⚪M1 ⚪M5 ⚪M15 ⚪H1 🔴H4 🔴D1

==================================================
📅 2026-06-16 15:52:43 UTC
```

**Legend**:
- 🟢 = BULL/BUY
- 🔴 = BEAR/SELL
- ⚪ = NEUT/WAIT
- M1-D1 = Timeframe directions
- Coh = Coherence %
- ML = Machine Learning score

## Logs

**Location**: `D:\Dev\TradBOT\logs\gom_sync.log`

**Example**:
```
2026-06-16 15:52:36 - INFO - [SYNC] Exécution unique GOM sync...
2026-06-16 15:52:37 - WARNING - [GATE-M15] BOOM 1000 INDEX: M15=BEAR opposé à BUY — rejeté
2026-06-16 15:52:43 - INFO - [OK] Charge 3 verdicts GOM depuis dashboard MT5 LIVE
2026-06-16 15:52:43 - WARNING - [GATE-COH] BOOM 900 INDEX: cohérence 67% < 85% — ordre ignoré
2026-06-16 15:52:43 - INFO - 📤 BOOM 900 INDEX → GOOD BUY (HTTP 200)
2026-06-16 15:52:43 - INFO - ✅ Rapport WhatsApp envoyé via AI server
```

## Troubleshooting

### Logs show "AI server indisponible"

**Fix**: Ensure AI server is running
```bash
# Check if ai_server is responding
curl http://127.0.0.1:8000/gom-verdicts
```

### WhatsApp report not delivered

**Check**:
1. `logs/gom_sync.log` for errors
2. WhatsApp phone number in `WHATSAPP_PHONE_NUMBER`
3. PsychoBot Render is online: `https://psychobot-1si7.onrender.com`

### No verdicts loaded

**Fix**: Check MT5 connection
```bash
# Get status from dashboard
curl "http://127.0.0.1:8000/gom-kola-dashboard?symbol=XAUUSD&chart_tf=M1"
```

### Orders not being placed

**Check**:
1. Coherence < 85%? (`[GATE-COH]` in logs)
2. M15 trend opposite? (`[GATE-M15]` in logs)
3. Position already open? (`[GATE-POS]` in logs)
4. Trading pause active? (`[GATE-PAUSE]` in logs)

## Execution Modes

### Mode 1: Infinite Loop (Production)

```bash
python Python/gom_sync_with_report.py
# No arguments = loop every 10 minutes indefinitely
```

### Mode 2: Single Shot

```bash
python Python/gom_sync_with_report.py --report
# --report flag = execute once and exit
```

### Mode 3: Windows Task Scheduler

```powershell
.\schedule_gom_sync_10min.ps1
# Creates recurring task (every 10 minutes)
```

## Performance

| Metric | Value |
|--------|-------|
| Loop interval | 10 minutes (600s) |
| Dashboard fetch timeout | 5s |
| ML score fetch timeout | 3s |
| WhatsApp send timeout | 30s |
| Log file | append mode (no rotation) |

**Typical cycle time**: 2-5 seconds (mostly HTTP calls)

## Integration

### AI Server Endpoints Used

- `GET /gom-kola-dashboard` → Live MT5 verdicts
- `GET /gom-verdicts` → Stored verdicts
- `POST /gom-verdict` → Send verdict + SL/TP
- `GET /ml-metrics/{symbol}` → ML scores
- `POST /pending-order` → Place market orders
- `POST /gom-verdict/close-request` → Close positions
- `GET /pending-orders` → Open positions
- `GET /trading-pause` → Win-streak pause status
- `POST /notify-whatsapp` → Send WhatsApp

### PsychoBot Integration

**Fallback endpoint**: `POST https://psychobot-1si7.onrender.com/send-message`

```json
{
  "phone": "+2290196911346",
  "message": "📊 GOM VERDICTS REPORT..."
}
```

## Status

✅ **PRODUCTION READY** (2026-06-16)

Last test:
- ✅ 3 verdicts loaded from MT5
- ✅ Gates applied correctly
- ✅ Report formatted properly
- ✅ WhatsApp delivered via AI server

---

**Maintained by**: TradBOT Autonomous System
**Last updated**: 2026-06-16 15:52:43 UTC
