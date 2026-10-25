#!/usr/bin/env python3
"""
Intégration Boom Rising Channel Predictor dans l'API existante
Modifie l'API principale pour inclure les endpoints Boom
"""

import os
import sys
from pathlib import Path

def integrate_boom_endpoints():
    """Intègre les endpoints Boom dans l'API existante"""
    
    # Chemin vers l'API principale
    api_main_path = Path("backend/api/main.py")
    
    if not api_main_path.exists():
        print("❌ Fichier backend/api/main.py non trouvé")
        return False
    
    # Lire le contenu actuel
    with open(api_main_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Vérifier si l'intégration existe déjà
    if "boom_rising_channel_predictor" in content:
        print("✅ Intégration Boom déjà présente")
        return True
    
    # Code d'intégration à ajouter
    boom_integration = '''
# --- Intégration Boom Rising Channel Predictor ---
try:
    from boom_rising_channel_predictor import (
        boom_predictor,
        get_boom_prediction,
        update_boom_data,
        get_boom_summary
    )
    from boom_config import get_config
    BOOM_PREDICTOR_AVAILABLE = True
    print("✅ Boom Rising Channel Predictor intégré")
except ImportError as e:
    BOOM_PREDICTOR_AVAILABLE = False
    print(f"⚠️ Boom Rising Channel Predictor non disponible: {e}")

@app.get("/boom/predict")
async def get_boom_prediction_endpoint(
    symbol: str = Query("Boom 1000 Index"),
    timeframe: str = Query("M1")
):
    """Endpoint Boom Rising Channel Predictor"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        prediction = get_boom_prediction()
        
        if not prediction:
            return {
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": time.time(),
                "action": "HOLD",
                "direction": "NEUTRAL",
                "confidence": 0.0,
                "spike_probability": 0.0,
                "error": "Aucune prédiction disponible"
            }
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "action": prediction.get('action', 'HOLD'),
            "direction": prediction.get('direction', 'NEUTRAL'),
            "confidence": prediction.get('confidence', 0.0),
            "spike_probability": prediction.get('spike_probability', 0.0),
            "time_to_spike": prediction.get('time_to_spike', 0),
            "ema_proximity": prediction.get('ema_proximity', 'N/A'),
            "channel_position": prediction.get('channel_position', 'N/A'),
            "current_price": prediction.get('current_price', 0.0),
            "stop_loss": prediction.get('stop_loss', 0.0),
            "take_profit": prediction.get('take_profit', 0.0),
            "lot_size": prediction.get('lot_size', 0.1),
            "reasoning": prediction.get('reasoning', 'Analyse canal haussier Boom')
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur prédiction Boom: {str(e)}")

@app.get("/boom/status")
async def get_boom_status_endpoint():
    """Statut du système Boom Rising Channel Predictor"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        summary = get_boom_summary()
        
        return {
            "status": "running",
            "summary": summary,
            "active_predictions": len(boom_predictor.prediction_arrows),
            "active_channels": len(boom_predictor.rising_channels),
            "success_rate": boom_predictor.success_rate,
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur statut Boom: {str(e)}")

@app.get("/boom/config")
async def get_boom_config_endpoint():
    """Configuration du système Boom"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        config = {
            "boom": get_config('boom'),
            "ema": get_config('ema'),
            "channel": get_config('channel'),
            "prediction": get_config('prediction'),
            "trading": get_config('trading')
        }
        
        return {
            "status": "ok",
            "config": config,
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur configuration Boom: {str(e)}")

@app.get("/trend")
async def get_trend_with_boom(symbol: str, timeframe: str = "M1"):
    """Endpoint trend amélioré avec support Boom"""
    try:
        # Si c'est un symbole Boom, utiliser le prédicteur spécialisé
        if "Boom" in symbol and BOOM_PREDICTOR_AVAILABLE:
            prediction = get_boom_prediction()
            
            if prediction:
                return {
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "timestamp": time.time(),
                    "direction": prediction.get('direction', 'NEUTRAL'),
                    "strength": int(prediction.get('confidence', 0) * 100),
                    "confidence": int(prediction.get('spike_probability', 0) * 100),
                    "signal": f"boom_{prediction.get('action', 'HOLD').lower()}",
                    "trend": prediction.get('direction', 'neutral').lower(),
                    "spike_probability": prediction.get('spike_probability', 0),
                    "time_to_spike": prediction.get('time_to_spike', 0),
                    "ema_proximity": prediction.get('ema_proximity', 'N/A'),
                    "channel_position": prediction.get('channel_position', 'N/A'),
                    "current_price": prediction.get('current_price', 0),
                    "stop_loss": prediction.get('stop_loss', 0),
                    "take_profit": prediction.get('take_profit', 0),
                    "reasoning": prediction.get('reasoning', 'Analyse canal haussier Boom')
                }
        
        # Fallback vers l'ancienne méthode pour les autres symboles
        return await get_trend_original(symbol, timeframe)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur trend: {str(e)}")

# --- Fin intégration Boom Rising Channel Predictor ---
'''
    
    # Trouver l'endroit pour insérer le code (après les imports)
    insert_position = content.find("app = FastAPI(")
    if insert_position == -1:
        print("❌ Impossible de trouver la position d'insertion")
        return False
    
    # Insérer le code d'intégration
    new_content = content[:insert_position] + boom_integration + content[insert_position:]
    
    # Créer une sauvegarde
    backup_path = api_main_path.with_suffix('.py.backup')
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Sauvegarde créée: {backup_path}")
    
    # Écrire le nouveau contenu
    with open(api_main_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✅ Intégration Boom Rising Channel Predictor ajoutée à l'API principale")
    return True

def create_boom_endpoints_file():
    """Crée un fichier séparé avec les endpoints Boom"""
    
    boom_endpoints_content = '''#!/usr/bin/env python3
"""
Endpoints Boom Rising Channel Predictor
Fichier séparé pour l'intégration avec l'API principale
"""

from fastapi import APIRouter, HTTPException, Query
import time

# Import du système Boom Rising Channel Predictor
try:
    from boom_rising_channel_predictor import (
        boom_predictor,
        get_boom_prediction,
        update_boom_data,
        get_boom_summary
    )
    from boom_config import get_config
    BOOM_PREDICTOR_AVAILABLE = True
except ImportError:
    BOOM_PREDICTOR_AVAILABLE = False

# Créer le router
boom_router = APIRouter(prefix="/boom", tags=["Boom Rising Channel Predictor"])

@boom_router.get("/predict")
async def get_boom_prediction_endpoint(
    symbol: str = Query("Boom 1000 Index"),
    timeframe: str = Query("M1")
):
    """Endpoint Boom Rising Channel Predictor"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        prediction = get_boom_prediction()
        
        if not prediction:
            return {
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": time.time(),
                "action": "HOLD",
                "direction": "NEUTRAL",
                "confidence": 0.0,
                "spike_probability": 0.0,
                "error": "Aucune prédiction disponible"
            }
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "action": prediction.get('action', 'HOLD'),
            "direction": prediction.get('direction', 'NEUTRAL'),
            "confidence": prediction.get('confidence', 0.0),
            "spike_probability": prediction.get('spike_probability', 0.0),
            "time_to_spike": prediction.get('time_to_spike', 0),
            "ema_proximity": prediction.get('ema_proximity', 'N/A'),
            "channel_position": prediction.get('channel_position', 'N/A'),
            "current_price": prediction.get('current_price', 0.0),
            "stop_loss": prediction.get('stop_loss', 0.0),
            "take_profit": prediction.get('take_profit', 0.0),
            "lot_size": prediction.get('lot_size', 0.1),
            "reasoning": prediction.get('reasoning', 'Analyse canal haussier Boom')
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur prédiction Boom: {str(e)}")

@boom_router.get("/status")
async def get_boom_status_endpoint():
    """Statut du système Boom Rising Channel Predictor"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        summary = get_boom_summary()
        
        return {
            "status": "running",
            "summary": summary,
            "active_predictions": len(boom_predictor.prediction_arrows),
            "active_channels": len(boom_predictor.rising_channels),
            "success_rate": boom_predictor.success_rate,
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur statut Boom: {str(e)}")

@boom_router.get("/config")
async def get_boom_config_endpoint():
    """Configuration du système Boom"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        config = {
            "boom": get_config('boom'),
            "ema": get_config('ema'),
            "channel": get_config('channel'),
            "prediction": get_config('prediction'),
            "trading": get_config('trading')
        }
        
        return {
            "status": "ok",
            "config": config,
            "timestamp": time.time()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur configuration Boom: {str(e)}")

@boom_router.get("/angelofspike/trend")
async def get_angelofspike_trend(
    symbol: str = Query("Boom 1000 Index"),
    timeframe: str = Query("M1")
):
    """Endpoint spécialement formaté pour AngelOfSpike"""
    if not BOOM_PREDICTOR_AVAILABLE:
        raise HTTPException(status_code=503, detail="Boom Predictor non disponible")
    
    try:
        prediction = get_boom_prediction()
        
        if not prediction:
            return {
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": time.time(),
                "direction": "NEUTRAL",
                "strength": 0,
                "confidence": 0,
                "signal": "no_signal",
                "trend": "neutral"
            }
        
        # Format compatible avec AngelOfSpike
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "direction": prediction.get('direction', 'NEUTRAL'),
            "strength": int(prediction.get('confidence', 0) * 100),
            "confidence": int(prediction.get('spike_probability', 0) * 100),
            "signal": f"boom_{prediction.get('action', 'HOLD').lower()}",
            "trend": prediction.get('direction', 'neutral').lower(),
            "spike_probability": prediction.get('spike_probability', 0),
            "time_to_spike": prediction.get('time_to_spike', 0),
            "ema_proximity": prediction.get('ema_proximity', 'N/A'),
            "channel_position": prediction.get('channel_position', 'N/A'),
            "current_price": prediction.get('current_price', 0),
            "stop_loss": prediction.get('stop_loss', 0),
            "take_profit": prediction.get('take_profit', 0),
            "reasoning": prediction.get('reasoning', 'Analyse canal haussier Boom')
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur AngelOfSpike trend: {str(e)}")
'''
    
    # Créer le fichier
    boom_endpoints_path = Path("backend/api/boom_endpoints.py")
    with open(boom_endpoints_path, 'w', encoding='utf-8') as f:
        f.write(boom_endpoints_content)
    
    print(f"✅ Fichier endpoints Boom créé: {boom_endpoints_path}")
    return True

def create_integration_instructions():
    """Crée les instructions d'intégration"""
    
    instructions = '''# Instructions d'Intégration Boom Rising Channel Predictor

## 🚀 Intégration avec l'API existante

### Option 1: API Séparée (Recommandée)
```bash
# Démarrer l'API Boom séparée
python boom_api.py
# ou
python launch_boom_api.py
# ou
lancer_api_boom.bat
```

**URLs disponibles:**
- API Boom: http://localhost:8002
- Endpoint AngelOfSpike: http://localhost:8002/angelofspike/trend
- Documentation: http://localhost:8002/docs

### Option 2: Intégration dans l'API existante

#### Étape 1: Ajouter les imports
Dans `backend/api/main.py`, ajouter:
```python
# Import du système Boom Rising Channel Predictor
try:
    from boom_rising_channel_predictor import (
        boom_predictor,
        get_boom_prediction,
        update_boom_data,
        get_boom_summary
    )
    from boom_config import get_config
    BOOM_PREDICTOR_AVAILABLE = True
except ImportError:
    BOOM_PREDICTOR_AVAILABLE = False
```

#### Étape 2: Ajouter les endpoints
```python
@app.get("/boom/predict")
async def get_boom_prediction_endpoint(symbol: str = "Boom 1000 Index"):
    # Code du endpoint...

@app.get("/boom/status")
async def get_boom_status_endpoint():
    # Code du endpoint...

@app.get("/boom/config")
async def get_boom_config_endpoint():
    # Code du endpoint...
```

#### Étape 3: Modifier l'endpoint /trend
```python
@app.get("/trend")
async def get_trend_with_boom(symbol: str, timeframe: str = "M1"):
    # Si c'est un symbole Boom, utiliser le prédicteur spécialisé
    if "Boom" in symbol and BOOM_PREDICTOR_AVAILABLE:
        prediction = get_boom_prediction()
        # Retourner la prédiction Boom
    else:
        # Utiliser l'ancienne méthode
```

## 🤖 Utilisation avec AngelOfSpike

### Configuration AngelOfSpike
Dans votre EA AngelOfSpike, utiliser:
```
http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1
```

### Format de réponse
```json
{
    "symbol": "Boom 1000 Index",
    "timeframe": "M1",
    "timestamp": 1234567890,
    "direction": "BUY",
    "strength": 85,
    "confidence": 78,
    "signal": "boom_trade",
    "trend": "bullish",
    "spike_probability": 0.85,
    "time_to_spike": 120,
    "ema_proximity": "EMA10",
    "channel_position": "lower",
    "current_price": 10050.0,
    "stop_loss": 10030.0,
    "take_profit": 10070.0,
    "reasoning": "Pattern canal haussier détecté - Proximité EMA10 - Position lower"
}
```

## 📊 Endpoints Disponibles

### API Boom Séparée (Port 8002)
- `/predict` - Prédiction Boom principale
- `/angelofspike/trend` - Format AngelOfSpike
- `/status` - Statut du système
- `/health` - Vérification santé
- `/config` - Configuration
- `/chart` - Génération graphique
- `/summary` - Résumé prédictions

### API Intégrée (Port existant)
- `/boom/predict` - Prédiction Boom
- `/boom/status` - Statut Boom
- `/boom/config` - Configuration Boom
- `/trend` - Trend amélioré avec support Boom

## 🔧 Configuration

### Paramètres recommandés pour AngelOfSpike
```python
# Dans boom_config.py
BOOM_CONFIG = {
    'symbol': 'Boom 1000 Index',
    'timeframe': 'M1',
    'min_candles': 100
}

BOOM_EMA_CONFIG = {
    'periods': [10, 30, 50],
    'proximity_threshold': 0.002
}

PREDICTION_CONFIG = {
    'spike_probability_threshold': 0.75,
    'confidence_threshold': 0.75,
    'max_time_to_spike': 300
}
```

## 🧪 Tests

### Test de l'API Boom
```bash
python quick_test_boom.py
```

### Test de l'intégration AngelOfSpike
```bash
curl "http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1"
```

### Test de l'API intégrée
```bash
curl "http://localhost:8000/boom/predict?symbol=Boom 1000 Index"
```

## 📈 Monitoring

### Vérification du statut
```bash
curl "http://localhost:8002/status"
```

### Résumé des prédictions
```bash
curl "http://localhost:8002/summary"
```

## 🚨 Dépannage

### Problèmes courants
1. **Import Error**: Vérifier que tous les fichiers Boom sont présents
2. **Port occupé**: Changer le port dans boom_api.py
3. **Données manquantes**: Vérifier la connexion MT5
4. **Prédictions vides**: Attendre la génération des données

### Logs
- Logs API: Console de l'API
- Logs Boom: boom_trading.log
- Historique: boom_trade_history.json
'''
    
    # Créer le fichier d'instructions
    instructions_path = Path("INTEGRATION_BOOM_API.md")
    with open(instructions_path, 'w', encoding='utf-8') as f:
        f.write(instructions)
    
    print(f"✅ Instructions d'intégration créées: {instructions_path}")
    return True

def main():
    """Fonction principale"""
    print("🔧 Intégration Boom Rising Channel Predictor dans l'API existante")
    print("=" * 70)
    
    # Créer le fichier d'endpoints séparé
    if create_boom_endpoints_file():
        print("✅ Fichier endpoints Boom créé")
    
    # Créer les instructions d'intégration
    if create_integration_instructions():
        print("✅ Instructions d'intégration créées")
    
    # Proposer l'intégration dans l'API principale
    print("\n🤔 Voulez-vous intégrer les endpoints Boom dans l'API principale?")
    print("   Cela modifiera le fichier backend/api/main.py")
    
    try:
        choice = input("Continuer? (y/N): ").lower()
        if choice in ['y', 'yes', 'oui']:
            if integrate_boom_endpoints():
                print("✅ Intégration dans l'API principale terminée")
            else:
                print("❌ Échec de l'intégration dans l'API principale")
        else:
            print("⏭️ Intégration dans l'API principale ignorée")
    except KeyboardInterrupt:
        print("\n⏹️ Intégration annulée")
    
    print("\n🎉 Intégration Boom Rising Channel Predictor terminée!")
    print("\n📋 Prochaines étapes:")
    print("   1. Démarrer l'API Boom: python boom_api.py")
    print("   2. Tester l'intégration: python quick_test_boom.py")
    print("   3. Configurer AngelOfSpike avec l'URL: http://localhost:8002/angelofspike/trend")
    print("   4. Consulter les instructions: INTEGRATION_BOOM_API.md")

if __name__ == "__main__":
    main()
