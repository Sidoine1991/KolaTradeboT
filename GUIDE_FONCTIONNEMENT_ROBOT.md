# 📖 Guide Complet: Fonctionnement du Robot SMC_Universal

**Date**: 2026-05-17  
**Robot**: SMC_Universal.mq5  
**Serveur IA**: ai_server.py  
**Objectif**: Explication du flux trading complet

---

## 🏗️ ARCHITECTURE GLOBALE

```
┌─────────────────────────────────────────────────────────────┐
│                      ROBOT MT5                              │
│              SMC_Universal.mq5 (Terminal)                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  OnInit()     OnTick()      OnDeinit()               │  │
│  │  Initialise   Boucle princ. Nettoyage               │  │
│  └──────────────────────────────────────────────────────┘  │
│                        │                                    │
│         ┌──────────────┴──────────────┐                    │
│         ▼                             ▼                    │
│  ┌─────────────────┐         ┌──────────────────┐         │
│  │ Calculs Locaux  │         │ Connexion Serveur│         │
│  │                 │         │                  │         │
│  │ • EMA M1/M5/H1  │         │ POST /decision   │         │
│  │ • RSI, MACD     │         │ GET /ml/decision │         │
│  │ • ATR, Supertr. │         │ GET /trends      │         │
│  │ • Patterns SMC  │         │ GET /analysis    │         │
│  └─────────────────┘         └──────────────────┘         │
│         │                             │                    │
│         └──────────────┬──────────────┘                    │
│                        ▼                                   │
│         ┌──────────────────────────────┐                  │
│         │  LOGIQUE DÉCISION TRADING    │                  │
│         │                              │                  │
│         │ IF (IA == "BUY" OR "SELL")   │                  │
│         │   AND Patterns alignés       │                  │
│         │   AND Confiance > 60%        │                  │
│         │   THEN: Exécuter trade       │                  │
│         └──────────────────────────────┘                  │
│                        │                                   │
│         ┌──────────────┼──────────────┐                   │
│         ▼              ▼              ▼                   │
│    ┌─────────┐  ┌─────────┐   ┌─────────────┐           │
│    │ Market  │  │ Limit   │   │ Management  │           │
│    │ Order   │  │ Order   │   │ Position    │           │
│    │ BUY/SEL │  │ BUY/SEL │   │ - SL/TP     │           │
│    │         │  │         │   │ - Close     │           │
│    └─────────┘  └─────────┘   │ - Trail     │           │
│                                └─────────────┘           │
│                        │                                   │
│                        ▼                                   │
│         ┌──────────────────────────────┐                  │
│         │    EXÉCUTION + GESTION       │                  │
│         │                              │                  │
│         │ • Placement ordre             │                  │
│         │ • Monitoring SL/TP           │                  │
│         │ • Fermeture automatique       │                  │
│         │ • Logging détaillé           │                  │
│         └──────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ WebRequest
                            │ (TCP/IP)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              SERVEUR IA (ai_server.py)                      │
│                  FastAPI + Python                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ POST /decision          → Décision BUY/SELL/HOLD    │  │
│  │ GET /ml/decision        → Signal simplifié cache     │  │
│  │ GET /ml/trend_alignment → Alignement M1/M5/H1       │  │
│  │ GET /ml/coherent_analysis → Cohérence multi-TF      │  │
│  │ GET /ml/metrics         → Métriques ML              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Traitement:                                                │
│  • Reçoit indicateurs MT5                                  │
│  • Analyse avec modèles ML                                │
│  • Retourne décision + confiance                           │
│  • Fallback si modèle indisponible                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 FLUX DE TRADING COMPLET (Pas à pas)

### ÉTAPE 1: OnInit() - Initialisation

```
Temps: Au démarrage du robot

Actions:
1. Charger variables globales
   g_lastAIAction = ""
   g_lastAIConfidence = 0.0
   g_lastAIUpdate = 0

2. Initialiser indicateurs
   • Créer handles EMA (M1, M5, H1)
   • Créer handles Supertrend
   • Charger patterns SMC

3. Nettoyer graphique
   • Supprimer anciens objets
   • Initialiser symbole stats

4. Premier sync /decision
   UpdateAIDecision() → Recevoir premier signal

Logs:
"?? IA: premier sync /decision (démarrage EA)…"
"✅ Signal IA initial reçu | Action: HOLD"
```

---

### ÉTAPE 2: OnTick() - Boucle Principale (Exécutée à chaque tick!)

```
Temps: À CHAQUE MOUVEMENT DE PRIX

Fréquence: 1000+ fois par seconde (très rapide!)

Flux:
┌─────────────────────────────────────────┐
│ 1. Récupérer données de marché          │
│    - Bid/Ask actuels                    │
│    - Nouvelle bougie? OUI → Recalculer  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. Mettre à jour indicateurs            │
│    - EMA (M1, M5, H1)                   │
│    - RSI, MACD, ATR, Supertrend         │
│    - Détecter patterns SMC (OTE, BOS)   │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 3. Tous les ~8-30 secondes:             │
│    Appeler serveur IA                   │
│    POST http://SERVER/decision          │
│                                         │
│    Données envoyées:                    │
│    - symbol: "Boom 1000 Index"          │
│    - bid: 10345.67, ask: 10346.01       │
│    - ema_fast_m1: 10342.10              │
│    - rsi: 72.5, atr: 12.34              │
│    - ... (19 champs total)              │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 4. Réception réponse serveur            │
│                                         │
│    Response JSON:                       │
│    {                                    │
│      "action": "buy",                   │
│      "confidence": 0.87,                │
│      "stop_loss": 10340.00,             │
│      "take_profit": 10355.00,           │
│      "entry_price": 10346.00            │
│    }                                    │
│                                         │
│    Extraction:                          │
│    g_lastAIAction = "BUY"               │
│    g_lastAIConfidence = 87%             │
│    g_stopLoss = 10340.00                │
│    g_takeProfit = 10355.00              │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 5. Évaluation du signal                 │
│                                         │
│    Questions:                           │
│    • IA dit BUY ou SELL?                │
│    • Confiance >= 60% (MinAIConfidence)?│
│    • Patterns SMC alignés?              │
│    • Pas déjà en position?              │
│    • Pas pause post-perte?              │
│    • Pas dépassé limite trades/jour?    │
│    • Pas en HOLD de l'IA?               │
└─────────────────────────────────────────┘
         │
      ┌──┴──┐
      │ OUI │ NON
      ▼     ▼
   TRADE  SKIP
      │     │
      │     └─→ Attendre prochain signal
      │
      ▼
┌─────────────────────────────────────────┐
│ 6. Exécuter TRADE                       │
│                                         │
│    Décision: BUY                        │
│                                         │
│    Calculs:                             │
│    • Lot size = CalculateLotSize()      │
│    • Entry = 10346.00 (prix actuel)     │
│    • SL = 10340.00 (serveur)            │
│    • TP = 10355.00 (serveur)            │
│                                         │
│    Exécution:                           │
│    trade.Buy(lot, _Symbol, entry, SL, TP)│
│                                         │
│    Résultat:                            │
│    ✅ Ordre exécuté                     │
│    ❌ Ordre rejeté (raison loggée)      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 7. Gestion position ouverte             │
│                                         │
│    Monitoring constant:                 │
│    • Prix atual vs SL → Fermeture auto  │
│    • Prix actual vs TP → Fermeture auto │
│    • Trailing stop actif?               │
│    • Profit cible atteint? → Fermeture  │
│    • Nouvelle signal IA HOLD? → Fermer  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 8. Mettre à jour dashboard              │
│    - Afficher signal IA                 │
│    - Afficher positions ouvertes        │
│    - Afficher P&L                       │
│    - Afficher protections actives       │
└─────────────────────────────────────────┘
         │
         ▼
    (Boucle recommence au prochain tick)
```

**C'est rapide!** OnTick() s'exécute plusieurs milliers de fois par seconde, mais:
- POST /decision seulement toutes les ~30 secondes (cache)
- Autres calculs: quelques millisecondes

---

### ÉTAPE 3: Gestion Position

```
POSITION OUVERTE: BUY @ 10346.00 | SL: 10340.00 | TP: 10355.00

Scénario 1: PRIX MONTE (Profit)
────────────────────────────────
Prix: 10346 → 10350 → 10355 (TP atteint!)
Action: Fermeture automatique
Profit: +9 pips = +45.67$
Log: "🔴 POSITION FERMÉE | Profit: +45.67$ | Raison: TP"

Scénario 2: PRIX BAISSE (Perte)
────────────────────────────────
Prix: 10346 → 10343 → 10340 (SL atteint!)
Action: Fermeture automatique
Loss: -6 pips = -30.34$
Log: "🔴 POSITION FERMÉE | Loss: -30.34$ | Raison: SL"

Scénario 3: IA ENVOIE HOLD
──────────────────────────
IA signal change: BUY → HOLD
Action: Fermer position même si pas SL/TP atteint
Raison: IA confiance baisse ou conditions changent
Log: "? POSITION FERMÉE | Raison: IA HOLD"

Scénario 4: PROTECTION DRAWDOWN ACTIVÉE
────────────────────────────────────────
Perte journalière cumulée > 500$
Action: Fermer TOUTES les positions
Log: "⛔ FERMETURE AUTOMATIQUE - Perte max atteinte"

Scénario 5: SPIKE DÉTECTÉ
─────────────────────────
Prix monte/baisse très rapidement (spike imminent)
Action: Fermer position rapidement
Raison: Éviter grosse perte/slippage
Log: "? POSITION FERMÉE | Raison: SPIKE"
```

---

## 🤖 RÔLE DE L'IA

### Comment l'IA prend les décisions?

```
INPUT (Du robot MT5):
├─ Indicateurs techniques
│  ├─ EMA M1/M5/H1 (9 valeurs)
│  ├─ RSI, MACD
│  ├─ ATR, Supertrend
│  └─ Volatility compression
│
├─ Patterns détectés
│  ├─ Escalier détecté? OUI/NON
│  ├─ Direction escalier: BUY/SELL
│  ├─ Pattern type: classic/forming
│  └─ Confidence: 0-100%
│
└─ État du marché
   ├─ Volume spike détecté?
   ├─ Volatility regime: HIGH/NORMAL
   ├─ Price acceleration: 0.12
   └─ Volatility compression: 0.85

TRAITEMENT (Serveur IA):
├─ Modèles ML chargés
│  ├─ decision_simplified()
│  ├─ ML channel breakout detector
│  ├─ Staircase pattern recognition
│  └─ Multi-timeframe consensus
│
├─ Logique fusion
│  ├─ Scoring combiné
│  ├─ Filtrage par confiance
│  ├─ Validation multi-sources
│  └─ Ajustement selon mode
│
└─ Fallback si modèle down
   ├─ EMA alignment simple
   ├─ Supertrend confirmation
   └─ RSI/MACD filter

OUTPUT (Vers robot MT5):
├─ Action: "BUY" | "SELL" | "HOLD"
├─ Confidence: 0.87 (87%)
├─ Entry price: 10346.00
├─ Stop loss: 10340.00
├─ Take profit: 10355.00
└─ Reason: "Escalier classic + EMA aligned"
```

### Cas d'usage IA

**CAS 1: Signal CLAIR**
```
IA reçoit:
- EMA M1 > M5 > H1 (alignement haussier)
- Escalier classic détecté
- RSI = 72 (suracheté mais confirmation)
- Volume spike = YES
- Confidence calculée: 0.87 (87%)

IA décide: BUY
Raison: "Escalier classique + EMA alignée M1/M5/H1 + volume spike"

Robot reçoit: "BUY" (confiance 87% > 60% minimum)
Résultat: ✅ TRADE EXÉCUTÉ
```

**CAS 2: Signal AMBIGU**
```
IA reçoit:
- EMA M1 > M5 mais M5 < H1 (alignement mixte)
- Pas d'escalier détecté
- RSI = 45 (neutre)
- Volume spike = NO
- Confidence calculée: 0.48 (48%)

IA décide: HOLD
Raison: "Conditions insuffisantes pour trade"

Robot reçoit: "HOLD" (confiance 48% < 60% minimum)
Résultat: ❌ TRADE BLOQUÉ (attendre meilleur signal)
```

**CAS 3: SERVEUR DOWN**
```
Serveur IA n'est pas accessible (crash, redémarrage, etc.)

Robot utilise fallback:
1. Calcule score SMC localement
2. Vérifie EMA alignment local
3. Applique logique simple
4. Continue à trader avec confiance réduite

Logs:
"? Serveur IA indisponible"
"? Utilisation logique interne (fallback)"
"? Trade avec confiance réduite (50%)"

Résultat: ✅ ROBOT AUTONOME (pas de crash)
```

---

## 📊 PATTERNS SMC DÉTECTÉS

Le robot détecte ces patterns **LOCALEMENT** sur le graphique:

### 1. ESCALIER (Staircase)
```
Définition: Suite de montées/descentes ordonnées
Forme visuelle:
  Prix monte régulièrement (escaliers UP) ou descend (escaliers DOWN)

Détection:
  - Comparer swings élevés consécutifs
  - Comparer swings bas consécutifs
  - Si 3+ swings alignés → Escalier détecté
  - Direction: UP ou DOWN

Action robot:
  IF escalier UP (BUY) AND IA dit BUY → Trade BUY (confiance haute)
  IF escalier DOWN (SELL) AND IA dit SELL → Trade SELL
  IF escalier UP BUT IA dit SELL → BLOQUE (conflit)

Score confiance bonus: +20% si escalier détecté
```

### 2. OTE (Optimal Trade Entry)
```
Définition: Entrée optimale identifiée entre support/résistance

Détection:
  - Support/Résistance calculés
  - OTE = Point optimal entre S/R
  - Zone d'entrée étroite identifiée

Action robot:
  Attendre prix atteinde OTE zone
  Si prix en OTE + IA signal + pattern → ENTRY MARKET
  
Entry price: Price actuel à l'entrée OTE
SL: Sous le support
TP: Resistance opposée
```

### 3. BOS (Break of Structure)
```
Définition: Cassure d'une structure précédente (support/résistance)

Détection:
  - Identifie ancienne structure (niveau clé)
  - Détecte prix qui casse ce niveau
  - Confirm avec volume/force

Direction BOS:
  - Casse au-dessus de R = Signal haussier (BUY)
  - Casse au-dessous de S = Signal baissier (SELL)

Action robot:
  IF prix casse niveau + IA align → TRADE dans direction BOS
```

### 4. FVG (Fair Value Gap)
```
Définition: Écart entre prix (gap non comblé)

Détection:
  - Compare close d'une bougie vs open suivante
  - Si gap > ATR * 0.5 → FVG détecté

Action robot:
  - FVG agit comme support/résistance
  - Retournement possible au FVG
  - Stop loss peut être placé juste au-delà du FVG
```

### 5. VOLATILITY COMPRESSION/EXPANSION
```
Compression (Avant spike):
  - ATR bas (< moyenne 20)
  - Bougies petites
  - Prix range étroit

Expansion (Après spike):
  - ATR haut (> moyenne 20 * 1.5)
  - Bougies grandes
  - Prix accélère

Action robot:
  Compression détectée → Préparer trade
  Expansion détectée + IA signal → ENTRY IMMÉDIATE
```

---

## 🛡️ SYSTÈME DE PROTECTION

### Avant-match (Avant le trade)

```
✅ Check 1: IA Signal valide?
   IF g_lastAIAction != "BUY" AND g_lastAIAction != "SELL"
   → NE PAS TRADER

✅ Check 2: Confiance suffisante?
   IF g_lastAIConfidence < 60% (MinAIConfidence)
   → NE PAS TRADER

✅ Check 3: Pas déjà en position?
   IF positions >= MaxPositionsTerminal (5)
   → NE PAS TRADER

✅ Check 4: Pas dépassé limite trades/jour?
   IF trades_today >= MaxDailyTrades (20)
   → NE PAS TRADER

✅ Check 5: Pas perte journalière dépassée?
   IF daily_loss > MaxLossDollars (500$)
   → PAUSE 2h (ne pas trader)

✅ Check 6: Pas pause post-perte sur ce symbole?
   IF symbol_paused == TRUE
   → NE PAS TRADER

✅ Check 7: Fenêtre trading UTC correcte?
   IF time_UTC outside trading_window
   → NE PAS TRADER

✅ Check 8: Symbole "propice"?
   IF symbol_in_propice_list == FALSE
   → NE PAS TRADER (ou mode "toutes les opportunités" activé)
```

### Pendant le trade (Position ouverte)

```
🔄 Monitor constant:
   ├─ Prix < SL? → Fermer immédiatement
   ├─ Prix > TP? → Fermer immédiatement
   ├─ Trailing stop activé? → Ajuster SL vers profit
   ├─ Spike détecté? → Fermer rapidement (éviter grosse perte)
   ├─ IA HOLD reçu? → Fermer position
   ├─ Profit cible jour atteint? → Fermer (pause jour)
   └─ Perte max atteint? → Fermer TOUTES positions (pause 2h)

⏱️ Timing:
   ├─ SL/TP: Immédiat (MT5 gère)
   ├─ IA HOLD: ~30 secondes (vérification OnTick)
   ├─ Spike: ~100ms (détection très rapide)
   └─ Profit/Loss max: ~30 secondes (vérification OnTick)
```

### Après le trade (Position fermée)

```
📊 Logging:
   ├─ Profit/Loss: Calculé et loggé
   ├─ Raison fermeture: Loggée
   ├─ Temps ouvert: Calculé
   ├─ SL/TP atteint?: Noté
   └─ Stats: Mises à jour (wins/losses)

🔄 Reset:
   ├─ Cooldown 15s (pas double entrée)
   ├─ Si perte: Symbole en pause possible
   ├─ Si gain: Compteur daily profit augmenté
   └─ Prêt pour prochain signal
```

---

## 📡 COMMUNICATION AVEC LE SERVEUR

### REQUEST (Robot → Serveur)

```
Timing: Toutes les 8-30 secondes

POST http://SERVER:8000/decision

Headers:
  Content-Type: application/json
  User-Agent: MT5-SMC_Universal

Body (JSON):
{
  "symbol": "Boom 1000 Index",
  "timeframe": "M1",
  "bid": 10345.67,
  "ask": 10346.01,
  "atr": 12.34,
  "rsi": 72.5,
  "ema_fast_m1": 10342.10,
  "ema_slow_m1": 10330.20,
  "ema_fast_m5": 10340.00,
  "ema_slow_m5": 10328.50,
  "ema_fast_h1": 10345.00,
  "ema_slow_h1": 10320.00,
  "dir_rule": 1,
  "volatility_compression": 0.85,
  "price_acceleration": 0.12,
  "volume_spike": false,
  "spike_probability": 0.65,
  "timestamp": "2026-05-17T14:35:42Z"
}

Timeout: 5000ms (requête), 10000ms (fallback Render)
Cache: 30 secondes (réutilise réponse même symbole)
```

### RESPONSE (Serveur → Robot)

```
HTTP Status: 200 OK

Body (JSON):
{
  "action": "buy",
  "confidence": 0.87,
  "reason": "Escalier classique + EMA alignée M1/M5/H1",
  "entry_price": 10346.00,
  "stop_loss": 10340.00,
  "take_profit": 10355.00,
  "execution_type": "market",
  "spike_prediction": true,
  "spike_zone_price": 10350.00,
  "timestamp": "2026-05-17T14:35:42.123Z"
}

Parsing:
  g_lastAIAction = "buy"
  g_lastAIConfidence = 0.87
  g_stopLoss = 10340.00
  g_takeProfit = 10355.00
```

---

## 📊 EXEMPLE COMPLET: Trade BUY

```
SCÉNARIO: Boom 1000 Index | M1 | 14:35 UTC

┌─────────────────────────────────────────────────────────┐
│ TICK 1: 14:35:00                                        │
│ Prix: 10343.50                                          │
├─────────────────────────────────────────────────────────┤
│ Action: Détection patterns locaux                       │
│ • EMA M1: 10342.10 (en hausse)                          │
│ • EMA M5: 10340.00 (en hausse)                          │
│ • EMA H1: 10345.00 (stable)                             │
│ • Swing: UP, UP, UP (escalier détecté!)                │
│ • RSI: 65 (force positive)                              │
│ • Spike: Non                                            │
│                                                         │
│ Log: "?? Escalier UP détecté | RSI: 65"               │
└─────────────────────────────────────────────────────────┘
         │
         ▼ (5 secondes plus tard)
┌─────────────────────────────────────────────────────────┐
│ TICK 2: 14:35:05                                        │
│ Prix: 10344.30                                          │
├─────────────────────────────────────────────────────────┤
│ Action: Cache /decision expiré → Appel serveur          │
│ POST /decision avec données MT5                         │
│                                                         │
│ Attente réponse (300-500ms)...                          │
│                                                         │
│ Response reçue:                                         │
│ {                                                       │
│   "action": "buy",                                      │
│   "confidence": 0.82,                                   │
│   "entry_price": 10346.00,                              │
│   "stop_loss": 10340.00,                                │
│   "take_profit": 10355.00                               │
│ }                                                       │
│                                                         │
│ Extraction:                                             │
│ g_lastAIAction = "BUY"                                  │
│ g_lastAIConfidence = 0.82 (82%)                         │
│ g_stopLoss = 10340.00                                   │
│ g_takeProfit = 10355.00                                 │
│                                                         │
│ Log: "✅ Signal IA reçu | Action: BUY | Conf: 82%"    │
└─────────────────────────────────────────────────────────┘
         │
         ▼ (Immédiatement après)
┌─────────────────────────────────────────────────────────┐
│ TICK 3: 14:35:06                                        │
│ Prix: 10345.50 (remontée!)                              │
├─────────────────────────────────────────────────────────┤
│ Action: Évaluation du signal                            │
│                                                         │
│ ✅ IA dit: BUY                                          │
│ ✅ Confiance: 82% > 60% (minimum)                       │
│ ✅ Escalier UP détecté                                  │
│ ✅ EMA alignement BUY                                   │
│ ✅ Pas de position ouverte                              │
│ ✅ Pas au-dessus limite trades                          │
│ ✅ Pas perte max atteinte                               │
│ ✅ Pas en HOLD                                          │
│                                                         │
│ Résultat: ✅ TOUS LES CRITÈRES OK → EXÉCUTER TRADE     │
│                                                         │
│ Log: "✅ Tous critères validés → Exécution trade"      │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ TICK 4: 14:35:07 (Exécution du trade)                   │
│ Prix: 10346.00 (atteint entry_price!)                   │
├─────────────────────────────────────────────────────────┤
│ Action: Placer ordre BUY                                │
│                                                         │
│ Calculs:                                                │
│ • Lot size = 0.2 (minimum, défaut)                      │
│ • Entry price = 10346.00 (prix actuel)                  │
│ • Stop loss = 10340.00 (du serveur)                     │
│ • Take profit = 10355.00 (du serveur)                   │
│ • Risk/Lot = (10346 - 10340) * 0.2 = 1.2 dollars      │
│                                                         │
│ Placement:                                              │
│ trade.Buy(0.2, "Boom 1000 Index", 10346.00,           │
│           10340.00, 10355.00,                           │
│           "BUY @ 10346 | IA:82%")                      │
│                                                         │
│ Résultat: ✅ ORDER EXECUTED                             │
│ Ticket: 123456789                                       │
│                                                         │
│ Log: "🟢 TRADE EXÉCUTÉ"                                 │
│      "Symbol: Boom 1000 Index"                          │
│      "Type: BUY"                                        │
│      "Price: 10346.00"                                  │
│      "Lot: 0.2"                                         │
│      "SL: 10340.00 | TP: 10355.00"                      │
│      "IA Conf: 82%"                                     │
└─────────────────────────────────────────────────────────┘
         │
         ▼ (Maintenant: monitoring continu)
┌─────────────────────────────────────────────────────────┐
│ TICK 5-N: 14:35:08 → 14:36:15 (1 minute)               │
│                                                         │
│ SCÉNARIO A: Prix monte (Profit!)                        │
├─────────────────────────────────────────────────────────┤
│ 14:35:08 - Prix: 10348.00 (+2.00)                       │
│ 14:35:15 - Prix: 10352.00 (+6.00) → Proche TP!        │
│ 14:35:20 - Prix: 10355.00 (+9.00) → TP ATTEINT!       │
│                                                         │
│ Action: MT5 ferme automatiquement                       │
│ Fermeture au meilleur prix: 10355.00                    │
│ Profit: (10355 - 10346) * 0.2 * 10 = +18 pips × 0.2  │
│ = +36 USD                                               │
│                                                         │
│ Log: "🔴 POSITION FERMÉE"                               │
│      "Type: BUY Close"                                  │
│      "Price: 10355.00"                                  │
│      "Profit: +36 USD"                                  │
│      "Raison: TP atteint"                               │
│                                                         │
│ Feedback envoyé au serveur:                            │
│ POST /trades/feedback                                   │
│ {                                                       │
│   "symbol": "Boom 1000 Index",                          │
│   "entry_price": 10346.00,                              │
│   "exit_price": 10355.00,                               │
│   "profit": 36.00,                                      │
│   "ai_confidence": 0.82,                                │
│   "decision": "BUY",                                    │
│   "is_win": true                                        │
│ }                                                       │
│                                                         │
│ Stats mises à jour: wins++, net_profit += 36           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SCÉNARIO B: Prix baisse (Perte)                         │
├─────────────────────────────────────────────────────────┤
│ 14:35:08 - Prix: 10343.00 (-3.00)                       │
│ 14:35:15 - Prix: 10341.00 (-5.00) → Proche SL!        │
│ 14:35:20 - Prix: 10340.00 (-6.00) → SL ATTEINT!       │
│                                                         │
│ Action: MT5 ferme automatiquement                       │
│ Fermeture au meilleur prix: 10340.00                    │
│ Loss: (10346 - 10340) * 0.2 * 10 = -12 pips × 0.2    │
│ = -24 USD                                               │
│                                                         │
│ Log: "🔴 POSITION FERMÉE"                               │
│      "Type: BUY Close (SL)"                             │
│      "Price: 10340.00"                                  │
│      "Loss: -24 USD"                                    │
│      "Raison: SL atteint"                               │
│                                                         │
│ Symbole paused? Vérifier:                               │
│ IF loss > 50$ AND recent_loss_on_symbol                │
│    → Pause symbole 1h                                   │
│                                                         │
│ Stats mises à jour: losses++, net_profit -= 24         │
│ Symbole "Boom 1000 Index" → PAUSED                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SCÉNARIO C: IA envoie HOLD                              │
├─────────────────────────────────────────────────────────┤
│ 14:35:10 - Prix: 10347.00 (+1.00)                       │
│ 14:35:15 - Nouvel appel serveur (cache expiré)         │
│                                                         │
│ Response:                                               │
│ {                                                       │
│   "action": "hold",                                     │
│   "confidence": 0.50,                                   │
│   "reason": "Conditions insuffisantes"                  │
│ }                                                       │
│                                                         │
│ g_lastAIAction = "HOLD"                                 │
│                                                         │
│ Action: Fermer position immédiatement                   │
│ Fermeture au meilleur prix: 10347.00                    │
│ Profit: (10347 - 10346) * 0.2 * 10 = +2 pips × 0.2    │
│ = +4 USD                                                │
│                                                         │
│ Log: "? POSITION FERMÉE"                                │
│      "Raison: IA HOLD"                                  │
│      "Profit: +4 USD"                                   │
│                                                         │
│ Attendre prochain signal BUY ou SELL                   │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 RÉSUMÉ: COMMENT ÇA MARCHE

**RÉSUMÉ SIMPLE:**

1. **Robot REÇOIT** prix + indicateurs du marché
2. **Robot ANALYSE** patterns locaux (escaliers, supports, etc.)
3. **Robot DEMANDE** à l'IA "Que fais-je?"
4. **IA RÉPOND** "BUY à 10346 | SL: 10340 | TP: 10355 | Confiance: 82%"
5. **Robot VÉRIFIE** tous les critères de sécurité
6. **Robot EXÉCUTE** trade BUY si tous critères OK
7. **Robot MONITORE** position 24/7
8. **Automatique** → Fermeture à SL/TP ou signal IA HOLD
9. **Robot LOGUE** profit/loss
10. **Boucle** recommence (attendre prochain signal)

**SI SERVEUR IA DOWN:**
- Robot continue avec logique interne
- Pas de crash, robot autonome
- Confiance réduite mais toujours trade

**PROTECTIONS:**
- Min confiance 60%
- Max 5 positions ouvertes
- Max 20 trades/jour
- Max 500$ perte/jour
- Pause symbole après perte
- SL automatique < 10$ risque
- TP serveur ou ATR multiple

---

**C'est un système robuste, intelligent et autonome!** 🚀
