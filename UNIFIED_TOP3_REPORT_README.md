# Unified TOP 3 Report System

## Vue d'ensemble

**UN SEUL message WhatsApp consolidé** envoyé **toutes les 20 minutes** contenant:
- ✅ Classement TOP 3 avec table récapitulative
- ✅ Analyse détaillée de chaque symbol
- ✅ Confluence scores et alignements
- ✅ Données TradingView en direct (prix, VWAP, BB, etc.)
- ✅ Données AI Server (GOM verdict, biais session, ordres EA)
- ✅ Analyse croisée (multi-symbol alignment)
- ✅ Décision scalping unifiée

---

## Architecture

```
unified_top3_master_report.py (script unique)
    ├─ Fetch ALL data for 3 symbols (parallèle)
    │   ├─ TradingView: Prices
    │   ├─ AI Server: /session-bias
    │   ├─ AI Server: /pending-order
    │   └─ Calculate confluence
    ├─ Build SINGLE consolidated message
    └─ Send via WhatsApp

unified_top3_daemon.py (exécution toutes les 20 min)
    └─ Appelle le script master répétitivement

Résultat: UN message unique par 20 min
```

---

## Installation

### Prérequis
```bash
pip install requests python-dotenv
```

### Configuration `.env`
```ini
AI_SERVER_URL=http://127.0.0.1:8000
PSYCHOBOT_URL=https://psychobot-1si7.onrender.com
WHATSAPP_PHONE=+2290196911346
```

---

## Utilisation

### Test unique (génère et envoie 1 rapport)
```bash
python scripts/unified_top3_master_report.py
```

### Daemon continu (20 min interval)

**Windows (PowerShell)**
```powershell
.\Start-UnifiedTop3Daemon.ps1
```

**Linux/Mac (Bash)**
```bash
bash start_unified_top3_daemon.sh
```

---

## Format du Message WhatsApp

```
📊 *TradBOT UNIFIED TOP 3 REPORT* [HH:MM UTC]

*Complete Daily Surveillance* | DD/MM HH:MM UTC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

*1. TOP 3 RANKING*
┌─────┬─────────┬─────────────┬──────────┬────────────────┐
│ Rank│ Symbol  │ Price       │ GOM/Bias │ Confluence     │
├─────┼─────────┼─────────────┼──────────┼────────────────┤
│ 🥇  │ XAUUSD  │ $4554.59    │ GOOD/BUY │ 2/2 ✅         │
│ 🥈  │ EURUSD  │ $1.0895     │ WAIT/BUY │ 1/2            │
│ 🥉  │ BTCUSD  │ $62450      │ WAIT/NEU │ 0/2            │
└─────┴─────────┴─────────────┴──────────┴────────────────┘

*2. DETAILED ANALYSIS*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🥇 *XAUUSD*
   Price: $4554.59 (Live)
   🟢 GOM Verdict: GOOD BUY
      • BUY Score: 7.2
      • SELL Score: 3.1
   🟢 Session Bias: BUY 90%
      • Expires: 11.7h
      • Valid: ✅
   📦 Order EA: BUY
      • Entry: $4557.21
      • Confidence: 88%
      • Status: ready
   Score Confluence: 2/2 ✅ MULTIPLE

[... etc pour EURUSD et BTCUSD ...]

*3. CROSS ANALYSIS*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Top 1 (XAUUSD):
  → Confluence: 2/2 ✅
  → GOOD BUY + BUY bias

• Signal Count:
  → BUY signals: 1
  → With Confluence: 1
  → WAIT signals: 2

*4. TRADING DECISION*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ WEAK CONFLUENCE
   → Entry READY but WAIT for confirmation
   → Enter on next candle close
   → Monitor bias validity

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

*5. NEXT UPDATE* in 20 min
Session Active: 24/7 Autonomous
Last Update: HH:MM:SS UTC
```

---

## Données collectées

### TradingView (Prices)
- XAUUSD: $price live
- EURUSD: $price live
- BTCUSD: $price live

### AI Server - Session Bias
```json
{
  "direction": "BUY|SELL|NEUTRAL",
  "confidence": 0.9,
  "valid": true,
  "expires_in_hours": 11.9
}
```

### AI Server - Pending Order (GOM Verdict)
```json
{
  "order": {
    "action": "BUY|SELL|WAIT",
    "gom_verdict": "PERFECT BUY|GOOD BUY|BUY|WAIT|SELL",
    "gom_score_buy": 7.2,
    "gom_score_sell": 3.1,
    "entry_price": 4557.21,
    "confidence": 0.88,
    "status": "ready"
  }
}
```

---

## Confluence Scoring

```
Confluence = GOM Signal + Session Bias Alignment

Score 2/2:
  ✅ GOM = BUY + Bias = BUY
  → EXECUTE immediately

Score 1/2:
  ⚠️ GOM = BUY + Bias = NEUTRAL
  → READY but wait for confirmation

Score 0/2:
  ❌ No BUY signal or misalignment
  → HOLD
```

---

## Trading Decision Logic

| Top 1 Confluence | With Bias | Decision |
|---|---|---|
| 2/2 | 1+ | ✅ EXECUTE immediately |
| 1/2 | 1 | ⚠️ Entry ready, wait |
| 0/2 | - | ❌ HOLD, no trade |

---

## Fichiers générés

| Fichier | Contenu |
|---------|---------|
| `unified_top3_report_latest.txt` | Dernier rapport généré |
| `unified_top3_daemon.log` | Logs du daemon (tail -f) |
| `whatsapp_alerts.log` | Messages non envoyés (fallback) |

---

## Arrêter le Daemon

**Windows**
```powershell
Stop-Process -Name python -Force
```

**Linux/Mac**
```bash
pkill -f unified_top3_daemon.py
```

---

## Avantages du système unifié

✅ **UN seul message** = pas de spam 3 messages  
✅ **Format consolidé** = facile à lire et comparer  
✅ **Toutes les données** = contexte complet en 1 message  
✅ **Confluence claire** = décision immédiate sans calcul  
✅ **20 min cycle** = suivi continu sans overload  
✅ **Fallback robuste** = pas de perte de données  

---

## Troubleshooting

### Le daemon ne lance pas
```bash
# Vérifier les logs
tail -f unified_top3_daemon.log

# Test du script unique
python scripts/unified_top3_master_report.py
```

### Pas de message WhatsApp
- Vérifier `.env`: `PSYCHOBOT_URL`, `WHATSAPP_PHONE`
- Vérifier les logs: `whatsapp_alerts.log`
- Message sauvegardé localement: `unified_top3_report_latest.txt`

### AI Server inaccessible
- Le rapport continue avec les données TradingView
- Sections GOM/Bias affichent "WAIT" ou "N/A"
- Log indique: "[Warning] AI server timeout"

---

## Prochaines étapes

- [ ] Intégrer données GOM Pine Script directement
- [ ] Ajouter niveaux Fibonacci à l'analyse
- [ ] SMS alert si confluence >= 2
- [ ] Dashboard web historique
- [ ] BD Supabase pour archivage
