# Guide de Configuration Vonage pour TradBOT

## 📱 Configuration des Notifications SMS et WhatsApp

Ce guide explique comment configurer Vonage pour envoyer des notifications SMS et WhatsApp avec le format optimisé de TradBOT.

## 🔧 Configuration Vonage

### 1. Créer un compte Vonage

1. Allez sur [Vonage Developer](https://developer.vonage.com/)
2. Créez un compte gratuit
3. Vérifiez votre numéro de téléphone

### 2. Obtenir les clés API

1. Connectez-vous à votre dashboard Vonage
2. Allez dans "API Keys"
3. Créez une nouvelle application
4. Copiez votre `API Key` et `API Secret`

### 3. Configuration WhatsApp (Sandbox)

1. Allez dans "Messages API" > "WhatsApp Sandbox"
2. Suivez les instructions pour configurer le sandbox
3. Notez le numéro WhatsApp sandbox (ex: 14157386102)

### 4. Configuration des variables d'environnement

Créez ou modifiez votre fichier `.env` :

```env
# Configuration Vonage
VONAGE_API_KEY=your_api_key_here
VONAGE_API_SECRET=your_api_secret_here

# Configuration SMS
VONAGE_SMS_FROM=TradBOT
VONAGE_SMS_TO=22996911346

# Configuration WhatsApp Sandbox
VONAGE_WHATSAPP_FROM_SANDBOX=14157386102
VONAGE_WHATSAPP_TO_SANDBOX=22996911346

# Configuration Firebase (fallback)
FIREBASE_ENABLED=true
```

## 📱 Format des Messages

### Format SMS/WhatsApp Optimisé

Le service utilise le format Vonage optimisé :

```
🎯 SPIKE Boom 1000 Index
⏰ 14:30
📊 85% probabilité
🔄 BUY LIMIT
💰 Entrée: 17952.46900
🎯 TP: 17967.46900
🛡️ SL: 17947.46900
📦 0.01 lots min
```

### Format Signal Confirmé

```
✅ SIGNAL CONFIRMÉ EURUSD
⏰ 14:30
📊 92% probabilité
🔄 BUY
💰 Prix: 1.08500
🔗 Source: API Alpha Vantage
📦 0.01 lots min
⚠️ Signal confirmé par l'API
```

### Format Alerte de Spike

```
🚨 SPIKE DÉTECTÉ Crash 500 Index
⏰ 14:30
💰 Prix: 3298.22500
📈 Variation: +2.5%
⚠️ Attention: Mouvement important détecté
```

## 🚀 Utilisation

### Import du service

```python
from src.unified_notification_service import send_trading_signal, send_confirmed_signal, send_spike_alert
```

### Envoyer un signal de trading

```python
# Signal standard
results = send_trading_signal(
    symbol="Boom 1000 Index",
    action="BUY",
    price=17952.469,
    confidence=0.85,
    timeframe="M5"
)

# Vérifier les résultats
print(f"SMS: {results['sms']}")
print(f"WhatsApp: {results['whatsapp']}")
print(f"Firebase: {results['firebase']}")
```

### Envoyer un signal confirmé

```python
# Signal confirmé de l'API
results = send_confirmed_signal(
    symbol="EURUSD",
    action="BUY",
    price=1.0850,
    confidence=0.92,
    source="API Alpha Vantage"
)
```

### Envoyer une alerte de spike

```python
# Alerte de spike
results = send_spike_alert(
    symbol="Crash 500 Index",
    price=3298.225,
    spike_percentage=2.5
)
```

## 🧪 Test de la Configuration

### Test rapide

```bash
python test_unified_notifications.py
```

### Test manuel

```python
from src.unified_notification_service import get_unified_service

service = get_unified_service()

# Test tous les services
results = service.test_all_services()
print(results)

# Vérifier le statut
status = service.get_status()
print(status)
```

## 📊 Types de Signaux Supportés

### 1. Signaux Boom/Crash
- **Boom 1000 Index** : Signal BUY automatique
- **Crash 500 Index** : Signal SELL automatique
- Calcul automatique des niveaux TP/SL

### 2. Signaux Forex
- **EURUSD, GBPUSD, etc.** : Signaux basés sur l'action
- Calcul des pips appropriés
- Niveaux TP/SL optimisés

### 3. Signaux Confirmés
- Signaux provenant de l'API de signaux
- Marquage spécial "CONFIRMÉ"
- Source de l'API indiquée

### 4. Alertes de Spike
- Détection de mouvements importants
- Pourcentage de variation
- Alerte immédiate

## 🔧 Configuration Avancée

### Personnaliser les messages

Modifiez les fonctions de formatage dans `src/unified_notification_service.py` :

- `_format_trading_signal_message()`
- `_format_confirmed_signal_message()`
- `_format_spike_alert_message()`

### Ajouter de nouveaux types de signaux

```python
def send_custom_signal(self, signal_data: Dict[str, Any]) -> Dict[str, bool]:
    """Envoie un signal personnalisé"""
    message = self._format_custom_message(signal_data)
    
    results = {"sms": False, "whatsapp": False, "firebase": False}
    
    if self.sms_enabled:
        results["sms"] = self._send_sms(message)
    
    if self.whatsapp_enabled:
        results["whatsapp"] = self._send_whatsapp(message)
    
    return results
```

### Modifier les niveaux TP/SL

Dans `_format_trading_signal_message()` :

```python
# TP = +15 pips, SL = -5 pips (actuel)
# Modifiez selon vos besoins
if direction == "BUY":
    tp_price = current_price + (20 * pip_value)  # +20 pips
    sl_price = current_price - (10 * pip_value)  # -10 pips
```

## 🚨 Dépannage

### Problèmes courants

1. **SMS non reçus** :
   - Vérifiez les clés API Vonage
   - Vérifiez le format du numéro (sans + ni 00)
   - Consultez les logs Vonage

2. **WhatsApp non reçu** :
   - Vérifiez la configuration du sandbox
   - Assurez-vous que le numéro est dans le sandbox
   - Vérifiez les permissions WhatsApp

3. **Erreurs d'API** :
   - Vérifiez les quotas Vonage
   - Vérifiez la validité des clés
   - Consultez la documentation Vonage

### Logs et monitoring

```python
import logging
logging.basicConfig(level=logging.INFO)

# Les logs montreront les détails des envois
service = get_unified_service()
results = service.test_all_services()
```

## 💰 Coûts Vonage

### SMS
- **Gratuit** : 10 SMS/mois
- **Payant** : ~0.05€ par SMS

### WhatsApp
- **Sandbox** : Gratuit (limité)
- **Production** : ~0.05€ par message

### Recommandations
- Utilisez le sandbox pour les tests
- Passez en production pour l'usage réel
- Surveillez vos quotas

## 🎯 Intégration dans TradBOT

### Dans app_real_time.py

```python
from src.unified_notification_service import send_trading_signal, send_confirmed_signal

# Dans votre fonction de détection de signaux
def detect_trading_signals(symbol, data):
    # Votre logique d'analyse
    if signal_detected:
        results = send_trading_signal(
            symbol=symbol,
            action="BUY",
            price=data['close'],
            confidence=0.85
        )
        
        # Vérifier si au moins un service a fonctionné
        if any(results.values()):
            print("Signal envoyé avec succès!")
```

### Dans vos scripts de trading

```python
from src.unified_notification_service import send_confirmed_signal

# Pour les signaux confirmés de l'API
def process_api_signal(signal_data):
    results = send_confirmed_signal(
        symbol=signal_data['symbol'],
        action=signal_data['action'],
        price=signal_data['price'],
        confidence=signal_data['confidence'],
        source=signal_data['source']
    )
    
    return results
```

## 📋 Résumé

### ✅ Ce qui est configuré
- Service unifié SMS + WhatsApp + Firebase
- Format de messages optimisé Vonage
- Support des signaux Boom/Crash/Forex
- Signaux confirmés de l'API
- Alertes de spike

### 🔧 Prochaines étapes
1. Configurez vos clés Vonage
2. Testez avec `python test_unified_notifications.py`
3. Intégrez dans vos scripts de trading
4. Personnalisez selon vos besoins

---

**Votre système de notifications unifié est prêt !** 🎉

Les signaux confirmés de l'API seront automatiquement envoyés via SMS et WhatsApp avec le format optimisé Vonage.
