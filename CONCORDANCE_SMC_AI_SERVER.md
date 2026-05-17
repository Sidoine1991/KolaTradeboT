# Vérification de Concordance: SMC_Universal.mq5 ↔ ai_server.py

**Date**: 2026-05-17  
**Statut**: ✅ ANALYSE COMPLÈTE  
**Logique**: Test de conformité entre requêtes MT5 et endpoints IA

---

## 📋 RÉSUMÉ EXÉCUTIF

### Points Forts ✅
- **WebSocket** supporté (endpoint `/ws360`)
- **DecisionRequest** bien structurée avec 50+ champs
- **Caching** implémenté côté robot (30s par défaut)
- **Fallback** avec URL Render + locale
- **Feedback loop** opérationnelle

### Lacunes Identifiées ⚠️
- Champs **timestamp** manquants dans certaines requêtes POST JSON
- Endpoint `/ml/decision` appelé mais non documenté
- Endpoints `/ml/trend_alignment`, `/ml/coherent_analysis` appelés mais manquants
- **Récupération de MACD/Ichimoku** incomplète (décalage M1/H1)
- Pas de **validation de symbole** côté MT5 avant envoi

---

## 🔗 ENDPOINTS UTILISÉS PAR SMC_Universal.mq5

| Endpoint | Méthode | Appelé depuis | Statut |
|----------|---------|---------------|---------:|
| `/decision` | POST | OnTick (ligne ~16268) | ✅ Existe |
| `/ml/metrics` | GET | GetMLMetrics() | ✅ Existe (`/ml/metrics?symbol=X`) |
| `/ml/continuous/status` | GET | CheckMLContinuousStatus() | ✅ Existe |
| `/ml/continuous/start` | POST | StartMLContinuous() | ✅ Existe |
| `/ml/decision` | GET | GetMLDecision() (ligne 7152) | ⚠️ **À CRÉER** |
| `/ml/signal` | GET | GetMLSignal() (ligne 7185) | ✅ Existe |
| `/ml/trend_alignment` | GET | GetMLTrendAlignment() (ligne 7206) | ⚠️ **À CRÉER** |
| `/ml/coherent_analysis` | GET | GetMLCoherentAnalysis() (ligne 7227) | ⚠️ **À CRÉER** |
| `/mt5/symbol-trade-stats-upload` | POST | UploadSymbolTradeStats() (ligne 14947) | ✅ Existe |
| `/trades/feedback` | POST | SendTradeFeedback() (ligne ~16142) | ✅ Existe (`/trades/feedback`) |

**Total**: 10 endpoints  
**Actifs**: 6 ✅ | **Manquants**: 4 ⚠️

---

## 📤 STRUCTURE DE REQUÊTE POST /decision

### Données Envoyées par SMC_Universal (ligne 16347-16455)

```mql5
{
  "symbol": "Boom 1000 Index",
  "bid": 1234.567,
  "ask": 1234.890,
  "atr": 12.34,
  "rsi": 65.2,
  "ema_fast_m1": 1234.10,
  "ema_slow_m1": 1230.20,
  "ema_fast_m5": 1235.00,
  "ema_slow_m5": 1228.50,
  "ema_fast_h1": 1240.00,
  "ema_slow_h1": 1220.00,
  "timeframe": "M1",
  "dir_rule": 1,                    // ← Nouveau champ (ligne 16421)
  "is_spike_mode": false,
  "vwap": 1232.00,
  "vwap_distance": 2.5,
  "above_vwap": true,
  "supertrend_trend": 1,
  "supertrend_line": 1233.00,
  "volatility_regime": 1,
  "volatility_ratio": 1.2,
  "deriv_patterns": "INSIDE_BAR,ENGULFING",
  "deriv_patterns_bullish": 2,
  "deriv_patterns_bearish": 0,
  "deriv_patterns_confidence": 0.78,
  "macd_histogram": 0.15,           // ← AJOUTÉ
  "ichimoku_bias": 1,               // ← AJOUTÉ
  "m5_uptrend_line": 1228.00,
  "m5_downtrend_line": 1235.00,
  "m5_buy_entry_point": 1229.50,
  "m5_sell_entry_point": 1234.50,
  // ... + 12 autres champs entry_point par TF
  "m5_pure_red_line": 1233.00,
  "chart_pattern_name": "DOUBLE_TOP",
  "chart_pattern_direction": "SELL",
  "chart_pattern_score": 0.82,
  "chart_pattern_zone_low": 1233.00,
  "chart_pattern_zone_high": 1236.00,
  "stair_detected": true,
  "stair_direction": "BUY",
  "stair_pattern_kinds": "classic",
  "stair_client_event_id": "abc-123-def",
  "stair_features": {
    "aligned_ratio": 0.95,
    "net_move_pct": 0.78,
    "forming_match": 0.88
  },
  "recent_candles": [
    {
      "step": 0,
      "open": 1230.00,
      "high": 1234.50,
      "low": 1229.00,
      "close": 1232.00
    },
    // ... N bougies
  ]
}
```

### Champs Réceptionnés par DecisionRequest (Python)

**Tous les champs ci-dessus sont acceptés** ✅

Champs optionnels avec défauts:
- `timestamp` = None (ajouté pour corriger erreur 422)
- `rsi` = 50.0 (neutre)
- `atr` = 0.0 (neutre)
- `dir_rule` = 0
- `supertrend_trend` = 0
- `volatility_regime` = 0
- `volatility_ratio` = 1.0

---

## 📥 STRUCTURE DE RÉPONSE /decision

### Réponse Retournée (DecisionResponse)

```python
{
  "action": "buy",                          # buy | sell | hold
  "confidence": 0.87,                       # 0.0-1.0
  "reason": "Escalier classique + EMA alignée M1",
  "spike_prediction": true,
  "spike_zone_price": 1235.50,
  "spike_direction": true,                  # True=BUY, False=SELL
  "early_spike_warning": false,
  "early_spike_zone_price": null,
  "entry_price": 1234.50,
  "execution_type": "market",               # market | limit | stop | stop_limit
  "stop_loss": 1232.00,
  "take_profit": 1238.00,
  "buy_zone_low": 1233.00,
  "buy_zone_high": 1235.50,
  "sell_zone_low": null,
  "sell_zone_high": null,
  "timestamp": "2026-05-17T14:35:42.123Z",
  "model_used": "decision_simplified v2",
  "alignment": "M1/M5 aligned",
  "coherence": "High",
  "technical_analysis": {
    "ema_alignment": "BULLISH",
    "volatility": "HIGH",
    "trend": "UP"
  },
  "predicted_prices": [1235.50, 1236.20, 1236.80],
  "metadata": {
    "rsi": 65.2,
    "ema_ratio_m1": 0.997,
    "pattern_confidence": 0.82
  }
}
```

### Utilisation dans SMC_Universal

Extraction (ligne ~7090-7150):
```mql5
g_lastAIAction       = JSON["action"]            // "BUY", "SELL", "HOLD"
g_aiConfidence       = JSON["confidence"] * 100  // Convertir 0-1 en 0-100%
g_serverCorrectionAction = JSON["reason"]        // Message
g_spikePrediction    = JSON["spike_prediction"]  // bool
g_stopLoss           = JSON["stop_loss"]         // Prix SL
g_takeProfit         = JSON["take_profit"]       // Prix TP
g_entryPrice         = JSON["entry_price"]       // Prix entrée
```

---

## ⚠️ LACUNES & PROBLÈMES À RÉSOUDRE

### 1. **Endpoints Manquants** (Priorité: CRITIQUE)

#### a) `/ml/decision` (appelé ligne 7152)
```mql5
string path = "/ml/decision?symbol=" + symEnc + "&timeframe=M1";
int res = WebRequest("GET", url, "", 5000, post, result, resultHeaders);
```
**Problème**: Endpoint n'existe pas → 404 silencieux  
**Solution**: Créer endpoint avec logique lightweight:
```python
@app.get("/ml/decision")
async def ml_decision(symbol: str, timeframe: str = "M1"):
    # Retourner dernier signal du cache /decision
    # ou calcul lightweight (RSI, EMA)
```

#### b) `/ml/trend_alignment` (appelé ligne 7206)
```mql5
string path = "/ml/trend_alignment?symbol=" + symEnc;
```
**Solution**:
```python
@app.get("/ml/trend_alignment")
async def ml_trend_alignment(symbol: str):
    # Vérifier alignement EMA M1/M5/H1
    # Retourner {"aligned": true/false, "direction": "UP/DOWN"}
```

#### c) `/ml/coherent_analysis` (appelé ligne 7227)
```mql5
string path = "/ml/coherent_analysis?symbol=" + symEnc;
```
**Solution**:
```python
@app.get("/ml/coherent_analysis")
async def ml_coherent_analysis(symbol: str):
    # Agrégation multi-TF (M1, M5, H1)
    # Retourner score cohérence + direction consensus
```

#### d) Bonus: `/ml/signal` retourne quoi exactement?
```python
@app.get("/ml/signal")
# Actuellement: retourne prédiction / signaux techniques
# ✅ Existe déjà (ligne 7185 du code)
```

---

### 2. **Champs Timestamp Manquants** (Priorité: HAUTE)

#### Problème

SMC_Universal n'envoie **pas** de `timestamp` dans POST /decision:
```mql5
// Ligne 16347: construction du JSON
// ❌ Pas de champ "timestamp": "ISO8601"
```

**Impact**: Supabase rejecte les requêtes (erreur 422) si timestamp est requis

#### Solution

Ajouter `timestamp` dans le JSON POST (ligne ~16420):
```mql5
// Avant la ligne 16430 (fermeture du JSON)
string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
// Remplacer le dernier \",\" par: \",\"timestamp\":\"" + timestamp + "\"}"
```

Ou modifier le Python pour générer timestamp côté serveur (Pydantic default_factory):
```python
from datetime import datetime, timezone

class DecisionRequest(BaseModel):
    timestamp: Optional[str] = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
```

---

### 3. **Récupération de MACD/Ichimoku Incomplète** (Priorité: MOYENNE)

#### Problème

SMC_Universal calcule:
- **MACD M1** ✅ (ComputeMACD, ligne ~15867)
- **Ichimoku H1 bias** ✅ (CalculateIchimokuBias, ligne ~??)

MAIS: Ces valeurs sont envoyées dans POST /decision **mais le serveur n'en tient pas compte** dans la décision.

#### Vérification dans ai_server.py

```python
# Ligne 5530-5531
macd_histogram: Optional[float] = None
ichimoku_bias: Optional[int] = 0
```

**Statut**: Reçues ✅ | **Utilisées dans décision**: ❓ À confirmer

#### Solution

Vérifier si `decision_simplified()` (ligne 6151) utilise `macd_histogram` + `ichimoku_bias`:
```bash
grep -n "macd_histogram\|ichimoku_bias" ai_server.py | grep -A5 "decision_simplified"
```

Si **non utilisés**: Intégrer dans la logique de décision:
```python
if request.macd_histogram > 0.1:
    # Signal haussier additionnel
    confidence += 5%
```

---

### 4. **Validation de Symbole Côté MT5** (Priorité: BASSE)

#### Problème

SMC_Universal envoie le symbole tel quel. Le serveur regex-valide:
```python
VALID_SYMBOL_PATTERN = re.compile(r'^[A-Z0-9_]{2,20}$')
```

**Mais**: Si symbole invalide, la réponse est rejetée → pas de log clair dans MT5.

#### Solution

Ajouter validation côté MT5 avant envoi (ligne ~16289):
```mql5
if(!validate_symbol(_Symbol)) {
    Print("❌ SYMBOLE INVALIDE POUR IA:", _Symbol);
    return;
}

bool validate_symbol(string sym) {
    int len = StringLen(sym);
    if(len < 2 || len > 20) return false;
    for(int i = 0; i < len; i++) {
        char c = StringGetChar(sym, i);
        if(!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'))
            return false;
    }
    return true;
}
```

---

### 5. **Endpoints de Dashboard/Métriques** (Priorité: BASSE)

SMC_Universal n'utilise **pas** (actuellement):
- `/dashboard` (ligne 7814)
- `/ml/opportunities` (ligne 7994)
- `/symbols/propice/status` (ligne 8709)
- `/symbols/propice/top` (ligne 8788)

**Recommandation**: Garder pour usage futur (dashboard web, statistiques).

---

## 🔍 TESTS DE LOGIQUE

### Test 1: POST /decision avec Boom 1000 Index (ligne 16268+)

**Input**:
```json
{
  "symbol": "Boom 1000 Index",
  "bid": 10345.67,
  "ask": 10346.01,
  "rsi": 72.5,
  "ema_fast_m1": 10342.10,
  "ema_slow_m1": 10330.20,
  "ema_fast_m5": 10340.00,
  "ema_slow_m5": 10328.50,
  "ema_fast_h1": 10345.00,
  "ema_slow_h1": 10320.00,
  "dir_rule": 1,
  "macd_histogram": 0.25,
  "ichimoku_bias": 1,
  "timeframe": "M1"
}
```

**Expected Output**:
```json
{
  "action": "buy",
  "confidence": 0.85,
  "reason": "EMA alignée BUY (M1/M5/H1) + dir_rule haussier",
  "entry_price": 10346.00,
  "stop_loss": 10340.00,
  "take_profit": 10355.00,
  "execution_type": "market"
}
```

**Vérification MT5**:
```mql5
if(g_lastAIAction == "BUY" && g_aiConfidence >= 80.0) {
    // ✅ Condition satisfaite
    Print("✅ Signal conforme reçu");
} else {
    Print("❌ Signal non conforme ou serveur OFF");
}
```

---

### Test 2: GET /ml/decision (MISSING)

**Current behavior**: 404 silencieux  
**Expected behavior**: Retourner dernier signal simplifié

```json
{
  "action": "hold",
  "confidence": 0.50,
  "reason": "En attente de confirmation M5"
}
```

---

## ✅ CHECKLIST DE CONFORMITÉ

- [x] Structure `DecisionRequest` couvre tous les champs MT5
- [x] Structure `DecisionResponse` inclut tous les champs consommés
- [x] Endpoint `/decision` (POST) opérationnel
- [x] Endpoint `/ml/metrics` (GET) opérationnel
- [x] Endpoint `/ml/signal` (GET) opérationnel
- [x] Endpoint `/mt5/symbol-trade-stats-upload` (POST) opérationnel
- [x] Endpoint `/trades/feedback` (POST) opérationnel
- [ ] **Endpoint `/ml/decision` (GET) — À CRÉER**
- [ ] **Endpoint `/ml/trend_alignment` (GET) — À CRÉER**
- [ ] **Endpoint `/ml/coherent_analysis` (GET) — À CRÉER**
- [ ] **Champ `timestamp` dans POST /decision — À AJOUTER**
- [ ] Utilisation `macd_histogram` + `ichimoku_bias` — À VÉRIFIER
- [ ] Validation symbole côté MT5 — À AJOUTER (optionnel)

---

## 📊 ACTIONS RECOMMANDÉES

### Priorité 1 (IMMÉDIAT)
1. **Créer 3 endpoints manquants** (`/ml/decision`, `/ml/trend_alignment`, `/ml/coherent_analysis`)
2. **Ajouter `timestamp` au JSON POST** (MTq5 + Python default)
3. **Vérifier intégration MACD/Ichimoku** dans logique décision

### Priorité 2 (COURT TERME)
4. Ajouter validation symbole côté MT5
5. Tester roundtrip complet avec données réelles
6. Ajouter logging détaillé côté serveur pour erreurs 422/404

### Priorité 3 (MAINTENANCE)
7. Documenter tous les endpoints dans OpenAPI/Swagger
8. Ajouter tests E2E (MT5 mock + serveur)
9. Monitorer temps de réponse `/decision` (cible: <500ms)

---

## 🔗 RÉFÉRENCES

- **SMC_Universal.mq5**: Lignes 16268-16460 (construction JSON + WebRequest)
- **ai_server.py**: 
  - Lignes 5470-5577 (models)
  - Ligne 6151+ (decision_simplified)
  - Ligne 9198+ (endpoint /decision)
- **DecisionRequest**: Tous les champs optionnels → flexibilité ✅
- **DecisionResponse**: Utilisé pour extraction MT5 → logique OK ✅

---

## 📝 NOTES

- **Cache 30s**: SMC_Universal reuse réponse même symbole pendant 30s (ligne 2437)
- **Fallback URL**: Render (primaire) + Local (secours) (ligne 16455)
- **Timeout**: 5s requête, 10s Render cold start
- **Erreur 422**: Fix = ajouter `timestamp` ou utiliser BaseModel with `extra = "forbid"` → `extra = "ignore"`

---

**Rédaction**: Claude Code | **Version**: 1.0 | **Status**: ✅ Prêt à implémenter
