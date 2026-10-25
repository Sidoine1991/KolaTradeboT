# 📊 GUIDE D'INTÉGRATION API SUR GRAPHIQUE

## ✅ FONCTIONNALITÉS AJOUTÉES

### **1. Affichage des Données API sur le Graphique**
- ✅ **Direction de tendance** (bullish/bearish/neutral) avec couleurs
- ✅ **Force de tendance** (0-100%) 
- ✅ **Niveau de confiance** (high/medium/low)
- ✅ **Probabilité de spike** (0-100%)
- ✅ **Signal de trading** (BUY STRONG/SELL STRONG/BUY WEAK/SELL WEAK/WAIT)
- ✅ **Timestamp de mise à jour**

### **2. Positionnement sur le Graphique**
- 📍 **Colonne 3** : Données API (à droite du HUD principal)
- 🎨 **Couleurs dynamiques** :
  - 🟢 **Vert** : Tendance bullish
  - 🔴 **Rouge** : Tendance bearish  
  - 🟡 **Jaune** : Tendance neutre
  - ⚪ **Blanc** : Données générales

### **3. Mise à Jour en Temps Réel**
- ⏱️ **Rafraîchissement** : Toutes les secondes
- 🔄 **Synchronisation** : Avec le HUD principal
- 🧹 **Nettoyage automatique** : Suppression des anciens objets

## 🚀 UTILISATION

### **1. Démarrer l'API Réelle**
```bash
# Option 1 - Batch
lancer_api_reelle.bat

# Option 2 - PowerShell
python trend_api_real.py
```

### **2. Compiler et Attacher l'EA**
```
1. Compiler AngelOfSpike.mq5 dans MetaTrader 5
2. Attacher à un graphique Boom/Crash
3. Vérifier que InpShowHUD = true
4. Vérifier que InpScalpUseTrendAPI = true
```

### **3. Observer les Données sur le Graphique**
```
Le graphique affichera maintenant :
- === API TREND DATA ===
- Direction: bullish/bearish/neutral
- Force: XX.X%
- Confiance: high/medium/low
- Spike Prob: XX.X%
- Signal: BUY STRONG/SELL STRONG/etc.
- Update: HH:MM
```

## 📊 EXEMPLE D'AFFICHAGE

```
=== API TREND DATA ===
Direction: bullish          (en vert)
Force: 85.2%               (en blanc)
Confiance: high            (en blanc)
Spike Prob: 82.5%          (en blanc)
Signal: BUY STRONG         (en vert)
Update: 14:35              (en gris)
```

## 🔧 CONFIGURATION

### **Paramètres Importants**
| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `InpShowHUD` | `true` | Active l'affichage HUD |
| `InpScalpUseTrendAPI` | `true` | Utilise l'API de tendance |
| `InpTrendAPIUrl` | `http://localhost:8001/trend` | URL de l'API |

### **Position des Données**
- **X** : `InpHUDX + 400` (colonne 3)
- **Y** : `InpHUDY + 100` (décalage vertical)
- **Espacement** : `InpHUDLineSpacing` (16 pixels)

## 🎯 SIGNALS DE TRADING

### **BUY STRONG** 🟢
- Direction: bullish
- Spike Prob: > 70%
- Action: Trade immédiat recommandé

### **SELL STRONG** 🔴
- Direction: bearish  
- Spike Prob: > 70%
- Action: Trade immédiat recommandé

### **BUY WEAK** 🟡
- Direction: bullish
- Spike Prob: 50-70%
- Action: Attendre confirmation

### **SELL WEAK** 🟠
- Direction: bearish
- Spike Prob: 50-70%
- Action: Attendre confirmation

### **WAIT** ⚪
- Direction: neutral
- Spike Prob: < 50%
- Action: Ne pas trader

## 🔄 MISE À JOUR DES DONNÉES

### **Fréquence**
- ⏱️ **Toutes les secondes** avec le HUD
- 🔄 **Synchronisé** avec le timer principal
- 📊 **Données réalistes** basées sur l'heure

### **Source des Données**
- 🕐 **Heure de trading** : Influence la force de tendance
- 📈 **Volatilité** : Calculée selon l'activité du marché
- 🎯 **Probabilité de spike** : Basée sur l'heure et la tendance

## 🧹 NETTOYAGE AUTOMATIQUE

### **Objets Supprimés**
- `API_TITLE` - Titre principal
- `API_DIRECTION` - Direction de tendance
- `API_STRENGTH` - Force de tendance
- `API_CONFIDENCE` - Niveau de confiance
- `API_SPIKE` - Probabilité de spike
- `API_SIGNAL` - Signal de trading
- `API_TIME` - Timestamp

### **Moment du Nettoyage**
- 🔄 **Chaque mise à jour** : Suppression des anciens objets
- 🛑 **Fermeture EA** : Suppression de tous les objets
- 🧹 **Changement de symbole** : Nettoyage automatique

## 🎉 RÉSULTAT FINAL

Le graphique affiche maintenant **en temps réel** :
1. ✅ **Données de l'API** intégrées au HUD
2. ✅ **Signals de trading** clairs et colorés
3. ✅ **Mise à jour automatique** toutes les secondes
4. ✅ **Interface professionnelle** et lisible
5. ✅ **Synchronisation parfaite** avec le robot

**L'intégration API sur le graphique est maintenant complète ! 🚀**
