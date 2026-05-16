# 📊 GUIDE VISUEL DU SCANNER

## 🎨 Apparence du Panneau

```
╔════════════════════════════════════════════════════════════════════════╗
║  🔶 SCANNER OPPORTUNITÉS TEMPS RÉEL            2026-05-14 12:30:45    ║
╠════════════════════════════════════════════════════════════════════════╣
║ SYMBOLE          DIR    QUALITÉ   ENTRÉE     SPIKE  DIST   NIVEAUX    ║
╠════════════════════════════════════════════════════════════════════════╣
║ Boom 1000 Index  BUY    PERFECT   2845.32    72%    15p    M5 BUY     ║
║ Crash 1000 Index SELL   GOOD      1523.78    45%    8p     M5 SELL    ║
║ Volatility 75    BUY    FAIR      12.456     28%    35p    H1 BUY     ║
║ EURUSD           SELL   GOOD      1.0842     51%    12p    M5 SELL,H1 ║
║ GBPUSD           BUY    PERFECT   1.2654     68%    5p     M5 BUY     ║
╚════════════════════════════════════════════════════════════════════════╝
```

## 🎨 Codes Couleurs

### Direction
- **BUY** → 🟢 Vert lime (clrLimeGreen)
- **SELL** → 🔴 Rouge (clrRed)
- **WAIT** → ⚫ Gris (clrGray)

### Qualité
- **PERFECT** → 🟡 Or (clrGold) - Setup optimal, tous les critères alignés
- **GOOD** → 🟢 Vert lime (clrLimeGreen) - Setup solide, haute probabilité
- **FAIR** → 🟠 Orange (clrOrange) - Setup acceptable, confirmation requise

### Probabilité Spike
- **≥ 45%** → 🔴 Rouge vif - Spike imminent très probable
- **30-44%** → 🟠 Orange - Spike possible
- **< 30%** → ⚫ Gris - Faible probabilité

## 📊 Colonnes Expliquées

### SYMBOLE
Le nom exact du symbole MT5 (ex: "Boom 1000 Index", "EURUSD")

### DIR (Direction)
La direction du trade recommandée:
- **BUY** : Acheter (long)
- **SELL** : Vendre (short)
- **WAIT** : Attendre (pas d'opportunité)

### QUALITÉ
Le niveau de qualité du setup:
- **PERFECT** : 
  - Force du signal ≥ 3.6
  - Qualité des filtres ≥ 80%
  - Confluence niveaux KOLA
  - Volume confirmé
  - Structure alignée MTF

- **GOOD** :
  - Force du signal ≥ 2.8
  - Qualité des filtres ≥ 60%
  - Majorité des confirmations

- **FAIR** :
  - Setup acceptable
  - Quelques confirmations
  - Risque modéré

### ENTRÉE
Le prix d'entrée exact recommandé par GOM (niveaux KOLA M5/M15/H1)

### SPIKE %
La probabilité de spike détectée:
- Calculée sur M1 (lookback 20 barres)
- ≥45% → Alerte sonore + notification
- ≥40% → Bypass mode strict activé
- ≥35% → Clignotement indicateur

### DIST (Distance)
Distance actuelle du prix au niveau d'entrée recommandé:
- **< 10 points** → 🟢 Très proche, prêt à entrer
- **10-30 points** → 🟡 Proche, surveiller
- **> 30 points** → 🔴 Éloigné, attendre

### NIVEAUX
Les niveaux KOLA proches du prix actuel:
- **M5 BUY/SELL** : Niveaux M5 (scalping)
- **H1 BUY/SELL** : Niveaux H1 (swing)
- **M15, M30, H4, D1** : Autres timeframes si pertinents
- Plusieurs niveaux = confluence = meilleure opportunité

## 🎯 Exemples Concrets

### ✅ Opportunité Parfaite
```
Boom 1000 Index  BUY  PERFECT  2845.32  72%  5p  M5 BUY, H1 BUY
```
**Interprétation:**
- Setup parfait sur Boom 1000
- Direction BUY (acheter)
- Qualité PERFECT (or)
- Entrée à 2845.32
- Spike imminent 72% (rouge vif)
- Prix à seulement 5 points de l'entrée
- Confluence M5 + H1 (très forte)

**Action:** Entrer immédiatement au marché ou placer un BuyLimit à 2845.32

---

### ⚠️ Opportunité Moyenne
```
EURUSD  SELL  FAIR  1.0842  28%  35p  -
```
**Interprétation:**
- Setup acceptable sur EURUSD
- Direction SELL (vendre)
- Qualité FAIR (orange)
- Entrée à 1.0842
- Faible probabilité spike (28%)
- Prix à 35 points de l'entrée (éloigné)
- Aucun niveau proche

**Action:** Attendre que le prix se rapproche de 1.0842 et surveiller les confirmations

---

### 🚫 Pas d'Action
```
GBPUSD  WAIT  WAIT  0.0000  0%  0p  -
```
**Interprétation:**
- Aucun setup valide
- Attendre

**Action:** Surveiller, ne pas trader

## 📍 Position et Taille du Panneau

### Position par défaut
- **X:** 10 pixels depuis la gauche
- **Y:** 30 pixels depuis le haut
- **Largeur:** 500 pixels
- **Hauteur:** Ajustée automatiquement (max 15 lignes)

### Personnalisation
```mql5
ScannerPanelX = 10        // Déplacer vers la droite →
ScannerPanelY = 30        // Déplacer vers le bas ↓
ScannerPanelWidth = 520   // Élargir le panneau
ScannerRowHeight = 25     // Hauteur des lignes
```

## 🔄 Actualisation

### Fréquence
- Par défaut: **toutes les 2 secondes**
- Configurable: `ScannerRefreshSeconds`
- Timestamp affiché en haut à droite

### Tri Automatique
Les opportunités sont triées par:
1. **Qualité** (PERFECT → GOOD → FAIR)
2. **Probabilité spike** (plus élevée en premier)
3. **Distance à l'entrée** (plus proche en premier)

### Filtrage
- Seules les opportunités **valides** sont affichées
- Les symboles en WAIT ne sont **pas affichés**
- Maximum **15 lignes** visibles (les meilleures)

## 🎮 Interaction

### Navigation
- **Défilement** : Le panneau reste fixe en haut
- **Zoom** : Le panneau garde sa taille
- **Multi-graphiques** : Un seul panneau pour tous les symboles

### Lecture Rapide
1. **Regarder les couleurs** : Or = priorité absolue
2. **Vérifier SPIKE %** : Rouge (≥45%) = urgence
3. **Contrôler DIST** : < 10p = prêt à entrer
4. **Confirmer NIVEAUX** : Confluence = meilleure probabilité

## 💡 Astuces Visuelles

### Repérer les Meilleures Opportunités
```
🟡 PERFECT + 🔴 ≥45% + 🟢 <10p + 🟡 Confluence = ⭐ Setup optimal
```

### Ordre de Priorité
1. **Ligne 1** (en haut) = Meilleure opportunité
2. **Ligne 2-5** = Bonnes opportunités
3. **Ligne 6-15** = Opportunités secondaires

### Surveillance Active
- **Nouvelle ligne apparaît** → Nouveau setup détecté
- **Couleur change** → Qualité améliorée/dégradée
- **DIST diminue** → Prix approche du niveau
- **SPIKE % augmente** → Urgence croissante

## 🖥️ Exemples d'Écran

### Vue Normale (3-5 opportunités)
```
╔════════════════════════════════════════════════════════════════════════╗
║  🔶 SCANNER OPPORTUNITÉS TEMPS RÉEL            2026-05-14 12:30:45    ║
╠════════════════════════════════════════════════════════════════════════╣
║ Boom 1000 Index  BUY    PERFECT   2845.32    72%    5p     M5 BUY     ║
║ Crash 1000 Index SELL   GOOD      1523.78    45%    8p     M5 SELL    ║
║ GBPUSD           BUY    PERFECT   1.2654     68%    12p    M5 BUY, H1 ║
╚════════════════════════════════════════════════════════════════════════╝
```

### Vue Chargée (10+ opportunités)
```
╔════════════════════════════════════════════════════════════════════════╗
║  🔶 SCANNER OPPORTUNITÉS TEMPS RÉEL            2026-05-14 12:30:45    ║
╠════════════════════════════════════════════════════════════════════════╣
║ Boom 1000        BUY    PERFECT   2845.32    72%    5p     M5,H1 BUY  ║
║ GBPUSD           BUY    PERFECT   1.2654     68%    12p    M5 BUY     ║
║ Crash 1000       SELL   GOOD      1523.78    52%    8p     M5 SELL    ║
║ EURUSD           SELL   GOOD      1.0842     48%    15p    M5,H1 SELL ║
║ Volatility 75    BUY    GOOD      12.456     42%    20p    H1 BUY     ║
║ XAUUSD           SELL   FAIR      2045.32    35%    25p    M15 SELL   ║
║ Step Index       BUY    FAIR      156.78     30%    30p    M5 BUY     ║
║ Volatility 100   SELL   FAIR      45.678     28%    35p    -          ║
║ ... (15 max)                                                           ║
╚════════════════════════════════════════════════════════════════════════╝
```

### Vue Vide (aucune opportunité)
```
╔════════════════════════════════════════════════════════════════════════╗
║  🔶 SCANNER OPPORTUNITÉS TEMPS RÉEL            2026-05-14 12:30:45    ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║           Aucune opportunité détectée pour le moment...               ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
```

## 🎓 Apprentissage Rapide

### Débutant (1 semaine)
1. Regarder seulement les lignes **PERFECT** (or)
2. Attendre SPIKE % ≥ 60% (rouge vif)
3. Entrer quand DIST < 10p
4. Ignorer le reste

### Intermédiaire (1 mois)
1. Trader les **PERFECT** et **GOOD**
2. SPIKE % ≥ 45%
3. Vérifier la confluence (M5+H1)
4. Gérer plusieurs symboles

### Avancé (3 mois+)
1. Arbitrer entre tous les setups
2. Prioriser selon contexte global
3. Anticiper les mouvements
4. Optimiser les entrées/sorties

---

**Conseil:** Imprimez ce guide et gardez-le près de votre écran pour les premières semaines!
