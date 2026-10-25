# AUDIT — Logique d'entrée (gates / SL-TP / taille de lot) — TradBOT MT5

Périmètre: `SMC_Universal.mq5` + modules live (`SMC_*AlerteScalp*`/`SMC_AutoScalp*`/`SMC_Stubs.mqh`/`SMC_BoomCrashStrategy.mqh`/`SMC_Universal`).
Méthode: lecture ciblée + greps. Chaque ligne citée a été vérifiée. Niveaux: CRITIQUE / ÉLEVÉ / MOYEN / FAIBLE.

Ce rapport est **français**, priorisé, axé sur « pourquoi les trades sont mauvais ».

---

## CRITIQUE

### CR-1 — Deux « final gates » coexistent, appliqués de façon **inégale** selon le moteur d'entrée
`modules\SMC_Stubs.mqh:214` (`bool SafeOrderSend(...)` + corps 214-436) — et le commentaire interne l'admet explicitement.

Le pipeline « noble » passe par `SMC_FinalOpenGate` (déf. `SMC_Universal.mq5:8260`; appelé sur les chemins AI `~21100-21214`, boom/crash spike `~20852`, tri-gate). Mais les **scalpers** (Dow, DowSR20, VolMomentum, AutoScalpFX, AutoScalpRange, AutoScalp) **ne passent pas** par `SMC_FinalOpenGate` : ils aboutissent à `SafeOrderSend`/`SafeOrderSendAndAlert`/`SafeMarketOrder*`, qui ne l'appellent **jamais**.

Vérification : `grep SMC_FinalOpenGate` sur tout `modules\*.mqh` → **zéro occurrence** ; la fonction n'est référencée que dans `SMC_Universal.mq5` et ses backups. Le commentaire de code le confirme (§ `SMC_Stubs.mqh:289-293`) :

```
// Certains chemins d'exécution contournent SMC_FinalOpenGate, donc cette vérification
// [M1+M5] doit être répliquée ICI dans SafeOrderSend pour TOUS les ordres
```

`SafeOrderSend` réplique en effet un sous-ensemble (terminal plein, anti-hedge `CanTradeOnSymbol`, ordre actif par symbole, GOM≠WAIT, gate M1+M5, cohérence GOM) — mais **pas** : le verdict minimal « PERFECT » selon la stratégie, le cap global de capital `SMC_ApplySniperRiskCap`, le débounce multi-symboles, la revalidation prix/ATR du pipeline. Résultat net : **un scalp Dow avec verdict SIMPLE + ATR élevé peut passer là où le même signal AI serait bloqué**, ou l'inverse selon le moteur.

**Pourquoi mauvais trade** : la politique risque (verdict minimum, capital partagé, cap $3 max) n'est pas appliquée uniformément ; la « contrainte inviolable » n'est pas inviolable partout. Correction : fiabiliser un unique `SafeOrderSend` comme « POINT D'ENTRÉE UNIQUE » (déjà documenté `SMC_TradeExecutor.mqh:102`) au lieu de scissions parallèles.

### CR-2 — Les scalpers boom/crash dédoublonnent l'entrée mais **pas** le SL/TP ni le cap $3 de façon fiable
`modules\SMC_AutoScalp.mqh` — scalpers Dow (`SMCASC_TryDowScalp` ~325-561 / DowSR20 `SMCASC_TryDowSR20Scalp` ~566-693 / VolMomentum `SMCASC_TryVolMomentumScalp` ~693-860).

- **Dow** : lot = `SMCASC_LotForMaxLoss(symbol, slDistancePoints, SMCASC_MaxLossUSD)` puis `lot = MathMin(lot, balance/10)` (déjà lv dans la fonction), **sans passage par `SMC_ApplySniperRiskCap`** — le cap $3 « inviolable » n'est pas présent sur ce chemin.
- **VolMomentum** : même lotage `SMCASC_LotForMaxLoss(...)` × `bcPositionMult` (`SMC_BoomCrashStrategy.mqh:230` clamp [0.25,1.5]) ; aucun `SMC_ApplySniperRiskCap`.
- Un SL « tight » est recalculé via une garde dont l'unité est fausse → elle ne se déclenche jamais (voir MOY-2).

**Pourquoi mauvais trade** : la promesse « max perte $3 » est inégale selon le moteur ; sur Boom/Crash le multiplicateur 1.5x peut faire dépasser le cap.

Cohabitation **économiquement dangereuse** : combiné à CR-1, deux scalpers peuvent entrer « en même temps » sur des chemins ne se partageant pas le même cap → risque de position cumulée au-delà de la politique.

## ÉLEVÉ

### H-1 — `CanTradeOnSymbol` ne fait PAS appel à `SMC_FinalOpenGate`
`SMC_Universal.mq5:7941-8070` (`bool CanTradeOnSymbol(...)`). Corps vérifié : `IsTerminalFull`, spike « WAIT », `SMC_ReactionEntryBlocked`, `SMC_LowCapitalAllowsSymbol`, `SMC_SpreadAllowsEntry`, marge libre ≥ 1.0, cooldowns gain (7959-7972), bloc GOM WAIT (7974-7979). **Aucun appel à `SMC_FinalOpenGate`.**

Or c'est LE garde partagé par `SafeOrderSend` (via `CanTradeOnSymbol`) et les chemins `SafeOrderSendAndAlert`. Donc : le verdict global GOM/cohérence M5 n'est **pas recalculé de façon homogène** sur tous les ordres ; seul le cache verdict (et la direction) sont utilisés. Quand `SMC_Stubs.mqh:342-358` ajoute sa propre garde « GOM WAIT » textuelle, c'est un correctif **rattrapé** d'un écueil systémique, pas une architecture.

**Pourquoi mauvais trade** : la direction/verdict peut être décalée entre symboles utilisés et symbole réel si un cache périmé ou un chemin non-cache rentre — risque de trades contre-tendance qui auraient été bloqués ailleurs.

> Note preuve, juste en-deçà de CRITIQUE : aucun « gate final » (FinalOpenGate / anti-hedge / spread / freeze / stops-level) n'est invoqué depuis `SafeOrderSend` seul ni depuis les scalpers ; ils se fient à des gardes **partielles répliquées** et à `CanTradeOnSymbol`. C'est robuste contre le hedge croisé mais **pas** contre le non-respect de la politique capitale.

### H-2 — `SafeOrderSend` autorise les verdicts « SIMPLE » sur Dow si le cache symbole est SIMPLE
`modules\SMC_AutoScalp.mqh:373-374` (DowScalp) :

```
if(vn == 0) return;                 // WAIT bloqué
if(MathAbs(vn) < SMCASC_MinVerdictNum) return;  // seuil
```

avec `vn` issu de `SMCGP_GetCachedVerdictNum`/`SMCGP_GetCachedVerdictStr`. En pratique Dow/SR20 n'exige **pas** `GOM=PERFECT` (contrairement à boom/crash AI), et `SafeOrderSend` n'impose pas non plus la PERFECT. SingleGate n'est pas appelé sur ces chemins (voir CR-1).

**Pourquoi mauvais trade** : tolérer SIMPLE revient à entrer dans la direction d'un verdict faible ; sur des symboles Boom/Crash le verdict SIMPLE peut être de moindre fiabilité → slippage/anti-tendance.

## MOYEN

### MOY-1 — Unités SL « point » vs « prix » mélangées (scalp Dow)
`modules\SMC_AutoScalp.mqh:458-464` (DowScalp) :

```
double minDist = stopsLvl * SymbolInfoDouble(symbol, SYMBOL_POINT);   // prix (ok)
...
if(MathAbs(entry - sl) < minDist * SymbolInfoDouble(symbol, SYMBOL_POINT))  // ← ×point en trop
    sl = entry ± minDist*1.2*... ;
```

`minDist` est DÉJÀ en unités de prix ; le re-multiplier par `SYMBOL_POINT` rend la condition ~`stopsLvl²` trop large → la garde « SL trop serré » ne se déclenche quasiment jamais.

**Pourquoi mauvais trade** : le SL réellement appliqué dévie du design (reposé sur ATR brut), → pertes = maxLoss au lieu de la réduction voulue ; aucun SignalStopLoss Update même après coup.

### MOY-2 — VolMomentum lit les barres M1 en incluant la barre en formation (look-ahead/repaint)
`modules\SMC_AutoScalp.mqh:775-792` (VolMomentum) : `CopyRates(symbol, PERIOD_M1, 0, N, rates)` puis chaîne de momentum basée sur `rates[0]` (barre incomplète/repainting). Le même module `SMCASC` lit ailleurs avec start=1 pour Dow, mais pas ici.

**Pourquoi mauvais trade** : verdict calculé sur une barre qui change en cours d'exécution → le scalp qui « marchait » au backtest ne reproduit pas en live (repaint), d'où trades qui semblent « juste » puis échouent.

### MOY-3 — Les scalpers sont appelés uniquement avec `_Symbol` mais le code scalaire garde des fins de boucle « symbol vs _Symbol »
Les call-sites vérifiés (`SMC_Universal.mq5:10473, 10480, 10487, 10493`) passent `_Symbol` — ok. MAIS plusieurs scalpers construisent des itérations/indicateurs sur `_Symbol` alors que le paramètre `symbol` peut différer (ex. `atrHandle` des scalpers lié à `_Symbol`, pas au symbole param).

**Pourquoi mauvais trade** : risque latent d'utiliser l'ATR/verdict du mauvais symbole si un jour on appelle avec un autre symbole ; aujourd'hui masqué car tous les appels sont `_Symbol`. À fiabiliser pour cloisonner.

## FAIBLE

### F-1 — `SafeOrderSend` réplique des gardes au lieu de déléguer (lutte contre la divergence)
`SMC_Stubs.mqh:242-290` : refactoriser pour n'avoir qu'un seul chemin (FinalOpenGate-like) et supprimer les commentaires « certains chemins contournent ». Le coût à moyen terme est des règles inégales entre moteurs (déjà constaté).

### F-2 — Copie des backups en double (`SMC_Universal_*backup.mq5`, `_merged`) ; des versions mortes de `SMC_EvaluateEntryGate` restent
`prime backup` vs `live`. Ne pas éditer les backups. Nettoyer les définitions mortelles pour éviter toute confusion dans l'audit futur.

---

## Matrice des chemins d'entrée

| Moteur | FinalOpenGate | CanTradeOnSymbol | SniperRiskCap | Verdict min | Cap $3 max |
|---|---|---|---|---|---|
| AI Decision (pipeline) `21100-21214` | OUI (`SMC_ApplySniperRiskCap` + gates) | OUI | OUI | PERFECT/GOM | OUI (1.0) |
| Boom/Crash Spike Market `20852` | NON (uniq. SafeOrderSend) | OUI | NON | GOM≠WAIT | ×1.5 possible |
| AutoScalp Dow `SMC_AutoScalp.mqh:335` | NON | via SafeOrderSend | NON | SIMPLE+ | NON (~balance/10) |
| AutoScalp VolMomentum `:693` | NON | via SafeOrderSend | NON | SIMPLE+ | NON (×bc mult ≤1.5) |
| AutoScalpRange/AutoScalpFX | NON | via SafeOrderSend | NON | idem | NON |

**Conclusion** : le moteur AI est le seul à respecter l'intégralité de la politique ; les scalpeurs boom/crash la contournent partiellement (CR-1/CR-2), avec en plus des bugs d'unités (MOY-1) et de look-ahead (MOY-2) qui dégradent la qualité perçue des trades.
