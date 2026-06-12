# TradBOT — Architecture

Robot de trading algorithmique multi-actifs connectant TradingView, un serveur IA Python et MetaTrader 5.

**Marchés** : XAUUSD · Boom/Crash · Forex · Volatility Indices  
**Stratégie** : Smart Money Concepts (SMC) + GOM (Global Order Model) multi-timeframes

---

## Vue d'ensemble

```
MT5 Terminal (candles live)
    │  MetaTrader5 Python API
    ▼
ai_server.py  (FastAPI :8000)   ◄──── gom_mt5_poller.py (30s loop)
    │  POST /pending-order
    ▼
SMC_Universal.mq5  (MT5 EA)
    │  Ouverture ordres
    ▼
TradeManager.mq5   (MT5 EA)     — SL/TP trailing · Duplication · Re-entrée
    │  Upload candles / deals
    ▼
ai_server.py  (feedback loop)
```

---

## Couches de l'architecture

### Couche 1 — Sources de données

| Source | Protocol | Données fournies |
|--------|----------|-----------------|
| TradingView Desktop | MCP / CDP | Indicateurs, OHLCV, état du chart par TF |
| Deriv WebSocket | WS | Candles live Boom/Crash et synthétiques |
| MT5 Terminal | MQL5 API | Candles live, deals fermés, equity |

### Couche 2 — Calcul GOM (100 % local)

**Fichier principal** : `python/gom_live_calculator.py`

Pour chaque symbole et chaque TF (M1, M5, M15, H1, H4, D1, W1) :

1. Calcul des indicateurs : RSI(14), Bollinger Bands, MACD, SuperTrend, VWAP, Keltner Channel
2. Détection SMC : Order Blocks, FVG, Break of Structure, CHoCH
3. Direction par TF : `BULL` / `BEAR` / `NEUT`

**Fichier scoring** : `python/gom_pine_calculator.py`

```
score_buy  = ST(×1.5) + VWAP(×1.0) + RSI(×1.0) + MACD(×0.8) + OB(×1.5) + BOS(×1.38) + ...
score_sell = (logique symétrique)
verdict_gap = |score_buy − score_sell|
filter_ratio = confirmateurs alignés / 6
```

**Seuils de verdict** :

| verdict_num | Label | Conditions |
|-------------|-------|------------|
| +3 | PERFECT BUY | gap ≥ 5.0 ET filter ≥ 0.67 |
| +2 | GOOD BUY | gap ≥ 2.5 ET filter ≥ 0.55 |
| +1 | BUY | gap ≥ 1.2 ET filter ≥ 0.55 |
| 0 | WAIT | conditions non remplies |
| −1 | SELL | gap ≥ 1.2 ET filter ≥ 0.55 |
| −2 | GOOD SELL | gap ≥ 2.5 ET filter ≥ 0.55 |
| −3 | PERFECT SELL | gap ≥ 5.0 ET filter ≥ 0.67 |

**Gate MTF** (`apply_mtf_verdict_gate`) : H4 = ×3, H1 = ×2, D1 = ×2, autres = ×1  
→ H4 BEAR + H1 BEAR = WAIT forcé sur tout signal BUY

**Garde Boom/Crash** : SELL interdit sur Boom, BUY interdit sur Crash.

### Couche 3 — Serveur IA (`ai_server.py`)

FastAPI — ~25 000 lignes — port 8000.

**Endpoints clés** :

| Endpoint | Méthode | Rôle |
|----------|---------|------|
| `/gom-kola-dashboard` | GET | Dashboard GOM live (source=local\|tv) |
| `/gom-verdicts` | GET | Liste de tous les verdicts actifs |
| `/gom-verdict` | POST | Injecter/mettre à jour un verdict |
| `/pending-order` | GET/POST | File d'attente des ordres pour MT5 |
| `/decision` | POST | Décision unifiée (SMC + GOM + ML) |
| `/webhook/tradingview` | POST | Réception alertes Pine Script |
| `/mt5/upload-candles` | POST | Réception candles depuis l'EA |
| `/mt5/deals-upload` | POST | Réception deals fermés |
| `/health` | GET | Santé du serveur |

**Store interne** : `_GOM_VERDICT_STORE` — dict en mémoire `{symbol: verdict_record}`, TTL configurable via `GOM_TV_VERDICT_TTL_SEC`.

**Résolution dashboard** (`_resolve_gom_dashboard`) :
1. Calcul live depuis `_gom_live_calc` (candles MT5 fraîches)
2. Fallback sur `_GOM_VERDICT_STORE` si le live retourne WAIT
3. Fallback sur fichier `data/gom_signal.json`

### Couche 4 — EAs MetaTrader 5

#### `SMC_Universal.mq5` (EA principal)

- Interroge `/gom-kola-dashboard` à chaque timer tick
- Affiche le dashboard GOM sur le chart (`ShowGOMDashboard=ON`)
- Filtre les entrées via le verdict GOM (`UseGOMVerdictFilter=ON`)
- Lance le pipeline autonome (`UseGOMPipeline=ON`)
- Exécute les ordres pending depuis `/pending-order`

**Modules inclus** :

| Module | Rôle |
|--------|------|
| `SMC_GOM_Pipeline.mqh` | Interprétation verdicts GOM, dessin dashboard |
| `MCPSignalManager.mqh` | Polling et validation ordres depuis ai_server |
| `ValidationPipeline.mqh` | Vérification confluence, SL/TP, spread |
| `RiskManager.mqh` | Sizing des lots (2 % risk/trade) |
| `MT5_Candles_Uploader.mqh` | Upload OHLCV vers `/mt5/upload-candles` |
| `HTTPTransport.mqh` | Client HTTP REST vers ai_server |
| `GOM_Graphics.mqh` | Rendu visuel du tableau de bord |

#### `TradeManager.mq5` (gestionnaire de positions)

- Trailing stop dynamique
- Breakeven automatique (50 % du chemin TP)
- Protection petite perte (ne ferme pas si profit > −$2)
- Duplication de position si profit > seuil
- Re-entrée sur touche EMA
- Limite globale : 7 positions/jour

### Couche 5 — Pipelines Python

#### Poller MT5 (`python/gom_mt5_poller.py`) ← SOURCE PRINCIPALE

```
MT5 Terminal (candles live) → gom_live_calculator → POST /gom-verdict × 7 symboles
```

Calcul 100% local depuis les bougies MT5 — **aucune connexion TradingView requise**.  
Intervalle : 30 s. Lance via `scripts\start_gom_loop.bat`.

#### Sync GOM 10 min (`python/gom_sync_with_report.py`)

```
/gom-verdicts (live depuis MT5) → POST /gom-verdict × N signaux → Rapport WhatsApp
```

#### Pipeline horaire autonome (`python/pipeline_hourly_autonomous.py`)

```
Phase 1 : Scan /gom-verdicts → Top-5 par verdict_gap
Phase 2 : TradingAgents (subprocess) → fallback GOM cache
Phase 3 : POST /pending-order → MT5 exécute
Rapport : WhatsApp + log
```

---

## Structure des fichiers

```
TradBOT/
├── ai_server.py                  # Serveur FastAPI principal (~25 000 lignes)
├── symbol_mapper.py              # Normalisation symboles (TV ↔ MT5)
├── SMC_Universal.mq5             # EA principal MT5
├── TradeManager.mq5              # Gestionnaire positions MT5
│
├── python/
│   ├── gom_live_calculator.py    # Calcul GOM temps réel (candles MT5)
│   ├── gom_pine_calculator.py    # Scoring Pine Script (moteur principal)
│   ├── gom_scoring_engine.py     # Moteur scoring simplifié (secondaire)
│   ├── gom_verdict_poller.py     # Poller TradingView → /gom-verdict
│   ├── gom_sync_with_report.py   # Sync 10min + rapport WhatsApp
│   ├── pipeline_hourly_autonomous.py  # Pipeline Top-5 horaire
│   ├── pipeline_with_approval.py      # Pipeline avec validation WhatsApp
│   ├── mt5_candles_fetcher.py    # Fetch candles depuis MT5
│   ├── deriv_candles_ws.py       # Candles Deriv via WebSocket
│   ├── tradbot_bridge.py         # Bridge CLI → TradingAgents → MT5
│   └── morning_scan.py           # Scan matinal des symboles
│
├── mt5/
│   ├── SMC_Universal.mq5         # (symlink ou copie de la racine)
│   ├── GOM_KOLA_script.pine      # Indicateur Pine Script (TradingView)
│   └── modules/
│       ├── SMC_GOM_Pipeline.mqh  # Pipeline GOM MQL5
│       ├── MCPSignalManager.mqh  # Gestion ordres pending
│       ├── ValidationPipeline.mqh
│       ├── RiskManager.mqh
│       ├── MT5_Candles_Uploader.mqh
│       ├── HTTPTransport.mqh
│       └── GOM_Graphics.mqh
│
├── data/
│   ├── gom_signal.json           # Verdicts GOM (fallback fichier)
│   ├── mt5_files/                # Candles uploadées par l'EA
│   └── state/                    # État persisté par symbole
│
├── logs/
│   ├── gom_sync.log              # Logs sync 10 min
│   └── pipeline_hourly.log       # Logs pipeline horaire
│
└── scripts/
    ├── start_gom_sync_report.bat       # Lance gom_sync_with_report.py
    └── register_gom_sync_task.ps1      # Enregistre la tâche Windows
```

---

## Flux de données complet

```
┌─────────────────────┐
│  TradingView Desktop │  Pine Script GOM KOLA actif
└──────────┬──────────┘
           │ MCP CDP (data_get_study_values)
           ▼
┌─────────────────────┐
│  gom_verdict_poller  │  Toutes les 30 s
└──────────┬──────────┘
           │ POST /gom-verdict
           ▼
┌─────────────────────────────────────────────────────────┐
│                    ai_server.py :8000                   │
│                                                         │
│  _GOM_VERDICT_STORE  ◄── /gom-verdict (POST)           │
│        │                                               │
│        ├── GET /gom-verdicts        → Python pipelines │
│        └── GET /gom-kola-dashboard  → MT5 EAs          │
│                                                         │
│  _gom_live_calc  ◄── /mt5/upload-candles (MT5 EA)      │
│        │                                               │
│        └── Calcul live → override store si non-WAIT    │
└─────────────────────┬───────────────────────────────────┘
                      │
          ┌───────────┴────────────┐
          ▼                        ▼
┌──────────────────┐    ┌──────────────────────────┐
│ SMC_Universal    │    │ gom_sync_with_report.py  │
│ (MT5, toutes 3s) │    │ (Python, toutes 10 min)  │
│                  │    │                          │
│ Dashboard GOM    │    │ Rapport WhatsApp         │
│ Filtre entrées   │    │ 5 signaux actifs         │
│ Exécute ordres   │    └──────────────────────────┘
└──────────────────┘
          │
          ▼
┌──────────────────┐
│ TradeManager.mq5 │  Trailing · Breakeven · Duplication
└──────────────────┘
          │ Upload deals
          ▼
┌──────────────────┐
│  ai_server.py    │  Feedback loop → amélioration ML
└──────────────────┘
```

---

## Lancement rapide

```bash
# 1. Démarrer le serveur IA
python ai_server.py

# 2. Synchroniser les verdicts GOM + WhatsApp (one-shot)
python python/gom_sync_with_report.py --report

# 3. Lancer le poller MT5 (terminal séparé, MT5 ouvert)
python python/gom_mt5_poller.py

# 4. Lancer le pipeline horaire autonome
python python/pipeline_hourly_autonomous.py --once

# 5. Enregistrer la tâche Windows (admin, une seule fois)
powershell -ExecutionPolicy Bypass -File scripts/register_gom_sync_task.ps1
```

**MT5** : Attacher `SMC_Universal.ex5` sur chaque chart avec `UseGOMPipeline=ON` et `ShowGOMDashboard=ON`.

---

## Variables d'environnement clés

```env
AI_SERVER_URL=http://127.0.0.1:8000
PSYCHOBOT_URL=https://psychobot-1si7.onrender.com
WHATSAPP_OWNER=2290196911346
GOM_TV_VERDICT_TTL_SEC=600
GOM_CANDLE_CACHE_TTL_SEC=8
```

---

## Dépendances principales

| Package | Usage |
|---------|-------|
| `fastapi` + `uvicorn` | Serveur HTTP |
| `pandas` + `numpy` | Calculs indicateurs |
| `MetaTrader5` | Connexion terminal MT5 |
| `requests` | Appels HTTP inter-services |
| `ta-lib` | Indicateurs techniques |
| `scikit-learn` + `xgboost` | ML scoring |
| `supabase` | Base de données cloud |
