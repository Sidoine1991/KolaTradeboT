# Fast Test Pipeline (MT5 + Profit-First)

Ce pipeline sert a tester vite sans passer directement par des backtests longs "every tick" sur chaque idee.

## Etape 1 - Prescreen rapide (10-20 min)

- Mode MT5: `Open prices only` (ou mode le plus rapide disponible).
- Horizon: 30 jours.
- Symboles: `Crash 300`, `Boom 900`.
- Objectif: eliminer les configs qui ne prennent aucun trade ou ont un drawdown trop sale.

Critere de passage:

- `Nb trades >= 10`
- `Profit Factor >= 1.10`
- `Drawdown relatif <= 25%`

## Etape 2 - Validation serieuse (30-90 min)

- Mode MT5: `Every tick based on real ticks`.
- Horizon: 90 jours.
- Levier: meme valeur que ton compte reel.
- Tester seulement les 2-3 meilleures configs de l'etape 1.

Critere de passage:

- `Nb trades >= 30`
- `Profit Factor >= 1.30`
- `Max drawdown relatif <= 15%`
- Pas de periode de giveback massif en fin de courbe.

## Etape 3 - Walk-forward (robustesse)

- Split recommande:
  - Train: 60 jours
  - Test OOS: 30 jours
- Glisser la fenetre 3 fois.
- Une config est valide si elle reste correcte sur la majorite des fenetres.

## Parametres prioritaires a faire varier

- `StrictModeMinAIConfidencePct`
- `StrictModeMinSetupScore`
- `DailyPeakGivebackStopUSD`
- `AdaptiveTradeBudgetMin`
- `AdaptiveTradeBudgetMax`
- `TrailingPhase2LockPct`
- `TrailingPhase3LockPct`

## Profil de depart recommande

- `UsePropiceSymbolsFilter=false` (phase test uniquement)
- `StrictModeTriggerProfitUSD=10`
- `StrictModeMinAIConfidencePct=75`
- `StrictModeMinSetupScore=65`
- `AdaptiveTradeBudgetMin=10`
- `AdaptiveTradeBudgetMax=30`
- `DailyPeakGivebackStopUSD=5.0`
- `TrailingPhase2LockPct=0.75`
- `TrailingPhase3LockPct=0.85`

## Methode d'interpretation rapide

- Trop peu de trades -> diminuer legerement `StrictModeMinAIConfidencePct` et/ou `StrictModeMinSetupScore`.
- Trop de drawdown -> monter `DailyPeakGivebackStopUSD` seulement si faux lock; sinon baisser ce seuil pour couper plus tot.
- Courbe qui rend les gains -> augmenter `TrailingPhase3LockPct` (ex: 0.88-0.90) et renforcer `StrictModeMinSetupScore`.

## Astuce pratique

Pour gagner du temps:

1. Lance 3 profils en prescreen rapide.
2. Garde seulement 1-2 profils.
3. Lance ces profils en tick reel 90 jours.
4. Termine par walk-forward sur le meilleur.
