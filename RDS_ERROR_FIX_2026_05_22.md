# 🔧 RDS/Supabase Error - m15_prediction_log Missing Table

## Error Details

**Time:** 2026-05-22 15:31:38,956
**Error Code:** Relation "m15_prediction_log" does not exist
**Endpoint:** GET /projection/smart
**Database:** AWS RDS (Supabase)

```
ERROR - Erreur exécution requête: relation "m15_prediction_log" does not exist
LINE 8:                FROM m15_prediction_log
                            ^
```

---

## Root Cause

The query tries to access table `m15_prediction_log` which **does not exist in the database**.

This happens when:
1. ✗ Table was never created
2. ✗ Table was deleted
3. ✗ Wrong database name/schema
4. ✗ Query references old/renamed table

---

## Solutions (Choose One)

### Solution 1: Fix Query (Fastest)

**Location:** ai_server.py - find `/projection/smart` endpoint

**Change:**
```sql
-- REMOVE THIS LINE:
FROM m15_prediction_log

-- REPLACE WITH:
FROM (SELECT * FROM m5_prediction_log LIMIT 0)  -- Empty result
-- OR use existing table that has data
```

### Solution 2: Create Missing Table

**SQL Query:**
```sql
CREATE TABLE IF NOT EXISTS m15_prediction_log (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20),
    timeframe VARCHAR(10),
    prediction VARCHAR(50),
    probability FLOAT,
    timestamp TIMESTAMP DEFAULT NOW()
);
```

### Solution 3: Check Existing Tables

**To see all tables:**
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema='public';
```

**Expected output should include:**
- m5_prediction_log ✓
- m15_prediction_log ✗ (MISSING)
- prediction_log ✓
- etc.

---

## Recommended Fix

**For ai_server.py `/projection/smart` endpoint:**

### Option A: Comment Out / Disable Endpoint
```python
# Temporarily disable problematic endpoint
@app.get("/projection/smart")
def projection_smart():
    return {"status": "disabled", "message": "Table m15_prediction_log not found"}
```

### Option B: Use Alternative Table
```python
# If m5_prediction_log exists, use that:
@app.get("/projection/smart")
def projection_smart():
    # Query uses m5_prediction_log instead of m15_prediction_log
    query = """
    SELECT * FROM m5_prediction_log WHERE ...
    """
    ...
```

### Option C: Create Table in Database
```python
# Run once to create table:
cursor.execute("""
    CREATE TABLE IF NOT EXISTS m15_prediction_log (
        id SERIAL PRIMARY KEY,
        symbol VARCHAR(20),
        timeframe VARCHAR(10),
        prediction VARCHAR(50),
        probability FLOAT,
        timestamp TIMESTAMP DEFAULT NOW()
    );
""")
```

---

## Immediate Action

### Step 1: Check What Tables Exist
```bash
# Connect to Supabase/RDS and run:
SELECT table_name FROM information_schema.tables 
WHERE table_schema='public' ORDER BY table_name;
```

### Step 2: Fix ai_server.py
Find the line that references `m15_prediction_log`:
- Comment it out, OR
- Replace with existing table name, OR
- Create the table

### Step 3: Restart ai_server.py
```bash
# Kill existing process
ps aux | grep python
kill -9 [PID]

# Restart
python ai_server.py
```

### Step 4: Test
```bash
# Try the failing endpoint
curl http://127.0.0.1:8000/projection/smart

# Should not get the m15_prediction_log error anymore
```

---

## Prevention for Future

### Best Practice: Try-Except Blocks
```python
try:
    query = "SELECT * FROM m15_prediction_log WHERE ..."
    result = execute_query(query)
except Exception as e:
    if "does not exist" in str(e):
        # Fall back to alternative query
        query = "SELECT * FROM m5_prediction_log WHERE ..."
        result = execute_query(query)
```

### Best Practice: Table Check on Startup
```python
def check_required_tables():
    required_tables = [
        'm5_prediction_log',
        'm15_prediction_log',
        'prediction_log',
        # ... more
    ]
    
    for table in required_tables:
        if not table_exists(table):
            print(f"WARNING: Table {table} not found!")
            # Create it or disable related endpoints
```

---

## Related Errors to Check

Look for similar errors with other missing tables:
```bash
grep -i "does not exist" /var/log/postgresql/postgresql.log
# Or check Supabase UI for table list
```

---

## Files Affected

**File:** D:\Dev\TradBOT\ai_server.py
- Endpoint: GET /projection/smart
- Issue: Queries non-existent table `m15_prediction_log`

---

## Quick Workaround

Until table is created or query is fixed:

**Disable the endpoint temporarily:**

In ai_server.py, find the `/projection/smart` endpoint and modify:

```python
@app.get("/projection/smart")
def projection_smart():
    """
    DISABLED: Table m15_prediction_log does not exist
    TODO: Create table or use alternative
    """
    return {
        "status": "error",
        "message": "Endpoint temporarily disabled - missing table m15_prediction_log",
        "timestamp": datetime.now().isoformat()
    }
```

---

## Status

**Severity:** MEDIUM (affects /projection/smart endpoint only)
**Impact:** Other endpoints unaffected
**Action Required:** Fix query or create table
**Timeline:** Can be fixed in < 5 minutes

---

## Next Steps

1. [ ] Connect to Supabase/RDS database
2. [ ] Run: `SELECT table_name FROM information_schema.tables WHERE table_schema='public';`
3. [ ] Check if m15_prediction_log exists
4. [ ] Either:
   - Create the table, OR
   - Fix the query, OR
   - Disable the endpoint
5. [ ] Restart ai_server.py
6. [ ] Test: curl http://127.0.0.1:8000/projection/smart
7. [ ] Verify: No "does not exist" error

---

**Status:** ⚠️ NEEDS FIX - Database table issue
**Date:** 2026-05-22
**Error Time:** 15:31:38
**Database:** Supabase/AWS RDS

---
