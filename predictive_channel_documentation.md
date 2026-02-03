# Documentation du Canal Prédictif

## 📈 Vue d'ensemble

Le canal prédictif est une fonctionnalité d'analyse technique qui dessine un canal de tendance basé sur l'historique des prix et projette ce canal dans le futur pour générer des signaux de trading.

## 🎯 Objectif

- Identifier les tendances de marché
- Détecter les points d'entrée/sortie optimaux
- Projeter les niveaux de support/résistance futurs
- Générer des signaux avec niveaux de SL/TP

## 🔧 Fonction principale

### `draw_predictive_channel(df, symbol, lookback_period=50)`

**Paramètres :**
- `df`: DataFrame pandas avec colonnes OHLCV
- `symbol`: Symbole à analyser (ex: "EURUSD")
- `lookback_period`: Période d'analyse (défaut: 50 bougies)

**Retour :**
```python
{
    "has_channel": True,
    "symbol": "EURUSD",
    "current_price": 1.0550,
    "signal": "BUY",  # BUY, SELL, ou NEUTRAL
    "confidence": 75.5,
    "channel_info": {
        "upper_line": {
            "current": 1.0600,
            "slope": 0.0001,
            "projected": [1.0601, 1.0602, ...]
        },
        "lower_line": {
            "current": 1.0500,
            "slope": 0.0001,
            "projected": [1.0501, 1.0502, ...]
        },
        "center_line": {
            "current": 1.0550,
            "slope": 0.0001,
            "projected": [1.0551, 1.0552, ...]
        },
        "width": 0.0100,
        "position_in_channel": 0.5
    },
    "support_resistance": {
        "support": 1.0505,
        "resistance": 1.0605
    },
    "stop_loss": 1.0525,
    "take_profit": 1.0580,
    "reasoning": ["Prix au centre du canal (50.0%)", "Canal haussier (pente: 0.0001)"],
    "timestamp": "2026-02-03T16:30:00"
}
```

## 📊 Méthodologie

### 1. Analyse des tendances
- **Régression linéaire** sur les highs, lows, et closes
- Calcul des pentes pour chaque ligne de tendance
- Détermination de la largeur du canal

### 2. Projection future
- Extension des tendances sur 5 périodes futures
- Calcul des niveaux de support/résistance projetés

### 3. Génération de signaux
- **BUY** : Prix < 20% de la largeur depuis la borne inférieure
- **SELL** : Prix > 80% de la largeur depuis la borne inférieure  
- **NEUTRAL** : Prix entre 20% et 80%

### 4. Calcul de confiance
- Base : 25% par critère rempli
- Bonus : +10% si signal aligné avec la tendance
- Maximum : 95%

## 🌐 Endpoints API

### GET `/channel/predictive`
```bash
GET /channel/predictive?symbol=EURUSD&lookback_period=50
```

### POST `/channel/predictive`
```json
{
    "symbol": "EURUSD",
    "lookback_period": 50
}
```

## 📋 Cas d'utilisation

### 1. Trading de range
```python
# Si signal BUY près de la borne inférieure
if result["signal"] == "BUY" and result["confidence"] > 70:
    entry_price = result["current_price"]
    stop_loss = result["stop_loss"]
    take_profit = result["take_profit"]
```

### 2. Confirmation de tendance
```python
# Vérifier l'alignement du signal avec la pente
if result["signal"] == "BUY" and result["channel_info"]["center_line"]["slope"] > 0:
    # Signal haussier confirmé
    pass
```

### 3. Gestion du risque
```python
# Utiliser la largeur du canal pour le position sizing
channel_width = result["channel_info"]["width"]
position_size = calculate_position_size(channel_width, risk_percent)
```

## ⚠️ Limitations

- **Données requises** : Minimum `lookback_period + 10` bougies
- **Période optimale** : 50-100 bougies pour la plupart des timeframes
- **Marchés latéraux** : Moins fiable dans les marchés sans tendance claire
- **Volatilité extrême** : Peut générer des faux signaux

## 🔄 Intégration avec MT5

### Exemple d'intégration
```mql5
// Appel depuis MT5
string url = "http://localhost:8000/channel/predictive?symbol=EURUSD";
string response = HttpRequest(url);

// Parser la réponse JSON
if (JsonParse(response, result)) {
    if (result["signal"] == "BUY" && result["confidence"] > 70) {
        double sl = StringToDouble(result["stop_loss"]);
        double tp = StringToDouble(result["take_profit"]);
        // Exécuter le trade
    }
}
```

## 📈 Exemples de signaux

### Signal BUY valide
```json
{
    "signal": "BUY",
    "confidence": 85.0,
    "position_in_channel": 0.15,
    "reasoning": [
        "Prix proche de la borne inférieure du canal (15.0%)",
        "Canal haussier (pente: 0.0002)",
        "Signal aligné avec la tendance"
    ]
}
```

### Signal NEUTRAL
```json
{
    "signal": "NEUTRAL", 
    "confidence": 50.0,
    "position_in_channel": 0.45,
    "reasoning": [
        "Prix au centre du canal (45.0%)",
        "Canal latéral (pente: 0.0000)"
    ]
}
```

## 🛠️ Paramètres avancés

### `lookback_period` recommandés par timeframe :
- **M1** : 50-100
- **M5** : 50-100  
- **M15** : 30-50
- **H1** : 24-50
- **H4** : 12-24
- **D1** : 20-30

### Ajustement de la sensibilité :
- **Plus sensible** : `lookback_period = 30`
- **Moins sensible** : `lookback_period = 100`

## 📊 Performance attendue

- **Précision** : 65-75% dans les marchés tendanciels
- **Ratio risque/récompense** : 1:1.5 à 1:2
- **Fréquence des signaux** : 2-4 par jour sur M1/M5

## 🔄 Maintenance

- **Surveiller** la performance des signaux
- **Ajuster** les paramètres selon les conditions de marché
- **Combiner** avec d'autres indicateurs pour confirmation
- **Backtester** régulièrement sur différentes périodes
