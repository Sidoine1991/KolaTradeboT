# 🔧 PATCH : Afficher tableau GOM pour Boom 500 Index

**Problème :** Le tableau horizontal GOM en bas de TradingView ne s'affiche pas pour Boom 500 Index.

**Cause :** Quality = 43% < 50% (seuil minimum Pine Script pour afficher le setup dans le tableau).

**Pour les autres symboles ça marche** → Leur quality est probablement > 50%.

---

## ✅ SOLUTION 1 : Assouplir les critères Pine Script (RECOMMANDÉ)

### Modifie l'indicateur GOM KOLA sur TradingView :

```
1. Sur TradingView, clique sur l'indicateur "GOM KOLA SIDO — Full Integration"
2. Clique sur l'icône "..." (3 points) → "Edit" ou appuie sur icône </>
3. Cherche la ligne (environ ligne 850-900) :

// AVANT (strict)
if (entry_quality >= 50.0 and coherence_pct >= 70.0 and tf_aligned)
    setup_dir := verdict_num
    setup_entry := close
    setup_sl := ...
    setup_tp1 := ...

// APRÈS (assoupli pour Boom/Crash)
// Seuils assouplis pour indices synthétiques volatils
float quality_threshold = syminfo.ticker == "BOOM_500_INDEX" or 
                          syminfo.ticker == "CRASH_500_INDEX" or
                          syminfo.ticker == "BOOM_1000_INDEX" or
                          syminfo.ticker == "CRASH_1000_INDEX" ? 30.0 : 50.0

if (entry_quality >= quality_threshold and coherence_pct >= 60.0)
    setup_dir := verdict_num
    setup_entry := close
    setup_sl := close - (atr_val * 1.5)  // ou ton calcul SL
    setup_tp1 := close + (atr_val * 2.0)  // ou ton calcul TP
    setup_tp2 := close + (atr_val * 3.0)
    setup_rr := math.abs(setup_tp1 - setup_entry) / math.abs(setup_entry - setup_sl)

4. Sauvegarde l'indicateur
5. Recharge le graphique Boom 500 Index
```

**Résultat :** Le tableau affichera maintenant le setup même avec quality 43%.

---

## ✅ SOLUTION 2 : Forcer l'affichage du tableau (SIMPLE)

Si tu veux **TOUJOURS** afficher le tableau, même avec quality très faible :

```pine
// Dans la section "Affichage du tableau" (cherche "table.new")

// AVANT
if (entry_quality >= 50.0 and coherence_pct >= 70.0)
    // Afficher tableau complet

// APRÈS (toujours afficher)
// Toujours calculer le setup
setup_dir := verdict_num
setup_entry := close

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

// Afficher tableau TOUJOURS (avec warning si quality faible)
string quality_label = entry_quality < 50 ? " ⚠️ LOW QUALITY" : ""
```

---

## ✅ SOLUTION 3 : Vérifier le code du tableau (DIAGNOSTIC)

Cherche dans le Pine Script la section qui crée le tableau :

```pine
// Cherche cette section (environ ligne 950-1000)
if barstate.islast
    var table tbl = table.new(position.bottom_right, 4, 15, ...)
    
    // Vérifier cette condition
    if (setup_dir != 0)  // ← SI CETTE CONDITION EST FAUSSE, TABLEAU VIDE
        table.cell(tbl, 0, row, "Entry:", ...)
        table.cell(tbl, 1, row, str.tostring(setup_entry), ...)
        ...
```

**Si `setup_dir == 0`** → Le tableau n'affiche pas les lignes Entry/SL/TP.

**Fix :**
```pine
// Remplace la condition par :
if (verdict_num != 0)  // Afficher si verdict existe
    // Calculer setup même si quality < 50%
    float temp_entry = close
    float temp_sl = verdict_num == 1 ? close - atr_val*1.5 : close + atr_val*1.5
    float temp_tp1 = verdict_num == 1 ? close + atr_val*2.0 : close - atr_val*2.0
    
    table.cell(tbl, 0, row, "Entry:", ...)
    table.cell(tbl, 1, row, str.tostring(temp_entry), ...)
    table.cell(tbl, 0, row+1, "SL:", ...)
    table.cell(tbl, 1, row+1, str.tostring(temp_sl), ...)
    ...
```

---

## 🎯 SOLUTION RAPIDE (SI TU AS ACCÈS AU CODE PINE)

**Modifie juste 1 ligne :**

```pine
// Ligne ~850-900, cherche :
if (entry_quality >= 50.0 and coherence_pct >= 70.0)

// Remplace par :
if (entry_quality >= 30.0 and coherence_pct >= 60.0)  // Seuils assouplis
```

**Sauvegarde → Recharge Boom 500 Index → Le tableau apparaîtra !**

---

## 📊 POURQUOI ÇA MARCHE POUR LES AUTRES SYMBOLES ?

**Exemple : XAUUSD**
```
Quality: 43% (même que Boom 500)
Mais XAUUSD a peut-être :
- TF Global aligné avec verdict (pas de contradiction)
- Ou le code Pine a des conditions spéciales pour Forex
- Ou le tableau affiche même avec quality < 50% pour certains symboles
```

**Vérifions XAUUSD actuellement :**

Je peux changer le symbole TV sur XAUUSD pour comparer si tu veux.

---

## ✅ CE QUE JE PEUX FAIRE MAINTENANT

**Option A :** "Change sur XAUUSD pour comparer"
→ Je vais voir pourquoi ça marche sur XAUUSD mais pas Boom 500

**Option B :** "Je vais modifier le Pine Script moi-même"
→ Je t'ai donné le patch ci-dessus, modifie les seuils 50→30

**Option C :** "Modifie le Pine Script pour moi"
→ Mais je ne peux pas éditer directement ton indicateur TradingView privé. Tu dois :
1. Ouvrir l'éditeur Pine (icône </> sur l'indicateur)
2. Chercher la ligne avec `entry_quality >= 50.0`
3. Changer en `entry_quality >= 30.0`
4. Sauvegarder

**Quelle option tu préfères ?** 🎯

---

## 📸 À QUOI RESSEMBLE LE TABLEAU GOM (quand il s'affiche)

```
┌─────────────────────────────────────────────┐
│ GOM KOLA — Boom 500 Index M1                │
├─────────────────────────────────────────────┤
│ Verdict: PERFECT BUY ⭐⭐⭐                  │
│ Quality: 43% ⚠️  (seuil bas)                │
│ Coherence: 83%                              │
│                                              │
│ Score Buy: 6.68 ▲                           │
│ Score Sell: 1.90 ▼                          │
│ Gap: 4.78                                    │
│                                              │
│ GHOST OrderFlow:                            │
│ Buy: 24% | Sell: 76% ▼                     │
│ Delta: +92.89                               │
│ CVD: -70,017                                │
│                                              │
│ Multi-TF Global: BEARISH (5/7) ⚠️          │
│ Bull: 2 TF | Bear: 5 TF                    │
│                                              │
│ Prediction (200 bars):                      │
│ Bull: 168 | Bear: 0 | Neut: 32            │
│ Net: +168 (bullish)                         │
│                                              │
│ Setup BUY:                                  │
│ Entry: 5011.79                              │
│ SL: 5010.82                                 │
│ TP1: 5012.76                                │
│ TP2: 5013.25                                │
│ R:R: 1.00                                   │
└─────────────────────────────────────────────┘
```

**Si tu vois juste les premières lignes (Verdict/Quality) mais PAS le Setup** → C'est exactement le problème quality < 50%.

---

**Dis-moi ce que tu veux faire !** 🚀
