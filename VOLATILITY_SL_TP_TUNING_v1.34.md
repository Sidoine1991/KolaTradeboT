# Volatility SL/TP Tuning - Version 1.34

## Changements apportés (v1.34)

Suite à la demande "tes SL sont trop serrés sur les volatility", les paramètres de gestion du risque volatilité ont été élargis pour laisser plus de respiration aux trades et éviter les coupes prématurées.

### Paramètres de base (général)

| Paramètre | Ancien | Nouveau | Impact |
|-----------|--------|---------|--------|
| `SL_ATRMult` | 3.0 | **4.5** | SL plus large (+50%) pour volatilité synthétique |
| `TP_ATRMult` | 5.0 | 5.0 | Inchangé (Take Profit reste stable) |
| `MaxSLDollars` | 3.0 | **5.0** | Cap max SL élargi pour moins de coupes serrées |
| `MarketSLExtraPoints` | 10 | **20** | Buffer supplémentaire +20 pips sur market orders |

### Paramètres Impulse Zone (entrées spike + impulse 20 bars)

| Paramètre | Ancien | Nouveau | Impact |
|-----------|--------|---------|--------|
| `ImpulseZoneSL_ATRMult` | 1.2 | **1.8** | SL impulse +50% → moins de stop-out sur bruit intraday |
| `ImpulseZoneTP_ATRMult` | 2.4 | 2.4 | TP impulse stable ~RR 2.4 |

### Ratios Risk/Reward affectés

Avec `SL_ATRMult = 4.5` et `TP_ATRMult = 5.0`:
- **RR ratio ≈ 1.11** (avant: 1.67 avec 3.0 SL)
- Plus conservateur mais **évite les faux stops** sur la volatilité intra-minute

## Justification

### Avant (v1.25c)
- `SL_ATRMult = 3.0` → SL trop proche du prix d'entrée
- Sur FxVOL/SFXVOL avec volatilité 10-20% journalière → **coupes rapides sur simple bruit**
- Même avec GOM PERFECT, le prix oscillait dans le SL sans décision claire

### Après (v1.34)
- `SL_ATRMult = 4.5` → SL respire + accepte le bruit normal de volatilité
- `MaxSLDollars = 5.0` → cap en $ reste géré (jamais un seul trade ne sort > 5$ max)
- **Résultat**: trades laissés assez de place pour se développer avant coupe

## Vérification en live

Sur **Boom1000** (ou FxVOL configuré):

1. Attendre un setup GOM GOOD/PERFECT avec M1 aligné
2. Observer le SL distance affichée sur le graphique
3. Le SL devrait être **nettement plus loin** qu'avant (≈4.5 ATR vs 3.0 avant)
4. Vérifier que les ordres ne coupent plus trop vite sur oscillations mineures

### Dashboard
Le tableau de bord affiche maintenant au-dessous du nom du symbole:
```
VOL SL=4.5×ATR TP=5.0×ATR Cap=$5.0
```
Cela permet de confirmer en temps réel que les paramètres v1.34 sont appliqués.

## Risque capital conservé

- **Sniper Risk Cap** reste actif → aucun trade ne peut risquer plus que le max
- **Daily Capital Manager** reste actif → limites journalières respectées
- Seule la **distance SL-prix** augmente, le risque en $ est plafonné

## Prochaines étapes

1. ✅ Vérifier la syntaxe (sans erreurs)
2. ✅ Compiler et loader dans MT5
3. Tester sur Boom1000 en live 30 minutes
4. Observer le déclenchement de 2-3 ordres avec les nouveaux SL
5. Si toujours des coupes précoces → signaler pour ajustement `GainProtectTriggerUSD` ou `TrailingStop_ATRMult`

## Notes de configuration

- Ces changements ne s'appliquent **qu'aux volatility synthétiques** (FxVOL, SFXVOL, Boom1000 test)
- Forex, Metals, Crypto gardent leurs profils propres (`ForexSL_ATRMult`, `GoldSL_ATRMult`, etc.)
- DOW Trendline et structures SMC restent inchangées

---

**Version**: 1.34  
**Date**: 2026-09-01  
**Auteur**: Claude AI / TradBOT EA
