# Career-Ops AWS RDS Setup Guide

## Step 1: Add DATABASE_URL to .env

If you already have `DATABASE_URL` in your `.env`, Career-Ops will use it automatically.

If not, add this line to `D:\Dev\TradBOT\.env`:

```bash
# AWS RDS PostgreSQL Connection
# Format: postgresql://username:password@host:port/database
DATABASE_URL=postgresql://user:password@your-rds-endpoint.us-east-1.rds.amazonaws.com:5432/tradbot
```

Replace:
- `user` → your RDS master username
- `password` → your RDS master password
- `your-rds-endpoint` → your actual RDS endpoint (e.g., `tradbot-db.c9akciq32.us-east-1.rds.amazonaws.com`)
- `tradbot` → your database name

## Step 2: Install Dependencies

```bash
pip install psycopg2-binary
```

## Step 3: Apply Migration

Run from `D:\Dev\TradBOT`:

```bash
python career_ops/db/apply_rds_migration.py
```

This will:
1. Connect to your RDS instance
2. Create `career_ops` schema
3. Create 5 tables (career_profile, jobs, job_matches, scraper_runs, applications)
4. Create 8 performance indexes
5. Insert Sidoine's profile

## Step 4: Verify

```bash
python -c "
from career_ops.db.rds_repository import RDSRepository

repo = RDSRepository()
profile = repo.get_profile()
print(f'Profile: {profile[\"full_name\"]}')
print(f'Experience: {profile[\"years_experience\"]} years')
print(f'Skills: {profile[\"skills_primary\"]}')
"
```

## RDS Connection String Format

Your `DATABASE_URL` should follow this format:

```
postgresql://[username]:[password]@[endpoint]:[port]/[database]
```

### Finding Your RDS Endpoint

1. Go to AWS Console → RDS → Databases
2. Click your database name
3. Under "Connectivity & security" → find "Endpoint"
4. Example: `tradbot-db.c9akciq32.us-east-1.rds.amazonaws.com`

## Tables Created

| Table | Purpose |
|-------|---------|
| `career_ops.career_profile` | Sidoine's parsed CV profile |
| `career_ops.jobs` | Normalized jobs from all sources |
| `career_ops.job_matches` | Scoring results (profile-to-job) |
| `career_ops.scraper_runs` | Scraper execution logs |
| `career_ops.applications` | Application tracking |

## Connection Troubleshooting

### Error: "could not connect to server"
- Check RDS endpoint is correct
- Verify RDS security group allows inbound PostgreSQL (port 5432)
- Test from local machine: `psql -h [endpoint] -U [username] -d [database]`

### Error: "FATAL: database does not exist"
- Create database first: `CREATE DATABASE tradbot;`

### Error: "psycopg2 not installed"
- Run: `pip install psycopg2-binary`

## Accessing from Career-Ops Code

```python
from career_ops.db.rds_repository import RDSRepository

# Automatically uses DATABASE_URL from .env
repo = RDSRepository()

# Insert job
job_id = repo.insert_job(job_dict)

# Insert match
match_id = repo.insert_match(match_dict)

# Get top matches
matches = repo.get_top_matches(profile_id=1, limit=10)

# Log scraper run
repo.log_scraper_run('remoteok', jobs_found=50, jobs_new=12)
```

## Next Steps

1. ✅ Configure DATABASE_URL
2. ✅ Install psycopg2-binary
3. ✅ Run migration script
4. ✅ Verify tables created
5. → Run pipeline: `python career_ops/pipeline.py`
6. → Jobs will be stored in RDS automatically

---

**Note**: The migration script includes Sidoine's profile by default. Additional scrapers will insert jobs via `rds_repository.insert_job()`.
