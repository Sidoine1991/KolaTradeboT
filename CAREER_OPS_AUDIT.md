# Career-Ops System Audit & Rebuild Plan
**Status**: 🔴 CRITICAL - Current system uses 100% mock data
**Target**: ✅ Autonomous real job prospection with intelligent CV matching
**Timeline**: 4 weeks (incremental value from Week 1)
**Owner**: Sidoine (Data Analyst & Web Developer Fullstack)

---

## Current State (BROKEN)

```
PsychoBot Career-Ops (TODAY):
  ├─ Data: 100% MOCK (Google, Amazon, "Company 1", etc.)
  ├─ Scraping: NONE (no real job sources)
  ├─ Matching: NONE (manual scoring only)
  ├─ CV Integration: NONE
  ├─ Autonomy: NONE (manual trigger)
  └─ Result: UNUSABLE for real job search
```

**Problem**: System is a shell. It stores fabricated data in RDS but provides zero value.

---

## Target Architecture (4-Week Build)

```
Career-Ops Pipeline (REAL):
  ├─ 06:00 Daily
  ├─ Scrape 6+ real sources (APIs + web)
  │   ├─ RemoteOK (JSON API)
  │   ├─ Himalayas (public API)
  │   ├─ We Work Remotely (RSS)
  │   ├─ Indeed (Playwright)
  │   ├─ Jobgether
  │   └─ Wellfound
  ├─ Parse CV → Skill Profile
  ├─ Intelligent Matching (8-factor scoring)
  ├─ Filter by expiration & location
  ├─ Build WhatsApp digest
  └─ Deliver via PsychoBot
```

---

## Week 1: Foundation (Days 1-7)

### Task 1.1: Setup & Database
- [ ] Create `D:\Dev\TradBOT\career_ops/` directory structure
- [ ] Create Supabase migration: `001_career_ops_schema.sql`
- [ ] Deploy schema (career_profile, jobs, job_matches, scraper_runs)
- [ ] Test connection from Python

### Task 1.2: CV Parsing
- [ ] Implement `cv_parser.py` to extract from PDF:
  - Full name, email, phone
  - Skills (primary: Python, SQL, R, Power BI + secondary)
  - Experience (4+ years)
  - Location (Cotonou, Benin)
  - Target roles (Data Analyst, Web Developer, etc.)
- [ ] Parse Sidoine's CV: `D:\Perso\Remote job\CV_Sidoine_YEBADOKPO_PNUD.pdf`
- [ ] Store parsed profile in `career_profile` table

### Task 1.3: Skill Taxonomy
- [ ] Build `skill_taxonomy.py` with aliases:
  - Python → python3, py, Python
  - SQL → postgresql, mysql, tsql
  - Power BI → power bi, powerbi, dax
  - Etc.
- [ ] Test normalization function

### Task 1.4: First Scraper (RemoteOK)
- [ ] Implement `scrapers/remoteok.py`:
  - Fetch from `https://remoteok.com/api/jobs.json`
  - Filter: `tags` contains 'python' OR 'data' OR 'fullstack'
  - Normalize to `NormalizedJob` schema
  - Save to `jobs` table
- [ ] Test with Sidoine's target keywords

### Task 1.5: Deduplication
- [ ] Implement `job_normalizer.py`:
  - Generate fingerprint: `SHA256(company + title + posted_date)`
  - Skip duplicates on insert
  - Store unique count

### Expected Output (End of Week 1)
- ✅ Supabase schema deployed
- ✅ Sidoine's profile parsed & stored
- ✅ RemoteOK scraper working (50-100 real jobs/day)
- ✅ Duplicates removed
- ✅ Jobs in RDS table (no matches yet)

---

## Week 2: Core Intelligence (Days 8-14)

### Task 2.1: Scoring Algorithm
- [ ] Implement `matching/scorer.py`:
  - 8-factor weighted scoring system
  - Primary skills (30%)
  - Secondary skills (15%)
  - Seniority fit (15%)
  - Remote compatibility (15%)
  - Semantic similarity (10%)
  - Experience level (8%)
  - Salary fit (5%)
  - Recency (2%)
- [ ] Test scoring with known jobs

### Task 2.2: More Scrapers
- [ ] Implement `scrapers/himalayas.py` (public API)
- [ ] Implement `scrapers/weworkremotely.py` (RSS)
- [ ] Test both sources

### Task 2.3: Digest Formatter
- [ ] Implement `delivery/digest_builder.py`:
  - Format WhatsApp message
  - Excellent matches (score >= 0.75)
  - Good matches (0.55-0.74)
  - Job links, company, salary, skills
- [ ] Test formatting

### Task 2.4: PsychoBot Integration
- [ ] Implement `delivery/psychobot_client.py`:
  - POST /send-message endpoint
  - Handle response
  - Log delivery status
- [ ] Test delivery to owner phone

### Task 2.5: First Full Run
- [ ] Run entire pipeline manually:
  - Scrape → 100+ jobs
  - Score against Sidoine's profile
  - Send digest via WhatsApp
  - Store matches in RDS

### Expected Output (End of Week 2)
- ✅ 100+ real jobs in RDS (3 sources)
- ✅ Scoring algorithm working (8 components)
- ✅ 5-10 "Excellent" matches per day
- ✅ WhatsApp digests delivered
- ✅ Manual pipeline works end-to-end

---

## Week 3: Automation & Scale (Days 15-21)

### Task 3.1: Indeed Scraper (Hard Target)
- [ ] Implement `scrapers/indeed.py`:
  - Use Playwright for JS rendering
  - Proxy rotation for anti-bot
  - Search: "data analyst remote", "python remote", etc.
  - Extract job details
  - Normalize
- [ ] Test with 5-10 queries

### Task 3.2: Windows Scheduler
- [ ] Create `setup_career_ops_scheduler.ps1`
- [ ] Register "CareerOps_DailyScan" task
- [ ] Trigger: Daily at 06:00 WAT (UTC+1)
- [ ] Run `scheduler_career_ops.py`
- [ ] Test first automated run

### Task 3.3: PsychoBot Commands
- [ ] Implement handlers in PsychoBot:
  - `/jobs` → show today's top 5 matches
  - `/jobs all` → all matches >= 0.55
  - `/jobs stats` → weekly stats
  - `/applied [job_id]` → mark applied
  - `/skip [job_id]` → mark skip
  - `/profile` → show parsed profile
- [ ] Test all commands

### Task 3.4: Semantic Matching (Optional)
- [ ] Download `all-MiniLM-L6-v2` model (~80MB)
- [ ] Implement `matching/semantic.py`
- [ ] Compute embeddings for jobs + profile
- [ ] Add to scoring algorithm
- [ ] Test quality improvement

### Task 3.5: Monitoring & Logging
- [ ] Track scraper runs: `scraper_runs` table
- [ ] Log errors and success rate
- [ ] Create health check endpoint

### Expected Output (End of Week 3)
- ✅ 300+ real jobs in RDS (4+ sources)
- ✅ Daily autonomous run at 06:00 (automatic)
- ✅ 10-15 excellent matches per day
- ✅ Users can interact via `/jobs` commands
- ✅ Track applications submitted

---

## Week 4: Polish & Monitoring (Days 22-28)

### Task 4.1: More Scrapers
- [ ] `scrapers/jobgether.py`
- [ ] `scrapers/wellfound.py`
- [ ] Bonus: `scrapers/glassdoor.py` (if time)

### Task 4.2: Weekly Report
- [ ] Implement Sunday 08:00 report:
  - Total jobs scraped this week
  - Total new matches
  - Excellence rate
  - Applications submitted
  - Top matched companies
- [ ] Send via WhatsApp

### Task 4.3: Application Tracking
- [ ] Link from match → application
- [ ] Track: applied date, response status
- [ ] Show in `/jobs stats`

### Task 4.4: Quality Evaluation
- [ ] Measure false positive rate (user skips)
- [ ] Adjust scoring weights if needed
- [ ] Tune thresholds

### Task 4.5: Documentation
- [ ] README with architecture overview
- [ ] Env vars template
- [ ] Quick start guide
- [ ] Troubleshooting

### Expected Output (End of Week 4)
- ✅ 6+ real job sources
- ✅ 400-500 unique real jobs in RDS
- ✅ 15-20 excellent matches per day
- ✅ Fully autonomous (no manual triggers)
- ✅ Users applying via /jobs commands
- ✅ Weekly summaries
- ✅ Complete documentation

---

## Critical Success Factors

| Factor | Must-Do | Reason |
|--------|---------|--------|
| **Real Data** | Week 1 | No mock data. Ever. |
| **CV Parsing** | Week 1 | Profile must match Sidoine's actual skills |
| **Intelligent Scoring** | Week 2 | Garbage in → garbage out. Score well or users skip. |
| **Autonomous Scheduler** | Week 3 | Must run automatically at 06:00 or becomes abandoned tool |
| **PsychoBot Delivery** | Week 2 | If users don't see results in WhatsApp, they won't engage |
| **Application Tracking** | Week 4 | Close loop: send → apply → track |

---

## Environment Setup (Day 1)

```bash
# 1. Clone/update repo
cd D:\Dev\TradBOT
git pull origin main

# 2. Create career_ops module
mkdir career_ops
cd career_ops
mkdir scrapers parsing matching delivery db tests

# 3. Install dependencies (add to requirements.txt)
httpx              # async HTTP client
playwright         # JS rendering for web scraping
pdfplumber         # PDF extraction
spacy              # NER for CV parsing
sentence-transformers  # local embeddings
supabase           # already in stack
langchain          # optional, for RAG

# 4. Create .env.career_ops
CAREER_OPS_ENABLED=true
CAREER_OPS_CV_PATH=D:\Perso\Remote job\CV_Sidoine_YEBADOKPO_PNUD.pdf
CAREER_OPS_MIN_SCORE=0.55
SUPABASE_URL=<from existing config>
SUPABASE_KEY=<from existing config>
```

---

## Success Criteria (30 Days)

```
✅ Metrics:
  - Jobs scraped per day: >= 30 (real)
  - New unique jobs per day: >= 10
  - Excellent matches per week: >= 5
  - Users apply per week: >= 3
  - Pipeline uptime: > 95%
  - False positive rate: < 30%

✅ User Experience:
  - Receive WhatsApp digest at 06:35 daily
  - Can view top matches via /jobs
  - Can mark job as /applied or /skip
  - Can see /jobs stats weekly
```

---

## File Structure (Final)

```
D:\Dev\TradBOT\career_ops\
├── __init__.py
├── config.py                    # Settings, weights, thresholds
├── scheduler_career_ops.py      # Daily orchestrator (triggered at 06:00)
├── setup_scheduler.ps1          # Windows Task Scheduler setup
│
├── scrapers/                    # 6+ job sources
│   ├── base.py                  # Abstract interface
│   ├── remoteok.py              # ✅ Week 1
│   ├── himalayas.py             # ✅ Week 2
│   ├── weworkremotely.py        # ✅ Week 2
│   ├── indeed.py                # ✅ Week 3
│   ├── jobgether.py             # ✅ Week 4
│   └── wellfound.py             # ✅ Week 4
│
├── parsing/
│   ├── cv_parser.py             # ✅ Week 1 - Sidoine's CV
│   ├── job_normalizer.py        # ✅ Week 1
│   └── skill_taxonomy.py        # ✅ Week 1
│
├── matching/
│   ├── scorer.py                # ✅ Week 2 - 8-factor algorithm
│   ├── semantic.py              # ⏳ Week 3 - optional
│   └── filters.py               # Expiration, dedup
│
├── delivery/
│   ├── digest_builder.py        # ✅ Week 2
│   └── psychobot_client.py      # ✅ Week 2
│
├── db/
│   ├── models.py                # Pydantic schemas
│   ├── repository.py            # Supabase CRUD
│   └── migrations/
│       └── 001_career_ops_schema.sql  # ✅ Week 1
│
└── tests/
    ├── test_cv_parser.py
    ├── test_scorer.py
    └── test_scrapers.py
```

---

## Go-Live Checklist (Week 4)

- [ ] All 6+ scrapers working
- [ ] Scoring algorithm tuned (no false positives)
- [ ] Windows Task Scheduler set to 06:00 daily
- [ ] PsychoBot commands tested
- [ ] Database migrations applied
- [ ] .env configured
- [ ] Error handling in place
- [ ] Monitoring active
- [ ] Documentation complete
- [ ] First 7 days of production run validated

---

## Estimated Effort

| Component | Days | FTE |
|-----------|------|-----|
| Week 1 (Foundation) | 7 | 1.0 |
| Week 2 (Intelligence) | 7 | 1.2 |
| Week 3 (Automation) | 7 | 1.1 |
| Week 4 (Polish) | 7 | 0.8 |
| **Total** | **28** | **1.0 avg** |

*One person working full-time, 4 weeks to full production autonomy.*

---

## Next Steps

1. **Immediate (Day 1)**: Set up directory structure, install dependencies
2. **Day 2**: Implement CV parser for Sidoine's PDF
3. **Day 3**: Create Supabase schema
4. **Day 4-5**: Build RemoteOK scraper
5. **Day 6-7**: First manual pipeline run

**By end of Week 1**: Real jobs in RDS, no mocks.

---

Generated: 2026-06-01
Target Launch: 2026-06-29
