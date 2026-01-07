# 🚀 TradBOT - Plateforme de Trading Algorithmique Avanc\u00e9e

## \ud83d\udd10 Nouveaut\u00e9s 2026

- **\u26a1 Strat\u00e9gie EMA Touch (Scalping)** : 
  - Entr\u00e9es ultra-pr\u00e9cises sur rebond EMA rapide avec confirmation de bougie M5 et tendance M5 align\u00e9e.
- **\ud83d\udd12 S\u00e9curisation Progressive du Profit** :
  - Verrouillage automatique de **50% du profit maximum atteint** d\u00e8s que le prix retrace. Prot\u00e8ge vos gains contre les retournements brusques.
- **\ud83e\udde0 IA Multi-Timeframe (7 Niveaux)** :
  - Analyse simultan\u00e9e de **M1, M5, M30, H1, H4, D1 et Weekly**. 
  - Score de confiance IA revu pour n\u00e9cessiter un alignement fort (>80%) avant d'entrer en position.
- **\ud83c\udfce\ufe0f Mode High-Performance (Trend API)** :
  - Architecture distribu\u00e9e avec un cache intelligent sur le port 8001. 
  - R\u00e9duction du temps de d\u00e9cision de 4s \u00e0 ~200ms pour un trading haute fr\u00e9quence sans latence.

## \ud83d\udd11 Nouveaut\u00e9s 2024

- **Notifications WhatsApp avec fallback automatique Vonage** :
  - Les notifications sont envoyées via Twilio, et basculent automatiquement sur Vonage si Twilio est en quota ou en erreur.
  - Plus de perte de signal : vous recevez toujours vos alertes !
- **Choix du modèle Gemini (1.5 Pro ou 1.5 Flash)** :
  - Dans l'interface, sélectionnez le modèle Gemini à utiliser pour l'analyse IA (Pro = plus précis, Flash = plus rapide).
- **Flèches BUY sur le graphique** :
  - À chaque détection d'un signal d'achat, une flèche verte ⬆️ s'affiche sur le graphique des prix.
- **Bip sonore continu** :
  - Tant que la condition "scalping possible" est vraie, un bip sonore est joué à chaque rafraîchissement.
- **Correction de l'affichage du symbole** :
  - Le symbole affiché dans les notifications et messages WhatsApp est toujours correct, même lors d'un changement de symbole.

### Exemple de configuration `.env` pour Vonage et Gemini

```env
# Configuration MT5
MT5_ACCOUNT=your_account_number
MT5_PASSWORD=your_password
MT5_SERVER=your_broker_server
   
# Paramètres de trading
RISK_PER_TRADE=0.02         # 2% de risque par trade
MAX_DAILY_RISK=0.05         # 5% de risque quotidien
MAX_DRAWDOWN=0.10           # 10% de drawdown maximum
   
# Paramètres de l'application
LOG_LEVEL=INFO             # Niveau de journalisation
TIMEZONE=Europe/Paris      # Fuseau horaire
# Twilio
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_token
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
TWILIO_WHATSAPP_TO=whatsapp:+33XXXXXXXXX

# Vonage
VONAGE_API_KEY=your_vonage_key
VONAGE_API_SECRET=your_vonage_secret
VONAGE_WHATSAPP_FROM_SANDBOX=14157386102
VONAGE_WHATSAPP_TO_SANDBOX=22996911346

# Gemini
GEMINI_API_KEY=your_gemini_api_key
```

### Exemple d'utilisation de l'analyse IA Gemini avec choix du modèle

Dans l'interface (onglet Analyse IA) :
- Sélectionnez le modèle : `gemini-1.5-pro-latest` ou `gemini-1.5-flash-latest`
- Cliquez sur "Analyser avec IA"
- Le résultat s'affiche avec le modèle choisi

---

Application professionnelle de trading algorithmique avec gestion avancée du risque, stratégies personnalisables et exécution automatisée via MetaTrader 5. Conçue pour les traders expérimentés cherchant un avantage compétitif sur les marchés financiers.

## 🎯 Robot MT5 - F_INX_robot4.mq5

### 📊 Prédiction de Spike avec Affichage Visuel

Le robot MT5 `F_INX_robot4.mq5` intègre un système avancé de prédiction de spike pour les indices Boom et Crash avec :

#### 🔔 **Flèche Clignotante de Prédiction**
- **Flèche visuelle** : Une flèche verte (BUY) ou rouge (SELL) **clignotante** apparaît sur le graphique pour annoncer l'arrivée imminente d'un spike
- **Position** : La flèche est placée au prix de la zone de spike prédite par l'IA (`g_aiSpikeZonePrice`)
- **Effet clignotant** : La flèche change de visibilité toutes les 1 seconde pour attirer l'attention
- **Couleurs** : 
  - 🟢 **Vert (clrLime)** pour les spikes haussiers (BUY sur Boom)
  - 🔴 **Rouge (clrRed)** pour les spikes baissiers (SELL sur Crash)
- **Mise à jour dynamique** : La flèche se met à jour en temps réel selon les nouvelles prédictions du serveur AI

#### ⏱️ **Décompte Visuel (Countdown)**
- **Affichage du décompte** : Un **label centré** sur le graphique affiche le nombre de secondes restantes avant l'arrivée du spike
- **Format** : "SPIKE dans: Xs" (exemple : "SPIKE dans: 3s")
- **Style** : 
  - Police : Arial Black, taille 32
  - Couleur : Jaune (clrYellow) pour une visibilité maximale
  - Position : Centré au milieu du graphique
- **Calcul** : Le décompte est basé sur `g_spikeEntryTime` qui est calculé comme `TimeCurrent() + SpikePreEntrySeconds`
- **Mise à jour** : Le décompte se met à jour toutes les secondes, affichant le temps restant
- **Exécution automatique** : Le trade s'exécute automatiquement quand `TimeCurrent() >= g_spikeEntryTime` (décompte atteint 0) si les conditions sont toujours réunies

#### 🎯 **Fonctionnement**
1. Le serveur AI détecte un spike imminent via `/decision`
2. La flèche clignotante apparaît immédiatement sur le graphique
3. Le décompte visuel démarre (par exemple : 3 secondes)
4. Le trade s'exécute automatiquement quand le décompte atteint 0
5. La flèche et le décompte disparaissent après exécution ou annulation

### ⚙️ Configuration du Robot

Paramètres importants dans `F_INX_robot4.mq5` :

```mql5
input bool   AI_PredictSpikes   = true;              // Prédire les zones de spike Boom/Crash avec flèches
input int    SpikePreEntrySeconds = 3;               // Nombre de secondes avant le spike estimé pour entrer
input bool   UseAI_Agent        = true;              // Activer l'agent IA
input string AI_ServerURL       = "http://127.0.0.1:8000/decision";
```

### 📍 Utilisation

1. **Démarrer le serveur AI** : `python ai_server.py`
2. **Compiler et attacher** `F_INX_robot4.mq5` sur un graphique M1 d'un indice Boom ou Crash
3. **Surveiller** : La flèche clignotante et le décompte apparaîtront automatiquement lors de la prédiction d'un spike
4. **Exécution** : Le trade s'exécute automatiquement à la fin du décompte

## 🤖 Serveur AI (ai_server.py)

Le serveur AI TradBOT fournit une API REST complète pour l'analyse et les décisions de trading en temps réel.

### 🚀 Démarrage du serveur AI

```bash
# Activer l'environnement virtuel
.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # Linux/Mac

# Lancer le serveur
python ai_server.py
```

Le serveur sera disponible sur `http://127.0.0.1:8000`

### 📡 Endpoints Principaux

- **POST `/decision`** : Décision de trading en temps réel (appelé par le robot MQ5)
- **GET `/analysis?symbol=SYMBOL`** : Analyse structurelle H1/H4/M15
- **GET `/time_windows/{symbol}`** : Fenêtres horaires optimales
- **POST `/indicators/analyze`** : Analyse avec AdvancedIndicators
- **GET `/indicators/sentiment/{symbol}`** : Sentiment du marché
- **POST `/analyze/gemini`** : Analyse avec Google Gemini AI
- **GET `/status`** : Statut détaillé du serveur
- **GET `/health`** : Vérification de santé

Documentation interactive : `http://127.0.0.1:8000/docs`

### 🔑 Configuration API Keys

Dans votre fichier `.env` :

```env
# Google Gemini AI (recommandé)
GEMINI_API_KEY=your_gemini_api_key

# Mistral AI (optionnel)
MISTRAL_API_KEY=your_mistral_api_key

# MetaTrader5 (optionnel)
MT5_LOGIN=your_account
MT5_PASSWORD=your_password
MT5_SERVER=your_server
```

### 🤖 Intégrations IA

Le serveur supporte :
- **Google Gemini AI** : Analyse de marché et amélioration des décisions
- **Mistral AI** : Fallback optionnel pour l'analyse
- **ML Models** : Prédictions avec modèles entraînés (si disponibles)
- **Advanced Indicators** : Calculs techniques avancés

## 🎯 Fonctionnalités Principales

### 📊 Gestion des Données
- **Récupération en temps réel** des données de marché via MT5
- **Calcul d'indicateurs techniques** avancés (RSI, MACD, ATR, Bandes de Bollinger, etc.)
- **Gestion du cache et des performances**

### 🤖 Moteur de Stratégies
- **Architecture modulaire** pour les stratégies de trading
- **Implémentation de stratégies personnalisables**
- **Gestion des signaux de trading**

### ⚖️ Gestion des Risques
- **Calcul de la taille de position optimale**
- **Validation des trades selon les règles de risque**
- **Suivi des performances et métriques**

### 🚀 Exécution des Ordres
- **Interface avec MT5 pour l'exécution des ordres**
- **Gestion du cycle de vie des positions**
- **Suivi des positions et historique des trades**

### 📈 Interface Utilisateur
- **Dashboard Streamlit** moderne et réactif
- **Visualisations interactives** des données de marché
- **Tableau de bord** des performances
- **Contrôles en temps réel** des stratégies

## 🏗️ Architecture Technique

### Structure du Projet
```
TradBOT/
│
├── backend/
│   ├── core/                  # Cœur de l'application
│   │   ├── __init__.py
│   │   ├── data_manager.py    # Gestion des données de marché
│   │   └── strategy_engine.py # Moteur de stratégies
│   │
│   ├── risk/                  # Gestion des risques
│   │   ├── __init__.py
│   │   └── risk_manager.py    # Gestion avancée du risque
│   │
│   └── execution/             # Exécution des ordres
│       ├── __init__.py
│       └── order_executor.py  # Interface avec MT5
│
├── config/
│   └── settings.py           # Configuration de l'application
│
├── frontend/
│   └── app.py                # Interface utilisateur Streamlit
│
├── tests/                    # Tests unitaires et d'intégration
├── .env                      # Variables d'environnement
├── requirements.txt          # Dépendances Python
└── README.md                 # Ce fichier
```

### Composants Principaux

#### 1. DataManager
- Récupération des données historiques et en temps réel
- Calcul des indicateurs techniques
- Gestion du cache et des performances

#### 2. StrategyEngine
- Architecture modulaire pour les stratégies
- Implémentation de stratégies personnalisables
- Gestion des signaux de trading

#### 3. RiskManager
- Calcul de la taille de position optimale
- Validation des trades selon les règles de risque
- Suivi des performances et métriques

#### 4. OrderExecutor
- Interface avec MT5 pour l'exécution des ordres
- Gestion du cycle de vie des positions
- Suivi des positions et historique des trades

### Dépendances ML
Ajoutez dans `requirements.txt` si ce n'est pas déjà fait :
```
scikit-learn
```

## 🚀 Installation et Configuration

### Prérequis
- **Python 3.9+**
- **MetaTrader 5** installé et configuré
- **Compte de trading MT5** (démo ou réel)
- **Accès à un serveur MT5** (broker supporté)

### Installation

1. **Cloner le dépôt**
   ```bash
   git clone <repository-url>
   cd TradBOT
   ```

2. **Créer et activer un environnement virtuel**
   ```bash
   # Création de l'environnement
   python -m venv .venv
   
   # Activation (Windows)
   .venv\Scripts\activate
   
   # Activation (Linux/Mac)
   source .venv/bin/activate
   ```

3. **Installer les dépendances**
   ```bash
   pip install -r requirements.txt
   ```

### Configuration

1. **Configurer les variables d'environnement**
   Créer un fichier `.env` à la racine du projet :
   ```env
   # Configuration MT5
   MT5_ACCOUNT=your_account_number
   MT5_PASSWORD=your_password
   MT5_SERVER=your_broker_server
   
   # Paramètres de trading
   RISK_PER_TRADE=0.02         # 2% de risque par trade
   MAX_DAILY_RISK=0.05         # 5% de risque quotidien
   MAX_DRAWDOWN=0.10           # 10% de drawdown maximum
   
   # Paramètres de l'application
   LOG_LEVEL=INFO             # Niveau de journalisation
   TIMEZONE=Europe/Paris      # Fuseau horaire
   ```

2. **Vérifier la connexion à MT5**
   ```bash
   python -c "import MetaTrader5 as mt5; print('MT5 version:', mt5.version())"
   ```

## 🧪 Tests et Vérifications

### Vérifier l'installation
```bash
# Tester l'import des modules principaux
python -c "from backend.core import DataManager, StrategyEngine; print('Modules chargés avec succès')"

# Tester la connexion MT5
python -c "from backend.execution import OrderExecutor; executor = OrderExecutor(); print('MT5 connecté:', executor.connected)"
```

### Exécuter les tests unitaires
```bash
# Exécuter tous les tests
python -m pytest tests/

# Exécuter un test spécifique
python -m pytest tests/test_data_manager.py -v
```

## 🎮 Utilisation

### Lancer l'application
```bash
# Mode développement avec rechargement automatique
streamlit run frontend/app.py

# Mode production
STREAMLIT_SERVER_PORT=8501 streamlit run frontend/app.py --server.port=8501
```

### Interface Utilisateur

1. **Tableau de bord principal**
   - Vue d'ensemble du portefeuille
   - Graphique des performances
   - Positions ouvertes et signaux récents

2. **Gestion des Stratégies**
   - Activation/désactivation des stratégies
   - Paramétrage des signaux
   - Suivi des performances

3. **Gestion des Risques**
   - Configuration des limites de risque
   - Suivi du drawdown
   - Rapports de performance

4. **Exécution des Ordres**
   - Vue des ordres en cours
   - Historique des trades
   - Gestion manuelle des positions

## ⚙️ Configuration Avancée

### Configuration des Stratégies

```python
# Exemple de configuration d'une stratégie de tendance
from backend.core.strategy_engine import StrategyEngine, TrendFollowingStrategy

# Initialiser le moteur de stratégies
engine = StrategyEngine()

# Configurer et activer une stratégie de tendance
params = {
    'ma_fast': 20,
    'ma_slow': 50,
    'rsi_period': 14,
    'atr_period': 14,
    'atr_multiplier': 2.0
}
engine.activate_strategy('trend_following', 'EURUSD', 'H1', params)
```

### Paramètres de Gestion des Risques

```python
from backend.risk.risk_manager import RiskManager

# Initialiser le gestionnaire de risque
risk_manager = RiskManager({
    'max_risk_per_trade': 0.02,    # 2% de risque par trade
    'max_daily_risk': 0.05,        # 5% de risque quotidien
    'max_drawdown': 0.10,          # 10% de drawdown maximum
    'min_risk_reward': 1.5,        # Ratio risque/rendement minimum
})
```

### Configuration de l'Exécution

```python
from backend.execution import OrderExecutor

# Initialiser l'exécuteur d'ordres
executor = OrderExecutor(
    account=12345678,           # Numéro de compte MT5
    server='YourBroker-Server', # Serveur MT5
    password='your_password'    # Mot de passe du compte
)

# Vérifier la connexion
if not executor.connected:
    print("Échec de la connexion à MT5")
```

## 📊 Métriques et Performances

### Métriques de Trading
- **Taux de réussite** des trades
- **Profit Factor** (bénéfice brut / perte brute)
- **Drawdown maximum** (en % et en valeur absolue)
- **Ratio de Sharpe/Sortino**
- **Rentabilité** (mensuelle/annuelle)

### Métriques Techniques
- **Latence d'exécution** des ordres
- **Précision** des signaux
- **Temps de réponse** du système
- **Utilisation des ressources** (CPU, mémoire)

### Rapports
- **Rapports quotidiens** par e-mail
- **Statistiques** détaillées par stratégie
- **Analyses de performance** (hebdomadaires, mensuelles)

## 🔒 Sécurité et Bonnes Pratiques

### Protection des Données
- **Identifiants** stockés dans des variables d'environnement
- **Fichier `.env`** exclu du suivi Git
- **Chiffrement** des données sensibles
- **Audit** régulier des accès

### Gestion des Erreurs
- **Journalisation** complète des opérations
- **Alertes** en cas d'erreur critique
- **Reconnexion automatique** en cas de déconnexion
- **Sauvegardes** régulières des configurations

### Bonnes Pratiques
- **Tests unitaires** pour tous les composants critiques
- **Documentation** à jour du code
- **Gestion des versions** avec Git
- **Revues de code** systématiques

## 🛠 Développement et Contribution

### Structure des Modules Principaux

#### `backend/core/`
- **`data_manager.py`** : Gestion des données de marché et indicateurs
- **`strategy_engine.py`** : Moteur d'exécution des stratégies

#### `backend/risk/`
- **`risk_manager.py`** : Gestion avancée du risque et money management

#### `backend/execution/`
- **`order_executor.py`** : Interface avec MT5 pour l'exécution des ordres

### Comment Contribuer

1. **Créer une branche** pour votre fonctionnalité
   ```bash
   git checkout -b feature/nouvelle-fonctionnalite
   ```

2. **Développer et tester** votre code
   ```bash
   # Exécuter les tests
   python -m pytest tests/
   
   # Vérifier la qualité du code
   flake8 .
   ```

3. **Soumettre une Pull Request**
   - Décrire les modifications apportées
   - Inclure des tests unitaires
   - Mettre à jour la documentation si nécessaire

### Standards de Code
- Respecter la PEP 8
- Documenter les fonctions et classes
- Écrire des tests unitaires pour les nouvelles fonctionnalités
- Utiliser des messages de commit clairs et descriptifs

### Dépendances
- **Principales** : `pandas`, `numpy`, `MetaTrader5`, `streamlit`
- **Développement** : `pytest`, `flake8`, `black`, `mypy`

## 📚 Documentation Complémentaire

### API Référence

#### DataManager
- `get_historical_data(symbol, timeframe, count=1000)` : Récupère les données historiques
- `get_tick_data(symbol, count=1000)` : Récupère les données de ticks
- `calculate_technical_indicators(df)` : Calcule les indicateurs techniques

#### StrategyEngine
- `add_strategy(strategy_id, strategy_class, params)` : Ajoute une stratégie personnalisée
- `activate_strategy(strategy_id, symbol, timeframe, params)` : Active une stratégie
- `process_data(symbol, timeframe, data)` : Traite les données avec les stratégies actives

#### RiskManager
- `calculate_position_size(entry_price, stop_loss, account_balance)` : Calcule la taille de position optimale
- `validate_trade(symbol, position_type, entry_price, stop_loss, take_profit, position_size, account_balance)` : Valide un trade potentiel
- `get_risk_report()` : Génère un rapport de risque détaillé

#### OrderExecutor
- `place_order(symbol, order_type, side, volume, price=None, stop_loss=None, take_profit=None)` : Passe un nouvel ordre
- `close_position(position_id, volume=None)` : Ferme une position existante
- `modify_position(position_id, stop_loss=None, take_profit=None)` : Modifie les niveaux de SL/TP d'une position

### Exemples d'Utilisation

#### Exécuter une Stratégie de Tendance
```python
from backend.core import DataManager, StrategyEngine
from backend.risk import RiskManager
from backend.execution import OrderExecutor
import pandas as pd

# Initialiser les composants
data_manager = DataManager()
strategy_engine = StrategyEngine()
risk_manager = RiskManager()
executor = OrderExecutor()

# Charger les données
df = data_manager.get_historical_data('EURUSD', 'H1', 1000)

# Configurer et activer la stratégie
strategy_engine.activate_strategy('trend_following', 'EURUSD', 'H1')

# Générer les signaux
signals = strategy_engine.process_data('EURUSD', 'H1', df)

# Traiter les signaux
for signal in signals:
    if signal.signal_type == 'BUY':
        # Calculer la taille de position
        position_size = risk_manager.calculate_position_size(
            entry_price=signal.price,
            stop_loss=signal.stop_loss,
            account_balance=10000  # Solde du compte
        )
        
        # Passer l'ordre
        executor.place_order(
            symbol='EURUSD',
            order_type=OrderType.MARKET,
            side=OrderSide.BUY,
            volume=position_size,
            stop_loss=signal.stop_loss,
            take_profit=signal.take_profit
        )
```

### Dépannage

#### Problèmes de Connexion MT5
1. Vérifier que MetaTrader 5 est installé et en cours d'exécution
2. Vérifier les identifiants de connexion dans le fichier `.env`
3. Vérifier que le serveur MT5 est accessible depuis votre réseau

#### Problèmes de Performance
- Réduire le nombre d'indicateurs chargés
- Augmenter l'intervalle de mise à jour des données
- Utiliser un cache pour les données historiques

### Support
Pour toute question ou problème, veuillez ouvrir une [issue](https://github.com/votre-utilisateur/TradBOT/issues) sur GitHub.

```python
# Dans technical_analysis.py
def add_custom_indicator(df):
    # Votre indicateur personnalisé
    df['custom_indicator'] = your_calculation(df)
    return df
```

## 🔄 Mise à jour/raffinage du modèle ML

Pour raffiner le modèle sur de nouvelles données :

```python
from backend.spike_detector import fine_tune_spike_model_from_csv
result = fine_tune_spike_model_from_csv('chemin/vers/votre.csv')
print(result)
```

Le CSV doit contenir les colonnes : `timestamp`, `open`, `high`, `low`, `close`, `volume`.

## 📝 Roadmap (mise à jour)

- [x] **Machine Learning** pour amélioration des prédictions (RandomForest, raffinage, batch prediction)
- [ ] **Intégration WebSocket** pour données temps réel
- [ ] **Backtesting** des stratégies
- [ ] **Alertes push** (email, SMS, Telegram)
- [ ] **API REST** pour intégration externe
- [ ] **Dashboard mobile** responsive
- [ ] **Multi-brokers** support

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 👨‍💻 Auteur

**Sidoine YEBADOKPO** - Développeur passionné de trading algorithmique

## 🙏 Remerciements

- **MetaTrader5** pour l'API de trading
- **Google Gemini** pour l'IA
- **Streamlit** pour l'interface utilisateur
- **Communauté open-source** pour les bibliothèques utilisées

---

**⚠️ Avertissement** : Ce logiciel est destiné à des fins éducatives et de recherche. Le trading comporte des risques de perte. Utilisez à vos propres risques. 

# Modes Turbo Bullish & Turbo Bearish

## Fonctionnement général

L'application TradBOT propose deux modes spéciaux pour la génération de signaux automatiques : **Turbo Bullish** et **Turbo Bearish**. Ces modes permettent d'envoyer des signaux d'achat (BUY) ou de vente (SELL) immédiats lorsque toutes les conditions de tendance sont parfaitement alignées, même si la probabilité de confiance classique n'est pas atteinte.

---

## Logique de scan et d'envoi des signaux

- **Scan automatique** : Le moniteur automatique scanne à intervalle régulier (paramétrable) tous les symboles sélectionnés dans l'interface.
- **Pour chaque symbole** :
  1. Récupération des données de marché et calcul des indicateurs.
  2. Analyse de la tendance sur plusieurs timeframes (multi-timeframe).
  3. **Si un mode Turbo est activé** :
     - **Turbo Bullish** : Si toutes les tendances sont BULLISH et le prix est au-dessus des MA5/20/50, un signal BUY est envoyé immédiatement (confiance 1.0).
     - **Turbo Bearish** : Si toutes les tendances sont BEARISH et le prix est en-dessous des MA5/20/50, un signal SELL est envoyé immédiatement (confiance 1.0).
  4. **Sinon** : Le signal classique n'est envoyé que si la confiance combinée (technique + tendance) dépasse le seuil défini (ex : 0.58).

---

## Priorité et sécurité

- Les signaux Turbo **bypassent** le filtre de confiance classique : ils sont envoyés dès que les conditions sont réunies, même si la confiance calculée serait plus faible.
- Les signaux classiques restent filtrés par la probabilité de confiance.
- Il est recommandé de monitorer la performance des signaux Turbo et d'ajuster les conditions ou la fréquence si besoin.

---

## Activation dans l'interface

- Rendez-vous dans l'onglet **Auto Monitor** de l'application Streamlit.
- Utilisez les boutons :
  - "⚡ Activer le mode Turbo Bullish" / "🛑 Désactiver le mode Turbo Bullish"
  - "⚡ Activer le mode Turbo Bearish" / "🛑 Désactiver le mode Turbo Bearish"
- L'état de chaque mode est affiché (🟢 ACTIVÉ ou ⚪️ Désactivé pour Bullish, 🔴 ACTIVÉ ou ⚪️ Désactivé pour Bearish).
- Un message d'avertissement s'affiche quand un mode Turbo est actif.

---

## Exemple de message envoyé (WhatsApp)

```
🔴 *SIGNAL MTF - EURUSD*

🎯 *Action:* VENTE
💰 *Prix:* 1.1234
📊 *Confiance:* 100.0%
🛑 *Stop Loss:* 1.1300
🎯 *Take Profit:* 1.1000

📈 *Tendance Globale:* BEARISH
📊 *Consensus:* 0H/3B/0N

*Détails par Timeframe:*
📉 H1: BEARISH
📉 M30: BEARISH
📉 M15: BEARISH

⏰ *Validité:* 30 minutes
🔄 *Alignement:* ✅

📱 *EXÉCUTER L'ORDRE:*
🔗 mt5://order?symbol=EURUSD&type=OP_SELL&price=1.1234&sl=1.1300&tp=1.1000&volume=0.1&comment=Signal_MTF_Auto

💡 *Instructions:*
1️⃣ Cliquez sur le lien ci-dessus
2️⃣ Confirmez l'ordre dans MT5
3️⃣ L'ordre sera exécuté automatiquement
```

---

## Conseils d'utilisation

- Utilisez les modes Turbo pour capter les mouvements extrêmes, mais surveillez leur performance réelle.
- N'hésitez pas à désactiver les modes Turbo en période de news ou de volatilité extrême.
- Les signaux Turbo sont un outil puissant mais doivent être utilisés avec discernement. 

---

## 🚦 Lancer l'application Streamlit sans erreur d'import

Pour éviter l'erreur `ModuleNotFoundError: No module named 'backend'` :

### 1. **Toujours lancer Streamlit depuis la racine du projet**

Ouvre un terminal dans le dossier racine du projet (là où se trouvent les dossiers `backend/` et `frontend/`) :

```sh
cd D:\Dev\TradBOT
streamlit run frontend/app.py
```

**Ne lance jamais la commande depuis le dossier `frontend/`** sinon les imports relatifs au projet ne fonctionneront pas.

### 2. **Vérifie le PYTHONPATH (optionnel)**

Si tu rencontres encore des problèmes d'import, tu peux forcer le PYTHONPATH :

- Sous Windows (PowerShell/cmd) :
  ```sh
  set PYTHONPATH=D:\Dev\TradBOT
  streamlit run frontend/app.py
  ```
- Sous bash :
  ```sh
  PYTHONPATH=D:/Dev/TradBOT streamlit run frontend/app.py
  ```

### 3. **Bonnes pratiques d'import**
- Assure-toi qu'il n'y a pas de fichier `backend.py` parasite dans `frontend/` ou à la racine.
- Le dossier `backend/` doit contenir un fichier `__init__.py` (c'est déjà le cas).
- Si tu utilises un environnement virtuel, active-le avant de lancer Streamlit :
  ```sh
  .venv\Scripts\activate
  cd D:\Dev\TradBOT
  streamlit run frontend/app.py
  ```

---

**En cas de problème, vérifie la structure du projet et les chemins d'importation affichés dans le terminal.** 