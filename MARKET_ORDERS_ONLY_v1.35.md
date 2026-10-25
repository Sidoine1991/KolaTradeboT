# Configuration v1.35 - Ordres Marché Uniquement

## Demande utilisateur
```
"Je ne veux plus d'ordre limit, execute les ordre au marché, 
support/resistance 20 bars, Engulfing, dow line, SMC_DISP_TRAIL line, GOM_TF_TL"
```

## Modifications appliquées (v1.35)

### 1. Désactivation complète des ordres LIMIT

| Paramètre | Ancien | Nouveau | Effet |
|-----------|--------|---------|--------|
| `UseSR20BarLimits` | true | **false** | Pas d'ordres LIMIT sur S/R 20 bars |
| `UseDispFVGTrailLimits` | true | **false** | Pas d'ordres LIMIT sur FVG trail |
| `PatternDashedPreferLimit` | true | **false** | Préfère marché aux lignes Pattern |
| `PreferLimitOverMarket` | true | **false** | Préfère toujours le marché |
| `GOMAlignPreferLimit` | true | **false** | Préfère marché pour GOM alignment |
| `GOMAlignMarketFallback` | false | **true** | Repli marché si aucune limite |

**Résultat**: Zéro ordre LIMIT. Toutes les entrées se font au prix marché courant.

### 2. Activation des conditions d'entrée MARCHÉ

| Condition | Flag | Status | Entrées activées |
|-----------|------|--------|------------------|
| **Support/Resistance 20 bars** | `UseSR20BarLimits` | Active | Détection S/R, exécution marché |
| **Engulfing** | `EngulfRetestEnable` | ✅ true | Entrée retest Engulfing + market |
| **Dow line** | `UseDowEpTouchMarket` | ✅ true | Marché au toucher trendline DOW |
| **SMC_DISP_TRAIL line** | `UseDispFVGTrail` | ✅ true | Détection + filtrage DISP FVG |
|   | `UseScalpTlContactEntry` | ✅ true | Marché au contact DISP trail |
| **GOM_TF_TL** | `UseGOMTFAlignmentEntry` | ✅ true | Marché si GOM + tous TF alignés |
|   | `UseScalpTlContactEntry` | ✅ true | Marché au contact TF trendline |

### 3. Conditions d'entrée actives (par signal)

1. **Support/Resistance 20 bars**
   - Détecte les zones S/R sur dernier 20 bars
   - Exécute marché quand prix rebondit en zone
   - GOM alignement requis (GOOD min)

2. **Engulfing Pattern**
   - Détecte pattern engulfing M1
   - Exécute marché au retest du niveau
   - Confirmation GOM + M1 bar flip

3. **Dow Trendline**
   - Détecte trendlines DOW
   - Exécute marché au toucher zone EP
   - H1/M5 alignement préféré

4. **SMC_DISP_TRAIL Line**
   - Trace ligne bords FVG (DISP gap)
   - Exécute marché au contact trail
   - GOM + TF confirmation

5. **GOM_TF_TL (Timeframe Trendline)**
   - GOM verdict: BUY/SELL sur tous les TF
   - Entrée marché automatique
   - H1/M5 alignés + direction confirmée

---

## Vérification en live

### Dashboard
L'EA affichera automatiquement:
```
VOL SL=4.5×ATR TP=5.0×ATR Cap=$5.0
```

### Signaux d'entrée attendus
1. 🟢 **SR20** - Rebond détecté en zone support/résistance 20 bars → MARKET BUY/SELL
2. 🟢 **ENG** - Pattern engulfing M1 + retest → MARKET
3. 🟢 **DOW** - Toucher trendline DOW EP → MARKET
4. 🟢 **DISP** - Contact ligne DISP FVG trail → MARKET
5. 🟢 **GOM_TF** - Alignement complet GOM + tous TF → MARKET

### Validation rapide
- Attendre un setup GOM GOOD/PERFECT
- Observer le déclenchement d'un ordre marché (PAS de LIMIT en attente)
- Vérifier SL affichée = ~4.5 ATR (nouvelle largeur v1.34)

---

## Notes

### Sécurité du capital
- Sniper Risk Cap reste actif → max $5.00 par trade
- Daily Capital Manager reste actif → limites journalières respectées
- Ordres marché se déclenchent immédiatement → exécution garantie

### Temps d'entrée
- **Ordres marché** = déclenchement instant (pas de décalage)
- Peut être avantageux sur spikes volatilité (Boom/FxVOL)
- Peut générer plus de glissement (slippage) si spread large

### Conditions cumulatives
Plusieurs conditions peuvent converger = signal PLUS fort:
- SR20 + DOW + GOM alignment = priorité absolue
- FVG trail + Engulfing = high confidence
- Isolé (ex: SR20 seul) = OK si GOM GOOD min

---

**Version**: 1.35  
**Date**: 2026-09-01  
**Changement majeur**: Zéro ordres LIMIT, marché uniquement  
**Entrées actives**: S/R 20 bars, Engulfing, Dow, SMC_DISP_TRAIL, GOM_TF_TL
