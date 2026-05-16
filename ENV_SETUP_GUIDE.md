# Environment Configuration Guide (.env Setup)

## Overview

TradBOT uses `.env` files to store sensitive credentials and configuration. **This file must NEVER be committed to git.**

---

## Quick Start

### 1. Create Your .env File

```bash
# Copy the template
cp .env.example .env

# Edit with your credentials (use nano, vim, or VS Code)
nano .env
```

### 2. Fill in Your Credentials

Replace all `your-*-here` placeholders with actual values. See sections below for where to get each.

### 3. Verify Setup

```bash
# Test that environment variables are loaded correctly
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print('✅ .env loaded'); print('GEMINI_API_KEY:', 'OK' if os.getenv('GEMINI_API_KEY') else 'MISSING')"
```

---

## Getting Each Credential

### API Keys (Critical - Rotate If Exposed)

#### ALPHA_VANTAGE_API_KEY
- **Purpose:** Forex price data and signals
- **Get it:** https://www.alphavantage.co/
- **Steps:**
  1. Go to website
  2. Click "Get Free API Key"
  3. Enter email and verify
  4. Copy your API key
- **Format:** 16-character alphanumeric string
- **Example:** `4EM6K09BZU52S9JD`

#### POLYGON_API_KEY
- **Purpose:** Stock and crypto price data
- **Get it:** https://polygon.io/dashboard/api-keys
- **Steps:**
  1. Create free account on Polygon.io
  2. Go to Dashboard → API Keys
  3. Copy your key (starts with your username)
- **Format:** ~50 character string
- **Example:** `CJFmHohSIYSrNGfTD8I7TDW_Zq2HMq9s`

#### TWILIO_AUTH_TOKEN
- **Purpose:** WhatsApp trading notifications
- **Get it:** https://www.twilio.com/console/account/settings
- **Steps:**
  1. Create Twilio account
  2. Go to Account Settings
  3. Copy Auth Token (keep visible toggle on)
- **Format:** 32-character hex string
- **Example:** `8ee2b981c70120c9342e9ebbcd642dc9`

#### GEMINI_API_KEY
- **Purpose:** AI analysis and market intelligence
- **Get it:** https://aistudio.google.com/apikey
- **Steps:**
  1. Go to Google AI Studio
  2. Click "Create API Key"
  3. Create key in new GCP project
  4. Copy the key
- **Format:** Variable length, usually 40+ chars
- **Secure:** Restrict to your project only

---

### Database Credentials

#### SUPABASE_URL
- **Purpose:** PostgreSQL database for trading history and signals
- **Get it:** Supabase console → Project Settings → API
- **Format:** `https://xxxxx.supabase.co`
- **Keep secret:** Yes, but less critical than API keys

#### SUPABASE_KEY
- **Purpose:** Anonymous key for database access
- **Get it:** Supabase console → Project Settings → API
- **Find:** "Anonymous public key" (starts with `eyJ`)
- **Format:** Long JWT token
- **Keep secret:** Yes

#### SUPABASE_PASSWORD
- **Purpose:** Direct PostgreSQL database password
- **Get it:** Supabase console → Project Settings → Database
- **Find:** "Database Password" section
- **Format:** User-created password when you set up Supabase
- **Keep secret:** YES - this is critical

#### DATABASE_URL (Optional)
- **Purpose:** Full PostgreSQL connection string (if using external DB)
- **Format:** `postgresql://user:password@host:5432/tradbot`
- **Leave blank:** If using Supabase

---

### Trading Accounts

#### MT5_ACCOUNT_LOGIN
- **Purpose:** Your MetaTrader 5 account number for API calls
- **Get it:** MetaTrader 5 → Terminal → Account Information
- **Format:** 8-digit number
- **Example:** `12345678`

#### (Optional) Exness/Deriv Credentials
- **If deploying two terminals:**
  - Terminal 1 (Exness): Store login in MT5_EXNESS_LOGIN
  - Terminal 2 (Deriv): Store login in MT5_DERIV_LOGIN
- **Note:** MT5 terminal handles actual login, this is for reference

---

### Server Configuration

#### AI_SERVER_URL
- **Purpose:** Where the AI analysis server runs
- **Default:** `http://localhost:8000` (local development)
- **Production:** `http://your-server:8000` or cloud URL

#### RENDER_AI_SERVER_URL
- **Purpose:** Remote AI server (if deployed on Render)
- **Get it:** Deploy ai_server.py to Render and copy the URL
- **Format:** `https://your-app.onrender.com`
- **Usage:** Set `USE_RENDER_AI_SERVER=true` to use this

---

### Notifications

#### WHATSAPP_PHONE_NUMBER
- **Purpose:** Your WhatsApp number for trading alerts
- **Format:** International format: `+1234567890`
- **Include:** Country code and area code

#### SLACK_WEBHOOK_URL
- **Purpose:** Send alerts to Slack channel
- **Get it:** Slack app → Incoming Webhooks
- **Format:** Long URL starting with `https://hooks.slack.com/...`

---

## Security Best Practices

### ✅ DO

- ✅ **Copy .env.example to .env** - Use the template
- ✅ **Add .env to .gitignore** - Already done, but verify
- ✅ **Rotate keys quarterly** - Even if not exposed
- ✅ **Use strong passwords** - For database especially
- ✅ **Restrict API key scopes** - Only needed permissions
- ✅ **Use environment variables in production** - Not hardcoded
- ✅ **Backup .env securely** - Password manager or encrypted storage
- ✅ **Monitor for exposure** - Check git history occasionally

### ❌ DON'T

- ❌ **Never commit .env** - Git will reject if in .gitignore (check failed commits!)
- ❌ **Never share .env** - Not in Slack, email, or documentation
- ❌ **Never upload to GitHub** - Even if private repo
- ❌ **Never use real .env in Docker images** - Build secrets separately
- ❌ **Never log environment variables** - Except in errors (sanitize first)
- ❌ **Never hardcode credentials** - Always use getenv()
- ❌ **Never use same keys for dev/production** - Separate accounts
- ❌ **Never leave old .env files in backups** - Rotate and destroy

---

## Verifying Setup

### Test 1: File Exists
```bash
# Should exist and be readable
ls -la .env
# Should NOT appear in git
git status | grep .env  # Should be empty
```

### Test 2: Variables Load
```bash
# Python script should find all critical variables
python << 'EOF'
import os
from dotenv import load_dotenv

load_dotenv()

required = ['GEMINI_API_KEY', 'SUPABASE_URL', 'SUPABASE_KEY']
missing = [v for v in required if not os.getenv(v)]

if missing:
    print(f"❌ MISSING: {missing}")
    exit(1)
else:
    print("✅ All critical variables found")
EOF
```

### Test 3: No Secrets in Git
```bash
# Search for API key patterns in git history
git log -p | grep -i "api_key\|password\|token" | head -5
# Should return: nothing (or old commits only)

# Check current staged changes
git diff --cached | grep -i "api_key\|password\|token"
# Should return: nothing
```

### Test 4: API Connections Work
```bash
# Test Supabase connection
python << 'EOF'
import os
from dotenv import load_dotenv
import supabase

load_dotenv()
client = supabase.create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_KEY')
)
print("✅ Supabase connection OK")
EOF

# Test Gemini API
python << 'EOF'
import os
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()
genai.configure(api_key=os.getenv('GEMINI_API_KEY'))
print("✅ Gemini API connection OK")
EOF
```

---

## If You Accidentally Exposed a Secret

### 1. Immediate Actions
```bash
# Stop using the exposed credential
# Rotate it immediately (go to service provider)
# Update .env with new value
```

### 2. Clean Git History
```bash
# Remove from git history (one-time)
git filter-branch --force --index-filter \
  'git rm --cached -r --ignore-unmatch .env' \
  -- --all

# Force push (WARNING: affects all users)
git push origin --force --all
```

### 3. Notify Team
- Tell anyone with repo access
- Old clones may still have exposed keys
- New clones will not have them

### 4. Monitor Service
- Check API key usage in dashboard
- Set up alerts for unexpected usage
- Audit what happened with that key

---

## Multiple Environments

### Development (.env)
```
GEMINI_API_KEY=dev-key-here
AI_SERVER_URL=http://localhost:8000
USE_RENDER_AI_SERVER=false
DEBUG_MODE=true
```

### Staging (.env.staging)
```
GEMINI_API_KEY=staging-key-here
AI_SERVER_URL=http://staging-server:8000
USE_RENDER_AI_SERVER=false
DEBUG_MODE=false
```

### Production (.env.production - NEVER commit!)
```
GEMINI_API_KEY=prod-key-here
AI_SERVER_URL=https://prod-api.example.com:8000
USE_RENDER_AI_SERVER=true
DEBUG_MODE=false
```

Load correct environment:
```python
import os
from dotenv import load_dotenv

env = os.getenv('ENVIRONMENT', 'development')
load_dotenv(f'.env.{env}')
```

---

## Troubleshooting

### Problem: "Missing required environment variable"
```bash
# Solution 1: Check if .env exists
ls -la .env

# Solution 2: Verify variable is spelled correctly
grep "GEMINI_API_KEY" .env

# Solution 3: Make sure no spaces around =
# Wrong: GEMINI_API_KEY = value
# Correct: GEMINI_API_KEY=value
```

### Problem: Old keys still showing in git
```bash
# Check if old commits have secrets
git log --grep="api" -p | grep -i "key\|secret"

# If found, you need to rewrite history (see section above)
```

### Problem: .env changes showing in git diff
```bash
# This means .env is being tracked (shouldn't happen)
git rm --cached .env
git add .gitignore
git commit -m "Stop tracking .env file"
```

### Problem: Different team member configurations
```bash
# Solution: Use .env.local for personal overrides
# .env = shared defaults
# .env.local = personal (in .gitignore)

# Python: load both
load_dotenv('.env')  # Shared
load_dotenv('.env.local')  # Personal overrides
```

---

## Summary Checklist

- [ ] Copied .env.example to .env
- [ ] Filled in all required credentials
- [ ] .env is in .gitignore
- [ ] Verified no secrets in git history
- [ ] Tested environment variables load correctly
- [ ] Verified API connections work
- [ ] Backed up .env securely (not in git!)
- [ ] Shared setup instructions with team
- [ ] Set calendar reminder to rotate keys quarterly

---

**Last Updated:** 2026-05-16  
**Status:** Ready for production
