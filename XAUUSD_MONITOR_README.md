# XAUUSD 20-Minute Monitoring System

## Vue d'ensemble

Système automatisé qui collecte les données XAUUSD toutes les 20 minutes et envoie un rapport unifié via WhatsApp.

**Sources de données**:
- TradingView (MCP) : quote, indicateurs, GOM KOLA tables
- AI Server : session-bias, pending-order, tradingagents report

**Destination**:
- PsychoBot WhatsApp : +2290196911346
- Fallback : `whatsapp_alerts.log` si PsychoBot hors ligne

## Fichiers

| Fichier | Description |
|---------|-------------|
| `xauusd_20min_monitor.py` | Script principal (collecte + envoi) |
| `schedule_xauusd_monitor.ps1` | Tâche planifiée Windows (exécution automatique) |
| `send_xauusd_report_now.py` | Test manuel rapide (données fixes) |
| `whatsapp_alerts.log` | Log de sauvegarde |

## Installation

### 1. Vérifier les prérequis

```bash
# Python 3.8+
python --version

# MCP TradingView disponible
python -c "from mcp__tradingview_kola import quote_get; print('OK')"

# AI Server en cours d'exécution
curl http://127.0.0.1:8000/health
```

### 2. Test manuel

```bash
cd D:\Dev\TradBOT
python xauusd_20min_monitor.py
```

**Sortie attendue**:
```
================================================================================
🚀 XAUUSD 20-Min Monitor — Unified Report
================================================================================
📺 Fetching TradingView data...
  ✓ TradingView data fetched
🤖 Fetching AI Server data...
  ✓ bias fetched
  ✓ order fetched
  ✓ ta fetched

💬 Building message...

================================================================================
MESSAGE:
================================================================================
📊 TradBOT [15:56 UTC]

*XAUUSD — Suivi 20min* | 30/05 15:56 UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $73858.79
...
================================================================================

📱 Envoi WhatsApp via PsychoBot...
✅ Message envoyé avec succès!
✅ Sauvegardé dans: D:\Dev\TradBOT\whatsapp_alerts.log

✅ Report complete
```

### 3. Activer la tâche planifiée

```powershell
# Exécuter PowerShell en tant qu'administrateur
cd D:\Dev\TradBOT
.\schedule_xauusd_monitor.ps1
```

**Résultat**:
```
✅ Scheduled task created successfully!

Task details:
  Name: TradBOT_XAUUSD_Monitor
  Script: D:\Dev\TradBOT\xauusd_20min_monitor.py
  Frequency: Every 20 minutes
  Log: D:\Dev\TradBOT\xauusd_monitor.log
```

## Utilisation

### Exécuter immédiatement

```powershell
Start-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'
```

### Vérifier le statut

```powershell
Get-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'
```

### Voir les logs

```bash
tail -f D:\Dev\TradBOT\whatsapp_alerts.log
```

### Désactiver temporairement

```powershell
Disable-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'
```

### Réactiver

```powershell
Enable-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'
```

### Supprimer la tâche

```powershell
Unregister-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor' -Confirm:$false
```

## Format du Message

```
📊 TradBOT [HH:MM UTC]

*XAUUSD — Suivi 20min* | DD/MM HH:MM UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $XXXX.XX
📍 VWAP : $XXXX.XX → prix AU-DESSUS/EN-DESSOUS
📊 BB : [inf / mid / sup]
⚡ Supertrend : $XXXX.XX (↑/↓) → AU-DESSUS/EN-DESSOUS
📐 Fibo : zone [inf - sup]
━━━━━━━━━━━━━━━━━━━━
🔴/🟢/⚪ *Verdict GOM KOLA : SELL/BUY/WAIT*
   Score BUY=X  SELL=X  Spike=X%
   RSI=XX | ST=↑/↓
━━━━━━━━━━━━━━━━━━━━
🔴/🟢/⚪ *Biais session :* DIRECTION XX% | ✅/❌ valide Xh
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* ACTION @ ENTRY | SL: XX | TP: XX
   (ou) 📭 *Ordre EA :* Aucun ordre EA actif
━━━━━━━━━━━━━━━━━━━━
🔴/🟢/⚪ *Rapport TradingAgents :* DIRECTION XX% | Age: Xmin
   (ou) ⚪ *Rapport TradingAgents :* N/A (données indisponibles)
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  ✅ CONFLUENCE: Tous les signaux en DIRECTION
  (ou) ⚠️ CONFLIT: Signaux mixtes (...)
  (ou) ⚪ NEUTRE: Pas de signal clair
🎯 *Décision scalping*
  (Voir ci-dessus pour BUY/SELL/WAIT)
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

## Dépannage

### Problème : "MCP tools not found"

**Solution**:
```bash
# Vérifier que Claude Code est lancé avec MCP TradingView activé
# Ou installer le package MCP si disponible
```

### Problème : "AI Server hors ligne"

**Cause** : `ai_server.py` n'est pas démarré

**Solution**:
```bash
cd D:\Dev\TradBOT
python ai_server.py
```

### Problème : "PsychoBot erreur HTTP 35"

**Cause** : Erreur SSL ou PsychoBot temporairement indisponible

**Solution** : Le message est automatiquement sauvegardé dans `whatsapp_alerts.log`

### Problème : "Permission denied"

**Solution** : Exécuter PowerShell en tant qu'administrateur pour créer la tâche planifiée

### Problème : La tâche ne s'exécute pas

**Vérifications**:
```powershell
# 1. Vérifier que la tâche existe
Get-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'

# 2. Vérifier l'historique de la tâche
Get-ScheduledTaskInfo -TaskName 'TradBOT_XAUUSD_Monitor'

# 3. Tester manuellement
Start-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│           XAUUSD 20-Minute Monitor System               │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ TradingView  │  │  AI Server   │  │  PsychoBot   │
│     MCP      │  │  curl REST   │  │   WhatsApp   │
└──────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        │   quote_get      │   /session-bias  │   /send-message
        │   study_values   │   /pending-order │
        │   pine_tables    │   /tradingagents │
        │                  │                  │
        └──────────────────┴──────────────────┘
                           │
                           ▼
             ┌──────────────────────────┐
             │  xauusd_20min_monitor.py │
             └──────────────────────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
       ┌─────────────────┐   ┌─────────────────┐
       │  WhatsApp       │   │  whatsapp_      │
       │  +229 019...    │   │  alerts.log     │
       └─────────────────┘   └─────────────────┘
```

## Exemples de Sortie

### Confluence (BUY aligné)
```
🔬 *Analyse croisée*
  ✅ CONFLUENCE: Tous les signaux en BUY
🎯 *Décision scalping*
  BUY confirmé — Entrée immédiate
```

### Conflit (signaux opposés)
```
🔬 *Analyse croisée*
  ⚠️ CONFLIT: GOM=SELL vs EA=BUY
  → Bias expiré, EA actif, attendre confirmation marché
🎯 *Décision scalping*
  WAIT — Ordre EA en place | GOM bearish non confirmé
```

### AI Server hors ligne
```
⚪ *Biais session :* ⚠️ AI server hors ligne
━━━━━━━━━━━━━━━━━━━━
📭 *Ordre EA :* Aucun ordre EA actif
━━━━━━━━━━━━━━━━━━━━
⚪ *Rapport TradingAgents :* N/A (données indisponibles)
```

## Logs

### Structure du log (`whatsapp_alerts.log`)
```
[2026-05-30 15:56:42] XAUUSD UNIFIED
📊 TradBOT [15:56 UTC]

*XAUUSD — Suivi 20min* | 30/05 15:56 UTC
━━━━━━━━━━━━━━━━━━━━
...
========================================
```

### Rotation des logs

Le fichier `whatsapp_alerts.log` peut grossir. Pour rotation :

```powershell
# Archiver si > 10 MB
$LogFile = "D:\Dev\TradBOT\whatsapp_alerts.log"
$MaxSize = 10MB

if ((Get-Item $LogFile).Length -gt $MaxSize) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Move-Item $LogFile "$LogFile.$Timestamp.bak"
}
```

## Performance

- **Temps d'exécution** : 3-10 secondes
- **Bande passante** : ~5 KB par exécution
- **Fréquence** : Toutes les 20 minutes = 72 rapports/jour

## Sécurité

- ✅ Pas de secrets hardcodés (numéro téléphone OK)
- ✅ Logs en UTF-8 (emojis supportés)
- ✅ Fallback automatique si service down
- ✅ Timeout sur toutes les requêtes réseau

## Maintenance

### Hebdomadaire
- Vérifier que la tâche s'exécute bien
- Vérifier les logs pour erreurs récurrentes

### Mensuel
- Archiver `whatsapp_alerts.log` si > 10 MB
- Vérifier les mises à jour de PsychoBot

### Mise à jour du script
```bash
# 1. Désactiver la tâche
Disable-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'

# 2. Modifier xauusd_20min_monitor.py

# 3. Tester
python xauusd_20min_monitor.py

# 4. Réactiver
Enable-ScheduledTask -TaskName 'TradBOT_XAUUSD_Monitor'
```

## Support

Pour toute question ou problème :
1. Vérifier les logs (`whatsapp_alerts.log`)
2. Tester manuellement (`python xauusd_20min_monitor.py`)
3. Vérifier que TradingView MCP + AI Server sont actifs
