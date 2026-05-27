# 🎯 Planning GoldSMC v5 — Perfectionnement et Mise en Production

## 📊 État Actuel (2026-05-25)

### ✅ Ce qui est fait:

1. **Version 5 compilée et validée**
   - Fichier: `Validated_EA\GoldSMC_EA_v5_validated_20260525.mq5`
   - Taille: 47 KB
   - Compilation: 0 erreurs, 0 warnings
   - MagicNumber: 20260525

2. **Fonctionnalités v5 implémentées:**
   - ✅ Détection automatique régime marché (BULL/BEAR/TRANSITION)
   - ✅ EMA50/200 sur W1 pour filtrage directionnel
   - ✅ Partial TP: 50% fermé à RR=1.5, trailing sur 50% restant
   - ✅ Suppression BuyBiasOnly (remplacé par UseRegimeFilter)
   - ✅ Dashboard avec affichage régime en couleur
   - ✅ Tous les correctifs v4 préservés

3. **Backtest v4 (référence):**
   - Période bull 2024-2025: **PF=6.49** ✅
   - Période bear 2022-2023: **-13.1%** ❌
   - Raison échec: BuyBiasOnly=TRUE aveugle aux conditions baissières

---

## 🎯 Objectifs v5

### Objectif Principal
Créer un EA "all-weather" performant en bull ET bear markets grâce à la détection automatique du régime.

### Cibles de Performance

| Métrique | Objectif | Rationale |
|----------|----------|-----------|
| **Profit Factor** | ≥ 2.0 | Minimal pour systèmes automatisés |
| **Win Rate** | ≥ 55% | Acceptable avec RR > 2 |
| **Max Drawdown** | ≤ 20% | Protection capital |
| **Recovery Factor** | ≥ 3.0 | Net profit / Max DD |
| **Sharpe Ratio** | ≥ 1.5 | Rendement ajusté au risque |
| **Régime BULL** | PF ≥ 5.0 | Maintenir perf v4 |
| **Régime BEAR** | PF ≥ 2.0 | Nouveau: survivre aux bears |
| **Transition** | Breakeven | Préserver capital |

---

## 📅 Planning de Perfectionnement (4 Phases)

### PHASE 1: Backtest Complet v5 (1-2 jours)

**Objectif:** Valider la performance sur données historiques complètes

#### Tâche 1.1: Backtest Long Terme (14 ans)
- [ ] Période: 2012-2026
- [ ] Tick data: Every tick (qualité maximale)
- [ ] Paramètres: Configuration v5 par défaut
- [ ] Générer rapport HTML MT5
- [ ] Exporter trades en CSV
- [ ] Capturer courbe équité

**Métriques à collecter:**
- Profit Factor global
- Win Rate
- Max Drawdown (% et $)
- Recovery Factor
- Sharpe Ratio
- Nombre de trades par an
- Profit moyen par trade
- Plus grande série perdante

#### Tâche 1.2: Backtest par Régime
- [ ] **Bull Markets:**
  - 2016-2017 (bull pre-COVID)
  - 2019-2020 (bull COVID)
  - 2024-2025 (bull récent)
  
- [ ] **Bear Markets:**
  - 2013-2015 (consolidation or)
  - 2018 (correction)
  - 2022-2023 (bear hawkish Fed)

- [ ] **Transition:**
  - 2020 Q1 (COVID crash)
  - 2023 Q4 (pivot Fed)

**Attendu:**
- PF ≥ 5.0 en bull
- PF ≥ 2.0 en bear
- Breakeven en transition

#### Tâche 1.3: Analyse des Trades
- [ ] Exporter tous les trades en CSV
- [ ] Analyser distribution profits/pertes
- [ ] Identifier patterns perdants récurrents
- [ ] Vérifier cohérence détection régime
- [ ] Valider partial TP à RR=1.5

**Outils:**
```python
# Script d'analyse à créer
python Python/analyze_backtest_v5.py \
  --trades Backtest_report/goldsmc_v5_trades.csv \
  --output Backtest_report/goldsmc_v5_analysis.pdf
```

---

### PHASE 2: Optimisation Paramètres (2-3 jours)

**Objectif:** Affiner les paramètres pour maximiser performance

#### Tâche 2.1: Paramètres à Optimiser

**Priorité HAUTE:**
| Paramètre | Plage | Pas | Actuel |
|-----------|-------|-----|--------|
| `RegimeFilterThreshold` | 0.003-0.010 | 0.001 | 0.005 |
| `PartialTPRatio` | 1.2-2.0 | 0.1 | 1.5 |
| `TrailingStopRatio` | 2.5-4.0 | 0.5 | 3.0 |
| `LotReducePctTransition` | 30-70 | 10 | 50 |

**Priorité MOYENNE:**
| Paramètre | Plage | Pas | Actuel |
|-----------|-------|-----|--------|
| `RiskPercent` | 0.5-2.0 | 0.25 | 1.0 |
| `MinRR` | 1.5-3.0 | 0.25 | 2.0 |
| `ATRMultiplierSL` | 1.5-3.0 | 0.25 | 2.0 |

#### Tâche 2.2: Méthode d'Optimisation

**Walk-Forward Analysis (WFA):**
```
Training: 70% des données
Testing: 30% OOS (Out-of-Sample)

Exemple:
  Train: 2012-2020 (8 ans)
  Test:  2021-2026 (5 ans)

Ou découpage en fenêtres glissantes:
  Window 1: Train 2012-2018, Test 2019-2020
  Window 2: Train 2014-2020, Test 2021-2022
  Window 3: Train 2016-2022, Test 2023-2024
```

**Critère d'optimisation:**
- Maximize: `(Profit Factor × Recovery Factor) / Max Drawdown`
- Constraint: Win Rate ≥ 50%

#### Tâche 2.3: Validation Robustesse

**Monte Carlo Analysis:**
- [ ] 1000 simulations avec permutation des trades
- [ ] Calculer distribution drawdown max
- [ ] Vérifier probabilité ruine < 1%
- [ ] Valider sizing risque approprié

---

### PHASE 3: Tests Démo en Réel (1-2 semaines)

**Objectif:** Valider performance en conditions réelles

#### Tâche 3.1: Déploiement Démo

**Configuration:**
- [ ] Compte démo Deriv: $10,000 initial
- [ ] VPS avec uptime 99.9%
- [ ] Terminal MT5: E6E3 (T1) OU F016 (T2)
- [ ] Symbol: frxXAUUSD
- [ ] Timeframe: M1 (chart), W1 (régime detection)

**Paramètres conservateurs:**
```ini
RiskPercent = 0.5         # Réduit vs 1.0 (capital préservation)
MaxDailyTrades = 2        # Vs 3 (éviter overtrading)
UseRegimeFilter = true
PartialTPRatio = 1.5
TrailingStopRatio = 3.0
```

#### Tâche 3.2: Monitoring Quotidien

**Dashboard à surveiller:**
- [ ] Régime détecté (BULL/BEAR/TRANSITION)
- [ ] EMA50 vs EMA200 sur W1
- [ ] Nombre trades par jour
- [ ] PnL journalier
- [ ] Drawdown courant
- [ ] Slippage réel vs backtest

**Logs à capturer:**
```
logs/goldsmc_v5_demo_YYYY-MM-DD.log
```

**Métriques hebdomadaires:**
- Trades executés vs opportunités backtest
- Cohérence détection régime avec conditions réelles
- Différence slippage/commissions réel vs backtest
- Partial TP: % fermés à RR=1.5

#### Tâche 3.3: Ajustements en Cours de Route

**Si PF < 1.5 après 50 trades:**
- [ ] Revoir seuils régime (trop/pas assez sensibles?)
- [ ] Vérifier filtres LTF+HTF trop stricts
- [ ] Analyser trades perdants: pattern commun?

**Si Drawdown > 15%:**
- [ ] Réduire RiskPercent à 0.25%
- [ ] Limiter trades par jour à 1
- [ ] Suspendre temporairement et analyser

---

### PHASE 4: Mise en Production Réel (Progressive)

**Objectif:** Déploiement capital réel avec scaling progressif

#### Tâche 4.1: Pré-Production Checklist

- [ ] ✅ Backtest 14 ans: PF ≥ 2.0, DD ≤ 20%
- [ ] ✅ WFA validé: performance OOS consistante
- [ ] ✅ Monte Carlo: prob ruine < 1%
- [ ] ✅ Démo 2 semaines: PF ≥ 1.5, pas de bugs
- [ ] ✅ Régime detection: cohérence 90%+
- [ ] ✅ Partial TP fonctionnel: logs confirmés
- [ ] ✅ Dashboard: affichage régime correct
- [ ] ✅ Code review: pas de hardcode, tout paramétrable

#### Tâche 4.2: Scaling Plan (Approche Prudente)

**Étape 1: Micro Capital (Semaine 1-2)**
- Capital initial: **$50**
- RiskPercent: **0.5%** (risque $0.25 par trade)
- Lot min: 0.01
- MaxDailyTrades: 2
- **But:** Valider exécution réelle sans risque majeur

**Étape 2: Petit Capital (Semaine 3-4)**
- Capital: **$100** (si Étape 1 PF > 1.0)
- RiskPercent: **0.75%**
- MaxDailyTrades: 2
- **But:** Augmenter taille, vérifier slippage

**Étape 3: Capital Moyen (Mois 2)**
- Capital: **$200** (si Étape 2 PF > 1.5)
- RiskPercent: **1.0%**
- MaxDailyTrades: 3
- **But:** Configuration standard production

**Étape 4: Capital Cible (Mois 3+)**
- Capital: **$500+**
- RiskPercent: **1.0-1.5%**
- MaxDailyTrades: 3
- **But:** Exploitation long terme

**Règle d'Or:** Si drawdown > 10% à n'importe quelle étape → pause, analyse, ajustement.

#### Tâche 4.3: Monitoring Production

**Dashboards à installer:**

1. **Dashboard MT5 (temps réel)**
   - Régime actuel (BULL/BEAR/TRANSITION)
   - PnL journalier/hebdomadaire/mensuel
   - Drawdown courant
   - Prochains niveaux support/résistance

2. **Dashboard externe (Python/Streamlit)**
   ```python
   # À créer
   streamlit run Python/dashboard_goldsmc_v5.py
   ```
   - Courbe équité en temps réel
   - Distribution profits/pertes
   - Performance par régime
   - Alertes SMS/WhatsApp si drawdown > seuil

**Alertes automatiques via WhatsApp:**
- [ ] Drawdown > 8%
- [ ] 3 pertes consécutives
- [ ] Régime change (BULL→BEAR ou inverse)
- [ ] Partial TP exécuté avec succès
- [ ] Trade clôturé à BE après trailing

#### Tâche 4.4: Rapports Mensuels

**Contenu minimal:**
- Performance globale (PnL, PF, Win Rate, DD)
- Performance par régime
- Trades du mois (Excel + graphiques)
- Comparaison backtest vs réel
- Ajustements recommandés (si nécessaire)

**Format:**
```
reports/goldsmc_v5_monthly_YYYY_MM.pdf
```

---

## 🛠️ Outils et Scripts à Créer

### Script 1: Analyse Backtest
```python
# Python/analyze_backtest_v5.py

Fonctions:
- parse_mt5_report(html_file) → dict
- calculate_metrics(trades_csv) → DataFrame
- plot_equity_curve(trades) → PNG
- analyze_by_regime(trades, regime_log) → dict
- generate_pdf_report(metrics, plots) → PDF
```

### Script 2: Dashboard Temps Réel
```python
# Python/dashboard_goldsmc_v5.py (Streamlit)

Sections:
- 📊 Performance Overview (PnL, PF, Win Rate)
- 📈 Equity Curve (live)
- 🎯 Trade Distribution
- 🌍 Regime Detection Status
- 🚨 Alerts & Notifications
```

### Script 3: Alertes WhatsApp
```python
# Python/goldsmc_v5_alerts.py

Triggers:
- check_drawdown(threshold=8%)
- check_consecutive_losses(count=3)
- check_regime_change(prev, current)
- send_alert_whatsapp(message, phone)
```

### Script 4: Export Logs MT5 → CSV
```mql5
// Dans GoldSMC_EA_v5.mq5

void WriteRegimeLog(string regime, double ema50, double ema200) {
    int handle = FileOpen("goldsmc_v5_regime_log.csv", FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if (handle != INVALID_HANDLE) {
        FileWrite(handle, TimeToString(TimeCurrent()), regime, ema50, ema200);
        FileClose(handle);
    }
}
```

---

## 📋 Checklist Finale Avant Production

### Code
- [ ] Compilation: 0 erreurs, 0 warnings
- [ ] MagicNumber unique: 20260525
- [ ] Tous paramètres externalisés (pas de hardcode)
- [ ] Logs: niveau INFO en prod, DEBUG en test
- [ ] Gestion erreurs: try-catch sur OrderSend
- [ ] Circuit breaker: stop après N erreurs consécutives

### Backtest
- [ ] PF global ≥ 2.0
- [ ] PF bull ≥ 5.0
- [ ] PF bear ≥ 2.0
- [ ] Max DD ≤ 20%
- [ ] Recovery Factor ≥ 3.0
- [ ] WFA validé (OOS cohérent)
- [ ] Monte Carlo: prob ruine < 1%

### Démo
- [ ] 2 semaines minimum
- [ ] PF ≥ 1.5
- [ ] 0 bugs critiques
- [ ] Slippage acceptable (< 2 pips avg)
- [ ] Partial TP fonctionnel
- [ ] Dashboard affichage correct

### Infrastructure
- [ ] VPS configuré (uptime 99.9%)
- [ ] MT5 terminal stable
- [ ] Dashboard monitoring actif
- [ ] Alertes WhatsApp configurées
- [ ] Backup EA + config automatique
- [ ] Logs archivés quotidiennement

### Documentation
- [ ] Guide utilisateur v5
- [ ] Paramètres documentés
- [ ] Changelog v4 → v5
- [ ] Procédure d'urgence (stop EA)
- [ ] Contacts support (broker, VPS)

---

## 🎯 KPIs de Succès Production

### Mois 1:
- ✅ PF ≥ 1.3 (phase d'adaptation)
- ✅ Win Rate ≥ 50%
- ✅ Max DD < 12%
- ✅ 0 bugs critiques

### Mois 2-3:
- ✅ PF ≥ 1.8
- ✅ Win Rate ≥ 55%
- ✅ Max DD < 15%
- ✅ Régime detection: 85%+ précision

### Mois 4-6:
- ✅ PF ≥ 2.0 (objectif atteint)
- ✅ Win Rate ≥ 55%
- ✅ Max DD < 18%
- ✅ Scaling capital validé

### Année 1:
- ✅ ROI ≥ 50% net
- ✅ Max DD < 20%
- ✅ Performance stable sur 3+ régimes

---

## 🚨 Plan de Contingence

### Si Performance Médiocre (PF < 1.3 après 100 trades)

**Actions immédiates:**
1. **Pause trading** (désactiver EA)
2. **Analyse forensique:**
   - Exporter tous trades
   - Identifier pattern perdant dominant
   - Vérifier cohérence détection régime
3. **Hypothèses:**
   - Régime mal détecté? → Ajuster seuils EMA
   - Trop de trades en transition? → Augmenter filtre
   - Slippage excessif? → Revoir broker/VPS
4. **Backtest corrélation:**
   - Les trades perdants réels étaient-ils perdants en BT?
   - Si oui: problème paramètres
   - Si non: problème exécution (slippage, requotes)

### Si Drawdown Critique (> 18%)

**Actions immédiates:**
1. **STOP EA immédiatement**
2. **Clôturer positions ouvertes** (si applicable)
3. **Gel capital:** pas de nouveau trade avant analyse
4. **Post-mortem:**
   - Quelle série de trades a causé DD?
   - Régime détecté correctement?
   - Respect money management?
5. **Décision:**
   - Si bug détecté: corriger, re-tester démo
   - Si paramètres inadaptés: ré-optimiser
   - Si conditions marché anormales: attendre normalisation

### Si Bug Critique Découvert

**Procédure:**
1. Désactiver EA sur tous comptes
2. Isoler bug en environnement test
3. Corriger + tests unitaires
4. Recompiler avec nouveau MagicNumber
5. Re-déploiement via démo d'abord

---

## 📊 Timeline Résumé

```
Semaine 1-2:   PHASE 1 - Backtest complet
Semaine 3-4:   PHASE 2 - Optimisation
Semaine 5-6:   PHASE 3 - Démo réel
Semaine 7:     PHASE 4 - Production Étape 1 ($50)
Semaine 9:     Production Étape 2 ($100)
Mois 2:        Production Étape 3 ($200)
Mois 3+:       Production Étape 4 ($500+)
```

**Total:** 2-3 mois du backtest à production full scale

---

## ✅ Prochaines Actions Immédiates

### Cette semaine (2026-05-25 → 2026-05-31):

1. **Lundi-Mardi: Backtest 14 ans**
   ```bash
   # Lancer backtest MT5
   Symbol: frxXAUUSD
   Period: 2012.01.01 - 2026.05.25
   Tick: Every tick based on real ticks
   Params: GoldSMC_EA_v5_params_20260525.set
   ```

2. **Mercredi: Analyse résultats**
   ```bash
   python Python/analyze_backtest_v5.py \
     --html Backtest_report/goldsmc_v5_report.html \
     --trades Backtest_report/goldsmc_v5_trades.csv \
     --output Backtest_report/goldsmc_v5_analysis.pdf
   ```

3. **Jeudi-Vendredi: Backtest par régime**
   - Bull 2024-2025
   - Bear 2022-2023
   - Transition 2023 Q4

4. **Weekend: Rapport décision GO/NO-GO optimisation**

---

**Créé le:** 2026-05-25  
**Auteur:** TradBOT Team  
**Version EA:** GoldSMC v5  
**Statut:** 📋 Planning — En attente exécution Phase 1
