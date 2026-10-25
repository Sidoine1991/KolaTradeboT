# Guide des Notifications SMS - TradBOT

## 📱 Configuration des Notifications SMS

Votre numéro de téléphone **+22996911346** est maintenant configuré pour recevoir les notifications SMS automatiques de TradBOT.

## 🔧 Comment ça fonctionne

### 1. Configuration automatique
- **Numéro configuré** : +22996911346
- **Service** : Firebase SMS (10,000 SMS gratuits/mois)
- **Projet Firebase** : smstrade-5f6a5
- **Intégration** : Automatique avec les signaux de trading

### 2. Types de notifications envoyées

#### 🟢 Signaux de Trading
```
🟢 SIGNAL BUY
📊 EURUSD
💰 Prix: 1.0850
🎯 Confiance: 85%
⏰ M5
🕐 14:30:25
```

#### 🔴 Signaux de Vente
```
🔴 SIGNAL SELL
📊 Boom 1000 Index
💰 Prix: 17965.28
🎯 Confiance: 92%
⏰ M15
🕐 14:45:10
```

#### 🚨 Alertes de Spike
```
🚨 SPIKE DÉTECTÉ! Boom 1000 Index à 17965.28 (+2.5%)
```

#### 📊 Résumé Quotidien
```
📊 RÉSUMÉ QUOTIDIEN
📈 Signaux: 15
✅ Réussis: 12
🎯 Taux: 80%
💰 P&L: 1250.50
🕐 14/09/2025 22:30
```

## 🚀 Intégration dans l'Application

### Dans app_real_time.py

Les notifications SMS sont automatiquement intégrées dans l'application. Voici comment elles sont déclenchées :

```python
# Import du service SMS
from src.sms_notification_service import send_trading_signal, send_spike_alert

# Lors de la détection d'un signal
if signal_detected:
    send_trading_signal(
        symbol="EURUSD",
        action="BUY",
        price=current_price,
        confidence=signal_confidence,
        timeframe="M5"
    )

# Lors de la détection d'un spike
if spike_detected:
    send_spike_alert(
        symbol="Boom 1000 Index",
        price=current_price,
        spike_percentage=spike_percentage
    )
```

### Déclencheurs automatiques

1. **Signaux de trading** : Envoyés automatiquement quand :
   - RSI < 30 (survente) + MACD haussier
   - RSI > 70 (surachat) + MACD baissier
   - Supertrend change de direction
   - Bollinger Bands + momentum

2. **Alertes de spike** : Envoyées quand :
   - Variation de prix > 1% en moins de 5 minutes
   - Volume anormalement élevé
   - Rupture de support/résistance

3. **Résumés quotidiens** : Envoyés :
   - À 22h00 chaque jour
   - Résumé des performances
   - Statistiques des signaux

## 🧪 Test des Notifications

### Test rapide
```bash
python test_sms_notifications.py
```

### Test manuel dans le code
```python
from src.sms_notification_service import get_sms_service

# Obtenir le service SMS
sms_service = get_sms_service()

# Test d'envoi
success = sms_service.test_sms_notification()
if success:
    print("SMS envoyé avec succès!")
```

## 📊 Monitoring des Notifications

### Logs des notifications
Les notifications sont loggées dans :
- `logs/trading_bot.log`
- Console de l'application

### Vérification du statut
```python
from src.sms_notification_service import get_sms_service

sms_service = get_sms_service()
if sms_service.firebase_service and sms_service.firebase_service.initialized:
    print("✅ Service SMS opérationnel")
else:
    print("❌ Service SMS non disponible")
```

## 🔧 Configuration Avancée

### Modifier le numéro de téléphone
Dans `config/settings.py` :
```python
'phone_number': os.getenv('PHONE_NUMBER', '+22996911346')
```

Ou dans le fichier `.env` :
```env
PHONE_NUMBER=+22996911346
```

### Personnaliser les messages
Modifiez les fonctions de formatage dans `src/sms_notification_service.py` :
- `_format_trading_signal_message()`
- `_format_position_message()`
- `_format_daily_summary_message()`

### Désactiver les notifications
Dans `config/settings.py` :
```python
'firebase_enabled': False
```

## 📈 Intégration avec les Signaux

### Dans les scripts de trading existants

```python
# Import du service
from src.sms_notification_service import send_trading_signal

# Dans votre logique de trading
def detect_trading_signal(symbol, data):
    # Votre logique d'analyse
    if rsi < 30 and macd_bullish:
        # Envoyer notification SMS
        send_trading_signal(
            symbol=symbol,
            action="BUY",
            price=data['close'],
            confidence=0.85,
            timeframe="M5"
        )
```

### Dans l'application Streamlit

Les notifications sont automatiquement intégrées dans `app_real_time.py` et se déclenchent :
- Lors de la détection de signaux
- Lors des alertes de spike
- Pour les résumés quotidiens

## 🚨 Dépannage

### Problèmes courants

1. **SMS non reçus** :
   - Vérifiez que le numéro est correct (+22996911346)
   - Vérifiez la configuration Firebase
   - Consultez les logs

2. **Service non initialisé** :
   ```bash
   pip install firebase-admin
   python test_firebase_config.py
   ```

3. **Erreurs de configuration** :
   - Vérifiez `firebase_config.json`
   - Vérifiez les variables d'environnement
   - Relancez l'application

### Test de connectivité
```bash
python test_sms_notifications.py
```

## 📱 Format des Messages

### Structure des SMS
- **Titre** : Type de notification
- **Contenu** : Données du signal/alerte
- **Timestamp** : Heure d'envoi
- **Emojis** : Indicateurs visuels

### Exemples de messages

**Signal d'achat** :
```
🟢 SIGNAL BUY
📊 EURUSD
💰 Prix: 1.0850
🎯 Confiance: 85%
⏰ M5
🕐 14:30:25
```

**Alerte de spike** :
```
🚨 SPIKE DÉTECTÉ! Boom 1000 Index à 17965.28 (+2.5%)
```

## 🎯 Prochaines Étapes

1. **Testez les notifications** : `python test_sms_notifications.py`
2. **Lancez l'application** : Les notifications sont automatiques
3. **Surveillez les logs** : Pour vérifier l'envoi
4. **Personnalisez** : Selon vos besoins

---

**Note** : Les notifications SMS sont maintenant configurées pour votre numéro +22996911346 et se déclencheront automatiquement lors de la détection de signaux de trading.
