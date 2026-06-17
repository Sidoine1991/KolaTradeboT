# Pullback Entry System — Beautiful WhatsApp Alerts Integration

## Overview

Le système **Pullback Entry** maintenant envoie des **alertes WhatsApp beautifiées** intégrées à l'architecture TradBOT existante.

✅ **4 phases d'alerte:**
1. 🎯 PULLBACK TRACKING — Suivi démarre
2. 📉 PULLBACK DETECTED — Pullback confirmé  
3. ✅ SIGNAL GO! — Signal de resumption OK
4. 💰 TRADE OUVERT — Ordre exécuté

---

## Architecture d'Intégration

### 1. Formatter Python (Réutilisable)

```python
from pullback_alert_formatter import PullbackAlertFormatter

formatter = PullbackAlertFormatter()

# Phase 1
msg1 = formatter.format_pullback_started(
    symbol="Boom 150 Index",
    direction="BUY",
    breakout_price=1456.23,
    pullback_min=0.5,
    pullback_max=1.5
)
```

**Fichier:** `Python/pullback_alert_formatter.py`

### 2. Endpoint WhatsApp Existant

**Utilise le même endpoint que gom_sync_with_report.py:**

```
POST https://psychobot-1si7.onrender.com/send-message
```

**Payload format:**
```json
{
    "phone": "+2290196911346",
    "message": "🎯 *PULLBACK TRACKING*\n\n...",
    "source": "tradbot-pullback"
}
```

### 3. Fonction d'Envoi (Réutilisable)

```python
def send_pullback_alert(formatted_message: str, send_function) -> bool:
    """
    Envoie via la fonction send_whatsapp_report existante du système
    """
    return send_function(formatted_message)
```

---

## Intégration dans SMC_Universal.mq5

### A. MQL5 → Python Communication

**Phase 1: Pullback Started**
```mql5
// Depuis SMC_Universal:
string json = "{\"event\":\"pullback_start\",\"symbol\":\"" + symbol + 
              "\",\"direction\":\"" + dir + "\",\"breakout\":" + 
              DoubleToString(breakoutPrice, 2) + "}";

WebRequest("POST", "http://127.0.0.1:8000/pullback-alert",
           "", 3000, json, data_receive, headers);
```

**Phase 2-4:** Même pattern avec `pullback_detected`, `resumption_confirmed`, `trade_opened`

### B. Python → WhatsApp (Existing flow)

```python
# Dans gom_sync.py ou pipeline_auto.py:
from pullback_alert_formatter import PullbackAlertFormatter

formatter = PullbackAlertFormatter()

# Reçoit l'event du MQL5 via POST /pullback-alert
msg = formatter.format_pullback_started(
    symbol=event['symbol'],
    direction=event['direction'],
    breakout_price=event['breakout'],
    pullback_min=0.5,
    pullback_max=1.5
)

send_whatsapp_report(msg)  # Utilise la fonction existante!
```

---

## Configuration

### 1. MT5 WebRequest Authorization

**Tools → Options → Expert Advisors → "Allow WebRequest for listed URL"**

Ajouter:
```
http://127.0.0.1:8000
https://psychobot-1si7.onrender.com
```

### 2. EA Parameters (SMC_Universal)

```
UseWhatsAppAlerts = true
PsychoBotWebhookURL = "https://psychobot-1si7.onrender.com/send-message"
AlertPhoneNumber = "+2290196911346"
AlertDebounceSeconds = 5
AlertMaxPerDay = 50
```

### 3. Python Environment

Aucune dépendance supplémentaire requise (utilise `requests` déjà installé).

---

## Message Examples

### Phase 1: Pullback Started
```
🎯 *PULLBACK TRACKING*

*Symbole:* Boom 150 Index
*Direction:* 🟢 BUY
*Breakout Price:* 1456.23

*Attente Pullback:*
Recul attendu: 0.5% - 1.5%

⏰ 14:20:05 UTC
```

### Phase 2: Pullback Detected
```
📉 *PULLBACK DÉTECTÉ*

*Symbole:* Boom 150 Index
*Direction:* 🟢 BUY

*Mouvement du Pullback:*
↘️ - 0.92%
Extreme: 1452.11
Breakout: 1456.23

*En attente...*
Signal de resumption

⏰ 14:23:12 UTC
```

### Phase 3: Resumption Confirmed
```
✅ *SIGNAL GO!*

*Symbole:* Boom 150 Index
*Direction:* 🟢 BUY

*ENTRÉE:* 1453.45
*SL:* 1451.95 ↘️
*TP:* 1455.20 ↗️
*Lot:* 0.01

*Ratio R/R:* 1:1.17
*Signaux:* EMA Cross + Volume Spike (2/3)

⏰ 14:25:33 UTC
```

### Phase 4: Trade Opened
```
💰 *TRADE OUVERT*

*Symbole:* Boom 150 Index
*Direction:* 🟢 BUY
*Ticket:* #12345

*PRIX ENTRÉE:* 1453.45
*SL:* 1451.95
*TP:* 1455.20
*Lot:* 0.01

*RISQUE/RÉCOMPENSE:*
Risk: $0.48
Reward: $0.53

⏰ 14:25:35 UTC
```

---

## Testing

### Test Python Formatter Locally
```bash
cd D:/Dev/TradBOT/Python
python pullback_alert_formatter.py
```

### Test Full WhatsApp Flow
```bash
cd D:/Dev/TradBOT
python test_beautiful_alerts.py
```

**Expected output:** 4/4 messages sent successfully ✅

---

## Files Reference

| File | Purpose |
|------|---------|
| `Python/pullback_alert_formatter.py` | Message formatter (réutilisable) |
| `test_beautiful_alerts.py` | Test script (validation) |
| `mt5/SMC_Universal.mq5` | EA avec integration WebRequest |
| `Python/gom_sync_with_report.py` | Template d'intégration existant |

---

## Robustesse

✅ **Anti-spam:** 5s debounce entre alertes mêmes phase
✅ **Quota:** 50 alertes/jour max (reset minuit)
✅ **Fallback:** Email + Push MT5 si WhatsApp fail
✅ **Retry:** 3× avec backoff exponentiel
✅ **Logging:** Détaillé avec timestamps

---

## Support

Les messages sont envoyés via le **PsychoBot Render** déployé existant.
Pas de service supplémentaire requis.

**Endpoint:** `https://psychobot-1si7.onrender.com/send-message`
**Status:** Testé ✅ 4/4 messages réussis

