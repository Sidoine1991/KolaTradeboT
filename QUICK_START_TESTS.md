# Quick Start - Tests des Nouveaux Endpoints

**Durée**: 5-10 minutes  
**Prérequis**: Python 3.8+, pip, curl (optionnel)

---

## 🚀 ÉTAPE 1: Lancer le Serveur IA (Terminal 1)

```bash
cd D:\Dev\TradBOT\python
python ai_server.py
```

**Expected Output**:
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

⏸️ Laisser le terminal OUVERT

---

## 🧪 ÉTAPE 2: Lancer les Tests (Terminal 2)

```bash
cd D:\Dev\TradBOT
python test_new_endpoints.py
```

**Expected Output**:
```
======================================================================
  TEST 1: Server Health Check
======================================================================

ℹ️   Testing connection to http://localhost:8000
✅ Server is UP (HTTP 200)
ℹ️   Response: {'status': 'ok', 'version': '2.1.0'}

======================================================================
  TEST 2: GET /ml/decision
======================================================================

ℹ️   Testing: Boom 1000 Index
✅ HTTP 200 | Action: buy | Confidence: 0.87 | Time: 0.102s
✅ All required fields present
✅ Response time OK: 0.102s

... (tests pour autres symboles)

======================================================================
  TEST 3: GET /ml/trend_alignment
======================================================================

✅ All tests passed! 🎉
```

---

## 🔍 ÉTAPE 3: Test Manual avec curl (Terminal 2)

### Health Check
```bash
curl http://localhost:8000/health
```

**Response**: 
```json
{"status": "ok", "version": "2.1.0"}
```

### /ml/decision
```bash
curl "http://localhost:8000/ml/decision?symbol=Boom%201000%20Index&timeframe=M1"
```

**Response**:
```json
{
  "action": "buy",
  "confidence": 0.75,
  "reason": "M1=UP | M5=UP | H1=NEUTRAL",
  "timestamp": "2026-05-17T14:35:42.123Z"
}
```

### /ml/trend_alignment
```bash
curl "http://localhost:8000/ml/trend_alignment?symbol=Boom%201000%20Index"
```

**Response**:
```json
{
  "aligned": true,
  "direction": "UP",
  "confidence": 0.75,
  "m1_trend": "UP",
  "m5_trend": "UP",
  "h1_trend": "NEUTRAL",
  "timestamp": "2026-05-17T14:35:42.123Z"
}
```

### /ml/coherent_analysis
```bash
curl "http://localhost:8000/ml/coherent_analysis?symbol=Boom%201000%20Index"
```

**Response**:
```json
{
  "coherence_score": 0.75,
  "consensus": "UP",
  "m1_trend": "UP",
  "m5_trend": "UP",
  "h1_trend": "NEUTRAL",
  "volatility_regime": "NORMAL",
  "timestamp": "2026-05-17T14:35:42.123Z"
}
```

---

## 📊 ÉTAPE 4: Tester depuis MT5 (Optionnel)

### 4a. Ouvrir MT5
```
MetaTrader 5 Terminal → Expert Advisors → SMC_Universal
```

### 4b. Charger sur Boom 1000 Index M1
- Symbol: Boom 1000 Index
- Timeframe: M1
- Enable: Allow algorithms (checkbox)

### 4c. Vérifier les Logs
Journal (View → Toolbars → Journal) → onglet "Expert Advisors"

**Rechercher**:
```
?? ENVOI IA: {...}  // ← POST /decision
✅ Signal AI reçu   // ← Réponse recue
```

---

## ✅ CHECKLIST DE VALIDATION

### Test Suite Automatisé
- [ ] Health Check: PASS
- [ ] /ml/decision: PASS (3/3 symbols)
- [ ] /ml/trend_alignment: PASS (3/3 symbols)
- [ ] /ml/coherent_analysis: PASS (3/3 symbols)
- [ ] Performance: All <500ms

### Manual Tests
- [ ] curl /health: HTTP 200
- [ ] curl /ml/decision: HTTP 200 + JSON valide
- [ ] curl /ml/trend_alignment: HTTP 200 + JSON valide
- [ ] curl /ml/coherent_analysis: HTTP 200 + JSON valide

### MT5 Tests (Optionnel)
- [ ] SMC_Universal load OK (no crashes)
- [ ] POST /decision reçoit réponse
- [ ] g_lastAIAction ≠ HOLD
- [ ] Journal: pas d'erreurs 422/500

---

## 🐛 TROUBLESHOOTING

### Problème: "Connection refused"
```
❌ Error: Cannot reach server
```

**Solution**:
```bash
# Vérifier que ai_server.py tourne
netstat -an | grep 8000  # Windows
# ou
lsof -i :8000            # Mac/Linux

# Si pas de processus:
cd D:\Dev\TradBOT\python
python ai_server.py
```

### Problème: "500 Internal Server Error"
```
❌ HTTP 500: Internal server error
```

**Solution**:
1. Vérifier logs du serveur
2. Chercher exceptions dans terminal Python
3. Vérifier que symbol est valide: `Boom 1000 Index` (exact case!)

### Problème: "404 Not Found"
```
❌ HTTP 404: Not found
```

**Solution**:
- Endpoints n'existent pas? → Vérifier ai_server.py contient 3 endpoints (lignes 18591+)
- Symbol typo? → Utiliser `Boom%201000%20Index` (URL encoded)

### Problème: "422 Unprocessable Entity"
```
❌ HTTP 422: Validation error
```

**Solution**:
- Parameter invalide?
- Symbol missing?
- Vérifier URL syntax:
  ```
  ✅ http://localhost:8000/ml/decision?symbol=Boom%201000%20Index&timeframe=M1
  ❌ http://localhost:8000/ml/decision?symbol=Boom 1000 Index
  ```

---

## 📈 PERFORMANCE EXPECTATIONS

| Endpoint | Time | Notes |
|----------|------|-------|
| /ml/decision | ~100ms | Très rapide (cache) |
| /ml/trend_alignment | ~150ms | Calcul M1/M5/H1 |
| /ml/coherent_analysis | ~150ms | Consensus multi-TF |
| /decision (POST) | ~300ms | Decision engine |

**Total**: < 500ms target ✅

---

## 🎯 NEXT STEPS

### Si tous les tests PASSENT ✅
1. Commitez les changements
2. Notifiez l'équipe
3. Continuez Phase 2 (MACD/Ichimoku)

### Si certains tests ÉCHOUENT ❌
1. Consultez TROUBLESHOOTING ci-dessus
2. Vérifiez logs: Terminal Python → errors
3. Consultez document `CONCORDANCE_SMC_AI_SERVER.md`
4. Contactez support

---

## 📝 COMMANDES UTILES

```bash
# Vérifier Python version
python --version
# Besoin: 3.8+

# Vérifier port 8000 accessible
netstat -an | findstr 8000  # Windows
netstat -an | grep 8000     # Mac/Linux

# Kill processus Python si stuck
taskkill /PID <PID> /F      # Windows
kill -9 <PID>               # Mac/Linux

# Voir version ai_server
curl http://localhost:8000/health | jq .version

# Benchmark performance
time python test_new_endpoints.py
```

---

## 🎉 SUCCESS!

Si tous les tests passent, votre implémentation est complète!

**Prochaines étapes**:
1. ✅ Phase 1: 3 endpoints créés
2. 🔄 Phase 2: Ajouter MACD/Ichimoku (cette semaine)
3. 📋 Phase 3: Staircase + Pattern (prochaine semaine)
4. 🚀 Phase 4: Déployer sur Render

---

**Durée estimée**: 10 minutes  
**Difficulty**: 🟢 FACILE  
**Support**: Consultez CONCORDANCE_SMC_AI_SERVER.md
