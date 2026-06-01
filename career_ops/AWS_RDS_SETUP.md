# Career-Ops AWS RDS Setup & Deployment Guide

## Overview

Career-Ops has been updated to use **AWS RDS PostgreSQL** for persistent storage instead of Supabase.

All data (jobs, matches, profiles) will be stored in your existing RDS instance.

---

## Quick Start (5 minutes)

### 1. Add DATABASE_URL to .env

Open `D:\Dev\TradBOT\.env` and add:

```bash
# AWS RDS Connection (update with your actual values)
DATABASE_URL=postgresql://user:password@your-rds-endpoint.us-east-1.rds.amazonaws.com:5432/tradbot
```

**Find your RDS endpoint**:
- AWS Console → RDS → Databases → Select database
- Copy "Endpoint" from "Connectivity & security" section

### 2. Install Dependencies

```bash
pip install psycopg2-binary
```

### 3. Apply Migration

```bash
cd D:\Dev\TradBOT
python career_ops/db/apply_rds_migration.py
```

Output should show:
```
[SUCCESS] Migration completed!

[VERIFICATION] Tables created in career_ops schema:
  - applications
  - career_profile
  - job_matches
  - jobs
  - scraper_runs

[OK] All 5 Career-Ops tables created successfully!
```

### 4. Test Connection

```bash
python -c "
from career_ops.db.rds_repository import RDSRepository

repo = RDSRepository()
profile = repo.get_profile(profile_id=1)
print(f'Profile: {profile[\"full_name\"]}')
print(f'Skills: {profile[\"skills_primary\"]}')
"
```

---

## Detailed Setup

### Database Configuration

Career-Ops expects this RDS setup:

| Component | Value |
|-----------|-------|
| Engine | PostgreSQL 12+ |
| Database | `tradbot` (or your choice) |
| User | `postgres` or your master username |
| Port | 5432 (default) |

### Schema Structure

Career-Ops creates a dedicated schema: `career_ops`

```sql
career_ops.career_profile    -- Sidoine's CV profile
career_ops.jobs              -- Normalized jobs from scrapers
career_ops.job_matches       -- Scoring results (profile → job)
career_ops.scraper_runs      -- Audit/health logs
career_ops.applications      -- Application tracking
```

### Environment Variable

Set in `.env`:

```bash
DATABASE_URL=postgresql://[USER]:[PASSWORD]@[ENDPOINT]:5432/[DATABASE]
```

Example:
```bash
DATABASE_URL=postgresql://postgres:my-password@tradbot-db.c9akciq32.us-east-1.rds.amazonaws.com:5432/tradbot
```

---

## Using Career-Ops with RDS

### Insert Jobs

```python
from career_ops.db.rds_repository import RDSRepository

repo = RDSRepository()

job = {
    'source': 'remoteok',
    'source_id': 'job_12345',
    'source_url': 'https://remoteok.com/jobs/12345',
    'title': 'Senior Python Developer',
    'company': 'TechCorp',
    'description': '...',
    'salary_min': 50000,
    'salary_max': 70000,
    'fingerprint': 'sha256_hash_here',
    # ... other fields
}

job_id = repo.insert_job(job)
print(f"Inserted job ID: {job_id}")
```

### Query Top Matches

```python
from career_ops.db.rds_repository import RDSRepository

repo = RDSRepository()

# Get top 10 matches for Sidoine (profile_id=1)
matches = repo.get_top_matches(profile_id=1, limit=10)

for match in matches:
    print(f"{match['score_total']:.2f} | {match['title']} @ {match['company']}")
```

### Run Complete Pipeline

```bash
python career_ops/pipeline_rds.py
```

This will:
1. Parse Sidoine's CV
2. Generate test jobs
3. **Store jobs in AWS RDS**
4. Score each job (8-factor algorithm)
5. **Store matches in AWS RDS**
6. Generate JSON report
7. Log scraper run metrics

---

## File Reference

| File | Purpose |
|------|---------|
| `career_ops/db/apply_rds_migration.py` | Create schema & tables in RDS |
| `career_ops/db/rds_repository.py` | Python ORM for RDS access |
| `career_ops/pipeline_rds.py` | Full pipeline with RDS storage |
| `career_ops/db/migrations/001_career_ops_schema_rds.sql` | SQL schema definition |

---

## Troubleshooting

### Error: "DATABASE_URL not set in .env"

**Solution**: Add DATABASE_URL to `.env`

```bash
# .env
DATABASE_URL=postgresql://user:password@host:5432/database
```

### Error: "could not connect to server"

**Cause**: RDS endpoint, username, or password incorrect

**Solution**:
1. Verify RDS endpoint in AWS Console
2. Test locally: `psql -h [endpoint] -U [user] -d [database]`
3. Check RDS security group allows port 5432 inbound

### Error: "psycopg2 not installed"

**Solution**: 
```bash
pip install psycopg2-binary
```

### Error: "database does not exist"

**Solution**: Create database first
```bash
psql -h [endpoint] -U postgres -c "CREATE DATABASE tradbot;"
```

### Error: "permission denied for schema career_ops"

**Solution**: Grant permissions to user
```bash
psql -h [endpoint] -U postgres -d tradbot -c "GRANT ALL ON SCHEMA career_ops TO [your_user];"
```

---

## Verification Queries

Verify tables created:

```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'career_ops';
```

Verify Sidoine's profile:

```sql
SELECT full_name, years_experience, skills_primary 
FROM career_ops.career_profile WHERE full_name LIKE 'Sidoine%';
```

Check jobs stored:

```sql
SELECT COUNT(*) as total_jobs FROM career_ops.jobs;
```

Check top matches:

```sql
SELECT j.title, j.company, m.score_total 
FROM career_ops.job_matches m
JOIN career_ops.jobs j ON m.job_id = j.id
WHERE m.profile_id = 1
ORDER BY m.score_total DESC
LIMIT 10;
```

---

## Next Steps

### Week 1 (Done):
- ✅ Directory structure
- ✅ CV parser
- ✅ AWS RDS schema
- ✅ Test pipeline with RDS storage

### Week 2:
- [ ] Himalayas scraper
- [ ] We Work Remotely scraper (RSS)
- [ ] PsychoBot integration
- [ ] Digest formatter
- [ ] Production run with 3 sources

### Week 3:
- [ ] Indeed scraper (Playwright)
- [ ] Windows Task Scheduler (06:00 daily)
- [ ] PsychoBot commands
- [ ] Semantic matching

### Week 4:
- [ ] Jobgether + Wellfound scrapers
- [ ] Weekly reports
- [ ] Application tracking
- [ ] Quality tuning

---

## Production Deployment

1. **Pre-deployment**:
   ```bash
   python career_ops/db/apply_rds_migration.py
   python career_ops/pipeline_rds.py
   ```

2. **Verify RDS data**:
   ```sql
   SELECT COUNT(*) FROM career_ops.jobs;
   SELECT COUNT(*) FROM career_ops.job_matches;
   ```

3. **Setup Windows Scheduler** (Week 3):
   ```powershell
   New-ScheduledTask -TaskName "CareerOps_DailyScan" `
     -Trigger (New-ScheduledTaskTrigger -Daily -At 06:00) `
     -Action (New-ScheduledTaskAction -Execute "python" -Argument "career_ops/scheduler.py")
   ```

4. **Monitor**:
   ```sql
   SELECT * FROM career_ops.scraper_runs ORDER BY started_at DESC LIMIT 5;
   ```

---

## Support

**Documentation**: See `career_ops/db/setup_rds_connection.md`

**API Reference**: `career_ops/db/rds_repository.py`

**Example**: `career_ops/pipeline_rds.py`

---

**Status**: Career-Ops Week 1 complete with AWS RDS integration ✅
