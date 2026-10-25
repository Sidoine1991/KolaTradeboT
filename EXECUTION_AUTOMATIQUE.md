# 🤖 Système d'Exécution Automatique de Signaux

## Vue d'ensemble

Le système d'exécution automatique permet à MetaTrader 5 d'exécuter automatiquement les signaux générés par l'API TradBOT. Ce système surveille en continu l'API de signaux et exécute les ordres sur MT5 selon des paramètres de risque configurés.

## 🏗️ Architecture

```
API Signaux (Port 8001) → AutoSignalExecutor → MetaTrader 5
     ↓                        ↓                    ↓
Signaux JSON              Validation &         Ordres exécutés
                         Calcul position       avec SL/TP
```

## 📁 Fichiers du Système

- **`backend/auto_signal_executor.py`** - Module principal d'exécution
- **`start_auto_executor.py`** - Script de lancement
- **`lancer_auto_executor.bat`** - Script batch Windows
- **`frontend/app_real_time.py`** - Interface de contrôle dans Streamlit

## 🚀 Démarrage Rapide

### 1. Via l'Interface Streamlit
1. Lancez l'application : `streamlit run frontend/app_real_time.py`
2. Allez dans la section "🤖 Exécuteur Automatique de Signaux"
3. Configurez les paramètres de risque
4. Cliquez sur "🚀 Démarrer l'Exécuteur Automatique"

### 2. Via Script Python
```bash
python start_auto_executor.py
```

### 3. Via Script Batch (Windows)
```bash
lancer_auto_executor.bat
```

## ⚙️ Configuration

### Paramètres Principaux

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `max_risk_per_trade` | Risque maximum par trade (%) | 2% |
| `min_confidence` | Confiance minimum requise (%) | 75% |
| `max_daily_trades` | Nombre max de trades par jour | 8 |
| `check_interval` | Intervalle de vérification (s) | 5s |

### Configuration de Trading

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `default_lot_size` | Taille de lot par défaut | 0.01 |
| `max_lot_size` | Taille de lot maximum | 1.0 |
| `min_lot_size` | Taille de lot minimum | 0.01 |
| `max_spread` | Spread maximum accepté (pips) | 5 |

## 🔄 Fonctionnement

### 1. Surveillance Continue
- L'exécuteur vérifie l'API de signaux toutes les 5 secondes
- Récupère les nouveaux signaux depuis `http://localhost:8001/signals`

### 2. Validation des Signaux
- **Confiance** : Vérifie que la confiance ≥ seuil minimum
- **Timing** : Vérifie que le signal est dans sa fenêtre de validité
- **Symbole** : Vérifie que le symbole est valide
- **Direction** : Vérifie que la direction est BUY ou SELL

### 3. Calcul de Position
- **Taille de base** : 0.01 lots
- **Multiplicateur de confiance** : Jusqu'à 2x pour confiance > 50%
- **Ajustement de risque** : Réduction si stop loss > 50 pips
- **Limites** : Entre 0.01 et 1.0 lots

### 4. Exécution sur MT5
- Vérification du spread
- Envoi de l'ordre avec SL/TP
- Gestion des erreurs et retry

## 📊 Gestion des Risques

### Contrôles Automatiques
- **Limite quotidienne** : Maximum de trades par jour
- **Risque par trade** : Pourcentage maximum du capital
- **Spread** : Vérification avant exécution
- **Confiance** : Seuil minimum requis

### Calcul de Position
```python
# Taille de base
base_lot = 0.01

# Multiplicateur de confiance
confidence_multiplier = min(2.0, confidence / 0.5)

# Ajustement de risque
if stop_loss > 0:
    risk_pips = abs(entry_price - stop_loss) * 10000
    risk_multiplier = min(1.0, 50 / risk_pips)
    lot_size = base_lot * confidence_multiplier * risk_multiplier
```

## 🛡️ Sécurités

### Validation des Signaux
- Vérification de la confiance minimum
- Contrôle de la fenêtre de validité
- Validation du symbole et de la direction
- Éviter les doublons d'exécution

### Gestion des Erreurs
- Retry automatique en cas d'échec
- Logging détaillé des opérations
- Arrêt propre en cas d'erreur critique
- Gestion des déconnexions MT5

### Limites de Trading
- Limite quotidienne de trades
- Taille de position maximum
- Spread maximum accepté
- Risque maximum par trade

## 📈 Monitoring

### Statut en Temps Réel
- Nombre de trades exécutés aujourd'hui
- Signaux traités et rejetés
- Connexion MT5
- État de l'API de signaux

### Logs Détaillés
- Chaque signal traité
- Raisons de rejet
- Ordres exécutés
- Erreurs rencontrées

## 🔧 Dépannage

### Problèmes Courants

#### 1. MT5 Non Connecté
```
❌ Impossible de se connecter à MT5
```
**Solution** : Vérifiez que MetaTrader 5 est ouvert et connecté au courtier

#### 2. API de Signaux Indisponible
```
⚠️ API de signaux non disponible
```
**Solution** : Lancez l'API avec `python start_signal_api.py`

#### 3. Limite Quotidienne Atteinte
```
📊 Limite quotidienne atteinte (8 trades)
```
**Solution** : Attendez le lendemain ou augmentez la limite

#### 4. Spread Trop Élevé
```
⚠️ Spread trop élevé pour EURUSD
```
**Solution** : Attendez que le spread se réduise ou augmentez la tolérance

### Logs de Debug
```bash
# Activer les logs détaillés
export PYTHONPATH=$PYTHONPATH:.
python -c "
import logging
logging.basicConfig(level=logging.DEBUG)
from backend.auto_signal_executor import AutoSignalExecutor
"
```

## 📋 Checklist de Démarrage

- [ ] MetaTrader 5 installé et connecté
- [ ] API de signaux démarrée (port 8001)
- [ ] Capital suffisant sur le compte MT5
- [ ] Paramètres de risque configurés
- [ ] Limites de trading définies
- [ ] Monitoring activé

## ⚠️ Avertissements

### Risques
- **Exécution automatique** : Les ordres sont exécutés sans intervention humaine
- **Risque de perte** : Le trading comporte des risques de perte en capital
- **Surveillance requise** : Surveillez régulièrement les positions ouvertes

### Recommandations
- Commencez avec de petits montants
- Testez d'abord en mode démo
- Surveillez les performances
- Ajustez les paramètres selon vos besoins

## 🆘 Support

En cas de problème :
1. Vérifiez les logs dans la console
2. Consultez le statut de l'exécuteur
3. Vérifiez la connexion MT5
4. Redémarrez l'exécuteur si nécessaire

---

**Note** : Ce système est conçu pour être utilisé avec prudence. L'exécution automatique de trades comporte des risques financiers. Assurez-vous de bien comprendre le fonctionnement avant de l'utiliser avec de l'argent réel.
