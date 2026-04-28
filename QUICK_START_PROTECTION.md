# 🚀 DÉMARRAGE RAPIDE - Protection Automatique des Pertes

## ⚡ En 3 Minutes Chrono

### Étape 1 : Vérifier l'installation (30 secondes)

```powershell
# Vérifier Python
python --version

# Vérifier que MetaTrader5 est ouvert et connecté
```

### Étape 2 : Lancer le serveur AI (30 secondes)

```powershell
# Double-cliquer sur start_ai_server.ps1
# OU en ligne de commande :
python backend/api/main.py
```

**Vous devriez voir :**
```
============================================================
 🚀 TRADBOT AI SERVER - DÉMARRAGE
============================================================
📡 Port: 8000
🌐 URL: http://localhost:8000

🛡️  SYSTÈME DE PROTECTION DES PERTES ACTIVÉ
   • Perte maximale par trade: 3.00 USD
   • Monitoring API disponible: /monitor/loss-protection
============================================================
```

### Étape 3 : Lancer le monitoring continu (30 secondes)

Dans un **nouveau terminal** :

```powershell
# Double-cliquer sur start_loss_monitor.ps1
# OU en ligne de commande :
python backend/continuous_loss_monitor.py
```

**Vous devriez voir :**
```
============================================================
🛡️  SYSTÈME DE PROTECTION AUTOMATIQUE DES PERTES
============================================================
⚙️  Configuration:
   • Perte maximale par trade: 3.0$
   • Intervalle de vérification: 1s
============================================================

🔌 Connexion à MT5...
✅ Connecté à MT5 avec succès

🚀 Démarrage du monitoring continu...
🛑 Appuyez sur Ctrl+C pour arrêter
```

### Étape 4 : Trader en toute sérénité ! (2 minutes)

✅ **C'est tout !** Votre système de protection est actif.

Toute position qui atteindra **-3.00 USD** de perte sera **automatiquement fermée**.

---

## 📊 Que se passe-t-il maintenant ?

### Mode Normal (Pas de perte excessive)
```
✅ [14:30:00] Toutes les positions sont dans la limite de perte autorisée
✅ [14:30:30] Toutes les positions sont dans la limite de perte autorisée
✅ [14:31:00] Toutes les positions sont dans la limite de perte autorisée
```

### Alerte de Protection Activée
```
⚠️  [14:32:15] ALERTE: 1 position(s) fermée(s)!
   Message: 1 position(s) fermée(s) pour dépassement de perte

   📊 Détails de la position fermée:
      • Symbole: Crash 300 Index
      • Ticket: 123456789
      • Perte: -3.05$
      • Fermée à: 2026-04-28 14:32:15
      • Statut: SUCCESS ✅
```

---

## 🔧 Configuration Rapide (Optionnel)

### Modifier la limite de perte

**Dans le fichier `.env` :**
```bash
MT5_MAX_LOSS_PER_TRADE=3.0
```

**Ou dans le script :**
```python
# backend/continuous_loss_monitor.py (ligne 11)
MAX_LOSS_USD = 3.0  # Changez cette valeur
```

### Modifier l'intervalle de vérification
```python
# backend/continuous_loss_monitor.py (ligne 12)
CHECK_INTERVAL_SECONDS = 1  # Ne pas mettre moins de 0.5s
```

---

## 🧪 Test Rapide

### Test 1 : Vérifier le statut
```bash
curl http://localhost:8000/monitor/status
```

**Réponse attendue :**
```json
{
  "protection_active": true,
  "max_loss_per_trade": 3.0,
  "mt5_connected": true,
  "open_positions_count": 0
}
```

### Test 2 : Déclencher un monitoring manuel
```bash
curl -X POST "http://localhost:8000/monitor/loss-protection?max_loss=3.0"
```

---

## 🛑 Arrêter le Monitoring

Dans le terminal du monitoring, appuyez sur **Ctrl+C**

```
🛑 Arrêt du monitoring demandé par l'utilisateur

🔌 Fermeture de la connexion MT5...
✅ Déconnexion réussie

============================================================
👋 Monitoring arrêté
============================================================
```

---

## 🆘 Problèmes Courants

### "ModuleNotFoundError: No module named 'MetaTrader5'"
```bash
pip install MetaTrader5
```

### "MT5 n'est pas connecté"
1. Ouvrir MetaTrader 5
2. Se connecter à votre compte
3. Relancer le script

### Script ne démarre pas
```bash
# Vérifier Python
python --version

# Réinstaller les dépendances
pip install -r requirements.txt
```

---

## 📚 Documentation Complète

- **Guide complet** : `GUIDE_PROTECTION_PERTES.md`
- **Documentation technique** : `PROTECTION_PERTES_3USD_README.md`
- **Résumé visuel** : `RESUME_PROTECTION_3USD.txt`
- **Déploiement** : `DEPLOYMENT_SUCCESS.txt`

---

## ✅ Checklist de Démarrage

- [ ] Python installé
- [ ] MetaTrader 5 ouvert et connecté
- [ ] Serveur AI lancé (`python backend/api/main.py`)
- [ ] Monitoring continu lancé (`python backend/continuous_loss_monitor.py`)
- [ ] Test du statut réussi (`curl http://localhost:8000/monitor/status`)
- [ ] Prêt à trader !

---

## 💡 Astuces Pro

### 🔥 Mode 24/7 (VPS)
Pour une protection continue même quand votre PC est éteint :
1. Déployer sur un VPS Windows
2. Configurer le démarrage automatique des scripts
3. Utiliser `nohup` ou un service Windows

### 📱 Notifications (Avancé)
Ajouter des notifications Telegram/WhatsApp :
1. Modifier `backend/continuous_loss_monitor.py`
2. Ajouter un appel API de notification après fermeture
3. Recevoir une alerte sur votre téléphone

### 📊 Logs Détaillés
Les logs sont affichés en temps réel dans le terminal.
Pour sauvegarder :
```bash
python backend/continuous_loss_monitor.py > logs_protection.txt 2>&1
```

---

## 🎯 Résumé Ultra-Rapide

```bash
# Terminal 1
python backend/api/main.py

# Terminal 2
python backend/continuous_loss_monitor.py

# Trader !
```

**Protection active : Max 3.00 USD de perte par trade** 🛡️

---

**Version :** 1.0  
**Dernière mise à jour :** 2026-04-28  
**Status :** ✅ Opérationnel
