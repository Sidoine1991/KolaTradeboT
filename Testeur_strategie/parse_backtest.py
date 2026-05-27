import openpyxl
import json
import re

def parse_file(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb['Sheet1']
    rows = list(ws.iter_rows(values_only=True))

    # --- PARAMS ---
    params = {}
    for row in rows:
        v = row[3]
        if v and isinstance(v, str) and '=' in v and not v.startswith('==='):
            k, val = v.split('=', 1)
            try:
                val = int(val)
            except Exception:
                try:
                    val = float(val)
                except Exception:
                    pass
            params[k.strip()] = val

    # Labeled rows for broker/symbol/period/deposit/leverage/expert
    for row in rows:
        a = row[0]
        d = row[3]
        if a and d:
            s = str(a)
            if 'Courtier' in s:
                params['Broker'] = d
            elif 'Devise' in s:
                params['Currency'] = d
            elif 'initial' in s.lower() and ('p' in s.lower() or 'd' in s.lower()):
                params['InitialDeposit'] = d
            elif 'Levier' in s:
                params['Leverage'] = d
            elif 'riode' in s:
                params['Period'] = d
            elif 'Symbole' in s:
                params['Symbol'] = d
            elif 'Expert' in s:
                params['Expert'] = d

    # --- METRICS ---
    metrics = {}

    for row in rows:
        a = row[0]
        s_a = str(a) if a else ''

        # Row: Profit Total Net | BalanceDD Abs | FundsDD Abs
        if 'Net' in s_a and row[3] is not None and not isinstance(row[3], str):
            metrics['NetProfit'] = row[3]
            if row[7] is not None:
                metrics['BalanceDrawdownAbsolute'] = row[7]
            if row[10] is not None:
                metrics['FundsDrawdownAbsolute'] = row[10]

        # Row: Profit brut | BalanceDD Max | FundsDD Max
        if 'Profit brut' in s_a and row[3] is not None:
            metrics['GrossProfit'] = row[3]
            if row[7] is not None:
                metrics['BalanceDrawdownMaximal_str'] = str(row[7])
            if row[10] is not None:
                metrics['FundsDrawdownMaximal_str'] = str(row[10])
            # parse pct from string like "17.99 (3.60%)"
            for key, col in [('BalanceDrawdownMaximal', row[7]), ('FundsDrawdownMaximal', row[10])]:
                if col and isinstance(col, str):
                    m = re.search(r'([\d.]+)\s*\(([\d.]+)%\)', col)
                    if m:
                        metrics[key + '_abs'] = float(m.group(1))
                        metrics[key + '_pct'] = float(m.group(2))

        # Row: Perte brut | BalanceDD Rel | FundsDD Rel
        if 'Perte brut' in s_a and row[3] is not None:
            metrics['GrossLoss'] = row[3]
            if row[7] is not None:
                metrics['BalanceDrawdownRelative_str'] = str(row[7])
            if row[10] is not None:
                metrics['FundsDrawdownRelative_str'] = str(row[10])
            for key, col in [('BalanceDrawdownRelative', row[7]), ('FundsDrawdownRelative', row[10])]:
                if col and isinstance(col, str):
                    m = re.search(r'([\d.]+)%\s*\(([\d.]+)\)', col)
                    if m:
                        metrics[key + '_pct'] = float(m.group(1))
                        metrics[key + '_abs'] = float(m.group(2))

        # Profit Factor, Expected Payoff, Margin Level
        if 'Facteur de profit' in s_a:
            metrics['ProfitFactor'] = row[3]
            metrics['ExpectedPayoff'] = row[7]
            metrics['MarginLevel'] = row[10]

        # Recovery Factor, Sharpe, ZScore
        if 'cup' in s_a and 'Facteur' in s_a:
            metrics['RecoveryFactor'] = row[3]
            metrics['SharpeRatio'] = row[7]
            metrics['ZScore'] = row[10]

        # AHPR, LR Correlation
        if 'AHPR' in s_a:
            metrics['AHPR'] = row[3]
            metrics['LR_Correlation'] = row[7]

        # GHPR, LR Std Error
        if 'GHPR' in s_a:
            metrics['GHPR'] = row[3]
            metrics['LR_StdError'] = row[7]

        # Correlations
        if row[0] and 'Profits, MFE' in s_a:
            metrics['Corr_Profits_MFE'] = row[3]
            metrics['Corr_Profits_MAE'] = row[7]
            metrics['Corr_MFE_MAE'] = row[10]

        # Hold durations
        if 'minimale de tenue' in s_a:
            metrics['MinHoldDuration'] = row[3]
            metrics['MaxHoldDuration'] = row[7]
            metrics['AvgHoldDuration'] = row[10]

        # Trade counts
        if 'Nb trades' in s_a:
            metrics['TotalTrades'] = row[3]
            metrics['ShortPositions_WonPct'] = str(row[7])
            metrics['LongPositions_WonPct'] = str(row[10])
            # parse short/long win counts
            for key, val in [('Short', row[7]), ('Long', row[10])]:
                if val and isinstance(val, str):
                    m = re.search(r'(\d+)\s*\(([\d.]+)%\)', val)
                    if m:
                        metrics[key + '_Count'] = int(m.group(1))
                        metrics[key + '_WinRate_pct'] = float(m.group(2))

        # Total operations, winning/losing
        if 'rations au Total' in s_a:
            metrics['TotalOperations'] = row[3]
            if row[7]:
                metrics['WinningPositions_str'] = str(row[7])
                m = re.search(r'(\d+)\s*\(([\d.]+)%\)', str(row[7]))
                if m:
                    metrics['WinCount'] = int(m.group(1))
                    metrics['WinRate_pct'] = float(m.group(2))
            if row[10]:
                metrics['LosingPositions_str'] = str(row[10])
                m = re.search(r'(\d+)\s*\(([\d.]+)%\)', str(row[10]))
                if m:
                    metrics['LossCount'] = int(m.group(1))
                    metrics['LossRate_pct'] = float(m.group(2))

        # Largest win/loss
        if row[4] and 'large position gagnante' in str(row[4]):
            metrics['LargestWin'] = row[7]
            metrics['LargestLoss'] = row[10]

        # Avg win/loss
        if row[4] and 'Moyenne position gagnante' in str(row[4]):
            metrics['AvgWin'] = row[7]
            metrics['AvgLoss'] = row[10]

        # Max consec wins/losses by $
        if row[4] and 'Maximum R' in str(row[4]) and 'lisations cons' in str(row[4]):
            metrics['MaxConsecWins_$'] = str(row[7])
            metrics['MaxConsecLoss_$'] = str(row[10])

        # Max consec by count
        if row[4] and 'Maximum Gains cons' in str(row[4]):
            metrics['MaxConsecWins_count'] = str(row[7])
            metrics['MaxConsecLoss_count'] = str(row[10])

        # Avg consec
        if row[4] and 'Moyenne Gains' in str(row[4]):
            metrics['AvgConsecWins'] = row[7]
            metrics['AvgConsecLoss'] = row[10]

        # Bars/Ticks/Symbols
        if a and 'Barres' in s_a:
            metrics['Bars'] = row[3]
            metrics['Ticks'] = row[7]
            metrics['Symbols'] = row[10]

    metrics['BalanceInitial'] = 500.0
    if 'NetProfit' in metrics:
        metrics['BalanceFinal'] = 500.0 + metrics['NetProfit']

    # --- TRADES (from Transactions section) ---
    trades = []
    in_transactions = False
    for row in rows:
        if row[0] and 'Transactions' in str(row[0]) and row[1] is None:
            in_transactions = True
            continue
        if in_transactions:
            if row[0] == 'Heure':
                continue
            if row[0] and row[2] == 'XAUUSD':
                trades.append({
                    'time': str(row[0]),
                    'op_id': row[1],
                    'symbol': row[2],
                    'type': row[3],
                    'direction': row[4],
                    'volume': row[5],
                    'price': row[6],
                    'order': row[7],
                    'commission': row[8],
                    'swap': row[9],
                    'profit': row[10],
                    'balance': row[11],
                    'comment': row[12]
                })

    return {'params': params, 'metrics': metrics, 'trades': trades}


result = {
    'bear': parse_file('Testeur_strategie/ReportTester-5775742_26 mai_Or_bear setup.xlsx'),
    'bull': parse_file('Testeur_strategie/ReportTester-5775742_26 mai_Or_bull setup.xlsx')
}

print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
