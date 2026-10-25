# 🔴 Diagnostic: GOM Verdict ≠ Market Reality

## Observation
**Le verdict GOM calculé n'est pas en adéquation avec les réalités du marché** (GainX 400,M1, screenshot 22 Sep 01:34 - 18:38)

---

## 🎯 Root Cause Analysis

### 1. **Données Stale / Staleness Issue**
Le problème le plus courant sur GainX/PainX temps réel:

```python
# gom_live_calculator.py line 52-59
GOM_CANDLE_CACHE_TTL_SEC = 2.0  # FIX 2026-08-24: 8s → 2s
GOM_CANDLE_STALE_MIN_SEC = 120.0  # FIX 2026-08-24: 900s → 120s
```

**Symptômes:**
- Verdict calculé sur une bougie **T-1** (bougie fermée) au lieu de **T** (bougie en formation)
- Scores `score_buy` / `score_sell` laggués de 1-3 bougies
- Directions `tf_m1_dir`, `tf_m5_dir` figées alors que le prix a déjà inversé

**Check:**
```python
# Vérifier l'âge de chaque TF dans record:
price_direction_1b → doit être calculé en temps réel (< 2s)
price_direction_3b → doit être < 6s
price_direction_5b → doit être < 10s
last_update_ts → doit être = time.time() ± 1s
```

---

### 2. **Filtre M1+M5 Trop Strict (TrendAlign)**
```python
# gom_pine_calculator.py line 165-206
def apply_m1m5_trend_alignment(record: Dict[str, Any], verdict_num: int) -> int:
    # Si M1 = BULL, M5 = BEAR → retour 0 (WAIT)
```

**Cas PainX 999 observé:**
- Verdict GOM = BUY (score dominant)
- M1 = BULL (juste après spike up)
- M5 = BEAR (après dump antérieur)
→ **Verdict bloqué à 0 (WAIT)** alors que le prix monte

**Fix potentiel:**
```python
# Au lieu de bloquer complètement, utiliser une réduction de magnitude:
if m1 == "BULL" and m5 == "BEAR":
    # Retourner SIMPLE au lieu de 0:
    return 1 if vn > 0 else (-1 if vn < 0 else 0)
```

---

### 3. **Correction Gate Trop Aggressive**
```python
# gom_pine_calculator.py line 624-645
def apply_price_impulse_cap():
    if against_13 and against_5:
        return 0  # WAIT complet
    if against_13:
        return sign  # SIMPLE seulement
```

**Problème sur GainX 400,M1:**
- Un rebond 2-3 bougies contre le sens = tout le verdict s'effondre
- Mais c'est un **pullback naturel**, pas une inversion
- Le verdict devrait rester SIMPLE (1), pas WAIT (0)

**Diag:**
Vérifier `impulse_cap_reason` dans les logs:
```
impulse_cap_reason = "m1_1b3b_against->SIMPLE"  ← OK
impulse_cap_reason = "m1_1b3b5b_against->WAIT"  ← ⚠️ TOO AGGRESSIVE?
```

---

### 4. **Score Direction Authority Flawed**
```python
# gom_pine_calculator.py line 240-291
def apply_score_direction_authority(record, verdict_num):
    # Si score_buy >> score_sell, verdict passe à BUY même si natif SELL
```

**Cas PainX 999 / GainX 400 typique:**
```
score_buy = 8.5  (fort)
score_sell = 3.2  (faible)
gap = 5.3  (> 4.0 → PERFECT)

verdict_num = -2  (SELL natif, bon signal technique)

→ Verdict flipe à +3 (BUY PERFECT)
→ Mais prix continue DOWN (IA HOLD, tendance long-term)
```

**Fix:**
```python
# Ajouter vérification D1/H1 avant d'autoriser le flip:
if gap >= 4.0:
    # Vérifier que D1 n'est pas en strong downtrend
    tf_d1 = record.get("tf_d1_dir", "NEUT")
    if tf_d1 == "BEAR":
        # Limiter le flip:
        mag = 1 if gap >= 4.0 else 0
```

---

### 5. **Lag entre Candles MT5 et Calcul Python**
**Scénario typique:**
1. T=01:34:00 → Bougie ferme, verdict calculé = BUY
2. T=01:35:01 → Nouvelle bougie ouvre avec spike DOWN
3. T=01:35:30 → Verdict **toujours** = BUY (pas recalculé)
4. T=01:35:59 → Prix a dumped 15 pips mais verdict = BUY

**Cause:**
- `gom_live_calculator` recalcule seulement tous les **N** (2-5?) appels API
- Ou bien le cache **persist** le verdict même après fermeture de bougie

**Fix:**
```python
# Forcer recalcul si timestamp_derniere_execution > 60s:
if record["last_verdict_ts"] and (time.time() - record["last_verdict_ts"]) > 60:
    record.clear()  # Réinitialiser cache
    return calculate_verdict_fresh(...)
```

---

## 🔧 Solutions Priorisées

### Priority 1: **Fix Staleness (URGENT)**
```python
# Dans gom_live_calculator.py:

# 1. Réduire TTL à 1s (au lieu de 2s):
GOM_CANDLE_CACHE_TTL_SEC = 1.0

# 2. Forcer MT5 fetch si données > 60s:
def get_candles(...):
    age = df_last_bar_age_sec(df)
    if age and age > 60:
        # Ignorer cache, fetch MT5 fresh
        return fetch_mt5_candles(symbol, tf)

# 3. Timestamp chaque calcul:
record["verdict_calculated_at"] = time.time()
```

---

### Priority 2: **Adoucir TrendAlign pour Volatilités**
```python
# Pour GainX/PainX (volatilités), autoriser divergence M1/M5:
def apply_m1m5_trend_alignment(record, verdict_num):
    is_volatility = any(x in record.get("symbol", "").lower() 
                       for x in ["gainx", "painx", "vol"])
    
    if is_volatility and abs(verdict_num) >= 2:
        # Pour GOOD/PERFECT sur volatility, tolérer divergence M1/M5
        # (La volatility est bidirectionnelle par nature)
        return verdict_num
    
    # Sinon, appliquer la logique stricte M1+M5
    ...
```

---

### Priority 3: **Score Authority Gating**
```python
# Ne pas flipper le verdict si ordre supérieur est contre:
def apply_score_direction_authority(record, verdict_num):
    vn = int(verdict_num or 0)
    sb = float(record.get("score_buy", 0) or 0)
    ss = float(record.get("score_sell", 0) or 0)
    gap = abs(sb - ss)
    
    # Si H4 ou D1 est STRONG contre, limiter le flip:
    h4_dir = record.get("tf_h4_dir", "NEUT")
    d1_dir = record.get("tf_d1_dir", "NEUT")
    
    if sb > ss and gap >= 4.0:
        # Vérifier contexte long-term:
        if d1_dir == "BEAR" or h4_dir == "BEAR":
            # Flip limité à SIMPLE:
            return 1 if gap >= 2.5 else 0
        # Sinon, flip normal:
        return 3
    ...
```

---

### Priority 4: **Impulse Cap Refinement**
```python
# Ne pas couper un mouvement franc sur un simple pullback:
def apply_price_impulse_cap(record, verdict_num):
    vn = int(verdict_num or 0)
    if vn == 0:
        return 0
    
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    sign = 1 if vn > 0 else -1
    mag = abs(vn)
    
    # Nouveau: distinguer pullback vs vrai renversement
    swing_high = float(record.get("last_swing_high", 0) or 0)
    swing_low = float(record.get("last_swing_low", 0) or 0)
    close = float(record.get("close", 0) or 0)
    
    if swing_high > swing_low > 0:
        pullback_pct = abs(close - swing_high) / (swing_high - swing_low)
        
        if sign > 0 and d1 < 0 and d3 < 0:
            # BUY verdict mais 1b+3b down
            if pullback_pct < 0.3:  # pullback faible (< 30%)
                # C'est juste une correction, pas une inversion
                record["impulse_cap_reason"] = f"pullback_{pullback_pct*100:.0f}pct->SIMPLE"
                return sign
            else:
                # Pullback fort → réduction verdict
                record["impulse_cap_reason"] = "strong_pullback->WAIT"
                return 0
```

---

## 📊 Checklist Diagnostic

Avant d'appliquer fixes, vérifier:

- [ ] **Logs de timestamp:**
  ```python
  print(f"record_ts={record['timestamp']}, now={time.time()}, age_sec={time.time()-record['timestamp']}")
  ```

- [ ] **Vérifier données sources:**
  ```python
  print(f"price_direction_1b={record['price_direction_1b']}, "
        f"price_direction_3b={record['price_direction_3b']}, "
        f"price_direction_5b={record['price_direction_5b']}")
  ```

- [ ] **Logs filtres appliqués:**
  ```python
  print(f"mtf_align_reason={record.get('trend_align_reason')}, "
        f"impulse_cap_reason={record.get('impulse_cap_reason')}, "
        f"score_dir_reason={record.get('score_dir_reason')}")
  ```

- [ ] **Vérifier EA sync:**
  ```
  SMC_Universal.mq5: dernier CallCalculateVerdict() = quelle heure?
  GOM server: dernier calcul = quelle heure?
  Différence > 60s ?
  ```

---

## 🎯 Test Fixes

Après implémentation:

```python
# Test: PainX 999, M1, signal BUY vs réalité HOLD
record = {
    "symbol": "PainX999,M1",
    "score_buy": 8.5,
    "score_sell": 3.2,
    "verdict_num": -2,  # SELL natif
    "tf_d1_dir": "BEAR",
    "tf_m1_dir": "BULL",
    "tf_m5_dir": "BEAR",
    "price_direction_1b": 0.0001,
    "price_direction_3b": -0.0002,
    "price_direction_5b": -0.0003,
}

# Avant fix: verdict_num = +3 (BUY PERFECT) ← FAUX
# Après fix: verdict_num = +1 (BUY SIMPLE) ou 0 (WAIT) ← CORRECT
```

---

## 📝 Notes pour l'EA (SMC_Universal.mq5)

Ajouter dans `OnTick()`:

```mql5
if (IsNewCandle()) {
    // Force recalcul GOM avant chaque décision
    GOMCacheInvalidate();
    // Attendre que le calcul soit à jour:
    if (TimeCurrent() - GOMLastUpdateTime > 60) {
        // Log warning: GOM verdict peut être stale
        Print("WARNING: GOM verdict stale > 60s, skip entry");
    }
}
```

---

**Status:** 🔴 URGENT | Créé: 2026-09-22 | Priorité: 1 (Staleness), 2 (M1M5), 3 (Scores), 4 (Impulse)
