# Autonomous Loops Integration — AI Server Built-in

## 🎯 Overview

All autonomous trading loops are now **integrated into `ai_server.py`** as background tasks. No need for separate terminal windows!

## 📋 Integrated Loops

| Loop | Interval | Purpose |
|------|----------|---------|
| `gom_poller` | 30s | MT5 live candles → GOM verdicts |
| `gom_sync` | 10min | GOM verdicts POST + WhatsApp reports |
| `pipeline` | 1h | Order placement with anti-duplication |
| `recycler` | 5min | Cancel stale orders + replace on better signals |

## 🚀 Quick Start

### Option 1: Start All Loops (Recommended)

```bash
curl -X POST http://127.0.0.1:8000/autonomous/start-all
```

**Response:**
```json
{
  "status": "all_loops_started",
  "loops": ["gom_poller", "gom_sync", "pipeline", "recycler"],
  "timestamp": "2026-06-12T18:03:39.123456+00:00"
}
```

### Option 2: Start Individual Loops

```bash
# Start GOM poller
curl -X POST http://127.0.0.1:8000/autonomous/start/gom_poller

# Start GOM sync
curl -X POST http://127.0.0.1:8000/autonomous/start/gom_sync

# Start pipeline
curl -X POST http://127.0.0.1:8000/autonomous/start/pipeline

# Start recycler
curl -X POST http://127.0.0.1:8000/autonomous/start/recycler
```

## 📊 API Endpoints

### Start a Loop
```
POST /autonomous/start/{loop_name}
```
**Response:** Loop status + start time

### Stop a Loop
```
POST /autonomous/stop/{loop_name}
```
**Response:** Loop status + stop time

### Run Loop Once (Manual)
```
POST /autonomous/run/{loop_name}
```
**Response:** Execution status + exit code

### Start All Loops
```
POST /autonomous/start-all
```
**Response:** All loops started

### Stop All Loops
```
POST /autonomous/stop-all
```
**Response:** All loops stopped

### Get Status
```
GET /autonomous/status
```
**Response:**
```json
{
  "scheduler_running": true,
  "loops": {
    "gom_poller": {
      "enabled": true,
      "interval": 30,
      "last_run": "2026-06-12T18:03:39Z",
      "script": "Python/gom_mt5_poller.py"
    },
    "gom_sync": {
      "enabled": true,
      "interval": 600,
      "last_run": "2026-06-12T18:02:15Z",
      "script": "Python/gom_sync_with_report.py"
    },
    "pipeline": {
      "enabled": true,
      "interval": 3600,
      "last_run": "2026-06-12T17:15:42Z",
      "script": "Python/pipeline_hourly_autonomous.py"
    },
    "recycler": {
      "enabled": true,
      "interval": 300,
      "last_run": "2026-06-12T18:00:15Z",
      "script": "Python/order_recycler.py"
    }
  },
  "timestamp": "2026-06-12T18:03:39.123456+00:00"
}
```

### List Available Loops
```
GET /autonomous/loops-available
```
**Response:**
```json
{
  "available_loops": {
    "gom_poller": {
      "script": "Python/gom_mt5_poller.py",
      "interval_seconds": 30,
      "description": "gom_poller loop (runs every 30s)"
    },
    "gom_sync": {
      "script": "Python/gom_sync_with_report.py",
      "interval_seconds": 600,
      "description": "gom_sync loop (runs every 600s)"
    },
    "pipeline": {
      "script": "Python/pipeline_hourly_autonomous.py",
      "interval_seconds": 3600,
      "description": "pipeline loop (runs every 3600s)"
    },
    "recycler": {
      "script": "Python/order_recycler.py",
      "interval_seconds": 300,
      "description": "recycler loop (runs every 300s)"
    }
  },
  "total": 4
}
```

## 🔄 Flow Diagram

```
[Start ai_server]
    ↓
[API Ready + Background Scheduler]
    ↓
[POST /autonomous/start-all]
    ↓
[All 4 Loops Running in Background]
    │
    ├→ [GOM Poller every 30s]
    │   └→ MT5 → GOM verdicts
    │
    ├→ [GOM Sync every 10min]
    │   └→ Verdicts POST + WhatsApp
    │
    ├→ [Pipeline every 1h]
    │   └→ Order placement
    │
    └→ [Recycler every 5min]
        └→ Cancel old + replace
    ↓
[Monitor via GET /autonomous/status]
```

## 📝 Example: Complete Startup Sequence

```bash
# 1. Start ai_server (loops integrated)
python ai_server.py

# 2. In another terminal, start all loops
curl -X POST http://127.0.0.1:8000/autonomous/start-all

# 3. Check status
curl http://127.0.0.1:8000/autonomous/status

# 4. Monitor WhatsApp for alerts (GOM reports every 10min)

# 5. To stop all loops
curl -X POST http://127.0.0.1:8000/autonomous/stop-all
```

## ✅ Benefits

✅ **Single Process** — No more 4 separate terminal windows
✅ **Centralized Control** — Start/stop loops via HTTP API
✅ **Real-time Status** — GET /autonomous/status anytime
✅ **Automatic Scheduling** — All intervals maintained perfectly
✅ **Clean Shutdown** — POST /autonomous/stop-all terminates gracefully
✅ **Logging** — All loop activities logged to `logs/ai_server.log`

## 🛠️ Integration Steps (For Developers)

### 1. Import in ai_server.py

```python
from autonomous_loops import AutonomousLoopsManager, loops_manager
from autonomous_routes import create_autonomous_router

# Create router
autonomous_router = create_autonomous_router(loops_manager)

# Add to FastAPI app
app.include_router(autonomous_router)
```

### 2. Startup Event

```python
@app.on_event("startup")
async def startup():
    # Optionally start all loops on server startup
    # await loops_manager.start_all_loops()
    logger.info("[STARTUP] AI Server ready with autonomous loops")
```

## 📊 Monitoring Dashboard (Future)

Could add a web dashboard at `/autonomous/dashboard` showing:
- Real-time status of all 4 loops
- Last execution times + exit codes
- Error log for failed iterations
- One-click start/stop controls

## 🚀 Production Setup

**Minimal setup (one terminal):**
```bash
# Terminal 1: Start ai_server with all autonomous loops
python ai_server.py &

# That's it! All loops run automatically in the background
```

**Monitor status:**
```bash
# Check status anytime
curl http://127.0.0.1:8000/autonomous/status

# Watch logs
tail -f logs/ai_server.log | grep LOOPS
```

---

**Your trading system is now fully self-contained in ai_server! 🎯🚀**
