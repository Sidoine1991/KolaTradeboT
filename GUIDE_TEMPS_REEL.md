# 🚀 Guide d'utilisation - TradBOT Temps Réel

## 📋 Vue d'ensemble

Cette nouvelle version de TradBOT utilise **uniquement les vrais prix** de MetaTrader 5 pour les prédictions en temps réel. Plus de données factices !

## ⚡ Fonctionnalités principales

### ✅ Prédictions basées sur les vrais prix
- Connexion directe à MetaTrader 5
- Données OHLC en temps réel
- Prix actuels mis à jour automatiquement
- Indicateurs techniques calculés sur les vraies données

### 🎯 Prédiction de spikes en temps réel
- Modèle ML entraîné sur des données réelles
- Détection de patterns de prix
- Alertes sonores automatiques
- Probabilités de spike calculées en continu

### 📊 Interface temps réel
- Graphiques en temps réel
- Métriques de prix actuelles
- Analyse technique instantanée
- Rafraîchissement automatique

## 🔧 Configuration requise

### 1. Installation de MetaTrader 5
```bash
# Installer MetaTrader 5 Python
pip install MetaTrader5
```

### 2. Configuration des identifiants
Créer un fichier `.env` à la racine du projet :
```env
MT5_LOGIN=votre_login
MT5_PASSWORD=votre_mot_de_passe
MT5_SERVER=votre_serveur
```

### 3. Vérification de la connexion
```bash
python test_real_time_connection.py
```

## 🚀 Lancement de l'application

### Option 1: Application temps réel (recommandée)
```bash
cd frontend
streamlit run app_real_time.py
```

### Option 2: Application originale (avec données factices)
```bash
cd frontend
streamlit run app.py
```

## 📈 Utilisation

### 1. Connexion MT5
- Cliquer sur "🔗 Tester Connexion MT5" dans la sidebar
- Si la connexion échoue, vérifier les identifiants dans `.env`
- Cliquer sur "🔌 Connecter MT5" pour une connexion manuelle

### 2. Sélection du symbole
- Choisir une catégorie (Forex, Synthetic, etc.)
- Sélectionner le symbole désiré
- Choisir le timeframe (1m, 5m, 1h, etc.)

### 3. Analyse en temps réel
- Le prix actuel s'affiche automatiquement
- Le graphique se met à jour en temps réel
- Les indicateurs techniques sont calculés
- Les prédictions de spike apparaissent

### 4. Alertes
- Alertes sonores automatiques pour les spikes
- Notifications visuelles dans l'interface
- Historique des prédictions

## 🎯 Différences avec l'ancienne version

| Fonctionnalité | Ancienne version | Nouvelle version temps réel |
|----------------|------------------|------------------------------|
| Données | Factices (random) | Vraies prix MT5 |
| Connexion | Optionnelle | Obligatoire |
| Prédictions | Basées sur données factices | Basées sur vrais prix |
| Graphiques | Données abstraites | Données réelles |
| Spikes | Détection factice | Prédiction ML réelle |
| Temps réel | Simulé | Vraiment temps réel |

## 🔍 Dépannage

### Problème: "MT5 Non connecté"
**Solution:**
1. Vérifier que MetaTrader 5 est installé
2. Vérifier les identifiants dans `.env`
3. Tester la connexion avec le script de test

### Problème: "Aucune donnée disponible"
**Solution:**
1. Vérifier que le symbole existe dans MT5
2. S'assurer que le symbole est activé dans le Market Watch
3. Vérifier les permissions du compte

### Problème: "Erreur d'import"
**Solution:**
1. Installer les dépendances: `pip install -r requirements.txt`
2. Vérifier que MetaTrader5 est installé
3. Redémarrer l'application

## 📊 Interprétation des résultats

### Probabilité de spike
- **0-30%**: Faible probabilité
- **30-50%**: Probabilité modérée
- **50-70%**: Probabilité élevée
- **70%+**: Forte probabilité (alerte)

### Indicateurs techniques
- **RSI > 70**: Suralimenté (risque de correction)
- **RSI < 30**: Survente (opportunité d'achat)
- **MACD > Signal**: Tendance haussière
- **MACD < Signal**: Tendance baissière

## ⚠️ Avertissements

1. **Risque de trading**: Les prédictions ne garantissent pas les profits
2. **Connexion requise**: L'application nécessite une connexion MT5 active
3. **Données réelles**: Les prédictions sont basées sur les vrais prix du marché
4. **Latence**: Il peut y avoir un délai entre les prix MT5 et l'affichage

## 🆘 Support

En cas de problème :
1. Vérifier la configuration MT5
2. Consulter les logs d'erreur
3. Tester avec le script `test_real_time_connection.py`
4. Vérifier la documentation MT5

## 🎉 Avantages de la nouvelle version

✅ **Vrais prix** au lieu de données factices  
✅ **Prédictions réelles** basées sur l'analyse ML  
✅ **Temps réel** avec rafraîchissement automatique  
✅ **Alertes intelligentes** pour les opportunités  
✅ **Interface moderne** et intuitive  
✅ **Analyse technique** en temps réel  

---

**🎯 Maintenant vous avez une vraie application de trading avec des prédictions basées sur les vrais prix du marché !** 