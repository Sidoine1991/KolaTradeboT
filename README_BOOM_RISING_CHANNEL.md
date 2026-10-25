# 🚀 Boom Rising Channel Predictor

## Description

Le **Boom Rising Channel Predictor** est un système avancé de prédiction et de trading automatique spécialement conçu pour détecter les patterns de "ciseau montant" (canal haussier) sur le symbole Boom et prédire les spikes avec une précision élevée.

## 🎯 Fonctionnalités Principales

### 1. Détection du Canal Haussier
- **Identification automatique** des patterns de canal haussier
- **Calcul de la force** et de la cohérence du canal
- **Détection des lignes de tendance** supérieure et inférieure
- **Validation** des conditions de canal haussier

### 2. Prédiction de Spikes
- **Analyse de proximité** avec les EMA 10, 30, 50
- **Calcul de probabilité** de spike basé sur la position dans le canal
- **Estimation du temps** jusqu'au spike
- **Direction prédite** (BOOM ou CRASH)

### 3. Flèches Dynamiques
- **Flèches de prédiction** sur le graphique
- **Couleurs indicatives** (vert = BOOM, rouge = CRASH)
- **Niveaux de confiance** affichés
- **Mise à jour en temps réel**

### 4. Trading Automatique
- **Exécution automatique** des trades basée sur les prédictions
- **Gestion des risques** avec stop loss et take profit
- **Limites de sécurité** quotidiennes
- **Monitoring en temps réel** des positions

### 5. Interface Utilisateur
- **Interface Streamlit** moderne et intuitive
- **Graphiques interactifs** avec Plotly
- **Contrôles en temps réel** du trading
- **Statistiques détaillées** des performances

## 📁 Structure du Projet

```
TradBOT/
├── boom_rising_channel_predictor.py    # Module principal de prédiction
├── boom_trading_bot.py                 # Bot de trading automatique
├── boom_streamlit_app.py               # Interface utilisateur
├── launch_boom_system.py              # Script de lancement
├── requirements_boom.txt               # Dépendances Python
├── lancer_systeme_complet.bat         # Lanceur Windows
├── lancer_interface_boom.bat           # Lanceur interface
├── lancer_trading_boom.bat            # Lanceur trading
└── boom_trade_history.json            # Historique des trades
```

## 🚀 Installation et Configuration

### Prérequis
- Python 3.8+
- MetaTrader 5 installé et configuré
- Compte de trading MT5 (demo ou réel)

### Installation Rapide

1. **Cloner le projet**
```bash
git clone <repository>
cd TradBOT
```

2. **Installer les dépendances**
```bash
pip install -r requirements_boom.txt
```

3. **Configuration MT5**
- Ouvrir MetaTrader 5
- Se connecter à votre compte
- Vérifier que le symbole "Boom 1000 Index" est disponible

### Lancement du Système

#### Option 1: Script Python
```bash
python launch_boom_system.py --mode full
```

#### Option 2: Fichiers Batch (Windows)
```bash
lancer_systeme_complet.bat
```

#### Option 3: Composants séparés
```bash
# Interface uniquement
python launch_boom_system.py --mode interface

# Trading uniquement
python launch_boom_system.py --mode trading
```

## 🎛️ Utilisation

### Interface Web
1. Ouvrir http://localhost:8501 dans votre navigateur
2. Utiliser les contrôles de la sidebar pour:
   - Démarrer/arrêter le trading
   - Configurer les paramètres
   - Surveiller les positions

### Configuration des Paramètres

#### Paramètres de Trading
- **Max Positions**: Nombre maximum de positions simultanées
- **Taille Position**: Volume des trades
- **Confiance Min**: Seuil de confiance minimum pour trader

#### Paramètres de Prédiction
- **Seuil Proximité EMA**: Distance maximale pour considérer une proximité
- **Seuil Probabilité Spike**: Probabilité minimum pour générer une prédiction

### Surveillance des Prédictions

L'interface affiche en temps réel:
- **Prédictions actives** avec direction et confiance
- **Graphique interactif** avec canal haussier et EMAs
- **Positions actives** avec détails
- **Statistiques** de performance

## 📊 Algorithme de Prédiction

### 1. Détection du Canal Haussier
```python
# Identification des points pivots
pivot_points = find_pivot_points(prices, "upper")

# Calcul de la ligne de tendance
trendline = linear_regression(pivot_points)

# Validation du canal
channel = validate_rising_channel(upper_line, lower_line)
```

### 2. Analyse de Proximité EMA
```python
# Calcul des EMAs
ema10 = calculate_ema(prices, 10)
ema30 = calculate_ema(prices, 30)
ema50 = calculate_ema(prices, 50)

# Vérification de proximité
proximity = check_ema_proximity(current_price, ema_values)
```

### 3. Calcul de Probabilité
```python
# Facteurs de probabilité
ema_factor = get_ema_factor(ema_proximity)
position_factor = get_position_factor(channel_position)
channel_strength = calculate_channel_strength(channel)

# Probabilité combinée
spike_probability = base_probability * ema_factor * position_factor * channel_strength
```

## 🛡️ Gestion des Risques

### Limites de Sécurité
- **Perte quotidienne maximale**: 100 USD par défaut
- **Nombre de trades maximum**: 20 par jour
- **Positions simultanées**: 3 maximum
- **Stop Loss automatique**: 0.2% par défaut

### Monitoring en Temps Réel
- Surveillance continue des positions
- Alertes automatiques en cas de problème
- Arrêt d'urgence disponible
- Logs détaillés de toutes les opérations

## 📈 Optimisation des Performances

### Paramètres Recommandés

#### Pour Trading Conservateur
- Confiance Min: 0.85
- Probabilité Spike: 0.90
- Taille Position: 0.05
- Max Positions: 2

#### Pour Trading Agressif
- Confiance Min: 0.70
- Probabilité Spike: 0.75
- Taille Position: 0.15
- Max Positions: 5

### Amélioration Continue
- Analyse des performances passées
- Ajustement des paramètres selon les résultats
- Optimisation des seuils de prédiction
- Mise à jour des algorithmes

## 🔧 Dépannage

### Problèmes Courants

#### MT5 Non Connecté
```
Erreur: Échec de l'initialisation MT5
Solution: Vérifier que MT5 est ouvert et connecté
```

#### Symbole Non Disponible
```
Erreur: Impossible d'obtenir les données de prix
Solution: Vérifier que "Boom 1000 Index" est disponible sur votre broker
```

#### Interface Non Accessible
```
Erreur: Port 8501 occupé
Solution: Changer le port dans launch_boom_system.py
```

### Logs et Debug
- **Logs de trading**: `boom_trading.log`
- **Historique des trades**: `boom_trade_history.json`
- **Mode debug**: Ajouter `--debug` au lancement

## 📞 Support

### Documentation Technique
- Code source commenté
- Exemples d'utilisation
- Tests unitaires inclus

### Contact
- Issues GitHub pour les bugs
- Discussions pour les améliorations
- Documentation mise à jour régulièrement

## ⚠️ Avertissements

### Trading à Risque
- Le trading automatique comporte des risques
- Toujours tester en mode démo d'abord
- Ne jamais investir plus que ce que vous pouvez perdre
- Surveiller régulièrement les positions

### Responsabilité
- Ce système est fourni à des fins éducatives
- L'utilisateur est responsable de ses décisions de trading
- Les performances passées ne garantissent pas les résultats futurs

## 🎉 Conclusion

Le **Boom Rising Channel Predictor** offre une solution complète pour:
- Détecter automatiquement les patterns de canal haussier
- Prédire les spikes avec une précision élevée
- Exécuter des trades automatiquement
- Surveiller les performances en temps réel

Avec son interface moderne et ses algorithmes avancés, ce système représente un outil puissant pour les traders qui souhaitent exploiter les patterns de canal haussier sur Boom.

---

**Bonne chance avec vos trades! 🚀📈**
