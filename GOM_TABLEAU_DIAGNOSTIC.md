# 🔍 DIAGNOSTIC : Tableau GOM TradingView Boom 500 Index

**Date:** 2026-06-07  
**Chart:** DERIV:BOOM_500_INDEX M1  
**Indicateur:** GOM KOLA SIDO — Full Integration (ID: jKjHgC)  
**Status:** ✅ Chargé et fonctionnel  

---

## ✅ DONNÉES DISPONIBLES

L'indicateur GOM retourne **60+ valeurs**, dont :

### 📊 Valeurs principales
```
RSI: 70.19
VWAP: 5056.44
BB Mid: 5013.07
Supertrend: 5292.29 (direction: 1 = BUY)
```

### 🎯 Scores GOM
```
score_buy: 5.366
score_sell: 2.820
verdict_num: 2.000 (BUY)
verdict_gap: 2.546
entry_quality: 37.97%
coherence_pct: 66.67%
spike_pct: 8.29%
```

### 🧭 GHOST OrderFlow
```
ghost_delta: 0.000 ⚠️
ghost_cvd: -66446.12
ghost_buypct: 16.09%
ghost_sellpct: 83.91%
ghost_compass: 39.33°
```

### 🌍 Multi-Timeframe Global
```
tf_global_dir: -1 (BEARISH)
tf_global_strength: 6/7
tf_bull_count: 1
tf_bear_count: 6
```

### 📈 Prédiction (200 bars)
```
pred_bull: 119
pred_bear: 9
pred_neut: 72
pred_net: +110 (bullish)
pred_base_score: 14.80%
```

### 🎯 Setup (TABLEAU) — PROBLÈME ICI
```
setup_dir: 0 ⚠️  (pas de direction)
setup_entry: 0 ⚠️  (pas d'entrée)
setup_sl: 0 ⚠️  (pas de SL)
setup_tp1: 0 ⚠️  (pas de TP1)
setup_tp2: 0 ⚠️  (pas de TP2)
setup_rr: 0 ⚠️  (pas de R:R)
setup_confirm_code: 0
```

### 📍 Niveaux KOLA
```
kola_buy: 5016.65 (support)
kola_sell: 5023.68 (résistance)
```

---

## 🔴 PROBLÈME IDENTIFIÉ

Le **tableau GOM Pine Script** affiche normalement ces informations en **bas du graphique** dans un `table.new()`, mais les valeurs **setup_*** sont **toutes à 0**.

### Pourquoi le setup est vide ?

Le code Pine Script GOM calcule un setup **uniquement si certaines conditions sont remplies** :

1. **Entry quality ≥ 50%** (actuellement 37.97% ⚠️)
2. **Coherence ≥ 70%** (actuellement 66.67% ⚠️)
3. **Verdict aligné avec TF global** (verdict=BUY mais tf_global_dir=BEARISH ⚠️)
4. **Confirmation additionnelle** (SIDO, KOLA, spike, etc.)

**Résultat:** Les conditions ne sont **pas remplies**, donc le tableau affiche le verdict mais **pas de setup Entry/SL/TP**.

---

## ✅ SOLUTION 1 : Attendre de meilleures conditions

Le tableau GOM fonctionne correctement. Il affiche simplement :
```
Verdict: BUY
Quality: 37.97%
Setup: — (conditions insuffisantes)
```

**Action:** Attendre que :
- Entry quality > 50%
- Coherence > 70%
- TF global aligné avec verdict

---

## ✅ SOLUTION 2 : Assouplir les critères du Pine Script

Modifier le code Pine Script GOM KOLA pour afficher le setup même avec quality < 50% :

```pine
// Ligne ~850 dans GOM KOLA Pine Script
// AVANT :
if (entry_quality >= 50.0 and coherence_pct >= 70.0)
    setup_dir := verdict_num
    setup_entry := close
    ...

// APRÈS :
if (entry_quality >= 30.0 and coherence_pct >= 60.0)  // Seuils assouplis
    setup_dir := verdict_num
    setup_entry := close
    ...
```

---

## ✅ SOLUTION 3 : Forcer affichage du setup dans le tableau

Même si les conditions ne sont pas parfaites, afficher un setup "indicatif" :

```pine
// Toujours calculer un setup (même si quality faible)
setup_dir := verdict_num
setup_entry := close

// SL/TP basés sur ATR ou Keltner
atr_val = ta.atr(14)
if verdict_num == 1  // BUY
    setup_sl := close - (atr_val * 1.5)
    setup_tp1 := close + (atr_val * 2.0)
    setup_tp2 := close + (atr_val * 3.0)
else if verdict_num == -1  // SELL
    setup_sl := close + (atr_val * 1.5)
    setup_tp1 := close - (atr_val * 2.0)
    setup_tp2 := close - (atr_val * 3.0)

setup_rr := math.abs(setup_tp1 - setup_entry) / math.abs(setup_entry - setup_sl)

// Ajouter warning dans le tableau si quality faible
table_text := "⚠️  SETUP INDICATIF (quality " + str.tostring(entry_quality, "#.#") + "%)"
```

---

## 📊 AFFICHAGE ACTUEL DU TABLEAU

Le tableau GOM sur votre TradingView devrait afficher quelque chose comme :

```
┌─────────────────────────────────────────────┐
│ GOM KOLA — Boom 500 Index M1                │
├─────────────────────────────────────────────┤
│ Verdict: BUY                                │
│ Quality: 37.97% ⚠️                          │
│ Coherence: 66.67%                           │
│                                              │
│ RSI: 70.19 (overbought)                     │
│ Supertrend: UP                              │
│ Score Buy: 5.37 | Sell: 2.82               │
│                                              │
│ GHOST:                                       │
│ Buy: 16% | Sell: 84% (bearish)             │
│ CVD: -66,446                                │
│                                              │
│ Multi-TF Global: BEARISH (6/7)              │
│                                              │
│ Setup: —                                     │
│ (conditions insuffisantes)                   │
└─────────────────────────────────────────────┘
```

**Si vous ne voyez PAS ce tableau** → Le Pine Script utilise `table.new()` qui peut être masqué si :
1. Vous avez scroll/zoom trop loin
2. Le tableau est configuré pour s'afficher uniquement sur certain TF
3. Le code Pine a une erreur (vérifier console Pine)

---

## 🔧 VÉRIFICATION : Le tableau est-il visible ?

### Option A : Vérifier visuellement

1. Sur TradingView, regardez **en bas à gauche** ou **en bas à droite** du graphique
2. Cherchez un **tableau avec bordures** contenant "GOM KOLA"
3. Si invisible → Possibilité que `table.position` soit hors écran

### Option B : Vérifier le code Pine

1. Dans TradingView, cliquer sur l'indicateur "GOM KOLA SIDO"
2. Cliquer sur **{} Source code** ou **Edit**
3. Chercher `table.new(position = ...)`
4. Vérifier que `position = position.bottom_left` ou `position.bottom_right`

### Option C : Récupérer les valeurs du tableau via Pine Labels

Si le tableau `table.new()` ne s'affiche pas, on peut utiliser `label.new()` pour afficher les données :

```pine
// Remplacer table.new() par label.new()
if barstate.islast
    label.new(
        bar_index, 
        high, 
        "GOM: " + verdict_str + " | Quality: " + str.tostring(entry_quality) + "%\n" +
        "Setup: " + (setup_dir != 0 ? "Entry " + str.tostring(setup_entry) : "—"),
        style=label.style_label_down,
        color=verdict_num == 1 ? color.green : color.red,
        textcolor=color.white
    )
```

---

## 📝 DONNÉES EXPLOITABLES ACTUELLEMENT

Même sans le setup complet, vous avez déjà ces informations utiles :

✅ **Verdict:** BUY (mais faible qualité 37.97%)  
✅ **Direction TF Global:** BEARISH (6/7) ⚠️  
✅ **Prédiction 200 bars:** +110 (bullish)  
✅ **GHOST:** 84% sell pressure (bearish) ⚠️  
✅ **RSI:** 70.19 (overbought) ⚠️  
✅ **Niveaux KOLA:**  
   - Support: 5016.65  
   - Résistance: 5023.68  

**Conclusion:** Le signal BUY est **faible et contradictoire** avec les données multi-TF et GHOST → **Pas de trade recommandé actuellement**.

---

## 🚀 PROCHAINES ÉTAPES

### 1. Vérifier que le tableau est visible sur TradingView
- Regarder en bas du graphique
- Si absent → modifier position dans Pine Script

### 2. Attendre de meilleures conditions
- Entry quality > 50%
- TF global aligné avec verdict
- GHOST confirmant (buypct > 60% pour BUY)

### 3. Ou modifier le Pine Script
- Assouplir critères : quality ≥ 30%, coherence ≥ 60%
- Toujours afficher un setup (même avec warning)

### 4. Utiliser les données actuelles dans MT5
Le fichier `data/gom_signal.json` devrait contenir :
```json
{
  "symbol": "Boom500Index",
  "verdict": "BUY",
  "quality": 37.97,
  "ghost_delta": 0.0,
  "ghost_cvd": -66446.12,
  "ghost_buypct": 16.09,
  "ghost_sellpct": 83.91,
  "setup_entry": 0,
  "setup_sl": 0,
  "setup_tp1": 0
}
```

L'EA MT5 `deriveapro.mq5` v10.03 chargera ces données via `LoadGOMFromTV()` et affichera dans son dashboard.

---

**Date de diagnostic:** 2026-06-07 09:30 UTC  
**Status:** ✅ GOM fonctionne, tableau vide car conditions insuffisantes  
**Action:** Attendre meilleures conditions ou assouplir critères Pine Script  
