# PsychoBot Audio Transcription Issue - Diagnosis

**Date:** 2026-05-31 11:07 UTC  
**Issue:** Audio transcription failed  
**Status:** 🔴 OPENAI_API_KEY not configured

---

## 🔍 Problem Summary

### What Happened

User "Kira" sent a voice message to PsychoBot at 11:04:33 UTC.

**Bot Response:**
```
🎙️ Transcript:
"[Audio transcription - local fallback not available]"

🤖 Response:
Bonjour Kira ! 🙏 Je rencontre une petite difficulté technique. 
Votre message est bien reçu et je le transmets à Sidoine qui vous 
répondra dès que possible
```

**File Generated:**
```
C:\Users\USER\Downloads\WhatsApp Ptt 2026-05-31 at 11.04.33.ogg
Size: 180 KB
Format: OGG Opus (WhatsApp standard)
```

---

## ✅ What Worked

```
[✓] Step 1: Audio Reception       - Message received from WhatsApp
[✓] Step 2: Audio Download        - File downloaded successfully
[✓] Step 3: Format Conversion     - OGG ready for processing
[✗] Step 4: Transcription         - FAILED: API key missing/invalid
[✓] Step 5: Fallback Response     - User notified of technical issue
```

**Positive Points:**
- ✅ WhatsApp connection working
- ✅ Audio download functional
- ✅ File handling correct
- ✅ Error handling graceful (fallback message sent)

---

## ❌ Root Cause

### Missing/Invalid OpenAI API Key

**Error Message:**
```
"[Audio transcription - local fallback not available]"
```

**Cause:**
The `OPENAI_API_KEY` environment variable is either:
1. Not set in Render dashboard
2. Set but expired/invalid
3. Set but quota exceeded

**Impact:**
- OpenAI Whisper API cannot be called
- Audio → Text transcription fails
- Bot cannot generate contextual response
- User gets generic error message

---

## 🔧 Solution

### Step 1: Get OpenAI API Key

1. Go to: https://platform.openai.com/api-keys
2. Click: **"Create new secret key"**
3. Name: `PsychoBot-Whisper-Transcription`
4. Copy the key: `sk-proj-xxxxxxxxxxxxxxxxxx`

**Important:** Save the key immediately - it's only shown once!

---

### Step 2: Configure in Render

1. Go to: https://dashboard.render.com
2. Select service: **psychobot-1si7**
3. Click: **Environment** tab
4. Find or add variable: `OPENAI_API_KEY`
5. Paste value: `sk-proj-xxxxxxxxxxxxxxxxxx`
6. Click: **Save Changes**

**Result:** Render will automatically redeploy with the new key (~2-3 minutes)

---

### Step 3: Verify Configuration

**Wait for deployment to complete, then:**

```bash
# Test via curl
curl https://psychobot-1si7.onrender.com/health

# Expected: {"success": true, "connected": true}
```

**Or check Render logs:**
```
Go to: Logs tab in Render dashboard
Look for: "OpenAI Whisper API configured"
```

---

### Step 4: Test Voice Message

1. Open WhatsApp
2. Contact: **+229 01 96 91 13 46**
3. Send voice message: "Bonjour PsychoBot, test après configuration"
4. Wait 5-15 seconds

**Expected Response:**
- 🔊 Voice reply (audio message)
- 📋 Text transcript of your message
- 🤖 Contextual AI response

---

## 🧪 Local Testing (Optional)

### Test Transcription Locally

If you have an OpenAI API key, you can test the audio file locally:

```bash
# Run the test script
cd D:\Dev\TradBOT
python test_audio_transcription.py

# Follow the prompts to enter API key
# The script will transcribe the OGG file and show results
```

**This helps verify:**
- ✓ API key is valid
- ✓ Audio file is readable
- ✓ Transcription quality
- ✓ Expected transcript content

---

## 📊 Pipeline Status After Fix

Once `OPENAI_API_KEY` is configured:

```
User Voice Message
      ↓
[✓] Download Audio (OGG)
      ↓
[✓] Convert to WAV
      ↓
[✓] Transcribe (OpenAI Whisper) ← WILL WORK
      ↓
[✓] AI Response (NVIDIA NIM)
      ↓
[✓] Text-to-Speech (Google TTS)
      ↓
[✓] Convert to OGG
      ↓
[✓] Send Voice Reply
      ↓
[✓] Cleanup Temp Files

Expected time: 5-15 seconds
```

---

## 🎯 Quick Fix Checklist

- [ ] Get OpenAI API key from platform.openai.com
- [ ] Add key to Render environment variables
- [ ] Wait for Render redeployment (~3 min)
- [ ] Check logs for "Whisper configured" message
- [ ] Send test voice message
- [ ] Verify voice reply received
- [ ] Confirm transcript is accurate

---

## 💡 Alternative Solutions

### Option 1: Use Groq Whisper (Free)

Groq offers free Whisper API:
1. Get key: https://console.groq.com
2. Set: `GROQ_API_KEY` in Render
3. Modify audioProcessor.js to use Groq endpoint

**Pros:**
- Free tier available
- Fast transcription
- Good quality

**Cons:**
- Requires code modification
- Not currently implemented

---

### Option 2: Local Whisper (No API)

Install Whisper model locally on Render:
- Use `whisper.cpp` or `faster-whisper`
- No API calls needed
- Fully offline

**Pros:**
- No API costs
- No rate limits

**Cons:**
- Slower transcription (~10-15s)
- Requires more server resources
- Complex setup

---

## 📈 Cost Estimation

### OpenAI Whisper API Pricing

**Model:** `whisper-1`  
**Cost:** $0.006 per minute of audio

**Example Usage:**
```
Average voice message: 10 seconds (0.17 minutes)
Cost per message: $0.001 (0.1 cent)
100 messages: $0.10
1,000 messages: $1.00
```

**Monthly Estimate:**
- Light use (50 voice/month): $0.05
- Medium use (500 voice/month): $0.50
- Heavy use (5000 voice/month): $5.00

**Recommendation:** Very affordable for typical bot usage

---

## 🔍 Troubleshooting After Fix

### If transcription still fails:

#### Check 1: Verify API Key in Logs
```
Render Dashboard → Logs
Look for: "OPENAI_API_KEY" loading confirmation
```

#### Check 2: Test API Key Directly
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# Should return list of models
```

#### Check 3: Check OpenAI Account Status
- Go to: https://platform.openai.com/account/billing
- Verify: Credits available
- Check: Usage limits not exceeded

#### Check 4: Review Render Environment
```
Render Dashboard → Environment
Ensure: OPENAI_API_KEY is set (not empty)
Value: Starts with "sk-proj-" or "sk-"
```

---

## ✅ Success Criteria

After applying the fix, success means:

1. ✅ User sends voice message
2. ✅ Bot transcribes correctly (visible in text)
3. ✅ AI generates contextual response
4. ✅ Bot sends voice reply (not just text)
5. ✅ Response time < 15 seconds
6. ✅ No "[transcription not available]" error

---

## 📞 Next Steps

### Immediate Action Required:

1. **Get OpenAI API Key**
   - https://platform.openai.com/api-keys

2. **Configure in Render**
   - Add `OPENAI_API_KEY` environment variable

3. **Test Voice Message**
   - Send to +229 01 96 91 13 46
   - Verify voice reply received

4. **Run Local Test (Optional)**
   - `python test_audio_transcription.py`
   - Verify transcript quality

---

## 📝 Issue Timeline

```
11:04:33 UTC - Voice message received from user
11:04:35 UTC - Audio download successful (180 KB)
11:04:36 UTC - Transcription attempted → FAILED
11:04:37 UTC - Fallback error message sent
11:07:00 UTC - Issue diagnosed: Missing OPENAI_API_KEY
11:15:00 UTC - Fix documented
PENDING    - Apply fix to Render environment
PENDING    - Retest voice message
```

---

## 📚 Related Documentation

- `PSYCHOBOT_AUDIO_CAPABILITIES.md` - Full system documentation
- `PSYCHOBOT_AUDIO_QUICK_REFERENCE.txt` - Pipeline diagram
- `PSYCHOBOT_VOICE_TEST_GUIDE.md` - Testing procedures
- `test_audio_transcription.py` - Local transcription test
- `D:\Dev\Depot Github\Psychobot\AUDIO_PROCESSING_GUIDE.md` - Implementation guide

---

**Status:** 🔴 Awaiting API key configuration  
**ETA to Fix:** 5-10 minutes (key creation + Render redeploy)  
**Impact:** Medium (voice messages not processed until fixed)  
**Workaround:** Text messages still work normally

---

*Diagnosis completed: 2026-05-31 11:15 UTC*  
*Next update: After API key configuration*
