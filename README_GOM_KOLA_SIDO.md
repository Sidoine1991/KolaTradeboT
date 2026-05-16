# GOM_KOLA_SIDO Script - Documentation Complète

**Version**: 1.3
**Date**: 2026-05-06
**Auteur**: TradBOT Team

---

## 📋 Table des Matières

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Modules](#modules)
5. [Utilisation](#utilisation)
6. [Intégration](#intégration)
7. [Dépannage](#dépannage)
8. [FAQ](#faq)

---

## 🎯 Introduction

GOM_KOLA_SIDO_Script est un script d'analyse technique avancé pour MetaTrader 5 qui combine deux modules d'analyse :

### Module KOLA
- Détection de niveaux de support/résistance
- Algorithme Three Line Break
- Système de touch avec comptage
- Publication des niveaux pour utilisation par d'autres EAs

### Module SIDO
- Détection de figures chartistes (Double Top/Bottom)
- Tolérance ATR configurable
- Affichage visuel des patterns

### Fonctionnalités Clés
- **6 filtres de confirmation** : Volume, Momentum, RSI Divergence, Multi-Timeframe, Structure, Volatilité
- **Prédiction de spikes** : Analyse proactive pour Boom/Crash
- **Dashboard en temps réel** : Affichage des métriques techniques
- **Intégration IA** : Communication avec serveur externe pour interprétation

---

## 📦 Installation

### Prérequis
- MetaTrader 5 (build 3665 ou supérieur)
- Compte de trading actif
- Accès aux symboles à analyser

### Étapes d'Installation

1. **Copier le fichier**
   - Copier `GOM_KOLA_SIDO_Script.mq5` dans le dossier `MQL5/Scripts/` de votre terminal MT5

2. **Compiler le script**
   - Ouvrir MetaEditor
   - Ouvrir le fichier `GOM_KOLA_SIDO_SIDO_Script.mq5`
   - Appuyer sur F7 ou cliquer sur "Compiler"
   - Vérifier qu'il n'y a pas d'erreurs

3. **Lancer le script**
   - Dans MT5, ouvrir le graphique du symbole à analyser
   - Dans le navigateur, aller dans "Scripts"
   - Double-cliquer sur `GOM_KOLA_SIDO_Script`
   - Configurer les paramètres si nécessaire
   - Cliquer sur "OK"

---

## ⚙️ Configuration

### Paramètres Généraux

#### Timeframes
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `ShowM1Levels` | true | Afficher niveaux M1 |
| `ShowM5Levels` | true | Afficher niveaux M5 |
| `ShowM15Levels` | true | Afficher niveaux M15 |
| `ShowM30Levels` | true | Afficher niveaux M30 |
| `ShowH1Levels` | true | Afficher niveaux H1 |
| `ShowH4Levels` | true | Afficher niveaux H4 |
| `ShowD1Levels` | true | Afficher niveaux D1 |
| `ShowW1Levels` | true | Afficher niveaux W1 |

#### Algorithme Three Line Break
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `LineBreakPeriod` | 3 | Période pour le calcul des lignes de rupture |
| `MaxBarsToAnalyze` | 300 | Nombre maximum de barres à analyser |

#### Système de Touch
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `EnableTouchDetection` | true | Activer la détection de touch |
| `TouchZoneATRPercent` | 25.0 | Zone de touch en % de l'ATR |
| `BarsForTouchCount` | 200 | Nombre de barres pour compter les touches |
| `MinLineWidth` | 1 | Largeur de ligne minimum |
| `MaxLineWidth` | 5 | Largeur de ligne maximum |
| `TouchesForMaxWidth` | 10 | Touches nécessaires pour largeur max |

#### Affichage KOLA
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `ShowLabels` | true | Afficher les labels sur les niveaux |
| `ShowTouchCount` | false | Afficher le nombre de touches |
| `LabelShiftBars` | 3 | Décalage des labels en barres |
| `BuyLevelColor` | LimeGreen | Couleur des niveaux BUY |
| `SellLevelColor` | Red | Couleur des niveaux SELL |

#### Module SIDO
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `EnableSIDO` | true | Activer le module SIDO |
| `SIDOPivotLookback` | 3 | Lookback pour les pivots |
| `SIDOBarsToAnalyze` | 300 | Barres à analyser |
| `SIDOMaxBarsBetweenSwings` | 80 | Écart max entre swings |
| `SIDOToleranceATRPercent` | 35.0 | Tolérance en % de l'ATR |
| `SIDODoubleTopColor` | OrangeRed | Couleur Double Top |
| `SIDODoubleBottomColor` | DeepSkyBlue | Couleur Double Bottom |
| `ShowSIDOLabels` | true | Afficher les labels SIDO |

#### Dashboard
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `ShowBottomDashboard` | true | Afficher le dashboard en bas |
| `DashboardBottomOffset` | 34 | Offset vertical du dashboard |
| `DashboardLeftOffset` | 10 | Offset horizontal du dashboard |
| `DashboardFontSize` | 10 | Taille de police du dashboard |
| `DashboardTextColor` | White | Couleur du texte |
| `DashboardCellWidth` | 130 | Largeur des cellules |
| `DashboardVerdictExtraWidth` | 110 | Largeur cellule verdict |
| `DashboardVerdictRowHeight` | 26 | Hauteur ligne verdict |
| `DashboardVerdictBorderColor` | Gold | Bordure cellule verdict |
| `DashboardVolOnMinAtrPct` | 0.06 | Seuil VOL ON (% du prix) |
| `DashboardAtrOkMinAtrPct` | 0.04 | Seuil ATR OK (% du prix) |

#### IA Externe
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `EnableExternalAIInterpretation` | true | Activer l'interprétation IA externe |
| `ExternalAIUrl` | http://127.0.0.1:8001/gom/interpret | URL du serveur IA |
| `ExternalAITimeoutMs` | 1800 | Timeout requête IA (ms) |
| `ExternalAIThrottleMs` | 2000 | Throttle entre appels IA (ms) |

#### Script
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `KeepScriptAttached` | true | Garder le script attaché en boucle |
| `RefreshSeconds` | 2 | Intervalle de rafraîchissement (secondes) |
| `ShowScriptEMAs` | true | Afficher les EMA du script |
| `ScriptEmaTF` | M5 | Timeframe des EMA du script |

#### Filtres de Confirmation
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `EnableVolumeFilter` | true | Activer filtre Volume |
| `VolumeMinRatio` | 1.2 | Ratio volume actuel/moyenne minimum |
| `VolumeLookback` | 20 | Période pour calculer la moyenne du volume |
| `EnableMomentumFilter` | true | Activer filtre Momentum |
| `EnableRSIDivergenceFilter` | true | Activer filtre Divergence RSI |
| `RSIDivergenceLookback` | 5 | Lookback pour détecter divergence |
| `RSIDivergenceThreshold` | 5.0 | Seuil de divergence RSI |
| `EnableMTFFilter` | true | Activer filtre Multi-Timeframe |
| `EnableStructureFilter` | true | Activer filtre Structure |
| `StructureATRMultiplier` | 0.5 | Distance max du niveau en ATR |
| `EnableVolatilityFilter` | true | Activer filtre Volatilité |
| `VolatilityMinATRPct` | 0.03 | ATR minimum en % du prix |

#### Prédiction de Spike
| Paramètre | Défaut | Description |
|-----------|---------|-------------|
| `EnableSpikePrediction` | true | Activer la prédiction de spike |
| `SpikeLookbackBarsM1` | 24 | Lookback M1 pour prédiction |
| `SpikeAlertMinProbability` | 0.62 | Probabilité min pour alerte spike |

---

## 📚 Modules

### Module KOLA

#### Fonctionnement
Le module KOLA utilise l'algorithme Three Line Break pour détecter les niveaux de support et résistance :

1. **Détection des pivots** : Identification des swing highs et swing lows
2. **Calcul des lignes** : Création de lignes horizontales basées sur les pivots
3. **Système de touch** : Comptage du nombre de fois où le prix touche un niveau
4. **Largeur dynamique** : La largeur de la ligne augmente avec le nombre de touches

#### Niveaux Détectés
- **BUY Levels** : Niveaux où le prix a rebondi (support)
- **SELL Levels** : Niveaux où le prix a rejeté (résistance)

#### Confiance d'Entrée
La confiance d'entrée est calculée en fonction du nombre de touches :
- 55% minimum (1 touche)
- 100% maximum (10+ touches)

#### Publication des Niveaux
Les niveaux sont publiés via Global Variables pour utilisation par d'autres EAs :
```
GOM_KOLA_{SYMBOL}_{TF}_BUY
GOM_KOLA_{SYMBOL}_{TF}_SELL
```

### Module SIDO

#### Fonctionnement
Le module SIDO détecte les figures chartistes classiques :

1. **Double Top** : Deux sommets proches avec tolérance ATR
2. **Double Bottom** : Deux creux proches avec tolérance ATR

#### Tolérance ATR
La tolérance est exprimée en pourcentage de l'ATR :
- Défaut : 35% de l'ATR
- Ajustable selon la volatilité du marché

#### Affichage
- Lignes pointillées pour les patterns
- Labels avec nom du pattern et timeframe
- Couleurs distinctes (Orange pour Double Top, Bleu pour Double Bottom)

### Système de Filtres

#### Filtres Disponibles

1. **Volume Filter**
   - Vérifie que le volume actuel est au-dessus de la moyenne
   - Ratio minimum configurable (défaut: 1.2x)

2. **Momentum Filter**
   - Vérifie l'alignement EMA 9/21
   - Direction du prix alignée avec la tendance

3. **RSI Divergence Filter**
   - Détecte les divergences prix/RSI
   - Divergence haussière : prix plus bas, RSI plus haut
   - Divergence baissière : prix plus haut, RSI plus bas

4. **Multi-Timeframe Filter**
   - Vérifie l'alignement sur M5, M15, H1
   - Au moins 2 TF sur 3 doivent être alignés

5. **Structure Filter**
   - Vérifie la proximité des niveaux clés
   - Distance max en ATR configurable

6. **Volatility Filter**
   - Vérifie que l'ATR est suffisant
   - ATR minimum en % du prix

#### Score de Qualité
Le score de qualité est calculé en fonction des filtres passés :
- 0% à 100%
- Bonus si tous les filtres passent (+20%)
- Utilisé pour bloquer les signaux de faible qualité

### Prédiction de Spike

#### Fonctionnement
Le module de prédiction analyse les patterns pré-spike sur M1 :

1. **Compression** : Détection de compression avant expansion
2. **Expansion** : Détection d'expansion soudaine
3. **Body** : Analyse du corps des bougies
4. **Volume** : Comparaison avec la moyenne
5. **Micro-trend** : Alignement EMA 9/21 et RSI

#### Probabilité de Spike
- Calculée sur une échelle de 0.0 à 1.0
- Direction prédite (BUY/SELL)
- Intégration avec les filtres de confirmation

---

## 🚀 Utilisation

### Lancement du Script

1. **Ouvrir le graphique** du symbole à analyser
2. **Aller dans Scripts** et double-cliquer sur `GOM_KOLA_SIDO_Script`
3. **Configurer les paramètres** si nécessaire
4. **Cliquer sur OK**

### Interprétation du Dashboard

#### Cellules du Dashboard

| Cellule | Description |
|---------|-------------|
| M5, M15, M30, H1, H4, D1 | Biais de tendance (↑ haussier, ↓ baissier, - neutre) |
| AI | Action IA avec confiance (BUY/SELL/HOLD) |
| VERDICT | Verdict de trading (PERFECT BUY/SELL, GOOD BUY/SELL, BUY/SELL, WAIT) |
| SPIKE | Probabilité de spike avec direction |
| VOL | Statut de la volatilité (VOL ON/OFF) |
| ATR | Statut de l'ATR (OK/insuffisant) |
| SIDO | Patterns SIDO détectés (DBOT/DTOP/DB+DT) |
| KOLA | Niveaux KOLA détectés |
| RSI/MACD | Indicateurs RSI et MACD |
| FILTERS | Statut des filtres (passés/total + qualité) |
| WAIT | Signal de trading actuel |

#### Couleurs du Verdict

| Verdict | Couleur |
|--------|--------|
| PERFECT BUY | Vert foncé |
| PERFECT SELL | Rouge foncé |
| GOOD BUY | Vert clair |
| GOOD SELL | Rouge clair |
| BUY | Vert moyen |
| SELL | Rouge moyen |
| WAIT | Gris |

### Lecture des Niveaux

Les niveaux sont accessibles via Global Variables :

```mql5
// Niveaux KOLA
double m5Buy = GlobalVariableGet("GOM_KOLA_" + _Symbol + "_M5_BUY");
double m5Sell = GlobalVariableGet("GOM_KOLA_" + _Symbol + "_M5_SELL");

// Niveaux SIDO
double doubleTop = GlobalVariableGet("GOM_SIDO_" + _Symbol + "_M15_DOUBLE_TOP");
double doubleBottom = GlobalVariableGet("GOM_SIDO_" + _Symbol + "_M15_DOUBLE_BOTTOM");

// Plan de trading
double entry = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY");
double sl = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_SL");
double tp1 = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_TP1");
double tp2 = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_TP2");
double tp3 = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_TP3");
```

### Intégration avec SMC_Universal

Le script est conçu pour fonctionner avec le robot SMC_Universal :

1. **Lecture des signaux IA** depuis SMC_Universal
2. **Publication des niveaux** pour utilisation par SMC_Universal
3. **Envoi de données techniques** au serveur IA pour interprétation

#### Variables Globales Partagées

```mql5
// Depuis SMC_Universal vers GOM_KOLA_SIDO
SMC_UNIVERSAL_{SYMBOL}_AI_ACTION_NUM
SMC_UNIVERSAL_{SYMBOL}_AI_CONF
SMC_UNIVERSAL_{SYMBOL}_AI_SOURCE_MTF

// Depuis GOM_KOLA_SIDO vers SMC_Universal
GOM_SCRIPT_{SYMBOL}_BUY_ENTRY
GOM_SCRIPT_{SYMBOL}_SELL_ENTRY
GOM_SCRIPT_{SYMBOL}_SL
GOM_SCRIPT_{SYMBOL}_TP1
GOM_SCRIPT_{SYMBOL}_TP2
GOM_SCRIPT_{SYMBOL}_TP3
GOM_SCRIPT_{SYMBOL}_M1_ENTRY
GOM_SCRIPT_{SYMBOL}_VERDICT_NUM
```

---

## 🔗 Intégration

### Avec SMC_Universal

Le script GOM_KOLA_SIDO_Script est conçu pour fonctionner en complément du robot SMC_Universal :

#### Flux de Données

```
SMC_Universal → Global Variables → GOM_KOLA_SIDO_Script
GOM_KOLA_SIDO_Script → Global Variables → SMC_Universal
```

#### Utilisation dans SMC_Universal

```mql5
// Lire les niveaux KOLA
double m5Buy = GlobalVariableGet("GOM_KOLA_" + _Symbol + "_M5_BUY");
double m5Sell = GlobalVariableGet("GOM_KOLA_" + _Symbol + "_M5_SELL");

// Lire le verdict
double verdictNum = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM");

// Utiliser les niveaux pour les entrées
if(m5Buy > 0.0 && bid <= m5Buy * 1.0010) {
    // Entrée BUY sur niveau M5
}
```

### Avec Serveur IA Externe

Le script peut envoyer des données techniques à un serveur IA pour interprétation :

#### Données Envoyées
- Prix (bid/ask)
- ATR M15
- RSI M1
- EMA 9/21 M1 et M5
- Verdict numérique
- Probabilité de spike
- Direction de spike
- Niveaux KOLA (M5/M15 BUY/SELL)
- Patterns SIDO (Double Top/Bottom)

#### Réponse Reçue
- Action (BUY/SELL/HOLD)
- Confidence (0-1)
- Raison de la décision

---

## 🛠️ Dépannage

### Problèmes Courants

#### 1. Script ne se lance pas
**Symptôme**: Le script ne démarre pas ou se ferme immédiatement

**Solutions**:
- Vérifier que le script est compilé sans erreurs
- Vérifier que le symbole a suffisamment d'historique
- Vérifier que les timeframes demandés sont disponibles

#### 2. Niveaux ne s'affichent pas
**Symptôme**: Les lignes horizontales ne s'affichent pas sur le graphique

**Solutions**:
- Vérifier que `ShowChartGraphics` est activé dans MT5
- Vérifier que les timeframes sont activés dans les paramètres
- Vérifier que le symbole a suffisamment de données historiques

#### 3. Dashboard ne s'affiche pas
**Symptôme**: Le dashboard en bas du graphique ne s'affiche pas

**Solutions**:
- Vérifier que `ShowBottomDashboard` est activé
- Vérifier que `DashboardBottomOffset` est assez grand
- Vérifier que le graphique a assez d'espace en bas

#### 4. Erreur WebRequest
**Symptôme**: Message d'erreur lors de la communication avec le serveur IA

**Solutions**:
- Vérifier que `ExternalAIUrl` est correct
- Vérifier que le serveur IA est accessible
- Augmenter `ExternalAITimeoutMs` si nécessaire

#### 5. Performance lente
**Symptôme**: Le script ralentit le terminal MT5

**Solutions**:
- Désactiver les timeframes non utilisés
- Augmenter `RefreshSeconds`
- Désactiver `EnableExternalAIInterpretation` si non utilisé

### Logs et Messages

Le script affiche les messages suivants dans l'onglet Experts :

- ✅ Messages de succès (vert)
- ⚠️ Messages d'avertissement (jaune)
- ❌ Messages d'erreur (rouge)

### Mode Debug

Pour activer le mode debug, modifier les paramètres suivants :
- `DebugSpikeDetection = true` : Logs détaillés de détection de spike
- `DebugEMATouchFilter = false` : Logs EMA touch (désactivé par défaut)

---

## ❓ FAQ

### Q1 : Quels sont les prérequis pour utiliser ce script ?
**R** : MetaTrader 5 (build 3665+), compte de trading actif, accès aux symboles à analyser.

### Q2 : Combien de tempsframes peut-on analyser simultanément ?
**R** : Tous les timeframes sont supportés (M1 à W1), mais il est recommandé d'activer ceux qui ne sont pas nécessaires pour optimiser les performances.

### Q3 : Le script fonctionne-t-il avec tous les types de symboles ?
**R** : Oui, le script fonctionne avec tous les types de symboles (Forex, Indices, Commodities, Crypto, Boom/Crash, Volatility).

### Q4 : Comment ajuster la sensibilité de la détection de niveaux ?
**R** : Modifier `TouchZoneATRPercent` (plus grand = plus de tolérance) et `BarsForTouchCount` (plus grand = plus de touches comptées).

### Q5 : Le script consomme-t-il beaucoup de ressources ?
**R** : La consommation dépend du nombre de timeframes activés et de la fréquence de rafraîchissement. Avec 8 timeframes et rafraîchissement toutes les 2 secondes, la consommation CPU est modérée.

### Q6 : Peut-on utiliser le script sans SMC_Universal ?
**R** : Oui, le script fonctionne de manière autonome. Les niveaux sont publiés via Global Variables et peuvent être lus par n'importe quel EA.

### Q7 : Comment désactiver l'intégration IA ?
**R** : Définir `EnableExternalAIInterpretation = false` dans les paramètres.

### Q8 : Le script prédit-il les spikes avec précision ?
**R** : Le script fournit une probabilité de spike basée sur l'analyse technique, mais ce n'est pas une garantie. Il est recommandé de l'utiliser comme indicateur complémentaire.

### Q9 : Comment personnaliser les couleurs des niveaux ?
**R** : Modifier `BuyLevelColor` et `SellLevelColor` dans les paramètres.

### Q10 : Le script fonctionne-t-il en mode backtest ?
**R** : Non, ce script est conçu pour une utilisation en temps réel. Pour le backtest, il faudrait créer une version adaptée.

---

## 📈 Exemples d'Utilisation

### Exemple 1 : Utilisation avec SMC_Universal

```mql5
// Dans SMC_Universal.mq5
// Lire les niveaux KOLA
double m5Buy = GlobalVariableGet("GOM_KOLA_" + _Symbol + "_M5_BUY");
double m5Sell = GlobalVariableGet("GOM_KOLA_" + _Symbol + "_M5_SELL");

// Lire le verdict
double verdictNum = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM");

// Utiliser les niveaux pour les entrées
if(verdictNum > 0.0 && m5Buy > 0.0) {
    // Entrée BUY sur niveau M5
    double entry = m5Buy;
    double sl = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_SL");
    double tp = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_TP1");
    // Exécuter le trade...
}
```

### Exemple 2 : Lecture des filtres

```mql5
// Lire les résultats des filtres
double filterPassCount = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_FILTER_PASS_COUNT");
double filterTotal = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_FILTER_TOTAL");
double filterQuality = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_FILTER_QUALITY");

// Calculer le ratio de filtres passés
double passRatio = (filterTotal > 0) ? (filterPassCount / filterTotal) : 0.0;

// Bloquer si moins de 50% des filtres passent
if(passRatio < 0.5) {
    Print("⛔ Filtres insuffisants: ", DoubleToString(passRatio * 100, 1), "%");
}
```

### Exemple 3 : Lecture de la prédiction de spike

```mql5
// Lire la probabilité de spike
double spikeProb = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_SPIKE_PROB");
double spikeDirNum = GlobalVariableGet("GOM_SCRIPT_" + _Symbol + "_SPIKE_DIR_NUM");

// Interpréter la direction
string spikeDir = "NONE";
if(spikeDirNum > 0.5) spikeDir = "BUY";
else if(spikeDirNum < -0.5) spikeDir = "SELL";

// Agir selon la probabilité
if(spikeProb >= 0.62) {
    Print("⚠️ Spike probable: ", spikeDir, " (", DoubleToString(spikeProb * 100, 1), "%)");
}
```

---

## 📞 Support

Pour toute question ou problème, contactez l'équipe TradBOT ou consultez la documentation technique.

---

**Version**: 1.3
**Dernière mise à jour**: 2026-05-06
