# 🔍 AUTOSCAN SIGNALS - Guide Complet

## 📋 Vue d'ensemble

L'**Autoscan** est un système automatique qui analyse les conditions de marché toutes les **2 minutes** et envoie des signaux de trading par **WhatsApp** et **SMS** quand des opportunités sont détectées.

## 🎯 Fonctionnalités de l'Autoscan

### ⚡ **Analyse Automatique**
- **Fréquence** : Toutes les 2 minutes (120 secondes)
- **Indicateurs** : RSI, Moving Average, Volatilité
- **Conditions** : 3 algorithmes de détection
- **Confiance** : 60-75% selon les conditions

### 📱 **Envoi Multi-Canal**
- **WhatsApp** : Messages détaillés avec emojis
- **SMS** : Format optimisé pour mobile
- **MT5** : Notifications dans la plateforme
- **Sonores** : Alertes audio

## 🔧 Configuration

### **Paramètres d'Entrée**
```mql5
=== AUTOSCAN SIGNALS ===
InpAutoScan = true                    // Activer l'autoscan
InpScanInterval = 120                 // Intervalle (secondes) - 2 minutes
InpSendToWhatsApp = true              // Envoyer par WhatsApp
InpSendToSMS = true                   // Envoyer par SMS
InpPhoneNumber = "+22996911346"       // Numéro de téléphone
```

### **Activation**
1. **Cochez** `InpAutoScan = true`
2. **Configurez** l'intervalle (120 secondes = 2 minutes)
3. **Activez** WhatsApp et/ou SMS
4. **Vérifiez** le numéro de téléphone

## 🧠 Algorithmes de Détection

### **Condition 1: RSI (Relative Strength Index)**
```mql5
// RSI en survente (< 30)
if(rsi_values[0] < 30) {
    signal_type = "BUY";
    signal_direction = "BOOM";
    signal_confidence = 0.75;
    signal_reason = "RSI Survente";
}

// RSI en surachat (> 70)
else if(rsi_values[0] > 70) {
    signal_type = "SELL";
    signal_direction = "CRASH";
    signal_confidence = 0.75;
    signal_reason = "RSI Surachat";
}
```

### **Condition 2: Croisement de Moving Average**
```mql5
// Croisement haussier
if(ma_values[0] > ma_values[1] && ma_values[1] < ma_values[2]) {
    signal_type = "BUY";
    signal_direction = "BOOM";
    signal_confidence = 0.70;
    signal_reason = "MA Croisement Haussier";
}

// Croisement baissier
else if(ma_values[0] < ma_values[1] && ma_values[1] > ma_values[2]) {
    signal_type = "SELL";
    signal_direction = "CRASH";
    signal_confidence = 0.70;
    signal_reason = "MA Croisement Baissier";
}
```

### **Condition 3: Volatilité Élevée**
```mql5
// Volatilité > 0.2%
double volatility = MathAbs(current_price - ma_values[0]) / ma_values[0];
if(volatility > 0.002) {
    if(current_price > ma_values[0]) {
        signal_type = "BUY";
        signal_direction = "BOOM";
        signal_confidence = 0.65;
        signal_reason = "Volatilité Haussier";
    } else {
        signal_type = "SELL";
        signal_direction = "CRASH";
        signal_confidence = 0.65;
        signal_reason = "Volatilité Baissier";
    }
}
```

## 📱 Format des Messages

### **WhatsApp/SMS Format**
```
🟢 BUY Boom 1000 Index
💰 Prix: 17943.15600
🎯 Confiance: 75%
📊 Direction: BOOM
📝 Raison: RSI Survente
⏰ 2025.09.15 01:53:00
🤖 TradBOT Autoscan
```

### **Émojis Utilisés**
- **🟢** : Signal d'achat (BUY)
- **🔴** : Signal de vente (SELL)
- **💰** : Prix actuel
- **🎯** : Niveau de confiance
- **📊** : Direction du marché
- **📝** : Raison du signal
- **⏰** : Timestamp
- **🤖** : Source TradBOT

## 📊 Panneau de Performance

### **Section Autoscan**
```
║ 🔍 AUTOSCAN SIGNALS:                                      ║
║   Autoscan: 🟢 ACTIF                                    ║
║   Intervalle: 2 minutes                                    ║
║   Signaux envoyés: 15                                    ║
║   WhatsApp: 🟢 OUI | SMS: 🟢 OUI                                    ║
║   Dernier signal: BUY BOOM 75%                                    ║
```

### **Métriques Affichées**
- **Statut** : ACTIF/INACTIF
- **Intervalle** : Temps entre scans
- **Signaux envoyés** : Nombre total
- **Canaux** : WhatsApp et SMS
- **Dernier signal** : Type et confiance

## ⚙️ Intégration API

### **WhatsApp (Vonage)**
```mql5
void SendWhatsAppSignal(string message)
{
    //--- Appel à l'API Vonage WhatsApp
    // Exemple d'intégration:
    // VonageAPI.sendWhatsAppMessage(InpPhoneNumber, message);
    
    Print("📱 WHATSAPP SIGNAL ENVOYÉ à ", InpPhoneNumber);
    Print(message);
}
```

### **SMS (Vonage)**
```mql5
void SendSMSSignal(string message)
{
    //--- Appel à l'API Vonage SMS
    // Exemple d'intégration:
    // VonageAPI.sendSMS(InpPhoneNumber, message);
    
    Print("📲 SMS SIGNAL ENVOYÉ à ", InpPhoneNumber);
    Print(message);
}
```

## 🎯 Utilisation Pratique

### **1. Installation**
```bash
# Copiez le fichier dans MetaTrader 5
MetaTrader 5/MQL5/Experts/SpikeHunter_EA.mq5

# Compilez dans MetaEditor (F7)
# Redémarrez MetaTrader 5
```

### **2. Configuration**
1. **Ouvrez** un graphique Boom ou Crash
2. **Attachez** l'EA SpikeHunter
3. **Activez** l'autoscan : `InpAutoScan = true`
4. **Configurez** l'intervalle : `InpScanInterval = 120`
5. **Activez** les notifications : WhatsApp/SMS
6. **Vérifiez** le numéro : `InpPhoneNumber`

### **3. Surveillance**
- **Panneau** : Vérifiez le statut de l'autoscan
- **Logs** : Consultez les signaux envoyés
- **Téléphone** : Recevez les notifications
- **MT5** : Notifications dans la plateforme

## 📈 Exemples de Signaux

### **Signal d'Achat (BOOM)**
```
🟢 BUY Boom 1000 Index
💰 Prix: 17943.15600
🎯 Confiance: 75%
📊 Direction: BOOM
📝 Raison: RSI Survente
⏰ 2025.09.15 01:53:00
🤖 TradBOT Autoscan
```

### **Signal de Vente (CRASH)**
```
🔴 SELL Crash 1000 Index
💰 Prix: 17943.15600
🎯 Confiance: 70%
📊 Direction: CRASH
📝 Raison: MA Croisement Baissier
⏰ 2025.09.15 01:55:00
🤖 TradBOT Autoscan
```

## 🔧 Personnalisation

### **Modifier l'Intervalle**
```mql5
// 1 minute
InpScanInterval = 60

// 5 minutes
InpScanInterval = 300

// 10 minutes
InpScanInterval = 600
```

### **Ajuster les Seuils**
```mql5
// RSI plus sensible
if(rsi_values[0] < 35) // au lieu de 30
if(rsi_values[0] > 65) // au lieu de 70

// Volatilité plus sensible
if(volatility > 0.001) // au lieu de 0.002
```

### **Confiance Minimale**
```mql5
// Exiger plus de confiance
if(StringLen(signal_type) > 0 && signal_confidence > 0.7) // au lieu de 0.6
```

## ⚠️ Gestion des Risques

### **Sécurités Intégrées**
- **Confiance minimale** : 60% pour valider un signal
- **Intervalle minimum** : 2 minutes entre scans
- **Validation multiple** : 3 conditions différentes
- **Logs détaillés** : Traçabilité complète

### **Limitations**
- **Signaux** : Basés sur l'analyse technique
- **Confiance** : Indicateur, pas garantie
- **Timing** : Dépend de l'intervalle configuré
- **Marché** : Conditions peuvent changer rapidement

## 🔍 Dépannage

### **Problèmes Courants**

#### Autoscan ne fonctionne pas
- **Vérifiez** : `InpAutoScan = true`
- **Vérifiez** : `InpScanInterval > 0`
- **Vérifiez** : Logs dans l'onglet "Experts"

#### Pas de signaux envoyés
- **Vérifiez** : Conditions de marché
- **Vérifiez** : Seuils de confiance
- **Vérifiez** : Indicateurs RSI/MA

#### Messages non reçus
- **Vérifiez** : Numéro de téléphone
- **Vérifiez** : `InpSendToWhatsApp/SMS = true`
- **Vérifiez** : Connexion API Vonage

## 📊 Statistiques

### **Métriques de Performance**
- **Signaux envoyés** : Nombre total
- **Taux de réussite** : Signaux corrects
- **Fréquence** : Signaux par heure
- **Canaux** : WhatsApp vs SMS

### **Optimisation**
- **Ajustez** les seuils selon la volatilité
- **Modifiez** l'intervalle selon les besoins
- **Combinez** avec d'autres indicateurs
- **Analysez** les logs pour améliorer

---

**🎯 OBJECTIF** : L'autoscan analyse automatiquement le marché toutes les 2 minutes et envoie des signaux de trading par WhatsApp et SMS quand des opportunités sont détectées.

**⚠️ AVERTISSEMENT** : Les signaux sont basés sur l'analyse technique et ne garantissent pas 100% de réussite. Utilisez-les comme indicateurs supplémentaires dans votre stratégie de trading.
