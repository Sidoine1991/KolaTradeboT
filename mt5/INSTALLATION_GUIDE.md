# 🤖 MT5 Trading IA Robot - Guide d'Installation

## 📋 PRÉREQUIS

1. **MetaTrader 5** installé sur votre machine
2. **Compte de trading** actif avec les symboles Boom/Crash
3. **Connexion internet** stable pour accéder à l'API Render

## 🚀 INSTALLATION RAPIDE

### Étape 1: Copier les fichiers dans MT5

1. Ouvrir MetaTrader 5
2. Aller dans `Fichier` → `Ouvrir le dossier de données`
3. Naviguer vers `MQL5/Scripts/`
4. Copier les fichiers `.mq5` dans ce dossier

### Étape 2: Compiler les robots

1. Dans MT5, ouvrir l'**Éditeur MetaQuotes** (F4)
2. Ouvrir chaque fichier `.mq5`
3. Cliquer sur **Compiler** (F7)
4. Vérifier qu'il n'y a pas d'erreurs

### Étape 3: Démarrer le robot

#### Option A: Dashboard Simple
1. Sur un graphique, cliquer droit → **Scripts** → **MT5_Trading_Dashboard**
2. Configurer les paramètres si nécessaire
3. Cliquer **OK**

#### Option B: Robot Complet (Recommandé)
1. Sur un graphique, cliquer droit → **Experts** → **MT5_Auto_Trading_Robot**
2. Configurer les paramètres
3. Activer le trading automatique

## ⚙️ PARAMÈTRES

### Dashboard Simple
- **Render API**: URL de l'API (par défaut: https://kolatradebot.onrender.com)
- **Refresh Seconds**: Intervalle de rafraîchissement (5 secondes recommandé)
- **Colors**: Personnaliser les couleurs

### Robot Complet
- **Enable Trading**: Activer/désactiver les trades automatiques
- **Min Confidence**: Confiance minimale (70% recommandé)
- **Volumes**: Tailles de position par symbole
- **Show Dashboard**: Afficher l'interface

## 🎯 RÈGLES DE TRADING

### Restrictions Boom/Crash
- ✅ **Boom 300/600/900**: SELL uniquement (spikes baissiers)
- ✅ **Crash 1000**: BUY uniquement (spikes haussiers)
- ❌ **BUY sur Boom**: Bloqué automatiquement
- ❌ **SELL sur Crash**: Bloqué automatiquement

### Paramètres de sécurité
- 📊 **Confiance minimale**: 70%
- ⏱️ **Intervalle minimum**: 1 minute entre trades
- 📈 **Volumes**: 0.5 (Boom 300), 0.2 (autres)
- 🔄 **Rafraîchissement**: 10 secondes

## 📊 FONCTIONNALITÉS

### Dashboard Intégré
- **Monitoring temps réel** des 4 symboles
- **Signaux IA** avec confiance
- **Positions actuelles** avec P&L
- **Statistiques globales**
- **Contrôles interactifs**

### Robot Automatique
- **Exécution automatique** des signaux IA
- **Respect des restrictions** Boom/Crash
- **Gestion du risque** avec volumes adaptés
- **Notifications MT5** pour chaque trade
- **Logging détaillé** dans l'onglet Experts

## 🔧 DÉPANNAGE

### Problèmes Communs

#### "WebRequest failed"
- **Cause**: Firewall ou connexion bloquée
- **Solution**: Vérifier la connexion internet et les paramètres de sécurité MT5

#### "No trading allowed"
- **Cause**: Trading automatique désactivé
- **Solution**: Activer le trading automatique dans MT5 (bouton "Auto Trading")

#### "Invalid volume"
- **Cause**: Volume incorrect pour le symbole
- **Solution**: Utiliser les volumes par défaut (0.5 pour Boom 300, 0.2 pour autres)

#### "Invalid stops"
- **Cause**: SL/TP trop proches (normal pour Boom/Crash)
- **Solution**: Le robot utilise SL/TP = 0 (sans stops)

### Logs et Monitoring

#### Vérifier les logs:
1. Onglet **Experts** dans MT5
2. Rechercher les messages avec 🤖 ou ✅/❌
3. Surveiller les erreurs "WebRequest" ou "Trade"

#### Monitoring web:
- Dashboard web: http://localhost:5000 (si lancé séparément)
- API Render: https://kolatradebot.onrender.com/health

## 🚨 SÉCURITÉ

### Recommandations
1. **Tester en démo** avant le trading réel
2. **Surveiller les premiers trades** manuellement
3. **Ajuster les volumes** selon votre capital
4. **Désactiver** si comportement anormal

### Limites de risque
- **Maximum 1 position** par symbole
- **Interval minimum** de 1 minute entre trades
- **Confiance minimum** de 70% requise
- **Volumes fixes** pour éviter les sur-risques

## 📞 SUPPORT

### En cas de problème:
1. **Vérifier les logs** MT5 (onglet Experts)
2. **Tester la connexion** à l'API Render
3. **Vérifier les paramètres** du robot
4. **Redémarrer MT5** si nécessaire

### Ressources:
- **GitHub**: https://github.com/Sidoine1991/KolaTradeboT
- **API Documentation**: https://kolatradebot.onrender.com/docs
- **Community**: Issues GitHub pour le support

---

## 🎉 UTILISATION

Une fois installé et configuré:

1. **Surveillez** le dashboard intégré
2. **Vérifiez** les signaux et les trades
3. **Ajustez** les paramètres si nécessaire
4. **Profitez** du trading automatique IA ! 🚀

**Bon trading avec TradBOT IA !** 📈💰
