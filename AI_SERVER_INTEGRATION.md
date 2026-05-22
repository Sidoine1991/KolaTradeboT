# 🤖 AI SERVER INTEGRATION - Divergence Robot

## Configuration URLs

### Inputs dans le Robot (EA):

```
=== AI SERVER INTEGRATION ===
UseAIServer: true (Enable/Disable AI guidance)
AIServerURL: http://127.0.0.1:8000 (Local server)
AIServerBackup: https://kolatradebot.onrender.com (Fallback)
AIServerTimeout: 5000 (5 seconds)
```

---

## API ENDPOINTS UTILISÉS

### 1. `/divergence/signal` (PRIMARY)

**Purpose:** Valide et affine les signaux divergence détectés localement

**Request:**
```json
POST http://127.0.0.1:8000/divergence/signal
{
  "symbol": "EURUSD",
  "candles": [
    {"o": 1.0850, "h": 1.0860, "l": 1.0840, "c": 1.0855, "v": 1000},
    {"o": 1.0855, "h": 1.0870, "l": 1.0850, "c": 1.0865, "v": 1100},
    ...
  ],
  "lookback": 5,
  "threshold": 0.18,
  "confluence_min": 3
}
```

**Response:**
```json
{
  "ok": true,
  "symbol": "EURUSD",
  "direction": "BUY",
  "confidence": 87.5,
  "divergence_score": 4,
  "entry_price": 1.0855,
  "stop_loss": 1.0830,
  "take_profit": 1.0900,
  "reason": "Score 4, Price ROC extreme, Volume anomaly"
}
```

---

## FLUX D'EXÉCUTION

### Step 1: Local Detection
```
Robot calcule divergence localement
Score >= ConfluenceMin (3)? ✓
```

### Step 2: AI Validation (si UseAIServer = true)
```
Envoie candles + paramètres à http://127.0.0.1:8000/divergence/signal
Serveur analyse et renvoie:
  - Direction confirmée (BUY/SELL)
  - Confidence ajustée
  - Score validé
```

### Step 3: Decision
```
Si serveur répond:
  ✓ Utilise décision AI-guidée
  ✗ Fallback sur local decision

Si timeout (5s) ou erreur:
  → Essaie backup: https://kolatradebot.onrender.com
  → Si fail aussi: utilise local decision
```

### Step 4: Trade Execution
```
Signal final validé → CheckAndExecuteEntry()
```

---

## LOGS GÉNÉRÉS

### Dans MT5 Experts tab:

```
[INIT] Divergence Robot initialized on EURUSD
   Timeframe: H1
   Magic: 123456
   Auto Trading: 1
   AI Server: http://127.0.0.1:8000
   Backup: https://kolatradebot.onrender.com
   AI-guided divergence detection ENABLED

[BAR 5] Scanning for divergence signals...
   GOM Levels found: 3
   Signal: BUY | Score: 4 | Conf: 75%
   [AI] Server-guided decision applied
   [AI] Decision: BUY | Confidence: 87.5%

>> DIVERGENCE SIGNAL DETECTED: BUY
   Confidence: 87.5% | Score: 4
   Reason: AI-Server validated
   [AI-GUIDED] Decision validated by server

[ENTRY] DIVERGENCE BUY @ 1.08550
   | SL=1.08300 | TP=1.09000
   | Lot=0.10 | Score=4
   | Reason: AI-Server validated
```

---

## FAILURE SCENARIOS

### Scénario 1: Local Server Down
```
[AI] HTTP Error: -1 | URL: http://127.0.0.1:8000
[AI] Primary server failed, trying backup: https://kolatradebot.onrender.com
[AI] HTTP Error: -1 | URL: https://kolatradebot.onrender.com
[AI] Server call failed, using local decision
→ Robot utilise la décision locale
```

### Scénario 2: Timeout
```
[AI] HTTP Error: -1 | URL: http://127.0.0.1:8000 (timeout après 5s)
→ Fallback sur backup
```

### Scénario 3: Invalid Response
```
[AI] Server response: {"ok": false, "error": "Invalid candles"}
[AI] Decision: NONE (server rejected)
→ Robot utilise la décision locale
```

---

## PERFORMANCE

| Metrique | Valeur |
|----------|--------|
| Local decision time | ~50ms |
| AI server call | ~200-500ms |
| Timeout | 5000ms (5 sec) |
| Total per signal | ~500ms avg |

---

## ADVANTAGES

✅ **Dual Decision Making**: Local + AI validation
✅ **Redundancy**: Fallback server si primaire fail
✅ **Speed**: Timeout court (5s) = pas bloquer
✅ **Logging**: Tous les appels loggés
✅ **Flexible**: Peut désactiver avec UseAIServer = false

---

## TROUBLESHOOTING

### Q: Les appels AI ne se font pas?
A: Vérifier:
   1. UseAIServer = true (dans inputs)
   2. AIServerURL correcte (http://127.0.0.1:8000)
   3. Serveur running: `curl http://127.0.0.1:8000/health`
   4. Vérifier logs MT5 Experts tab

### Q: Serveur répond mais signal pas pris en compte?
A: Vérifier:
   1. Response JSON valide (format correct)
   2. "ok": true dans response
   3. "direction": "BUY" ou "SELL" présent

### Q: Trop lent, timeout?
A: Augmenter AIServerTimeout:
   - Actuel: 5000ms
   - Augmenter à: 10000ms (10s)
   - Dans inputs EA: AIServerTimeout = 10000

### Q: Veux utiliser que local decision?
A: Désactiver:
   - UseAIServer = false (dans inputs)
   - Robot utilisera que la détection locale

---

## PROCHAINES ÉTAPES

1. **Compile** l'EA avec intégration AI
2. **Lance** le serveur: `python ai_server.py --port 8000`
3. **Vérifie** health: `curl http://127.0.0.1:8000/health`
4. **Attache** robot au graphique
5. **Attends** signal divergence
6. **Regarde** les logs pour voir AI decision

---

## EXEMPLE DE SESSION COMPLÈTE

```
11:15:00 → EA attached
11:15:02 → [INIT] Robot initialized, AI enabled
11:15:05 → [BAR 5] GOM detected, signal calculated locally (Score: 4)
11:15:05 → POST /divergence/signal with candles data
11:15:05 → AI Server responds: BUY with 87.5% confidence
11:15:06 → [AI] Decision: BUY | Confidence: 87.5%
11:15:06 → >> DIVERGENCE SIGNAL DETECTED: BUY
11:15:06 → [ENTRY] DIVERGENCE BUY @ 1.08550
11:15:07 → Position opened: 0.1 lot, SL=1.08300, TP=1.09000

11:45:00 → TP reached at 1.09000
11:45:01 → Position closed: +50 USD profit
```

**LE ROBOT EST MAINTENANT AI-GUIDÉ!** 🚀
