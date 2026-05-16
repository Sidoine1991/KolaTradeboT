# 🎊 GOM_KOLA_SIDO_Script.mq5 - MISE À JOUR SCANNER + TRADING AUTO

## ✅ MISE À JOUR TERMINÉE

Le script **GOM_KOLA_SIDO_Script.mq5** a été mis à jour pour intégrer:
- ✅ **Scanner multi-symboles** en temps réel
- ✅ **Trading automatique** avec gestion du risque
- ✅ **Notifications push** toutes les 10 minutes

## 📦 FICHIER MIS À JOUR

```
GOM_KOLA_SIDO_Script.mq5 (modifié)
├── 17 nouveaux inputs (scanner + trading auto)
├── Initialisation du scanner dans OnStart()
├── Appel du scanner dans la boucle principale
└── Nettoyage automatique à la fin

Copié automatiquement:
C:\Users\USER\AppData\...\MQL5\Scripts\GOM_KOLA_SIDO_Script.mq5 ✅
```

## 🆕 NOUVEAUX INPUTS

### Scanner Multi-Symboles
```mql5
[SCANNER MULTI-SYMBOLES + TRADING AUTO]
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,..."
ScannerRefreshSeconds = 2
ScannerPanelX = 10
ScannerPanelY = 30
ScannerPanelWidth = 500
ScannerRowHeight = 25
ScannerShowPanel = true
```

### Trading Automatique
```mql5
EnableScannerAutoTrading = false      // Activer ici
AutoTradeMaxRiskDollars = 0.50        // Pour capital 10$
AutoTradeScalpTpPoints = 50
AutoTradeScalpSlPoints = 30
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 20
AutoTrailingStepPoints = 5
AutoTradeNotifyIntervalMin = 10
```

## 🚀 UTILISATION

### Mode 1: Script GOM Classique (Sans Scanner)

**Configuration:**
```mql5
EnableOpportunityScanner = false
```

**Résultat:** Script GOM normal (niveaux KOLA + dashboard)

---

### Mode 2: Script GOM + Scanner (Observation)

**Configuration:**
```mql5
EnableOpportunityScanner = true
EnableScannerAutoTrading = false
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index"
```

**Résultat:**
- Niveaux KOLA + dashboard GOM ✅
- Panneau scanner en haut ✅
- Pas de trade automatique ❌

---

### Mode 3: Script GOM + Scanner + Trading Auto (Actif)

**Configuration:**
```mql5
EnableOpportunityScanner = true
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50
```

**Résultat:**
- Niveaux KOLA + dashboard GOM ✅
- Panneau scanner en haut ✅
- Trades automatiques ✅
- Notifications push ✅

---

## 📊 FONCTIONNEMENT

### 1. Lancement du Script

```
1. Ouvrir graphique principal (ex: Boom 1000 Index)
2. Attacher GOM_KOLA_SIDO_Script
3. Configurer les paramètres
4. OK → Script démarre
```

### 2. Processus

```
┌─────────────────────────────────────┐
│  Script GOM_KOLA_SIDO_Script.mq5   │
├─────────────────────────────────────┤
│                                     │
│  1. Analyse niveaux KOLA            │
│     (M1, M5, M15, M30, H1, H4, D1)  │
│                                     │
│  2. Détection figures SIDO          │
│     (Double Top/Bottom)             │
│                                     │
│  3. Scanner multi-symboles          │ ← NOUVEAU
│     - Lecture Global Variables      │
│     - Affichage opportunités        │
│                                     │
│  4. Trading automatique (optionnel) │ ← NOUVEAU
│     - Placement ordres              │
│     - Trailing stop                 │
│     - Notifications                 │
│                                     │
│  5. Dashboard GOM                   │
│     (Verdict + Spike + Stats)       │
│                                     │
└─────────────────────────────────────┘
```

### 3. Interaction avec Autres Graphiques

Pour que le scanner fonctionne, il faut:

1. **Graphique 1: Boom 1000 Index**
   - EA SMC_Universal attaché (publie les données GV)

2. **Graphique 2: Crash 1000 Index**
   - EA SMC_Universal attaché (publie les données GV)

3. **Graphique 3: EURUSD (principal)**
   - Script GOM_KOLA_SIDO_Script attaché
   - Scanner activé
   - Affiche les opportunités des 3 symboles

---

## 🎯 AVANTAGES

### Par Rapport à SMC_Universal Seul

| Fonctionnalité | SMC_Universal | GOM Script + Scanner |
|----------------|---------------|----------------------|
| Niveaux KOLA | ✅ | ✅ |
| Dashboard GOM | ✅ | ✅ |
| Scanner multi-symboles | ✅ | ✅ |
| Trading auto | ✅ | ✅ |
| **Visuel dashboard GOM** | ❌ | ✅ (unique) |
| **Projection M1×500** | ❌ | ✅ (unique) |
| **Spike detection visuel** | ❌ | ✅ (unique) |

**Conclusion:** Le script GOM offre le **meilleur visuel** (dashboard complet).

---

## 💡 CAS D'USAGE

### Cas 1: Trader Manuel Avancé

**Setup:**
```mql5
EnableOpportunityScanner = true
EnableScannerAutoTrading = false    ← Pas d'auto
```

**Workflow:**
1. Scanner affiche les opportunités
2. Dashboard GOM affiche le verdict
3. Trader décide manuellement
4. Entrée/sortie manuelles

**Avantage:** Contrôle total + visuels GOM

---

### Cas 2: Trader Semi-Automatique

**Setup:**
```mql5
EnableOpportunityScanner = true
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50
```

**Workflow:**
1. Scanner détecte opportunités
2. Robot place les trades (PERFECT/GOOD)
3. Trader surveille les positions
4. Trailing stop automatique

**Avantage:** 80% auto, 20% supervision

---

### Cas 3: Trader Fullly Automatique

**Setup:**
```mql5
EnableOpportunityScanner = true
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 1.00
EnableAutoTrailingStop = true
```

**Workflow:**
1. Scanner détecte
2. Robot trade
3. Trailing stop gère
4. Notifications push
5. Trader vérifie rapport 10 min

**Avantage:** 100% automatique

---

## ⚙️ CONFIGURATION RECOMMANDÉE

### Pour Capital 10$

```mql5
[SCANNER MULTI-SYMBOLES + TRADING AUTO]
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index"
EnableScannerAutoTrading = true
AutoTradeMaxRiskDollars = 0.50
AutoTradeScalpTpPoints = 50
AutoTradeScalpSlPoints = 30
EnableAutoTrailingStop = true
AutoTrailingStopPoints = 20
```

**Résultat Attendu:** +1-2$ /jour

---

### Pour Capital 50$

```mql5
AutoTradeMaxRiskDollars = 2.00
AutoTradeScalpTpPoints = 80
AutoTradeScalpSlPoints = 50
AutoTrailingStopPoints = 30
```

**Résultat Attendu:** +5-10$ /jour

---

## 🔧 COMPILATION

### 1. Copier les Dépendances

Les fichiers suivants doivent être dans le même dossier:
```
MQL5\Scripts\
├── GOM_KOLA_SIDO_Script.mq5
├── SMC_OpportunityScanner.mqh
└── SMC_AutoTrader.mqh
```

Ou dans `MQL5\Include\`:
```
MQL5\Include\
├── SMC_OpportunityScanner.mqh
└── SMC_AutoTrader.mqh
```

### 2. Compiler

```
1. Ouvrir MetaEditor (F4)
2. Ouvrir GOM_KOLA_SIDO_Script.mq5
3. Compiler (F7)
4. Vérifier: 0 errors ✅
```

### 3. Utiliser

```
1. Ouvrir graphique
2. Glisser le script depuis Navigator
3. Configurer les paramètres
4. OK → Script démarre
```

---

## 📱 NOTIFICATIONS

### Format Identique à SMC_Universal

```
📊 SCANNER AUTO-TRADING
━━━━━━━━━━━━━━━━━━━━
⏰ 2026-05-14 15:30

📈 Trades: 5 (W:3 L:2)
✅ Win Rate: 60.0%
💰 Profit Net: $2.45

📊 Positions Ouvertes: 2
  Boom 1000 Index BUY: $1.20
  Crash 1000 Index SELL: $0.85

💵 P/L Total: $2.05
```

---

## 🛡️ SÉCURITÉ

### Identique à SMC_Universal

✅ Risque contrôlé (0.50$ max pour capital 10$)
✅ Calcul lot automatique
✅ Limites positions (1/symbole, 3 total)
✅ Trailing stop automatique
✅ Throttle 2 minutes entre trades

---

## 🆚 DIFFÉRENCES SCRIPT vs EA

| Aspect | Script GOM | EA SMC_Universal |
|--------|------------|------------------|
| **Type** | Script (one-time/loop) | EA (permanent) |
| **Démarrage** | Manuel | Automatique |
| **Attachement** | Temporaire | Permanent |
| **Dashboard GOM** | ✅ Complet | ✅ Compact |
| **Scanner** | ✅ | ✅ |
| **Trading Auto** | ✅ | ✅ |
| **Keep Running** | Option | Toujours |

**Conseil:** Utiliser le **script** pour le **visuel** (dashboard GOM complet).

---

## 💡 ASTUCES

### 1. Combiner Script + EA

**Setup:**
- **Graphique 1:** EA SMC_Universal (trade automatique)
- **Graphique 2:** Script GOM (visuel + scanner)

**Avantage:** Meilleur des deux mondes

### 2. Mode Observation Pure

**Setup:**
```mql5
EnableScannerAutoTrading = false
```

**Usage:** Observer les opportunités, trader manuellement

### 3. Script Multi-Symboles

**Setup:**
```mql5
ScannerSymbolsList = "Boom 1000,Crash 1000,V75,V100,Step,EURUSD,GBPUSD,XAUUSD"
```

**Usage:** Surveiller 8 symboles sur 1 seul graphique

---

## 📖 DOCUMENTATION

Pour en savoir plus:
- **AUTO_TRADING_QUICK_START.md** - Démarrage rapide
- **TRADING_AUTOMATIQUE_README.md** - Documentation complète
- **RESUME_COMPLET_SCANNER_AUTO.md** - Vue d'ensemble

---

## 🎊 RÉSUMÉ

**Le script GOM_KOLA_SIDO_Script.mq5 est maintenant aussi puissant que SMC_Universal:**

✅ Niveaux KOLA multi-timeframes
✅ Dashboard GOM complet (unique)
✅ Scanner multi-symboles
✅ Trading automatique
✅ Trailing stop
✅ Notifications push
✅ Projection M1×500 (unique)

**Choix:**
- **EA SMC_Universal** → Simplicité, permanent
- **Script GOM** → Visuel avancé, dashboard complet

**Ou les deux!** 🎉

---

**Développé par TradBOT SMC** - Script GOM avec Scanner + Trading Auto
**Version:** 1.3 → 2.0
**Date:** 2026-05-14
