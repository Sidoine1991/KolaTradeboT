# Guide d'Intégration des Améliorations AI Server

## Vue d'Ensemble

Ce guide explique comment intégrer les fonctions améliorées de `ai_server_improvements.py` dans `ai_server.py` pour rendre les prédictions plus fiables et cohérentes avec la réalité du marché.

## Étapes d'Intégration

### Étape 1: Importer les Fonctions Améliorées

Ajouter au début de `ai_server.py` (après les imports existants):

```python
# Importer les fonctions améliorées
try:
    from ai_server_improvements import (
        calculate_advanced_confidence,
        predict_prices_advanced,
        validate_multi_timeframe,
        adapt_prediction_for_symbol,
        detect_support_resistance_levels,
        is_boom_crash_symbol,
        is_volatility_symbol
    )
    IMPROVEMENTS_AVAILABLE = True
except ImportError:
    IMPROVEMENTS_AVAILABLE = False
    logger.warning("Module ai_server_improvements non disponible - utilisation des fonctions de base")
```

### Étape 2: Remplacer `calculate_trend_confidence`

Remplacer la fonction `calculate_trend_confidence` (ligne ~2163) par:

```python
def calculate_trend_confidence(symbol: str, timeframe: str = "M1") -> float:
    """Calcule le niveau de confiance de la tendance (0-100) - Version améliorée"""
    try:
        if not mt5_initialized:
            return 50.0
        
        # Utiliser la fonction améliorée si disponible
        if IMPROVEMENTS_AVAILABLE:
            try:
                tf_map = {
                    'M1': mt5.TIMEFRAME_M1,
                    'M5': mt5.TIMEFRAME_M5,
                    'M15': mt5.TIMEFRAME_M15,
                    'H1': mt5.TIMEFRAME_H1,
                    'H4': mt5.TIMEFRAME_H4
                }
                
                mt5_timeframe = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
                rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, 100)
                
                if rates is None or len(rates) < 50:
                    return 50.0
                
                df = pd.DataFrame(rates)
                confidence_data = calculate_advanced_confidence(df, symbol, timeframe)
                
                # Convertir de 0-1 à 0-100
                return confidence_data['confidence'] * 100
            except Exception as e:
                logger.warning(f"Erreur calcul confiance améliorée: {e}, fallback vers méthode de base")
        
        # Fallback vers méthode originale
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4
        }
        
        mt5_timeframe = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, 100)
        
        if rates is None or len(rates) < 50:
            return 50.0
        
        df = pd.DataFrame(rates)
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        current_rsi = rsi.iloc[-1]
        
        sma_20 = df['close'].rolling(window=20).mean().iloc[-1]
        current_price = df['close'].iloc[-1]
        
        if current_price > sma_20 and current_rsi > 50:
            return min(90, 60 + (current_rsi - 50))
        elif current_price < sma_20 and current_rsi < 50:
            return min(90, 60 + (50 - current_rsi))
        else:
            return max(40, 70 - abs(current_rsi - 50))
            
    except Exception as e:
        logger.error(f"Erreur calcul confiance {symbol} {timeframe}: {e}")
        return 50.0
```

### Étape 3: Améliorer `predict_prices` (Endpoint `/prediction`)

Remplacer la fonction `predict_prices` (ligne ~3815) par:

```python
@app.post("/prediction")
async def predict_prices(request: PricePredictionRequest):
    """
    Prédit une série de prix futurs pour un symbole donné - Version améliorée.
    Utilisé par le robot MQ5 pour afficher les prédictions de prix sur le graphique.
    """
    try:
        symbol = request.symbol
        current_price = request.current_price
        bars_to_predict = request.bars_to_predict
        timeframe = request.timeframe
        
        logger.info(f"📊 Prédiction de prix demandée: {symbol} - {bars_to_predict} bougies - Prix actuel: {current_price}")
        
        # Utiliser la fonction améliorée si disponible
        if IMPROVEMENTS_AVAILABLE and MT5_AVAILABLE and mt5_initialized:
            try:
                import MetaTrader5 as mt5_module
                period_map = {
                    "M1": mt5_module.TIMEFRAME_M1,
                    "M5": mt5_module.TIMEFRAME_M5,
                    "M15": mt5_module.TIMEFRAME_M15,
                    "H1": mt5_module.TIMEFRAME_H1,
                    "H4": mt5_module.TIMEFRAME_H4,
                    "D1": mt5_module.TIMEFRAME_D1
                }
                
                period = period_map.get(timeframe, mt5_module.TIMEFRAME_M1)
                rates = mt5_module.copy_rates_from_pos(symbol, period, 0, min(500, bars_to_predict + 100))
                
                if rates is not None and len(rates) >= 50:
                    df = pd.DataFrame(rates)
                    df['time'] = pd.to_datetime(df['time'], unit='s')
                    
                    # Utiliser la prédiction améliorée
                    prediction_result = predict_prices_advanced(
                        df=df,
                        current_price=current_price,
                        bars_to_predict=bars_to_predict,
                        timeframe=timeframe,
                        symbol=symbol
                    )
                    
                    # Adapter selon le type de symbole
                    prediction_result = adapt_prediction_for_symbol(
                        symbol=symbol,
                        base_prediction=prediction_result,
                        df=df
                    )
                    
                    logger.info(f"✅ Prédiction améliorée générée: {len(prediction_result['prediction'])} prix pour {symbol} "
                              f"(Confiance: {prediction_result.get('confidence', 0.5):.2%}, "
                              f"Méthode: {prediction_result.get('method', 'unknown')})")
                    
                    return {
                        "prediction": prediction_result['prediction'],
                        "symbol": symbol,
                        "current_price": current_price,
                        "bars_predicted": len(prediction_result['prediction']),
                        "timeframe": timeframe,
                        "timestamp": datetime.now().isoformat(),
                        "confidence": prediction_result.get('confidence', 0.5),
                        "direction": prediction_result.get('direction', 'NEUTRAL'),
                        "support_levels": prediction_result.get('support_levels', []),
                        "resistance_levels": prediction_result.get('resistance_levels', []),
                        "method": prediction_result.get('method', 'advanced')
                    }
            except Exception as e:
                logger.warning(f"Erreur prédiction améliorée: {e}, fallback vers méthode de base")
        
        # Fallback vers méthode originale (code existant)
        prices = []
        if MT5_AVAILABLE and mt5_initialized:
            try:
                import MetaTrader5 as mt5_module
                period_map = {
                    "M1": mt5_module.TIMEFRAME_M1,
                    "M5": mt5_module.TIMEFRAME_M5,
                    "M15": mt5_module.TIMEFRAME_M15,
                    "H1": mt5_module.TIMEFRAME_H1,
                    "H4": mt5_module.TIMEFRAME_H4,
                    "D1": mt5_module.TIMEFRAME_D1
                }
                
                period = period_map.get(timeframe, mt5_module.TIMEFRAME_M1)
                rates = mt5_module.copy_rates_from_pos(symbol, period, 0, min(100, bars_to_predict + 50))
                
                if rates is not None and len(rates) > 0:
                    recent_prices = [rate['close'] for rate in rates[-20:]]
                    if len(recent_prices) >= 2:
                        price_change = (recent_prices[-1] - recent_prices[0]) / len(recent_prices)
                        volatility = np.std(recent_prices) if len(recent_prices) > 1 else abs(price_change) * 0.01
                    else:
                        price_change = 0.0
                        volatility = current_price * 0.01
                    
                    np.random.seed(int(current_price * 1000) % 2**31)
                    for i in range(bars_to_predict):
                        trend_component = price_change * (1.0 - i / bars_to_predict)
                        noise = np.random.normal(0, volatility * 0.1)
                        predicted_price = current_price + (trend_component * i) + noise
                        prices.append(float(predicted_price))
                else:
                    np.random.seed(int(current_price * 1000) % 2**31)
                    volatility = current_price * 0.005
                    for i in range(bars_to_predict):
                        noise = np.random.normal(0, volatility)
                        prices.append(float(current_price + noise))
                        
            except Exception as e:
                logger.warning(f"Erreur lors de la récupération des données MT5 pour prédiction: {e}")
                np.random.seed(int(current_price * 1000) % 2**31)
                volatility = current_price * 0.005
                for i in range(bars_to_predict):
                    noise = np.random.normal(0, volatility)
                    prices.append(float(current_price + noise))
        else:
            np.random.seed(int(current_price * 1000) % 2**31)
            volatility = current_price * 0.005
            for i in range(bars_to_predict):
                noise = np.random.normal(0, volatility)
                prices.append(float(current_price + noise))
        
        if len(prices) == 0:
            prices = [float(current_price)] * bars_to_predict
        
        logger.info(f"✅ Prédiction générée (méthode de base): {len(prices)} prix pour {symbol}")
        
        return {
            "prediction": prices,
            "symbol": symbol,
            "current_price": current_price,
            "bars_predicted": len(prices),
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "confidence": 0.5,
            "method": "fallback"
        }
        
    except Exception as e:
        logger.error(f"Erreur dans /prediction: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur lors de la prédiction de prix: {str(e)}")
```

### Étape 4: Ajouter Validation Multi-Timeframe dans `/trend`

Modifier la fonction `get_trend_analysis` (ligne ~2211) pour inclure la validation multi-timeframe:

```python
@app.post("/trend")
async def get_trend_analysis(request: TrendAnalysisRequest):
    """Endpoint principal pour l'analyse de tendance (compatible avec MT5) - Version améliorée"""
    try:
        logger.info(f"Analyse de tendance demandée pour {request.symbol}")
        
        response = {
            "symbol": request.symbol,
            "timestamp": time.time()
        }
        
        # Validation multi-timeframe si disponible
        if IMPROVEMENTS_AVAILABLE and mt5_initialized:
            try:
                import MetaTrader5 as mt5_module
                multi_tf_validation = validate_multi_timeframe(
                    symbol=request.symbol,
                    timeframes=request.timeframes,
                    mt5_module=mt5_module,
                    mt5_initialized=mt5_initialized
                )
                response['multi_timeframe'] = {
                    'consensus': multi_tf_validation['consensus'],
                    'is_valid': multi_tf_validation['is_valid'],
                    'avg_confidence': multi_tf_validation.get('avg_confidence', 0.0),
                    'reason': multi_tf_validation.get('reason', '')
                }
            except Exception as e:
                logger.warning(f"Erreur validation multi-timeframe: {e}")
        
        # Analyser chaque timeframe demandé
        for tf in request.timeframes:
            direction = calculate_trend_direction(request.symbol, tf)
            confidence = calculate_trend_confidence(request.symbol, tf)
            
            response[tf] = {
                "direction": direction,
                "confidence": confidence
            }
        
        logger.info(f"Tendance {request.symbol}: {response.get('M1', {}).get('direction', 'unknown')} "
                   f"(conf: {response.get('M1', {}).get('confidence', 0):.1f}%)")
        return response
        
    except Exception as e:
        logger.error(f"Erreur analyse tendance: {e}")
        return {
            "error": f"Erreur lors de l'analyse de tendance: {str(e)}",
            "symbol": request.symbol,
            "timestamp": time.time()
        }
```

## Tests et Validation

### Test 1: Vérifier l'Import

```python
python -c "from ai_server_improvements import calculate_advanced_confidence; print('OK')"
```

### Test 2: Tester la Prédiction Améliorée

```python
import pandas as pd
import numpy as np
from ai_server_improvements import predict_prices_advanced

# Créer des données de test
dates = pd.date_range('2024-01-01', periods=100, freq='1min')
df = pd.DataFrame({
    'time': dates,
    'open': np.random.randn(100).cumsum() + 100,
    'high': np.random.randn(100).cumsum() + 101,
    'low': np.random.randn(100).cumsum() + 99,
    'close': np.random.randn(100).cumsum() + 100,
    'volume': np.random.randint(1000, 10000, 100)
})

result = predict_prices_advanced(df, 100.0, 50, "M1", "EURUSD")
print(f"Confiance: {result['confidence']}")
print(f"Direction: {result['direction']}")
print(f"Supports: {result['support_levels']}")
print(f"Résistances: {result['resistance_levels']}")
```

### Test 3: Tester avec le Serveur

1. Démarrer le serveur: `python ai_server.py`
2. Tester l'endpoint `/prediction`:
```bash
curl -X POST "http://localhost:8000/prediction" \
  -H "Content-Type: application/json" \
  -d '{"symbol": "EURUSD", "current_price": 1.1000, "bars_to_predict": 200, "timeframe": "M1"}'
```

3. Vérifier que la réponse contient `confidence`, `direction`, `support_levels`, `resistance_levels`

## Monitoring et Ajustements

### Métriques à Surveiller

1. **Taux de Précision**: Comparer les prédictions avec les prix réels
2. **Cohérence Multi-Timeframe**: Vérifier que les signaux sont cohérents
3. **Confiance Calibrée**: S'assurer que la confiance reflète la précision réelle
4. **Performance par Type de Symbole**: Comparer Boom/Crash vs Forex

### Ajustements Possibles

1. **Poids des Indicateurs**: Ajuster les poids dans `calculate_advanced_confidence`
2. **Seuils de Consensus**: Modifier les seuils dans `validate_multi_timeframe`
3. **Multiplicateurs de Volatilité**: Ajuster pour Boom/Crash selon les résultats

## Rollback

Si les améliorations causent des problèmes, vous pouvez facilement revenir en arrière en définissant:

```python
IMPROVEMENTS_AVAILABLE = False
```

Cela activera automatiquement les fonctions de base.

