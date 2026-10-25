# 🔄 AUTOSCAN AUTOMATIQUE - Guide Streamlit

## 📋 Vue d'ensemble

L'**Autoscan Automatique** dans Streamlit analyse automatiquement les marchés toutes les 2 minutes et envoie des signaux de trading par WhatsApp et SMS quand des opportunités sont détectées.

## 🎯 Fonctionnalités Principales

### ⚡ **Autoscan Automatique**
- **Fréquence** : Toutes les 2 minutes (configurable)
- **Analyse** : Focus sur Boom/Crash et indices
- **Notifications** : WhatsApp et SMS automatiques
- **Interface** : Contrôle complet dans Streamlit

### 📱 **Notifications Intégrées**
- **WhatsApp** : Messages détaillés avec emojis
- **SMS** : Format optimisé pour mobile
- **Filtrage** : Seulement les meilleurs signaux (score > 70%)
- **Format** : Identique au robot MT5

## 🔧 Configuration dans Streamlit

### **1. Activation de l'Autoscan**
```
Onglet "🔍 Auto Scan" → Section "⚙️ Configuration Autoscan Automatique"
✅ Cochez "🔄 Autoscan Automatique"
```

### **2. Paramètres Configurables**
- **⏱️ Intervalle de Scan** : 1min, 2min, 5min, 10min
- **📱 Notifications Auto** : WhatsApp/SMS automatiques
- **🎯 Catégories** : Synthetics, Indices (Boom/Crash)

### **3. Statut en Temps Réel**
- **🟢 ACTIF** : Autoscan en cours
- **⏳ Timer** : Compte à rebours jusqu'au prochain scan
- **📊 Statistiques** : Dernières opportunités détectées

## 📊 Interface Utilisateur

### **Section Configuration**
```
🔄 Autoscan Automatique     [✅ Activé]
⏱️ Intervalle de Scan       [2 minutes ▼]
📱 Notifications Auto       [✅ Activé]
```

### **Statut de l'Autoscan**
```
🟢 Autoscan ACTIF - Scan automatique toutes les 2 minutes
⏳ Prochain scan dans 45 secondes
```

### **Sidebar - Indicateur**
```
🔄 Statut Autoscan
🟢 Autoscan ACTIF
[████████░░] 80%
Prochain scan dans 24s

Dernières opportunités: 3
Meilleur score: 0.85
```

## 🧠 Logique de l'Autoscan

### **1. Déclenchement Automatique**
```python
# Vérification toutes les 30 secondes
if time_until_next <= 0:
    # Lancement du scan automatique
    scan_results = auto_scan_symbols(['Synthetics', 'Indices'])
    
    # Envoi des notifications si activées
    if autoscan_notifications:
        send_autoscan_notifications(scan_results)
```

### **2. Filtrage des Signaux**
```python
# Seulement les meilleurs signaux
best_signals = [r for r in scan_results if r.get('quality_score', 0) > 0.7]

# Prendre le meilleur signal
best_signal = max(best_signals, key=lambda x: x.get('quality_score', 0))
```

### **3. Format des Notifications**
```
🟢 AUTOSCAN SIGNAL
📊 Boom 1000 Index
💰 BUY - BOOM
🎯 Confiance: 85%
⭐ Score: 92%
⏰ 14:23:45
🤖 TradBOT Autoscan
```

## 📱 Intégration Notifications

### **Service Unifié**
```python
from src.unified_notification_service import send_trading_signal

# Envoi automatique
send_trading_signal(symbol, signal_type, price, confidence)
```

### **Providers Supportés**
- **Firebase** : SMS (10,000 gratuits/mois)
- **Vonage** : SMS + WhatsApp
- **Twilio** : SMS + WhatsApp

### **Configuration Automatique**
```python
# Détection automatique des providers disponibles
firebase_available = bool(os.getenv('FIREBASE_PROJECT_ID'))
vonage_available = bool(os.getenv('VONAGE_API_KEY'))
twilio_available = bool(os.getenv('TWILIO_ACCOUNT_SID'))
```

## ⚙️ Configuration Avancée

### **Variables d'Environnement**
```bash
# Firebase (priorité 1)
FIREBASE_PROJECT_ID=smstrade-5f6a5
FIREBASE_PRIVATE_KEY=your_private_key
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@...
PHONE_NUMBER=+22996911346

# Vonage (priorité 2)
VONAGE_API_KEY=your_api_key
VONAGE_API_SECRET=your_api_secret
PHONE_NUMBER=+22996911346

# Twilio (priorité 3)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
PHONE_NUMBER=+22996911346
```

### **Paramètres de Scan**
```python
# Catégories par défaut pour l'autoscan
default_categories = ['Synthetics', 'Indices']  # Focus Boom/Crash

# Seuil de qualité minimum
min_quality_score = 0.7  # 70%

# Intervalle de rafraîchissement
autoscan_refresh_interval = min(refresh_interval, 30)  # Max 30s
```

## 🎯 Utilisation Pratique

### **1. Activation**
1. **Ouvrez** l'onglet "🔍 Auto Scan"
2. **Cochez** "🔄 Autoscan Automatique"
3. **Configurez** l'intervalle (2 minutes recommandé)
4. **Activez** "📱 Notifications Auto"

### **2. Surveillance**
- **Sidebar** : Indicateur de statut en temps réel
- **Progress Bar** : Compte à rebours visuel
- **Métriques** : Dernières opportunités et scores

### **3. Notifications**
- **WhatsApp** : Messages détaillés avec emojis
- **SMS** : Format optimisé pour mobile
- **Filtrage** : Seulement les meilleurs signaux

## 📊 Statistiques et Monitoring

### **Métriques Affichées**
- **Dernières opportunités** : Nombre de signaux détectés
- **Meilleur score** : Score de qualité le plus élevé
- **Temps restant** : Compte à rebours jusqu'au prochain scan
- **Statut** : ACTIF/INACTIF

### **Logs et Historique**
- **Console** : Logs détaillés des scans
- **Session State** : Résultats conservés
- **Notifications** : Historique des envois

## 🔧 Dépannage

### **Problèmes Courants**

#### Autoscan ne se déclenche pas
- **Vérifiez** : `autoscan_enabled = True`
- **Vérifiez** : Connexion MT5 active
- **Vérifiez** : Rafraîchissement automatique activé

#### Pas de notifications
- **Vérifiez** : Configuration des providers (.env)
- **Vérifiez** : `autoscan_notifications = True`
- **Vérifiez** : Score des signaux > 70%

#### Interface ne se met pas à jour
- **Vérifiez** : Rafraîchissement automatique
- **Vérifiez** : Intervalle de rafraîchissement
- **Redémarrez** : L'application si nécessaire

### **Logs de Debug**
```python
# Activer les logs détaillés
st.session_state.debug_mode = True

# Vérifier les variables de session
st.write("Session State:", st.session_state)
```

## 🚀 Optimisations

### **Performance**
- **Intervalle optimal** : 2 minutes pour Boom/Crash
- **Catégories ciblées** : Synthetics + Indices
- **Filtrage strict** : Score > 70%

### **Notifications**
- **Seuil élevé** : Éviter le spam
- **Format optimisé** : Messages courts et clairs
- **Provider prioritaire** : Firebase > Vonage > Twilio

### **Interface**
- **Rafraîchissement** : 30 secondes maximum
- **Indicateurs visuels** : Progress bars et métriques
- **Statut clair** : ACTIF/INACTIF visible

## 📈 Intégration avec MT5

### **Synchronisation**
- **Même logique** : Identique au robot MT5
- **Même format** : Messages compatibles
- **Même timing** : 2 minutes d'intervalle

### **Complémentarité**
- **Streamlit** : Interface et configuration
- **MT5 Robot** : Exécution des trades
- **Notifications** : Alertes communes

---

**🎯 OBJECTIF** : L'autoscan automatique dans Streamlit analyse les marchés toutes les 2 minutes et envoie automatiquement les meilleurs signaux par WhatsApp et SMS.

**⚠️ AVERTISSEMENT** : Les signaux sont basés sur l'analyse technique et ne garantissent pas 100% de réussite. Utilisez-les comme indicateurs supplémentaires dans votre stratégie de trading.
