# 🚨 Solution: Robot n'exécute pas d'ordres

## 🔍 Diagnostic Complet

### ✅ Ce qui fonctionne:
- **Serveur IA**: Actif sur port 8000
- **MetaTrader 5**: En cours d'exécution
- **Fichiers robot**: SMC_Universal.mq5 et .ex5 présents
- **Logs**: Plusieurs fichiers de log disponibles

### ❌ Problème principal identifié:
**Configuration MT5 manquante dans .env**

```
MT5_LOGIN=     [MANQUANT]
MT5_PASSWORD=  [MANQUANT] 
MT5_SERVER=    [MANQUANT]
```

## 🎯 Solution Immédiate

### 1. Configurer les identifiants MT5

Éditer le fichier `.env` et ajouter:
```bash
MT5_LOGIN=votre_numero_compte
MT5_PASSWORD=votre_mot_de_passe_mt5
MT5_SERVER=votre_serveur_broker
```

### 2. Comment trouver vos identifiants MT5:

#### Ouvrir MetaTrader 5:
1. **Fichier** → **Connexion**
2. **Cliquer sur votre compte**
3. **Notez**:
   - **Login**: Numéro de compte (ex: 12345678)
   - **Serveur**: Nom du serveur (ex: MetaQuotes-Demo)
   - **Password**: Mot de passe du compte

### 3. Exemple de configuration complète:
```bash
# Connexion MT5
MT5_LOGIN=12345678
MT5_PASSWORD=votre_motdepasse
MT5_SERVER=MetaQuotes-Demo

# Autres paramètres (optionnels)
MT5_MAX_LOSS_PER_TRADE=3.0
MT5_MAX_POSITIONS=2
MT5_DEFAULT_SL_POINTS=300
MT5_DEFAULT_TP_RR=2.0
```

## 🔧 Étapes de Dépannage

### Étape 1: Configuration .env
```bash
# Éditer le fichier
notepad .env

# OU copier depuis l'exemple
copy .env.example .env
```

### Étape 2: Redémarrer les services
```bash
# Arrêter le serveur IA (Ctrl+C dans le terminal)
# Le redémarrer
python ai_server.py
```

### Étape 3: Vérifier dans MT5
1. **Ouvrir MetaTrader 5**
2. **Vérifier la connexion** (coin inférieur droit)
3. **Activer AutoTrading** (bouton vert)
4. **Attacher le robot** au graphique:
   - **Navigateur** → **Expert Advisors**
   - **Glisser** `SMC_Universal` sur le graphique
   - **Cocher** "Allow trading" et "Allow DLL imports"

### Étape 4: Vérification
```bash
# Relancer le diagnostic
.\diagnostic_trading.bat
```

## 🚨 Si ça ne fonctionne toujours pas

### Vérifier les permissions de trading:
1. **MT5**: Outils → Options → Expert Advisors
2. **Cocher**: "Allow algorithmic trading"
3. **Vérifier**: "Allow DLL imports"

### Vérifier les logs d'erreurs:
```bash
# Consulter les logs récents
type mt5_ai_client_*.log | findstr "ERROR"
type ai_server.log | findstr "ERROR"
```

### Test de connexion manuelle:
```python
# Dans un terminal Python
import MetaTrader5 as mt5
mt5.initialize()
account = mt5.account_info()
print(f"Compte: {account.login}")
print(f"Balance: {account.balance}")
mt5.shutdown()
```

## 📊 Checklist Finale

- [ ] `.env` configuré avec identifiants MT5
- [ ] Serveur IA démarré (`python ai_server.py`)
- [ ] MT5 connecté et AutoTrading activé
- [ ] Robot attaché au graphique
- [ ] Permissions trading accordées
- [ ] Diagnostic sans erreurs

## 🔍 Problèmes Courants

| Symptôme | Cause | Solution |
|----------|-------|----------|
| "No connection" | MT5 non connecté | Vérifier login/password |
| "Trading disabled" | AutoTrading désactivé | Activer AutoTrading |
| "Expert not running" | Robot pas attaché | Glisser robot sur graphique |
| "Invalid stops" | SL/TP incorrects | Ajuster paramètres de risque |

---

## 🎯 Une fois configuré

Le robot devrait commencer à:
1. **Analyser** les signaux IA
2. **Placer** ordres selon les stratégies
3. **Gérer** les positions automatiquement
4. **Logger** toutes les transactions

**Surveiller les logs** pour vérifier l'activité!
