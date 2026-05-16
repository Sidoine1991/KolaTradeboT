# ⚡ DÉMARRAGE RAPIDE - SCANNER EN 5 MINUTES

## 🎯 Pour les Pressés

### Étape 1: Compiler (30 secondes)
1. **F4** dans MT5 → ouvre MetaEditor
2. Ouvrir **SMC_Universal.mq5**
3. **F7** pour compiler
4. Vérifier: `0 errors` ✅

### Étape 2: Setup (2 minutes)
1. Ouvrir 2 graphiques:
   - **Boom 1000 Index**
   - **Crash 1000 Index**

2. Glisser **SMC_Universal** sur les 2 graphiques

3. Sur le graphique **Crash 1000**:
   - Cliquer droit sur l'icône du robot → **Propriétés**
   - Trouver section **SCANNER MULTI-SYMBOLES**
   - Mettre:
     ```
     EnableOpportunityScanner = true
     ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index"
     ```
   - Cliquer **OK**

### Étape 3: Vérifier (30 secondes)
Après 5 secondes, vous devriez voir en haut du graphique Crash 1000:

```
┌──────────────────────────────────────────────────────┐
│ 🔶 SCANNER OPPORTUNITÉS TEMPS RÉEL   14:30:45       │
├──────────────────────────────────────────────────────┤
│ Boom 1000 Index   BUY   PERFECT  2845.32  72%  5p   │
│ Crash 1000 Index  SELL  GOOD     1523.78  45%  8p   │
└──────────────────────────────────────────────────────┘
```

## ✅ C'est Tout!

Vous avez maintenant un scanner en temps réel qui surveille Boom et Crash.

## 🚀 Pour Aller Plus Loin

### Ajouter Plus de Symboles
1. Ouvrir un graphique par symbole (max 10)
2. Attacher le robot sur chaque graphique
3. Dans le graphique avec le scanner, modifier:
   ```
   ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,EURUSD,GBPUSD"
   ```

### Personnaliser l'Affichage
```mql5
ScannerPanelX = 10        // Position horizontale
ScannerPanelY = 30        // Position verticale
ScannerPanelWidth = 500   // Largeur
ScannerRefreshSeconds = 2 // Vitesse d'actualisation
```

## 📖 Documentation Complète

Pour en savoir plus:
- **SCANNER_INSTALLATION.md** - Guide d'installation détaillé
- **SCANNER_OPPORTUNITES_README.md** - Toutes les fonctionnalités
- **SCANNER_VISUAL_GUIDE.md** - Comment lire le panneau

## ⚠️ Problèmes Courants

### Le panneau n'apparaît pas
→ Vérifier: `EnableOpportunityScanner = true`

### Pas d'opportunités affichées
→ Attendre 1-2 minutes que les données se mettent à jour

### Erreur de compilation
→ Vérifier que `SMC_OpportunityScanner.mqh` est dans le dossier MT5

## 💡 Astuce Pro

**Un seul graphique a besoin du scanner activé.**

Les autres graphiques publient les données, et le graphique avec le scanner les affiche toutes.

---

**C'est parti!** 🎊
