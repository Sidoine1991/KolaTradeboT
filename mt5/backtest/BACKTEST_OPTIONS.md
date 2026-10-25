# Options de Backtest pour TradBOT

## Option 1: Strategy Tester MT5 (Recommandé pour l'instant)

**Avantages:**
- Backtest complet avec tous les indicateurs et logiques de l'EA
- Utilise le moteur de backtest officiel MT5
- Rapports détaillés HTML
- Supporte tous les paramètres de l'EA

**Inconvénients:**
- Configuration manuelle requise
- Pas d'automatisation facile
- 818 paramètres à configurer

**Procédure:**
1. Compiler SMC_Universal.mq5 dans MetaEditor
2. Ouvrir Strategy Tester
3. Configurer manuellement selon `params/MANUAL_CONFIG.md`
4. Exécuter et sauvegarder les rapports

---

## Option 2: API MetaTrader5 Python (Limité)

**Avantages:**
- Automatisation possible
- Récupération de données historiques facile
- Scripts personnalisables

**Inconvénients:**
- **Ne peut pas exécuter des backtests d'EA complets**
- Limité à la récupération de données et exécution d'ordres en temps réel
- Nécessite de réimplémenter toute la logique de l'EA en Python

**Utilisation:**
```python
import MetaTrader5 as mt5
import pandas as pd

# Récupérer des données historiques
mt5.initialize()
rates = mt5.copy_rates_from("GainX_400", mt5.TIMEFRAME_M1, datetime(2024,1,1), datetime(2024,12,31))
df = pd.DataFrame(rates)
```

**Script disponible:** `run_backtest.py` (template pour récupération de données)

---

## Option 3: Réimplémentation Python Pure (Long terme)

**Avantages:**
- Contrôle total de la logique
- Backtest rapide avec vectorisation (pandas/numpy)
- Optimisation de paramètres facile (scikit-optimize, optuna)
- Visualisation avancée (matplotlib, plotly)

**Inconvénients:**
- **Très long à implémenter** (818 paramètres, logique complexe)
- Risque de bugs/différences avec l'EA originale
- Maintenance difficile

**Librairies recommandées:**
- `backtrader` - Framework de backtest complet
- `vectorbt` - Backtest vectorisé rapide
- `freqtrade` - Spécialisé crypto, adaptable

---

## Option 4: MT5 Strategy Tester + Automation (Hybride)

**Avantages:**
- Utilise le moteur MT5 officiel
- Automatisation possible via subprocess
- Rapports HTML complets

**Inconvénients:**
- Complexité d'automatisation
- Dépend de l'installation MT5 locale

**Approche:**
```python
import subprocess

# Lancer MT5 avec arguments de backtest
subprocess.run([
    r"C:\Program Files\MetaTrader 5\terminal64.exe",
    "/portable",
    "/config:config.ini",
    "/tester:SMC_Universal.ex5",
    "/symbol:GainX_400",
    "/period:M1",
    "/model:0",  # Every tick
    "/from:20240101",
    "/to:20241231",
    "/forward:0",
    "/optimization:0",
    "/visual:0"
])
```

---

## Recommandation Actuelle

**Pour l'instant:**
1. Utiliser **Option 1** (Strategy Tester manuel) avec `params/MANUAL_CONFIG.md`
2. Exécuter les backtests sur les actifs principaux (GainX_400, PainX_400)
3. Analyser les résultats et ajuster les paramètres

**Pour le futur:**
1. Si les backtests manuels sont trop longs, envisager **Option 4** (automation)
2. Si une optimisation massive est nécessaire, envisager **Option 3** (réimplémentation Python)

---

## Installation des dépendances Python

```bash
cd D:\Dev\TradBOT\mt5\backtest
pip install -r requirements.txt
```

---

## Script Python disponible

`run_backtest.py` - Template pour:
- Vérifier les fichiers historiques
- Copier les données vers MT5
- Structure pour automatisation future

**Note:** Ce script ne lance pas encore de backtests complets - c'est un point de départ pour l'automatisation.
