# ⚡ ACTION IMMÉDIATE - 4 ÉTAPES

## ÉTAPE 1: COMPILER (2 minutes)

### Dans MetaTrader 5:

1. **Ouvre MetaTrader 5** (si pas ouvert)

2. **File** → **Open Data Folder**

3. Navigue vers: **MQL5\Experts**

4. **Cherche:** `Divergence_Robot_With_GOM.mq5`

5. **Double-clique** dessus (l'éditeur MQL s'ouvre)

6. **Appuie F7** (compile)

7. **Regarde** en bas de l'écran → onglet **"Output"**

### ✅ SUCCÈS si tu vois:
```
Divergence_Robot_With_GOM.mq5 EURUSD,H1: 0 errors, 0 warnings
```

### ❌ SI ERREURS:
- Copy-paste le message d'erreur
- Envoie-le moi

---

## ÉTAPE 2: ATTACHE AU GRAPHIQUE (1 minute)

### Dans MetaTrader 5:

1. **Ouvre un graphique:** 
   - Symbol: **EURUSD**
   - Timeframe: **H1**

2. **Right-click** sur le graphique

3. **Expert Advisors** → **Divergence_Robot_With_GOM**

4. **Double-click** → "Properties" dialog s'ouvre

5. **IMPÉRATIF - Vérifie ces inputs sont à TRUE:**
   ```
   ☑ EnableAutoTrading = true
   ☑ EnableGOMEntryLevels = true
   ☑ EnableOrderBlockDetection = true
   ☑ EnableSIDO = true
   ```

6. **Clique OK**

### ✅ SUCCÈS si:
- Chart title montre: `Expert Advisors: Divergence_Robot_With_GOM`
- Le robot s'attache sans erreur

---

## ÉTAPE 3: VÉRIFIES LES LOGS (30 secondes)

### Dans MetaTrader 5:

1. **View** → **Experts** (ou **Alt+L**)

2. **Regarde** l'onglet "Experts" tab

3. **Attends 10 secondes**

4. **Tu DOIS voir:**
   ```
   [INIT] Divergence Robot initialized on EURUSD
      Timeframe: H1
      Magic: 123456
      Auto Trading: 1
   ```

### ✅ SUCCÈS si tu vois ce message

### ❌ SI RIEN N'APPARAÎT:
1. Detach robot (right-click → remove)
2. Reattach
3. Attends 30 secondes
4. Refresh chart (F5)

---

## ÉTAPE 4: CAPTURE D'ÉCRAN

**Prends une capture d'écran qui montre:**
1. Le graphique EURUSD H1
2. Le dashboard (texte en haut à gauche du graphique)
3. Les logs Experts tab avec le message `[INIT]`

---

## 📋 CHECKLIST - Fais TOUTES les 4 étapes

- [ ] Étape 1: Compilé (0 errors, 0 warnings)
- [ ] Étape 2: Robot attaché au graphique H1
- [ ] Étape 3: Message `[INIT]` vu dans les logs
- [ ] Étape 4: Capture d'écran prise

---

## 🎯 APRÈS THESE ÉTAPES

Une fois que tu as confirmé les 4 étapes:

1. **Le robot** scanne automatiquement pour des **signaux divergence**
2. **Le dashboard** se met à jour en temps réel
3. **Les dessins** (GOM levels, Order Blocks) commencent à apparaître
4. **Quand un signal** est détecté → **Le robot trade automatiquement**

---

## ⏱️ TIMELINE ATTENDU

- **Minutes 0-5:** Robot initialise
- **Minutes 5-30:** Premiers dessins GOM apparaissent
- **1-24 heures:** Premier signal divergence (dépend du marché)
- **Quand signal:** Trade automatique exécuté

---

## 💬 RAPPORTE-MOI:

Après avoir fait les 4 étapes, dis-moi:

1. ✅ Compilation: combien d'errors/warnings?
2. ✅ Robot attaché: oui/non?
3. ✅ Message [INIT] visible: oui/non?
4. ✅ Capture d'écran: attachée?

**FAIS-LE MAINTENANT!** ⚡

