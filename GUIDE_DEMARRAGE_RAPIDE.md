# 🚀 GUIDE DE DÉMARRAGE RAPIDE - ANGEL OF SPIKE

## ✅ ÉTAPES COMPLÉTÉES

### 1. **API de Tendance** ✅
- ✅ L'API est maintenant en cours d'exécution sur le port 8001
- ✅ Fournit les données de tendance pour le scalping automatique

### 2. **Robot Angel of Spike** ✅
- ✅ Compilation sans erreurs
- ✅ Fonctions de scalping automatique intégrées
- ✅ Gestion des risques ($3.50/$5.00) configurée
- ✅ Support de tous les symboles Boom/Crash

## 🎯 PROCHAINES ÉTAPES

### 1. **Compiler le Robot dans MetaTrader 5**
```
1. Ouvrir MetaTrader 5
2. Aller dans l'éditeur MetaEditor (F4)
3. Ouvrir le fichier: D:\Dev\TradBOT\mt5\AngelOfSpike.mq5
4. Cliquer sur "Compile" (F7)
5. Vérifier qu'il n'y a pas d'erreurs
```

### 2. **Attacher l'EA à un Graphique**
```
1. Ouvrir un graphique Boom 1000 Index ou Crash 1000 Index
2. Glisser-déposer l'EA AngelOfSpike sur le graphique
3. Dans les paramètres, vérifier:
   - InpEnableAutoScalping = true
   - InpScalpMaxLossUSD = 3.50
   - InpScalpTargetProfitUSD = 5.00
   - InpShowSpikeArrow = true
4. Cliquer sur "OK"
```

### 3. **Surveiller le Fonctionnement**
```
1. Ouvrir l'onglet "Experts" dans MetaTrader 5
2. Chercher ces messages:
   - 🎯 SIGNAL EMA DÉTECTÉ
   - 🔮 SPIKE PRÉDIT
   - 🚀 SPIKE IMMÉDIAT
   - ✅ Position ouverte au marché
```

## 📊 FONCTIONNALITÉS ACTIVES

### **Détection de Spike**
- ✅ Flèches de prédiction (vertes/rouges)
- ✅ Affichage du pourcentage de confiance
- ✅ Animation de clignotement

### **Trading Automatique**
- ✅ Ouverture de positions au marché
- ✅ SL/TP automatiques ($3.50/$5.00)
- ✅ Gestion des cooldowns (60 secondes)

### **Symboles Supportés**
- ✅ Boom 300/500/1000 Index
- ✅ Crash 300/500/1000 Index

## 🔧 PARAMÈTRES IMPORTANTS

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `InpEnableAutoScalping` | `true` | Active le scalping automatique |
| `InpScalpMaxLossUSD` | `3.50` | Perte maximale par trade |
| `InpScalpTargetProfitUSD` | `5.00` | Gain cible par trade |
| `InpScalpMinIntervalSec` | `60` | Intervalle entre trades |
| `InpShowSpikeArrow` | `true` | Affiche les flèches de prédiction |

## 🚨 VÉRIFICATIONS IMPORTANTES

### **Avant de Trader en Live**
1. ✅ Tester d'abord en mode démo
2. ✅ Vérifier que les flèches apparaissent
3. ✅ Confirmer que les positions s'ouvrent
4. ✅ Vérifier les SL/TP automatiques

### **Messages d'Erreur à Surveiller**
- ❌ "Impossible de créer les handles EMA" → Problème de données
- ❌ "Spread trop élevé" → Attendre un meilleur moment
- ❌ "Cooldown actif" → Attendre 60 secondes

## 🎉 RÉSULTAT ATTENDU

Le robot devrait maintenant :
1. **Afficher des flèches de prédiction** sur les graphiques Boom/Crash
2. **Ouvrir automatiquement des positions** quand un signal est détecté
3. **Fermer automatiquement** à $5.00 profit ou $3.50 perte
4. **Respecter les cooldowns** entre les trades

## 📞 SUPPORT

Si vous rencontrez des problèmes :
1. Vérifier les logs dans l'onglet "Experts"
2. S'assurer que l'API de tendance fonctionne
3. Vérifier que les symboles Boom/Crash sont disponibles
4. Contrôler les paramètres de l'EA

**Le robot est maintenant prêt à fonctionner ! 🚀**
