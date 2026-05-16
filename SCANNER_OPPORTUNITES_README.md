# 📊 SCANNER MULTI-SYMBOLES TEMPS RÉEL

## 🎯 Vue d'ensemble

Le scanner d'opportunités temps réel affiche sur le graphique un tableau dynamique qui surveille **tous les symboles** sur lesquels le robot est attaché, et affiche en temps réel les meilleures opportunités de trading détectées.

## ✨ Fonctionnalités

### 🔍 Surveillance Multi-Symboles
- **Scan automatique** de tous les symboles configurés
- **Actualisation toutes les 2 secondes** (configurable)
- **Classement intelligent** par qualité d'opportunité

### 📈 Informations Affichées
Pour chaque symbole détecté avec une opportunité, le scanner affiche:

| Colonne | Description |
|---------|-------------|
| **SYMBOLE** | Nom du symbole (ex: Boom 1000 Index) |
| **DIRECTION** | BUY / SELL / WAIT (couleur: vert / rouge / gris) |
| **QUALITÉ** | PERFECT / GOOD / FAIR (couleur: or / vert / orange) |
| **ENTRÉE** | Prix d'entrée recommandé |
| **SPIKE %** | Probabilité de spike (0-100%) |
| **DISTANCE** | Distance au prix d'entrée (en points) |
| **NIVEAUX** | Niveaux proches (M5 BUY, H1 SELL, etc.) |

### 🎨 Interface Visuelle
- **Panneau flottant** en haut du graphique
- **Couleurs intuitives** (TradingView style)
- **Fond sombre** pour meilleure lisibilité
- **Tri automatique** (meilleures opportunités en premier)
- **Maximum 15 lignes** affichées simultanément

## 🛠️ Configuration

### Paramètres Principaux

```
[SCANNER MULTI-SYMBOLES TEMPS RÉEL]
EnableOpportunityScanner = true              // Activer le scanner
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,..."  // Liste des symboles
ScannerRefreshSeconds = 2                    // Intervalle de scan (secondes)
ScannerShowPanel = true                      // Afficher le panneau
```

### Paramètres d'Affichage

```
ScannerPanelX = 10                          // Position X (pixels depuis la gauche)
ScannerPanelY = 30                          // Position Y (pixels depuis le haut)
ScannerPanelWidth = 500                     // Largeur du panneau
ScannerRowHeight = 25                       // Hauteur des lignes
```

### 📝 Format de la Liste des Symboles

Les symboles doivent être séparés par des **virgules**. Exemples:

```
// Indices synthétiques
"Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,Step Index"

// Forex
"EURUSD,GBPUSD,USDJPY,AUDUSD"

// Mix
"Boom 1000 Index,EURUSD,XAUUSD,Volatility 100 Index"
```

**Important:** Les noms doivent correspondre **exactement** aux noms des symboles dans MT5.

## 🚀 Utilisation

### 1. Activation

1. **Ouvrir un graphique** (n'importe quel symbole)
2. **Attacher le robot** `SMC_Universal.mq5`
3. **Activer le scanner** dans les paramètres:
   - `EnableOpportunityScanner = true`
4. **Configurer la liste** des symboles à surveiller

### 2. Multi-Graphiques

Pour surveiller **plusieurs symboles** simultanément:

1. **Ouvrir un graphique** pour chaque symbole à trader
2. **Attacher le robot** sur chaque graphique
3. Le robot publiera les données via **Global Variables**
4. Le scanner affichera **toutes les opportunités** des graphiques actifs

**Exemple de setup:**
- Graphique 1: Boom 1000 Index (robot attaché)
- Graphique 2: Crash 1000 Index (robot attaché)
- Graphique 3: Volatility 75 Index (robot attaché)
- Graphique 4: EURUSD (robot attaché + **scanner actif**)

Le graphique 4 affichera le scanner avec les opportunités des 4 symboles.

### 3. Lecture du Panneau

#### Priorité des Opportunités
Le scanner classe automatiquement par:
1. **Qualité** (PERFECT > GOOD > FAIR)
2. **Probabilité de spike** (plus élevée = mieux)
3. **Distance à l'entrée** (plus proche = mieux)

#### Couleurs
- **BUY** = Vert lime
- **SELL** = Rouge
- **WAIT** = Gris
- **PERFECT** = Or
- **GOOD** = Vert lime
- **FAIR** = Orange

#### Spike %
- **Rouge (≥45%)** = Spike imminent très probable
- **Orange (≥30%)** = Spike possible
- **Gris (<30%)** = Faible probabilité

## 📊 Données Sources

Le scanner lit les **Global Variables** publiées par GOM:

```
GOM_SCRIPT_SYMBOL_VERDICT_NUM     // Direction + qualité
GOM_SCRIPT_SYMBOL_BUY_ENTRY       // Prix d'entrée BUY
GOM_SCRIPT_SYMBOL_SELL_ENTRY      // Prix d'entrée SELL
GOM_SCRIPT_SYMBOL_SL              // Stop Loss
GOM_SCRIPT_SYMBOL_TP1/TP2/TP3     // Take Profits
GOM_SCRIPT_SYMBOL_SPIKE_PROB      // Probabilité spike
GOM_SCRIPT_SYMBOL_TECH_BUY_SCORE  // Score technique BUY
GOM_SCRIPT_SYMBOL_TECH_SELL_SCORE // Score technique SELL
GOM_SCRIPT_SYMBOL_M5_BUY          // Niveau M5 BUY
GOM_SCRIPT_SYMBOL_M5_SELL         // Niveau M5 SELL
GOM_SCRIPT_SYMBOL_H1_BUY          // Niveau H1 BUY
GOM_SCRIPT_SYMBOL_H1_SELL         // Niveau H1 SELL
```

Ces variables sont **automatiquement mises à jour** par le robot sur chaque graphique.

## 🎯 Cas d'Usage

### Trading Actif
- Surveiller **plusieurs paires** simultanément
- Identifier rapidement les **meilleurs setups**
- Agir sur les opportunités **PERFECT** en priorité

### Observation de Marché
- Vue d'ensemble du marché en temps réel
- Détection des **spikes imminents** multi-symboles
- Analyse des **confluences** entre symboles

### Gestion de Portefeuille
- Diversification automatique des opportunités
- Priorisation des symboles les plus **propices**
- Éviter de concentrer sur un seul actif

## 🔧 Dépannage

### Le scanner n'affiche rien
1. Vérifier que `EnableOpportunityScanner = true`
2. Vérifier que `ScannerShowPanel = true`
3. S'assurer que les symboles sont correctement orthographiés
4. Vérifier que le robot est attaché sur les graphiques des symboles

### Données non actualisées
1. Vérifier que le robot tourne sur les graphiques sources
2. Vérifier l'intervalle de scan (`ScannerRefreshSeconds`)
3. Redémarrer le robot si nécessaire

### Symboles manquants
1. Le scanner n'affiche que les opportunités **valides** (BUY/SELL)
2. Les symboles en WAIT ne sont pas affichés
3. Vérifier les Global Variables dans MT5 (Ctrl+G)

## 📋 Fichiers

- **SMC_OpportunityScanner.mqh** - Classe du scanner
- **SMC_Universal.mq5** - Robot principal (intégration)

## 🆕 Nouveautés

### Version 1.0
- ✅ Scanner multi-symboles temps réel
- ✅ Panneau graphique TradingView style
- ✅ Tri intelligent par qualité
- ✅ Détection niveaux proches
- ✅ Probabilité spike en temps réel
- ✅ Interface configurable

## 💡 Conseils

1. **Limitez le nombre de symboles** (5-10 max) pour éviter la surcharge CPU
2. **Augmentez ScannerRefreshSeconds** (3-5s) si le terminal ralentit
3. **Positionnez le panneau** pour ne pas gêner les graphiques
4. **Surveillez les opportunités PERFECT** en priorité
5. **Croisez avec les niveaux** affichés (M5, H1) pour confirmer

## 🎓 Exemple de Configuration Optimale

```mql5
// Pour trader Boom/Crash avec Forex
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,EURUSD,GBPUSD,XAUUSD"
ScannerRefreshSeconds = 2
ScannerPanelX = 10
ScannerPanelY = 30
ScannerPanelWidth = 520
ScannerRowHeight = 25
ScannerShowPanel = true
```

## 🔗 Intégration avec GOM

Le scanner est **nativement intégré** avec GOM (KOLA + SIDO):
- Utilise les mêmes niveaux d'entrée
- Même système de qualité (PERFECT/GOOD/FAIR)
- Même détection de spike
- Cohérence totale avec les décisions du robot

---

**Développé par TradBOT SMC** - Scanner d'opportunités professionnel pour MT5
