# Configuration des permissions WebRequest dans MT5

## 🚨 Problème
Le robot MT5 ne peut pas communiquer avec le serveur AI car les permissions WebRequest ne sont pas configurées.

## 🔧 Solution 1: Configuration manuelle dans MT5

### Étape 1: Ouvrir les paramètres
1. Dans MT5, allez dans `Outils` → `Options` (ou appuyez sur `Ctrl+O`)
2. Allez dans l'onglet `Experts`

### Étape 2: Autoriser WebRequest
1. Cochez la case `Autoriser les requêtes WebRequest pour les URL spécifiées`
2. Cliquez sur le bouton `URL...`

### Étape 3: Ajouter les URLs
Ajoutez les URLs suivantes :
```
https://kolatradebot.onrender.com
http://localhost:8000
```

### Étape 4: Redémarrer
1. Cliquez sur `OK` pour sauvegarder
2. Redémarrez MT5
3. Rechargez le robot sur le graphique

## 🔧 Solution 2: Via le menu Fichier

1. Allez dans `Fichier` → `Ouvrir le dossier de données`
2. Naviguez vers `MQL5` → `Libraries`
3. Créez un fichier `WebRequestAllow.txt`
4. Ajoutez les URLs :
   ```
   https://kolatradebot.onrender.com
   http://localhost:8000
   ```

## 🔧 Solution 3: Script de configuration

Créez un script MQL5 pour configurer automatiquement :

```mql5
//+------------------------------------------------------------------+
//|                                            ConfigureWebRequest.mq5 |
//|                                    Copyright 2024, TradBOT Team |
//+------------------------------------------------------------------+
#property script_show_inputs

input string URL1 = "https://kolatradebot.onrender.com";
input string URL2 = "http://localhost:8000";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Cette fonction configure les permissions WebRequest
   // Note: Dans MT5, cette configuration doit être faite manuellement
   
   Alert("Configuration WebRequest requise:");
   Alert("1. Outils → Options → Experts");
   Alert("2. Cocher 'Autoriser WebRequest'");
   Alert("3. Ajouter: ", URL1);
   Alert("4. Ajouter: ", URL2);
   Alert("5. Redémarrer MT5");
}
//+------------------------------------------------------------------+
```

## ✅ Vérification

Après configuration, testez avec le script de diagnostic :

```bash
python diagnose_ai_connection.py
```

Le robot devrait maintenant pouvoir communiquer avec le serveur AI.

## 🚨 Erreurs communes

1. **Erreur 4013**: Permissions WebRequest non accordées
2. **Erreur 4014**: URL non autorisée
3. **Erreur 4015**: Timeout de la requête

## 📋 Étapes de test complètes

1. Configurez les permissions WebRequest
2. Démarrez le serveur AI local:
   ```bash
   .\activate_venv.bat
   python ai_server.py --port 8000
   ```
3. Compilez le robot GoldRush_basic.mq5
4. Attachez le robot à un graphique
5. Activez `UseAI_Agent = true`
6. Surveillez les logs du serveur et du robot

## 🔍 Logs attendus

**Côté serveur AI:**
```
📥 POST /decision
📤 POST /decision - 200 - Temps: 0.XXXs
```

**Côté robot MT5:**
```
🌐 Tentative de connexion au serveur local: http://localhost:8000/decision
✅ Réponse du serveur local reçue
✅ Signal AI (Local): buy (Confiance: XX.X%)
```
