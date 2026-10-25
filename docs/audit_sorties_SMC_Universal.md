# Audit des sorties — SMC_Universal.mq5 (24 968 lignes)

> Recherche seule, aucun fichier modifié. Toutes les lignes citées référence `mt5/SMC_Universal.mq5`.
> Constats classés **CRITIQUE / HAUTE / MOYENNE / BASSE**, puis cartographie du système de sortie.

---

## Constat CRITIQUE n°1 — Les fermetures « spike capté / giveback » sont bloquées par la porte d'âge pour les positions < 120 s

`PositionCloseWithLog()` (352) applique une porte anti-escalade : âge minimum (`minHoldSec = max(120, …)`), perte minimum (~2 $), sauf dérogations. Ces dérogations passent par le *motif* (`reason`) de fermeture :

- `isAntiHedge` (377–382) : « ANTI-HEDGE / anti-hedge / CAP global / RETOURNEMENT / REVERSAL / jambe opposee » ;
- `waitExitAllowed` (401–403) : motif contenant **WAIT** ET perte ≥ 0,50 $ ;
- `protectCapturedGain` (386–389) : `StringFind(reason, "giveback") / "Garde" / "1er spike"` **sensible à la casse**.

Or les raisons réellement émises utilisent **« Giveback » avec majuscule (G)** :

- `ManageBoomCrashSpikeClose` 9230–9266 → fermeture avec préfixe « Spike close - … » (9271) :
  - 9232 « Spike capté $X — close immédiat »
  - 9242 « Giveback 15% après spike peak=$X »
  - 9247 « Giveback max 30% peak=$X »
  - 9266 « Spike TP $X »
- `ManageUniversalSpikeDeadline` 9434/9464 → « Spike deadline - Giveback … / Timeout … ».
- `ManageAdverseSpikeClose` 9358 → « Spike adverse - fermeture protectrice ».

`StringFind` est **sensible à la casse** : « Giveback » ≠ « giveback ». Aucun de ces motifs ne contient « 1er spike » ni « Garde ».

**Effet :** toute fermeture de spike/giveback sur une position de moins de 120 s est **silencieusement rejetée** au 413 (`if(!isHardLoss && !protectCapturedGain && secondsSinceOpen < minHoldSec) return false;`) — précisément les fenêtres où le système de spike doit agir (action rapide après capture). La position reste ouverte malgré le pic, le giveback s'écoule, et seul le plancher dur `-MaxLossDollars` (via `SMC_EnforceHardLossCutoff`, fermeture directe 9531) finira par couper. C'est très cohérent avec les observations terrain : « l'EA ne sécurise pas le pic ; il rend tout le giveback », et « spikes câblés ≤ 120 s » quasi inopérants.

**Corrections à proposer (design) :**
1. Passer en `StringFind(...,"giveback")` `< 0` → utilisation d'une recherche insensible à la casse (`StringToLower`) ou ajouter un mot-clé dédié type « SPIKE ».
2. Confier aux appels spike `forceClose=true` une dérogation explicite sur l'âge (comme `antiHedge`).
3. Ou n'appliquer la porte d'âge **unités-par-paramètre** : `SpikeCloseMinAgeSec` indépendant de `MinPositionLifetimeSec`.

---

## Constat CRITIQUE n°2 — `ManageDollarExits` scanne TOUTES les positions du terminal, sans filtre magic

`ManageDollarExits()` (9540–9658) itère sur `PositionsTotal()` via `PositionGetSymbol(i)` (9564) / `POSITION_TICKET` (9567) **sans vérifier `posInfo.Magic() == InpMagicNumber`** (contrairement à `ManageBoomCrashSpikeClose` 9135, `ManageUniversalSpikeDeadline` ~9391, `ManageAdverseSpikeClose` 9318, `SMC_ProtectCapturedSpikeSL` 1842, `SMC_EnforceNoHedgeAllSymbols`…).

Conséquences :
- Fermeture **universelle à +2 $** (9593) et **-MaxLossDollars** (9615) appliquée à toute position du terminal : autres EAs du même compte, trades manuels, hedge. C'est une reprise « règle bon marché → catastrophe en multi-EA ».
- Le seuil +2 $ est un TP global « premier arrivé » : la toute première position qui atteint +2 $ ferme, sans cohérence avec `BoomCrashSpikeTP` ni la chaîne 2e spike (excepté `secondSpikeImminent` 9576).

**Correctif simple : filtrer `posInfo.Magic()` (l'objet `posInfo` est déjà sélectionné via `SelectByIndex` partout ailleurs) ou ajouter le paramètre `ManageDollarExitsAllSymbols`.**

---

## Constat CRITIQUE n°3 — La garde générale de giveback est morte (v1 jamais appelée, v2 inerte)

- `SMC_ManageGeneralGiveBackGuard()` — détection de giveback général — n'est **jamais appelée** : seules existent la déclaration (555), un commentaire (1514) et la définition (1582). Le commentaire OnTick 10177–10180 annonce qu'elle est « remplacée » par la v2.
- La v2 `SMC_ManageDynamicGiveBack` (module, appelée 10181) itère sur `g_giveBackTrackers[]`, qui n'est **jamais rempli** : `GiveBack_RegisterPosition` n'apparaît que **commentée** (SMC_GOM_Immediate.mqh:327), et les appels `SMC_ManageDynamicGiveBack()` à 331 sont commentés.

**Net : le filet « garde générale giveback » (30 % du pic) n'existe plus en pratique.** Seule subsiste la protection par SL `SMC_ProtectCapturedSpikeSL` (1833), et encore — voir MOYENNE n°1.

---

## Constat HAUTE n°1 — Trois fonctions de sécurité globale sont du code mort

- `CheckTotalLossAndClose()` (17748) → appelle `CloseWorstPositionIfTotalLossExceeded()` (17751). Aucun appelant (seulement les déclarations 568/569 et les définitions 8928 / 8951).
- `CloseAllPositionsIfTotalProfitReached()` (8951) — jamais appelée.

Le « stop de perte totale du compte » et le « take profit global » n'existent donc que dans `ManageDollarExits` (par position, cf. CRITIQUE n°2). Toute règle type « fermer la pire position si perte totale > X » est inerte.

---

## Constat HAUTE n°2 — Motif « Profit total atteint » utilisé aussi pour la perte max (9625)

En 9615–9626, la coupure de perte `profit <= -MaxLossDollars` appelle `PositionCloseWithLog(ticket, "Profit total atteint")` : **le même libellé qu'un TP gagnant** (9603). Impact plus que cosmétique : avec le constat CRITIQUE n°1, une perte max sur position < 120 s **sera aussi bloquée** (motif sans dérogation, `isHardLoss` non atteint si `-MaxLossDollars < 2 $`… 2,0 = 2,0 donc `isHardLoss` atteint seulement `<= -2,00`) et, surtout, les logs/notifications rapportent une fausse « profit total » en cas de perte.

---

## Constat MOYENNE n°1 — `SMC_ProtectCapturedSpikeSL` tourne sans mémoire de pic (slot toujours -1)

`SMC_ProtectCapturedSpikeSL()` (1833) lit les slots `g_giveBackTicket[.]/g_giveBackPeak[.]` et `g_giveBackCount` (1848–1851). Ces tableaux ne sont remplis que par `SMC_ManageGeneralGiveBackGuard` (1605–1611) — **jamais exécutée** (CRITIQUE n°3). Donc `g_giveBackCount == 0`, `slot = -1`, `peak = profit` (1851) : le « pic » n'est plus qu'un simple `max(profit courant)` à chaque tick, sans historique. La protection `70 % du pic` se calculera sur le profit courant, ce qui reste utile (monotone) mais **ne verrouille plus un vrai pic atteint puis reperdu**.

---

## Constat MOYENNE n°2 — Validation « spike favorable » sur barre M1 en formation (repaint)

- `SMC_ReactionSpikeNow(766)` : `CopyRates(_Symbol, PERIOD_M1, 0, 4, r)` puis boucle `i=0..1` → inclut la **barre 0 non close** ; le « body », la direction et le rapport de force varient en cours de bougie → clôture de spike basée sur une barre en formation (repaint).
- `ManageAdverseSpikeClose` (9329–9332) : `iHigh/iLow/iOpen/iClose(..., PERIOD_M1, 0)` sur la **barre M1 courante** → un spike adverse peut apparaître/disparaître selon la bougie en cours.

Si l'intention est « agir au spike immédiat », c'est voulu ; mais ces signaux **ne peuvent pas être vérifiés à la bougie close** et dégradent la fiabilité des clôtures du CRITIQUE n°1 (faux positifs, faux « spike rendu en perte »).

---

## Constat MOYENNE n°3 — Chevauchenent et compétition entre gestionnaires de sortie

Sur une même position coexistent : `SMC_EnforceHardLossCutoff`, `ManageDollarExits`, `SMC_EnforceNoHedgeAllSymbols`, `ClosePositionsOnIAHold`, `SMC_ManageBoomCrashSpikeClose`, `SMC_ManageUniversalSpikeDeadline`, `SMC_ManageAdverseSpikeClose`, `SMC_ProtectCapturedSpikeSL`, `SMC_ManageDynamicDollarSL`, `SMC_ProfitLockSL`, `AI_TrailStop`/`ManageTrailingStop`, `CloseOnVerdictWait`, `CloseUnprofitableAfterDelay`, `TP1_CloseAndReEntry`. Chacun garde ses propres `static` trackers (`s_ticket[]/s_peak[]`, `g_giveBack*`, `g_dynSLPeaks`, `g_stagPeak`, `s_trailTicket`…). Risque de **double fermeture simultanée** (le premier close gagne, les autres échouent) : non destructif mais bruyant et difficilement auditable. Recommandation : tracker centralisé (`SMC_Registry`) une seule fois par tick/position.

---

## Constat BASSE n°1 — Spam DEBUG dans `ManageDollarExits`

9556 log toutes les 5 s « DEBUG - ManageDollarExits appelée », et 9590 log « par position analysée » à chaque passe. En production, inondation du journal expert ; à placer derrière un booléen debug.

---

## Constat BASSE n°2 — Ordre d'exécution onéreux (bars M1 etc.) avant rate-limit

`SMC_EnforceHardLossCutoff` (10077) tourne *avant* le rate-limit 0,5 s (10088) et utilise `SMC_ReactionSpikeNow`/M1 ; le reste du bloc spike (10840–10852) est dans la boucle 0,5 s. C'est un choix CPU acceptable, mais couplé au MOYENNE n°2, les calculs M1 « barre 0 » sont recalculés lourdement à chaque tick.

---

## Cartographie du système de sortie (chaque gestionnaire capable de fermer une position)

| Gestionnaire | Lignes | Déclencheur | Porte anti-escalade | Motif émis | État effectif |
|---|---|---|---|---|---|
| `SMC_EnforceHardLossCutoff` | 9501–9539 | profit ≤ `-MaxLossDollars` | **aucune** (close direct 9531) | raison interne | ✅ fonctionne ; enregistre `SMC_MSR_RegisterMissedSpike` |
| `ManageDollarExits` | 9540–9658 | +2 $ / -MaxLoss / `BoomCrashSpikeTP` | `PositionCloseWithLog` (+ âge 120 s avant) | « Profit total atteint » (9603/9625) | ⚠️ **sans filtre magic** ; libellé perte = fausse profit |
| `SMC_EnforceNoHedgeAllSymbols` | 7356–7445 | hedge même symbole | `isAntiHedge` → contourt tout | « ANTI-HEDGE enforce - jambe opposee » / « CAP global » | ✅ contourt par design |
| `SMC_ManageBoomCrashSpikeClose` | 9107–9291 | spike favorable / giveback / timeout / TP spike | `PositionCloseWithLog` | « Spike close - … » | ❌ motifs non dérogatoires → **bloqué si < 120 s** |
| `SMC_ManageUniversalSpikeDeadline` | 9367–9470 | deadline giveback / timeout 2e spike | `PositionCloseWithLog` | « Spike deadline - … » | ❌ idem, bloqué si < 120 s |
| `SMC_ManageAdverseSpikeClose` | 9310–9366 | bougie M1 adverse ≥ ATR× | `PositionCloseWithLog` | « Spike adverse - fermeture protectrice » | ❌ bloqué si < 120 s |
| `SMC_ProtectCapturedSpikeSL` | 1833–1900 | pic ≥ `SpikeCloseMinProfitUSD` | déplace le SL (ne ferme pas) | — | ⚠️ pic non mémorisé (g_giveBack* vide) |
| `ClosePositionsOnIAHold` | 9746+ | action IA = HOLD | `forceClose` **sans** mot-clé | « IA HOLD - Fermeture automatique » | ⚠️ soumis à la porte d'âge (sauf -2 $) |
| `SMC_ManageDynamicGiveBack` | module, 10181 | « garde générale v2 » | — | — | ❌ **inerte** (trackers jamais remplis) |
| `SMC_ManageGeneralGiveBackGuard` | 1582 | giveback général 30 % | — | « Garde generale … » | ❌ **jamais appelée** |
| `SMC_ManageDynamicDollarSL` | module, 10259 | MaxLoss `DynSL_MaxLossUSD` / giveback | `PositionCloseWithLog` | « DynSL MaxLoss $X / Giveback peak=… » | ⚠️ « Giveback » majuscule → non dérogatoire |
| `SMC_ProfitLockSL` | 10856 | profit ≥ `ProfitLockTriggerUSD` | déplace SL | — | ✅ SL sécurisé dès 0,30 $ |
| `AI_TrailStop`/`ManageTrailingStop` | 10860 / 16553 | trailing ATR | `PositionCloseWithLog` | « Trailing stop … » | ⚠️ soumis aux mêmes portes |
| `CloseOnVerdictWait` | 10852 / 16184 | verdict WAIT | `waitExitAllowed` (WAIT + perte ≥ 0,5 $) | « fermeture verdict WAIT » | ✅ dérogation WAIT fonctionnelle |
| `CloseUnprofitableAfterDelay` | 24195 / 10847 | 7 min + perte ≥ 2 $ | `PositionCloseWithLog` | « 7min loss close » | ✅ mais redondant avec EnforceHardLossCutoff |
| `TP1_CloseAndReEntry` | 16130 / 10850 | profit ≥ `TP1ProfitTargetUSD` | **aucune** (close direct 16154) | « TP1 … » | ✅ fonctionne (**contourne** toute la porte d'âge) |
| `CheckTotalLossAndClose` (+2 sous-fonctions) | 17748 / 8928 / 8951 | perte totale / profit total | — | — | ❌ **code mort, jamais appelé** |
| `ATRTRAIL_ManageAll` (DowScanner) | 10303–10308 | ATR trail (ScannerUseATRTrail) | `ATRTRAIL_` interne | — | ✅ actif si DowScanner |

---

## Recommandations priorisées

1. **CRITIQUE** — Normaliser la dérogation spike : moteur `isAntiHedge` étendu à un mot-clé « SPIKE » (insensible à la casse) ou `forceClose` qui court-circuite l'âge **uniquement** pour `isSpikeCmt`. Sinon le CRITIQUE n°1 rend inutiles 3 gestionnaires entiers.
2. **CRITIQUE** — Restreindre `ManageDollarExits` à `InpMagicNumber` + paramétrer « all symbols vs symbole courant » ; corriger le libellé perte (9625).
3. **CRITIQUE** — Rétablir une vraie garde générale giveback : remplir `g_giveBackTrackers` (décommenter/appeler `GiveBack_RegisterPosition`) ou ressusciter `SMC_ManageGeneralGiveBackGuard` avec la porte d'âge du CRITIQUE n°1 corrigée.
4. **HAUTE** — Décider du sort de `CheckTotalLossAndClose`/`CloseWorst…`/`CloseAll…` : les brancher sérieusement (perte globale) ou les supprimer.
5. **MOYENNE** — Mémoïser le pic par position dans `SMC_ProtectCapturedSpikeSL` indépendamment des tableaux morts ; décider explicitement du comportement « barre M1 0 » (repaint) sur `ReactionSpikeNow`/`AdverseSpike`.
6. **MOYENNE** — Centraliser les trackers positionnels (`s_ticket[]` multiples) ; mettre derrière un flag les logs DEBUG 5 s de `ManageDollarExits`.

---

*Fin du rapport. Aucun fichier modifié.*