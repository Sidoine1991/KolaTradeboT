# Périodes Régimes XAUUSD pour Backtests MT5
Généré: 2026-05-25 22:36:25
Source: XAUUSD_H1_2010_2023.csv

## Instructions

Pour chaque période ci-dessous:
1. MT5 Strategy Tester
2. Expert: GoldSMC_EA_v5.ex5
3. Settings → Load: Optimization/goldsmc_v5_<REGIME>.set
4. Period: Start/End ci-dessous
5. Quality: Every tick
6. Start test

---


## BULL PERIODS

Total périodes: 1

### Périodes > 30 jours (1):

| # | Start | End | Days | MT5 Format |
|---|-------|-----|------|------------|
| 1 | 2017-01-30 | 2023-12-29 | 2524 | `2017.01.30 - 2023.12.29` |


## BEAR PERIODS

Total périodes: 1

### Périodes > 30 jours (1):

| # | Start | End | Days | MT5 Format |
|---|-------|-----|------|------------|
| 1 | 2013-11-04 | 2016-12-18 | 1141 | `2013.11.04 - 2016.12.18` |


## TRANSITION PERIODS

Total périodes: 2

### Périodes > 30 jours (1):

| # | Start | End | Days | MT5 Format |
|---|-------|-----|------|------------|
| 1 | 2016-12-19 | 2017-01-29 | 42 | `2016.12.19 - 2017.01.29` |


---

## Backtests Recommandés

### BULL
Top 3-4 périodes les plus longues (idéalement > 200 jours)

### BEAR
Top 3-4 périodes les plus longues (idéalement > 100 jours)

### TRANSITION
Top 2-3 périodes représentatives

---

## Analyse Résultats

Après chaque backtest:
```bash
python Python/analyze_goldsmc_backtest.py "rapport.xlsx"
```

Objectifs:
- BULL: PF ≥ 5.0, Win Rate ≥ 55%, DD < 20%
- BEAR: PF ≥ 2.0, Win Rate ≥ 50%, DD < 20%
- TRANSITION: PF ≥ 1.8, Win Rate ≥ 52%, DD < 15%
