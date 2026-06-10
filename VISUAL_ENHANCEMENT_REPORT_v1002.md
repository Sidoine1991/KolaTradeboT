# 📊 RAPPORT D'AMÉLIORATION VISUELLE — DerivEAPro v10.02

**Date:** 2026-06-07  
**Version:** v10.02  
**Statut:** ✅ Prêt pour intégration  

---

## 🎯 OBJECTIF

Transformer `deriveapro.mq5` en un **dashboard professionnel de trading** avec un **Money Management Flow** visuel qui guide le trader en temps réel, similaire au setup KMMTradeHUB montré dans l'image de référence.

---

## 🎨 NOUVELLES FONCTIONNALITÉS VISUELLES

### 1. **COMPASS CIRCULAIRE GHOST** (8 directions)
- **Affichage:** Cercle avec 8 segments (→ ↗ ↑ ↖ ← ↙ ↓ ↘)
- **Indicateur:** Segment actif surligné en jaune (fontSize 12)
- **Centre:** Point dynamique (⬤ ● ◉ ○) selon la force du signal
- **Position:** Top-left panel (InpGhostPanelX, InpGhostPanelY)
- **Couleur:** Vert (BUY), Rouge (SELL), Or (WAIT)

### 2. **HEATMAP DOM EMPILÉE** (barres rouge/vert)
- **10 niveaux de pression** (support/résistance)
- **Barres horizontales** sur le chart avec intensité graduelle
- **Labels:** "BUY 75%" ou "SELL 60%" avec force en %
- **Tri:** Du niveau le plus haut au plus bas
- **Mise à jour:** Toutes les 5min (pivots Highs/Lows)

### 3. **MONEY MANAGEMENT FLOW** (guide 6 étapes)
- **Position:** Coin inférieur droit
- **Étapes:**
  1. ① Capital : $X + Risk 2% = $Y
  2. ② SL : 1.5× ATR = N pips (distance affichée)
  3. ③ Lot Size : fixe ou MIN broker
  4. ④ TP : 2.5× ATR = N pips + R:R = 1:X.XX
  5. ⑤ Résultat potentiel : Loss -$X | Win +$Y
  6. ⑥ Validation : ✓ SETUP VALIDE ou ✗ INVALIDE
- **Rappel des règles MM** (2% max, R:R≥1.5, daily stop)
- **Alerte visuelle** si R:R < 1.5

### 4. **DELTA BARS AMÉLIORÉES** (histogramme vertical)
- **Affichage:** 20 barres empilées (blocs Unicode █)
- **Couleurs:** Vert = pression achat, Rouge = pression vente
- **Hauteur:** Proportionnelle au delta (normalisé)
- **Ligne zéro:** Trait horizontal (━━━) en gris

### 5. **CVD GRAPH MINI** (profil cumulatif)
- **40 points CVD** affichés en graphique ligne
- **Couleur gradient:** Vert si CVD≥0, Rouge si CVD<0
- **Normalisation:** Min/Max des 40 dernières valeurs
- **Label:** "CVD: +X.XX" au-dessus du graph

---

## 📝 NOUVELLES INPUTS PARAMÉTRABLES

```cpp
input bool   InpShowGhostPanel       = true;   // Afficher panel GHOST
input bool   InpShowDeltaBars        = true;   // Afficher barres delta
input bool   InpShowCVDLine          = true;   // Afficher graphique CVD
input bool   InpShowHeatmap          = true;   // Afficher heatmap DOM
input int    InpDeltaBarsCount       = 20;     // Nombre de barres delta (10-40)
input int    InpGhostPanelX          = 10;     // Position X panel GHOST
input int    InpGhostPanelY          = 200;    // Position Y panel GHOST
```

---

## 🔧 MODIFICATIONS DE STRUCTURE

### SGhost (structure améliorée)
```cpp
struct SGhost {
   string verdict;      // BUY/SELL/WAIT
   double quality;      // 0-100
   double delta;        // Delta moyen
   double cvd;          // Cumulative Volume Delta
   double buypct;       // % pression achat (0-100)
   double sellpct;      // % pression vente (0-100)
   int compass;         // Octant 0-7 (E=0, NE=1, N=2, NW=3, W=4, SW=5, S=6, SE=7)
   bool valid;          // Données valides
   ulong loadedAt;      // Timestamp dernière maj
   
   // ── NOUVEAUX CHAMPS ────────────────────────────────────────
   double deltaHistory[60];  // Historique delta pour CVD chart
   int deltaCount;           // Nombre d'entrées dans deltaHistory
};
```

### Variables heatmap DOM
```cpp
double g_heatmapLevels[10];      // Prix des niveaux (pivots)
double g_heatmapStrength[10];    // Force 0.0-1.0
bool g_heatmapIsBuy[10];         // true=support, false=résistance
int g_heatmapCount = 0;          // Nombre de niveaux actifs
datetime g_lastHeatmapUpdate = 0;// Dernière mise à jour (5min)
```

---

## 🚀 FONCTIONS AJOUTÉES

### 1. `DrawCompassCircular(int px, int py)`
Dessine le compass circulaire GHOST avec 8 directions et point central dynamique.

### 2. `DrawHeatmapStacked(int px, int py, int width, int height)`
Affiche les 10 niveaux de pression DOM en barres empilées rouge/vert sur le chart.

### 3. `DrawMoneyManagementFlow(int px, int py)`
Affiche le guide MM Flow 6 étapes + validation + règles + alertes (coin inf. droit).

### 4. `DrawDeltaBarsImproved(int px, int py, int width, int height)`
Histogramme vertical des 20 dernières barres delta (normalisé, coloré).

### 5. `DrawCVDGraph(int px, int py, int width, int height)`
Graphique ligne CVD des 40 derniers points (gradient vert/rouge).

### 6. `UpdateHeatmap()`
Calcule les niveaux de pression DOM à partir des pivots Highs/Lows sur 50 barres.

### 7. `DrawGhostPanel()` — **REMPLACE LA VERSION EXISTANTE**
Intègre toutes les visualisations GHOST dans un panel unique top-left.

---

## 📋 INTÉGRATION DANS `DrawChartIndicators()`

**Ajouter cet appel à la fin de la fonction `DrawChartIndicators()`:**

```cpp
// ── MONEY MANAGEMENT FLOW (coin inférieur droit) ─────────────
int screenHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
DrawMoneyManagementFlow(InpDashPanelWidth - 320, screenHeight - 300);
```

**Position:**
- Après l'affichage du panel dashboard principal (côté droit)
- Juste avant le `return;` final de la fonction

---

## ✅ CHECKLIST D'INTÉGRATION

### Phase 1 : Préparation
- [x] Compilation baseline réussie (0 erreurs, 5.4s)
- [x] Patch visuel créé (`deriveapro_visual_patch.txt`)
- [x] Nouvelle structure `SGhost` documentée
- [x] 7 nouvelles inputs définies

### Phase 2 : Intégration manuelle
- [ ] Ajouter les 7 nouvelles inputs en tête de fichier
- [ ] Modifier la structure `SGhost` (lignes ~120-135)
- [ ] Déclarer les variables heatmap DOM (lignes ~150-155)
- [ ] Copier les 7 nouvelles fonctions depuis le patch
  - [ ] `DrawCompassCircular()`
  - [ ] `DrawHeatmapStacked()`
  - [ ] `DrawMoneyManagementFlow()`
  - [ ] `DrawDeltaBarsImproved()`
  - [ ] `DrawCVDGraph()`
  - [ ] `UpdateHeatmap()`
  - [ ] **Remplacer** `DrawGhostPanel()` existante
- [ ] Ajouter l'appel `DrawMoneyManagementFlow()` dans `DrawChartIndicators()`
- [ ] Ajouter l'appel `UpdateHeatmap()` dans `OnTick()` (conditions: 5min elapsed)

### Phase 3 : Compilation & Test
- [ ] Compiler `deriveapro.mq5` → vérifier 0 erreurs
- [ ] Attacher à Boom500 M1 chart
- [ ] Vérifier affichage :
  - [ ] Compass circulaire GHOST (top-left)
  - [ ] Delta bars (sous compass)
  - [ ] CVD graph (sous delta bars)
  - [ ] Heatmap DOM (sur chart, lignes horizontales)
  - [ ] Money Management Flow (bottom-right)
- [ ] Tester la mise à jour temps réel des valeurs
- [ ] Vérifier que les inputs `InpShow*` activent/désactivent les éléments

### Phase 4 : Ajustements finaux
- [ ] Positionner les éléments sans chevauchement
- [ ] Ajuster les couleurs pour contraste optimal
- [ ] Valider la lisibilité sur fond noir (chart dark mode)
- [ ] Vérifier la performance (CPU<5% avec tous visuels actifs)

---

## 🎯 RÉSULTATS ATTENDUS

### Avant
- Dashboard basique avec indicateurs standards
- Pas de visualisation du flux de gestion de capital
- Trader doit calculer manuellement SL/TP/Lot/R:R

### Après (v10.02)
- **Dashboard professionnel** similaire à KMMTradeHUB
- **Money Management Flow** guide le trader étape par étape
- **GHOST Compass** indique la direction du marché (8 octants)
- **Heatmap DOM** montre les zones de pression support/résistance
- **Delta bars + CVD** visualisent le flux d'ordres en temps réel
- **Validation automatique** du setup (✓/✗) avant l'entrée

---

## 📊 LAYOUT FINAL

```
┌─────────────────────────────────────────────────────────────────┐
│ TOP-LEFT:                            TOP-RIGHT:                │
│ ┌──────────────────┐                 ┌──────────────────┐     │
│ │ ▣ GHOST OrderFlow│                 │ MAIN DASHBOARD   │     │
│ │ Compass (8 dir.) │                 │ Symbol | TF | SR │     │
│ │   ↗ → ↘ N ↙      │                 │ ATR | BB | SMC   │     │
│ │   ↑  ●  ↓        │                 │ Positions | CM   │     │
│ │   ↖ ← ↙          │                 └──────────────────┘     │
│ │ Delta: +0.25     │                                           │
│ │ CVD: +12.50      │                                           │
│ │ Delta Bars:      │                                           │
│ │ ▁▃█▅▃▂█▅█▃       │                                           │
│ │ CVD Graph:       │                                           │
│ │ ●●●●●●●●●●       │                                           │
│ │ Heatmap DOM:     │                                           │
│ │ 10 levels        │                                           │
│ └──────────────────┘                                           │
│                                                                 │
│                     CHART AREA                                  │
│           (heatmap levels drawn as OBJ_HLINE)                  │
│                                                                 │
│                                          BOTTOM-RIGHT:          │
│                                          ┌──────────────────┐  │
│                                          │ ═ MM FLOW ══════ │  │
│                                          │ ① Capital: $1000 │  │
│                                          │    Risk: 2%=$20  │  │
│                                          │ ② SL: 1.5×ATR    │  │
│                                          │ ③ Lot: 0.50      │  │
│                                          │ ④ TP: 2.5×ATR    │  │
│                                          │    R:R = 1:1.67  │  │
│                                          │ ⑤ Win: +$33.40   │  │
│                                          │    Loss: -$20.00 │  │
│                                          │ ⑥ ✓ VALIDE       │  │
│                                          │ ─ Règles ─────── │  │
│                                          │ • Max 2% risk    │  │
│                                          │ • Min R:R 1:1.5  │  │
│                                          │ • Daily stop 5%  │  │
│                                          └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎨 CARACTÈRES UNICODE UTILISÉS

| Symbole | Nom | Usage |
|---------|-----|-------|
| ▣ | Square with fill | Titre panel GHOST |
| → ↗ ↑ ↖ ← ↙ ↓ ↘ | Flèches directionnelles | Compass 8 directions |
| ⬤ ● ◉ ○ | Cercles | Point central (force) |
| █ ▅ ▃ ▁ | Blocs verticaux | Delta bars |
| ━ | Trait horizontal | Ligne zéro |
| ① ② ③ ④ ⑤ ⑥ | Nombres cerclés | Étapes MM Flow |
| ✓ ✗ | Check/Cross | Validation setup |
| ═ ─ | Lignes décoratives | Séparateurs |
| ⚠ | Warning | Alerte R:R insuffisant |

---

## 🔍 POINTS D'ATTENTION

### 1. **Performance**
- `UpdateHeatmap()` : max 1 fois par 5min (éviter calculs répétés)
- `DrawGhostPanel()` : activer/désactiver via `InpShowGhostPanel`
- Utiliser `ObjLabelTL()` avec cache des noms d'objets (pas de création répétée)

### 2. **Compatibilité**
- Fonctionne sur **Boom/Crash uniquement** (indices synthétiques Deriv)
- Chart M1 recommandé (plus de points pour heatmap)
- Résolution écran ≥ 1920×1080 pour affichage complet

### 3. **Personnalisation**
- Toutes les positions X/Y sont paramétrables via inputs
- Couleurs modifiables dans chaque fonction `Draw*()`
- Nombre de barres delta : `InpDeltaBarsCount` (10-40)

---

## 📄 FICHIERS LIVRÉS

1. **`deriveapro_visual_patch.txt`**  
   Contient les 7 fonctions prêtes à copier-coller.

2. **`VISUAL_ENHANCEMENT_REPORT_v1002.md`** (ce fichier)  
   Documentation complète de l'intégration.

3. **`deriveapro.mq5`** (version actuelle)  
   Base compilée avec succès (v10.01), prête pour modification.

---

## 🎯 PROCHAINES ÉTAPES

1. **Intégration manuelle** du patch dans `deriveapro.mq5`
2. **Compilation** → vérifier 0 erreurs
3. **Test visuel** sur Boom500 M1 chart
4. **Ajustements** de position/couleurs selon préférence
5. **Validation finale** → screenshot du dashboard complet

---

## 📌 NOTES DE VERSION

**v10.02 — Visual Enhancement**
- ✅ Compass circulaire GHOST (8 directions)
- ✅ Heatmap DOM empilée (10 niveaux)
- ✅ Money Management Flow (6 étapes)
- ✅ Delta bars améliorées (histogramme)
- ✅ CVD graph mini (40 points)
- ✅ 7 nouvelles inputs paramétrables
- ✅ Structure `SGhost` étendue (`deltaHistory[60]`)
- ✅ Helper `ObjLabelTL()` pour top-left labels

**Compilation baseline:**
- 0 erreurs
- 0 warnings
- 5.4s elapsed
- Binary: 147KB
- Architecture: X64 Regular

---

**Date de création:** 2026-06-07 04:15 UTC  
**Status:** ✅ Prêt pour intégration  
**Maintenance:** Vérifier performance CPU après intégration (<5% recommandé)

---

_Guidé par l'image KMMTradeHUB — Dashboard professionnel pour traders exigeants._
