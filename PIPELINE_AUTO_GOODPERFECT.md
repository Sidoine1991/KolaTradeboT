# Pipeline Auto Good/Perfect + Rapports Word

## Vue d'ensemble

Le **pipeline auto Good/Perfect** est une solution complète pour :

1. **Scan GOM MT5** — filtre uniquement les signaux **Good** (±2) et **Perfect** (±3)
2. **Analyse** — extrait Entry/SL/TP/ATR pour chaque signal
3. **Rapports Word** — génère et envoie un rapport détaillé via WhatsApp pour chaque Good/Perfect
4. **Auto-placement** — place les ordres automatiquement (marché/stop/limit) pour les **top-3**
5. **Résumé WhatsApp** — notifie le résultat final

## Architecture

```
Scan GOM MT5
    ↓
Filter Good/Perfect (verdict_num ±2, ±3)
    ↓
Analyser chaque signal
    ├─ Calculer Entry/SL/TP
    ├─ Générer rapport Word
    └─ Envoyer rapport WhatsApp
    ↓
Top-3 valides
    ├─ Gate IA status (≥70%)
    ├─ Gate MTF (H4+H1+M15)
    └─ Place ordres auto
    ↓
Résumé WhatsApp final
```

## Utilisation

### Exécution simple (top-3)

```bash
cd D:/Dev/TradBOT
python Python/pipeline_auto_goodperfect.py
```

### Avec paramètres

```bash
# Analyser top-5 au lieu de top-3
python Python/pipeline_auto_goodperfect.py --top-n 5

# Mode test (sans placer ordres)
python Python/pipeline_auto_goodperfect.py --dry-run

# Combinaison
python Python/pipeline_auto_goodperfect.py --top-n 5 --dry-run
```

### Via script Windows

```bash
# Démarrage manuel
D:\Dev\TradBOT\scripts\start_pipeline_auto_goodperfect.bat

# Enregistrer comme tâche planifiée (toutes les heures)
PowerShell -ExecutionPolicy Bypass -File D:\Dev\TradBOT\scripts\register_pipeline_auto_goodperfect_task.ps1 -Frequency Hourly -Interval 1
```

## Filtres appliqués

### Good/Perfect uniquement
- **Good** = `verdict_num = ±2`
- **Perfect** = `verdict_num = ±3`
- **Rejet** = `verdict_num` < 2 (WAIT, HOLD, etc.)

### Validation Boom/Crash
- ❌ **SELL sur Boom** = rejeté
- ❌ **BUY sur Crash** = rejeté

### Gates d'ordre

#### Gate IA Status
- ✅ `coherence_pct >= 70%` → ordre placé
- ❌ `coherence_pct < 70%` → ordre bloqué

#### Gate MTF (Multi-Timeframe)
- ✅ **BUY valide** : H4=BULL OU (H1=BULL ET M15=BULL)
- ✅ **SELL valide** : H4=BEAR OU (H1=BEAR ET M15=BEAR)
- ❌ **Rejet absolu** : H4+H1 tous deux opposés au signal

#### Cohérence MTF
- ✅ ≥ 4/6 timeframes alignées → ordre placé
- ❌ < 4/6 → ordre bloqué

## Rapports Word

Pour chaque Good/Perfect analysé, un rapport Word est généré et envoyé via WhatsApp :

```
📊 SIGNAL ANALYSIS — SYMBOL

Time: YYYY-MM-DD HH:MM:SS UTC
Direction: BUY / SELL
Verdict: PERFECT / GOOD

━━━━━━━━━━━━━━━━━━
ENTRY LEVELS
━━━━━━━━━━━━━━━━━━
Entry Price: X.XXXXX
Stop Loss:   X.XXXXX
Take Profit: X.XXXXX
Lot:         0.XX

Risk/Reward: 1:X.XX

━━━━━━━━━━━━━━━━━━
INDICATORS
━━━━━━━━━━━━━━━━━━
ATR (14):       X.XXXXX
IA Status:      XX%

Timeframe Analysis:
  M1:  BULL/BEAR/NEUT
  M5:  BULL/BEAR/NEUT
  M15: BULL/BEAR/NEUT
  H1:  BULL/BEAR/NEUT
  H4:  BULL/BEAR/NEUT
  D1:  BULL/BEAR/NEUT

Execution Type: market / limit / stop
```

## Types d'exécution

- **market** = entrée immédiate au prix courant
- **limit** = BUY en-dessous du prix / SELL au-dessus (pullback)
- **stop** = BUY au-dessus du prix / SELL en-dessous (breakout)

## Logs

- **Logs console** → affichage temps réel
- **Logs fichier** → `logs/pipeline_auto_goodperfect.log`
- **Rapports Word** → `logs/Signal_SYMBOL_YYYYMMDD_HHMMSS.txt`

## Alertes WhatsApp

### Au démarrage
```
🤖 TradBOT — Pipeline Auto Good/Perfect
HH:MM UTC

Traite N signal(s):
  1. SYMBOL1 BUY (GOOD)
  2. SYMBOL2 SELL (PERFECT)
  3. ...
```

### À la fin
```
🏁 TradBOT — Pipeline Terminé
HH:MM UTC

✅ Ordres placés    : N
📄 Rapports envoyés : N
❌ Erreurs          : N

Placés:  SYMBOL1, SYMBOL2
Rapports: SYMBOL1, SYMBOL2
Erreurs: SYMBOL3 (IA_STATUS_45%)

Durée: XXs
```

## Configuration

### Environnement (.env)
```bash
AI_SERVER_URL=http://127.0.0.1:8000
PSYCHOBOT_URL=https://psychobot-1si7.onrender.com
WHATSAPP_PHONE_NUMBER=+2290196911346
```

### Prérequis
- ✅ `ai_server` en cours d'exécution (port 8000)
- ✅ `gom_sync` actif (données GOM MT5 à jour)
- ✅ `PsychoBot` accessible (envoi WhatsApp/rapports)
- ✅ Connexion réseau active

## Dépannage

### Aucun signal Good/Perfect trouvé
- Vérifier que GOM MT5 a des données fraîches (`/gom-verdicts`)
- Vérifier que les symboles scannent avec `verdict_num ≥ ±2`

### Ordres non placés (gate IA status)
- Vérifier `coherence_pct` ≥ 70%
- Message : `IA_STATUS_XX%` dans les erreurs

### Ordres non placés (gate MTF)
- Vérifier alignement H4/H1/M15
- Message : `MTF_GATE: ...` dans les erreurs

### Rapports Word non envoyés
- Vérifier PsychoBot accessible
- Vérifier permissions WhatsApp

### Ordres non exécutés par TradeManager
- Vérifier TradeManager en cours
- Vérifier `/pending-order` endpoint fonctionnel

## Améliorations possibles

- [ ] Ajouter support for signal_refiner (quality_score > 75)
- [ ] Intégrer TradingAgents analyse optionnelle
- [ ] Ajouter support pour lots dynamiques
- [ ] Paramétrer seuils de gate par catégorie
- [ ] Ajouter backtest validation avant live

---

**Dernière mise à jour** : 2026-06-12  
**Version** : 1.0  
**Statut** : Production ✅
