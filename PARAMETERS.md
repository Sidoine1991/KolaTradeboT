# Guide d'Optimisation des Paramètres TradBOT

**Version:** 2.1.0  
**Objectif:** Maximiser profits journaliers (50$) et minimiser pertes

---

## 📊 Paramètres Serveur IA (ai_server.py)

### Détection de Spikes

| Paramètre | Valeur Actuelle | Recommandé | Plage Test | Impact |
|-----------|----------------|------------|------------|--------|
| `spike_score_threshold` | 0.80 | **0.78** | 0.75-0.85 | Fiabilité signaux |
| `volatility_min` | 0.003 | **0.0025** | 0.002-0.004 | Sensibilité |
| `rsi_extreme_buy` | 20 | **18** | 15-25 | Survente |
| `rsi_extreme_sell` | 80 | **82** | 75-85 | Surachat |
| `confluence_weight` | 0.20 | **0.22** | 0.15-0.25 | Tendance |

**Explication:**
- **spike_score_threshold**: Seuil de validation du score de spike (0-1)
  - Plus bas = Plus de signaux mais moins fiables
  - Plus haut = Moins de signaux mais plus fiables
  - **Recommandé 0.78** pour équilibre qualité/quantité

- **volatility_min**: Volatilité minimale requise (ATR/Prix)
  - Boom/Crash: 0.003 (0.3%)
  - Volatility: 0.0025 (0.25%)
  - Step Index: 0.002 (0.2%)

---

### Scoring Multi-Critères

| Indicateur | Poids Actuel | Recommandé | Justification |
|-----------|--------------|------------|---------------|
| Tendance H1 | 0.20 | **0.22** | Tendance principale |
| Tendance M1 | 0.15 | **0.15** | Confirmation court terme |
| RSI | 0.15 | **0.18** | Momentum fort |
| VWAP | 0.12 | **0.12** | Prix d'équilibre |
| SuperTrend | 0.12 | **0.10** | Tendance moderne |
| Volatilité | 0.10 | **0.10** | Conditions marché |
| Confluence EMA | 0.10 | **0.08** | Alignement |
| Régime ATR | 0.06 | **0.05** | Contexte volatilité |

**Total:** 1.00 (100%)

**Ajustements selon symbole:**

```python
# Boom/Crash (privilégier momentum)
weights_boom_crash = {
    'rsi': 0.25,          # +10%
    'volatility': 0.15,   # +5%
    'trend_h1': 0.18,     # -2%
    'vwap': 0.10,         # -2%
    # ... autres inchangés
}

# Volatility (privilégier tendance)
weights_volatility = {
    'trend_h1': 0.25,     # +3%
    'trend_m1': 0.18,     # +3%
    'rsi': 0.15,          # -3%
    'volatility': 0.07,   # -3%
    # ... autres inchangés
}
```

---

### Cache Intelligent

| Paramètre | Valeur Actuelle | Recommandé | Plage Test | Impact |
|-----------|----------------|------------|------------|--------|
| `default_ttl` | 30s | **20s** | 15-60s | Fraîcheur données |
| `volatility_change_threshold` | 0.20 | **0.15** | 0.10-0.30 | Invalidation cache |
| `max_cache_age` | 3600s | **1800s** | 1800-7200s | Nettoyage |

**Logique d'invalidation:**
```python
# Invalider si:
1. Volatilité change > 15% (au lieu de 20%)
2. TTL > 20s (au lieu de 30s)
3. Spike détecté (invalidation immédiate)
4. News économique majeure (à implémenter)
```

---

## 🎯 Paramètres MQL5 EA (F_INX_robot4.mq5)

### Risk Management

| Paramètre | Valeur Actuelle | Recommandé | Plage Test | Justification |
|-----------|----------------|------------|------------|---------------|
| `RiskPercent` | 1.0% | **0.8%** | 0.5-2.0% | Réduire risque |
| `FixedLotSize` | 0.1 | **0.08** | 0.05-0.15 | Si RiskPercent=0 |
| `MaxLotSize` | 5.0 | **3.0** | 2.0-5.0 | Limiter exposition |
| `DailyProfitTarget` | 50.0$ | **50.0$** | 40-60$ | Objectif validé |
| `DailyLossLimit` | 200.0$ | **100.0$** | 80-150$ | Protection capital |
| `MinRiskReward` | 1.5 | **2.0** | 1.8-2.5 | Meilleur R:R |
| `MaxConsecLosses` | 5 | **3** | 3-5 | Pause plus tôt |

**Formule de calcul du lot:**

```cpp
// Actuelle (simple)
double lot = (AccountBalance() * RiskPercent / 100) / (atr * 2);

// Recommandée (adaptative)
double baseLot = (AccountBalance() * RiskPercent / 100) / (atr * 2);
double winRateMultiplier = CalculateWinRateMultiplier();
double volAdjustment = CalculateVolatilityAdjustment(atr);

double lot = baseLot * winRateMultiplier * volAdjustment;
lot = MathMin(lot, MaxLotSize);
lot = MathMax(lot, 0.01);
```

**Multiplicateurs:**
```cpp
double CalculateWinRateMultiplier()
{
   double winRate = CalculateWinRate(); // %
   
   if(winRate > 60.0)
      return 1.2;  // Augmenter si bonne série
   else if(winRate < 40.0)
      return 0.7;  // Réduire si mauvaise série
   else
      return 1.0;  // Normal
}

double CalculateVolatilityAdjustment(double atr)
{
   double volatility = atr / SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(volatility > 0.003)
      return 0.8;  // Réduire en haute volatilité
   else if(volatility < 0.001)
      return 0.6;  // Réduire en basse volatilité
   else
      return 1.0;  // Normal
}
```

---

### Stops et Targets

| Paramètre | Valeur Actuelle | Recommandé | Plage Test | Impact |
|-----------|----------------|------------|------------|--------|
| `TP_ATR_Mult` | 8.0 | **7.5** | 6.0-10.0 | Take Profit |
| `SL_ATR_Mult` | 2.0 | **2.2** | 1.5-3.0 | Stop Loss |
| `BE_ATR_Mult` | 0.8 | **1.0** | 0.8-1.5 | Break Even |
| `BE_Offset` | 10 pts | **15 pts** | 10-20 pts | Sécurité BE |
| `Trail_ATR_Mult` | 0.6 | **Dynamique** | - | Voir tableau |

**Trailing Stop Dynamique (Recommandé):**

| Profit Atteint | SL Position | Exemple (ATR=100 pts) |
|----------------|-------------|----------------------|
| < 1.0× ATR | Pas de trail | SL initial |
| 1.0× ATR | Break-even | SL = Entry + 15 pts |
| 2.0× ATR | 50% du gain | SL = Entry + 100 pts |
| 3.0× ATR | 70% du gain | SL = Entry + 210 pts |
| 5.0× ATR | 80% du gain | SL = Entry + 400 pts |

**Code proposé:**
```cpp
void UpdateTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double currentSL = PositionGetDouble(POSITION_SL);
   double atr = iATR(_Symbol, PERIOD_H1, 14);
   
   double profit = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                   (currentPrice - entryPrice) : (entryPrice - currentPrice);
   
   double newSL = 0;
   
   if(profit >= atr * 5.0)
      newSL = entryPrice + (profit * 0.8);
   else if(profit >= atr * 3.0)
      newSL = entryPrice + (profit * 0.7);
   else if(profit >= atr * 2.0)
      newSL = entryPrice + (profit * 0.5);
   else if(profit >= atr * 1.0)
      newSL = entryPrice + (BE_Offset * _Point);
   
   if(newSL > currentSL && newSL > 0)
      ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
}
```

---

### Filtres et Protection

| Paramètre | Valeur Actuelle | Recommandé | Plage Test | Justification |
|-----------|----------------|------------|------------|---------------|
| `MaxSpread` | 100 pts | **50 pts** | 30-100 pts | Réduire slippage |
| `MaxSimultaneousSymbols` | 2 | **3** | 2-4 | Diversification |
| `GlobalLossLimit` | -3.0$ | **-5.0$** | -3 à -8$ | Protection globale |
| `LossCutDollars` | 2.0$ | **3.0$** | 2-5$ | SL par position |
| `ProfitSecureDollars` | 2.0$ | **2.5$** | 2-4$ | TP partiel |
| `MinPositionLifetimeSec` | 60s | **90s** | 60-180s | Éviter scalp trop rapide |

**Filtre Spread Dynamique:**
```cpp
bool IsSpreadAcceptable()
{
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = iATR(_Symbol, PERIOD_H1, 14);
   
   // Spread ne doit pas dépasser 2× ATR
   if(spread > atr * 2.0)
      return false;
   
   // Spread ne doit pas dépasser 0.1% du prix
   double spreadPct = (spread / SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 100;
   if(spreadPct > 0.1)
      return false;
   
   return true;
}
```

---

### Ordres Limit Globaux

| Paramètre | Valeur Actuelle | Recommandé | Plage Test | Impact |
|-----------|----------------|------------|------------|--------|
| `UseGlobalLimitOrders` | true | **true** | - | Activer |
| `GlobalLimitAtrMult` | 0.8 | **1.0** | 0.8-1.5 | Distance |
| `GlobalLimitMinPoints` | 50 pts | **80 pts** | 50-150 pts | Distance min |
| `GlobalLimitExpirySec` | 300s | **600s** | 300-900s | Expiration |
| `UseTrendFilterForLimits` | false | **true** | - | Filtrer contre-tendance |

**Logique recommandée:**
```cpp
// Ne placer BUY LIMIT que si tendance haussière
if(UseTrendFilterForLimits && g_trendDirection == "bearish")
   canPlaceBuyLimit = false;

// Ne placer SELL LIMIT que si tendance baissière
if(UseTrendFilterForLimits && g_trendDirection == "bullish")
   canPlaceSellLimit = false;

// Restrictions Boom/Crash
if(StringFind(_Symbol, "Boom") != -1)
   canPlaceSellLimit = false;  // Jamais SELL LIMIT sur Boom

if(StringFind(_Symbol, "Crash") != -1)
   canPlaceBuyLimit = false;   // Jamais BUY LIMIT sur Crash
```

---

## 🔧 Paramètres par Symbole

### Volatility 75/100 Index

```cpp
// Paramètres optimaux
RiskPercent = 0.8;
TP_ATR_Mult = 7.0;
SL_ATR_Mult = 2.0;
MinRiskReward = 2.0;

// Heures de trading
PreferredHours = {9, 10, 11, 12, 13, 14, 15, 16, 17, 18};
ForbiddenHours = {22, 23, 0, 1, 2, 3, 4, 5};

// Filtres
MaxSpread = 40 pts;
MinATR = 0.0015;  // 0.15%
MaxATR = 0.0050;  // 0.50%
```

### Boom 500/1000 Index

```cpp
// Paramètres optimaux
RiskPercent = 0.6;  // Plus conservateur
TP_ATR_Mult = 8.0;  // TP plus large
SL_ATR_Mult = 2.5;  // SL plus large
MinRiskReward = 2.5;

// Heures de trading
PreferredHours = {8, 9, 10, 11, 14, 15, 16, 17};
ForbiddenHours = {0, 1, 2, 3, 4, 5, 22, 23};

// Filtres
MaxSpread = 60 pts;
MinATR = 0.0025;  // 0.25%
MaxATR = 0.0080;  // 0.80%

// Spécifique Boom
UseDynamicSL = true;
SL_Profit_Level1 = 0.20;  // Modifier SL plus tôt
MaxSLModifications = 4;
```

### Crash 500/1000 Index

```cpp
// Paramètres optimaux
RiskPercent = 0.6;
TP_ATR_Mult = 8.0;
SL_ATR_Mult = 2.5;
MinRiskReward = 2.5;

// Heures de trading
PreferredHours = {8, 9, 10, 11, 14, 15, 16, 17};
ForbiddenHours = {0, 1, 2, 3, 4, 5, 22, 23};

// Filtres
MaxSpread = 60 pts;
MinATR = 0.0025;
MaxATR = 0.0080;

// Spécifique Crash
UseDynamicSL = true;
SL_Profit_Level1 = 0.20;
MaxSLModifications = 4;
```

### Step Index

```cpp
// Paramètres optimaux
RiskPercent = 0.7;
TP_ATR_Mult = 6.0;  // TP plus court
SL_ATR_Mult = 2.0;
MinRiskReward = 1.8;

// Heures de trading
PreferredHours = {9, 10, 11, 12, 13, 14, 15, 16};
ForbiddenHours = {22, 23, 0, 1, 2, 3, 4, 5};

// Filtres
MaxSpread = 50 pts;
MinATR = 0.0020;
MaxATR = 0.0060;
```

---

## 📈 Optimisation par Backtesting

### Méthode Grid Search

**Étape 1: Paramètres Individuels**
```python
# Tester chaque paramètre séparément
parameters_to_test = {
    'RiskPercent': [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.5, 2.0],
    'TP_ATR_Mult': [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 10.0],
    'SL_ATR_Mult': [1.5, 1.8, 2.0, 2.2, 2.5, 3.0],
    'MinRiskReward': [1.5, 1.8, 2.0, 2.2, 2.5]
}

for param, values in parameters_to_test.items():
    for value in values:
        results = run_backtest(param=value)
        save_results(param, value, results)
```

**Étape 2: Combinaisons Prometteuses**
```python
# Tester les 3 meilleures valeurs de chaque paramètre ensemble
best_combinations = itertools.product(
    [0.7, 0.8, 0.9],  # RiskPercent
    [7.0, 7.5, 8.0],  # TP_ATR_Mult
    [2.0, 2.2, 2.5],  # SL_ATR_Mult
    [1.8, 2.0, 2.2]   # MinRiskReward
)

for combo in best_combinations:
    results = run_backtest(combo)
    save_results(combo, results)
```

**Étape 3: Validation Croisée**
```python
# Tester la meilleure configuration sur périodes différentes
best_config = find_best_configuration()

periods = [
    ('2024-07-01', '2024-09-30'),  # Q3 2024
    ('2024-10-01', '2024-12-31'),  # Q4 2024
    ('2024-04-01', '2024-06-30')   # Q2 2024
]

for start, end in periods:
    results = run_backtest(best_config, start, end)
    validate_consistency(results)
```

---

### Métriques de Sélection

**Fonction Objectif (à maximiser):**
```python
def objective_function(results):
    """
    Score composite pour sélectionner la meilleure configuration
    """
    # Poids des métriques
    weights = {
        'sharpe_ratio': 0.30,
        'profit_factor': 0.25,
        'win_rate': 0.20,
        'target_success_rate': 0.15,  # % jours 50$ atteint
        'max_drawdown': 0.10  # Pénalité
    }
    
    score = (
        results['sharpe_ratio'] * weights['sharpe_ratio'] +
        results['profit_factor'] * weights['profit_factor'] +
        (results['win_rate'] / 100) * weights['win_rate'] +
        (results['target_success_rate'] / 100) * weights['target_success_rate'] -
        (results['max_drawdown'] / 100) * weights['max_drawdown']
    )
    
    return score
```

**Critères de Validation:**
```python
def is_configuration_valid(results):
    """
    Vérifie si une configuration respecte les contraintes minimales
    """
    return (
        results['win_rate'] >= 60.0 and
        results['profit_factor'] >= 2.0 and
        results['max_drawdown'] <= 12.0 and
        results['sharpe_ratio'] >= 1.5 and
        results['target_success_rate'] >= 70.0  # 70% jours 50$ atteint
    )
```

---

## 🎯 Configuration Recommandée Finale

### Serveur IA
```python
# ai_server.py - Configuration optimale
SPIKE_DETECTION = {
    'score_threshold': 0.78,
    'volatility_min': 0.0025,
    'rsi_extreme_buy': 18,
    'rsi_extreme_sell': 82,
    'confluence_weight': 0.22
}

MULTI_CRITERIA_WEIGHTS = {
    'trend_h1': 0.22,
    'trend_m1': 0.15,
    'rsi': 0.18,
    'vwap': 0.12,
    'supertrend': 0.10,
    'volatility': 0.10,
    'ema_confluence': 0.08,
    'atr_regime': 0.05
}

CACHE_CONFIG = {
    'default_ttl': 20,
    'volatility_threshold': 0.15,
    'max_age': 1800
}
```

### MQL5 EA
```cpp
// F_INX_robot4.mq5 - Configuration optimale
input double RiskPercent = 0.8;
input double MinRiskReward = 2.0;
input double DailyProfitTarget = 50.0;
input double DailyLossLimit = 100.0;
input int MaxConsecLosses = 3;

input double TP_ATR_Mult = 7.5;
input double SL_ATR_Mult = 2.2;
input double BE_ATR_Mult = 1.0;
input int BE_Offset = 15;

input int MaxSpread = 50;
input int MaxSimultaneousSymbols = 3;
input double GlobalLossLimit = -5.0;
input int MinPositionLifetimeSec = 90;

input bool UseGlobalLimitOrders = true;
input double GlobalLimitAtrMult = 1.0;
input int GlobalLimitMinPoints = 80;
input bool UseTrendFilterForLimits = true;
```

---

**Note:** Ces paramètres sont des recommandations basées sur l'analyse du code. Ils doivent être validés par backtesting sur vos données réelles avant utilisation en production.

**Auteur:** Kombai AI Assistant  
**Dernière mise à jour:** 22/12/2024