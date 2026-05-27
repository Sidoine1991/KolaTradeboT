# GoldSMC v5 - Planning Walk-Forward Analysis
Généré: 2026-05-25 21:26:36

## Méthodologie

**Fenêtre glissante:**
- Train: 24 mois (70%)
- Test: 6 mois (30%)
- Pas: 6 mois (overlap pour robustesse)

**Critère d'optimisation:**
Maximiser: `(Profit Factor × Recovery Factor) / Max Drawdown %`

**Contraintes:**
- Win Rate ≥ 45%
- Profit Factor ≥ 1.5
- Max Drawdown ≤ 25%

---

## Périodes WFA

Total: 26 itérations


### Itération 1

**TRAIN (2012.01.01 → 2013.12.21)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2013.12.21 → 2014.06.19)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 2

**TRAIN (2012.06.29 → 2014.06.19)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2014.06.19 → 2014.12.16)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 3

**TRAIN (2012.12.26 → 2014.12.16)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2014.12.16 → 2015.06.14)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 4

**TRAIN (2013.06.24 → 2015.06.14)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2015.06.14 → 2015.12.11)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 5

**TRAIN (2013.12.21 → 2015.12.11)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2015.12.11 → 2016.06.08)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 6

**TRAIN (2014.06.19 → 2016.06.08)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2016.06.08 → 2016.12.05)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 7

**TRAIN (2014.12.16 → 2016.12.05)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2016.12.05 → 2017.06.03)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 8

**TRAIN (2015.06.14 → 2017.06.03)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2017.06.03 → 2017.11.30)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 9

**TRAIN (2015.12.11 → 2017.11.30)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2017.11.30 → 2018.05.29)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 10

**TRAIN (2016.06.08 → 2018.05.29)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2018.05.29 → 2018.11.25)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 11

**TRAIN (2016.12.05 → 2018.11.25)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2018.11.25 → 2019.05.24)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 12

**TRAIN (2017.06.03 → 2019.05.24)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2019.05.24 → 2019.11.20)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 13

**TRAIN (2017.11.30 → 2019.11.20)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2019.11.20 → 2020.05.18)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 14

**TRAIN (2018.05.29 → 2020.05.18)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2020.05.18 → 2020.11.14)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 15

**TRAIN (2018.11.25 → 2020.11.14)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2020.11.14 → 2021.05.13)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 16

**TRAIN (2019.05.24 → 2021.05.13)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2021.05.13 → 2021.11.09)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 17

**TRAIN (2019.11.20 → 2021.11.09)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2021.11.09 → 2022.05.08)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 18

**TRAIN (2020.05.18 → 2022.05.08)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2022.05.08 → 2022.11.04)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 19

**TRAIN (2020.11.14 → 2022.11.04)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2022.11.04 → 2023.05.03)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 20

**TRAIN (2021.05.13 → 2023.05.03)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2023.05.03 → 2023.10.30)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 21

**TRAIN (2021.11.09 → 2023.10.30)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2023.10.30 → 2024.04.27)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 22

**TRAIN (2022.05.08 → 2024.04.27)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2024.04.27 → 2024.10.24)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 23

**TRAIN (2022.11.04 → 2024.10.24)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2024.10.24 → 2025.04.22)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 24

**TRAIN (2023.05.03 → 2025.04.22)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2025.04.22 → 2025.10.19)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 25

**TRAIN (2023.10.30 → 2025.10.19)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2025.10.19 → 2026.04.17)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

### Itération 26

**TRAIN (2024.04.27 → 2026.04.17)**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST (2026.04.17 → 2026.10.14)**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---

## Instructions MT5

### 1. Optimisation (phase TRAIN)

```
1. Ouvrir Strategy Tester MT5
2. Expert: GoldSMC_EA_v5.ex5
3. Période: Dates TRAIN de l'itération
4. Mode: Optimization (Genetic Algorithm)
5. Critère: Custom max (PF × RF / DD)
6. Charger: goldsmc_v5_optimization_ranges.set
7. Lancer optimisation
8. Sauvegarder meilleurs résultats
```

### 2. Test (phase TEST)

```
1. Charger meilleurs paramètres de TRAIN
2. Période: Dates TEST de l'itération
3. Mode: Single run
4. Quality: Every tick
5. Lancer test
6. Comparer métriques vs TRAIN
```

### 3. Validation

Pour chaque itération, vérifier:
- [ ] PF test ≥ 1.5
- [ ] Win Rate test ≥ 45%
- [ ] DD test ≤ 25%
- [ ] PF test ≥ 80% PF train
- [ ] Performance cohérente

---

## Résultats attendus

**Si WFA réussit (toutes itérations validées):**
✅ Paramètres robustes confirmés
✅ Passer Phase 3: Tests démo
✅ Confiance élevée pour production

**Si échec sur >30% des itérations:**
❌ Overfitting détecté
❌ Retour optimisation
❌ Revoir logique EA

---

## Fichiers générés

- `goldsmc_v5_BULL.set` - Paramètres optimisés BULL
- `goldsmc_v5_BEAR.set` - Paramètres optimisés BEAR
- `goldsmc_v5_TRANSITION.set` - Paramètres optimisés TRANSITION
- `goldsmc_v5_optimization_ranges.set` - Plages optimisation génétique
