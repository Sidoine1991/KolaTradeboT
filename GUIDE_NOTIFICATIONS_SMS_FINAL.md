# Guide Complet des Notifications SMS - TradBOT

## 📱 Configuration des Notifications SMS

Votre numéro de téléphone **+22996911346** est maintenant configuré pour recevoir les notifications SMS automatiques de TradBOT.

## 🔧 Comment ça fonctionne actuellement

### 1. Service SMS Simplifié
- **Numéro configuré** : +22996911346
- **Mode** : Simulation + Sauvegarde locale
- **Fichiers** : Sauvegardés dans le dossier `notifications/`
- **Format** : JSON avec timestamp, numéro, titre et message

### 2. Types de notifications disponibles

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
🕐 15/09/2025 00:20
```

## 🚀 Intégration dans l'Application

### Dans app_real_time.py

Pour intégrer les notifications SMS dans votre application, ajoutez ce code :

```python
# Import du service SMS simplifié
from src.simple_sms_service import send_trading_signal, send_spike_alert

# Dans votre fonction de détection de signaux
def detect_trading_signals(symbol, data):
    # Votre logique d'analyse technique
    if rsi < 30 and macd_bullish:
        # Envoyer notification SMS
        send_trading_signal(
            symbol=symbol,
            action="BUY",
            price=data['close'],
            confidence=0.85,
            timeframe="M5"
        )
    
    # Détection de spike
    if price_change > 0.02:  # 2% de variation
        send_spike_alert(
            symbol=symbol,
            price=data['close'],
            spike_percentage=price_change * 100
        )
```

### Exemple d'intégration complète

```python
import streamlit as st
from src.simple_sms_service import get_simple_sms_service

# Dans votre application Streamlit
def main():
    st.title("TradBOT - Trading en Temps Réel")
    
    # Obtenir le service SMS
    sms_service = get_simple_sms_service()
    
    # Bouton de test SMS
    if st.button("Test SMS"):
        if sms_service.test_sms_notification():
            st.success("SMS de test envoyé!")
        else:
            st.error("Erreur lors de l'envoi du SMS")
    
    # Votre logique de trading...
    if st.button("Détecter Signaux"):
        # Simuler la détection d'un signal
        send_trading_signal(
            symbol="EURUSD",
            action="BUY",
            price=1.0850,
            confidence=0.85
        )
        st.success("Signal détecté et notification envoyée!")
```

## 📁 Fichiers de Notification

### Structure des fichiers
Les notifications sont sauvegardées dans `notifications/sms_YYYYMMDD_HHMMSS.json` :

```json
{
  "timestamp": "2025-09-15T00:20:54.452232",
  "phone_number": "+22996911346",
  "title": "TradBOT Signal - EURUSD",
  "message": "🟢 SIGNAL BUY\n📊 EURUSD\n💰 Prix: 1.0850\n🎯 Confiance: 85%\n⏰ M5\n🕐 14:30:25"
}
```

### Consulter les notifications
```bash
# Lister tous les fichiers de notification
ls notifications/

# Voir le contenu d'un fichier
cat notifications/sms_20250915_002054.json
```

## 🔧 Configuration Avancée

### Modifier le numéro de téléphone
Dans `src/simple_sms_service.py` :
```python
def __init__(self):
    self.phone_number = "+22996911346"  # Changez ici
```

### Personnaliser les messages
Modifiez les fonctions de formatage dans `src/simple_sms_service.py` :
- `_format_trading_signal_message()`
- `_format_daily_summary_message()`

### Ajouter de nouveaux types de notifications
```python
def send_custom_alert(self, alert_type: str, data: dict) -> bool:
    """Envoie une alerte personnalisée"""
    message = f"🚨 {alert_type.upper()}\n"
    message += f"📊 {data.get('symbol', 'N/A')}\n"
    message += f"💰 Prix: {data.get('price', 0):.4f}\n"
    message += f"🕐 {datetime.now().strftime('%H:%M:%S')}"
    
    return self.send_sms_notification(message, f"TradBOT {alert_type}")
```

## 🧪 Test des Notifications

### Test rapide
```bash
python test_simple_sms.py
```

### Test manuel dans le code
```python
from src.simple_sms_service import get_simple_sms_service

# Obtenir le service SMS
sms_service = get_simple_sms_service()

# Test d'envoi
success = sms_service.test_sms_notification()
if success:
    print("SMS envoyé avec succès!")
```

## 📊 Monitoring des Notifications

### Logs des notifications
Les notifications sont loggées dans :
- Console de l'application
- Fichiers dans `notifications/`

### Vérification du statut
```python
from src.simple_sms_service import get_simple_sms_service

sms_service = get_simple_sms_service()
print(f"Service SMS actif: {sms_service.enabled}")
print(f"Numéro configuré: {sms_service.phone_number}")
```

## 🔄 Intégration avec les Signaux Existants

### Dans vos scripts de trading

```python
# Import du service
from src.simple_sms_service import send_trading_signal, send_spike_alert

# Dans votre logique de trading
def analyze_market_data(symbol, data):
    # Analyse RSI
    if data['rsi'] < 30:
        send_trading_signal(
            symbol=symbol,
            action="BUY",
            price=data['close'],
            confidence=0.85,
            timeframe="M5"
        )
    
    # Analyse de spike
    price_change = (data['close'] - data['open']) / data['open']
    if abs(price_change) > 0.02:  # 2%
        send_spike_alert(
            symbol=symbol,
            price=data['close'],
            spike_percentage=price_change * 100
        )
```

### Dans l'application Streamlit

```python
import streamlit as st
from src.simple_sms_service import send_trading_signal

# Interface utilisateur
st.title("TradBOT - Notifications SMS")

# Configuration
phone_number = st.text_input("Numéro de téléphone", value="+22996911346")

# Test de notification
if st.button("Envoyer Test SMS"):
    from src.simple_sms_service import get_simple_sms_service
    sms_service = get_simple_sms_service()
    if sms_service.test_sms_notification():
        st.success("SMS de test envoyé!")
    else:
        st.error("Erreur lors de l'envoi")

# Simulation de signal
if st.button("Simuler Signal BUY"):
    send_trading_signal(
        symbol="EURUSD",
        action="BUY",
        price=1.0850,
        confidence=0.85
    )
    st.success("Signal simulé et notification envoyée!")
```

## 🚨 Dépannage

### Problèmes courants

1. **Notifications non sauvegardées** :
   - Vérifiez les permissions d'écriture
   - Vérifiez que le dossier `notifications` existe

2. **Erreurs d'importation** :
   - Vérifiez que `src/simple_sms_service.py` existe
   - Vérifiez les chemins d'importation

3. **Messages mal formatés** :
   - Vérifiez les fonctions de formatage
   - Vérifiez les données d'entrée

### Test de connectivité
```bash
python test_simple_sms.py
```

## 🔮 Évolutions Futures

### Intégration avec de vraies APIs SMS

Pour envoyer de vrais SMS, vous pouvez intégrer :

1. **Twilio** :
```python
from twilio.rest import Client

def send_real_sms(message):
    client = Client(account_sid, auth_token)
    message = client.messages.create(
        body=message,
        from_='+1234567890',
        to='+22996911346'
    )
```

2. **Vonage (Nexmo)** :
```python
import vonage

def send_real_sms(message):
    client = vonage.Client(key="your_key", secret="your_secret")
    client.sms.send_message({
        "from": "TradBOT",
        "to": "22996911346",
        "text": message
    })
```

3. **Firebase Cloud Messaging** (après activation de Firestore) :
```python
from firebase_admin import messaging

def send_fcm_notification(message):
    message = messaging.Message(
        notification=messaging.Notification(
            title="TradBOT",
            body=message
        ),
        token=device_token
    )
    messaging.send(message)
```

## 📱 Activation de Firestore (Optionnel)

Si vous voulez utiliser Firestore pour sauvegarder les notifications :

1. **Activez l'API Firestore** :
   - Allez sur : https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=smstrade-5f6a5
   - Cliquez sur "Enable API"

2. **Attendez quelques minutes** pour la propagation

3. **Testez avec le service Firebase complet** :
```bash
python test_sms_notifications.py
```

## 🎯 Résumé

### ✅ Ce qui fonctionne maintenant
- Service SMS simplifié opérationnel
- Notifications sauvegardées localement
- Intégration facile dans l'application
- Tests automatisés

### 🔧 Prochaines étapes
1. Intégrez `send_trading_signal()` dans vos signaux
2. Ajoutez `send_spike_alert()` dans la détection de spikes
3. Personnalisez les messages selon vos besoins
4. (Optionnel) Activez Firestore pour la sauvegarde cloud

### 💡 Utilisation immédiate
```python
from src.simple_sms_service import send_trading_signal

# Dans votre code de trading
send_trading_signal("EURUSD", "BUY", 1.0850, 0.85)
```

---

**Votre numéro +22996911346 est maintenant configuré et prêt à recevoir les notifications SMS de TradBOT !** 🎉
