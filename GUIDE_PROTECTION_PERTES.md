# 🛡️ GUIDE DE PROTECTION AUTOMATIQUE DES PERTES - TradBOT

## Vue d'ensemble

Ce système de protection automatique surveille en continu toutes les positions ouvertes sur MT5 et **ferme automatiquement** toute position dès que la perte atteint **3 dollars**, peu importe le symbole (Crash 300, Boom 1000, Forex, etc.).

---

## 🎯 Fonctionnalités

### ✅ Protection Active
- ⚡ **Vérification en temps réel** : surveillance toutes les 1 seconde
- 💰 **Limite stricte** : fermeture automatique à -3.00 USD de perte
- 🌍 **Multi-symboles** : fonctionne pour tous les instruments (Synthétiques, Forex, Métaux, Indices, Crypto)
- 🔄 **Reconnexion automatique** : en cas de déconnexion MT5, le système tente de se reconnecter automatiquement

### ✅ Intégration Multi-Niveaux
1. **Monitoring continu** (script Python standalone)
2. **API REST** (endpoint `/robot/monitor/loss-limit`)
3. **Protection au niveau des ordres** (calcul SL intelligent)

---

## 📋 Installation

### Prérequis
- Python 3.8+
- MetaTrader 5 installé et connecté
- Variables d'environnement MT5 configurées (`.env` ou `.env.supabase`)

### Vérification des dépendances
```powershell
# Installer les dépendances si nécessaire
pip install MetaTrader5 python-dotenv pandas numpy
```

---

## 🚀 Utilisation

### Méthode 1 : Script PowerShell (Recommandé)

```powershell
# Double-cliquer sur le fichier ou exécuter dans PowerShell
.\start_loss_monitor.ps1
```

**Ce script :**
- ✅ Vérifie que Python est installé
- ✅ Lance le monitoring continu
- ✅ Affiche les informations en temps réel
- ✅ Se ferme proprement avec Ctrl+C

### Méthode 2 : Script Python Direct

```powershell
# Lancer le monitoring manuellement
python backend/continuous_loss_monitor.py
```

### Méthode 3 : Via l'API REST

```python
import requests

# Appeler l'endpoint de monitoring (une seule vérification)
response = requests.post("http://localhost:8000/robot/monitor/loss-limit", params={"max_loss": 3.0})
print(response.json())
```

**Exemple de réponse :**
```json
{
  "success": true,
  "message": "1 position(s) fermée(s) pour dépassement de perte",
  "closed_positions": [
    {
      "symbol": "Crash 300 Index",
      "ticket": 123456789,
      "loss": -3.98,
      "closed_at": "2026-04-28 14:32:15",
      "status": "SUCCESS"
    }
  ]
}
```

---

## 🔧 Configuration

### Modifier la limite de perte

**Option 1 : Dans le script Python**
```python
# backend/continuous_loss_monitor.py
MAX_LOSS_USD = 3.0  # Modifier cette valeur (par défaut 3.0$)
```

**Option 2 : Via l'API**
```python
# Utiliser une limite personnalisée (ex: 5$)
requests.post("http://localhost:8000/robot/monitor/loss-limit", params={"max_loss": 5.0})
```

**Option 3 : Dans le fichier .env**
```bash
# .env ou .env.supabase
MT5_MAX_LOSS_PER_TRADE=3.0
```

### Modifier l'intervalle de vérification

```python
# backend/continuous_loss_monitor.py
CHECK_INTERVAL_SECONDS = 1  # Vérification toutes les X secondes (par défaut 1s)
```

⚠️ **Attention :** Ne pas mettre moins de 0.5 seconde pour éviter de surcharger l'API MT5.

---

## 📊 Affichage du Monitoring

### État Normal (Pas de perte excessive)
```
✅ [2026-04-28 14:30:00] Toutes les positions sont dans la limite de perte autorisée
```

### Position Fermée Automatiquement
```
⚠️  [2026-04-28 14:32:15] ALERTE: 1 position(s) fermée(s)!
   Message: 1 position(s) fermée(s) pour dépassement de perte

   📊 Détails de la position fermée:
      • Symbole: Crash 300 Index
      • Ticket: 123456789
      • Perte: -3.98$
      • Fermée à: 2026-04-28 14:32:15
      • Statut: SUCCESS
```

### Déconnexion MT5
```
⚠️  [2026-04-28 14:35:00] MT5 déconnecté, tentative de reconnexion...
✅ [2026-04-28 14:35:02] Reconnexion réussie
```

---

## 🧪 Tests

### Test 1 : Vérifier la connexion MT5
```python
from backend.mt5_connector import is_connected, connect
connect()
print("MT5 connecté:", is_connected())
```

### Test 2 : Tester le monitoring manuellement
```python
from backend.mt5_connector import monitor_positions_loss_limit

result = monitor_positions_loss_limit(max_loss_usd=3.0)
print(result)
```

### Test 3 : Tester avec l'API REST
```bash
# Lancer le serveur FastAPI
python backend/api/main.py

# Dans un autre terminal
curl -X POST "http://localhost:8000/robot/monitor/loss-limit?max_loss=3.0"
```

---

## 🔍 Dépannage

### Problème : "MT5 n'est pas connecté"
**Solution :**
1. Vérifier que MetaTrader 5 est ouvert
2. Vérifier que vous êtes connecté à votre compte
3. Vérifier les variables d'environnement dans `.env`

### Problème : "Échec fermeture de position"
**Solution :**
- Vérifier le spread du symbole (peut être trop élevé)
- Vérifier la liquidité du marché
- Vérifier les logs MT5 pour plus de détails

### Problème : "Trop d'erreurs consécutives"
**Solution :**
- Redémarrer MetaTrader 5
- Vérifier la connexion Internet
- Relancer le script de monitoring

---

## 📈 Statistiques et Logs

Le système affiche en temps réel :
- ✅ Nombre de positions surveillées
- ⚠️ Positions fermées avec détails (symbole, ticket, perte)
- 🔄 État de la connexion MT5
- 📊 Intervalle de surveillance

---

## ⚡ Arrêt du Monitoring

Pour arrêter proprement le monitoring :
1. Appuyer sur **Ctrl+C** dans le terminal
2. Le script fermera la connexion MT5 proprement
3. Un message de confirmation sera affiché

---

## 🔒 Sécurité

### Protections Intégrées
- ✅ Pas de fermeture de positions gagnantes
- ✅ Vérification de la connexion avant chaque action
- ✅ Gestion des erreurs avec tentatives de reconnexion
- ✅ Logs détaillés pour audit

### Recommandations
- 🔐 Ne pas modifier le script pendant qu'il tourne
- 💾 Sauvegarder les logs pour analyse
- 📊 Surveiller les performances du système
- ⚠️ Tester sur compte démo avant utilisation en réel

---

## 🎓 Exemple d'Utilisation Complète

### Scénario : Trading sur Crash 300 avec protection

```powershell
# 1. Lancer le monitoring de pertes
.\start_loss_monitor.ps1

# Dans un autre terminal :

# 2. Lancer le serveur de trading
python backend/api/main.py

# 3. Le robot ouvre une position sur Crash 300

# 4. Si la position perd 3$, elle sera fermée automatiquement
# Le monitoring affichera :
⚠️  [2026-04-28 14:32:15] ALERTE: 1 position(s) fermée(s)!
   📊 Détails de la position fermée:
      • Symbole: Crash 300 Index
      • Perte: -3.98$ ❌
      • Statut: SUCCESS ✅
```

---

## 📞 Support

En cas de problème :
1. Vérifier ce guide
2. Consulter les logs MT5
3. Vérifier les fichiers `.env`
4. Tester sur compte démo d'abord

---

## 📝 Notes Importantes

⚠️ **Limitations connues :**
- Le système ferme au marché (peut y avoir un léger slippage)
- Fonctionne uniquement si MT5 est ouvert et connecté
- Dépend de la latence réseau entre le script et MT5

✅ **Avantages :**
- Protection automatique 24/7 (si le script tourne)
- Pas besoin de surveiller manuellement
- Fonctionne pour tous les symboles simultanément
- Logs détaillés pour analyse post-trade

---

## 🚀 Prochaines Améliorations

- [ ] Notifications push (Telegram/WhatsApp) lors de fermeture
- [ ] Dashboard web en temps réel
- [ ] Statistiques de pertes évitées
- [ ] Intégration avec Supabase pour historique
- [ ] Support multi-comptes MT5

---

**Version:** 1.0  
**Dernière mise à jour:** 2026-04-28  
**Auteur:** TradBOT Team
