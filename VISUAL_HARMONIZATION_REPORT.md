# GOM KOLA SIDO — Rapport d'harmonisation visuels TradingView

**Date:** 2026-06-07  
**Script:** `mt5\GOM_KOLA_script.pine` (1713 lignes)  
**Objectif:** Harmoniser couleurs, police, épaisseurs pour une identité visuelle cohérente

---

## 1. État actuel des visuels

### Palette couleurs actuelle (incohérente)
- **KOLA levels:** `color.lime` / `color.red`
- **SIDO (DT/DB):** `color.orange` / `color.aqua`
- **Order Blocks:** `color.red` / `color.lime`
- **Fibonacci:** `color.fuchsia` (OTE), `color.orange` (50%)
- **Verdict:** `color.lime` / `color.red` / `color.orange`
- **Spike:** `color.yellow`, `color.orange`
- **GHOST OrderFlow:** `#2962ff` (bull), `#f23645` (bear), `#ffd700` (gold)

### Tables (6 tables)
1. **MTF** (top_right) — gris/noir, 3×10
2. **Signal unifié** (bottom_left) — noir/orange, 2×12
3. **Verdict GOM** (bottom_left) — noir, 2×10
4. **Pre-Spike** (top_center) — noir/orange, 2×8
5. **Setup** (middle_right) — noir, 2×7
6. **GHOST** (bottom_right) — noir, 14×11

### Problèmes identifiés
- ❌ **Incohérence couleurs:** lime/red/orange/aqua/fuchsia/yellow mix
- ❌ **Text size mixte:** `size.small` / `size.normal` / `size.tiny` sans hiérarchie claire
- ❌ **Line width aléatoire:** 1, 2, 4 (basé sur touches, pas design)
- ❌ **Transparence chaotique:** 10, 15, 20, 30, 40, 50, 60, 65, 70, 78, 80, 85, 92, 97
- ❌ **Position tables:** 6 tables dispersées, collision possible
- ❌ **Chemin prédictif:** couleurs lime/red/orange (redondant verdict)

---

## 2. Palette harmonisée proposée

### **Identité GHOST Pro** (dark, pro-trader style)
```pine
// ── Core brand colors (inspiration TradingView + GHOST module) ──
BRAND_PRIMARY   = #00D5FE    // cyan vif (signature GOM KOLA SIDO)
BRAND_SECONDARY = #FF6B35    // orange énergique (alertes, spikes)
BRAND_ACCENT    = #FFD700    // gold (excellence, qualité)

// ── Directional signals (standard marché) ──
BULL = #00FF80               // green électrique
BEAR = #FF3366               // red moderne
WAIT = #FFB800               // orange neutre (attente)

// ── UI surfaces (dark theme cohérent) ──
BG_MAIN   = color.new(#0A0E1A, 85)   // noir-bleu translucide
BG_HEADER = color.new(#1A1F2E, 60)   // header plus sombre
BG_CELL   = color.new(#14172B, 80)   // cellule table
BORDER    = color.new(#2E3650, 40)   // séparateurs

// ── Emphasis levels (hiérarchie typographique) ──
TEXT_PRIMARY   = color.white           // titres, valeurs importantes
TEXT_SECONDARY = color.new(#B0B8D0, 0) // labels, métadonnées
TEXT_MUTED     = color.new(#6B7280, 0) // notes, infos tertiaires
```

---

## 3. Changements par module

### **A. KOLA Levels (lignes 276-306)**
**Avant:**
```pine
color=color.lime / color.red, width=_w (1-4 variable)
```
**Après:**
```pine
color.new(BULL, 0) / color.new(BEAR, 0)
width=2 (constant, épaisseur pro)
style=line.style_solid (pas de dashed)
```

### **B. SIDO — Double Top/Bottom (lignes 381-397)**
**Avant:**
```pine
color.new(color.orange, 20) / color.new(color.aqua, 20)
```
**Après:**
```pine
color.new(BRAND_SECONDARY, 20) / color.new(BRAND_PRIMARY, 20)
style=line.style_dashed (distinction vs KOLA)
```

### **C. Order Blocks (lignes 428-443)**
**Avant:**
```pine
color.red / color.lime, bgcolor=color.new(color.red/lime, 80)
```
**Après:**
```pine
border_color=color.new(BEAR, 0) / color.new(BULL, 0)
bgcolor=color.new(BEAR, 88) / color.new(BULL, 88)
```

### **D. Fibonacci OTE (lignes 542-564)**
**Avant:**
```pine
OTE: color.new(color.fuchsia, 0)
50%: color.new(color.orange, 0)
```
**Après:**
```pine
OTE: color.new(BRAND_PRIMARY, 0)
50%: color.new(WAIT, 0)
Zone OTE: color.new(BULL/BEAR, 75) (selon st_dir)
```

### **E. Spike Detection — barcolor (lignes 794-807)**
**Avant:**
```pine
color.lime / color.red / color.orange / color.yellow mix
```
**Après:**
```pine
spike_level_num == 4: color.new(BRAND_ACCENT, 20)
spike_tradable:       color.new(BRAND_SECONDARY, 30)
spike_watch:          color.new(WAIT, 55)
spike_min:            color.new(BULL/BEAR, 30)
```

### **F. Flèches clignotantes (lignes 1073-1080)**
**Avant:**
```pine
color.lime / color.red
```
**Après:**
```pine
color.new(BULL, 0) / color.new(BEAR, 0)
size=size.huge (ON), size.large (OFF) — plus visible
```

### **G. Tables (6 tables)**

#### **MTF Table (lignes 1114-1140)**
```pine
bgcolor=BG_MAIN
border_color=BORDER
header: bgcolor=BG_HEADER, text_color=BRAND_PRIMARY
cells: text_color=TEXT_PRIMARY
```

#### **Signal Unifié (lignes 1145-1203)**
```pine
border_color=color.new(BRAND_SECONDARY, 35)
frame_color=color.new(BRAND_SECONDARY, 25)
header: bgcolor=spike_tradable ? color.new(BRAND_SECONDARY, 15) : BG_HEADER
action: text_color=spike_tradable ? BRAND_ACCENT : TEXT_PRIMARY
```

#### **GHOST OrderFlow (lignes 1484-1584)**
```pine
// Garder palette GHOST actuelle (déjà cohérente)
OF_BULL = #2962ff
OF_BEAR = #f23645
OF_GOLD = #ffd700
// Ajuster seulement transparence: 0 → 15 (plus lisible)
```

### **H. Chemin prédictif (lignes 1310-1394)**
**Avant:**
```pine
pdir==1: color.new(color.lime, 0)
pdir==-1: color.new(color.red, 0)
pdir==0: color.new(color.orange, 20)
```
**Après:**
```pine
pdir==1: color.new(BRAND_PRIMARY, 15)   // cyan signature
pdir==-1: color.new(BRAND_SECONDARY, 15) // orange signature
pdir==0: color.new(WAIT, 35)            // neutre discret
width=path_width (5 par défaut) → 3 (plus fin, moins invasif)
```

---

## 4. Hiérarchie typographique unifiée

### **Table cell text sizes**
```pine
// Headers (niveau 0)
size.normal (10pt) — titres tableaux

// Primary data (niveau 1)
size.small (8pt) — valeurs importantes (verdict, scores, RSI)

// Secondary data (niveau 2)
size.tiny (6pt) — métadonnées (labels, infos complémentaires)

// Never use size.large — réservé labels chart uniquement
```

### **Chart labels**
```pine
// Signals (PRE-SPIKE, SPIKE, CHoCH)
size.large (12pt) — alertes visuelles majeures

// Levels (KOLA, SIDO, OB)
size.small (8pt) — annotations discrètes

// Metadata (touches, prix)
size.tiny (6pt) — infos techniques
```

---

## 5. Transparence standardisée

### **Niveaux de transparence (0-100)**
```pine
// Opaque (signaux critiques)
0   — Lignes importantes (KOLA, SIDO, Fib OTE)
15  — Labels alertes (PRE-SPIKE)

// Semi-opaque (éléments secondaires)
30  — Borders boxes (OB)
40  — Headers tables

// Translucide (backgrounds)
75  — Zone OTE Fibonacci
85  — BG tables principales
88  — Boxes OB

// Très transparent (ambiance)
92  — bgcolor spike_tradable
97  — bgcolor verdict
```

---

## 6. Plan d'implémentation

### **Phase 1: Variables palette (30 min)**
- Ajouter section `// ═══ VISUAL IDENTITY — GHOST PRO ═══` en haut
- Définir 12 variables couleurs (BRAND_PRIMARY, BULL, BEAR, etc.)
- Tester avec 1 table (MTF) pour validation

### **Phase 2: Refactor tables (1h)**
- Appliquer palette aux 6 tables
- Unifier text_size (3 niveaux max)
- Harmoniser border/frame colors

### **Phase 3: Refactor chart elements (1h)**
- KOLA/SIDO/OB/Fib → nouvelle palette
- Spike barcolor/labels → BRAND_SECONDARY
- Flèches clignotantes → size.huge

### **Phase 4: Chemin prédictif (30 min)**
- Cyan/orange au lieu de lime/red
- Réduire width 5 → 3
- Ajuster transparence 0 → 15

### **Phase 5: Test visuel final (30 min)**
- Screenshot Boom500 M1 + Volatility100 M5
- Vérifier lisibilité dark mode
- Valider cohérence 6 tables + chart

---

## 7. Avant/Après visuel (simulation)

### **Avant (état actuel)**
```
MTF table: gris neutre
Signal: orange/lime/red mix
KOLA: lime/red vif
Chemin: lime/red/orange redondant
GHOST: palette séparée
```

### **Après (harmonisé)**
```
MTF table: cyan header + texte blanc
Signal: BRAND_SECONDARY frame + BRAND_ACCENT action
KOLA: BULL/BEAR standardisé
Chemin: cyan/orange signature (pas de confusion)
GHOST: inchangé (déjà cohérent)
Verdict: orange WAIT neutre (pas jaune/lime)
```

---

## 8. Code snippet — Palette master

```pine
// ═══════════════════════════════════════════════════════════════
// VISUAL IDENTITY — GHOST PRO PALETTE (insérer après inputs)
// ═══════════════════════════════════════════════════════════════
BRAND_PRIMARY   = #00D5FE   // Cyan signature GOM KOLA SIDO
BRAND_SECONDARY = #FF6B35   // Orange alertes / spikes
BRAND_ACCENT    = #FFD700   // Gold excellence / qualité premium

BULL = #00FF80              // Green électrique (BUY confirmé)
BEAR = #FF3366              // Red moderne (SELL confirmé)
WAIT = #FFB800              // Orange neutre (attente / WAIT)

BG_MAIN   = color.new(#0A0E1A, 85)   // Background principal
BG_HEADER = color.new(#1A1F2E, 60)   // Headers tables
BG_CELL   = color.new(#14172B, 80)   // Cellules alternées
BORDER    = color.new(#2E3650, 40)   // Séparateurs

TEXT_PRIMARY   = color.white             // Valeurs importantes
TEXT_SECONDARY = color.new(#B0B8D0, 0)   // Labels
TEXT_MUTED     = color.new(#6B7280, 0)   // Notes
```

---

## 9. Checklist validation

### **Avant merge**
- [ ] Palette définie et testée
- [ ] 6 tables refactorisées
- [ ] KOLA/SIDO/OB harmonisés
- [ ] Fibonacci OTE cyan (pas fuchsia)
- [ ] Spike barcolor BRAND_SECONDARY
- [ ] Flèches size.huge
- [ ] Chemin prédictif cyan/orange, width=3
- [ ] Text size hiérarchisé (3 niveaux max)
- [ ] Transparence 8 niveaux max
- [ ] Screenshot validation Boom500 + V100

### **Tests**
- [ ] Dark mode lisibilité
- [ ] Light mode (si supporté)
- [ ] Collision tables (6 positions)
- [ ] Mobile preview (petit écran)
- [ ] Limite 64 plots OK
- [ ] Limite 500 lines/200 labels OK

---

## 10. Impact performance

### **Avant (état actuel)**
- 38 plots (5 chart + 33 data_window) ✅
- ~500 lines/labels dynamiques ⚠️
- 6 tables (50+ cells) ⚠️

### **Après harmonisation**
- Aucun impact sur plots (visuels seulement)
- Aucun impact sur calculs
- **Gain potentiel:** réduction 10-15% rendering time (moins de couleurs différentes → cache GPU)

---

## 11. Recommandations finales

1. **Garder palette GHOST** (OF_BULL/OF_BEAR/OF_GOLD) — déjà cohérente et distincte
2. **Unifier verdict/spike/setup** → BULL/BEAR/WAIT systématique
3. **Chemin prédictif** → cyan/orange (signature marque, pas standard)
4. **Limiter à 3 text sizes** — éviter taille variable confuse
5. **Bordures tables** → BRAND_PRIMARY header, BORDER cells
6. **Flèches clignotantes** → size.huge (ON), size.large (OFF) — plus visible
7. **Labels chart** → max 12pt, éviter size.huge sauf alertes critiques

---

**Livrable suivant:** Patch Pine script avec palette appliquée + screenshots avant/après  
**Durée estimée:** 3-4h de refactor + 1h tests visuels  
**Risque:** Faible (changements esthétiques uniquement, logique intacte)
