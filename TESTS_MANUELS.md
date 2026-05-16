# Tests Manuels - Dashboard ML + AWS RDS

**Date:** 2026-05-16 01:20  
**Objectif:** Vérifier que tout fonctionne correctement

---

## ✅ Tests Automatiques (Effectués)

### 1. Render Deployment ✅
- **URL:** https://kolatradebot-7ofl.onrender.com
- **Status:** Service live
- **Logs:** Aucune erreur au démarrage
- **Endpoint /health:** Répond 200 OK

### 2. Compilation SMC_Universal ✅
- **Terminal 1:** SMC_Universal.ex5 (1.1 MB, 23:32)
- **Dev:** SMC_Universal.ex5 (1.1 MB, 00:07)
- **Résultat:** 0 errors, 0 warnings

### 3. Fichiers Dashboard ✅
- **GOM_Enhanced_Dashboard.mqh:** Fonction V3 présente
- **SMC_Universal.mq5:** Appelle V3 correctement
- **Terminal 2:** Fichiers copiés (01:13)

### 4. Code AWS RDS ✅
- **ai_server.py:** Variables AWS_RDS_AVAILABLE présentes
- **aws_rds_helper.py:** Classe AWSRDSClient implémentée
- **.env:** Credentials AWS RDS configurés

---

## 📋 Tests Manuels À Effectuer

### Test 1: Vérifier Logs Render

1. Allez sur: https://dashboard.render.com/web/srv-cvs93ddumphs739q5hd0/logs

2. **Cherchez dans les logs:**
   ```
   ✅ AWS RDS PostgreSQL helper chargé
   ```
   
3. **Vérifiez qu'il N'Y A PAS:**
   ```
   ❌ Supabase
   ❌ Table 'supabase'
   ❌ HTTP request to supabase.co
   ```

4. **Si vous voyez AWS RDS:** ✅ Test réussi

---

### Test 2: Compiler SMC_Universal (Terminal 2)

1. **Ouvrez MetaEditor**

2. **File → Open:**
   ```
   C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\
   E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\SMC_Universal.mq5
   ```

3. **Appuyez sur F7** (Compile)

4. **Vérifiez résultat:**
   ```
   Result: 0 errors, 0 warnings
   ```

5. **Vérifiez fichier .ex5 créé:**
   ```
   C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\
   E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\SMC_Universal.ex5
   ```

6. **Si 0 errors:** ✅ Test réussi

---

### Test 3: Lancer Synchronisation ML

1. **Double-cliquez sur:**
   ```
   D:\Dev\TradBOT\start_ml_sync.bat
   ```

2. **Attendez le démarrage:**
   ```
   === Synchronisation ML Stats vers MT5 ===
   Connexion AWS RDS...
   Rafraîchissement toutes les 30s
   ```

3. **Vérifiez logs toutes les 30s:**
   ```
   [XX:XX:XX] Synchronisation stats ML...
     Prédictions: XXX (précision: XX.X%)
     Trades: XX (win rate: XX.X%)
     Profit moyen: $X.XX
     Modèles chargés: XX
     ✅ Synchronisation terminée
   ```

4. **Laissez tourner en arrière-plan**

5. **Si synchronisation réussie:** ✅ Test réussi

---

### Test 4: Vérifier GlobalVariables MT5

1. **Dans MT5:**
   - Tools → Options → Expert Advisors
   - Onglet "Global Variables"

2. **Cherchez ces variables:**
   ```
   ML_TOTAL_PREDICTIONS = XXX
   ML_ACCURACY = X.XX
   ML_TRADES_TOTAL = XX
   ML_TRADES_WIN = XX
   ML_AVG_PROFIT_USD = X.XX
   ML_MODELS_LOADED = XX
   EA_DASH_UTC_PAUSE = 0 ou 1
   ```

3. **Si variables présentes avec valeurs > 0:** ✅ Test réussi

---

### Test 5: Attacher SMC_Universal

1. **Ouvrez un graphique MT5:**
   - Exemple: Boom 1000 Index, M5

2. **Navigateur (Ctrl+N) → Expert Advisors → SMC_Universal**

3. **Glissez sur le graphique**

4. **Dans la fenêtre Inputs:**

   **Section "DASHBOARD ML AWS RDS":**
   ```
   UseEnhancedDashboard    = true    ✅
   DashboardMLPosX         = 10
   DashboardMLPosY         = 30
   DashboardMLAnchorTop    = true
   DashboardMLCellWidth    = 100
   DashboardMLCellHeight   = 25
   DashboardMLFontSize     = 8
   ```

   **Section "SCANNER MULTI-SYMBOLES":**
   ```
   EnableOpportunityScanner = false  ⚠️ DÉSACTIVER
   ScannerShowPanel        = false   ⚠️ DÉSACTIVER
   ```

5. **Cliquez OK**

6. **Si EA s'attache sans erreur:** ✅ Test réussi

---

### Test 6: Vérifier Dashboard Visible

1. **Attendez 30-60 secondes** (première synchro)

2. **Cherchez en haut à gauche du graphique:**

   **Si pause UTC active (heure actuelle 00h-06h UTC):**
   ```
   ┌────────────────────────────────┐
   │ ⏸️ UTC PAUSE  📊 POS:0  💵 -20$ │
   │ ⏰ Hors fenêtre UTC  ↻ ATTENTE │
   │ 🎯 68.2%   📈 64.0%   🧠 x36   │
   │ 🔮 15s     📊 1247    💼 89    │
   └────────────────────────────────┘
   ```

   **Si fenêtre UTC ouverte:**
   ```
   ┌────────────────────────────────┐
   │ 🤖 ACTIVE  📊 POS:0  💵 +2.45$ │
   │ 🎯 68.2%   📈 64.0%   🧠 x36   │
   │ 🔮 15s     📊 1247    💼 89    │
   └────────────────────────────────┘
   ```

3. **Légende:**
   - **Ligne 1:** Statut robot, positions, profit
   - **Ligne 2:** (si pause) Raison pause UTC
   - **Ligne 3:** ML précision, win rate, modèles
   - **Ligne 4:** Dernière prédiction, total prédictions, total trades

4. **Si dashboard visible:** ✅ Test réussi

---

### Test 7: Vérifier Valeurs ML Non Nulles

1. **Regardez le dashboard**

2. **Vérifiez que ces valeurs NE SONT PAS 0:**
   - 🎯 XX.X% (précision ML)
   - 📈 XX.X% (win rate)
   - 🧠 xXX (modèles chargés)
   - 📊 XXXX (total prédictions)

3. **Si valeurs > 0:** ✅ Test réussi

4. **Si toutes à 0:**
   - ❌ Vérifiez que `sync_ml_stats_to_mt5.py` tourne
   - ❌ Vérifiez GlobalVariables MT5
   - ❌ Relancez `start_ml_sync.bat`

---

### Test 8: Tester Endpoint Decision

1. **Ouvrez PowerShell**

2. **Exécutez:**
   ```powershell
   $body = @{
       symbol = "EURUSD"
       bid = 1.0850
       ask = 1.0852
       atr = 0.0015
       rsi = 55.0
       ema_fast_m1 = 1.0851
       ema_slow_m1 = 1.0849
       timeframe = "M1"
   } | ConvertTo-Json

   Invoke-RestMethod -Uri "https://kolatradebot-7ofl.onrender.com/decision" `
       -Method POST `
       -Body $body `
       -ContentType "application/json"
   ```

3. **Vérifiez réponse:**
   ```json
   {
     "action": "hold",
     "confidence": 0.58,
     "reason": "Analyse technique...",
     ...
   }
   ```

4. **Si réponse valide:** ✅ Test réussi

---

### Test 9: Vérifier Logs MT5

1. **Dans MT5, onglet "Experts"**

2. **Cherchez:**
   ```
   ✅ Pas d'erreur "GOM_DrawEnhancedDashboardV3"
   ✅ Pas d'erreur "undeclared identifier"
   ✅ Pas d'erreur "file not found"
   ```

3. **Si vous voyez:**
   ```
   ⏸ MODE ARRÊT AUTO UTC - Trading suspendu (heure UTC=XX)
   ```
   C'est **NORMAL** - le dashboard doit l'afficher.

4. **Si aucune erreur dashboard:** ✅ Test réussi

---

### Test 10: Vérifier Pause UTC Fonctionne

1. **Si l'heure actuelle est 00h-06h UTC (01h-07h locale):**
   - Dashboard doit afficher: `⏸️ UTC PAUSE`
   - Ligne 2: `⏰ Hors fenêtre UTC`

2. **Si l'heure actuelle est 06h-23h UTC:**
   - Dashboard doit afficher: `🤖 ACTIVE` ou `⏸️ PAUSE`
   - PAS de ligne "Hors fenêtre UTC"

3. **Si affichage correct selon l'heure:** ✅ Test réussi

---

## 🎯 Résumé des Tests

Cochez au fur et à mesure:

- [ ] Test 1: Logs Render montrent AWS RDS
- [ ] Test 2: Compilation Terminal 2 réussie
- [ ] Test 3: Sync ML tourne et synchronise
- [ ] Test 4: GlobalVariables MT5 présentes
- [ ] Test 5: EA attaché sans erreur
- [ ] Test 6: Dashboard visible
- [ ] Test 7: Valeurs ML non nulles
- [ ] Test 8: Endpoint /decision répond
- [ ] Test 9: Aucune erreur dans logs MT5
- [ ] Test 10: Pause UTC affichée correctement

**Si tous cochés:** 🎉 **SYSTÈME OPÉRATIONNEL !**

---

## 🐛 Dépannage

### Dashboard ne s'affiche pas

**Vérifications:**
1. `UseEnhancedDashboard = true` ✅
2. Script `sync_ml_stats_to_mt5.py` tourne ✅
3. Onglet Experts MT5: pas d'erreur ✅

**Solution:**
- Supprimer l'EA du graphique
- Re-glisser SMC_Universal
- Attendre 30 secondes

### Stats ML à 0

**Cause:** Script Python pas lancé ou AWS RDS inaccessible

**Solution:**
```bash
# Relancer sync
python sync_ml_stats_to_mt5.py

# OU
start_ml_sync.bat
```

### Dashboard en double

**Cause:** Script GOM_KOLA_SIDO_Script aussi attaché

**Solution:**
- Garder **uniquement SMC_Universal**
- Supprimer GOM_KOLA_SIDO_Script du graphique

---

## 📞 Support

**Fichiers logs:**
- MT5: Onglet "Experts"
- Python: Console `sync_ml_stats_to_mt5.py`
- Render: https://dashboard.render.com/logs

**Commandes diagnostiques:**
```bash
# Test AWS RDS local (si Python fonctionne)
python test_aws_rds_connection.py

# Vérifier fichiers
sync_all_terminals.bat

# Tests Render
test_render.bat
```

---

**Version:** 1.0.0  
**Auteur:** TradBOT Team  
**Date:** 2026-05-16 01:20
