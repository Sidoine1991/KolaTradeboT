# GOM Sync Scheduler — Synchronisation 10 Minutes

## Vue d'ensemble

La synchronisation GOM s'exécute **toutes les 10 minutes** pour :

1. **Charger** les verdicts GOM depuis `/gom-verdicts` (live) ou `gom_signal.json` (fallback)
2. **Filtrer** les signaux actifs (verdict_num ≠ 0) + validation Boom/Crash
3. **Envoyer** chaque verdict via POST `/gom-verdict` à l'ai_server
4. **Construire** un rapport formaté avec Entry/SL/TP/Cohérence
5. **Envoyer** le rapport via WhatsApp (endpoint `/notify-whatsapp`)
6. **Logger** tous les détails avec timestamps

---

## 🚀 Démarrage Rapide

### Exécution Unique (test)
```bash
cd D:/Dev/TradBOT
python Python/gom_sync_with_report.py --report
```

### Boucle 10 Minutes (production)
```bash
python Python/gom_sync_scheduler.py
```

### Via Script Windows
```cmd
D:\Dev\TradBOT\scripts\start_gom_sync_10min.bat
```

### Tâche Planifiée (autonome)
```powershell
PowerShell -ExecutionPolicy Bypass -File D:\Dev\TradBOT\scripts\register_gom_sync_10min_task.ps1
```

---

## 📊 Flux de Données

```
GOM MT5 (Live Candles)
    ↓
/gom-verdicts endpoint
    ↓
Load Signals + Dedup + Filter (timestamp < 1h)
    ↓
Filter Active (verdict_num ≠ 0)
    ↓
Validate Boom/Crash Rules
    ↓
POST /gom-verdict (per signal)
    ↓
Build Report
    ├─ Format: "🟢 SYMBOL — ACTION | Entry: X | SL: X | TP: X | Coh: X%"
    └─ Include: TF directions (M1-D1)
    ↓
POST /notify-whatsapp
    ↓
Log + File (logs/gom_sync_scheduler.log)
```

---

## 📝 Format Rapport WhatsApp

```
🎯 **GOM VERDICTS REPORT**
==================================================
🟢 BOOM 1000 INDEX — GOOD BUY | Entry: 13890.55 | SL: 13854.22 | TP: 13927.88 | Coh: 67%
  🟢M1 🔴M5 🟢M15 🟢H1 🔴H4 🔴D1
🟢 XAUUSD — GOOD BUY | Entry: 4203.96 | SL: 4199.55 | TP: 4211.23 | Coh: 50%
  🟢M1 🟢M5 🔴M15 🟢H1 🔴H4 🔴D1
==================================================
📅 2026-06-12 16:05:14 UTC
```

**Légende:**
- 🟢 = BUY / BULL / Bullish
- 🔴 = SELL / BEAR / Bearish
- ⚪ = WAIT / NEUT / Neutral

---

## 📋 Options de Commande

### gom_sync_with_report.py
```bash
python Python/gom_sync_with_report.py --report
# Exécute une seule fois et quitte

python Python/gom_sync_with_report.py
# Boucle infinie (10 min par défaut)
```

### gom_sync_scheduler.py
```bash
python Python/gom_sync_scheduler.py
# Boucle infinie (10 min)

python Python/gom_sync_scheduler.py --once
# Exécute une seule fois et quitte

python Python/gom_sync_scheduler.py --interval 300
# Boucle avec intervalle personnalisé (300s = 5 min)
```

---

## 📊 Logs

### Logs Fichier
```bash
# GOM Sync (raw)
tail -f logs/gom_sync.log

# Scheduler (avec timestamps complets)
tail -f logs/gom_sync_scheduler.log
```

### Format Logs
```
2026-06-12 16:05:11 [INFO] [Itération 1] Démarrage synchronisation...
2026-06-12 16:05:12 [INFO] [OK] Charge 7 verdicts GOM depuis serveur LIVE
2026-06-12 16:05:13 [INFO] [SEND] BOOM 500 INDEX → PERFECT SELL (HTTP 200)
2026-06-12 16:05:14 [INFO] [OK] Rapport WhatsApp envoyé (HTTP 200)
2026-06-12 16:05:14 [INFO] ⏰ Prochain sync dans 10 minutes...
```

---

## 🔧 Configuration

### Variables d'Environnement
```bash
# .env ou export
AI_SERVER_URL=http://127.0.0.1:8000
WHATSAPP_PHONE_NUMBER=+2290196911346
```

### Fichiers
- **GOM Source**: `data/gom_signal.json` (fallback si serveur down)
- **Logs**: `logs/gom_sync.log` + `logs/gom_sync_scheduler.log`
- **Intervalle**: 10 minutes (600 sec) — configurable via `--interval`

---

## ✅ Prérequis

- ✓ `ai_server` running sur `http://127.0.0.1:8000`
- ✓ Endpoint `/gom-verdicts` accessible
- ✓ Endpoint `/gom-verdict` accessible
- ✓ Endpoint `/notify-whatsapp` accessible
- ✓ Données GOM MT5 à jour
- ✓ PsychoBot + WhatsApp configurés
- ✓ Dossier `logs/` accessible

---

## 🐛 Troubleshooting

### Aucun verdict trouvé
```bash
# Vérifier /gom-verdicts
curl http://127.0.0.1:8000/gom-verdicts | jq '.verdicts | length'
```

### Verdict stale (> 1h)
- Les verdicts avec timestamp > 1h sont automatiquement rejetés
- Vérifier que GOM MT5 sync est actif

### WhatsApp non envoyé
- Vérifier logs pour HTTP response code
- Vérifier PsychoBot accessible
- Vérifier WhatsApp bot connecté

### Script crash après N itérations
- Vérifier logs pour exceptions
- Vérifier memory/disk libre
- Relancer scheduler

---

## 📈 Performance

- **Scan + Load**: ~1-2 secondes
- **POST verdicts**: ~2-3 secondes (7 signaux)
- **Build report**: ~0.5 secondes
- **WhatsApp send**: ~1-2 secondes
- **Total par cycle**: ~5-10 secondes

---

## 🎯 Mise en Production

### Option 1: Lancer Manuellement
```cmd
D:\Dev\TradBOT\scripts\start_gom_sync_10min.bat
```

### Option 2: Tâche Planifiée Windows
```powershell
PowerShell -ExecutionPolicy Bypass -File D:\Dev\TradBOT\scripts\register_gom_sync_10min_task.ps1

# Vérifier la tâche
Get-ScheduledTask -TaskName "TradBOT-GOM-Sync-10min"

# Lancer manuellement
Start-ScheduledTask -TaskName "TradBOT-GOM-Sync-10min"

# Voir l'exécution
Get-ScheduledTaskInfo -TaskName "TradBOT-GOM-Sync-10min"
```

### Option 3: Boucle Infinie Console
```bash
cd D:/Dev/TradBOT
python Python/gom_sync_scheduler.py
# Ctrl+C pour arrêter
```

---

## 📞 Support

Pour déboguer :
1. Lancer `--report` une fois
2. Vérifier logs/gom_sync.log
3. Vérifier logs/gom_sync_scheduler.log
4. Vérifier endpoints ai_server
5. Vérifier WhatsApp/PsychoBot

---

## Version Info

- **Version**: 1.0
- **Release**: 2026-06-12
- **Interval**: 10 minutes (configurable)
- **Status**: ✅ Production Ready

---

**Prêt à synchroniser ?** 🚀
```bash
python Python/gom_sync_scheduler.py
```
