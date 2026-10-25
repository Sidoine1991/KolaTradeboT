# Configuration Manuelle des Paramètres de Backtest

## Procédure

1. Ouvrir MetaTrader 5 Strategy Tester
2. Sélectionner `SMC_Universal.mq5`
3. Cliquer sur "Inputs" pour accéder aux paramètres
4. Modifier uniquement les paramètres listés ci-dessous
5. Garder tous les autres paramètres par défaut

## Paramètres Clés à Modifier (par catégorie d'actif)

### === GÉNÉRAL ===
- **InpMagicNumber**: 123456
- **MaxPositionsTerminal**: 3
- **UnifiedGOMEntryMode**: true
- **OnePositionPerSymbol**: true

### === GOM VERDICT ===
- **UseGOMVerdictFilter**: true
- **MinGOMVerdictNumAbs**: 2 (GOOD/PERFECT uniquement)
- **RequireGoodPerfectAlways**: true
- **BlockEntryWhenAIHold**: false

### === RISQUE ===

#### GainX/PainX 400-600-800
- **MaxLossPerTradeDollars**: 2.5
- **GeneralGiveBackMaxPct**: 25.0
- **GeneralGiveBackMinPeakUSD**: 0.40
- **FirstSpikeGiveBackMaxPct**: 25.0
- **FirstSpikeGiveBackMinPeakUSD**: 0.25

#### PainX 999 (volatilité extrême)
- **MaxLossPerTradeDollars**: 3.0
- **GeneralGiveBackMaxPct**: 30.0
- **GeneralGiveBackMinPeakUSD**: 0.50
- **FirstSpikeGiveBackMaxPct**: 30.0
- **FirstSpikeGiveBackMinPeakUSD**: 0.30

#### FlipX (bidirectionnel)
- **MaxLossPerTradeDollars**: 2.0
- **GeneralGiveBackMaxPct**: 30.0
- **GeneralGiveBackMinPeakUSD**: 0.50
- **FirstSpikeGiveBackMaxPct**: 30.0
- **FirstSpikeGiveBackMinPeakUSD**: 0.30

### === SPIKE ===

#### GainX/PainX 400-600-800
- **UseSecondSpikeCapture**: true
- **SpikeCloseMinProfitUSD**: 0.25
- **SpikeCloseKeepPct**: 75.0

#### PainX 999
- **UseSecondSpikeCapture**: true
- **SpikeCloseMinProfitUSD**: 0.30
- **SpikeCloseKeepPct**: 70.0

#### FlipX
- **UseSecondSpikeCapture**: true
- **SpikeCloseMinProfitUSD**: 0.30
- **SpikeCloseKeepPct**: 70.0

### === TIMEFRAMES ===
- **UseM1**: true
- **UseM5**: true
- **UseM15**: true
- **UseH1**: true

### === STAGNATION ===

#### GainX/PainX 400-600-800
- **UseStagnationTimeExit**: true
- **StagnationMaxAgeMinutes**: 4

#### PainX 999 / FlipX
- **UseStagnationTimeExit**: true
- **StagnationMaxAgeMinutes**: 5

## Configuration Strategy Tester

- **Symbol**: Sélectionner l'actif (ex: GainX_400)
- **Model**: "Every tick" (pour volatilité)
- **Timeframe**: M1
- **Period**: Choisir la période de backtest
- **Deposit**: 1000 USD (ou montant souhaité)
- **Currency**: USD
- **Leverage**: 1:100

## Sauvegarde des Résultats

Après chaque backtest:
1. Cliquer sur "Report"
2. Sauvegarder en HTML dans:
   - `volatility/` pour GainX/PainX
   - `flipx/` pour FlipX
3. Nommer le fichier: `Symbol_Date_ParamVersion.html`
   - Ex: `GainX_400_2026-10-17_v1.html`

## Notes

- Ces paramètres sont basés sur les corrections récentes:
  - RequireGoodPerfectAlways=true (bloque SIMPLE)
  - Gate M5 pour volatilités
  - Spike imminent giveback guard
- Après les premiers backtests, ajuster les paramètres selon les résultats
- Focus sur: Profit Factor, Drawdown Max, Win Rate
