# 🚀 GUIDE DE DÉMARRAGE — TradBOT v10.04

**Date:** 2026-06-07  
**Temps estimé:** 15 minutes  

---

## ✅ ÉTAPE 1 : Tester l'EA MT5 (5 min)

### 1.1 Ouvrir MetaTrader 5

```
1. Lance MetaTrader 5
2. Ouvre le graphique Boom 500 Index (ou Crash 500 Index)
3. Timeframe : M1 (1 minute)
```

### 1.2 Attacher l'EA deriveapro.mq5

```
1. Dans le Navigateur MT5 (Ctrl+N)
2. Dossier "Experts" → cherche "deriveapro"
3. Glisse-dépose sur le graphique Boom 500 Index M1
```

### 1.3 Configurer les paramètres

**Paramètres minimaux à vérifier :**

```
=== GESTION DU RISQUE ===
InpFixedLot = 0.20  (ou ton lot habituel)

=== DÉTECTION SPIKE ===
InpTF = PERIOD_M1
InpZScoreMin = 1.8

=== DEBUG ===
InpDebug = true  ← IMPORTANT : Active pour voir les logs GOM TV
```

Clique **OK** pour attacher l'EA.

### 1.4 Vérifier le dashboard

Sur le graphique, tu devrais voir en haut à gauche :

```
┌────────────────────────────────────────────────────┐
│ -- DerivEAPro v10.04 -- Boom 500 Index --         │
│ Regime=TRENDING SL=1.5×ATR TP=2.5×ATR | MTF=...   │
│ Bal $... | Eq $... | Pos:0 | DayLoss:0.0%        │
│ Z=...  RSI=...  ATR=...  Stair=...%               │
│ Imminence [..........] ...%                        │
│                                                     │
│ GHOST: WAIT | delta=... | buyPct=...% | q=...    │
│                                                     │
└────────────────────────────────────────────────────┘
```

**Si tu ne vois PAS le dashboard** → Vérifie que l'EA est bien attaché (icône souriante en haut à droite du graphique).

### 1.5 Vérifier les logs

```
1. Ouvre "Boîte à outils" (Ctrl+T)
2. Onglet "Expert"
3. Cherche les lignes qui commencent par "[v10]" ou "[DerivEAPro v10.04]"
```

**Log attendu au démarrage :**

```
[DerivEAPro v10.04] ✅ Init | Boom 500 Index | SMC=ON | ...
[v10] ⚠️  GOM TV non disponible au démarrage (GOM poller lancé?)
```

**C'est normal !** L'EA cherche `data/gom_signal.json` mais le fichier n'est pas encore alimenté.

---

## ✅ ÉTAPE 2 : Activer le GOM Poller (5 min)

### 2.1 Vérifier TradingView Desktop ouvert

```
1. Ouvre TradingView Desktop (pas le site web)
2. Vérifie qu'un graphique est ouvert (n'importe quel symbole)
3. Charge l'indicateur "GOM KOLA SIDO — Full Integration"
   (cherche dans tes indicateurs favoris ou Community Scripts)
```

**Indicateur visible ?** → Tu devrais voir des niveaux et un tableau en bas du graphique.

### 2.2 Vérifier CDP actif

```bash
# Dans PowerShell ou CMD
curl http://localhost:9222/json/version
```

**Réponse attendue :**
```json
{
  "Browser": "Chrome/...",
  "Protocol-Version": "1.3",
  "User-Agent": "..."
}
```

**Si erreur "connexion refusée"** → Lance TradingView Desktop avec CDP :

```powershell
# Lance ce script PowerShell
D:\Dev\TradBOT\scripts\Start-TradingViewCDP.ps1
```

Ou manuellement :
```powershell
# Ferme TradingView d'abord, puis :
& "C:\Users\USER\AppData\Local\TradingView\TradingView.exe" --remote-debugging-port=9222
```

### 2.3 Tester le polling manuel via Claude

**Dans cette conversation Claude Code**, demande :

```
Poll GOM pour Boom 500 Index :
1. Change symbole DERIV:BOOM_500_INDEX
2. Attends 3s
3. Récupère study values GOM KOLA
4. Parse les données (verdict, quality, delta, cvd, etc.)
5. Écris data/gom_signal.json
```

Je vais exécuter ces étapes automatiquement.

**Résultat attendu :**
- Fichier `D:\Dev\TradBOT\data\gom_signal.json` créé/mis à jour
- Contient les dernières données GOM (verdict, quality, setup, etc.)

### 2.4 Vérifier EA MT5 lit le fichier

Retourne sur MT5 et regarde le dashboard. Après ~10s, tu devrais voir :

```
│ GHOST: WAIT | delta=-79.00 | buyPct=15% | q=24 | CVD=-67804  │
│ GOM TV: FRESH (2s) | imbalance=0.00 | liquidity=0.00 | ...   │
│ Setup AUTO WAIT ⚠️: Entry=5017.00 SL=... TP1=... R:R=1.5    │
```

**Et dans les logs Expert :**
```
[v10] ✅ GOM TV: Boom500Index | verdict=WAIT | delta=-79.00 | imbalance=0.00
[v10] 📊 Setup Fallback généré: WAIT Entry=5017.00 SL=... (quality=24%, ATR-based)
[v10] 🎯 GOM TV: WAIT (q=24%) | imbalance=0.00 | liquidity=0.00
```

**Si tu vois ces logs** → ✅ GOM TV fonctionne !

---

## ✅ ÉTAPE 3 : Activer le Bridge Automatique (5 min)

### 3.1 Tester le bridge manuellement

```bash
cd D:\Dev\TradBOT
python Python\gom_claude_bridge.py
```

**Sortie attendue :**
```
============================================================
GOM Claude Bridge — Test
============================================================
✅ Claude bridge actif

Test 1: Change symbole BTCUSD
[Bridge] 📤 Requête Claude: chart_set_symbol(BITSTAMP:BTCUSD)
```

Puis **dans Claude Code** (cette conversation), je vais détecter la requête et répondre automatiquement.

### 3.2 Activer la surveillance continue

**Dans cette conversation Claude Code**, demande :

```
Active le bridge GOM en mode continu :
1. Surveille data/claude_bridge/mcp_request.json toutes les 1s
2. Quand requête détectée :
   - Execute l'action MCP correspondante
   - Écris la réponse dans mcp_response.json
3. Update heartbeat toutes les 10s
4. Boucle infinie (arrêt avec Ctrl+C)
```

Je vais alors lancer une tâche en arrière-plan qui surveille les requêtes.

### 3.3 Lancer le polling multi-symboles

**Option A : Polling unique (test)**

```bash
cd D:\Dev\TradBOT
python Python\master_gom_poller.py --symbol "Boom 500 Index" --once
```

**Option B : Polling tous les symboles (production)**

```bash
python Python\master_gom_poller.py --once
```

**Option C : Polling en boucle (24/7)**

```bash
python Python\master_gom_poller.py --interval 60
# (pause 60s entre chaque cycle complet)
```

**Sortie attendue :**
```
2026-06-07 12:15:00 [MasterPoller] 🚀 Master GOM Poller démarré
2026-06-07 12:15:00 [MasterPoller]    Symboles (18)
2026-06-07 12:15:00 [MasterPoller] ✅ Claude bridge actif
2026-06-07 12:15:00 [MasterPoller] ─── Tour : 6 symboles ouverts ───

[Bridge] 📤 Requête Claude: chart_set_symbol(BITSTAMP:BTCUSD)
[Bridge] ✅ Symbole changé: BITSTAMP:BTCUSD
[Bridge] 📤 Requête Claude: data_get_study_values()
[Bridge] ✅ Study values reçus: 1 études
2026-06-07 12:15:08 [MasterPoller] ✅ BTCUSD    verdict=BUY buy=5.2 sell=3.8

... (5 autres symboles)

2026-06-07 12:17:00 [MasterPoller] ─── Tour terminé : 6/6 OK ───
```

---

## ✅ ÉTAPE 4 : Automatisation (optionnel, 10 min)

### 4.1 Créer tâche planifiée Windows

```powershell
# Dans PowerShell Administrateur

# Script de polling
$action = New-ScheduledTaskAction -Execute "python" `
  -Argument "D:\Dev\TradBOT\Python\master_gom_poller.py --once" `
  -WorkingDirectory "D:\Dev\TradBOT"

# Trigger : toutes les 5 minutes
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Minutes 5) `
  -RepetitionDuration ([TimeSpan]::MaxValue)

# Créer tâche
Register-ScheduledTask -TaskName "TradBOT_GOM_Poller" `
  -Action $action -Trigger $trigger `
  -Description "Polling GOM multi-symboles toutes les 5min"
```

### 4.2 Vérifier la tâche

```powershell
Get-ScheduledTask -TaskName "TradBOT_GOM_Poller"
```

### 4.3 Démarrer/Arrêter manuellement

```powershell
# Démarrer
Start-ScheduledTask -TaskName "TradBOT_GOM_Poller"

# Arrêter
Stop-ScheduledTask -TaskName "TradBOT_GOM_Poller"

# Supprimer
Unregister-ScheduledTask -TaskName "TradBOT_GOM_Poller" -Confirm:$false
```

---

## 📊 VÉRIFICATION FINALE

### Checklist système opérationnel

- [ ] **MT5** : EA deriveapro.mq5 v10.04 attaché sur Boom 500 Index M1
- [ ] **Dashboard** : Visible en haut à gauche du graphique
- [ ] **Logs Expert** : Affiche `[v10]` et `[DerivEAPro v10.04]`
- [ ] **TradingView** : Desktop ouvert avec indicateur GOM KOLA chargé
- [ ] **CDP** : Port 9222 actif (`curl http://localhost:9222/json/version`)
- [ ] **Fichier GOM** : `data/gom_signal.json` existe et récent (< 5min)
- [ ] **Dashboard GOM TV** : Affiche "GOM TV: FRESH (Xs)" sur EA MT5
- [ ] **Setup AUTO** : Affiche "Setup AUTO WAIT ⚠️" si quality < 50%
- [ ] **Bridge** : `python Python/gom_claude_bridge.py` → ✅ actif
- [ ] **Polling** : `master_gom_poller.py --once` → X/6 OK

**Si tous les ✅ sont cochés** → Système opérationnel !

---

## 🐛 PROBLÈMES FRÉQUENTS

### Problème 1 : "GOM TV non disponible"

**Symptôme :** Dashboard EA affiche uniquement "GHOST" mais pas "GOM TV"

**Cause :** Fichier `data/gom_signal.json` absent ou trop vieux

**Solution :**
```bash
# Dans cette conversation Claude Code, demande :
Poll GOM pour Boom 500 Index
```

### Problème 2 : "Claude bridge pas actif"

**Symptôme :** `python Python/gom_claude_bridge.py` affiche ❌

**Cause :** Heartbeat `data/claude_bridge/bridge_active.json` trop vieux (> 60s)

**Solution :**
```bash
# Dans cette conversation Claude Code, demande :
Update le heartbeat bridge maintenant
```

### Problème 3 : TradingView CDP indisponible

**Symptôme :** `curl http://localhost:9222/json/version` → erreur connexion

**Cause :** TradingView pas lancé en mode CDP

**Solution :**
```powershell
# Ferme TradingView, puis :
& "C:\Users\USER\AppData\Local\TradingView\TradingView.exe" --remote-debugging-port=9222
```

### Problème 4 : Setup toujours AUTO, jamais TV

**Symptôme :** Dashboard affiche toujours "Setup AUTO" orange

**Cause :** Quality GOM toujours < 50% (conditions de marché faibles)

**Solution :** Normal si quality < 50%. Attendre meilleures conditions de marché ou assouplir critères Pine Script (voir `GOM_TABLEAU_DIAGNOSTIC.md`).

---

## 📞 AIDE RAPIDE

### Commandes utiles

```bash
# Test bridge
python Python/gom_claude_bridge.py

# Polling manuel un symbole
python Python/master_gom_poller.py --symbol "Boom 500 Index" --once

# Polling tous symboles
python Python/master_gom_poller.py --once

# Vérifier fichier GOM récent
cat D:/Dev/TradBOT/data/gom_signal.json

# Vérifier heartbeat bridge
cat D:/Dev/TradBOT/data/claude_bridge/bridge_active.json

# Vérifier CDP TradingView
curl http://localhost:9222/json/version
```

### Logs importants

```bash
# Logs EA MT5
# → MT5 : Boîte à outils (Ctrl+T) → Onglet "Expert"

# Logs GOM poller
D:/Dev/TradBOT/logs/master_gom_poller.log

# Logs bridge
D:/Dev/TradBOT/data/claude_bridge/bridge.log
```

---

## 🚀 DÉMARRAGE RAPIDE (TL;DR)

```bash
# 1. Lance MT5 → Attache deriveapro.mq5 sur Boom 500 Index M1
# 2. Lance TradingView Desktop en mode CDP
# 3. Dans Claude Code :

Poll GOM pour Boom 500 Index

# 4. Vérifie dashboard EA affiche "GOM TV: FRESH"
# 5. Lance polling automatique :

python Python/master_gom_poller.py --interval 60

# TERMINÉ ! Système opérationnel 24/7
```

---

**Temps total:** 15-20 minutes  
**Difficulté:** ⭐⭐☆☆☆ (Facile si tu suis étape par étape)  

**Besoin d'aide ?** Demande dans cette conversation Claude Code !
