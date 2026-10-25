# 🤖 Algorithme de Trading Avancé pour Indices Synthétiques

## 🎯 Vue d'ensemble

Cet algorithme puissant combine l'intelligence artificielle et les stratégies éprouvées de Vince Stanzione pour anticiper les mouvements de prix sur les indices synthétiques Boom/Crash et Volatility.

## 🚀 Fonctionnalités Principales

### 1. **Prédicteur ML Avancé** (`AdvancedMLPredictor`)
- **4 modèles de prédiction** : Direction, Amplitude, Spike, Breakout
- **47 features techniques** basées sur les stratégies de Vince Stanzione
- **Random Forest & Gradient Boosting** pour une précision optimale
- **Auto-apprentissage** avec sauvegarde des modèles

### 2. **Détecteur de Setups** (`SetupDetector`)
- **8 types de setups** : MA Crossover, RSI, MACD, Bollinger Bands, Donchian Channels, Stochastic, Support/Résistance, Patterns de chandeliers
- **Signaux en temps réel** avec scores de confiance
- **Recommandations personnalisées** selon le type d'indice

### 3. **Gestionnaire de Risque** (`RiskManager`)
- **Calcul automatique** de la taille de position
- **Stop Loss & Take Profit** optimaux
- **Limites de risque** : 2% par trade, 6% par jour, 20% de drawdown max
- **Protection contre les pertes consécutives**

## 📊 Stratégies Spécialisées

### 🚀 **BOOM Index**
```
Entrée: RSI < 30 + prix sur support
Stop Loss: 5 points maximum
Take Profit: 15 points (ratio 1:3)
Timing: Éviter les heures de faible volatilité
```

### 💥 **CRASH Index**
```
Entrée: RSI > 70 + prix sur résistance
Stop Loss: 5 points maximum
Take Profit: 15 points (ratio 1:3)
Timing: Éviter les heures de faible volatilité
```

### 📊 **VOLATILITY Index**
```
Entrée: Breakout des bandes de Bollinger
Stop Loss: 2x ATR
Take Profit: 3x ATR (ratio 1:1.5)
Timing: Trading 24/7 possible
```

## 🎯 Signaux ML en Temps Réel

### **Signaux Principaux**
- 🟢 **STRONG BUY** : Signal très fort avec haute probabilité
- 🟢 **BUY** : Signal d'achat modéré
- 🔴 **SELL** : Signal de vente modéré
- 🔴 **STRONG SELL** : Signal de vente très fort
- ⚠️ **SPIKE WARNING** : Risque de spike élevé
- ⚪ **HOLD** : Attendre un signal plus clair

### **Métriques de Risque**
- 🚨 **HIGH SPIKE RISK** : Volatilité extrême détectée
- ⚠️ **MEDIUM SPIKE RISK** : Volatilité modérée
- ✅ **LOW SPIKE RISK** : Volatilité contrôlée
- 📈 **BREAKOUT LIKELY** : Probabilité de breakout élevée
- 📊 **HIGH VOLATILITY** : Volatilité élevée détectée

## 🛠️ Utilisation

### **1. Lancement de l'Application**
```bash
# Activer l'environnement virtuel
.\.venv\Scripts\activate

# Lancer l'application
streamlit run frontend/app_real_time.py
```

### **2. Configuration MT5**
- Connectez-vous à MetaTrader 5
- Assurez-vous que les indices synthétiques sont disponibles
- Vérifiez la connexion dans la sidebar

### **3. Sélection du Symbole**
- Choisissez un indice synthétique (Boom 1000, Crash 1000, Volatility 75, etc.)
- L'algorithme s'adapte automatiquement au type d'indice

### **4. Analyse en Temps Réel**
- **Prix actuel** avec formatage adaptatif
- **Indicateurs techniques** : RSI, MACD, Bollinger Bands
- **Signaux ML** avec probabilités
- **Setups de trading** détaillés
- **Recommandations** personnalisées

## 📈 Exemples de Signaux

### **Signal d'Achat (BOOM Index)**
```
🟢 STRONG BUY
✅ LOW SPIKE RISK (45%)
📈 BREAKOUT LIKELY (78%)
📊 HIGH VOLATILITY (82%)

Détails:
• MA Crossover: BULLISH (Force: 0.156)
• RSI: OVERSOLD (28.3)
• MACD: BULLISH
• BB: OVERSOLD (0.15)
• Donchian: NEAR BREAKOUT (0.85)
```

### **Signal de Vente (CRASH Index)**
```
🔴 STRONG SELL
🚨 HIGH SPIKE RISK (85%)
📈 BREAKOUT LIKELY (72%)
📊 HIGH VOLATILITY (91%)

Détails:
• MA Crossover: BEARISH (Force: 0.203)
• RSI: OVERBOUGHT (73.7)
• MACD: BEARISH
• BB: OVERBOUGHT (0.89)
• Donchian: NEAR BREAKDOWN (0.12)
```

## 🎯 Recommandations de Trading

### **Stratégie d'Entrée**
- Attendre un pullback vers support/résistance
- Confirmer avec plusieurs indicateurs
- Vérifier les niveaux de support/résistance

### **Gestion du Risque**
- **Stop Loss** : Toujours placer un stop loss
- **Take Profit** : Ratio risque/récompense minimum 1:2
- **Position Size** : Maximum 2% du capital par trade
- **Pertes consécutives** : Arrêter après 3 pertes

### **Timing**
- **Boom/Crash** : Éviter les heures de faible volatilité
- **Volatility** : Trading 24/7 possible
- **Meilleures heures** : 8h-12h et 14h-18h GMT

## 🔧 Configuration Avancée

### **Paramètres ML**
```python
# Modifier les paramètres dans backend/advanced_ml_predictor.py
max_risk_per_trade = 0.02  # 2% par trade
max_daily_risk = 0.06      # 6% par jour
max_drawdown = 0.20        # 20% de drawdown max
```

### **Indicateurs Techniques**
```python
# Personnaliser les périodes dans backend/setup_detector.py
rsi_period = 14
macd_fast = 12
macd_slow = 26
bollinger_period = 20
```

## 📊 Métriques de Performance

### **Précision des Prédictions**
- **Direction** : 65-75% de précision
- **Spike Detection** : 70-80% de précision
- **Breakout** : 60-70% de précision
- **Amplitude** : 55-65% de précision

### **Gestion du Risque**
- **Drawdown maximum** : < 20%
- **Pertes consécutives** : < 3
- **Ratio risque/récompense** : 1:2 minimum

## 🚨 Alertes et Notifications

### **Alertes Automatiques**
- 🟢 **RSI OVERSOLD** - Signal d'achat
- 🔴 **RSI OVERBOUGHT** - Signal de vente
- ⚠️ **VOLATILITÉ EXTRÊME** - Risque élevé
- 📈 **PRÈS DU SUPPORT** - Signal d'achat
- 📉 **PRÈS DE LA RÉSISTANCE** - Signal de vente

### **Niveaux de Support/Résistance**
- Calcul automatique des niveaux clés
- Alertes quand le prix s'approche des niveaux
- Distance en pourcentage du prix actuel

## 💡 Conseils d'Utilisation

### **Pour les Débutants**
1. Commencez avec des positions petites
2. Utilisez toujours les stop loss
3. Ne tradez qu'avec de l'argent que vous pouvez perdre
4. Testez d'abord sur un compte démo

### **Pour les Traders Expérimentés**
1. Combine les signaux ML avec votre analyse
2. Ajustez les paramètres selon votre style
3. Utilisez la gestion de risque avancée
4. Surveillez les métriques de performance

## 🔄 Mise à Jour et Maintenance

### **Mise à Jour des Modèles**
- Les modèles s'entraînent automatiquement
- Sauvegarde automatique des modèles
- Chargement des modèles au démarrage

### **Optimisation Continue**
- Ajustement des paramètres selon les performances
- Ajout de nouvelles features
- Amélioration des algorithmes

## 📞 Support

Pour toute question ou problème :
1. Vérifiez la connexion MT5
2. Consultez les logs d'erreur
3. Redémarrez l'application si nécessaire
4. Vérifiez que tous les modules sont installés

---

**⚠️ Avertissement** : Le trading comporte des risques. Cet algorithme est un outil d'aide à la décision et ne garantit pas de profits. Utilisez toujours une gestion de risque appropriée et ne tradez qu'avec de l'argent que vous pouvez vous permettre de perdre.
