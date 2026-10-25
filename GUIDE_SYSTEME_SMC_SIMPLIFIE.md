# 🎯 Guide du Système de Trading SMC Simplifié

## Vue d'ensemble

Système de trading automatique basé sur les **Smart Money Concepts (SMC)** :
- ✅ **Support/Résistance confirmés** (multiple touches)
- ✅ **Zones d'Imbalance (IB)** - Fair Value Gaps
- ✅ **Order Blocks (OB)** institutionnels
- ✅ **SL/TP intelligemment calculés** (ratio 1:2 minimum)

---

## 📋 Fonctionnalités

### 1. **Détection Support/Résistance**

Le système détecte automatiquement les niveaux confirmés :
- **Swing Highs** (résistances)
- **Swing Lows** (supports)
- **Minimum 2 touches** pour confirmer un niveau
- **Force calculée** basée sur le nombre de touches

### 2. **Détection Imbalance (IB)**

Deux types de zones d'imbalance :

**IB BUY (Gap Haussier)** :
- 3 bougies consécutives
- Bougie 1 bas < Bougie 3 bas
- Gap vers le haut
- Signal d'achat potentiel

**IB SELL (Gap Baissier)** :
- 3 bougies consécutives
- Bougie 1 haut > Bougie 3 haut
- Gap vers le bas
- Signal de vente potentiel

### 3. **Détection Order Blocks (OB)**

Blocs d'ordres institutionnels :

**OB BUY** :
- Série de bougies baissières
- Suivie d'une bougie haussière
- Zone devient support institutionnel

**OB SELL** :
- Série de bougies haussières
- Suivie d'une bougie baissière
- Zone devient résistance institutionnelle

### 4. **Calcul SL/TP Intelligent**

Le système calcule automatiquement :
- **SL (Stop Loss)** : 
  - Soit sous/au-dessus du key level détecté
  - Soit 2x ATR du prix d'entrée
- **TP (Take Profit)** :
  - Ratio minimum 1:2 (gain 2x le risque)
  - 4x ATR pour maximum de profit

---

## 🚀 Utilisation

### Option 1 : Python (Standalone)

```bash
python srmc_trading_system.py
```

**Fonctionnalités** :
- Détection automatique sur tous les symboles Boom/Crash
- Signaux générés en continu
- Execution automatique avec SL/TP

### Option 2 : Intégration MT5 (AngelOfSpike)

Le fichier `SimplifiedSMTrading.mq5` peut être inclus dans votre EA :

```cpp
#include "SimplifiedSMTrading.mq5"

// Dans OnTick()
if(InpUseSMCTrading) {
    SMCSignal signal = GenerateSMCSignals(_Symbol);
    
    if(signal.confidence >= 0.65 && signal.risk_reward >= 2.0) {
        // Exécuter le trade
        ExecuteTrade(signal);
    }
}
```

---

## ⚙️ Paramètres

### Paramètres S/R
```
InpSRTolerance = 0.001    // Tolérance 0.1% pour fusion niveaux
InpMinSRTouches = 2       // Minimum 2 touches pour confirmer
InpMinStrength = 0.6      // Force minimum 60%
```

### Paramètres Imbalance
```
Min FVG Size = 0.05%     // Taille minimale zone d'imbalance
```

### Paramètres Order Blocks
```
Min OB Bodies = 3         // Minimum 3 bougies pour OB
```

### Paramètres SL/TP
```
InpSLATRMultiplier = 2.0  // SL à 2x ATR
InpTPATRMultiplier = 4.0  // TP à 4x ATR (ratio 1:2)
InpMinRRRatio = 2.0       // Risk/Reward minimum 1:2
```

---

## 📊 Exemples de Signaux

### Signal BUY - Support Confirmé
```
Niveau: 500.25
Touches: 3
Force: 85%
Distance: 0.15%
Action: BUY
Entry: 500.30
SL: 499.80 (0.5)
TP: 502.30 (2.0)
R:R: 1:4
```

### Signal SELL - Order Block
```
OB Type: OB_SELL
Zone: 501.00 - 501.50
Formed: 2h ago
Action: SELL
Entry: 501.10
SL: 501.60 (0.5)
TP: 500.10 (1.0)
R:R: 1:2
```

### Signal BUY - Imbalance Zone
```
IB Type: IB_BUY
Zone: 499.50 - 499.70
Formed: 30min ago
Action: BUY
Entry: 499.65
SL: 499.40 (0.25)
TP: 500.15 (0.5)
R:R: 1:2
```

---

## 🔒 Règles de Sécurité

1. **Maximum 2 positions simultanées**
2. **Perte journalière max : $10**
3. **Risk/Reward minimum 1:2**
4. **Confiance minimum 65%**
5. **SL toujours défini**

---

## 📈 Résultats Attendus

Avec une stratégie SMC bien implémentée :
- **Win Rate** : 60-70%
- **Risk/Reward** : 1:2 minimum
- **Daily Trades** : 5-10 maximum
- **Drawdown** : < 5%

---

## 🛠️ Debugging

Pour activer les logs détaillés :

```python
# srmc_trading_system.py
logging.basicConfig(level=logging.DEBUG)
```

Pour afficher les niveaux SMC sur le graphique :

```mql5
if(InpDrawSMCLevels) {
    DrawSMCLevels();
}
```

---

## 📝 Notes Importantes

1. **Tolérance S/R** : 0.1% pour éviter les faux niveaux
2. **Force minimum** : 60% pour filtrer les faibles signaux
3. **Ratio R:R** : Toujours 1:2 minimum
4. **Order Blocks** : Plus fiables que les IB
5. **Supports/Résistances** : Plus confirmées = Plus fortes

---

## 🎯 Workflow Recommandé

1. **Scanner quotidien** des niveaux S/R
2. **Identifier** les OB/IB actifs
3. **Attendre** l'approche du prix
4. **Valider** le signal (>65% confiance)
5. **Entrer** avec SL/TP automatiques
6. **Gérer** avec trailing stop si optionnel

---

## ✅ Checklist Avant de Trader

- [ ] Niveau confirmé (2+ touches)
- [ ] Force >= 60%
- [ ] Prix proche (< 0.2%)
- [ ] SL défini intelligemment
- [ ] TP avec ratio 1:2 minimum
- [ ] Confiance >= 65%
- [ ] Pas de position existante
- [ ] Daily loss limit respected

---

**Système Simplifié ✅ - Prêt pour le Trading SMC !**
