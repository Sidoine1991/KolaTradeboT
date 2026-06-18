# GOM Sync + WhatsApp Report — Boucle 10 Minutes

## 🎯 Vue d'ensemble

Synchronisation automatique des verdicts GOM toutes les 10 minutes avec:
- ✅ Chargement données MT5 live depuis AI server
- ✅ Construction rapport standardisé (Emoji + Entry/SL/TP/Cohérence)
- ✅ Envoi WhatsApp (AI server ou PsychoBot fallback)
- ✅ Logging complet avec timestamps
- ✅ Support Windows Scheduler (24/7 automatique)

## 🚀 Démarrage Rapide

### Option 1: Exécution Manuelle (Une fois)
```bash
cd D:/Dev/TradBOT
python python/gom_sync_with_report.py --report
```

### Option 2: Boucle PowerShell (Interactive)
```powershell
# Boucle 10 minutes (défaut)
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1

# Boucle 5 minutes
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -IntervalMinutes 5

# Exécution unique avec reporting
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -RunOnce
```

### Option 3: Windows Scheduler (24/7 Automatique)
```batch
REM Run as ADMIN - Install
install_gom_sync_task.bat install

REM Check status
install_gom_sync_task.bat status

REM Uninstall if needed
install_gom_sync_task.bat uninstall
```

## 📊 Exemple de Rapport

```
🎯 **GOM VERDICTS REPORT**
==================================================
🟢 BOOM 900 INDEX — BUY | Entry: 9156.29 | SL: 9146.69 | TP: 9175.47 | Coh: 83%
  🟢M1 🟢M5 🟢M15 🟢H1 🟢H4 🔴D1

🔴 CRASH 300 INDEX — PERFECT SELL | Entry: 1827.75 | SL: 1841.12 | TP: 1801.02 | Coh: 83%
  🔴M1 🔴M5 ⚪M15 ⚪H1 🔴H4 ⚪D1

🔴 BTCUSD — GOOD SELL | Entry: 65811.64 | SL: 65937.44 | TP: 65622.93 | Coh: 83%
  🔴M1 🔴M5 🔴M15 🔴H1 🟢H4 🔴D1
==================================================
📅 2026-06-17 00:55:15 UTC
```

## 📁 Fichiers

| Fichier | Description |
|---------|------------|
| `python/gom_sync_with_report.py` | Script principal (exécutable une fois ou en boucle) |
| `gom_sync_loop.ps1` | Wrapper PowerShell pour boucle 10-min (nouveau) |
| `install_gom_sync_task.bat` | Installateur Windows Scheduler (nouveau) |
| `data/gom_signal.json` | Verdicts GOM (enrichi tf_*_dir + coherence_pct) |
| `logs/gom_sync.log` | Log principal (append mode, persistant) |
| `logs/gom_sync_loop.log` | Log boucle PowerShell (tous les runs) |

## 📋 Logs

### Format
```
[2026-06-17 00:52:35] - INFO - [SYNC] Exécution unique GOM sync...
[2026-06-17 00:52:45] - INFO - [OK] Charge 2 verdicts GOM depuis dashboard MT5 LIVE
[2026-06-17 00:53:01] - INFO - [SEND] CRASH 300 INDEX → GOOD SELL (HTTP 200)
[2026-06-17 00:53:06] - INFO - [OK] Rapport WhatsApp envoyé via AI server
```

### Emplacements
- **Principal**: `logs/gom_sync.log` (append mode, toutes les exécutions)
- **Boucle**: `logs/gom_sync_loop.log` (créé par PowerShell, stats + timestamps)

### Consulter Logs (PowerShell)
```powershell
# 20 dernières lignes
Get-Content logs\gom_sync.log | Select-Object -Last 20

# Compter succès
(Get-Content logs\gom_sync.log | Select-String "\[OK\]").Count

# Voir erreurs
Get-Content logs\gom_sync.log | Select-String "\[ERROR\]"

# Logs boucle
Get-Content logs\gom_sync_loop.log
```

## 🎯 Fenêtres de Trading (UTC)

| Symbole | Fenêtre | Statut |
|---------|---------|--------|
| BOOM 1000 | 7-16 | ⚠️ Actif seulement ces heures |
| BOOM 500 | 8-16 | ⚠️ Rejeté hors fenêtre |
| CRASH 300 | 8-16 | ⚠️ Rejeté hors fenêtre |
| CRASH 1000 | 8-16 | ⚠️ Rejeté hors fenêtre |
| XAUUSD | 7-17 | ⚠️ Rejeté hors fenêtre |
| BTCUSD | 8-22 | ⚠️ Rejeté hors fenêtre |

**Note**: Boom/Crash rejettent avec `HTTP 403` hors fenêtre tradeables (design intent).

## 🔧 Gates Appliquées

1. **[GATE-Boom/Crash Direction]** — SELL interdit sur Boom, BUY interdit sur Crash
2. **[GATE-IA-STATUS]** — Cohérence < 70% (synthétiques) ou < 80% (autres)
3. **[GATE-BC-HEURE]** — Boom/Crash hors fenêtre UTC
4. **[GATE-SESSION]** — Symbole hors fenêtre trading UTC
5. **[GATE-RSI]** — RSI extreme (BUY > 78, SELL < 22)
6. **[GATE-M15]** — M15 opposé à direction

## 📊 Top 3 Symboles (Historique)

| Rang | Symbole | Trades | Win Rate | Profit Factor | PnL Net |
|------|---------|--------|----------|---------------|---------|
| 🥇 | Boom 150 Index | 30 | **70.0%** | **1.38x** | +3.50 |
| 🥈 | Boom 50 Index | 15 | **73.3%** | **1.40x** | +2.23 |
| 🥉 | Crash 1000 Index | 60 | 56.7% | 1.23x | +7.32 |

## ⚙️ Paramètres PowerShell

### gom_sync_loop.ps1

```powershell
# Intervalle en minutes (défaut: 10)
-IntervalMinutes 5

# Exécution unique (défaut: boucle infinie)
-RunOnce
```

### Exemples
```powershell
# Boucle 5 minutes
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -IntervalMinutes 5

# Exécution unique avec stats
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -RunOnce

# Boucle 10 min (défaut)
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1
```

## 🔧 Commandes Utiles

```bash
# Exécuter une fois
python python/gom_sync_with_report.py --report

# PowerShell interactive loop (Ctrl+C pour arrêter)
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1

# Windows Scheduler install (admin)
install_gom_sync_task.bat install

# Vérifier tâche
install_gom_sync_task.bat status

# Arrêter tâche
install_gom_sync_task.bat uninstall
```

## 📌 Données Sources

Priorité de chargement:

1. **`/gom-verdicts`** (serveur AI live) — Priorité HAUTE
2. **`/gom-kola-dashboard`** (MT5 temps réel) — Priorité HAUTE
3. **`gom_signal.json`** (fichier local) — Fallback (peut être stale)

## 🎓 Dépannage

### WhatsApp timeout
```
[ERROR] Erreur WhatsApp (PsychoBot): HTTPSConnectionPool timeout=30
```
→ PsychoBot Render indisponible, rapport stocké en logs

### Boom/Crash rejetés
```
HTTP 403: {"detail":"BC heure UTC 23 — confiance 18% < 60%"}
```
→ Hors fenêtre tradeable (8-16 UTC). Tester durant ces heures.

### Gate cohérence bloque
```
[GATE-COH] BOOM 900 INDEX: cohérence 83% < 85% — ordre ignoré
```
→ Seuil cohérence peut être ajusté dans pipeline (actuellement 85% stricte)

## 📞 Support

- **Logs**: `D:\Dev\TradBOT\logs\`
- **Config**: `D:\Dev\TradBOT\data\gom_signal.json`
- **AI Server**: `http://127.0.0.1:8000`
- **WhatsApp**: Sidoine (+2290196911346)
- **Memory**: `session_2026_06_17_gom_sync_whatsapp.md`

---

**Déploiement Date**: 2026-06-17  
**Status**: ✅ Production Ready  
**Mode**: Boucle 10 minutes avec logging complet
