# DIVERGENCE TRADING v5 — PRODUCTION
# Paramètres optimisés: {'w': 5, 'div_t': 0.18, 'sl_m': 1.4, 'tp_m': 2.5, 'cm': 3, 'tr_f': 1.3, 'max_hold': 10}
# Sharpe: 0.85 | WinRate: 42.4% | PF: 1.05 | TPD: 3.2 | MaxDD: -19.0%
# Usage: brancher sur API broker (Binance/Kraken/Bybit) avec données 1H réelles
# Timeframe: 1H | Risk/trade: 1.2% | Capital: $10,000

# Composantes du champ vectoriel divergence:
# div F = dP/dx + dQ/dy + dR/dz
# dP = ROC normalisé (momentum prix)
# dQ = Z-score volume (anomalie volume)
# dR = dérivée RSI normalisée (open interest proxy)

BEST_PARAMS = {'w': 5, 'div_t': 0.18, 'sl_m': 1.4, 'tp_m': 2.5, 'cm': 3, 'tr_f': 1.3, 'max_hold': 10}
RISK_PCT    = 0.012
CAPITAL     = 10000
TIMEFRAME   = "1H"
