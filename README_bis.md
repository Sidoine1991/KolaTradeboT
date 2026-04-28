# Trading System 360° — Guide d'installation et d'utilisation

## Architecture du système

```
MetaTrader 5 (EA_Analysis360.mq5)
        │
        │  Écrit analysis_SYMBOL.json dans MQL5/Files/
        ▼
file_bridge.py  (surveille le dossier MQL5/Files)
        │
        │  Appelle le moteur IA
        ▼
ai_server.py    (analyse + génère les signaux)
        │
        │  Écrit AI_MT5_signals.json dans MQL5/Files/
        ▼
MetaTrader 5    (EA lit le signal et exécute si AUTO_TRADE=true)
```

---

## Installation Python

```bash
cd python/
pip install -r requirements.txt

# Lancer le bridge (surveille MT5 et traite les analyses)
python file_bridge.py
```

## Configuration MT5

1. Copier `EA_Analysis360.mq5` dans `MQL5/Experts/`
2. Compiler dans MetaEditor (F7)
3. Attacher l'EA sur n'importe quel chart (il analysera tous les symbols du MarketWatch)
4. Paramètres recommandés :
   - `AUTO_TRADE = false`  → démarrer en mode observation
   - `LOG_TO_FILE = true`  → activer les logs
   - `ACCOUNT_BALANCE`     → mettre votre capital réel

## Ajuster le capital dans ai_server.py

```python
RISK_PARAMS = {
    "account_balance" : 10000.0,   # ← Modifier ici
    "scalping_risk_pct": 1.0,      # 1% par trade scalping
    "swing_risk_pct"   : 1.5,      # 1.5% par trade swing
}
```

## Fichiers générés

| Fichier | Description |
|---------|-------------|
| `logs/ai_server_YYYYMMDD.log` | Logs du serveur AI |
| `logs/signals_YYYYMMDD.json` | Tous les signaux générés |
| `signals/SYMBOL_TS_STATUS.json` | Détail par signal |
| `EA_log_YYYYMMDD.txt` | Logs de l'EA MQL5 |

## Modes de fonctionnement

### Mode observation (recommandé pour démarrer)
- `AUTO_TRADE = false` dans l'EA
- Les signaux sont loggés mais non exécutés
- Valider la qualité des signaux sur 2-3 semaines

### Mode semi-automatique
- `AUTO_TRADE = false`
- Lire les signaux dans `signals/` et exécuter manuellement

### Mode automatique
- `AUTO_TRADE = true` dans l'EA
- L'EA exécute automatiquement les signaux reçus
- ⚠️ Tester sur compte démo d'abord

## Symbols supportés

| Type | Exemples | Spread max |
|------|----------|-----------|
| Forex Majeur | EURUSD, GBPUSD, USDJPY | 2.0 pips |
| Forex Cross | EURGBP, AUDJPY | 3.0 pips |
| Forex Exotique | EURTRY, USDZAR | 5.0 pips |
| Indices Volatilité | V10, V25, V75, BOOM1000 | 0.5 pts |
| Indices | US30, NAS100, DE40 | 1.0 pts |

## Score de confluence

| Score | Décision | Confiance |
|-------|----------|-----------|
| 85-100 | SIGNAL | HIGH |
| 75-84 | SIGNAL | MEDIUM |
| 70-74 | SIGNAL scalping (LOW) | LOW |
| < 70 | HOLD | — |
