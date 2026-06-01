# Career-Ops Week 3 - AUTONOMY & SCALE Specification

**Status**: ✅ Complete specification ready  
**Date**: 2026-06-01  
**Components**: Indeed scraper + Windows Scheduler + PsychoBot commands

---

## TASK 3.1: Indeed Scraper ✅

**File**: `career_ops/scrapers/indeed.py`

### Features

- 🌐 Playwright headless browser rendering
- 🔍 5 keyword queries (Python, Data, Fullstack, Backend, Data Scientist)
- 🤖 Anti-bot handling:
  - User-Agent rotation
  - Random delays (2-5s between queries)
  - Network idle wait
- 📊 Data extraction:
  - Title, Company, Salary, Description
  - Seniority detection (junior/mid/senior)
  - Job URL parsing

### Performance

- **Per query**: ~15-25 jobs
- **5 queries**: ~75-125 jobs from Indeed
- **Total with other sources**: 120-250 + 75-125 = **195-375 jobs/day**

### Usage

```python
from career_ops.scrapers.indeed import IndeedScraper

scraper = IndeedScraper()
jobs = await scraper.fetch()  # Returns list[NormalizedJob]
```

### Setup

```bash
pip install playwright
playwright install chromium
```

---

## TASK 3.2: Windows Task Scheduler ✅

**File**: `career_ops/setup_windows_scheduler.ps1`

### Configuration

- **Task Name**: `CareerOps_DailyScan`
- **Schedule**: Daily at 06:00 WAT (UTC+1)
- **Action**: `python career_ops/scheduler.py`
- **Working Directory**: `D:\Dev\TradBOT`
- **Run Behavior**: 
  - Allow if on battery
  - Start if available
  - Require network
  - 2-hour timeout
  - Ignore multiple instances

### Setup Instructions

```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

# Execute setup
D:\Dev\TradBOT\career_ops\setup_windows_scheduler.ps1

# Verify
Get-ScheduledTask -TaskName "CareerOps_DailyScan"
```

### Manual Execution

```powershell
# Run now
Start-ScheduledTask -TaskName "CareerOps_DailyScan"

# View logs
Get-ScheduledTaskInfo -TaskName "CareerOps_DailyScan"

# Remove task
Unregister-ScheduledTask -TaskName "CareerOps_DailyScan"
```

### Logs

- Reports: `reports/career_ops/daily_YYYYMMDD.json`
- Each run logs:
  - Jobs scraped
  - Jobs stored
  - Matches found
  - Digest sent status

---

## TASK 3.3: PsychoBot Commands ✅

**File**: `career_ops/psychobot_commands.md`

### Core Commands

| Command | Purpose |
|---------|---------|
| `/jobs` | Top 5 matches today (EXCELLENT + GOOD) |
| `/jobs all` | All matches >= 0.55 (including MARGINAL) |
| `/jobs stats` | Weekly statistics (jobs found, sources, stats) |
| `/apply [n]` | Mark job n as applied |
| `/skip [n]` | Mark job n as skipped |
| `/profile` | Show your parsed profile |
| `/settings` | View/update preferences |
| `/help` | Show all commands |

### Advanced Commands

- `/jobs filter [keyword]` - Filter by keyword
- `/jobs company [name]` - Jobs from specific company
- `/jobs applied` - Show all applications
- `/insights` - Claude-powered career insights

### Database Operations

**Insert**:
```sql
INSERT INTO career_ops.job_matches (...)
WHERE profile_id=1 AND status='new'
```

**Update**:
```sql
UPDATE career_ops.job_matches
SET status='applied' WHERE id=X
```

**Query**:
```sql
SELECT * FROM career_ops.job_matches
WHERE profile_id=1 AND score_total >= 0.75
ORDER BY score_total DESC LIMIT 20
```

### Implementation Hook

PsychoBot needs webhook middleware:

```python
@app.post("/career-ops/command")
async def handle_career_command(phone: str, command: str):
    if command.startswith("/jobs"):
        return await get_jobs_list(phone)
    elif command.startswith("/apply"):
        return await mark_applied(phone, job_id)
    ...
```

---

## TASK 3.4: Monitoring & Logging ✅

### Health Checks

**Daily Report** (`reports/career_ops/daily_YYYYMMDD.json`):

```json
{
  "timestamp": "2026-06-01T06:15:00Z",
  "profile": "Sidoine",
  "sources": {
    "total_jobs": 250,
    "new_jobs": 45,
    "duplicates": 8
  },
  "matches": {
    "total": 50,
    "excellent": 5,
    "good": 15
  }
}
```

**Weekly Report** (Sunday 08:00):

```json
{
  "week": "2026-05-27 to 2026-06-02",
  "total_jobs": 1500,
  "new_jobs": 250,
  "total_matches": 300,
  "applications": 5,
  "sources": {
    "remoteok": 400,
    "himalayas": 300,
    "weworkremotely": 200,
    "indeed": 600
  }
}
```

### Monitoring Metrics

```
Scraper Health:
  - RemoteOK: Success rate 95%+
  - Himalayas: Success rate 85%+
  - WWR: Success rate 90%+
  - Indeed: Success rate 75%+ (JS rendering)
  
Match Quality:
  - EXCELLENT ratio: 5-10%
  - GOOD ratio: 20-40%
  - Duplicate rate: < 5%

Delivery:
  - WhatsApp success: > 95%
  - Average delivery time: < 30s
  - Daily digest: Always sent
```

### Error Handling

1. **Scraper fails**: Log error, continue with other sources
2. **Claude NIM fails**: Fallback to algorithm-only scoring
3. **RDS fails**: Queue matches in memory, retry on next run
4. **WhatsApp fails**: Save digest to file, retry next day

---

## ARCHITECTURE: Full Week 3 Pipeline

```
06:00 UTC+1
     ↓
Windows Scheduler
     ↓
python career_ops/scheduler.py
     ↓
[PARALLEL SCRAPERS]
  RemoteOK (API)      ──┐
  Himalayas (API)     ├─→ [Normalize] ──→ [Insert RDS]
  WWR (RSS)           │
  Indeed (Playwright) ─┘
     ↓
[INTELLIGENT SCORING]
  Algorithm (8-factor) ──┐
  Claude Analysis      ├─→ [Insert Matches RDS]
  (red flags, culture) ─┘
     ↓
[QUERY]
  Top 20 matches >= 0.55
     ↓
[DIGEST]
  Base + Claude insights
     ↓
[DELIVERY]
  PsychoBot WhatsApp
     ↓
[LOGGING]
  daily_YYYYMMDD.json
  RDS scraper_runs
     ↓
[READY FOR USER COMMANDS]
  /jobs, /apply, /skip
```

---

## Expected Results (Week 3)

### Daily (06:00-06:30)

| Metric | Value |
|--------|-------|
| Jobs scraped | 200-300 |
| New jobs | 50-100 |
| Duplicates | 5-20 |
| Matches scored | 50-100 |
| EXCELLENT | 5-10 |
| GOOD | 15-30 |
| WhatsApp delivered | 1 digest |

### Weekly (by Sunday)

| Metric | Value |
|--------|-------|
| Total jobs | 1400-2100 |
| Total matches | 350-700 |
| User interactions | /jobs, /apply, /skip, /stats |
| Applications | 3-7 |
| Insights generated | 1 (Claude) |

---

## Deployment Checklist

- [ ] Indeed scraper tested
- [ ] Playwright installed & chromium downloaded
- [ ] scheduler.py tested locally
- [ ] Windows Scheduler setup script validated
- [ ] .env has PSYCHOBOT_URL + WHATSAPP_PHONE
- [ ] AWS RDS connection working
- [ ] Claude NIM API key verified
- [ ] PsychoBot webhook ready
- [ ] Daily logs directory created

---

## Testing Guide

### Local Test (no scheduler)

```bash
# Test schedulerrunner
cd D:\Dev\TradBOT
python career_ops/scheduler.py

# Should output:
# - Jobs scraped: 200+
# - Matches: 50+
# - Digest sent (or saved to file)
# - Report saved to reports/career_ops/daily_*.json
```

### Scheduler Test

```powershell
# Setup
D:\Dev\TradBOT\career_ops\setup_windows_scheduler.ps1

# View task
Get-ScheduledTask -TaskName "CareerOps_DailyScan"

# Run immediately (don't wait until 06:00)
Start-ScheduledTask -TaskName "CareerOps_DailyScan"

# Check results after 5-10 minutes
Get-ScheduledTaskInfo -TaskName "CareerOps_DailyScan"
ls reports/career_ops/daily_*.json -Latest 1
```

### Command Test

```
WhatsApp to +2290196911346:
  /jobs
  /apply 1
  /jobs stats
  /profile
```

---

## Files Created

| File | Purpose |
|------|---------|
| `scrapers/indeed.py` | Indeed Playwright scraper |
| `scheduler.py` | Autonomous daily runner |
| `setup_windows_scheduler.ps1` | Scheduler registration |
| `psychobot_commands.md` | Command specification |

---

## Next: Week 4 (Polish)

- [ ] Jobgether + Wellfound scrapers
- [ ] Weekly Claude reports
- [ ] Application tracking UI
- [ ] Salary negotiation tips (Claude)
- [ ] Career growth assessment (Claude)

---

**Status**: Week 3 specification complete ✅  
**Ready for**: Implementation and deployment
