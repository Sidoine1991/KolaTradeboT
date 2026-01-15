# 📤 MT5 History Uploader - Bridge vers Render

## 🎯 Objectif

Ce script MQL5 permet d'envoyer automatiquement les données historiques MT5 vers le serveur Render, permettant au système ML avancé d'avoir accès aux 2000 bougies nécessaires même si MT5 n'est pas installé sur Render.

## 🚀 Installation

1. **Copier le fichier** `MT5_HistoryUploader.mq5` dans le dossier `MQL5/Experts/` de MetaTrader5

2. **Compiler** le script dans MetaEditor (F7)

3. **Autoriser WebRequest dans MT5** :
   - Aller dans `Outils -> Options -> Expert Advisors`
   - Cocher "Autoriser WebRequest pour les URL listées"
   - Ajouter : `https://kolatradebot.onrender.com`

4. **Attacher le script** à un graphique (n'importe lequel, il fonctionne en arrière-plan)

## ⚙️ Configuration

Dans les paramètres du script :

- **API_URL** : URL de l'endpoint Render (par défaut: `https://kolatradebot.onrender.com/mt5/history-upload`)
- **BarsToUpload** : Nombre de bougies à envoyer (par défaut: 2000)
- **UploadInterval** : Intervalle entre les uploads en secondes (par défaut: 60)
- **AutoUpload** : Upload automatique au démarrage et périodiquement (par défaut: true)
- **UploadOnRequest** : Upload uniquement sur demande (par défaut: false)

## 📊 Symboles uploadés

Le script upload automatiquement les données pour tous ces symboles :

- **Forex** : EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF, NZDUSD
- **Commodities** : XAUUSD, XAGUSD, US Oil
- **Crypto** : BTCUSD, ETHUSD, LTCUSD, XRPUSD, TRXUSD, UNIUSD, SHBUSD, TONUSD
- **Boom/Crash** : Boom 300/500/600/900/150, Crash 300/600/900/150/1000
- **Volatility** : Volatility 10/25/50/100/75/150/250
- **Autres indices** : Step Index, Jump Index, DEX Index, etc.

## 🔄 Fonctionnement

1. **Au démarrage** : Si `AutoUpload = true`, le script upload immédiatement toutes les données
2. **Périodiquement** : Toutes les `UploadInterval` secondes, le script ré-upload les données pour tous les symboles
3. **Format** : Les données sont envoyées au format JSON avec structure OHLCV

## ✅ Vérification

Pour vérifier que ça fonctionne :

1. **Logs MT5** : Tu devrais voir dans les logs :
   ```
   ✅ Upload réussi pour EURUSD PERIOD_M1 (2000 bougies) - HTTP 200
   ```

2. **Logs Render** : Dans les logs du serveur Render, tu devrais voir :
   ```
   ✅ Données historiques uploadées depuis MT5: 2000 bougies pour EURUSD M1
   ```

3. **Résultat** : Les warnings "⚠️ Données ML insuffisantes ... 0 bougies" devraient disparaître dans les logs Render

## 🐛 Dépannage

### Erreur 4060 (URL non autorisée)
- Vérifier que l'URL est bien dans la liste WebRequest de MT5
- Redémarrer MT5 après modification

### Erreur de connexion
- Vérifier que le serveur Render est bien accessible
- Vérifier l'URL dans les paramètres du script

### Symboles non disponibles
- Le script logue un warning mais continue avec les autres symboles
- Vérifier que les symboles sont bien disponibles dans ton broker MT5

## 📝 Notes

- Le script fonctionne en arrière-plan, tu peux l'attacher à n'importe quel graphique
- Les données sont mises en cache côté Render avec un TTL de 5 minutes
- Le script upload uniquement les données M1 (prioritaire pour le ML)
- Pour uploader d'autres timeframes, modifier le script et ajouter d'autres appels

