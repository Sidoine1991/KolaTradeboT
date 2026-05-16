# Checklist - Tests Finaux AWS RDS Integration

**Objectif:** Vérifier que le système complet fonctionne end-to-end

---

## Phase 1: Préparation

### ✓ Vérifier Configuration

- [ ] `.env` contient `USE_SUPABASE=false`
- [ ] `.env` contient `AWS_RDS_HOST=trading-db.cq9suk2wcwxh...`
- [ ] `.env` contient `AWS_RDS_USER=dbadmin`
- [ ] `.env` contient `AWS_RDS_PASSWORD=REMOVED_DB_PASSWORD`
- [ ] Aucune erreur sur https://kolatradebot-7ofl.onrender.com/health

### ✓ Vérifier Fichiers Locaux

- [ ] `D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh` existe
- [ ] `D:\Dev\TradBOT\SMC_Universal.mq5` existe
- [ ] `D:\Dev\TradBOT\sync_ml_stats_to_mt5.py` existe
- [ ] `D:\Dev\TradBOT\aws_rds_helper.py` existe

---

## Phase 2: Compilation Terminal 1

### ✓ MetaEditor Terminal 1

1. [ ] Ouvrir MetaEditor
2. [ ] File → Open: `C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts\SMC_Universal.mq5`
3. [ ] Appuyer F7 (Compile)
4. [ ] ✓ Vérifier: `0 errors, 0 warnings`
5. [ ] Vérifier fichier `.ex5` créé: `...Terminal.../MQL5/Experts/SMC_Universal.ex5`

---

## Phase 3: Compilation Terminal 2

### ✓ MetaEditor Terminal 2

1. [ ] Ouvrir MetaEditor pour Terminal 2
2. [ ] File → Open: `C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\SMC_Universal.mq5`
3. [ ] Appuyer F7 (Compile)
4. [ ] ✓ Vérifier: `0 errors, 0 warnings`
5. [ ] Vérifier fichier `.ex5` créé: `...Terminal.../MQL5/Experts/SMC_Universal.ex5`

---

## Phase 4: Lancer Synchronisation ML

### ✓ Démarrer sync_ml_stats_to_mt5.py

1. [ ] Ouvrir PowerShell
2. [ ] Navigate: `cd D:\Dev\TradBOT`
3. [ ] Lancer: `python sync_ml_stats_to_mt5.py`
4. [ ] ✓ Vérifier logs toutes les 30s:
   ```
   [HH:MM:SS] Synchronisation stats ML...
     Prédictions: XXX (précision: XX.X%)
     Trades: XX (win rate: XX.X%)
     Profit moyen: $XX.XX
     Modèles chargés: XX
     ✅ Synchronisation terminée
   ```
5. [ ] Laisser tourner en arrière-plan

---

## Phase 5: Attacher Robot Terminal 1

### ✓ Attacher SMC_Universal

1. [ ] Ouvrir MT5 Terminal 1
2. [ ] Navigateur (Ctrl+N) → Expert Advisors → SMC_Universal
3. [ ] Glisser sur un graphique (ex: Boom 1000 Index, M5)
4. [ ] Onglet "Inputs":
   - [ ] **DASHBOARD ML AWS RDS:**
     - UseEnhancedDashboard = **true** ✓
     - DashboardMLPosX = 10
     - DashboardMLPosY = 30
     - DashboardMLAnchorTop = true
     - DashboardMLCellWidth = 100
     - DashboardMLCellHeight = 25
     - DashboardMLFontSize = 8
   - [ ] **SCANNER MULTI-SYMBOLES:**
     - EnableOpportunityScanner = **false** ⚠️
     - ScannerShowPanel = **false** ⚠️
5. [ ] Cliquer OK
6. [ ] ✓ EA s'attache sans erreur

---

## Phase 6: Vérifier Dashboard Visible

### ✓ Regarder le Dashboard

1. [ ] Attendre 30-60 secondes (1ère synchro)
2. [ ] Chercher en haut à gauche du graphique
3. [ ] Vérifier le format du dashboard:

   **Si pause UTC (heure actuelle 00h-06h UTC):**
   ```
   ┌────────────────────────────────┐
   │ ⏸️ UTC PAUSE  📊 POS:0  💵 -20$ │
   │ ⏰ Hors fenêtre UTC  ↻ ATTENTE │
   │ 🎯 68.2%   📈 64.0%   🧠 x36   │
   │ 🔮 15s     📊 1247    💼 89    │
   └────────────────────────────────┘
   ```

   **Si fenêtre UTC ouverte (06h-23h UTC):**
   ```
   ┌────────────────────────────────┐
   │ 🤖 ACTIVE  📊 POS:0  💵 +2.45$ │
   │ 🎯 68.2%   📈 64.0%   🧠 x36   │
   │ 🔮 15s     📊 1247    💼 89    │
   └────────────────────────────────┘
   ```

4. [ ] Dashboard visible: ✓ PASS
5. [ ] Dashboard lisible: ✓ PASS

---

## Phase 7: Vérifier Valeurs ML Non Nulles

### ✓ Dashboard Affiche Données

Vérifier que les valeurs NE SONT PAS 0:

- [ ] 🎯 **XX.X%** - ML accuracy (précision)
- [ ] 📈 **XX.X%** - Win rate
- [ ] 🧠 **xXX** - Modèles chargés (doit être > 0)
- [ ] 📊 **XXXX** - Total prédictions (doit être > 0)
- [ ] 💼 **XX** - Total trades (peut être 0 au départ)

**Si toutes ces valeurs > 0:** ✓ PASS

**Si valeurs = 0:**
- [ ] Vérifier que sync_ml_stats_to_mt5.py tourne
- [ ] Vérifier logs PowerShell pour erreurs
- [ ] Vérifier GlobalVariables dans MT5 (Tools → Options → Global Variables)

---

## Phase 8: Tester Écriture AWS RDS

### ✓ Envoyer Test Decision

1. [ ] Ouvrir PowerShell (nouveau terminal)
2. [ ] Exécuter:
   ```powershell
   $body = @{
       symbol = "TEST_EURUSD"
       bid = 1.0850
       ask = 1.0852
       atr = 0.0015
       rsi = 55.0
       ema_fast_m1 = 1.0851
       ema_slow_m1 = 1.0849
       ema_fast_m5 = 1.0850
       ema_slow_m5 = 1.0848
       ema_fast_h1 = 1.0845
       ema_slow_h1 = 1.0840
       dir_rule = 1
       timeframe = "M1"
       volatility_compression = 1.0
       price_acceleration = 0.0001
       volume_spike = 0
       spike_probability = 0.0
   } | ConvertTo-Json

   Invoke-RestMethod -Uri "https://kolatradebot-7ofl.onrender.com/decision" `
       -Method POST `
       -Body $body `
       -ContentType "application/json"
   ```

3. [ ] ✓ Vérifier réponse JSON:
   ```json
   {
     "action": "hold",
     "confidence": 0.58,
     "reason": "Analyse technique...",
     ...
   }
   ```

---

## Phase 9: Vérifier Logs Render

### ✓ Vérifier AWS RDS Écrit

1. [ ] Aller sur: https://dashboard.render.com/web/srv-cvs93ddumphs739q5hd0/logs
2. [ ] Chercher dans les logs (dernières 5 minutes):
   ```
   ✅ AWS RDS PostgreSQL helper chargé
   ✅ Prediction enregistrée dans AWS RDS
   ```

3. [ ] ✓ Vérifier qu'il N'Y A PAS:
   ```
   ❌ Supabase
   ❌ Table 'supabase'
   ❌ HTTP request to supabase.co
   ```

4. [ ] ✓ Si logs AWS RDS: PASS

---

## Phase 10: Vérifier Logs sync_ml_stats

### ✓ Vérifier Synchronisation

1. [ ] Regarder PowerShell (sync_ml_stats_to_mt5.py)
2. [ ] Vérifier logs toutes les 30s:
   ```
   [HH:MM:SS] Synchronisation stats ML...
     Prédictions: XXX (précision: XX.X%)  ← Doit inclure le test
     Trades: XX (win rate: XX.X%)
     Profit moyen: $XX.XX
     Modèles chargés: XX
     ✅ Synchronisation terminée
   ```

3. [ ] ✓ Total prédictions augmenté: PASS

---

## Phase 11: Vérifier Dashboard Mis à Jour

### ✓ Vérifier Refresh Dashboard

1. [ ] Attendre 30-60 secondes
2. [ ] Regarder le dashboard
3. [ ] Vérifier que la ligne "🔮" affiche une heure plus récente
4. [ ] Vérifier que "📊 XXXX" (total prédictions) a augmenté

**Avant test:** 📊 1247  
**Après test (30-60s):** 📊 1248 ← Incrément de 1

- [ ] Dashboard rafraîchi: ✓ PASS

---

## Phase 12: Tester Pause UTC

### ✓ Vérifier Affichage Pause UTC

**Si heure actuelle entre 00h-06h UTC (01h-07h locale):**

1. [ ] Dashboard doit afficher:
   ```
   ⏸️ UTC PAUSE
   ⏰ Hors fenêtre UTC
   ```

2. [ ] Vérifier que robot NE trade PAS
3. [ ] [ ] Pause UTC affichée: ✓ PASS

**Si heure actuelle entre 06h-23h UTC:**

1. [ ] Dashboard doit afficher:
   ```
   🤖 ACTIVE  (ou ⏸️ PAUSE si profit limit atteint)
   ```

2. [ ] Pas de ligne "Hors fenêtre UTC"
3. [ ] [ ] Fenêtre UTC active: ✓ PASS

---

## Phase 13: Vérifier Aucune Erreur MT5

### ✓ Onglet Experts MT5

1. [ ] Ouvrir MT5 → Onglet "Experts"
2. [ ] Chercher erreurs:
   - [ ] ✓ PAS d'erreur "GOM_DrawEnhancedDashboardV3"
   - [ ] ✓ PAS d'erreur "undeclared identifier"
   - [ ] ✓ PAS d'erreur "file not found"

3. [ ] Normal (ne pas alarmer):
   ```
   ⏸ MODE ARRÊT AUTO UTC - Trading suspendu (heure UTC=XX)
   ```

4. [ ] Aucune erreur dashboard: ✓ PASS

---

## Phase 14: Tester Terminal 2

### ✓ Répéter sur Terminal 2

1. [ ] Ouvrir MT5 Terminal 2
2. [ ] Attacher SMC_Universal au graphique (même config)
3. [ ] Vérifier dashboard visible
4. [ ] Vérifier mêmes données affichées
5. [ ] Terminal 2 synchronisé: ✓ PASS

---

## Résumé Final

### Tous les Tests

- [ ] Phase 1: Préparation ✓
- [ ] Phase 2: Compilation Terminal 1 ✓
- [ ] Phase 3: Compilation Terminal 2 ✓
- [ ] Phase 4: Sync ML lancé ✓
- [ ] Phase 5: Robot attaché T1 ✓
- [ ] Phase 6: Dashboard visible ✓
- [ ] Phase 7: Valeurs ML non nulles ✓
- [ ] Phase 8: Test decision sent ✓
- [ ] Phase 9: Render logs show AWS RDS ✓
- [ ] Phase 10: Sync logs show update ✓
- [ ] Phase 11: Dashboard rafraîchi ✓
- [ ] Phase 12: Pause UTC affichée ✓
- [ ] Phase 13: Aucune erreur MT5 ✓
- [ ] Phase 14: Terminal 2 sync ✓

---

## 🎉 Résultat

**Si tous cochés:** ✅ **SYSTÈME OPÉRATIONNEL COMPLET!**

Le système AWS RDS fonctionne end-to-end:
1. ✓ ai_server écrit dans AWS RDS Render 24/7
2. ✓ sync_ml_stats lit depuis AWS RDS toutes les 30s
3. ✓ Dashboard affiche les données en temps réel
4. ✓ Zéro dépendance Supabase
5. ✓ Robot 100% autonome sur cloud

---

## 🐛 Dépannage

### Si dashboard ne s'affiche pas:

```
1. Vérifier: UseEnhancedDashboard = true ✓
2. Relancer: python sync_ml_stats_to_mt5.py ✓
3. Vérifier: MT5 → Experts tab (aucune erreur) ✓
4. Sauver EA du graphique et le réattacher ✓
```

### Si valeurs ML sont 0:

```
1. Vérifier sync_ml_stats_to_mt5.py tourne ✓
2. Vérifier logs PowerShell ✓
3. Vérifier Render logs pour erreurs AWS RDS ✓
4. Relancer: python sync_ml_stats_to_mt5.py ✓
```

### Si erreur "file not found":

```
1. Copier GOM_Enhanced_Dashboard.mqh:
   C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Experts\
2. Recompiler SMC_Universal ✓
3. Réattacher EA ✓
```

---

**Date:** 2026-05-16  
**Version:** 1.0  
**Auteur:** TradBOT Migration Team
