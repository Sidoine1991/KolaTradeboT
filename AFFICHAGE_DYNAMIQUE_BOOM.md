# 📊 Affichage Dynamique Boom Rising Channel Predictor

## 📋 Vue d'Ensemble

Le système d'**Affichage Dynamique Boom Rising Channel Predictor** permet d'afficher en temps réel les résultats d'analyse directement sur le graphique MT5 dans un cadran en bas à droite. Cette fonctionnalité est spécialement conçue pour le robot AngelOfSpike et affiche toutes les informations importantes de l'analyse du canal haussier.

## 🎯 Fonctionnalités Principales

### ✅ **Affichage en Temps Réel**
- **Cadran dynamique** en bas à droite du graphique MT5
- **Mise à jour automatique** toutes les 5 secondes
- **Couleurs adaptatives** selon la direction et la confiance
- **Informations complètes** de l'analyse Boom

### ✅ **Informations Affichées**
- **Direction**: BUY, SELL, NEUTRAL
- **Force**: Force de la tendance (0-100%)
- **Confiance**: Confiance de la prédiction (0-100%)
- **Signal**: Signal de trading généré
- **Probabilité Spike**: Probabilité de spike (0-100%)
- **Temps estimé**: Temps jusqu'au spike (secondes)
- **Proximité EMA**: EMA10, EMA30, EMA50
- **Position Canal**: upper, middle, lower
- **Prix actuel**: Prix actuel du symbole
- **Force Canal**: Force du canal haussier
- **Probabilité Breakout**: Probabilité de breakout
- **Horodatage**: Heure de dernière mise à jour

### ✅ **Couleurs Dynamiques**
- **Vert**: Direction BUY avec confiance élevée
- **Rouge**: Direction SELL avec confiance élevée
- **Jaune**: Direction NEUTRAL ou confiance faible
- **Gris**: Erreur de connexion ou données manquantes

## 🚀 Installation et Utilisation

### **Prérequis**
- MetaTrader 5 installé et connecté
- API Boom Rising Channel Predictor démarrée (port 8002)
- Symbole "Boom 1000 Index" disponible
- Python 3.8+ avec MetaTrader5

### **Installation Rapide**
```bash
# Installer les dépendances
pip install MetaTrader5 requests

# Démarrer l'affichage
python boom_display_mt5.py

# Ou utiliser le lanceur
python launch_boom_display.py
```

### **Utilisation Windows**
```bash
# Fichier batch
lancer_affichage_boom.bat
```

## 📊 Configuration de l'Affichage

### **Position et Taille**
```python
display_config = {
    'position_x': 0.75,  # Position X (0-1) - 75% de la largeur
    'position_y': 0.15,  # Position Y (0-1) - 15% de la hauteur
    'width': 0.23,       # Largeur (0-1) - 23% de la largeur
    'height': 0.25,      # Hauteur (0-1) - 25% de la hauteur
}
```

### **Couleurs**
```python
colors = {
    'background_color': 0x1E1E1E,  # Fond sombre
    'text_color': 0xFFFFFF,       # Texte blanc
    'border_color': 0x00FF00,      # Bordure verte par défaut
}
```

### **Police**
```python
font = {
    'font_name': "Arial",
    'font_size': 8
}
```

## 🔧 Configuration Avancée

### **Changer le Symbole**
```python
from boom_display_mt5 import set_boom_symbol
set_boom_symbol("Boom 500 Index")
```

### **Changer le Timeframe**
```python
from boom_display_mt5 import set_boom_timeframe
set_boom_timeframe("M5")
```

### **Changer l'Intervalle de Mise à Jour**
```python
from boom_display_mt5 import boom_display
boom_display.set_update_interval(10)  # 10 secondes
```

### **Changer la Position**
```python
from boom_display_mt5 import boom_display
boom_display.set_display_position(0.8, 0.2, 0.2, 0.3)
```

## 📱 Intégration avec AngelOfSpike

### **EA MT5 Intégré**
Le fichier `BoomDisplayEA.mq5` contient un Expert Advisor complet qui intègre l'affichage dynamique directement dans le robot AngelOfSpike.

### **Paramètres EA**
```mql5
input string InpApiUrl = "http://localhost:8002/angelofspike/trend";
input string InpSymbol = "Boom 1000 Index";
input string InpTimeframe = "M1";
input int    InpUpdateInterval = 5;
input double InpDisplayX = 0.75;
input double InpDisplayY = 0.15;
input double InpDisplayWidth = 0.23;
input double InpDisplayHeight = 0.25;
```

### **Installation EA**
1. Copier `BoomDisplayEA.mq5` dans le dossier `MQL5/Experts/`
2. Compiler l'EA dans MetaEditor
3. Attacher l'EA au graphique Boom
4. Configurer les paramètres selon vos besoins

## 🎨 Personnalisation de l'Affichage

### **Format du Texte**
Le texte d'affichage est formaté comme suit:
```
🚀 BOOM RISING CHANNEL
━━━━━━━━━━━━━━━━━━━━━━
Direction: BUY
Force: 85%
Confiance: 78%
Signal: boom_trade
Spike Prob: 85.0%
Temps: 120s
EMA: EMA10
Canal: lower
Prix: 10050.00
Canal Force: 87.4%
Breakout: 17.8%
⏰ 14:30:25
```

### **Couleurs de Bordure**
- **Vert vif** (0x00FF00): BUY avec confiance ≥ 80%
- **Rouge vif** (0xFF0000): SELL avec confiance ≥ 80%
- **Jaune vif** (0xFFFF00): NEUTRAL avec confiance ≥ 80%
- **Vert moyen** (0x00AA00): BUY avec confiance 60-79%
- **Rouge moyen** (0xAA0000): SELL avec confiance 60-79%
- **Jaune moyen** (0xAAAA00): NEUTRAL avec confiance 60-79%
- **Gris** (0x666666): Confiance < 60% ou erreur

## 🧪 Tests et Validation

### **Test Rapide**
```bash
python launch_boom_display.py --test
```

### **Test Complet**
```bash
python boom_display_mt5.py
```

### **Vérification API**
```bash
curl "http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1"
```

## 📊 Exemple de Réponse API

```json
{
    "symbol": "Boom 1000 Index",
    "timeframe": "M1",
    "timestamp": 1760255047.731543,
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
    "lot_size": 0.1,
    "reasoning": "Pattern canal haussier détecté - Proximité EMA10 - Position lower",
    "channel_strength": 0.8742492517612188,
    "breakout_probability": 0.17824032861154943
}
```

## 🚨 Dépannage

### **Problèmes Courants**

#### **Cadran Non Visible**
```
Problème: Le cadran n'apparaît pas sur le graphique
Solution: Vérifier que MT5 est ouvert et connecté
```

#### **Données Non Mises à Jour**
```
Problème: Les données restent statiques
Solution: Vérifier que l'API Boom est accessible sur le port 8002
```

#### **Erreur de Connexion**
```
Problème: "Erreur connexion API"
Solution: Démarrer l'API Boom: python boom_api.py
```

#### **Position Incorrecte**
```
Problème: Le cadran est mal positionné
Solution: Ajuster les paramètres position_x, position_y, width, height
```

### **Logs de Debug**
```bash
# Activer les logs détaillés
python boom_display_mt5.py --debug

# Vérifier les logs
tail -f boom_display.log
```

## 📈 Performances

### **Optimisations**
- **Cache intelligent**: Évite les mises à jour inutiles
- **Thread séparé**: N'affecte pas les performances MT5
- **Mise à jour conditionnelle**: Seulement si les données changent
- **Gestion mémoire**: Suppression automatique des anciens objets

### **Métriques**
- **Temps de réponse API**: < 1 seconde
- **Fréquence de mise à jour**: 5 secondes par défaut
- **Utilisation mémoire**: Minimale
- **Impact MT5**: Négligeable

## 🔄 Intégration avec d'Autres Systèmes

### **API REST**
L'affichage peut être intégré avec d'autres systèmes via l'API REST:
```bash
# Obtenir le statut de l'affichage
curl "http://localhost:8002/status"

# Obtenir la dernière analyse
curl "http://localhost:8002/predict?symbol=Boom 1000 Index"
```

### **Webhooks**
Possibilité d'ajouter des webhooks pour notifier d'autres systèmes des changements d'analyse.

### **Base de Données**
Les analyses peuvent être sauvegardées en base de données pour historique et statistiques.

## 📚 Documentation Technique

### **Architecture**
```
📊 Graphique MT5
    ↓ (Objets graphiques)
🎨 Affichage Dynamique
    ↓ (Requêtes HTTP)
📡 API Boom Rising Channel Predictor
    ↓ (Analyse)
🧠 Boom Rising Channel Predictor
    ↓ (Prédictions)
🎯 Résultats d'Analyse
```

### **Objets MT5 Utilisés**
- **OBJ_RECTANGLE_LABEL**: Rectangle de fond
- **OBJ_LABEL**: Texte d'affichage
- **Propriétés**: Position, taille, couleurs, police

### **Threading**
- **Thread principal**: Interface MT5
- **Thread d'affichage**: Mise à jour des données
- **Synchronisation**: Thread-safe pour les objets MT5

## 🎉 Conclusion

Le système d'**Affichage Dynamique Boom Rising Channel Predictor** offre une solution complète pour visualiser en temps réel les prédictions du canal haussier directement sur le graphique MT5. Avec ses fonctionnalités avancées, sa personnalisation flexible et son intégration parfaite avec AngelOfSpike, il constitue un outil indispensable pour le trading Boom.

**L'affichage dynamique est maintenant prêt et opérationnel! 📊🚀**
