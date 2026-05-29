# WhatsApp Report System — Quick Start

## 🚀 Démarrage Rapide (5 min)

### Étape 1: Vérifier la configuration

```bash
# Vérifier que ai_server.py est actif
curl -s http://127.0.0.1:8000/session-bias?symbol=XAUUSD

# Sortie attendue:
# {"success":true,"data":{"direction":"BUY","confidence":0.9,...}
```

### Étape 2: Tester un rapport unique

```bash
python scripts/whatsapp_unified_report.py
```

✅ Le message doit être envoyé via WhatsApp et écrit dans `last_whatsapp_report.txt`.

### Étape 3: Lancer le daemon (20min boucle)

#### **Windows PowerShell**
```powershell
.\Start-WhatsAppReportDaemon.ps1
```

#### **Linux/Mac Terminal**
```bash
bash start_whatsapp_daemon.sh
```

---

## 📊 Message Reçu

Vous recevrez un message WhatsApp comme celui-ci chaque 20 minutes:

```
📊 *TradBOT [18:34 UTC]*

*XAUUSD — Suivi 20min* | 29/05 18:34 UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $4560.52
   Open: $4559.45 | High: $4560.86 | Low: $4559.44
━━━━━━━━━━━━━━━━━━━━
🟢 *Verdict GOM KOLA : BUY*
   Score BUY=11.56  SELL=-0.35
   Verdict: PERFECT BUY
   Entry: $4534.40 | SL: $4532.35 | TP: $4545.35
   Ticket MT5: 1376457740
━━━━━━━━━━━━━━━━━━━━
🟢 *Biais session :* BUY 90% | ✅ valide 12h
━━━━━━━━━━━━━━━━━━━━
🟢 *Rapport TradingAgents :* BUY 88%
   Age: 5min | Expire: 55min
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
   ✅ Confluence 3/3 pour BUY
   🎯 *Décision : BUY*
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

---

## 📋 Architecture

```
TradingView (live price)
    ↓
whatsapp_unified_report.py → Collecte données
    ↓
AI Server (biais, ordres, TA)
    ↓
Message Unifié
    ↓
PsychoBot → WhatsApp
```

---

## 🛑 Arrêter le Daemon

### Windows
```powershell
Stop-Process -Name python -Force
```

### Linux/Mac
```bash
pkill -f whatsapp_report_daemon.py
```

---

## 📁 Fichiers Importants

| Fichier | Rôle |
|---------|------|
| `scripts/whatsapp_unified_report.py` | Générateur report |
| `scripts/whatsapp_report_daemon.py` | Boucle autonome |
| `last_whatsapp_report.txt` | Dernier message |
| `whatsapp_daemon.log` | Logs en temps réel |
| `whatsapp_alerts.log` | Messages non envoyés |

---

## ✅ Checklist

- [ ] `ai_server.py` est lancé
- [ ] `.env` contient `PSYCHOBOT_URL` et `WHATSAPP_PHONE`
- [ ] Test rapport unique OK
- [ ] Daemon lancé (Windows PS ou Linux bash)
- [ ] ✅ Message WhatsApp reçu toutes les 20 min

---

## 🔗 Liens Utiles

- Documentation complète: `WHATSAPP_REPORT_SYSTEM.md`
- GOM Pine Script: `GOM_KOLA_SIDO.pine`
- AI Server: `ai_server.py`
- TradBOT Kernel: `CLAUDE.md`
