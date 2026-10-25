#!/usr/bin/env python3
"""
Script de backtesting pour TradBOT
Teste les stratégies sur données historiques
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import logging
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("backtest")


class Backtester:
    """Moteur de backtesting pour stratégies de trading"""
    
    def __init__(
        self,
        initial_capital: float = 1000.0,
        risk_per_trade: float = 0.01,  # 1% du capital
        target_daily_profit: float = 50.0
    ):
        self.initial_capital = initial_capital
        self.capital = initial_capital
        self.risk_per_trade = risk_per_trade
        self.target_daily_profit = target_daily_profit
        
        self.trades = []
        self.equity_curve = []
        self.daily_profits = {}
        
    def load_historical_data(self, symbol: str, timeframe: str, start_date: str, end_date: str) -> pd.DataFrame:
        """
        Charge les données historiques (à adapter selon votre source)
        
        Pour l'instant, génère des données simulées
        """
        logger.info(f"Chargement données: {symbol} {timeframe} de {start_date} à {end_date}")
        
        # Simulation de données (à remplacer par vraies données MT5/CSV)
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
        
        dates = pd.date_range(start, end, freq='1H')
        
        # Générer des prix OHLCV simulés
        np.random.seed(42)
        base_price = 10000 if "Volatility" in symbol else 5000
        
        data = {
            'time': dates,
            'open': base_price + np.random.randn(len(dates)) * 100,
            'high': base_price + np.random.randn(len(dates)) * 100 + 50,
            'low': base_price + np.random.randn(len(dates)) * 100 - 50,
            'close': base_price + np.random.randn(len(dates)) * 100,
            'volume': np.random.randint(100, 1000, len(dates))
        }
        
        df = pd.DataFrame(data)
        df['high'] = df[['open', 'high', 'close']].max(axis=1)
        df['low'] = df[['open', 'low', 'close']].min(axis=1)
        
        return df
    
    def calculate_indicators(self, df: pd.DataFrame) -> pd.DataFrame:
        """Calcule les indicateurs techniques"""
        # RSI
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['rsi'] = 100 - (100 / (1 + rs))
        
        # EMA
        df['ema_fast'] = df['close'].ewm(span=50, adjust=False).mean()
        df['ema_slow'] = df['close'].ewm(span=200, adjust=False).mean()
        
        # ATR
        high_low = df['high'] - df['low']
        high_close = np.abs(df['high'] - df['close'].shift())
        low_close = np.abs(df['low'] - df['close'].shift())
        ranges = pd.concat([high_low, high_close, low_close], axis=1)
        true_range = ranges.max(axis=1)
        df['atr'] = true_range.rolling(14).mean()
        
        # VWAP (approximation)
        df['vwap'] = (df['close'] * df['volume']).cumsum() / df['volume'].cumsum()
        
        return df
    
    def generate_signals(self, df: pd.DataFrame) -> pd.DataFrame:
        """Génère les signaux de trading basés sur la stratégie"""
        df['signal'] = 0  # 0 = hold, 1 = buy, -1 = sell
        
        # Stratégie combinée
        for i in range(50, len(df)):
            rsi = df.iloc[i]['rsi']
            ema_fast = df.iloc[i]['ema_fast']
            ema_slow = df.iloc[i]['ema_slow']
            close = df.iloc[i]['close']
            vwap = df.iloc[i]['vwap']
            
            # Signal BUY
            if (rsi < 30 and                    # RSI survente
                ema_fast > ema_slow and         # Tendance haussière
                close < vwap):                  # Prix sous VWAP
                df.loc[df.index[i], 'signal'] = 1
                
            # Signal SELL
            elif (rsi > 70 and                  # RSI surachat
                  ema_fast < ema_slow and       # Tendance baissière
                  close > vwap):                # Prix sur VWAP
                df.loc[df.index[i], 'signal'] = -1
        
        return df
    
    def execute_backtest(self, df: pd.DataFrame, symbol: str) -> Dict:
        """Exécute le backtest sur les données"""
        logger.info(f"Exécution backtest sur {len(df)} bougies")
        
        position = None  # Position actuelle (None, 'long', 'short')
        entry_price = 0
        entry_time = None
        
        for i in range(len(df)):
            row = df.iloc[i]
            current_time = row['time']
            current_price = row['close']
            signal = row['signal']
            atr = row['atr']
            
            # Vérifier si on a une position ouverte
            if position is not None:
                # Calculer le P/L actuel
                if position == 'long':
                    pnl = current_price - entry_price
                    sl = entry_price - (atr * 2)
                    tp = entry_price + (atr * 3)
                    
                    # Vérifier SL/TP
                    if current_price <= sl or current_price >= tp:
                        # Fermer la position
                        profit = (current_price - entry_price) * self.calculate_lot_size(atr)
                        self.close_trade(symbol, 'long', entry_price, current_price, profit, entry_time, current_time)
                        position = None
                        
                elif position == 'short':
                    pnl = entry_price - current_price
                    sl = entry_price + (atr * 2)
                    tp = entry_price - (atr * 3)
                    
                    # Vérifier SL/TP
                    if current_price >= sl or current_price <= tp:
                        # Fermer la position
                        profit = (entry_price - current_price) * self.calculate_lot_size(atr)
                        self.close_trade(symbol, 'short', entry_price, current_price, profit, entry_time, current_time)
                        position = None
            
            # Ouvrir nouvelle position si signal
            if position is None and signal != 0:
                if signal == 1:  # BUY
                    position = 'long'
                    entry_price = current_price
                    entry_time = current_time
                    logger.debug(f"Ouverture LONG à {entry_price} le {current_time}")
                    
                elif signal == -1:  # SELL
                    position = 'short'
                    entry_price = current_price
                    entry_time = current_time
                    logger.debug(f"Ouverture SHORT à {entry_price} le {current_time}")
        
        # Calculer les métriques finales
        return self.calculate_metrics()
    
    def calculate_lot_size(self, atr: float) -> float:
        """Calcule la taille du lot basée sur le risque"""
        risk_amount = self.capital * self.risk_per_trade
        lot_size = risk_amount / (atr * 2)  # SL = 2x ATR
        return max(0.01, min(lot_size, 1.0))  # Entre 0.01 et 1.0
    
    def close_trade(
        self,
        symbol: str,
        direction: str,
        entry_price: float,
        exit_price: float,
        profit: float,
        entry_time: datetime,
        exit_time: datetime
    ):
        """Enregistre la fermeture d'un trade"""
        self.capital += profit
        
        trade = {
            'symbol': symbol,
            'direction': direction,
            'entry_price': entry_price,
            'exit_price': exit_price,
            'profit': profit,
            'entry_time': entry_time,
            'exit_time': exit_time,
            'duration': (exit_time - entry_time).total_seconds() / 60  # minutes
        }
        
        self.trades.append(trade)
        self.equity_curve.append({
            'time': exit_time,
            'equity': self.capital
        })
        
        # Suivre les profits journaliers
        date_key = exit_time.date()
        if date_key not in self.daily_profits:
            self.daily_profits[date_key] = 0
        self.daily_profits[date_key] += profit
        
        logger.info(f"Trade fermé: {direction} P/L: {profit:.2f}$ Capital: {self.capital:.2f}$")
    
    def calculate_metrics(self) -> Dict:
        """Calcule les métriques de performance du backtest"""
        if not self.trades:
            return {
                'total_trades': 0,
                'win_rate': 0,
                'profit_factor': 0,
                'max_drawdown': 0,
                'sharpe_ratio': 0,
                'total_profit': 0,
                'avg_profit_per_trade': 0
            }
        
        wins = [t for t in self.trades if t['profit'] > 0]
        losses = [t for t in self.trades if t['profit'] < 0]
        
        total_profit = sum(t['profit'] for t in self.trades)
        total_wins = sum(t['profit'] for t in wins)
        total_losses = abs(sum(t['profit'] for t in losses))
        
        win_rate = len(wins) / len(self.trades) * 100
        profit_factor = total_wins / total_losses if total_losses > 0 else 0
        avg_profit = total_profit / len(self.trades)
        
        # Calculer le drawdown maximum
        equity_values = [e['equity'] for e in self.equity_curve]
        peak = equity_values[0]
        max_dd = 0
        
        for equity in equity_values:
            if equity > peak:
                peak = equity
            dd = (peak - equity) / peak * 100
            if dd > max_dd:
                max_dd = dd
        
        # Calculer le Sharpe ratio (simplifié)
        returns = [t['profit'] / self.initial_capital for t in self.trades]
        sharpe = np.mean(returns) / np.std(returns) * np.sqrt(252) if returns else 0
        
        # Jours ayant atteint l'objectif de 50$
        days_target_reached = sum(1 for profit in self.daily_profits.values() if profit >= self.target_daily_profit)
        
        return {
            'total_trades': len(self.trades),
            'wins': len(wins),
            'losses': len(losses),
            'win_rate': win_rate,
            'profit_factor': profit_factor,
            'total_profit': total_profit,
            'total_wins': total_wins,
            'total_losses': total_losses,
            'avg_profit_per_trade': avg_profit,
            'max_drawdown': max_dd,
            'sharpe_ratio': sharpe,
            'final_capital': self.capital,
            'return_pct': (self.capital - self.initial_capital) / self.initial_capital * 100,
            'days_tested': len(self.daily_profits),
            'days_target_reached': days_target_reached,
            'target_success_rate': days_target_reached / len(self.daily_profits) * 100 if self.daily_profits else 0
        }
    
    def generate_report(self, metrics: Dict, symbol: str) -> str:
        """Génère un rapport de backtest"""
        report = f"""
{'='*60}
RAPPORT DE BACKTEST - {symbol}
{'='*60}

RÉSULTATS GLOBAUX:
------------------
Capital initial:        {self.initial_capital:.2f}$
Capital final:          {metrics['final_capital']:.2f}$
Profit total:           {metrics['total_profit']:.2f}$
Rendement:              {metrics['return_pct']:.2f}%

STATISTIQUES DE TRADING:
------------------------
Nombre de trades:       {metrics['total_trades']}
Trades gagnants:        {metrics['wins']} ({metrics['win_rate']:.1f}%)
Trades perdants:        {metrics['losses']}
Profit moyen/trade:     {metrics['avg_profit_per_trade']:.2f}$

MÉTRIQUES DE RISQUE:
--------------------
Profit factor:          {metrics['profit_factor']:.2f}
Max drawdown:           {metrics['max_drawdown']:.2f}%
Sharpe ratio:           {metrics['sharpe_ratio']:.2f}

OBJECTIF JOURNALIER (50$):
--------------------------
Jours testés:           {metrics['days_tested']}
Jours objectif atteint: {metrics['days_target_reached']}
Taux de réussite:       {metrics['target_success_rate']:.1f}%

{'='*60}
"""
        return report


def run_backtest(
    symbol: str = "Volatility 75 Index",
    start_date: str = "2024-10-01",
    end_date: str = "2024-12-31",
    initial_capital: float = 1000.0
):
    """Exécute un backtest complet"""
    logger.info(f"Démarrage backtest: {symbol} du {start_date} au {end_date}")
    
    # Initialiser le backtester
    bt = Backtester(initial_capital=initial_capital)
    
    # Charger les données
    df = bt.load_historical_data(symbol, "H1", start_date, end_date)
    
    # Calculer les indicateurs
    df = bt.calculate_indicators(df)
    
    # Générer les signaux
    df = bt.generate_signals(df)
    
    # Exécuter le backtest
    metrics = bt.execute_backtest(df, symbol)
    
    # Générer le rapport
    report = bt.generate_report(metrics, symbol)
    print(report)
    
    # Sauvegarder les résultats
    results = {
        'symbol': symbol,
        'period': f"{start_date} to {end_date}",
        'metrics': metrics,
        'trades': bt.trades,
        'equity_curve': bt.equity_curve
    }
    
    with open(f"backtest_results_{symbol.replace(' ', '_')}_{start_date}_{end_date}.json", 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    logger.info("Backtest terminé - Résultats sauvegardés")
    
    return metrics


if __name__ == "__main__":
    # Tester sur plusieurs symboles
    symbols = [
        "Volatility 75 Index",
        "Boom 500 Index",
        "Crash 500 Index"
    ]
    
    all_results = {}
    
    for symbol in symbols:
        print(f"\n{'='*60}")
        print(f"BACKTEST: {symbol}")
        print(f"{'='*60}\n")
        
        metrics = run_backtest(
            symbol=symbol,
            start_date="2024-10-01",
            end_date="2024-12-31",
            initial_capital=1000.0
        )
        
        all_results[symbol] = metrics
    
    # Résumé comparatif
    print(f"\n{'='*60}")
    print("RÉSUMÉ COMPARATIF")
    print(f"{'='*60}\n")
    
    for symbol, metrics in all_results.items():
        print(f"{symbol}:")
        print(f"  Win Rate: {metrics['win_rate']:.1f}%")
        print(f"  Profit: {metrics['total_profit']:.2f}$")
        print(f"  Objectif 50$/jour: {metrics['target_success_rate']:.1f}%")
        print()