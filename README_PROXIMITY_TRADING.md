# Système de Trading par Proximité des Supports/Résistances

## 🎯 Description

Ce système de trading automatique exécute des trades basés sur la proximité des niveaux de support et résistance :

- **SELL** quand le prix est proche d'une **résistance** (pour un Crash)
- **BUY** quand le prix est proche d'un **support** (pour un Boom)

## 🚀 Fonctionnalités

### Détection des Niveaux
- **Swing Highs/Lows** : Détection des points de retournement
- **Pivot Points** : Niveaux de support/résistance classiques
- **Niveaux Psychologiques** : Nombres ronds (1000, 2000, etc.)
- **Niveaux de Volume** : Zones de forte activité

### Calcul de Proximité
- Distance en pourcentage du prix actuel
- Seuil de proximité configurable (défaut: 0.2%)
- Validation de la force et confiance des niveaux

### Gestion des Risques
- Limite de positions simultanées
- Limite de perte quotidienne
- Limite de trades quotidiens
- Validation des distances SL/TP

## 📁 Fichiers du Système

### Fichiers Principaux
- `proximity_trading_system.py` - Système principal
- `test_proximity_trading.py` - Tests du système
- `demo_proximity_trading.py` - Démonstration
- `proximity_trading_config.json` - Configuration

### Scripts de Lancement
- `lancer_proximity_trading.bat` - Lance le système
- `tester_proximity_trading.bat` - Lance les tests
- `demo_proximity_trading.bat` - Lance la démonstration

## ⚙️ Configuration

### Paramètres de Trading
```json
{
  "trading": {
    "max_positions": 2,
    "lot_size": 0.01,
    "max_daily_loss": 10.0,
    "max_daily_trades": 10
  }
}
```

### Paramètres de Proximité
```json
{
  "proximity": {
    "threshold": 0.002,    // 0.2% du prix
    "min_strength": 0.6,    // Force minimale
    "min_confidence": 0.7   // Confiance minimale
  }
}
```

## 🎮 Utilisation

### 1. Démonstration
```bash
demo_proximity_trading.bat
```
Montre comment le système détecte les niveaux et génère les signaux.

### 2. Tests
```bash
tester_proximity_trading.bat
```
Valide le fonctionnement du système.

### 3. Lancement
```bash
lancer_proximity_trading.bat
```
Démarre le système de trading en mode réel.

## 🔧 Fonctionnement

### Workflow du Système

1. **📊 Analyse des Données**
   - Récupération des données M1
   - Calcul des indicateurs techniques
   - Détection des patterns

2. **🎯 Détection des Niveaux**
   - Swing highs/lows
   - Pivot points
   - Niveaux psychologiques
   - Niveaux de volume

3. **📏 Calcul de Proximité**
   - Distance prix actuel ↔ niveaux
   - Validation des seuils
   - Calcul de la confiance

4. **🚦 Génération des Signaux**
   - BUY près d'un support
   - SELL près d'une résistance
   - Validation SL/TP

5. **⚡ Exécution des Trades**
   - Vérification des limites
   - Envoi des ordres MT5
   - Suivi des positions

6. **🛡️ Gestion des Risques**
   - Surveillance des positions
   - Respect des limites
   - Fermeture automatique

## 📊 Exemples de Signaux

### Signal BUY (Boom)
```
Prix actuel: 1000.0
Support détecté: 998.5
Distance: 0.15% (proche)
→ Signal BUY à 1000.0
→ SL: 995.0, TP: 1010.0
```

### Signal SELL (Crash)
```
Prix actuel: 1000.0
Résistance détectée: 1001.5
Distance: 0.15% (proche)
→ Signal SELL à 1000.0
→ SL: 1005.0, TP: 990.0
```

## ⚠️ Gestion des Risques

### Limites Automatiques
- **Positions max** : 2 simultanées
- **Perte quotidienne** : 10$ maximum
- **Trades quotidiens** : 10 maximum
- **Taille de lot** : 0.01 (configurable)

### Validation des Distances
- Distance SL minimale : 10 points
- Distance TP minimale : 10 points
- Validation des stop levels MT5

## 📈 Avantages

### Précision
- Détection multi-méthodes
- Validation croisée des niveaux
- Calcul de confiance

### Sécurité
- Limites de risque strictes
- Validation des distances
- Surveillance continue

### Flexibilité
- Configuration personnalisable
- Support multi-symboles
- Logs détaillés

## 🚨 Avertissements

### Risques
- Le trading comporte des risques de perte
- Tester d'abord en mode démo
- Surveiller les positions actives

### Recommandations
- Commencer avec de petits lots
- Tester la configuration
- Surveiller les logs

## 📝 Logs

### Fichiers de Log
- `proximity_trading.log` - Logs du système
- Rotation automatique des logs
- Niveaux de log configurables

### Informations Loggées
- Détection des niveaux
- Génération des signaux
- Exécution des trades
- Gestion des risques

## 🔄 Maintenance

### Surveillance
- Vérifier les logs régulièrement
- Surveiller les performances
- Ajuster la configuration si nécessaire

### Mise à Jour
- Sauvegarder la configuration
- Tester les modifications
- Redémarrer le système

## 📞 Support

### En Cas de Problème
1. Vérifier les logs
2. Tester la configuration
3. Redémarrer le système
4. Contacter le support

### Configuration Recommandée
- MT5 connecté et fonctionnel
- Compte de démonstration pour tests
- Configuration de base pour débuter

---

**⚠️ IMPORTANT** : Ce système est fourni à des fins éducatives. Le trading comporte des risques de perte. Testez toujours en mode démo avant d'utiliser en mode réel.
