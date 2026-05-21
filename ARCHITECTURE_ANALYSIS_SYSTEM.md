# 🏗️ Architecture d'Analyse des Indicateurs - Système Complet

## Vue d'Ensemble

```
MetaTrader 5 (MT5)
    │
    ├─────► EA SMC_Universal (Local)
    │       ├─ Lit les indicateurs du graphique (EMA, ATR, etc.)
    │       ├─ Collecte snapshot des données
    │       └─ Envoie à AI_SERVER via WebRequest
    │
    ├─────► AI_SERVER (Local: 127.0.0.1:8000 OR Render: kolatradebot.onrender.com)
    │       ├─ /decision endpoint (analyse + renvoie signal)
    │       ├─ /ml/metrics endpoint (retourne précision ML)
    │       ├─ /symbols/propice/top endpoint (top symbols)
    │       └─ /ml/continuous/status endpoint (entraînement)
    │
    └─────► AWS RDS (Database - Stockage permanent)
            ├─ Historique des trades (trade_feedback)
            ├─ Statistiques par symbole (symbol_trade_stats)
            ├─ Données d'entraînement ML
            └─ Métriques de performance
```

---

## 1️⃣ CAPTURE SNAPSHOT (EA → AI_SERVER)

### Ce Que L'EA Envoie

**Endpoint:** `GET /ml/decision?symbol=<SYM>&timeframe=M1`

**Snapshot Data:**
```
{
  "symbol": "Crash 150 Index",
  "timeframe": "M1",
  "current_price": 10045.23,
  "bid": 10045.20,
  "ask": 10045.26,
  "atr": 3.45,
  
  "indicators": {
    "ema9": 10044.12,
    "ema31": 10043.98,
    "rsi": 65.2,
    "trend_direction": "UPTREND",
    "swing_high": 10050.00,
    "swing_low": 10040.00,
    "fvg_zone": true,
    "obruction_block": true,
    "break_of_structure": false
  },
  
  "market_structure": {
    "higher_high": true,
    "higher_low": true,
    "structure": "BULLISH"
  },
  
  "ml_features": {
    "price_acceleration": 0.082,
    "volatility_state": "normal",
    "volume_trend": "increasing",
    "momentum": "strong_buy"
  }
}
```

**Code EA:**
```mql5
// Ligne 7484 du SMC_Universal.mq5
string path = "/ml/decision?symbol=" + symEnc + "&timeframe=M1";
int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, 
                     post, result, resultHeaders);
```

---

## 2️⃣ ANALYSE EN TEMPS RÉEL (AI_SERVER)

### Que Fait l'AI_SERVER

**Endpoint:** `/ml/decision`

**Processus d'Analyse:**
```
1. Reçoit snapshot de l'EA
   │
2. Normalise les données
   │
3. Exécute 3 modèles ML en parallèle:
   ├─ Random Forest (70.8% accuracy)
   ├─ Gradient Boosting (70.3% accuracy)
   └─ Neural Network (69.5% accuracy)
   │
4. Combine les prédictions (voting)
   │
5. Calcule confiance (0-100%)
   │
6. Retourne DECISION (BUY/SELL/HOLD)
   │
7. Stock feedback dans AWS RDS
   │
8. Met à jour métriques de performance
```

**Réponse AI_SERVER:**
```json
{
  "symbol": "Crash 150 Index",
  "timeframe": "M1",
  "decision": "BUY",
  "confidence": 72.5,
  "models": {
    "random_forest": {"prediction": "BUY", "confidence": 73.2},
    "gradient_boosting": {"prediction": "BUY", "confidence": 71.8},
    "mlp": {"prediction": "SELL", "confidence": 65.1}
  },
  "reasoning": {
    "trend_alignment": "bullish",
    "support_level": "holds",
    "resistance_distance": "safe"
  },
  "timestamp": "2026-05-17T20:55:00Z"
}
```

---

## 3️⃣ ENDPOINTS API DETAILLES

### A. `/ml/decision` - Main Decision Engine

```
REQUEST:
  GET http://127.0.0.1:8000/ml/decision?symbol=Crash%20150%20Index&timeframe=M1

RESPONSE (HTTP 200):
{
  "decision": "BUY",
  "confidence": 72.5,
  "...metadata..."
}

CACHE: 30 secondes (configurable: AI_DecisionCacheSeconds)
TIMEOUT: 5 secondes (AI_Timeout_ms)
FALLBACK: kolatradebot.onrender.com
```

**Utilisation dans EA:**
```mql5
// Ligne 7489 SMC_Universal.mq5
int res = WebRequest("GET", baseUrl + path, headers, 
                     AI_Timeout_ms, post, result, resultHeaders);
if(res == 200) {
  g_lastAIAction = ExtractJsonDecisionRootAction(response);
  g_lastAIConfidence = ExtractJsonDecisionRootConfidence(response);
}
```

---

### B. `/ml/metrics` - Model Performance Metrics

```
REQUEST:
  GET http://127.0.0.1:8000/ml/metrics?symbol=Crash%20150%20Index&timeframe=M1

RESPONSE (HTTP 200):
{
  "symbol": "Crash 150 Index",
  "accuracy": 70.8,
  "best_model": "random_forest",
  "total_samples": 5432,
  "training_status": "collecting_data",
  "feedback_wins": 127,
  "feedback_losses": 52,
  "day_wins": 3,
  "day_losses": 1,
  "day_net_profit": 45.50,
  "month_wins": 87,
  "month_losses": 31,
  "month_net_profit": 1245.75
}
```

**Utilisation dans EA:**
```mql5
// Ligne 7018 SMC_Universal.mq5
int res = WebRequest("GET", baseUrl + pathMetrics, headers, 
                     AI_Timeout_ms, post, result, resultHeaders);
// Résultat affiché dans dashboard (📊 ML: 70.8% | random_forest)
```

---

### C. `/symbols/propice/top` - Top Symbols Filter

```
REQUEST:
  GET http://127.0.0.1:8000/symbols/propice/top?timeframe=M1&lookback_days=14&n=5

RESPONSE (HTTP 200):
{
  "timeframe": "M1",
  "hour_utc": 20,
  "symbols": [
    {"symbol": "Crash 150 Index", "propice_score": 89.5},
    {"symbol": "Boom 600 Index", "propice_score": 87.2},
    {"symbol": "EURUSD", "propice_score": 82.1},
    {"symbol": "GBPUSD", "propice_score": 78.9},
    {"symbol": "XAUUSD", "propice_score": 76.3}
  ]
}
```

**Utilisation dans EA:**
```mql5
// Ligne 1381 SMC_Universal.mq5
string url = baseUrl + "/symbols/propice/top?timeframe=M1&lookback_days=14&n=5";
// Filtre optionnel: BlockTradingNonTopPropiceWhenLosing = true
// = Ne trader que sur les meilleurs symboles si on perd
```

---

### D. `/ml/continuous/status` - Training Status

```
REQUEST:
  GET http://127.0.0.1:8000/ml/continuous/status

RESPONSE (HTTP 200):
{
  "training_active": true,
  "models_training": ["random_forest", "gradient_boosting"],
  "last_update": "2026-05-17T20:55:12Z",
  "samples_collected": 15420,
  "next_retraining": "2026-05-17T21:00:00Z",
  "valid": true
}
```

---

## 4️⃣ STOCKAGE AWS RDS

### Tables Principales

**1. `symbol_trade_stats` (Statistics)**
```sql
symbol | timeframe | date | wins | losses | net_profit | accuracy
─────────────────────────────────────────────────────────────────
Crash 150 Index | M1 | 2026-05-17 | 15 | 3 | 245.50 | 83.3%
Boom 600 Index | M1 | 2026-05-17 | 12 | 5 | 189.25 | 70.6%
EURUSD | M1 | 2026-05-17 | 8 | 2 | 145.75 | 80.0%
```

**2. `trade_feedback` (Decision Learning)**
```sql
symbol | entry_time | entry_price | exit_time | exit_price | profit | ai_decision | ai_confidence | ml_accuracy
──────────────────────────────────────────────────────────────────────────────────────────────────────────────
Crash 150 | 2026-05-17 20:50:00 | 10041.56 | 2026-05-17 20:51:45 | 10039.83 | -1.73 | BUY | 72.5 | 70.8%
Boom 600 | 2026-05-17 20:45:30 | 2847.22 | 2026-05-17 20:47:12 | 2851.45 | 4.23 | BUY | 68.2 | 70.8%
```

**3. `ml_training_data` (Model Training)**
```
Symbol, TimeFrame, Indicators (EMA, ATR, RSI...), 
Label (BUY/SELL/HOLD), Profit/Loss, Confidence
```

---

## 5️⃣ FLUX D'UN TRADE COMPLET

### Timeline d'un Trade de Crash 150 Index:

```
T=0s: EA démarre
  │
T=2s: EA scrape graphique M1
  ├─ Prix: 10041.56
  ├─ EMA9: 10044.12
  ├─ ATR: 3.45
  └─ Trend: UPTREND
  │
T=2.5s: EA envoie snapshot à AI_SERVER
  │GET /ml/decision?symbol=Crash%20150%20Index&timeframe=M1
  │
T=3s: AI_SERVER analyse
  ├─ Exécute 3 modèles ML
  ├─ Random Forest vote: BUY (73.2%)
  ├─ Gradient Boosting: BUY (71.8%)
  ├─ Neural Net: SELL (65.1%)
  └─ Résultat: BUY 72.5%
  │
T=3.5s: AI_SERVER sauvegarde dans AWS RDS
  ├─ Enregistre snapshot
  ├─ Enregistre modèles ML utilisés
  └─ Enregistre confiance
  │
T=4s: EA reçoit réponse
  ├─ Extrait: decision=BUY, confidence=72.5%
  ├─ Vérifie alignement tendance (✓ UPTREND)
  ├─ Calcule entrée: 10042.15
  ├─ Calcule SL: 10030.31
  └─ Calcule TP: 10060.26
  │
T=5s: EA place trade
  ├─ Market Order: BUY 0.5 @ 10041.56
  └─ SL=10030.31, TP=10060.26
  │
T=90s: Trade fermé
  ├─ Exit @ 10039.83
  ├─ Profit: -1.73$
  └─ Enregistre LOSS
  │
T=91s: Trade feedback enregistré AWS RDS
  ├─ Symbol: Crash 150 Index
  ├─ Entry: 10041.56 (AI BUY 72.5%)
  ├─ Exit: 10039.83 (LOSS)
  ├─ AI était correct? NON
  └─ ML learn from feedback
  │
T=100s: ML retraining déclenché
  ├─ Ajoute ce trade à dataset
  ├─ Réentraîne 3 modèles
  ├─ Améliore accuracy
  └─ Prochains trades: mieux?
```

---

## 6️⃣ DATA FLOW DIAGRAM

```
┌──────────────────────────────────────────────────────────────────┐
│                      MetaTrader 5 Terminal                        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │         EA: SMC_Universal.mq5 (27,240 lines)           │    │
│  │                                                          │    │
│  │ OnTick() every 1M1 candle:                             │    │
│  │  1. Read graph indicators (EMA, ATR, Swings)          │    │
│  │  2. Build snapshot data                                │    │
│  │  3. WebRequest to AI_SERVER /ml/decision              │    │
│  │  4. Receive BUY/SELL/HOLD + confidence                │    │
│  │  5. Place trade if conditions met                      │    │
│  │  6. Close position based on SL/TP                      │    │
│  │  7. Store feedback for ML learning                     │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ WebRequest (HTTP)
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│              AI_SERVER (127.0.0.1:8000 or Render)               │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              FastAPI REST Endpoints                     │    │
│  │                                                          │    │
│  │  /ml/decision          → BUY/SELL/HOLD signals        │    │
│  │  /ml/metrics           → Model accuracy (70.8%)        │    │
│  │  /symbols/propice/top  → Best symbols to trade        │    │
│  │  /ml/continuous/status → Training progress            │    │
│  │  /robot/trade_feedback → Accept trade results         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │         ML Models (Trained, Active, Live)              │    │
│  │                                                          │    │
│  │  • Random Forest (accuracy: 70.8%) ← BEST             │    │
│  │  • Gradient Boosting (accuracy: 70.3%)                │    │
│  │  • Neural Network MLP (accuracy: 69.5%)               │    │
│  │                                                          │    │
│  │  → Voting ensemble for final decision                 │    │
│  │  → Confidence = agreement %                           │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ JSON Response
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                AWS RDS (PostgreSQL Database)                      │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │            Persistent Data Storage                      │    │
│  │                                                          │    │
│  │  • symbol_trade_stats → Performance metrics            │    │
│  │  • trade_feedback     → Historic decisions + results   │    │
│  │  • ml_training_data   → Data for model retraining     │    │
│  │  • ml_metrics         → Accuracy tracking              │    │
│  │                                                          │    │
│  │  → Used for:                                           │    │
│  │    ✓ Feedback loop learning                            │    │
│  │    ✓ Model retraining (continuous)                     │    │
│  │    ✓ Performance analysis                              │    │
│  │    ✓ Risk management decisions                         │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 7️⃣ CYCLE D'APPRENTISSAGE ML

```
Day 1:
  ├─ Collect 150 trades (feedback)
  ├─ Store in AWS RDS
  └─ ML learns from wins/losses

Day 2:
  ├─ Retrain 3 models
  ├─ Random Forest accuracy: 70.1% → 70.8% (+0.7%)
  ├─ Gradient Boosting: 70.0% → 70.3% (+0.3%)
  └─ Neural Net: 69.0% → 69.5% (+0.5%)

Day 3:
  ├─ Next 150 trades with improved models
  ├─ Win rate increases (feedback loop)
  └─ Process repeats (continuous learning)
```

---

## 8️⃣ CONFIGURATION DANS EA

```mql5
// AI_SERVER URLs (Ligne 2356-2357 SMC_Universal.mq5)
input string AI_ServerURL       = "http://127.0.0.1:8000";
input string AI_ServerRender    = "https://kolatradebot.onrender.com";

// Bascule entre local et cloud
input bool   UseRenderAsPrimary = false;  // false = local first, Render fallback

// Cache (Ligne 2360)
input int    AI_DecisionCacheSeconds = 30;

// Timeouts (Ligne 2358-2359)
input int    AI_Timeout_ms     = 5000;   // Local
input int    AI_Timeout_ms2    = 10000;  // Render (cold start)
```

---

## 9️⃣ ERREURS COURANTES & FIXES

### Problème: "Invalid price" lors du placement d'ordres

**Cause:** Snapshot mal envoyé ou analysé

**Solution:**
```mql5
// Vérifier que snapshot est correct
if(buyLevel <= 0 || sellLevel <= 0) {
  // Fallback à logique locale (pas de AI_SERVER response)
  buyLevel = GetClosestBuyLevel(...);
}
```

### Problème: "Connexion impossible" à AI_SERVER

**Cause:** 
- Local server arrêté (127.0.0.1:8000 non accessible)
- Render indisponible (timeout)

**Fallback Automatique:**
```mql5
// Ligne 7489-7495: Si local échoue → try Render
if(res != 200) {
  res = WebRequest("GET", fallbackUrl + path, ...);  // Try Render
}
// Si Render aussi échoue → use GenerateFallbackAIDecision()
```

---

## 🔟 RÉSUMÉ SIMPLIFIÉ

```
USER PERSPECTIVE:

1. EA runs on MT5 chart
   │
2. Captures indicator snapshot every minute
   │
3. Sends to AI_SERVER (local or cloud)
   │
4. AI_SERVER analyzes with 3 ML models
   │
5. Returns BUY/SELL/HOLD + confidence
   │
6. EA decides to place trade or wait
   │
7. Trade executed, closes based on SL/TP
   │
8. Result stored in AWS RDS for ML learning
   │
9. Next trade benefits from improved models
   │
10. Loop repeats with better accuracy over time
```

---

**Status:** ✅ Complete Architecture Documentation  
**Date:** 2026-05-17  
**Version:** 1.02 (Enhanced Dashboard)
