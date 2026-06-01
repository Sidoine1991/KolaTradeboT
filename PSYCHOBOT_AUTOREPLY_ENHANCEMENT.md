# PsychoBot Auto-Reply Enhancement

## Problem Statement

The current auto-reply logic sends a generic "Je rencontre une petite difficulté technique..." message **every time a user messages**, even when:
1. **Sidoine has recently replied** (conversation is active)
2. **The message is a voice note** (audio should get special handling)
3. **The conversation is ongoing** (no need for the "absent owner" message)

This causes spam and poor UX.

---

## Solution Architecture

### Three Detection Layers

```
Message arrives
    ↓
[Layer 1] Is owner active? (< 15 min since last Sidoine msg)
    ├─ YES → Skip auto-reply, respond contextually
    ├─ NO  → Continue to Layer 2
    ↓
[Layer 2] Message type?
    ├─ AUDIO → Send 🎤 acknowledgment (+ optional transcribe)
    ├─ IMAGE → Brief "Image reçue ✓"
    ├─ TRADING CONTENT (>100 chars, keywords) → Route to trading AI
    ├─ CASUAL → Short context-aware response
    ↓
[Layer 3] Owner absent > 60 min?
    ├─ YES → Send generic "Je rencontre une difficulté technique..."
    ├─ NO  → Delay reply or queue for owner review
```

---

## Implementation Plan

### Phase 1: Conversation State Tracking

**File**: `src/db/conversationState.js` (new)

```javascript
// Store conversation state with TTL
const conversationStates = new Map();

const STATE_STRUCTURE = {
  jid: "group@g.us or number@s.whatsapp.net",
  lastOwnerMessageTime: 1234567890, // unix timestamp
  lastBotReplyTime: 1234567890,
  lastUserMessageType: "text|audio|image|other",
  conversationActive: true, // true if < 15 min since owner msg
  messageCount: 5, // consecutive user msgs without owner response
};

function getConversationState(jid) {
  return conversationStates.get(jid) || {
    jid,
    lastOwnerMessageTime: 0,
    lastBotReplyTime: 0,
    lastUserMessageType: "text",
    conversationActive: false,
    messageCount: 0,
  };
}

function setConversationActive(jid, active = true, durationMinutes = 15) {
  const state = getConversationState(jid);
  state.conversationActive = active;
  state.lastOwnerMessageTime = Date.now();
  conversationStates.set(jid, state);

  // Auto-expire after durationMinutes
  if (active) {
    setTimeout(() => {
      setConversationActive(jid, false);
    }, durationMinutes * 60 * 1000);
  }
}

function updateMessageType(jid, type) {
  const state = getConversationState(jid);
  state.lastUserMessageType = type;
  state.messageCount += 1;
  conversationStates.set(jid, state);
}

module.exports = {
  getConversationState,
  setConversationActive,
  updateMessageType,
};
```

### Phase 2: Message Type Detection

**File**: `src/handlers/messageType.js` (new)

```javascript
function detectMessageType(message) {
  if (message.audioMessage) return "audio";
  if (message.imageMessage) return "image";
  if (message.videoMessage) return "video";
  if (message.documentMessage) {
    const mime = message.documentMessage.mimetype;
    if (mime && mime.startsWith("audio/")) return "audio";
    return "document";
  }
  if (message.stickerMessage) return "sticker";
  if (message.extendedTextMessage) {
    const text = message.extendedTextMessage.text;
    return classifyTextMessage(text);
  }
  if (message.conversation) return classifyTextMessage(message.conversation);
  return "other";
}

function classifyTextMessage(text) {
  if (!text) return "other";

  const tradingKeywords = [
    "trade", "signal", "buy", "sell", "tp", "sl", "entry",
    "xauusd", "btc", "boom", "crash", "chart", "level",
    "cassure", "retest", "ordre", "position",
  ];

  const isTradingContent = 
    tradingKeywords.some(kw => text.toLowerCase().includes(kw)) &&
    text.length > 100;

  return isTradingContent ? "trading_analysis" : "text";
}

module.exports = { detectMessageType, classifyTextMessage };
```

### Phase 3: Auto-Reply Decision Engine

**File**: `src/handlers/autoReplyDecision.js` (new)

```javascript
const { getConversationState } = require("../db/conversationState");

const OWNER_JID = process.env.OWNER_JID || "+2290196911346@s.whatsapp.net";

function shouldAutoReply(jid, messageType, sender) {
  // Never auto-reply to owner
  if (sender === OWNER_JID) return false;

  const state = getConversationState(jid);
  const timeSinceOwnerMsg = Date.now() - state.lastOwnerMessageTime;
  const FIFTEEN_MIN_MS = 15 * 60 * 1000;

  // [Layer 1] Owner active?
  if (timeSinceOwnerMsg < FIFTEEN_MIN_MS) {
    return false; // Conversation is active, no auto-reply
  }

  // [Layer 2] Special handling for audio
  if (messageType === "audio") {
    return "audio_ack"; // Special audio response, not generic
  }

  // [Layer 3] Owner absent check
  const SIXTY_MIN_MS = 60 * 60 * 1000;
  if (timeSinceOwnerMsg > SIXTY_MIN_MS) {
    return "generic_absent"; // Send the "Je rencontre..." message
  }

  // [Layer 3b] Owner 15-60 min absent
  if (state.messageCount > 2) {
    return "context_aware"; // Short, relevant response
  }

  return false; // Queue for review or silently queue
}

function selectReplyTemplate(decisionCode, messageType, messageText) {
  const templates = {
    audio_ack: {
      emoji: "🎤",
      text: "Votre message vocal reçu ✓",
      action: "transcribe_optional",
    },
    context_aware: {
      emoji: "✓",
      text: "Sidoine prendra connaissance bientôt.",
      action: "queue_for_review",
    },
    generic_absent: {
      emoji: "🙏",
      text: `Bonjour ! Je suis l'assistant de Sidoine en son absence.

${extractQueryFromMessage(messageText)}

J'ai bien reçu votre message et Sidoine vous répondra au plus tôt. Merci !`,
      action: "send_now",
    },
  };

  return templates[decisionCode] || null;
}

function extractQueryFromMessage(text) {
  if (!text) return "";
  const lines = text.split("\n");
  return lines.slice(0, 2).join("\n"); // First 2 lines as context
}

module.exports = {
  shouldAutoReply,
  selectReplyTemplate,
  OWNER_JID,
};
```

### Phase 4: Update Message Handler

**File**: `src/services/ai.js` (modifications)

```javascript
// At top, add imports
const { getConversationState, setConversationActive, updateMessageType } = require("../db/conversationState");
const { detectMessageType } = require("../handlers/messageType");
const { shouldAutoReply, selectReplyTemplate, OWNER_JID } = require("../handlers/autoReplyDecision");

// In handlePrivateMessage(), replace the auto-reply logic:

async function handlePrivateMessage(msg, client, contactName) {
  const senderJid = msg.key.remoteJid;
  const messageText = msg.message?.conversation || msg.message?.extendedTextMessage?.text || "";
  const sender = senderJid.includes("@") ? senderJid.split("@")[0] : senderJid;

  console.log(`[Private] From ${contactName} (${sender}): ${messageText.substring(0, 50)}`);

  // OWNER MESSAGE: Update conversation state & mark active
  if (sender === OWNER_JID.replace("@s.whatsapp.net", "")) {
    setConversationActive(senderJid, true, 15); // Mark active for 15 min
    // Owner reply continues normal message handling...
  }

  // USER MESSAGE: Detect type & check auto-reply eligibility
  const messageType = detectMessageType(msg.message);
  updateMessageType(senderJid, messageType);

  const autoReplyDecision = shouldAutoReply(senderJid, messageType, sender);

  if (!autoReplyDecision) {
    // No auto-reply: silently queue or log
    console.log(`[AutoReply] SKIPPED (conversation active)`);
    return;
  }

  // AUTO-REPLY SELECTED
  const template = selectReplyTemplate(autoReplyDecision, messageType, messageText);
  if (!template) return;

  try {
    // [AUDIO] Special handling: transcribe if available
    if (messageType === "audio" && autoReplyDecision === "audio_ack") {
      await client.sendMessage(senderJid, { 
        text: `${template.emoji} ${template.text}` 
      });
      
      // Queue transcription async (don't block reply)
      if (template.action === "transcribe_optional") {
        queueTranscription(msg, senderJid, client);
      }
      return;
    }

    // [GENERIC] Send full response
    if (template.action === "send_now") {
      await client.sendMessage(senderJid, { text: template.text });
    }

    console.log(`[AutoReply] SENT: ${autoReplyDecision}`);
  } catch (err) {
    console.error("[AutoReply Error]", err);
  }
}

function queueTranscription(msg, jid, client) {
  // TODO: Implement async transcription via Groq Whisper
  // Store msg ID + jid, process in background, reply when ready
}
```

### Phase 5: Audio Transcription (Optional Enhancement)

**File**: `src/handlers/transcription.js` (new)

```javascript
const { Groq } = require("groq-sdk");

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

async function transcribeAudio(audioBuffer) {
  try {
    const transcript = await groq.audio.transcriptions.create({
      file: new File([audioBuffer], "audio.ogg", { type: "audio/ogg" }),
      model: "whisper-large-v3-turbo",
      language: "fr", // French by default
    });

    return transcript.text;
  } catch (err) {
    console.error("[Transcription Error]", err);
    return null;
  }
}

module.exports = { transcribeAudio };
```

---

## Deployment Steps

1. **Stop PsychoBot on Render**
   ```bash
   # From GitHub: Render → Manual Deploy → Stop → Clear Build Cache
   ```

2. **Clone & checkout branch**
   ```bash
   cd ~/Depot\ Github/Psychobot
   git pull origin main
   git checkout -b feature/autoreply-fix
   ```

3. **Create new files**
   - `src/db/conversationState.js`
   - `src/handlers/messageType.js`
   - `src/handlers/autoReplyDecision.js`
   - `src/handlers/transcription.js`

4. **Modify existing files**
   - `src/services/ai.js` → Update `handlePrivateMessage()`

5. **Test locally**
   ```bash
   npm start
   # Test: Send message while "Sidoine" is online
   # Expected: No auto-reply ✓
   ```

6. **Commit & push**
   ```bash
   git add .
   git commit -m "feat: smart auto-reply with conversation activity detection"
   git push origin feature/autoreply-fix
   ```

7. **Deploy**
   ```bash
   # GitHub: Create PR → Merge to main
   # Render auto-deploys from main → Watch logs for errors
   ```

---

## Testing Checklist

- [ ] Owner online (< 15 min since msg): NO auto-reply sent
- [ ] Owner offline > 60 min: Generic "Je rencontre..." sent
- [ ] Audio message: 🎤 acknowledgment only (not generic)
- [ ] Image message: Brief "Image reçue ✓"
- [ ] Trade discussion (>100 chars + keywords): Routed to trading AI
- [ ] Multiple messages in 5 min: 1st gets context-aware reply, rest queued
- [ ] Owner sends reply: Conversation flag resets to active

---

## Future Enhancements

1. **Audio Response**: Reply with voice note (TTS)
2. **Smart Transcription**: Auto-transcribe voice notes and include in AI analysis
3. **Conversation Grouping**: Thread multiple messages for coherent responses
4. **Trading Integration**: Route trade discussions to TradingAgents API
5. **Analytics**: Track auto-reply metrics (bypass rate, user satisfaction)
