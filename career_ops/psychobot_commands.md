# Career-Ops PsychoBot Commands

WhatsApp commands for job search interaction

---

## Command Reference

### `/jobs`
Show today's top 5 matches (EXCELLENT + GOOD)

**Usage**: `/jobs`

**Response**:
```
Top 5 Job Matches Today:

1. Senior Python Developer @ TechCorp
   Score: 78% [EXCELLENT]
   $50k - $70k
   
2. Data Analyst @ StartupXYZ
   Score: 65% [GOOD]
   $45k - $60k

...

Reply: /apply 1  (to apply)
       /skip 2   (to skip)
       /jobs all (see all matches)
```

---

### `/jobs all`
Show ALL matches >= 0.55 (including MARGINAL)

**Usage**: `/jobs all`

**Response**: List of all 20+ matches with scores

---

### `/jobs stats`
Show weekly job search statistics

**Usage**: `/jobs stats`

**Response**:
```
Weekly Statistics (June 1-7, 2026):

Jobs Found: 850
New Matches: 127
  • Excellent: 12
  • Good: 35
  • Marginal: 80

Sources:
  • RemoteOK: 250 jobs
  • Himalayas: 180 jobs
  • WWR: 150 jobs
  • Indeed: 270 jobs

Top Companies:
  1. TechCorp (5 matches)
  2. StartupXYZ (4 matches)
  3. DataCo (3 matches)

Applications This Week: 3
Response Rate: 0% (pending)
```

---

### `/apply [number]`
Mark job as applied

**Usage**: `/apply 1`

**Response**:
```
Applied to: Senior Python Developer @ TechCorp
Status: APPLIED
Sent: 2026-06-01 14:30 UTC

Next: Check email for confirmation
Reply /jobs to see more matches
```

---

### `/skip [number]`
Mark job as skipped / not interested

**Usage**: `/skip 3`

**Response**:
```
Skipped: AWS Solutions Architect @ CloudCorp
Reason: Not interested in this role

Reply /jobs to see more matches
```

---

### `/profile`
Show your parsed profile

**Usage**: `/profile`

**Response**:
```
Your Profile:

Name: Sidoine Kolaolé YEBADOKPO
Location: Cotonou, Benin
Experience: 4.5 years

Skills:
  Primary: Python, SQL, R, Power BI, Tableau
  Secondary: Pandas, NumPy, Plotly, Streamlit, React
  Tools: Git, PostgreSQL

Target Roles: Data Analyst, Python Developer, Full-Stack, Data Scientist

Preferences:
  • Remote: Fully Remote
  • Salary: $40k+
  • Languages: French, English
```

---

### `/settings`
Show / update preferences

**Usage**: `/settings`

**Response**:
```
Current Settings:

Digest Time: 06:30 UTC
Minimum Score: 0.55
Job Sources: All (RemoteOK, Himalayas, WWR, Indeed)
Notifications: ON

Commands:
  /settings min-score 0.65  (change minimum score)
  /settings time 07:00      (change digest time)
  /settings quiet           (disable notifications)
  /settings loud            (enable notifications)
```

---

### `/help`
Show all available commands

**Usage**: `/help`

**Response**: This command reference

---

## Advanced Commands

### `/jobs filter [keyword]`
Filter matches by keyword

**Usage**: `/jobs filter python`

**Response**: Matches containing "Python" in title/description

---

### `/jobs company [name]`
Show all matches from specific company

**Usage**: `/jobs company TechCorp`

**Response**: All TechCorp jobs you match

---

### `/jobs applied`
Show jobs you've applied to

**Usage**: `/jobs applied`

**Response**:
```
Applications (3):

1. Senior Python Developer @ TechCorp
   Status: APPLIED (2026-06-01 14:30)
   Score: 78%
   Status: No response yet

2. Data Analyst @ StartupXYZ
   Status: APPLIED (2026-06-01 10:15)
   Score: 65%
   Status: Interviewing

3. Full-Stack @ WebCo
   Status: APPLIED (2026-05-31 16:45)
   Score: 72%
   Status: Rejected
```

---

### `/insights`
Get Claude insights about your opportunities

**Usage**: `/insights`

**Response**:
```
Career Insights This Week:

Trending Skills:
  • React (8 jobs)
  • Kubernetes (6 jobs)
  • AWS Lambda (5 jobs)

You're Strongest In:
  • Python roles: 78% avg match
  • Data roles: 72% avg match
  • Backend roles: 68% avg match

Consider Learning:
  • React (mentioned in 5 high-match jobs)
  • Kubernetes (could increase matches by 20%)

Best Fit Companies:
  1. TechCorp (multiple strong matches)
  2. DataStream (data roles)
  3. WebDev Inc (full-stack roles)
```

---

## Implementation Notes

### Backend Integration

Commands are handled by PsychoBot middleware:

```python
# pseudocode
if message.startswith("/jobs"):
    response = await career_ops_handler.list_jobs(...)
elif message.startswith("/apply"):
    response = await career_ops_handler.mark_applied(...)
elif message.startswith("/skip"):
    response = await career_ops_handler.mark_skipped(...)
```

### Database Queries

- `/jobs` → Query RDS: `career_ops.job_matches WHERE score >= 0.75 OR score >= 0.55-0.74`
- `/apply` → Update: `career_ops.job_matches SET status='applied'`
- `/skip` → Update: `career_ops.job_matches SET status='skipped'`
- `/stats` → Aggregate: `COUNT(*) FROM career_ops.job_matches WHERE date >= WEEK_START`

### Rate Limiting

- Max 10 commands/minute per user
- Max 100 job details per request
- Cooldown: 5s between large queries

---

## Testing Commands

### Test in PsychoBot

```
/jobs
/jobs all
/jobs stats
/profile
/help

/apply 1
/skip 2
/jobs applied
/insights
```

### Test via API

```bash
curl -X POST https://psychobot-1si7.onrender.com/command \
  -H "Content-Type: application/json" \
  -d '{"phone": "+2290196911346", "command": "/jobs"}'
```

---

## Future Enhancements

- `/interview-tips [job-id]` - Claude generates interview prep
- `/cover-letter [job-id]` - Claude generates cover letter
- `/salary-research [title] [location]` - Market salary data
- `/watch [company]` - Alert on new matching jobs from company
- `/unwatch [company]` - Stop alerting for company
- `/export pdf` - Export all matches as PDF

---

**Status**: Week 3 commands specification ready for implementation
