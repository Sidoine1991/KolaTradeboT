# Guide de test — Harmonisation visuels GOM KOLA SIDO

**Fichier:** `GOM_KOLA_script.pine` (harmonisé)  
**Backup:** `GOM_KOLA_script_BACKUP_20260607.pine`  
**Durée test:** 30-45 min

---

## ✅ Étape 1: Compilation Pine (5 min)

### **TradingView Desktop/Web:**

1. Ouvrir TradingView Pine Editor
2. Copier tout le contenu de `GOM_KOLA_script.pine`
3. Cliquer "Save" (ne pas encore ajouter au chart)
4. **Vérifier:** 
   - ✅ 0 erreurs compilation
   - ✅ 0 warnings critiques
   - ✅ Message "Compiled successfully"

### **Si erreur CE10095 (variable déjà définie):**
- Rechercher la variable en double
- Supprimer la 2ème définition
- Recompiler

---

## ✅ Étape 2: Test Boom500 M1 (15 min)

### **Configuration:**
```
Symbole: Boom 500 Index (Deriv)
Timeframe: M1
Panel unifié: OUI (ui_signal_panel = true)
```

### **Checklist visuelle:**

#### **A. Panneau Signal Unifié (bottom_left)** 🎯
- [ ] Frame **orange** (BRAND_SECONDARY)
- [ ] Action ">>> ACHETER <<<" en **GOLD** si tradable (BRAND_ACCENT)
- [ ] Pre-Spike "BOOM ▲" en **orange** si tradable
- [ ] Prob/Imm en **vert** (BULL) si >= seuil
- [ ] Texte hiérarchie: blanc/gris-bleu/gris (PRIMARY/SECONDARY/MUTED)
- [ ] EA "ENVOYER TRADE" en **cyan** (BRAND_PRIMARY)

#### **B. Flèches clignotantes pre-spike** 🎯
- [ ] Triangles **ÉNORMES** (size huge ON, large OFF)
- [ ] Couleur **vert électrique** (#00FF80) si BOOM
- [ ] Effet blink visible (2 états alternants)
- [ ] Position sous barre (belowbar)

#### **C. Chemin prédictif (si activé)** 🎯
- [ ] Segments **CYAN** (#00D5FE) si direction haussière
- [ ] Segments **ORANGE** (#FF6B35) si direction baissière
- [ ] PAS de lime/red classique
- [ ] Bougies fantômes transp 75% (cyan/orange)

#### **D. KOLA Levels**
- [ ] Ligne BUY **vert électrique** (#00FF80), width=2
- [ ] Ligne SELL **red moderne** (#FF3366), width=2
- [ ] Labels "(touches)" cohérent

#### **E. Order Blocks**
- [ ] Box OB Bull: border **vert**, bg vert transp 88%
- [ ] Box OB Bear: border **red**, bg red transp 88%

#### **F. Fibonacci OTE**
- [ ] Lignes OTE 61.8/78.6: **CYAN** (#00D5FE) - PAS fuchsia!
- [ ] Ligne 50%: **orange neutre** (#FFB800)
- [ ] Zone OTE: bg vert/red transp 75% selon tendance

---

## ✅ Étape 3: Test Volatility100 M5 (15 min)

### **Configuration:**
```
Symbole: Volatility 100 Index (Deriv)
Timeframe: M5
Panel unifié: NON (ui_signal_panel = false)
```

### **Checklist visuelle:**

#### **A. Table Verdict GOM (bottom_left)** 🎯
- [ ] Header "GOM VERDICT" **cyan** (BRAND_PRIMARY)
- [ ] BUY score **vert** (#00FF80)
- [ ] SELL score **red** (#FF3366)
- [ ] Spike % **gold** (#FFD700) si >= seuil
- [ ] RSI Alert **orange** (BRAND_SECONDARY) si survente/surachat
- [ ] Force **gold** si >=4, **vert** si >=2.5
- [ ] Coherence/Quality: vert/orange/red gradient
- [ ] KOLA: "NEAR BUY" vert, "NEAR SELL" red

#### **B. Table MTF (top_right)** 🎯
- [ ] Header TF/DIR/RSI **cyan** (BRAND_PRIMARY)
- [ ] BULL cells: bg **vert transp 85%**
- [ ] BEAR cells: bg **red transp 85%**
- [ ] GLOBAL row: "BULL 5B" vert si majorité bull

#### **C. Table Pre-Spike (top_center si Boom/Crash)**
- [ ] Frame **orange** (BRAND_SECONDARY)
- [ ] Header selon niveau: gold/orange/wait
- [ ] Tradable "OUI" en **vert** (BULL)

#### **D. Table Setup (middle_right)**
- [ ] Header "SETUP" **cyan** (BRAND_PRIMARY)
- [ ] SL en **red** (#FF3366)
- [ ] TP1 en **vert** (#00FF80)
- [ ] TP2 en **cyan** (#00D5FE)
- [ ] R/R en **orange** (#FF6B35)

#### **E. SIDO Double Top/Bottom**
- [ ] DT (Double Top): ligne **orange** (BRAND_SECONDARY), dashed
- [ ] DB (Double Bottom): ligne **cyan** (BRAND_PRIMARY), dashed
- [ ] Labels "DT"/"DB" cohérents

#### **F. CHoCH / BOS (si activé)**
- [ ] CHoCH ^ vert, CHoCH v red, size small
- [ ] BOS ^ cyan, BOS v orange, size tiny

---

## ✅ Étape 4: Test collision tables (5 min)

### **Positions des 6 tables:**
1. **top_right:** MTF (sauf si Boom/Crash + panel unifié)
2. **top_center:** Pre-Spike (Boom/Crash uniquement)
3. **top_left:** MTF (si Boom/Crash + panel unifié)
4. **bottom_left:** Signal unifié OU Verdict GOM
5. **middle_right:** Setup
6. **bottom_right:** GHOST OrderFlow

### **Test petit écran:**
- [ ] Résolution 1366×768: pas de collision
- [ ] Toutes tables lisibles
- [ ] Pas de texte tronqué

---

## ✅ Étape 5: Test GHOST OrderFlow (5 min)

### **Vérifications:**
- [ ] Table bottom_right visible
- [ ] Header "GHOST OrderFlow" **gold** (#ffd700)
- [ ] Sentiment gauge: bleu/red (#2962ff / #f23645)
- [ ] Delta histogramme: barres bleu/red
- [ ] Boussole 8 directions: symboles E/NE/N/NW/W/SW/S/SE
- [ ] Heatmap liquidité: boxes overlay bleu dégradé

**Note:** Palette GHOST conservée (OF_BULL/OF_BEAR distincte du reste)

---

## ✅ Étape 6: Performance (5 min)

### **Test lag:**
1. Activer tous visuels (KOLA, SIDO, OB, Fib, Spike, Path, Tables)
2. Scroll rapide chart (50 barres/sec)
3. **Vérifier:** rendering fluide, pas de freeze

### **CPU usage:**
- [ ] Usage CPU <30% (idle)
- [ ] Usage GPU <50% (rendering)
- [ ] Pas de memory leak (surveillance 5 min)

---

## 🔄 Rollback si problème majeur

```bash
cd D:\Dev\TradBOT\mt5
cp GOM_KOLA_script_BACKUP_20260607.pine GOM_KOLA_script.pine
```

**Problèmes mineurs:** Noter dans rapport, corriger après tests

---

## 📸 Screenshots requis

### **Avant/Après (depuis backup):**
1. **Boom500 M1 panel unifié:**
   - Flèches clignotantes (avant: lime, après: vert électrique huge)
   - Chemin prédictif (avant: lime/red, après: cyan/orange)
   - Panel signal (avant: orange mix, après: frame orange + action gold)

2. **V100 M5 tables classiques:**
   - Fibonacci OTE (avant: fuchsia, après: cyan)
   - KOLA levels (avant: lime/red, après: vert/red harmonisé)
   - Verdict GOM (avant: gris neutre, après: cyan header)

3. **GHOST OrderFlow:**
   - Confirmer palette conservée (OF_BULL bleu, pas changé)

---

## ✅ Validation finale

### **Si tous tests OK:**
- [ ] 0 erreurs compilation
- [ ] 6 tables positionnées correctement
- [ ] Flèches huge visibles (Boom/Crash)
- [ ] Chemin cyan/orange (pas lime/red)
- [ ] Fib OTE cyan (pas fuchsia)
- [ ] KOLA vert/red harmonisé
- [ ] GHOST OrderFlow conservé
- [ ] Performance <100ms rendering
- [ ] Screenshots capturés

### **→ Merge production:**
```bash
git add mt5/GOM_KOLA_script.pine
git commit -m "feat(tv): harmoniser visuels GOM KOLA SIDO — palette GHOST Pro"
git push
```

### **Si problèmes mineurs:**
- Noter dans `HARMONIZATION_ISSUES.md`
- Corriger via Edit ciblés
- Re-tester section concernée

### **Si problèmes majeurs:**
- Rollback vers backup
- Analyser erreurs
- Corriger en brouillon
- Re-tester complet

---

## 📋 Checklist complète (copier/coller)

```
[ ] Étape 1: Compilation Pine (0 erreurs)
[ ] Étape 2: Boom500 M1 (panel unifié, flèches huge, chemin cyan/orange)
[ ] Étape 3: V100 M5 (tables classiques, Fib cyan, KOLA harmonisé)
[ ] Étape 4: Collision tables (6 positions OK)
[ ] Étape 5: GHOST OrderFlow (palette conservée)
[ ] Étape 6: Performance (<100ms rendering)
[ ] Screenshots avant/après (3 captures)
[ ] Validation finale (tous items OK)
[ ] Merge production OU Rollback
```

---

**Durée totale:** 30-45 min  
**Risque:** Faible (visuels seulement, backup existant)  
**Priorité:** Haute (identité visuelle pro)

**FIN DU GUIDE DE TEST**
