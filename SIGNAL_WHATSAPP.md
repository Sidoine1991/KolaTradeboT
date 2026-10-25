# 📱 Système de Signaux WhatsApp avec Critères de Risque

## 🎯 Vue d'ensemble

Le système de signaux WhatsApp automatise l'envoi des signaux de trading par WhatsApp en respectant des critères de risque stricts pour protéger le capital.

## 🔧 Fonctionnalités

### ✅ **Envoi Automatique WhatsApp**
- **Surveillance continue** de l'API de signaux
- **Envoi automatique** des signaux respectant les critères
- **Messages formatés** avec emojis et informations détaillées
- **Prévention des doublons** (chaque signal n'est envoyé qu'une fois)

### 🛡️ **Critères de Risque Stricts**
- **Stop Loss maximum** : 10 pips
- **Take Profit minimum** : 30 pips
- **Ratio R/R minimum** : 1:3
- **Validation automatique** avant envoi

### 📊 **Types de Symboles Supportés**
- **Paires de devises** : EURUSD, GBPUSD, etc. (pip = 0.0001)
- **Paires JPY** : USDJPY, EURJPY, etc. (pip = 0.01)
- **Indices** : Boom 500 Index, Crash 500 Index, etc. (pip = 0.1)

## 🚀 Installation et Configuration

### 1. **Prérequis**
```bash
# Vérifier que WhatsApp est configuré
python -c "from frontend.whatsapp_notify import send_whatsapp_message_unified; print('✅ WhatsApp OK')"
```

### 2. **Lancement du Surveillant**
```bash
# Option 1: Script Python
python start_whatsapp_monitor.py

# Option 2: Fichier batch (Windows)
lancer_whatsapp_monitor.bat
```

### 3. **Configuration**
Le surveillant est configuré avec les paramètres suivants :
- **API Signaux** : `http://localhost:8001`
- **Intervalle de vérification** : 10 secondes
- **SL maximum** : 10 pips
- **TP minimum** : 30 pips

## 📱 Format des Messages WhatsApp

### **Signal BUY**
```
🟢 SIGNAL SNIPER
📊 Boom 500 Index
🎯 BUY @ 5258.829
🛡️ SL: 5257.829 (10.0 pips)
🎯 TP: 5261.829 (30.0 pips)
⚡ Confiance: 80%
⏰ Valide jusqu'à: 2025-09-13 00:20:44
📈 Ratio R/R: 1:3.0
```

### **Signal SELL**
```
🔴 SIGNAL SNIPER
📊 Boom 500 Index
🎯 SELL @ 5258.829
🛡️ SL: 5259.829 (10.0 pips)
🎯 TP: 5255.829 (30.0 pips)
⚡ Confiance: 80%
⏰ Valide jusqu'à: 2025-09-13 00:20:44
📈 Ratio R/R: 1:3.0
```

## 🔍 Validation des Signaux

### **Critères d'Acceptation**
1. **Stop Loss** ≤ 10 pips
2. **Take Profit** ≥ 30 pips
3. **Confiance** ≥ 80%
4. **Signal non expiré**
5. **Signal non déjà traité**

### **Exemple de Validation**
```python
# Signal avec critères corrects
{
    "symbol": "Boom 500 Index",
    "side": "BUY",
    "price": 5258.829,
    "sl": 5257.829,    # 10 pips
    "tp": 5261.829,    # 30 pips
    "confidence": 0.8
}
# ✅ Accepté - Ratio R/R = 1:3
```

## 📊 Statistiques et Monitoring

### **Statut du Surveillant**
```python
{
    'running': True,
    'enabled': True,
    'processed_signals_count': 15,
    'last_check_time': '2025-09-13T00:15:30',
    'whatsapp_available': True,
    'max_sl_pips': 10.0,
    'min_tp_pips': 30.0
}
```

### **Logs et Monitoring**
- **Logs détaillés** de chaque opération
- **Statistiques** des signaux traités
- **Alertes** en cas d'erreur
- **Statut** en temps réel

## 🛠️ Architecture Technique

### **Composants Principaux**

#### 1. **SignalWhatsAppMonitor** (`backend/signal_whatsapp_monitor.py`)
- **Surveillance continue** de l'API de signaux
- **Validation** des critères de risque
- **Envoi** des messages WhatsApp
- **Gestion** des doublons

#### 2. **Intégration Streamlit** (`frontend/app_real_time.py`)
- **Envoi automatique** lors de la génération de signaux
- **Validation** avant publication
- **Formatage** des messages

#### 3. **Scripts de Lancement**
- **`start_whatsapp_monitor.py`** : Lancement Python
- **`lancer_whatsapp_monitor.bat`** : Lancement Windows

### **Flux de Données**
```
API Signaux → Surveillant → Validation → WhatsApp → Utilisateur
     ↓              ↓           ↓          ↓
  signals.json   Critères    Formatage   Message
```

## 🔧 Personnalisation

### **Modifier les Critères de Risque**
```python
monitor = SignalWhatsAppMonitor(
    max_sl_pips=15.0,    # SL max 15 pips
    min_tp_pips=45.0,    # TP min 45 pips
    check_interval=5     # Vérifier toutes les 5 secondes
)
```

### **Modifier le Format des Messages**
```python
def _format_whatsapp_message(self, signal, sl_pips, tp_pips):
    # Personnaliser le format du message
    message = f"🚀 {signal['symbol']} {signal['side']}"
    # ...
    return message
```

## 📈 Avantages du Système

### **Sécurité**
- **Critères stricts** de gestion du risque
- **Validation automatique** avant envoi
- **Prévention** des signaux dangereux

### **Efficacité**
- **Envoi automatique** sans intervention manuelle
- **Surveillance continue** 24/7
- **Messages formatés** et informatifs

### **Flexibilité**
- **Configuration** des critères de risque
- **Support** de tous les types de symboles
- **Intégration** avec l'écosystème TradBOT

## 🚨 Dépannage

### **Problèmes Courants**

#### **WhatsApp non disponible**
```
⚠️ WhatsApp non disponible: No module named 'whatsapp_notify'
```
**Solution** : Vérifier que WhatsApp est configuré dans `frontend/whatsapp_notify.py`

#### **API de signaux indisponible**
```
⚠️ API de signaux non disponible sur le port 8001
```
**Solution** : Démarrer l'API avec `python start_signal_api.py`

#### **Signaux rejetés**
```
⚠️ Signal rejeté - Critères non respectés: SL=15.2pips, TP=25.1pips
```
**Solution** : Ajuster les paramètres de génération des signaux

### **Logs de Debug**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 📋 Checklist de Déploiement

- [ ] **WhatsApp configuré** et testé
- [ ] **API de signaux** démarrée sur le port 8001
- [ ] **Critères de risque** définis (SL max 10 pips, TP min 30 pips)
- [ ] **Surveillant** lancé et fonctionnel
- [ ] **Test** avec des signaux réels
- [ ] **Monitoring** des logs et statistiques

## 🎯 Résultat Final

Le système garantit que **seuls les signaux respectant vos critères de risque stricts** (SL max 10 pips, TP min 30 pips) sont envoyés par WhatsApp, offrant une **protection maximale du capital** tout en maintenant une **efficacité optimale** dans la réception des signaux de trading.
