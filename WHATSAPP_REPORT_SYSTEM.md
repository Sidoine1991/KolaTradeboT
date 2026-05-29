# WhatsApp Unified Report System

## Vue d'ensemble

Système autonome d'envoi de rapports **TradBOT** via **WhatsApp** toutes les 20 minutes, avec :

- ✅ Données **TradingView** en temps réel (prix, indicateurs)
- ✅ Données **AI Server** (biais session, ordres EA, TradingAgents)
- ✅ **Analyse croisée** (confluence BUY/SELL/WAIT)
- ✅ **Fallback** vers log file si PsychoBot indisponible

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  WhatsApp Report System                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  whatsapp_report_daemon.py  ← Boucle 20min (loop)         │
│       │                                                     │
│       └─→ whatsapp_unified_report.py                       │
│             ├─→ TradingView MCP (quote_get)               │
│             ├─→ AI Server /session-bias                   │
│             ├─→ AI Server /pending-order                  │
│             └─→ AI Server /tradingagents/report-status    │
│                   │                                        │
│                   └─→ Message Unifié                      │
│                       │                                    │
│                       ├─→ PsychoBot /send-message (WhatsApp)
│                       └─→ Fallback: whatsapp_alerts.log   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Fichiers Clés

| Fichier | Rôle |
|---------|------|
| `scripts/whatsapp_unified_report.py` | Générateur de rapport unifié |
| `scripts/whatsapp_report_daemon.py` | Boucle autonome 20min |
| `Start-WhatsAppReportDaemon.ps1` | Launcher PowerShell (Windows) |
| `start_whatsapp_daemon.sh` | Launcher Bash (Linux/Mac) |
| `whatsapp_alerts.log` | Logs des alertes |
| `last_whatsapp_report.txt` | Dernier rapport généré |

---

## Format du Message

```
📊 *TradBOT [HH:MM UTC]*

*XAUUSD — Suivi 20min* | DD/MM HH:MM UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $XXXX.XX
   Open: $X | High: $X | Low: $X
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Verdict GOM KOLA : BUY/SELL/ATTENTE*
   Score BUY=X  SELL=X
   Verdict: PERFECT BUY / GOOD SELL
   Entry: $X | SL: $X | TP: $X
   Ticket MT5: XXXXXXXX
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Biais session :* BUY/SELL/NEUTRAL X% | ✅/❌ valide Xh
━━━━━━━━━━━━━━━━━━━━
🟢/🔴/⚪ *Rapport TradingAgents :* BUY/SELL/NONE X%
   Age: Xmin | Expire: Xmin
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
   ✅ Confluence 2/3 pour BUY
   🎯 *Décision : BUY*
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

---

## Installation

### 1. Prérequis

```bash
pip install requests python-dotenv
```

### 2. Configuration `.env`

```ini
# .env
AI_SERVER_URL=http://127.0.0.1:8000
PSYCHOBOT_URL=https://psychobot-1si7.onrender.com
WHATSAPP_PHONE=+2290196911346
```

### 3. Lancer le Daemon

#### **Windows (PowerShell)**
```powershell
.\Start-WhatsAppReportDaemon.ps1
```

#### **Linux / Mac (Bash)**
```bash
bash start_whatsapp_daemon.sh
```

#### **Manuel (Python)**
```bash
python scripts/whatsapp_report_daemon.py
```

---

## Rapports Manuels

### Générer un rapport unique

```bash
python scripts/whatsapp_unified_report.py
```

Le rapport est généré dans `last_whatsapp_report.txt`.

---

## Données Collectées

### TradingView
- **Prix en live** : $XXXX.XX
- **OHLC** : Open, High, Low, Close
- **Volume** : Nombre d'ordres

### AI Server

#### `/session-bias`
```json
{
  "direction": "BUY",           // BUY, SELL, NEUTRAL
  "confidence": 0.9,            // 0.0 → 1.0
  "age_hours": 11.71,           // Âge du biais
  "valid": true,                // Valide maintenant?
  "expires_in_hours": 12.29     // Temps avant expiration
}
```

#### `/pending-order`
```json
{
  "ok": true,
  "order": {
    "action": "BUY",
    "entry_price": 4534.405,
    "stop_loss": 4532.35,
    "take_profit": 4545.35,
    "gom_verdict": "PERFECT BUY",
    "gom_score_buy": 11.56,
    "gom_score_sell": -0.35,
    "mt5_ticket": 1376457740
  }
}
```

#### `/tradingagents/report-status`
```json
{
  "ok": false,                  // Aucun rapport actif en ce moment
  "direction": "NONE",
  "confidence": 0.0,
  "age_minutes": 0.0,
  "expires_in_minutes": 0.0
}
```

---

## Logique d'Analyse Croisée

### Confluence Score

Le système compte les sources d'accord sur la direction :

- **GOM Verdict** (pending-order) : +1 si BUY
- **Biais Session** : +1 si BUY
- **TradingAgents** : +1 si BUY

### Décision Finale

| Confluence | Décision |
|---|---|
| 3/3 (parfait) | 🟢 **BUY** |
| 2/3 (bon) | 🟢 **BUY** |
| 1/3 (faible) | ⚠️ **ATTENDRE** |
| 0/3 (aucune) | 🔴 **WAIT** |

---

## Fallback

### Si PsychoBot Indisponible

Le système enregistre le message dans `whatsapp_alerts.log` :

```
[2026-05-29T19:32:24+00:00]
📊 *TradBOT [18:32 UTC]*
...
```

Vous pouvez consulter ce fichier manuellement ou l'envoyer ultérieurement.

---

## Logs & Debugging

### Fichiers de Log

- **`whatsapp_daemon.log`** : Logs du daemon (vérifié par tail -f)
- **`whatsapp_alerts.log`** : Messages non envoyés via PsychoBot
- **`last_whatsapp_report.txt`** : Dernier rapport généré

### Vérifier les Logs

```bash
# Windows PowerShell
Get-Content whatsapp_daemon.log -Wait

# Linux/Mac
tail -f whatsapp_daemon.log
```

### Arrêter le Daemon

```bash
# Linux/Mac
pkill -f whatsapp_report_daemon.py

# Windows (Process Explorer ou PowerShell)
Stop-Process -Name python -Force
```

---

## Intégration avec GOM_KOLA_SIDO.pine

Le Pine Script **GOM_KOLA_SIDO.pine** continue de dessiner les indicateurs sur le chart.

Le système WhatsApp rapport consomme les données via :
- **TradingView MCP** pour les prix en live
- **AI Server** pour les verdicts GOM (déjà intégrés à partir des données Pine)

**Pas de modification du Pine Script requise** ✅

---

## Troubleshooting

### ❌ "AI server hors ligne"
- Vérifier que `ai_server.py` est lancé
- Vérifier `AI_SERVER_URL` dans `.env`
- Test: `curl http://127.0.0.1:8000/session-bias?symbol=XAUUSD`

### ❌ "PsychoBot error"
- Vérifier `PSYCHOBOT_URL` et `WHATSAPP_PHONE` dans `.env`
- Le rapport sera enregistré dans `whatsapp_alerts.log`
- Vérifier la connexion Internet

### ⚠️ "TradingView indisponible"
- C'est normal si TradingView MCP n'est pas lancé
- Le système continue avec les données AI server uniquement

---

## Roadmap

- [ ] Ajouter les indicateurs (VWAP, BB, Supertrend) au rapport
- [ ] Intégrer les niveaux Fibonacci directement
- [ ] Alertes SMS en cas de signal PERFECT
- [ ] Historique des rapports en BD Supabase
- [ ] Dashboard web des rapports
