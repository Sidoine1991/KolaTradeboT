# Documentation Technique : Système de Trading Pure Momentum

Ce système automatisé est conçu pour identifier et trader les régimes de "flux pur" (chaînes de spikes successives) sur les indices synthétiques tels que Boom/Crash (Deriv) et Painx/Gainx (Weltrade). Il se compose d'un Expert Advisor (EA) pour MetaTrader 5 et d'un module d'analyse en Python.

## 1. Expert Advisor MQL5 : PureMomentumEA.mq5

L'EA est conçu pour une exécution en temps réel sur la plateforme MetaTrader 5. Il surveille les conditions du marché sur l'unité de temps M1 et utilise une unité de temps supérieure (M5 par défaut) pour la confirmation de la tendance.

### Fonctionnalités Clés
- **Surveillance M1 :** Analyse chaque nouvelle bougie sur M1 pour détecter les signaux de momentum.
- **Confluence Multi-Timeframe :** Vérifie que la tendance sur l'unité de temps supérieure (M5) est alignée avec le signal M1.
- **Indicateurs Intégrés :** Utilise les EMA (9 et 21), le RSI (14) et le Stochastique (5,3,3) pour valider le momentum.
- **Gestion des Risques :** Inclut des paramètres pour la taille des lots, le Stop Loss et le Take Profit.

### Paramètres d'Entrée
| Paramètre | Description | Valeur par Défaut |
| :--- | :--- | :--- |
| `LotSize` | Taille du lot pour chaque transaction | 0.01 |
| `StopLossPips` | Distance du Stop Loss en pips | 100 |
| `TakeProfitPips` | Distance du Take Profit en pips | 200 |
| `MagicNumber` | Identifiant unique pour les transactions de l'EA | 12345 |
| `EMAPeriodFast` | Période de l'EMA rapide (M1) | 9 |
| `EMAPeriodSlow` | Période de l'EMA lente (M1) | 21 |
| `RSIOverbought` | Niveau de surachat du RSI pour Boom/Gainx | 70 |
| `RSISold` | Niveau de survente du RSI pour Crash/Painx | 30 |

### Installation
1. Ouvrez votre terminal MetaTrader 5.
2. Allez dans `Fichier` > `Ouvrir le dossier des données`.
3. Naviguez vers `MQL5` > `Experts`.
4. Copiez le fichier `PureMomentumEA.mq5` dans ce dossier.
5. Redémarrez MetaTrader 5 ou faites un clic droit sur `Experts` dans le navigateur et sélectionnez `Rafraîchir`.
6. Glissez-déposez l'EA sur un graphique M1 (Boom, Crash, Gainx ou Painx).

---

## 2. Module Python : pure_momentum_analyzer.py

Ce module est destiné à l'analyse a posteriori (backtesting) ou à l'intégration dans des systèmes d'analyse de données plus vastes. Il permet d'identifier les signaux de momentum pur sur des ensembles de données historiques.

### Fonctionnalités Clés
- **Calcul d'Indicateurs :** Fonctions optimisées pour calculer l'EMA, le RSI et le Stochastique.
- **Identification des Signaux :** Fonction `identify_pure_momentum` qui applique tous les critères de flux pur à un DataFrame pandas.
- **Flexibilité :** Tous les seuils et périodes sont paramétrables.

### Utilisation
Le module nécessite les bibliothèques `pandas` et `numpy`.
```python
import pandas as pd
from pure_momentum_analyzer import identify_pure_momentum

# Charger vos données M1 (Open, High, Low, Close)
df = pd.read_csv("votre_donnee_m1.csv")

# Identifier les signaux
df_avec_signaux = identify_pure_momentum(df)

# Afficher les signaux d'achat
print(df_avec_signaux[df_avec_signaux["Pure_Momentum_Buy_Signal"] == True])
```

---

## 3. Stratégie de Flux Pur (Rappel)

Le système repose sur la confluence de quatre piliers :
1. **Structure de Prix :** Cassure de structure et retracements minimaux (1-5 bougies).
2. **Momentum des Indicateurs :** RSI et Stochastique en zones extrêmes (surachat/survente).
3. **Alignement des Moyennes Mobiles :** Prix soutenu par l'EMA 9 et l'EMA 21.
4. **Confirmation HTF :** Tendance confirmée sur une unité de temps supérieure (M5).

---

## 4. Avertissement sur les Risques

Le trading d'indices synthétiques comporte des risques élevés de perte en capital. Ces outils sont fournis à titre éducatif et informatif. Il est fortement recommandé de les tester sur un compte de démonstration avant toute utilisation avec des fonds réels. Manus AI ne saurait être tenu responsable des pertes financières résultant de l'utilisation de ces scripts.
