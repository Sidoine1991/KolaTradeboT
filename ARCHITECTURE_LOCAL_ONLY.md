# 🏗️ Nouvelle Architecture: 100% LOCAL, SANS MCP

**Date**: 2026-06-10 17:35 UTC  
**Status**: ⚠️ **EN CONCEPTION**

---

## ❌ PROBLÈME ACTUEL

```
Endpoint /gom-kola-dashboard
    ↓
Lit data/gom_signal.json (STALE)
    ↓
Timestamp: 2026-06-10T11:15:00Z (6+ heures ago!)
    ↓
Verdict: PERFECT BUY (mais TradingView dit PERFECT SELL)
```

**Causes:**
1. ❌ Daemon `gom_sync_daemon.py` n'est pas en cours d'exécution
2. ❌ Aucun refresh du JSON depuis 11:15 UTC
3. ❌ Données complètement obsolètes
4. ❌ Utilisateur reçoit des verdicts INCORRECTS

---

## ✅ NOUVELLE ARCHITECTURE

### Avant (MCP-Dependent)
```
/gom-kola-dashboard
    ↓
Cherche data/gom_signal.json
    ↓
JSON stale (daemon off)
    ↓
❌ Verdict INCORRECT (6+ heures de retard)
```

### Après (100% LOCAL & LIVE)
```
/gom-kola-dashboard?symbol=XAUUSD
    ↓
Récupère candles HISTORIQUES localement
    (MT5 historic data, ou CSV cache)
    ↓
Calcule:
  - RSI multi-TF (M1, M5, M15, H1, H4, D1)
  - Bollinger Bands
  - VWAP
  - MACD
  - SuperTrend
  - KOLA levels
    ↓
Exécute GOMVerdictCalculatorV2
  (score_buy, score_sell, verdict_num)
    ↓
Retourne verdict EN TEMPS RÉEL
    ↓
✅ Verdict CORRECT (calculé à la demande)
```

---

## 🎯 Changements Requis

### 1. SUPPRIMER la dépendance au JSON stale

**Ancien Code** (ai_server.py):
```python
# ❌ Charge depuis JSON (peut être stale)
gom_file = Path(__file__).parent / "data" / "gom_signal.json"
with open(gom_file, 'r', encoding='utf-8') as f:
    gom_data = json.load(f)
record = gom_data[symbol]
```

**Nouveau Code**:
```python
# ✅ Calcule EN TEMPS RÉEL
record = calculate_gom_signals_live(symbol, timeframe="M15")
# Cette fonction:
# 1. Récupère les candles (source locale/MT5)
# 2. Calcule tous les indicateurs
# 3. Retourne record frais
```

### 2. Créer fonction `calculate_gom_signals_live()`

**Responsabilités:**
- Récupérer candles M1, M5, M15, H1, H4, D1
- Calculer indicateurs (RSI, BB, VWAP, MACD, etc.)
- Calculer KOLA levels
- Retourner record complet

**Source des candles:**
- Option A: MT5 API (si connected)
- Option B: CSV cache local
- Option C: Cache in-memory (10min retention)

### 3. Rendre GOMVerdictCalculatorV2 LIVE-READY

**Actuel:**
```python
calc.enrich_record(record)
# record vient du JSON (stale)
```

**Nouveau:**
```python
# record vient de calculate_gom_signals_live()
record = calculate_gom_signals_live("XAUUSD")
calc.enrich_record(record)
# Verdict FRAIS basé sur données ACTUELLES
```

---

## 📊 Sources de Données (Hiérarchie)

```
1. MT5 LIVE (si connecté)
   ├─ Candles actuelles M1-D1
   ├─ Indicateurs MT5 intégrés
   └─ Prix actuel

2. CSV Cache LOCAL (fallback)
   ├─ Données historiques (J-5 jours)
   ├─ Mise à jour horaire
   └─ Calculé localement

3. Memory Cache (optionnel)
   ├─ Derniers 10min de candles
   └─ Rapidité optimisée
```

---

## 🔄 Pipeline Calculée EN DIRECT

### Phase 1: Récupérer Candles
```python
def get_candles_live(symbol, timeframe, bars=100):
    # Source 1: MT5 si connected
    # Source 2: CSV cache si pas MT5
    # Retourne: DataFrame [time, open, high, low, close, volume]
```

### Phase 2: Calculer Indicateurs
```python
def calculate_indicators(df):
    # RSI(14) multi-TF
    # Bollinger Bands(20,2)
    # VWAP
    # MACD
    # SuperTrend
    # Keltner Channel
    # Donchian
    # KOLA levels (custom)
    # Retourne: dict {indicator_name: value}
```

### Phase 3: Évaluer Multi-TF
```python
def evaluate_multitf(symbol):
    # Pour M1, M5, M15, H1, H4, D1:
    #   1. Récupère candles
    #   2. Calcule RSI + Direction
    #   3. Retourne [dir, rsi]
    # Retourne: {
    #   "tf_m1_dir": "BULL", "tf_m1_rsi": 68,
    #   ...
    #   "tf_global_dir": "BULL", "tf_global_strength": 6
    # }
```

### Phase 4: Calculer Verdict
```python
def calculate_verdict_live(symbol):
    # 1. Récupère candles + indicateurs (live)
    # 2. Construit record complet
    # 3. Applique GOMVerdictCalculatorV2
    # 4. Retourne record enrichi avec verdict
    return record
```

### Phase 5: Servir Endpoint
```python
@app.get("/gom-kola-dashboard")
async def gom_kola_dashboard(symbol: str = Query("XAUUSD")):
    # ✅ NOUVEAU: Appel la fonction LIVE
    record = calculate_verdict_live(symbol)
    
    # Retourne réponse FRAÎCHE
    return {
        "timestamp": datetime.utcnow().isoformat(),  # ← ACTUEL
        "verdict": record["verdict"],
        "score_buy": record["score_buy"],
        ...
    }
```

---

## 🎯 Avantages

| Aspect | Avant (JSON) | Après (LIVE) |
|--------|------------|------------|
| **Fraîcheur** | 6+ heures stale | ✅ Temps réel |
| **Exactitude** | ❌ Peut être inverse | ✅ Toujours correct |
| **Dépendance** | Daemon externe | ✅ Aucune |
| **Latence** | 1 seule (read file) | ~500ms (calcul) |
| **Maintenance** | Complexe (daemon) | ✅ Simple (stateless) |

---

## 🔧 Implémentation Prioritaire

### Étape 1: Créer `gom_live_calculator.py`
```python
class GOMSignalsLiveCalculator:
    def get_candles(self, symbol, timeframe, bars=100):
        # Récupère candles (MT5 ou CSV)
        pass
    
    def calculate_all_indicators(self, symbol, df):
        # RSI, BB, VWAP, MACD, ST, KC, DC
        pass
    
    def evaluate_multitf_live(self, symbol):
        # M1-D1: Direction + RSI
        pass
    
    def calculate_record_live(self, symbol):
        # Record complet FRAIS
        pass
```

### Étape 2: Modifier `ai_server.py`
```python
from gom_live_calculator import GOMSignalsLiveCalculator

_live_calc = GOMSignalsLiveCalculator()

@app.get("/gom-kola-dashboard")
async def gom_kola_dashboard(symbol: str = Query("XAUUSD")):
    # ✅ NOUVEAU: Utilise calculateur LIVE
    record = _live_calc.calculate_record_live(symbol)
    record = _gom_verdict_calc.enrich_record(record)
    return record
```

### Étape 3: Tester
```bash
# Avant: JSON stale (6+ heures)
# Après: Données fraîches (< 1 seconde)

curl http://localhost:8000/gom-kola-dashboard?symbol=XAUUSD
# Affiche timestamp ACTUEL
# Verdict CORRECT (matches TradingView)
```

---

## ⚠️ Points Critiques

### Source de Candles
**Question:** Où récupérer les candles?
- ✅ MT5 API (si tu as connexion MT5)
- ✅ CSV local (si tu exporte les données)
- ✅ Cache in-memory (10min)

### Performance
**Concern:** Calcul 6 TF + 8 indicateurs = ~500ms
**Solution:** Cache 1-2 minutes, invalidate si nouvel appel

### Fallback
**Concern:** Si source indisponible?
**Solution:** Fallback gracieux, retourne erreur claire

---

## 🎯 Résultat Attendu

**AVANT** (JSON stale):
```json
{
  "timestamp": "2026-06-10T11:15:00Z",  ← 6+ heures ago!
  "verdict": "PERFECT BUY",              ← FAUX (TradingView: SELL)
  "source": "local_json"
}
```

**APRÈS** (LIVE calculation):
```json
{
  "timestamp": "2026-06-10T17:35:00Z",  ← MAINTENANT!
  "verdict": "PERFECT SELL",            ← CORRECT (matches TV)
  "source": "live_calculation"          ← Calculé en direct
}
```

---

## 📋 Checklist Implementation

- [ ] Créer `gom_live_calculator.py`
- [ ] Implémenter `get_candles()`
- [ ] Implémenter `calculate_all_indicators()`
- [ ] Implémenter `evaluate_multitf_live()`
- [ ] Implémenter `calculate_record_live()`
- [ ] Modifier `ai_server.py` pour utiliser live calc
- [ ] Tester avec plusieurs symboles
- [ ] Vérifier performance (< 1s par appel)
- [ ] Valider vs TradingView (match verdicts)

---

**Status**: ⏳ **EN ATTENTE DE DÉCISION**

Veux-tu que je procède à cette restructuration?
