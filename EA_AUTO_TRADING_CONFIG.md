# Configuration EA SpikeHunter - Trading Automatique

## 🚀 API Trend Activée

L'API Trend est maintenant disponible sur **http://localhost:8001/trend**

### Endpoints disponibles:
- `GET /trend?symbol=EURUSD&timeframe=M1` - Données de tendance
- `GET /health` - Vérification santé API
- `GET /status` - Statut détaillé

## 🤖 Améliorations EA SpikeHunter

### Trading Automatique Activé

L'EA SpikeHunter a été amélioré avec les fonctionnalités suivantes:

#### 1. Activation Automatique du Trading
```mql5
// Vérification et activation automatique du trading
if(InpEnableTrading) {
    // Activer le trading automatique dans MT5
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("❌ Trading non autorisé dans le terminal");
        return INIT_FAILED;
    }
    
    // Vérifier que le trading automatique est activé
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("❌ Trading automatique non autorisé pour les EA");
        return INIT_FAILED;
    }
    
    // Activer le trading automatique pour ce symbole
    if(!SymbolSelect(_Symbol, true)) {
        Print("❌ Impossible d'activer le symbole pour le trading");
        return INIT_FAILED;
    }
    
    Print("✅ Trading automatique ACTIVÉ pour ", _Symbol);
}
```

#### 2. Configuration Trading Sécurisé
- **Capital par trade**: $5.00 (configurable)
- **Stop Loss**: $1.00 (20% du capital)
- **Take Profit**: $1.50 (30% du capital)
- **Max trades par jour**: 20
- **Cooldown entre trades**: 5 minutes

#### 3. Gestion des Risques
- **Perte max journalière**: 2% du capital
- **Capital minimum**: $5.00
- **Vérification multi-timeframe**: Activée
- **Min timeframes alignés**: 3 sur 4

#### 4. Scalping Intelligent
- **Objectif gain rapide**: $2.00
- **Stop loss scalping**: $1.00
- **Repositionnement auto**: Activé
- **Cooldown repositionnement**: 2 minutes

## 📊 Paramètres Recommandés

### Configuration Générale
```
InpEnableTrading = true           // Activer le trading AUTONOME
InpTimeframe = PERIOD_M1          // Timeframe d'analyse
InpMagicNumber = 123456          // Magic Number
InpUserCapital = 50.0            // Capital utilisateur ($)
```

### Trading Automatique
```
InpAutoTradeOnSpike = true       // Trading AUTONOME sur les spikes
InpTrendApiUrl = "http://localhost:8001/trend"  // API tendance
InpMinPredictionConfidence = 50.0 // Confiance minimum pour trading (%)
InpScalpCloseAtSLRatio = 1.2     // Fermer gains à 120% du SL
```

### Gestion du Capital
```
InpStrictRiskMode = true         // Mode risque strict: 5$ par trade
InpFixedCapitalPerTrade = 5.0    // Capital fixe par trade (USD)
InpMaxLossPerTrade = 1.0        // Perte max par trade (USD)
InpQuickProfitTarget = 1.5       // Objectif gain rapide (USD)
InpMaxTradesPerDay = 20          // Max trades par jour
```

### Sécurité
```
InpSecureTrading = true          // Activer trading sécurisé
InpMinCapital = 5.0             // Capital minimum pour trader ($)
InpMaxDailyLossPercent = 2.0    // Perte max par jour (% du capital)
InpMinCooldownMinutes = 5       // Cooldown minimum entre trades (min)
InpTrendOnlyTrading = true      // Trader seulement avec la tendance
```

## 🔧 Démarrage

### 1. Lancer l'API Trend
```bash
# Option 1: Script Python
python trend_api.py

# Option 2: Script Batch
lancer_trend_api.bat
```

### 2. Tester l'API
```bash
python test_trend_api.py
```

### 3. Configurer l'EA dans MT5
1. Ouvrir MetaTrader 5
2. Aller dans Expert Advisors
3. Charger SpikeHunter_Simple_EA.mq5
4. Configurer les paramètres selon les recommandations
5. Activer le trading automatique
6. Démarrer l'EA

## 📈 Monitoring

L'EA affiche en temps réel:
- **Score de confiance**: 0-100%
- **Niveaux S/R**: Support et résistance
- **Signaux de trading**: BUY/SELL/HOLD
- **Statut API**: Connexion à l'API trend
- **Performance**: Trades ouverts, profit/loss

## ⚠️ Avertissements

1. **Testez d'abord en mode démo** avant le trading réel
2. **Surveillez les logs** pour détecter les erreurs
3. **Ajustez les paramètres** selon votre capital
4. **Respectez les limites** de risque configurées
5. **Vérifiez la connexion** à l'API trend

## 🎯 Objectifs

- **Trading automatique** sans intervention manuelle
- **Gestion des risques** stricte et sécurisée
- **Scalping intelligent** pour maximiser les gains
- **Intégration API** pour des signaux précis
- **Monitoring en temps réel** de la performance
