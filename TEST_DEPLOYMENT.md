# Déploiement de Test - Checklist Détaillée

Date: 2026-05-17
Objectif: Vérifier que SMC_Universal fonctionne en conditions réelles

---

## PHASE 1: PRÉPARATION (avant 10 minutes)

### ✅ Compilation du robot

```
1. Ouvrir MetaTerminal 5
2. Appuyer sur F4 (MetaEditor)
3. File → Open → D:\Dev\TradBOT\SMC_Universal.mq5
4. Appuyer sur F7 (Compile)
5. Vérifier: "Compilation successful" (0 errors, 0 warnings)
```

**Validation**: Si vous voyez "0 errors, 0 warnings", passez à l'étape suivante.

---

### ✅ Démarrage du serveur IA

```bash
# Terminal/CMD:
cd D:\Dev\TradBOT\python
python ai_server.py
```

**Validation attendue**:
```
Uvicorn running on http://127.0.0.1:8000
Press CTRL+C to quit
```

**Endpoints à tester** (dans un autre terminal):
```bash
curl http://localhost:8000/health
curl http://localhost:8000/docs
```

---

### ✅ Chargement du robot dans MT5

```
1. MetaTerminal 5 → Navigateur (Experts)
2. Sélectionner SMC_Universal
3. Double-cliquer ou drag onto chart
4. Confirmer les inputs
5. Click OK
```

**Validation**: Robot doit charger sans erreur dans le Journal

---

## PHASE 2: VÉRIFICATION INITIALE (0-30 secondes après chargement)

Ouvrir **Journal tab** (View → Toolbox → Experts)

Vous devriez voir:

```
✅ SMC_Universal: OnInit() - Robot initialized
✅ ML continuous training démarré/relancé.
🟢 GOM_SIDO UNIFIED - Score: 0.825
???? IA: premier sync /decision (démarrage EA)…
```

**Checklist**:
- [ ] Pas d'erreur dans le Journal
- [ ] Message "ML continuous training" visible
- [ ] Pas de "Cannot connect to server"

---

## PHASE 3: VÉRIFICATION DU DASHBOARD (30-60 secondes)

Regarder le **chart MT5**. Vous devriez voir:

### **Tableau de Bord Gauche (Bottom-Left)**
```
┌────────────────────────────────┐
│ GOM_SIDO UNIFIED - Score: 0.825│
├────────────────────────────────┤
│ M1  │ M5  │ H1  │ IA%  │VERDICT│
│ 🟢  │ 🟢  │ 🟢  │ 87%  │PERFECT│
│ BUY │ BUY │ BUY │      │ BUY  │
└────────────────────────────────┘
```

### **Tableau de Bord Droit (Bottom-Right, 200px from edge)**
```
⚙️ DÉCISION FINALE
🚀 PERFECT BUY
Score: 0.825 | Align: 3/3
M1:↑ M5:↑ H1:↑
IA: BUY (87%)
RSI:65.2 ATR:12.5
OB: Waiting...
Positions: 0 | Price: 10346.82
```

### **Lignes d'Entry (sur le chart)**
- 3 lignes horizontales vertes (M1/M5/H1 EMA Fast)
- Marquent les niveaux d'entrée pour les ordres limit

### **Métriques ML (Top-Left)**
```
ML (Boom/Crash, Boom 1000 Index): Accuracy: 87% | Model: XGBoost_v2.1
| Samples: 2,847 | Status: Active | Feedback: 156W/89L | Canal: OK
```

**Checklist**:
- [ ] Tableau gauche visible et complet
- [ ] Tableau droit visible et complet
- [ ] 3 lignes d'entry visibles
- [ ] Métriques ML affichées
- [ ] Aucun chevauchement (overlap)

---

## PHASE 4: ATTENTE DE SIGNAL (1-15 minutes)

Monitorer le chart pour:

**Rectangle OB+CHOCH** (Blue = Bullish, Red = Bearish)
- Doit aparaître quand le pattern OB+CHOCH est détecté
- Rectangle montre la zone Order Block

**Journal logs attendus**:
```
✅ OB+CHOCH Detected: Bullish
✅ Confirming pattern...
```

**Si rien ne se passe**:
- Attendre jusqu'à 15 minutes (pattern ne peut pas être garanti chaque bar)
- Essayer timeframe M1 (plus de signaux)
- Essayer symbole différent (Volatility 75, 100)

**Checklist**:
- [ ] Au moins 1 rectangle OB visible
- [ ] Message "OB+CHOCH Detected" dans Journal

---

## PHASE 5: PLACEMENT DE L'ORDRE LIMIT (quand OB+CHOCH)

Une fois que OB+CHOCH est détecté ET que le verdict est GOOD/PERFECT:

**Journal logs attendus**:
```
✅ LIMIT BUY Order Placed | Level: 10362.50
   SL: 10340.00
   TP1: 10370.00
   TP2: 10377.50
   TP3: 10385.00
```

**Sur le chart**:
- Ligne horizontale au niveau d'entry (EMA M1)
- Rectangle OB surligné
- Attendu: Prix touche le niveau et l'ordre se remplit

**Checklist**:
- [ ] "Order Placed" message visible
- [ ] Prix d'entry, SL, TP1/TP2/TP3 affichés
- [ ] Attendre que le prix atteigne le niveau

---

## PHASE 6: EXÉCUTION (prix touche entry)

**Journal logs attendus**:
```
✅ Order Filled: BUY 0.2 @ 10362.50
✅ Position Opened: Ticket 123456789
```

**Sur le chart**:
- Position line à l'entry price
- Ligne SL visible en rouge en dessous
- Lignes TP visibles en vert en dessus

**Checklist**:
- [ ] "Order Filled" message
- [ ] Ticket number visible
- [ ] SL et TP lines visibles

---

## PHASE 7: GESTION DE POSITION (après entry)

**Cibles attendues**:

```
TP1 Hit:
✅ TP1 Target Hit: +7.50 pips
   Close 33% (0.067 lot)
   Remaining: 0.133 lot

TP2 Hit:
✅ TP2 Target Hit: +15.00 pips
   Close 33% (0.067 lot)
   Remaining: 0.066 lot

TP3 Hit:
✅ TP3 Target Hit: +22.50 pips
   Close 100% (0.066 lot)
   Position Closed: Profit +45.67$
```

**Checklist**:
- [ ] TP1 partiel close visible
- [ ] TP2 partiel close visible
- [ ] TP3 close final visible
- [ ] Profit/Perte enregistré

---

## PHASE 8: FEEDBACK ML (après trade fermé)

**Journal logs attendus** (10-15 minutes après close):
```
?? ENVOI FEEDBACK IA - URL1: http://127.0.0.1:8000/trades/feedback
?? ENVOI FEEDBACK IA - Données: symbol=Boom 1000 Index profit=45.67 ai_conf=0.87
? FEEDBACK IA ENVOYÉ: Boom 1000 Index BUY Profit: 45.67 IA Conf: 0.87
```

**Validation serveur** (dans le terminal serveur):
```
POST /trades/feedback - 200 OK
```

**Checklist**:
- [ ] "FEEDBACK IA ENVOYÉ" visible dans Journal
- [ ] Serveur reçoit HTTP 200
- [ ] Pas d'erreur réseau

---

## PHASE 9: MISE À JOUR MÉTRIQUES ML

**Journal logs attendus** (tous les 5 minutes):
```
✅ ML continuous training vérifié - Statut: RUNNING
GET /ml/metrics → Accuracy: 87.2% (was 87.1%)
```

**Sur le chart (Métriques ML)**:
Avant le trade:
```
Samples: 2,847 | Feedback: 156W/89L
```

Après le trade:
```
Samples: 2,848 | Feedback: 157W/89L
```

**Checklist**:
- [ ] Nombre de samples augmente
- [ ] W/L count augmente
- [ ] Accuracy reste stable ou améliore

---

## RÉSUMÉ: TEST 1 HEURE = SUCCÈS SI

- ✅ Code compile: 0 errors, 0 warnings
- ✅ Serveur démarre: http://127.0.0.1:8000 accessible
- ✅ EA démarre: OnInit complète sans erreur
- ✅ ML training démarre: "démarré/relancé" visible
- ✅ Tableaux de bord: Deux dashboards visibles et lisibles
- ✅ Lignes d'entry: M1/M5/H1 EMA visibles
- ✅ Métriques ML: Affichées et mises à jour
- ✅ OB+CHOCH: Au moins 1 pattern détecté
- ✅ Ordre limit: Placement validé
- ✅ Position: Au moins 1 trade exécuté
- ✅ TP management: Closes partiels visibles
- ✅ Feedback: Envoyé au serveur avec 200 OK
- ✅ Métriques: Samples et accuracy mises à jour
- ✅ Aucun crash: Robot stable 1 heure

**Si tous les ✅**: Prêt pour trading LIVE
**Si des ❌**: Consulter LIVE_TEST_GUIDE.md pour solutions

---

## CONTACTS D'ERREUR COURANTS

| Problème | Solution |
|----------|----------|
| Compilation errors | Voir SMC_Universal.mq5 ligne mentionnée, corriger typo |
| "Cannot connect to server" | Vérifier ai_server.py running, check firewall localhost |
| "No OB+CHOCH detected" | Attendre, essayer M1 timeframe, symbole différent |
| "Limit order not placed" | Vérifier verdict >= GOOD (0.35), M1/M5 align, H1 confirm |
| "Dashboard overlap" | Déjà fixé, positions 10px left et 200px right |
| "Feedback not sending" | Vérifier serveur /trades/feedback endpoint, logs |

---

Generated: 2026-05-17
Status: Ready for deployment
