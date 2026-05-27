# 🚀 GoldSMC v5 — Roadmap Production

## 📍 Où Sommes-Nous?

```
✅ FAIT                    🔄 EN COURS              ⏳ À FAIRE
────────────────────────────────────────────────────────────────
v5 Compilée              
Régime Auto              
Partial TP               
Dashboard                
                                                    → Backtest 14 ans
                                                    → Optimisation WFA
                                                    → Tests Démo
                                                    → Production
```

---

## 🎯 Objectifs Clés v5

| Objectif | Cible | Statut |
|----------|-------|--------|
| **Performance BULL** | PF ≥ 5.0 | ⏳ À valider |
| **Performance BEAR** | PF ≥ 2.0 | ⏳ Nouveau! |
| **Max Drawdown** | ≤ 20% | ⏳ À valider |
| **Recovery Factor** | ≥ 3.0 | ⏳ À valider |
| **Sharpe Ratio** | ≥ 1.5 | ⏳ À calculer |

---

## 📅 Timeline 8 Semaines

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  SEMAINE 1-2: BACKTEST & ANALYSE                           │
│  ├─ Backtest 14 ans (2012-2026)                            │
│  ├─ Analyse par régime (BULL/BEAR/TRANSITION)              │
│  ├─ Métriques: PF, DD, Win Rate, RF                        │
│  └─ Décision GO/NO-GO optimisation                         │
│                                                             │
│  SEMAINE 3-4: OPTIMISATION                                 │
│  ├─ Walk-Forward Analysis                                  │
│  ├─ Optimisation paramètres prioritaires                   │
│  ├─ Monte Carlo (1000 simulations)                         │
│  └─ Validation robustesse                                  │
│                                                             │
│  SEMAINE 5-6: TESTS DÉMO                                   │
│  ├─ Déploiement compte démo $10,000                        │
│  ├─ Monitoring quotidien PnL/DD                            │
│  ├─ Validation régime detection temps réel                 │
│  └─ Logs: 50+ trades minimum                               │
│                                                             │
│  SEMAINE 7: PRODUCTION ÉTAPE 1                             │
│  ├─ Capital: $50                                            │
│  ├─ Risk: 0.5% par trade                                   │
│  ├─ MaxDailyTrades: 2                                      │
│  └─ Objectif: PF ≥ 1.0                                     │
│                                                             │
│  SEMAINE 8+: SCALING PROGRESSIF                            │
│  ├─ Semaine 9: $100 capital (si PF > 1.0)                 │
│  ├─ Mois 2: $200 capital (si PF > 1.5)                    │
│  └─ Mois 3+: $500+ capital (si PF > 2.0)                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 4 Phases Détaillées

### PHASE 1: Backtest (Semaine 1-2)

**🎯 Objectif:** Valider performance historique v5

#### Actions:
1. Backtest MT5 complet
   - Période: 2012-2026 (14 ans)
   - Quality: Every tick
   - Exporter: HTML + CSV trades

2. Backtest par régime
   - Bull: 2016-2017, 2019-2020, 2024-2025
   - Bear: 2013-2015, 2018, 2022-2023
   - Transition: 2020 Q1, 2023 Q4

3. Analyse approfondie
   - Script Python `analyze_backtest_v5.py`
   - Rapport PDF avec graphiques
   - Comparaison v4 vs v5

#### Livrables:
- [ ] `goldsmc_v5_backtest_14ans.html`
- [ ] `goldsmc_v5_trades.csv`
- [ ] `goldsmc_v5_analysis.pdf`
- [ ] Décision GO/NO-GO Phase 2

---

### PHASE 2: Optimisation (Semaine 3-4)

**🎯 Objectif:** Affiner paramètres pour robustesse

#### Paramètres Prioritaires:

```
RegimeFilterThreshold:     0.003 → 0.010 (pas 0.001)
PartialTPRatio:           1.2 → 2.0    (pas 0.1)
TrailingStopRatio:        2.5 → 4.0    (pas 0.5)
LotReducePctTransition:   30% → 70%    (pas 10%)
```

#### Méthode:
- Walk-Forward Analysis (70% train, 30% test)
- Critère: Maximize `(PF × RF) / DD`
- Contrainte: Win Rate ≥ 50%

#### Validation:
- Monte Carlo: 1000 simulations
- Probabilité ruine < 1%
- Performance OOS cohérente

#### Livrables:
- [ ] `goldsmc_v5_optimized_params.set`
- [ ] `optimization_report.pdf`
- [ ] `monte_carlo_analysis.csv`

---

### PHASE 3: Tests Démo (Semaine 5-6)

**🎯 Objectif:** Validation conditions réelles

#### Configuration:
```
Compte:      Démo Deriv $10,000
Terminal:    MT5 E6E3 ou F016
Symbol:      frxXAUUSD
Risk:        0.5% (conservateur)
MaxTrades:   2 par jour
Duration:    2 semaines minimum
```

#### Monitoring Quotidien:
- [ ] Régime détecté vs conditions réelles
- [ ] PnL journalier
- [ ] Drawdown courant
- [ ] Slippage réel vs backtest
- [ ] Partial TP: exécution correcte

#### Critères de Réussite:
- PF ≥ 1.5 après 50 trades
- Max DD < 15%
- 0 bugs critiques
- Régime detection: cohérence 90%+

#### Si Échec:
- Analyser pattern perdant
- Ajuster paramètres
- Redémarrer Phase 3

---

### PHASE 4: Production (Semaine 7+)

**🎯 Objectif:** Déploiement capital réel progressif

#### Scaling Plan:

```
ÉTAPE 1 (Semaine 7-8): Micro Capital
  Capital:      $50
  Risk:         0.5%
  Lot min:      0.01
  MaxTrades:    2/jour
  Objectif:     PF > 1.0

ÉTAPE 2 (Semaine 9-10): Petit Capital
  Capital:      $100
  Risk:         0.75%
  MaxTrades:    2/jour
  Objectif:     PF > 1.5

ÉTAPE 3 (Mois 2): Capital Moyen
  Capital:      $200
  Risk:         1.0%
  MaxTrades:    3/jour
  Objectif:     PF > 1.8

ÉTAPE 4 (Mois 3+): Capital Cible
  Capital:      $500+
  Risk:         1.0-1.5%
  MaxTrades:    3/jour
  Objectif:     PF ≥ 2.0 (stable)
```

#### Règle d'Or:
**Si DD > 10% à n'importe quelle étape → PAUSE immédiate**

---

## 📊 Dashboards & Alertes

### Dashboard MT5 (Intégré EA)
- Régime actuel: BULL 🟢 / BEAR 🔴 / TRANSITION 🟠
- PnL: Jour / Semaine / Mois
- Drawdown: Courant / Max
- Prochains niveaux: Support/Résistance

### Dashboard Python (Externe)
```bash
streamlit run Python/dashboard_goldsmc_v5.py
```
- Courbe équité temps réel
- Distribution profits/pertes
- Performance par régime
- Graphiques interactifs

### Alertes WhatsApp Automatiques
- 🚨 Drawdown > 8%
- 🚨 3 pertes consécutives
- 🔄 Régime change (BULL↔BEAR)
- ✅ Partial TP exécuté
- 🎯 Trade clôturé trailing

---

## ⚠️ Plan de Contingence

### Si Performance Médiocre (PF < 1.3 après 100 trades)

1. **PAUSE** trading immédiate
2. **Analyse forensique:**
   - Exporter tous trades
   - Pattern perdant dominant?
   - Régime mal détecté?
3. **Backtest corrélation:**
   - Trades perdants réels = perdants BT?
   - Si oui: problème paramètres
   - Si non: problème exécution
4. **Action:**
   - Ajuster paramètres
   - Re-tester démo
   - Ou attendre meilleures conditions

### Si Drawdown Critique (> 18%)

1. **STOP EA** immédiatement
2. **Clôturer** positions ouvertes
3. **Gel capital**: pas de nouveau trade
4. **Post-mortem**:
   - Quelle série de trades?
   - Régime détecté correctement?
   - Money management respecté?
5. **Décision:**
   - Bug → corriger
   - Paramètres → ré-optimiser
   - Marché anormal → attendre

---

## ✅ Checklist Pré-Production

### Code
- [ ] Compilation: 0 erreurs, 0 warnings
- [ ] MagicNumber: 20260525
- [ ] Paramètres externalisés (0 hardcode)
- [ ] Logs: niveau approprié
- [ ] Gestion erreurs: try-catch OrderSend
- [ ] Circuit breaker: stop après N erreurs

### Backtest
- [ ] PF global ≥ 2.0
- [ ] PF bull ≥ 5.0
- [ ] PF bear ≥ 2.0
- [ ] Max DD ≤ 20%
- [ ] Recovery Factor ≥ 3.0
- [ ] WFA validé
- [ ] Monte Carlo: prob ruine < 1%

### Démo
- [ ] 2 semaines minimum
- [ ] PF ≥ 1.5
- [ ] 0 bugs critiques
- [ ] Slippage acceptable
- [ ] Partial TP fonctionnel
- [ ] Dashboard OK

### Infrastructure
- [ ] VPS uptime 99.9%
- [ ] MT5 stable
- [ ] Monitoring actif
- [ ] Alertes WhatsApp configurées
- [ ] Backups automatiques
- [ ] Logs archivés

---

## 🎯 KPIs Mensuels

| Période | PF Min | Win Rate | Max DD | Note |
|---------|--------|----------|--------|------|
| **Mois 1** | 1.3 | 50% | 12% | Adaptation |
| **Mois 2-3** | 1.8 | 55% | 15% | Stabilisation |
| **Mois 4-6** | 2.0 | 55% | 18% | Objectif atteint |
| **Année 1** | 2.0+ | 55%+ | <20% | ROI ≥ 50% net |

---

## 🔧 Outils à Créer

### 1. Script Analyse Backtest
```python
Python/analyze_backtest_v5.py
  ├─ Parse MT5 report HTML
  ├─ Calculate metrics (PF, DD, RF, Sharpe)
  ├─ Plot equity curve
  ├─ Analyze by regime
  └─ Generate PDF report
```

### 2. Dashboard Temps Réel
```python
Python/dashboard_goldsmc_v5.py (Streamlit)
  ├─ Performance overview
  ├─ Equity curve live
  ├─ Trade distribution
  ├─ Regime status
  └─ Alerts panel
```

### 3. Alertes WhatsApp
```python
Python/goldsmc_v5_alerts.py
  ├─ Check drawdown > 8%
  ├─ Check consecutive losses ≥ 3
  ├─ Check regime change
  └─ Send WhatsApp alert
```

### 4. Export Logs CSV
```mql5
GoldSMC_EA_v5.mq5 (fonction à ajouter)
  └─ WriteRegimeLog(regime, ema50, ema200)
     → goldsmc_v5_regime_log.csv
```

---

## 📅 Prochaines Actions (Cette Semaine)

### Lundi 26/05:
- [ ] Configurer backtest MT5 (2012-2026)
- [ ] Lancer backtest overnight
- [ ] Vérifier fichier .set paramètres

### Mardi 27/05:
- [ ] Récupérer résultats backtest
- [ ] Exporter HTML + CSV trades
- [ ] Première analyse visuelle

### Mercredi 28/05:
- [ ] Créer script `analyze_backtest_v5.py`
- [ ] Générer rapport PDF
- [ ] Backtest régimes individuels

### Jeudi 29/05:
- [ ] Analyser résultats par régime
- [ ] Comparer v4 vs v5
- [ ] Identifier points faibles

### Vendredi 30/05:
- [ ] Rapport décision GO/NO-GO
- [ ] Si GO: préparer Phase 2 (optimisation)
- [ ] Si NO-GO: identifier correctifs

---

**Statut Actuel:** 📋 Phase 1 — Prêt à démarrer  
**Prochaine Étape:** Backtest 14 ans  
**Date Cible Production:** Semaine du 21 juillet 2026  
**Créé le:** 2026-05-25
