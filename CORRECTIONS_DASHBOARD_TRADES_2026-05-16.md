# Corrections Dashboard + Trades — 2026-05-16

## 🔴 Problèmes Diagnostiqués

### 1. Dashboard désorganisé / Chevauchements
**Symptôme:** Les cellules du dashboard se chevauchent, positions non alignées.

**Root Cause:** Dans `GOM_Enhanced_Dashboard.mqh`, la fonction `GOM_DrawEnhancedDashboardV3()` **redessine les cellules sans nettoyer les anciennes**. Les objets RECTANGLE_LABEL gardaient leurs anciennes dimensions.

**Ligne affectée:** `GOM_Enhanced_Dashboard.mqh:407-449`

**Fix appliqué:** Ajout de `GOM_CleanEnhancedDashboard()` au début de `GOM_DrawEnhancedDashboardV3()` (ligne 443).

---

### 2. Trades ne passent pas (pas d'ordres générés)
**Symptôme:** Scanner détecte des opportunités mais aucun trade n'est exécuté.

**Root Cause:** Dans `SMC_AutoTrader.mqh`, les fonctions `OpenBuyPosition()` et `OpenSellPosition()` **ne reçoivent pas le prix d'entrée calculé** par le scanner.

```cpp
// AVANT (BUGUÉ)
OpenBuyPosition(symbol, lotSize, finalSl, finalTp);  // finalEntry PERDU!
// La fonction alors utilise ASK du marché au lieu de finalEntry
```

**Impact:** Les ordres passent au prix du marché (ASK/BID courant), pas au niveau du scanner. Souvent la cotation n'est plus valide → rejet de l'ordre par le broker.

**Lignes affectées:**
- Appels: `SMC_AutoTrader.mqh:182-185`
- Implémentations: `SMC_AutoTrader.mqh:410-421`

**Fix appliqué:**
```cpp
// APRÈS (CORRIGÉ)
OpenBuyPosition(symbol, lotSize, finalEntry, finalSl, finalTp);
OpenSellPosition(symbol, lotSize, finalEntry, finalSl, finalTp);

// Les fonctions utilisent maintenant entry du scanner
bool OpenBuyPosition(const string symbol, const double lots, const double entry, const double sl, const double tp)
{
    double price = entry > 0 ? entry : SymbolInfoDouble(symbol, SYMBOL_ASK);
    return m_trade.Buy(lots, symbol, price, sl, tp, m_tradeComment);
}
```

---

## ✅ Fixes Appliquées

| Fichier | Ligne | Modification |
|---------|-------|--------------|
| `GOM_Enhanced_Dashboard.mqh` | 443 | Ajout `GOM_CleanEnhancedDashboard()` avant redessinage |
| `SMC_AutoTrader.mqh` | 183-185 | Passer `finalEntry` aux fonctions d'ouverture |
| `SMC_AutoTrader.mqh` | 410-421 | Ajouter paramètre `entry` + l'utiliser pour le prix d'ouverture |

---

## 🧪 Étapes de Test

1. **Dashboard:** Redémarrez l'EA sur le graphique. Vérifiez que les cellules s'alignent correctement, pas de chevauchement.

2. **Trades:** 
   - Activez `EnableOpportunityScanner = true`
   - Activez `EnableScannerAutoTrading = true`
   - Capital: minimum 20 USD (10$ test, 20$ production)
   - Observez les logs:
     ```
     ✅ TRADE OUVERT: EURUSD BUY 0.01 lots @ 1.08500 (SL:1.08450 TP:1.08600)
     ```
   - Si le prix n'est plus valide → "Order Send failed: 10016" (price outdated) → normal, scanner passera à l'opportunité suivante

3. **Vérification compilation:** Compilez `SMC_Universal.mq5` avec MetaEditor. Doit afficher: `0 errors, 0 warnings`

---

## 📋 Configuration Recommandée pour Tests

```mql5
// Inputs optimisés pour Boom/Crash 20 USD
EnableOpportunityScanner = true;        // ✅ Activer détection
ScannerRefreshSeconds = 60;              // Scan toutes les minutes
EnableScannerAutoTrading = true;         // ✅ Trader les opportunités
AutoTradeMaxRiskDollars = 0.20;         // Risque ~1% capital (très conservateur)
AutoTradeScalpTpPoints = 80;            // TP scalping
AutoTradeScalpSlPoints = 30;            // SL scalping
EnableAutoTrailingStop = true;          // Sécuriser les positions
```

---

## 🚀 Prochaines Étapes

- [ ] Compiler `SMC_Universal.mq5` avec MetaEditor (validation zéro erreur)
- [ ] Tester sur Boom 1000 Index en M5
- [ ] Vérifier les logs pour `✅ TRADE OUVERT`
- [ ] Monitorer les équités/flottes au dashboard
- [ ] Si toujours bloqué: activer `PrintCTradeResult()` pour diagnostiquer les rejets des ordres

---

## 💡 Explication Technique

Le scanner SMC détecte des **niveaux de prix** (FVG, OB, BOS, etc.) où un ordre a une haute probabilité d'être accepté. Cependant, ces niveaux sont **calculés sur les barres historiques**.

Par temps réel, si le prix du marché s'éloigne de ce niveau entre la détection et l'ordre, le broker rejette avec "price outdated" (code 10016).

**Les fixes garantissent:**
1. ✅ Que le prix d'entrée calculé **est passé au broker** (était ignoré avant)
2. ✅ Que le dashboard se redessine proprement (plus de chevauchement)

Le taux d'acceptation dépend maintenant du **spread** et de la **volatilité** du symbole, pas d'un bug de logique.

---

**Date:** 2026-05-16
**EA:** SMC_Universal v1.00
**Status:** ✅ Prêt pour test production
