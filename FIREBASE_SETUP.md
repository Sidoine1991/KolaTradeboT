# Configuration Firebase pour TradBOT

## 📋 Vue d'ensemble

Ce guide explique comment configurer et utiliser Firebase avec TradBOT pour les notifications SMS et la gestion des données de trading.

## 🔧 Configuration

### Informations du projet
- **Nom du projet**: `smstrade-5f6a5`
- **Clé API Google**: `AIzaSyClCAXRU8kk4l1TxtaMfDqbRUEixNQ68Ao`
- **Email du service**: `firebase-adminsdk-fbsvc@smstrade-5f6a5.iam.gserviceaccount.com`

### Fichiers de configuration créés

1. **`firebase_config.json`** - Configuration Firebase complète
2. **`src/firebase_service.py`** - Service Firebase pour TradBOT
3. **`config/settings.py`** - Configuration mise à jour avec Firebase
4. **`.env`** - Variables d'environnement (créé par le script d'installation)

## 🚀 Installation rapide

### Option 1: Installation automatique
```bash
python install_firebase.py
```

### Option 2: Installation manuelle

1. **Installer les dépendances**:
```bash
pip install firebase-admin>=6.2.0 google-cloud-firestore>=2.11.0
```

2. **Configurer les variables d'environnement**:
```bash
python setup_firebase.py
```

3. **Tester la configuration**:
```bash
python test_firebase_config.py
```

## 🧪 Test de la configuration

### Test complet
```bash
python test_firebase_config.py
```

### Démonstration des fonctionnalités
```bash
python demo_firebase_sms.py
```

## 📱 Utilisation des notifications SMS

### Exemple basique
```python
from src.firebase_service import get_firebase_service

# Obtenir le service Firebase
service = get_firebase_service()

# Envoyer une notification SMS
service.send_sms_notification(
    phone_number="+1234567890",
    message="Signal de trading détecté!",
    title="TradBOT Alert"
)
```

### Intégration dans les signaux de trading
```python
def send_trading_signal(symbol, action, price, confidence):
    service = get_firebase_service()
    
    # Sauvegarder le signal
    signal_data = {
        'symbol': symbol,
        'action': action,
        'price': price,
        'confidence': confidence,
        'timestamp': datetime.now()
    }
    
    signal_id = service.save_trading_signal(signal_data)
    
    # Envoyer notification SMS
    message = f"Signal {action} {symbol} à {price} (confiance: {confidence:.2f})"
    service.send_sms_notification(
        phone_number="+1234567890",
        message=message,
        title="TradBOT Signal"
    )
    
    return signal_id
```

## 🗄️ Gestion des données

### Sauvegarde des signaux
```python
service = get_firebase_service()

# Sauvegarder un signal
signal_data = {
    'symbol': 'EURUSD',
    'action': 'BUY',
    'price': 1.0850,
    'confidence': 0.85,
    'indicators': {
        'rsi': 35.2,
        'macd': 'bullish'
    }
}

signal_id = service.save_trading_signal(signal_data)
```

### Récupération des signaux
```python
# Récupérer les 10 derniers signaux
signals = service.get_trading_signals(limit=10)

for signal in signals:
    print(f"{signal['symbol']} - {signal['action']} - {signal['confidence']}")
```

### Sauvegarde des données de marché
```python
market_data = {
    'open': 1.0845,
    'high': 1.0860,
    'low': 1.0840,
    'close': 1.0855,
    'volume': 1000000,
    'timeframe': 'M5'
}

service.save_market_data('EURUSD', market_data)
```

## ⚙️ Configuration avancée

### Variables d'environnement requises

Créer un fichier `.env` avec :
```env
# Configuration Firebase
FIREBASE_PROJECT_ID=smstrade-5f6a5
FIREBASE_PRIVATE_KEY_ID=7da798f4748423a37852118ac2812d045244ef22
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@smstrade-5f6a5.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=110284900614212803727
GOOGLE_API_KEY=AIzaSyClCAXRU8kk4l1TxtaMfDqbRUEixNQ68Ao

# Votre numéro de téléphone
PHONE_NUMBER=+1234567890
```

### Configuration dans settings.py

La configuration Firebase est automatiquement chargée depuis les variables d'environnement :

```python
from config.settings import FIREBASE_CONFIG, ALERT_CONFIG

# Accéder à la configuration
project_id = FIREBASE_CONFIG['project_id']
api_key = FIREBASE_CONFIG['google_api_key']

# Vérifier si Firebase est activé
if ALERT_CONFIG['firebase_enabled']:
    print("Firebase activé")
```

## 🔒 Sécurité

### Bonnes pratiques

1. **Ne jamais commiter les clés privées** dans le code
2. **Utiliser des variables d'environnement** pour les secrets
3. **Limiter les permissions** du compte de service Firebase
4. **Surveiller l'utilisation** des API

### Fichiers à ignorer

Ajouter à `.gitignore` :
```
.env
firebase_config.json
*.json
```

## 📊 Monitoring et logs

### Vérification du statut
```python
service = get_firebase_service()

if service.initialized:
    print("✅ Firebase opérationnel")
else:
    print("❌ Firebase non initialisé")
```

### Logs
Les logs Firebase sont intégrés avec le système de logging de TradBOT :
```python
import logging
logger = logging.getLogger('firebase_service')
logger.info("Notification SMS envoyée")
```

## 🛠️ Dépannage

### Problèmes courants

1. **Erreur d'importation Firebase**:
   ```bash
   pip install firebase-admin google-cloud-firestore
   ```

2. **Clés d'authentification invalides**:
   - Vérifier le fichier `firebase_config.json`
   - Vérifier les variables d'environnement

3. **Service non initialisé**:
   - Vérifier les permissions du compte de service
   - Vérifier la connectivité réseau

### Test de connectivité
```python
python test_firebase_config.py
```

## 📈 Fonctionnalités avancées

### Nettoyage automatique des données
```python
# Nettoyer les données de plus de 30 jours
service.cleanup_old_data(days=30)
```

### Mise à jour du statut des signaux
```python
# Marquer un signal comme exécuté
service.update_signal_status(signal_id, 'executed')
```

### Récupération des données de marché
```python
# Récupérer les 100 derniers points pour EURUSD
data = service.get_market_data('EURUSD', limit=100)
```

## 🎯 Intégration avec TradBOT

### Dans les scripts de trading existants

1. **Importer le service**:
   ```python
   from src.firebase_service import get_firebase_service
   ```

2. **Initialiser le service**:
   ```python
   firebase_service = get_firebase_service()
   ```

3. **Intégrer dans les signaux**:
   ```python
   if signal_detected:
       firebase_service.send_sms_notification(
           phone_number=PHONE_NUMBER,
           message=f"Signal {action} {symbol}",
           title="TradBOT"
       )
   ```

## 📞 Support

Pour toute question ou problème :
1. Vérifier les logs dans `logs/trading_bot.log`
2. Lancer `python test_firebase_config.py`
3. Consulter la documentation Firebase officielle

---

**Note**: Cette configuration utilise Firebase avec 10,000 SMS gratuits par mois. Pour une utilisation en production, considérez les limites et les coûts.
