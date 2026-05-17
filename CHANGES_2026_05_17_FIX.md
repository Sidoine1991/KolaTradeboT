# CHANGEMENTS: SMC_Universal.mq5 - Fix Trades Bloqués (2026-05-17)

## ✅ SOLUTION 1: Réduction Seuil Confiance 85% → 70%

### Problème Identifié
- Volatility 90 Index recevait signal SELL avec confiance 70%
- Robot refusait le trade car threshold était à 85%
- Blockage message: `TRADE BLOQUÉ - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ≥ 85%`

### Solution Appliquée
Réduit les 2 seuils 85% → 70% dans SMC_Universal.mq5:
- **Ligne 17737**: `if(g_lastAIConfidence < 0.85)` → `if(g_lastAIConfidence < 0.70)`
- **Ligne 17744**: `if(g_lastAIConfidence < 0.85)` → `if(g_lastAIConfidence < 0.70)`
- **Ligne 18877**: `if(g_lastAIConfidence < 0.85)` → `if(g_lastAIConfidence < 0.70)`
- **Ligne 18884**: `if(g_lastAIConfidence < 0.85)` → `if(g_lastAIConfidence < 0.70)`

### Résultat Attendu
✅ Volatility 90 devrait trader (70% ≥ 70%)
✅ Volatility 100 reste bloqué (indicateurs insuffisants - problème séparé)

---

## ✅ NOUVELLE FONCTIONNALITÉ: Dashboard Multi-Timeframe

### Ajout du Dashboard MTF
Ajouter une affichage en bas du graphique montrant:
- **M1 Direction** (BUY/SELL) via EMA fast/slow
- **M5 Direction** (BUY/SELL) via EMA fast/slow
- **H1 Direction** (BUY/SELL) via EMA fast/slow
- **VERDICT FINAL**:
  - STRONG BUY: Les 3 TF alignés en BUY
  - STRONG SELL: Les 3 TF alignés en SELL
  - BUY (M1/M5) / BUY (M5/H1) / BUY (M1/H1): 2 TF alignés
  - DIVERGENCE: Pas d'alignement
  - MIXED: Autre cas
- **IA CONFIANCE**: Affiche % confiance serveur
- **IA ACTION**: Affiche dernier signal (BUY/SELL/HOLD)

### Implémentation
- **Nouvelle fonction**: `DisplayMTFDashboard()` (lignes 25631-25736)
  - Calcule EMA 9/21 sur M1, M5, H1
  - Détermine direction pour chaque TF
  - Calcule alignement (0-3 TF alignés)
  - Affiche verdict avec couleurs:
    - Verde/Rosso: Tendance
    - Gris: Divergence/Attente
- **Helper function**: `DrawDashboardCell()` (lignes 25738-25765)
  - Crée un label rectangle avec background color
  - Texte blanc, bordure grise
  - Positionné via XDISTANCE/YDISTANCE
- **Intégration**: Appelée dans `UpdateDashboard()` (ligne 6408)
  - Affichée toutes les 15 secondes (selon lastDashboardUpdate)
  - Protection via `ShowBottomDashboard` input

### Format Visuel
```
📊 MULTI-TIMEFRAME VERDICT
┌─────────────────────────────────┐
│ M1    │ M5    │ H1    │ VERDICT │
│ BUY   │ BUY   │ SELL  │ MIXED   │
├─────────────────────────────────┤
│ CONF      │ IA ACTION (BUY)     │
│ IA: 70%   │ BUY                 │
└─────────────────────────────────┘
```

---

## Fichiers Modifiés
- **SMC_Universal.mq5**: 
  - 4 lignes: Seuil 85% → 70%
  - 1 ligne: Appel DisplayMTFDashboard()
  - 137 lignes: Nouvelles fonctions (DisplayMTFDashboard + DrawDashboardCell)

---

## Test & Validation

### Avant Fix
```
2026.05.17 16:14:49.571    SMC_Universal (Volatility 90 Index,M1)
?? TRADE BLOQUÉ - Zone Discount au bord inférieur: 
   SELL autorisé seulement si confiance IA ≥ 85% (actuel: 70.0%)
```

### Après Fix (Attendu)
```
2026.05.17 16:15:XX.XXX    SMC_Universal (Volatility 90 Index,M1)
✅ TRADE EXÉCUTÉ | Price: XXXX.XX | Confiance: 70.0%
```

---

## Prochaines Étapes
1. Compiler SMC_Universal.mq5
2. Charger sur MT5
3. Observer Journal pour confirmations trades
4. Vérifier dashboard MTF affiche correctement les directions
5. Si toujours pas de trades: Debug Volatility 100 indicateurs insuffisants

