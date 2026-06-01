# PsychoBot ↔ Career-Ops Integration

**Date**: 2026-06-01  
**Status**: ✅ Ready for Integration

---

## Overview

Career-Ops commands are now fully integrated into PsychoBot's WhatsApp interface with:
- ✅ Comprehensive command menu
- ✅ Natural language understanding (NLP-like fallback)
- ✅ Formatted WhatsApp responses
- ✅ Automatic command detection
- ✅ French + English support

---

## Files Created

1. **psychobot_commands_careerops.py**
   - Main command handler with NLP fallback
   - All 9 command implementations
   - Formatted output for WhatsApp

2. **career_ops_psychobot_bridge.py**
   - FastAPI router for incoming/outgoing messages
   - Webhook integration points
   - Message queue handling

---

## Available Commands

### Job Discovery (4 commands)
```
/jobs           → Top 5 best matches
/jobs all       → All matches (score ≥ 0.55)
/jobs stats     → Weekly statistics
/apply [n]      → Mark job as applied
/skip [n]       → Mark job as skipped
```

### Profile & Settings (3 commands)
```
/profile        → Show CV data
/settings       → View/update preferences
/insights       → Career advice
```

### Help (1 command)
```
/help           → Show all commands
```

---

## Natural Language Support

Users don't need to remember exact commands. Examples:

✓ "show me the best jobs" → `/jobs`  
✓ "all positions matching me" → `/jobs all`  
✓ "stats for this week" → `/jobs stats`  
✓ "mark as applied" → `/apply`  
✓ "mon profil" → `/profile`  
✓ "affiche mes offres" → `/jobs all`  

The system uses similarity matching to find the closest command.

---

## Integration Steps

### Option 1: FastAPI Router (Recommended)

Add to `ai_server.py`:

```python
from career_ops_psychobot_bridge import router as careerops_router

# Register router
app.include_router(careerops_router, prefix="/api")

# Endpoints now available:
# POST /api/career-ops/webhook/incoming-message
# POST /api/career-ops/send-message
# GET /api/career-ops/help
# GET /api/career-ops/commands
# GET /api/career-ops/status
```

### Option 2: Standalone Service

```python
from fastapi import FastAPI
from career_ops_psychobot_bridge import router

app = FastAPI()
app.include_router(router)

# Run: uvicorn career_ops_service:app --port 8001
```

---

## Webhook Flow

### Incoming Message (from PsychoBot)
```
User sends WhatsApp message
           ↓
PsychoBot → POST /api/career-ops/webhook/incoming-message
           ↓
CareerOpsCommandHandler processes message
           ↓
Automatically sends response via PsychoBot
```

### Example Request
```json
POST /api/career-ops/webhook/incoming-message
{
  "phone": "+2290196911346",
  "message": "show me best jobs",
  "timestamp": "2026-06-01T16:00:00Z",
  "message_id": "wamsg_xyz123"
}
```

### Example Response
```json
{
  "ok": true,
  "phone": "+2290196911346",
  "command_detected": true,
  "response_queued": true
}
```

---

## Message Format

All WhatsApp messages are formatted with:
- Emoji indicators (🎯, 📊, ✅, ❌)
- Clear hierarchy with `*bold*` and line breaks
- Numbered lists for jobs
- Score grades (🟢 EXCELLENT, 🟡 GOOD, 🔴 MARGINAL)

Example response:

```
🌟 TOP 5 BEST MATCHES TODAY 🌟
========================================

1. Full-Stack Python Developer
   Company: TechStartup Inc
   Score: 0.78 🟢 EXCELLENT
   Salary: $50,000 - $70,000

2. Senior Python Data Analyst
   Company: DataFlow AI
   Score: 0.73 🟡 GOOD
   Salary: $55,000 - $75,000

... (3 more jobs)

========================================
💡 Use `/apply 1` to mark job #1 as applied
💡 Use `/skip 2` to skip job #2
```

---

## Testing

### Test Command Handler
```bash
curl -X POST http://localhost:8000/api/career-ops/test-command \
  -H "Content-Type: application/json" \
  -d '{"message": "show me best jobs"}'
```

### Get Help
```bash
curl http://localhost:8000/api/career-ops/help
```

### Get Status
```bash
curl http://localhost:8000/api/career-ops/status
```

---

## Database Integration

Commands read/write to Career-Ops tables:

| Command | Tables Read | Tables Write |
|---------|------------|--------------|
| `/jobs` | job_matches | - |
| `/jobs all` | job_matches | - |
| `/jobs stats` | job_matches | - |
| `/apply [n]` | job_matches | applications |
| `/skip [n]` | job_matches | applications |
| `/profile` | career_profile | - |
| `/settings` | career_profile | career_profile |

---

## Natural Language Recognition

The system uses `difflib.SequenceMatcher` for fuzzy matching:

```python
# Examples of recognition
"show jobs" → /jobs (0.85 similarity)
"meilleurs matchs" → /jobs (0.72 similarity)
"mes offres" → /jobs (0.80 similarity)
"mon profil" → /profile (0.88 similarity)
```

Threshold: 0.40 (40% minimum similarity)

---

## Error Handling

All errors are caught and formatted for WhatsApp:

```
❌ Database not available. Please try again later.
```

```
❌ Error: Invalid job number. Please use /apply 1
```

```
❌ Profile not loaded. Contact admin.
```

---

## Future Enhancements

- [ ] Store user preferences (language, remote type, salary)
- [ ] Weekly digest email
- [ ] Resume builder integration
- [ ] Interview tips from Claude
- [ ] Salary negotiation advice
- [ ] Company research summaries
- [ ] Application tracking dashboard
- [ ] Calendar integration (interview scheduling)

---

## Production Checklist

- [ ] Test all 9 commands with real data
- [ ] Verify RDS connectivity
- [ ] Test French + English NLP
- [ ] Monitor error logs
- [ ] Set up alerts for failures
- [ ] Document user experience
- [ ] Train team on new features

---

## Quick Start

1. **Add to ai_server.py**:
```python
from career_ops_psychobot_bridge import router as careerops_router
app.include_router(careerops_router, prefix="/api")
```

2. **Restart ai_server**:
```bash
python ai_server.py
```

3. **Test in WhatsApp**:
```
Send: /help
Send: show me best jobs
Send: /profile
Send: stats
```

---

## Support

Questions? Check:
- `psychobot_commands_careerops.py` for command logic
- `career_ops_psychobot_bridge.py` for API endpoints
- `CAREER_OPS_11SOURCES_SUMMARY.md` for system overview

