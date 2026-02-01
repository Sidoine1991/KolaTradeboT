# STRATÉGIE SIMPLIFIÉE - 21 Janvier 2026

## NOUVELLE STRATÉGIE DE TRADING

### PRINCIPE FONDAMENTAL
L'IA n'est plus utilisée pour prendre des décisions de trading directes. Le robot se base UNIQUEMENT sur:
1. **Alignement H1/M5** - Signaux techniques multi-timeframe
2. **Zones de correction** - Supports et résistances pour ordres LIMIT

### CHANGEMENTS APPORTÉS

#### 1. DÉSACTIVATION DES FONCTIONS IA POUR TRADING
- `UseIntelligentDecisionSystem = false` - Système de décision intelligent désactivé
- `UseMarketStateDetection = false` - Détection état marché désactivée
- `UseAdaptiveSLTP = false` - SL/TP adaptatif désactivé
- `UsePositionDuplication = false` - Duplication positions désactivée

#### 2. DÉSACTIVATION DES FONCTIONS DE TRAJECTOIRE
- `UsePredictedTrajectoryForLimitEntry = false` - Placement LIMIT sur trajectoire désactivé
- `UseTrajectoryTrendConfirmation = false` - Confirmation tendance via trajectoire désactivée
- `UpdateLimitOrderOnTrajectory = false` - Mise à jour ordres LIMIT sur trajectoire désactivée

#### 3. STRATÉGIE PRINCIPALE: ALIGNEMENT H1/M5

**Conditions pour BUY:**
- RSI H1 < 70 (pas surachat)
- RSI M5 < 70 (pas surachat)
- EMA 9 M5 > EMA 21 M5 (tendance haussière court terme)
- EMA 9 H1 > EMA 21 H1 (tendance haussière long terme)
- Prix en zone de correction (OBLIGATOIRE)

**Conditions pour SELL:**
- RSI H1 > 30 (pas survente)
- RSI M5 > 30 (pas survente)
- EMA 9 M5 < EMA 21 M5 (tendance baissière court terme)
- EMA 9 H1 < EMA 21 H1 (tendance baissière long terme)
- Prix en zone de correction (OBLIGATOIRE)

#### 4. ORDRES LIMIT (STRATÉGIE US BREAKOUT)
- Placement sur zones de correction identifiées
- Validation ultra-tardive (2 secondes avant exécution)
- Utilisation des niveaux fractals pour S/R
- Pas de dépendance à la trajectoire prédite

#### 5. IA UTILISÉE SEULEMENT POUR INFORMATION
- L'IA continue de fournir des analyses informatives
- Les décisions de trading ne dépendent plus de l'IA
- Messages informatifs affichés en mode debug
- Confiance IA minimale toujours requise (60%)

### FONCTIONS CONSERVÉES

#### Analyse Technique
- ✅ Alignement H1/M5
- ✅ Zones de correction
- ✅ Niveaux fractals
- ✅ RSI multi-timeframe
- ✅ EMA 9/21 multi-timeframe

#### Gestion des Ordres
- ✅ Ordres LIMIT sur zones de correction
- ✅ Validation tardive des ordres
- ✅ SL/TP fixes (30/15 pips)
- ✅ Gestion du risque (2% max)

#### Visualisation
- ✅ Bougies H1/M5 colorées
- ✅ Zones de correction
- ✅ Niveaux fractals
- ✅ Informations IA (informatif)

### FONCTIONS DÉSACTIVÉES

#### Systèmes de Décision IA
- ❌ Système de décision intelligent
- ❌ Détection état marché
- ❌ SL/TP adaptatif basé IA
- ❌ Duplication positions

#### Trajectoire Prédite
- ❌ Placement LIMIT sur trajectoire
- ❌ Confirmation tendance via trajectoire
- ❌ Mise à jour ordres sur trajectoire

### AVANTAGES DE LA NOUVELLE STRATÉGIE

1. **Simplicité** - Moins de paramètres à optimiser
2. **Fiabilité** - Basée sur des signaux techniques éprouvés
3. **Stabilité** - Moins de dépendances aux prédictions IA
4. **Performance** - Réduction des faux signaux
5. **Transparence** - Logique de trading claire et compréhensible

### RISQUES ET LIMITATIONS

1. **Moins d'opportunités** - Filtres plus stricts
2. **Dépendance aux zones** - Nécessite des corrections claires
3. **Timeframes fixes** - H1/M5 uniquement

### SURVEILLANCE ET MONITORING

- Logs détaillés des signaux H1/M5
- Suivi des zones de correction
- Messages informatifs IA (non utilisés pour trading)
- Alertes en cas de données IA anciennes

---

**Date:** 21 Janvier 2026  
**Version:** F_INX_Scalper_double.mq5 v2.1  
**Stratégie:** Alignement H1/M5 + Zones de correction (IA informative uniquement)
