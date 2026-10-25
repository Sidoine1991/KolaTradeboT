# Structure de Backtest TradBOT

## Organisation des dossiers

```
backtest/
├── volatility/      # Rapports backtest GainX/PainX
├── flipx/           # Rapports backtest FlipX
├── reports/         # Rapports consolidés et analyses
├── params/          # Fichiers de paramètres optimisés par actif
└── README.md        # Ce fichier
```

## Données historiques disponibles

### Volatilité (GainX/PainX)
- GainX_400, GainX_600, GainX_800
- PainX_400, PainX_600, PainX_800, PainX_999
- Timeframes: M1, M5, M15, M30, H1, H4, D1, W1

### FlipX
- FlipX_1, FlipX_2, FlipX_3, FlipX_4, FlipX_5
- Timeframes: M1, M5, M15, M30, H1, H4, D1, W1

## Paramètres par défaut à optimiser

### Paramètres GOM
- MinGOMVerdictNumAbs: 2 (GOOD/PERFECT uniquement)
- RequireGoodPerfectAlways: true
- UseGOMVerdictFilter: true

### Paramètres de risque
- MaxLossPerTradeDollars
- GeneralGiveBackMaxPct
- FirstSpikeGiveBackMaxPct

### Paramètres de volatilité
- SpikeCloseMinProfitUSD
- SpikeCloseKeepPct

## Procédure de backtest

1. Copier les données historiques vers MT5/MQL5/Files
2. Configurer Strategy Tester avec les paramètres par défaut
3. Exécuter backtest sur chaque actif
4. Sauvegarder le rapport HTML dans le dossier correspondant
5. Analyser les résultats et ajuster les paramètres
6. Sauvegarder les paramètres optimisés dans params/

## Métriques clés à surveiller

- Profit Factor
- Drawdown Max
- Sharpe Ratio
- Win Rate
- Average Win/Loss
- Total Trades
