# 🎯 Accès aux Top 3 Symboles Recommandés — Guide Complet

## 📊 Où voir le Top 3 dans le Dashboard ?

Le **Top 3 symboles recommandés** s'affiche dans la section **"Top 3 symboles recommandés pour le robot (historique journal)"** du dashboard TradBOT.

---

## 🚀 3 Méthodes pour Accéder au Top 3

### **Méthode 1: Via le Dashboard Web (FACILE — Recommandé)**

#### Étape 1: Lancer le serveur dashboard
```bash
Double-clic sur: D:\Dev\TradBOT\launch-dashboard.bat
```

OU en cmd:
```bash
cd D:\Dev\TradBOT
python dashboard/serve_trade_journal.py
```

#### Étape 2: Ouvrir le navigateur
```
http://127.0.0.1:8765/
```

#### Étape 3: Voir le Top 3
- Scrollez vers le bas du journal
- Vous verrez la section: **"Top 3 symboles recommandés pour le robot (historique journal)"**
- Les données se chargeront automatiquement depuis l'API `/api/recommendations`

---

### **Méthode 2: Via l'API JSON (Pour développeurs)**

#### Requête directe:
```bash
curl http://127.0.0.1:8765/api/recommendations
```

#### Réponse:
```json
{
  "top_symbols": [
    {
      "symbol": "Crash 1000 Index",
      "category": "BOOM_CRASH",
      "score": 70.4,
      "trades": 61,
      "win_rate": 57.4,
      "net_pnl": 7.59,
      "profit_factor": 1.24,
      "best_direction": "SELL",
      "best_hours": [
        {"hour_utc": 23, "label": "23h-24h UTC", "win_rate": 100.0},
        {"hour_utc": 18, "label": "18h-19h UTC", "win_rate": 100.0}
      ]
    },
    ...
  ]
}
```

---

### **Méthode 3: Via Fichier JSON (Hors ligne)**

#### Fichier:
```
D:\Dev\TradBOT\data\top3_recommendations.json
```

#### Consulter:
```bash
cat D:\Dev\TradBOT\data\top3_recommendations.json
```

OU via Python:
```python
import json
with open('D:\\Dev\\TradBOT\\data\\top3_recommendations.json') as f:
    data = json.load(f)
    for sym in data['top_symbols']:
        print(f"{sym['symbol']}: Score {sym['score']}, WR {sym['win_rate']}%")
```

---

## 🔄 Mettre à Jour les Recommandations

Les Top 3 sont calculés chaque semaine. Pour regénérer:

```bash
cd D:\Dev\TradBOT
python python/generate_top3_recommendations.py
```

Cela crée/met à jour:
- `data/top3_recommendations.json` (données brutes)
- `logs/top3_report.html` (rapport HTML)

---

## 📋 Contenu du Top 3 Affiché

Pour chaque symbole, vous verrez:

```
#1 — CRASH 1000 INDEX
  Catégorie: BOOM_CRASH
  Score: 70.4/100
  Win Rate: 57.4% (61 trades)
  Net PnL: +7.59$
  Profit Factor: 1.24x
  
  Fenêtres actives (UTC):
  • 23h-24h UTC (100% WR)
  • 18h-19h UTC (100% WR)
  • 07h-08h UTC (66.7% WR)
  
  Direction: SELL only (Crash)
  Durée moyenne: 12.5 min
  
  Stratégie recommandée:
  Boom: BUY only | Crash: SELL only
  · Fenêtres actives: 23h-24h UTC, 18h-19h UTC
  · Direction historique: SELL
  · Durée moy. 12 min
```

---

## ⏰ Heures en UTC — Convertir à votre Broker

Les heures affichées sont en **UTC (GMT+0)**.

**Ajouter votre décalage broker:**

| Broker Zone | Décalage | Exemple |
|-------------|----------|---------|
| **GMT+0** (UK) | +0h | 23h UTC = 23h |
| **GMT+1** (CET/WET) | +1h | 23h UTC = 00h+1 (minuit) |
| **GMT+2** (CEST/EET) | +2h | 23h UTC = 01h+1 |
| **GMT+3** (MSK/AST) | +3h | 23h UTC = 02h+1 |
| **EST (UTC-5)** | -5h | 23h UTC = 18h |

**Exemple pratique:**
- Signal: 23h-24h UTC
- Si vous tradez en GMT+2: 23h + 2h = 01h (minuit à 1h du matin)

---

## 🐛 Problèmes Courants

### **Le Top 3 ne s'affiche pas dans le dashboard**

**Cause 1: Serveur non lancé**
```bash
# Vérifier que le serveur tourne
# Si le port 8765 est fermé, relancer:
D:\Dev\TradBOT\launch-dashboard.bat
```

**Cause 2: Pas de trades historiques**
```bash
# Vérifier le nombre de trades
python -c "
import sys
sys.path.insert(0, 'dashboard')
from serve_trade_journal import load_trades
trades = load_trades()
print(f'Trades loaded: {len(trades)}')
"
```

**Cause 3: Moins de 8 trades par symbole**
```bash
# Les symboles avec < 8 trades ne sont pas recommandés
# Exécuter plus de trades pour voir les Top 3
```

---

## ✅ Checklist — Voir le Top 3

- [ ] Lancé le serveur: `launch-dashboard.bat`
- [ ] Ouvert le navigateur: `http://127.0.0.1:8765/`
- [ ] Attendu le chargement des données (quelques secondes)
- [ ] Scrollé vers le bas du journal
- [ ] Vu la section "Top 3 symboles recommandés"
- [ ] Convertis les heures UTC à votre zone broker

---

## 📞 Support

Si les Top 3 ne s'affichent toujours pas:

1. **Vérifier les logs du serveur:**
   ```bash
   tail -100 logs/dashboard.log
   ```

2. **Vérifier les données JSON:**
   ```bash
   cat data/top3_recommendations.json
   ```

3. **Regénérer les recommandations:**
   ```bash
   python python/generate_top3_recommendations.py
   ```

4. **Relancer le serveur:**
   ```bash
   # Fermer la fenêtre actuelle et relancer
   D:\Dev\TradBOT\launch-dashboard.bat
   ```

---

**Dernière mise à jour**: 2026-06-17  
**Base historique**: 1067 trades  
**Symboles éligibles**: 12 (minimum 8 trades/symbole)
