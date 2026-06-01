# Career-Ops Service Deployment on Render
## Standalone FastAPI Service (Port 8001)

**Date**: 2026-06-01  
**Status**: Ready for Render deployment  

---

## 🏗️ ARCHITECTURE

```
Render (Cloud)
├─ Service 1: ai_server.py (port 8000)
│  └─ Trading (GOM poller, TradingAgents, etc.)
│
└─ Service 2: Career-Ops Service (port 8001) ← NEW
   ├─ FastAPI (career_ops_service.py)
   ├─ Endpoints: /api/career-ops/*
   ├─ Scheduler: Runs job prospection
   └─ Database: AWS RDS for persistence
```

---

## 📋 FILES CREATED

```
career_ops_service.py           [100 lines]
  └─ Standalone FastAPI app
  └─ Imports career_ops_api_rds
  └─ Ready for Render

Procfile-career-ops             [2 lines]
  └─ web: uvicorn server
  └─ scheduler: daily job run

requirements-career-ops.txt     [7 packages]
  └─ FastAPI, psycopg2, dotenv, etc.

DEPLOY_CAREEROPS_RENDER.md      [This file]
  └─ Step-by-step deployment guide
```

---

## 🚀 STEP 1: CREATE NEW RENDER SERVICE

### In Render Dashboard:

1. **New Web Service**
   - Name: `career-ops` (or `career-ops-service`)
   - Environment: `Python`
   - Build Command: `pip install -r requirements-career-ops.txt`
   - Start Command: `python career_ops_service.py`

2. **Environment Variables**
   ```
   DATABASE_URL=postgresql://dbadmin:REMOVED_DB_PASSWORD@trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com:5432/postgres
   PSYCHOBOT_URL=https://psychobot-1si7.onrender.com
   WHATSAPP_PHONE=+2290196911346
   EMAIL_ADDRESS=syebadokpo@gmail.com
   ENVIRONMENT=production
   PORT=8001
   ```

3. **GitHub Integration**
   - Connect your TradBOT repo
   - Branch: `main` (or your branch)
   - Auto-deploy on push

4. **Instance Type**
   - Choose: `Starter` or `Standard` (depending on traffic)

5. **Create Service**
   - Click "Create Web Service"
   - Wait for build & deploy (5-10 minutes)

---

## 🔧 STEP 2: CONFIGURE FOR DAILY PROSPECTION

### Option A: Render Cron Job (Recommended)

Create a new **Background Worker** on Render:

1. **New Background Worker**
   - Name: `career-ops-scheduler`
   - Environment: `Python`
   - Build Command: `pip install -r requirements-career-ops.txt`
   - Start Command: `python career_ops_scheduler_rds.py`

2. **Schedule**: Set cron trigger
   - Daily at 06:00 WAT
   - Cron format: `0 6 * * *` (if Render uses UTC, adjust to WAT offset)

Actually, Render doesn't have native cron. Use Option B instead.

### Option B: External Scheduler (Better)

Use **EasyCron** or **AWS Lambda** to trigger Career-Ops daily:

1. **Set up webhook endpoint** on Career-Ops service:
   ```
   POST /api/career-ops/trigger-prospection
   ```

2. **Call from external cron** (EasyCron, Lambda, etc.):
   ```bash
   curl -X POST https://career-ops-xxxxx.onrender.com/api/career-ops/trigger-prospection
   ```

3. **Schedule**: Daily at 06:00 WAT

### Option C: Local Scheduler (What you had)

Keep running `career_ops_scheduler_rds.py` on your Windows machine via Task Scheduler at 06:00 WAT. Career-Ops service on Render just serves the API.

---

## 📊 STEP 3: VERIFY DEPLOYMENT

### Check Service is Online

```bash
# Health check
curl https://career-ops-xxxxx.onrender.com/health

# Should return:
{
  "status": "healthy",
  "service": "Career-Ops",
  "version": "1.0.0"
}
```

### Test API Endpoints

```bash
# Get status
curl https://career-ops-xxxxx.onrender.com/api/career-ops/status

# Get jobs (after scheduler runs)
curl https://career-ops-xxxxx.onrender.com/api/career-ops/jobs/best-matches

# Get stats
curl https://career-ops-xxxxx.onrender.com/api/career-ops/stats
```

### Check Logs

In Render Dashboard:
- Service → Logs tab
- Look for: "Career-Ops Service starting..."
- Check for errors

---

## 🔗 STEP 4: CONNECT TO PSYCHOBOT

### Update PsychoBot Frontend

Instead of localhost:
```javascript
// ❌ OLD (local)
const API_URL = 'http://localhost:8000/api/career-ops'

// ✅ NEW (Render)
const API_URL = 'https://career-ops-xxxxx.onrender.com/api/career-ops'
```

### Test Connection

```javascript
fetch('https://career-ops-xxxxx.onrender.com/api/career-ops/jobs/best-matches')
  .then(r => r.json())
  .then(data => console.log(data))
```

---

## 📅 STEP 5: SETUP DAILY SCHEDULER

### Option C (Recommended): Windows Task Scheduler

Keep on your machine (where we configured it):

```batch
@echo off
REM career_ops_daily.bat
python D:\Dev\TradBOT\career_ops_scheduler_rds.py

REM Then notify Render service (optional)
curl -X POST https://career-ops-xxxxx.onrender.com/api/career-ops/log-run
```

Schedule at 06:00 WAT via Windows Task Scheduler.

### Option B (Alternative): EasyCron Service

1. Go to **easycron.com**
2. Create new cron job:
   - URL: `https://career-ops-xxxxx.onrender.com/api/career-ops/schedule-prospection`
   - Cron: `0 6 * * *` (6 AM UTC, adjust for WAT)
3. Save

---

## 🔄 DATA FLOW (After Deployment)

```
06:00 WAT (Windows Task Scheduler OR EasyCron)
    ↓
career_ops_scheduler_rds.py runs
    ├─ Scrapes 11 job sources
    ├─ Scores against profile
    └─ Persists to AWS RDS

AWS RDS (career_ops schema)
    ├─ career_ops.jobs ← New jobs inserted
    ├─ career_ops.job_matches ← Scores calculated
    └─ career_ops.scraper_runs ← Execution logged

Career-Ops Service on Render (port 8001)
    ├─ Reads from RDS via career_ops_api_rds.py
    ├─ Endpoints available:
    │  ├─ /api/career-ops/status
    │  ├─ /api/career-ops/jobs/best-matches
    │  ├─ /api/career-ops/stats
    │  └─ ... (all endpoints)
    └─ Returns REAL data (NOT mocks)

PsychoBot + Dashboard
    ├─ Calls: https://career-ops-xxxxx.onrender.com/api/career-ops/*
    ├─ Gets real job data from RDS
    └─ Displays fresh opportunities
```

---

## 📍 SERVICE URLS

After deployment:

- **Health Check**: `https://career-ops-xxxxx.onrender.com/health`
- **Status**: `https://career-ops-xxxxx.onrender.com/api/career-ops/status`
- **Best Matches**: `https://career-ops-xxxxx.onrender.com/api/career-ops/jobs/best-matches`
- **All Jobs**: `https://career-ops-xxxxx.onrender.com/api/career-ops/jobs/all`
- **Stats**: `https://career-ops-xxxxx.onrender.com/api/career-ops/stats`
- **Profile**: `https://career-ops-xxxxx.onrender.com/api/career-ops/profile`

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] Create new Web Service on Render
- [ ] Set environment variables (DATABASE_URL, etc.)
- [ ] Connect GitHub repo
- [ ] Deploy (wait for build to complete)
- [ ] Verify service is online (health check)
- [ ] Test API endpoints (curl or browser)
- [ ] Update PsychoBot frontend URLs
- [ ] Setup daily scheduler (Windows + EasyCron OR Lambda)
- [ ] Run scheduler manually to test
- [ ] Verify data appears in RDS
- [ ] Verify PsychoBot gets real data

---

## 🔍 TROUBLESHOOTING

### ❌ "Service fails to build"
**Solution**:
1. Check Build Command in Render
2. Verify `requirements-career-ops.txt` exists in repo
3. Check Python version compatibility
4. See Logs in Render dashboard

### ❌ "API returns 500 error"
**Solution**:
1. Check Render logs for errors
2. Verify DATABASE_URL is correct
3. Test RDS connectivity from Render
4. Check environment variables are set

### ❌ "No data in RDS"
**Solution**:
1. Scheduler hasn't run yet (wait for 06:00 WAT)
2. Manually run: `python career_ops_scheduler_rds.py`
3. Check scheduler logs

### ❌ "PsychoBot getting old data"
**Solution**:
1. Verify scheduler runs daily at 06:00 WAT
2. Check RDS has fresh data (query job posting dates)
3. Clear PsychoBot cache (Ctrl+Shift+Delete in browser)

---

## 📈 MONITORING

### Check Health Regularly

```bash
# Daily health check (add to your monitoring)
curl https://career-ops-xxxxx.onrender.com/health
```

### Monitor RDS

```sql
-- Check latest jobs
SELECT COUNT(*) FROM career_ops.jobs 
WHERE posted_at > NOW() - INTERVAL '1 day';

-- Check latest matches
SELECT COUNT(*) FROM career_ops.job_matches 
WHERE created_at > NOW() - INTERVAL '1 day';

-- Check scraper runs
SELECT * FROM career_ops.scraper_runs 
ORDER BY started_at DESC LIMIT 5;
```

---

## 🎯 FINAL ARCHITECTURE

```
Render Cloud
├─ ai_server.py (port 8000) ← Trading system
│  ├─ GOM poller
│  ├─ TradingAgents
│  └─ PsychoBot integration
│
└─ Career-Ops Service (port 8001) ← NEW!
   ├─ FastAPI app
   ├─ RDS backend
   ├─ Daily prospection
   └─ Real job data

AWS RDS
└─ career_ops schema
   ├─ profile
   ├─ jobs
   ├─ job_matches (scored)
   ├─ scraper_runs (logs)
   └─ applications (tracking)

Local Machine
└─ Windows Task Scheduler
   └─ 06:00 WAT → career_ops_scheduler_rds.py
      (or external cron service)
```

---

## ✨ RESULT

After deployment:

✅ **Independent Services**
- ai_server.py focused on trading
- Career-Ops focused on job prospection
- Can update/redeploy independently

✅ **Real Data Flow**
- Scheduler → RDS persistence
- Career-Ops API → Real data (no mocks)
- PsychoBot → Live opportunities

✅ **Fully Autonomous**
- 06:00 WAT daily execution
- Automatic data ingestion
- Complete audit trail in RDS

✅ **Scalable Architecture**
- Easy to add more services
- Clean separation of concerns
- Render handles scaling

---

## 📞 NEXT STEPS

1. **Push code to GitHub**
   ```bash
   git add career_ops_service.py requirements-career-ops.txt Procfile-career-ops
   git commit -m "feat: Career-Ops standalone service for Render"
   git push
   ```

2. **Create Render service** (follow Step 1 above)

3. **Deploy** (Render auto-deploys from GitHub)

4. **Setup scheduler** (Windows Task Scheduler or EasyCron)

5. **Test** (curl health check, verify data)

6. **Monitor** (check logs, RDS data)

---

**Ready to deploy Career-Ops to Render!** 🚀

Location: https://career-ops-xxxxx.onrender.com  
API Base: https://career-ops-xxxxx.onrender.com/api/career-ops  
Status: Independent, scalable, production-ready
