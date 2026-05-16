# ✅ CHECKLIST COMPILATION & VÉRIFICATION - Capital 20$

**Date** : 2026-05-15  
**Objectif** : Compiler et vérifier le système avant lancement

---

## 📋 ÉTAPE 1 : VÉRIFICATION FICHIERS (2 min)

### Fichiers Présents ✅

```
✅ D:\Dev\TradBOT\ai_server.py                    (Serveur IA Python)
✅ D:\Dev\TradBOT\SMC_Universal.mq5                (Robot principal MT5)
✅ D:\Dev\TradBOT\GOM_KOLA_SIDO_Script.mq5         (Scanner GOM)
✅ D:\Dev\TradBOT\SMC_OpportunityScanner.mqh       (Include scanner)
✅ D:\Dev\TradBOT\SMC_Universal.ex5                (Déjà compilé ?)
```

### Vérification Rapide Paramètres

**ai_server.py** (ligne 206-207) :
```python
MIN_CONFIDENCE_THRESHOLD = 0.72  # ✅ Doit être 0.72
FORCE_HOLD_THRESHOLD = 0.60      # ✅ Doit être 0.60
```

**SMC_Universal.mq5** (ligne 8586-8589) :
```mql5
input double InpLotSize = 0.01;           // ✅ Doit être 0.01
input int MaxPositionsTerminal = 1;       // ✅ Doit être 1
```

**GOM_KOLA_SIDO_Script.mq5** (ligne 113-117) :
```mql5
input double SpikeAlertMinProbability = 0.62;  // ✅ Doit être 0.62
input bool SpikeModeBypassStrict = false;      // ✅ Doit être false
```

---

## 🔧 ÉTAPE 2 : COMPILATION MQL5 (5 min)

### Option A : Compilation MetaEditor (Recommandé)

1. **Ouvrir MetaEditor MT5** :
   ```
   MT5 → Menu Outils → MetaQuotes Language Editor
   Ou appuyer : F4
   ```

2. **Compiler SMC_Universal.mq5** :
   ```
   - Fichier → Ouvrir → D:\Dev\TradBOT\SMC_Universal.mq5
   - Compiler : F7 ou bouton "Compile"
   - Vérifier résultat :
     ✅ "0 error(s), 0 warning(s)"
     ✅ Fichier .ex5 créé dans même dossier
   ```

3. **Compiler GOM_KOLA_SIDO_Script.mq5** :
   ```
   - Fichier → Ouvrir → D:\Dev\TradBOT\GOM_KOLA_SIDO_Script.mq5
   - Compiler : F7
   - Vérifier :
     ✅ "0 error(s), 0 warning(s)"
     ✅ Fichier .ex5 créé
   ```

### Option B : Compilation Ligne de Commande

**Note** : Nécessite MetaEditor installé et path configuré

```bash
# Trouver le compilateur MT5
# Par défaut : C:\Program Files\MetaTrader 5\metaeditor64.exe

# Compiler SMC_Universal.mq5
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"D:\Dev\TradBOT\SMC_Universal.mq5"

# Compiler GOM_KOLA_SIDO_Script.mq5
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"D:\Dev\TradBOT\GOM_KOLA_SIDO_Script.mq5"
```

### Résultat Attendu

```
D:\Dev\TradBOT\
├── SMC_Universal.mq5           (Source)
├── SMC_Universal.ex5           (✅ Compilé - nouvelle version)
├── GOM_KOLA_SIDO_Script.mq5    (Source)
└── GOM_KOLA_SIDO_Script.ex5    (✅ Compilé - nouvelle version)
```

---

## 🐍 ÉTAPE 3 : TEST SERVEUR IA (3 min)

### Démarrer ai_server.py

```bash
# Dans terminal PowerShell ou CMD
cd D:\Dev\TradBOT
python ai_server.py
```

### Sortie Attendue ✅

```
✅ INFO: MODE SIMPLIFIÉ ACTIVÉ - RoboCop v2 compatible
✅ INFO: Système fallback Qwen disponible
✅ INFO: 🤖 Système d'entraînement continu intégré chargé
✅ INFO: 🎯 Système de recommandation ML chargé avec succès
✅ INFO: 🧠 Système ML chargé avec succès
✅ INFO: Started server process [XXXX]
✅ INFO: Uvicorn running on http://127.0.0.1:8000
```

### Test Endpoints

**Ouvrir navigateur** : http://127.0.0.1:8000/health

```json
✅ Réponse attendue :
{
  "status": "healthy",
  "timestamp": "2026-05-15T...",
  "version": "2.1.0"
}
```

**Test endpoint /decision** :

```bash
# Dans un autre terminal
curl -X POST http://127.0.0.1:8000/decision ^
  -H "Content-Type: application/json" ^
  -d "{\"symbol\":\"Boom 1000 Index\",\"timeframe\":\"M5\",\"timestamp\":\"2026-05-15T14:00:00\"}"
```

```json
✅ Réponse attendue (exemple) :
{
  "action": "HOLD",
  "confidence": 0.65,
  "reason": "Confidence 65% < 72% → HOLD forcé, capital 20$ protégé"
}
```

**Si erreur 422** : Vérifier format timestamp et champs requis

---

## 🔌 ÉTAPE 4 : CONFIGURATION MT5 (5 min)

### 4.1 Autoriser WebRequest

```
1. Ouvrir MT5
2. Menu : Outils → Options
3. Onglet : Expert Advisors
4. Section : "Autoriser WebRequest pour les URL suivantes"
5. Ajouter :
   ✅ http://127.0.0.1:8000
   ✅ https://kolatradebot-7ofl.onrender.com
6. Cliquer : OK
```

### 4.2 Configurer Trading Automatique

```
1. MT5 → Onglet "Boîte à outils" (en bas)
2. Onglet "Expert Advisors" 
3. Vérifier paramètres généraux :
   ✅ "Autoriser le trading automatique" : Coché
   ✅ "Autoriser l'import de DLL" : Décoché (pas nécessaire)
   ✅ "Autoriser les imports depuis des sources externes" : Décoché
```

### 4.3 Vérifier Capital

```
1. MT5 → Boîte à outils → Onglet "Trade"
2. Vérifier ligne "Balance" :
   ✅ Balance = 20.00 USD (ou équivalent)
   ✅ Equity = 20.00 USD
   ✅ Margin Free ≥ 15.00 USD (pour pouvoir trader)
```

---

## 🚀 ÉTAPE 5 : LANCEMENT ROBOT (5 min)

### 5.1 Attacher EA au Graphique

```
1. Ouvrir graphique : Boom 1000 Index
2. Timeframe : M1 ou M5 (recommandé M5)
3. Navigateur (Ctrl+N) → Expert Advisors
4. Glisser-déposer : SMC_Universal.ex5 sur le graphique
```

### 5.2 Vérifier Paramètres Inputs

**Fenêtre qui s'ouvre automatiquement** :

```
PARAMÈTRES CRITIQUES À VÉRIFIER :

✅ Common (Onglet "Commun")
   - "Autoriser le trading automatique" : ✅ Coché
   - "Autoriser l'import de DLL" : ⬜ Décoché

✅ Inputs (Onglet "Paramètres d'entrée")
   
   [SCANNER MULTI-SYMBOLES TEMPS RÉEL]
   ✅ EnableOpportunityScanner = true
   ✅ EnableScannerAutoTrading = true
   ✅ ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,..."
   ✅ ScannerRefreshSeconds = 30
   
   [TRADING AUTOMATIQUE]
   ✅ AutoTradeMaxRiskDollars = 0.20
   ✅ AutoTradeScalpTpPoints = 80
   ✅ AutoTrailingStopPoints = 15
   
   [PARAMÈTRES EA UNIVERSELS]
   ✅ InpLotSize = 0.01
   ✅ MaxPositionsTerminal = 1
   ✅ MaxTotalLossDollars = 3.0
   ✅ DailyProfitTarget = 2.0
   
   [SPIKE PREDICTION]
   ✅ EnableSpikePrediction = true
   ✅ SpikeAlertMinProbability = 0.65
   
   [FERMETURE AUTO SPIKE]
   ✅ EnableAutoClosePositionsOnSpikeCaptured = true
   ✅ GomSpikeCapturedCloseAnyProfit = true
```

### 5.3 Cliquer OK et Vérifier Démarrage

```
✅ Coin supérieur droit du graphique :
   - Icône "😊" (smiley) = EA actif et autorisé
   - Icône "✅" (coche) = Trading automatique activé
   
✅ Journal MT5 (Onglet "Journal" en bas) :
   - "SMC_Universal EA XXXX initialized"
   - "Scanner multi-symboles : ACTIVÉ"
   - "IA serveur : http://127.0.0.1:8000"
   - "Position max : 1"
   - "Lot size : 0.01"
```

---

## 📊 ÉTAPE 6 : VÉRIFICATION PREMIÈRE HEURE (15 min)

### 6.1 Observer Journal MT5

```
✅ Logs attendus toutes les 30 secondes :
   - "Scanner : analyse symbole Boom 1000 Index..."
   - "Scanner : analyse symbole Crash 1000 Index..."
   - "IA Decision : HOLD (confidence 65%) - en attente signal"
   - "GOM Verdict : WAIT - pas de setup valide"
```

### 6.2 Observer Graphique

```
✅ Dashboard GOM visible en bas du graphique :
   - Verdict MTF : BUY/SELL/WAIT
   - Score technique : XX%
   - Niveaux M5/M15/H1 dessinés (lignes vertes/rouges)
   - Spike probability : XX% (si EnableSpikePrediction = true)
```

### 6.3 Premier Trade Attendu

```
🎯 Conditions pour trade :
   1. Scanner détecte opportunité (confiance IA ≥ 72%)
   2. Confluence signaux (MTF + Structure + Spike si Boom/Crash)
   3. Prix proche niveau d'entrée (KOLA/M5)
   4. Pas de position ouverte (MaxPositionsTerminal = 1)
   
⏰ Temps moyen avant premier trade :
   - Mode ultra-conservateur : 30 min à 2 heures
   - Si pas de trade en 4 heures : vérifier que scanner est actif
```

### 6.4 Notification Premier Trade

```
✅ Notification push MT5 (sur mobile si configuré) :
   - "NOUVELLE POSITION : BUY Boom 1000 Index 0.01 lot"
   - "Entry : XXXXX.XX | SL : XXXXX.XX | TP : XXXXX.XX"
   
✅ Journal MT5 :
   - "Position ouverte : #XXXXXX BUY 0.01 Boom 1000 Index"
   - "Entry reason : GOM_PLAN_ARROW + IA confidence 78%"
   - "Risk : 0.20 USD (1% capital)"
```

---

## ⚠️ PROBLÈMES COURANTS & SOLUTIONS

### ❌ Problème : EA ne démarre pas

**Symptômes** :
- Pas d'icône smiley sur le graphique
- Aucun log dans Journal

**Solutions** :
1. Vérifier : AutoTrading activé (bouton vert en haut MT5)
2. Vérifier : "Autoriser trading automatique" coché dans inputs EA
3. Recompiler SMC_Universal.mq5 et réattacher au graphique
4. Redémarrer MT5

---

### ❌ Problème : "WebRequest not allowed"

**Symptômes** :
- Log : "WebRequest error : URL not allowed"
- IA ne répond pas

**Solutions** :
1. MT5 → Outils → Options → Expert Advisors
2. Ajouter URLs autorisées (voir Étape 4.1)
3. Redémarrer EA (retirer et réattacher au graphique)

---

### ❌ Problème : ai_server.py erreur démarrage

**Symptômes** :
- `ModuleNotFoundError: No module named 'fastapi'`
- `uvicorn command not found`

**Solutions** :
```bash
# Installer dépendances manquantes
pip install fastapi uvicorn pydantic pandas numpy requests joblib

# Ou via requirements.txt si disponible
pip install -r requirements.txt
```

---

### ❌ Problème : Pas de trades en 4 heures

**Symptômes** :
- Scanner actif mais "HOLD" ou "WAIT" constant
- Confiance IA toujours < 72%

**Solutions** :
1. **Temporaire** : Réduire légèrement seuils (demo test uniquement)
   ```python
   # ai_server.py ligne 206
   MIN_CONFIDENCE_THRESHOLD = 0.68  # Au lieu de 0.72 (TEST)
   ```
   
2. **Vérifier heures trading** :
   - Éviter heures creuses (nuit Europe/USA)
   - Meilleur : 08:00-17:00 UTC (sessions Londres + NY)

3. **Vérifier symboles scanner** :
   - Ajouter plus de symboles volatils si nécessaire
   - `ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,Volatility 100 Index,EURUSD,GBPUSD,XAUUSD"`

4. **Analyser logs IA** :
   - Terminal ai_server.py : noter les raisons "HOLD"
   - Si "RSI neutre" fréquent → marché range, attendre breakout

---

### ❌ Problème : Compilation erreurs MQL5

**Symptômes** :
- "undeclared identifier"
- "declaration expected"
- "invalid array access"

**Solutions** :
1. Vérifier que **tous les fichiers .mqh** sont présents :
   ```
   ✅ SMC_OpportunityScanner.mqh
   ✅ SMC_AutoTrader.mqh (inclus dans Scanner)
   ```

2. Vérifier encodage fichier :
   - MetaEditor → File → Save As → UTF-8

3. Si erreur persiste :
   - Lire message erreur complet (ligne + colonne)
   - Partager erreur pour aide

---

## ✅ CHECKLIST FINALE

Avant de valider le système opérationnel :

- [ ] ✅ ai_server.py démarré sans erreur
- [ ] ✅ Endpoint /health répond correctement
- [ ] ✅ SMC_Universal.ex5 compilé (0 erreur)
- [ ] ✅ GOM_KOLA_SIDO_Script.ex5 compilé (0 erreur)
- [ ] ✅ WebRequest autorisés dans MT5
- [ ] ✅ EA attaché au graphique Boom 1000 Index
- [ ] ✅ Icône smiley visible (EA actif)
- [ ] ✅ AutoTrading activé (bouton vert)
- [ ] ✅ Journal MT5 : "Scanner : ACTIVÉ"
- [ ] ✅ Capital = 20.00 USD
- [ ] ✅ Paramètres inputs vérifiés (lot 0.01, positions 1)
- [ ] ✅ Dashboard GOM visible sur graphique
- [ ] ✅ Notifications push configurées (optionnel)

---

## 🎯 STATUT SYSTÈME

```
╔═══════════════════════════════════════════╗
║  🎉 SYSTÈME PRÊT À TRADER                 ║
║                                           ║
║  ✅ Fichiers compilés                     ║
║  ✅ Serveur IA actif                      ║
║  ✅ MT5 configuré                         ║
║  ✅ EA démarré                            ║
║                                           ║
║  🎯 Attente premier signal...             ║
║     Patience = Discipline = Profit        ║
╚═══════════════════════════════════════════╝
```

**Tout est prêt ! Le robot va maintenant scanner et trader automatiquement selon les règles ultra-conservatrices optimisées pour votre capital 20$.**

**Bon trading ! 🚀📈**

---

**Version** : 1.0  
**Dernière mise à jour** : 2026-05-15 15:00
