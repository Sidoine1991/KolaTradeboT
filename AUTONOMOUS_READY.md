# 🤖 SYSTÈME DE TRADING AUTONOME — PRÊT À LANCER

## ✅ STATUS: 100% PRÊT

Tout est configuré. Vous n'avez **QUE 3 CHOSES À FAIRE** pour que le robot trade à votre place.

---

## 🚀 LANCER EN 30 SECONDES

### Option 1: Double-cliquer (FACILE)
```
Double-cliquer sur: start-autonomous.bat
```

### Option 2: Ligne de commande (AVANCÉ)
```powershell
cd D:\Dev\TradBOT
.\start-autonomous.bat
```

---

## 📋 APRÈS LE LANCEMENT

### ✅ 3 terminaux s'ouvriront automatiquement

**Terminal 1: Master GOM Poller** (🔴 NE PAS FERMER)
- Met à jour `gom_signal.json` en continu
- Récupère verdicts MT5 live
- **CRITIQUE**: Si on ferme, pas de données fraîches

**Terminal 2: GOM Sync Scheduler**
- Chaque 10 min: charge verdicts + envoie rapport WhatsApp
- Peut être fermé si vous surveillez manuellement

**Terminal 3: Trailing Stop Monitor**
- Chaque 5 sec: gère SL/TP + breakeven
- Peut être fermé si positions = autogérées par EA

---

## 🎯 MAINTENANT: CONFIGURER MT5

### Étape 1: Ouvrir MT5

### Étape 2: Attacher SMC_Universal.mq5

1. Ouvrir n'importe quel graphique (ex: XAUUSD M1)
2. Dans le navigateur, chercher "SMC_Universal"
3. Double-cliquer ou drag-drop sur le graphique
4. Cliquer "OK"

### Étape 3: Vérifier les inputs

```
Dans la fenêtre "Inputs" de l'EA:

✅ DisableAllAutoEntries = FALSE
✅ AllowLiveTrading = TRUE
✅ GOM_RequireCoherence = TRUE (gate 70%+)
✅ AI_Timeout_ms = 5000
```

### Étape 4: Activer AutoTrading

Cliquer le bouton **AutoTrading** (top toolbar MT5)

---

## 🎯 QUE SE PASSE-T-IL?

```
TOUTES LES 10 MIN:
  📊 GOM Sync Scheduler
     • Charge verdicts GOM
     • Envoie rapport WhatsApp
     • Signal: "Entry: 2250.5 | SL: 2245 | TP: 2260 | Coh: 85%"
     
TOUTES LES 5 SEC:
  🔒 Position Monitor
     • Monitore positions ouvertes
     • Applique Breakeven SL à +$2 profit
     • Applique Trailing Stop (0.5% distance)
     
TEMPS RÉEL (Chaque nouvelle bougie M1):
  🤖 SMC_Universal.mq5 (EA)
     • Vérifie /gom-verdict endpoint
     • Valide multi-TF (H4, H1, M15, M1)
     • SI tous les feux verts → PLACE ORDRE
     • Gère SL/TP automatiquement
```

---

## ✅ EXEMPLE DE SIGNAL COMPLET

```
2026-06-12 16:30:00 - GOM SYNC RAPPORT
================================================
🟢 BOOM 1000 INDEX — PERFECT BUY
   Entry: 13920.27
   SL: 13890.96
   TP: 13978.88
   Coherence: 85%
   
   Multi-TF:
   🟢 M1 aligned
   🟢 M5 aligned
   🟢 M15 aligned
   🟢 H1 aligned
   🔴 H4 contre (mais gates OK)
   
   ACTION:
   ✅ Gates passées:
      • Coherence 85% > 70% ✓
      • Boom rule OK ✓
      • Risk 1.2% < 2% ✓
      • Multi-TF 4/5 aligned ✓
   
   ✅ ORDRE PLACÉ PAR SMC_Universal
      • Ticket: 123456
      • Type: BUY
      • Volume: 0.20 lot
      • Entry: 13920.27
      • SL: 13890.96
      • TP: 13978.88
```

---

## 💰 RÉSULTATS

Vous recevrez sur WhatsApp:

### Rapport toutes les 10 min
```
🎯 **TRADING REPORT**
🟢 BOOM 1000 INDEX — BUY @ 13920.27
   SL: 13890.96 | TP: 13978.88
   
🟡 XAUUSD — NEUTRAL (attente)

📊 Positions: 1 ouverte, +58$ profit
```

### Alertes en temps réel
```
✅ Ordre placé: BOOM 1000 BUY
🔒 Breakeven activé: +$2 gain
📈 Position: +$58 (trailing SL: 13915)
⏹️ Position fermée: +$142 gain
```

---

## 🛑 KILL SWITCHES (Sécurité)

### ⚠️ Si quelque chose ne va pas

**Option 1: Arrêter les services Python**
```powershell
# Fermer les 3 terminaux (Ctrl+C dans chaque)
# OU
pkill -f "master_gom_poller"
pkill -f "gom_sync_scheduler"
pkill -f "trademanager_position_sync"
```

**Option 2: Désactiver l'EA**
```
MT5 → Cliquer AutoTrading OFF
```

**Option 3: Fermer MT5**
```
Fermer le terminal MT5 complètement
```

---

## 🔍 MONITORING & LOGS

### Voir les logs en temps réel
```powershell
# GOM Sync
tail -f logs/gom_sync_scheduler.log

# Position Monitor
tail -f logs/trademanager_sync.log

# Rechercher les erreurs
grep -i "error" logs/*.log
```

### Vérifier les processus en cours
```powershell
Get-Process python | Select-Object Name, ProcessName, Path
```

---

## 📊 CHECKLIST PRÉ-LANCEMENT

Avant de lancer, vérifier:

- [ ] Master GOM Poller lancé (Terminal 1 ouvert)
- [ ] GOM Sync Scheduler lancé (Terminal 2 ouvert)
- [ ] Trailing Stop Monitor lancé (Terminal 3 ouvert)
- [ ] MT5 ouvert
- [ ] SMC_Universal.mq5 attaché à un graphique
- [ ] AutoTrading activé (bouton vert)
- [ ] Inputs vérifiés (DisableAllAutoEntries = FALSE)
- [ ] Numéro WhatsApp configuré
- [ ] AI Server tourne sur http://127.0.0.1:8000

---

## ⏰ AUTOMATISATION COMPLÈTE

```
┌─────────────────────────────────────┐
│ MT5 Terminal                        │
│ ↓ SMC_Universal.mq5 (EA)           │
│   Écoute verdicts GOM en temps réel │
│   Place ordres automatiquement       │
│   Gère SL/TP avec Trailing Stop     │
└──────┬──────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│ AI Server (Python)                  │
│ ↓ /gom-verdict endpoint            │
│   Fournit verdicts GOM              │
│   Valide qualité des signaux        │
│   Gère la logique métier            │
└──────┬──────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│ Background Services                 │
│ ↓ master_gom_poller (live data)    │
│ ↓ gom_sync_scheduler (10 min)      │
│ ↓ position_sync (5 sec)             │
│   Tous les 3 tournent en boucle     │
└─────────────────────────────────────┘

RÉSULTAT: 100% AUTONOME ✅
```

---

## 🎯 CE QUE VOUS FAITES

1. ✅ Lancer `start-autonomous.bat` (une fois)
2. ✅ Attacher EA à MT5 (une fois)
3. ✅ Cliquer AutoTrading (une fois)
4. ✅ **ATTENDRE** — Le robot trade à votre place 24/7

---

## 💡 VOS POUVOIRS DE CONTRÔLE

✅ Pouvez modifier les inputs EA en temps réel
✅ Pouvez arrêter les services à tout moment
✅ Pouvez intervenir manuellement si besoin
✅ Recevez alerts WhatsApp pour chaque signal
✅ Pouvez fermer positions manuellement
✅ Pouvez changer les gates de qualité
✅ Emergency button: AutoTrading OFF

---

## 📚 DOCUMENTATION

- `AUTONOMOUS_TRADING_SETUP.md` — Guide complet
- `COMMANDS_CHEATSHEET.md` — Commandes rapides
- `TRAILING_STOP_GUIDE.md` — Mécanics SL/TP
- `PRODUCTION_STATUS.md` — État du système

---

## 🚀 VOUS ÊTES PRÊT!

### Maintenant lancez:
```
Double-cliquer sur: start-autonomous.bat
```

Le système démarrera avec:
- ✅ Verdicts GOM en temps réel
- ✅ Ordres automatiques
- ✅ SL/TP gérés
- ✅ Rapports WhatsApp

**Claude ne peut pas trader à votre place, mais CE SYSTÈME peut! 🤖**

---

**Last Updated**: 2026-06-12  
**Status**: 🟢 READY TO LAUNCH
