"""
F_INX_Robot3 Manager - Python interface for managing and monitoring F_INX_Robot3 EA
"""
import MetaTrader5 as mt5
from utils.mt5_utils import get_mt5_connection
from datetime import datetime
import pandas as pd


class F_INX_Robot3Manager:
    """Manager class for F_INX_Robot3 Expert Advisor"""
    
    def __init__(self, magic_number=20251115):
        """
        Initialize the manager
        
        Args:
            magic_number: Magic number used by the EA (default: 20251115)
        """
        self.magic_number = magic_number
        self.connected = False
        
    def connect(self):
        """Establish MT5 connection"""
        self.connected = get_mt5_connection()
        return self.connected
    
    def disconnect(self):
        """Disconnect from MT5"""
        if self.connected:
            mt5.shutdown()
            self.connected = False
            print("✅ Disconnected from MT5")
    
    def get_positions(self, symbol=None):
        """
        Get open positions managed by the EA
        
        Args:
            symbol: Optional symbol filter
            
        Returns:
            List of position dictionaries
        """
        if not self.connected:
            raise RuntimeError("Not connected to MT5. Call connect() first.")
        
        positions = mt5.positions_get(symbol=symbol) if symbol else mt5.positions_get()
        if positions is None:
            return []
        
        # Filter by magic number
        ea_positions = [pos for pos in positions if pos.magic == self.magic_number]
        
        result = []
        for pos in ea_positions:
            result.append({
                'ticket': pos.ticket,
                'symbol': pos.symbol,
                'type': 'BUY' if pos.type == mt5.ORDER_TYPE_BUY else 'SELL',
                'volume': pos.volume,
                'price_open': pos.price_open,
                'price_current': pos.price_current,
                'profit': pos.profit,
                'swap': pos.swap,
                'sl': pos.sl,
                'tp': pos.tp,
                'time_open': datetime.fromtimestamp(pos.time),
                'comment': pos.comment
            })
        
        return result
    
    def get_positions_summary(self):
        """Get summary of all EA positions"""
        positions = self.get_positions()
        
        if not positions:
            return {
                'total_positions': 0,
                'total_profit': 0.0,
                'by_symbol': {}
            }
        
        total_profit = sum(p['profit'] for p in positions)
        by_symbol = {}
        
        for pos in positions:
            symbol = pos['symbol']
            if symbol not in by_symbol:
                by_symbol[symbol] = {
                    'count': 0,
                    'total_profit': 0.0,
                    'total_volume': 0.0
                }
            by_symbol[symbol]['count'] += 1
            by_symbol[symbol]['total_profit'] += pos['profit']
            by_symbol[symbol]['total_volume'] += pos['volume']
        
        return {
            'total_positions': len(positions),
            'total_profit': total_profit,
            'by_symbol': by_symbol
        }
    
    def get_deal_history(self, from_date=None, to_date=None):
        """
        Get deal history for the EA
        
        Args:
            from_date: Start date (datetime)
            to_date: End date (datetime)
            
        Returns:
            DataFrame with deal history
        """
        if not self.connected:
            raise RuntimeError("Not connected to MT5. Call connect() first.")
        
        if from_date is None:
            from_date = datetime.now().replace(hour=0, minute=0, second=0)
        if to_date is None:
            to_date = datetime.now()
        
        # Convert to timestamp
        from_timestamp = int(from_date.timestamp())
        to_timestamp = int(to_date.timestamp())
        
        deals = mt5.history_deals_get(from_timestamp, to_timestamp)
        if deals is None:
            return pd.DataFrame()
        
        # Filter by magic number
        ea_deals = [deal for deal in deals if deal.magic == self.magic_number]
        
        if not ea_deals:
            return pd.DataFrame()
        
        # Convert to DataFrame
        deals_data = []
        for deal in ea_deals:
            deals_data.append({
                'ticket': deal.ticket,
                'order': deal.order,
                'time': datetime.fromtimestamp(deal.time),
                'type': deal.type,
                'entry': deal.entry,
                'symbol': deal.symbol,
                'volume': deal.volume,
                'price': deal.price,
                'profit': deal.profit,
                'swap': deal.swap,
                'commission': deal.commission,
                'comment': deal.comment
            })
        
        return pd.DataFrame(deals_data)
    
    def get_performance_stats(self, days=1):
        """
        Get performance statistics for the EA
        
        Args:
            days: Number of days to analyze
            
        Returns:
            Dictionary with performance statistics
        """
        if not self.connected:
            raise RuntimeError("Not connected to MT5. Call connect() first.")
        
        from_date = datetime.now().replace(hour=0, minute=0, second=0)
        from_date = from_date.replace(day=from_date.day - days)
        
        df = self.get_deal_history(from_date=from_date)
        
        if df.empty:
            return {
                'total_trades': 0,
                'winning_trades': 0,
                'losing_trades': 0,
                'win_rate': 0.0,
                'total_profit': 0.0,
                'total_loss': 0.0,
                'net_profit': 0.0,
                'average_win': 0.0,
                'average_loss': 0.0,
                'profit_factor': 0.0
            }
        
        # Filter closed positions (entry == DEAL_ENTRY_OUT)
        closed_trades = df[df['entry'] == mt5.DEAL_ENTRY_OUT].copy()
        
        if closed_trades.empty:
            return {
                'total_trades': 0,
                'winning_trades': 0,
                'losing_trades': 0,
                'win_rate': 0.0,
                'total_profit': 0.0,
                'total_loss': 0.0,
                'net_profit': 0.0,
                'average_win': 0.0,
                'average_loss': 0.0,
                'profit_factor': 0.0
            }
        
        winning = closed_trades[closed_trades['profit'] > 0]
        losing = closed_trades[closed_trades['profit'] < 0]
        
        total_profit = winning['profit'].sum() if not winning.empty else 0.0
        total_loss = abs(losing['profit'].sum()) if not losing.empty else 0.0
        
        return {
            'total_trades': len(closed_trades),
            'winning_trades': len(winning),
            'losing_trades': len(losing),
            'win_rate': (len(winning) / len(closed_trades) * 100) if len(closed_trades) > 0 else 0.0,
            'total_profit': total_profit,
            'total_loss': total_loss,
            'net_profit': closed_trades['profit'].sum(),
            'average_win': winning['profit'].mean() if not winning.empty else 0.0,
            'average_loss': losing['profit'].mean() if not losing.empty else 0.0,
            'profit_factor': (total_profit / total_loss) if total_loss > 0 else 0.0
        }
    
    def print_status(self):
        """Print current status of the EA"""
        print("\n" + "="*60)
        print("F_INX_Robot3 Status Report")
        print("="*60)
        
        # Current positions
        positions = self.get_positions()
        print(f"\n📊 Open Positions: {len(positions)}")
        
        if positions:
            for pos in positions:
                print(f"  • {pos['symbol']} {pos['type']} | "
                      f"Volume: {pos['volume']:.2f} | "
                      f"Profit: {pos['profit']:.2f} | "
                      f"SL: {pos['sl']:.5f} | TP: {pos['tp']:.5f}")
        
        # Positions summary
        summary = self.get_positions_summary()
        print(f"\n💰 Total Profit: {summary['total_profit']:.2f}")
        
        if summary['by_symbol']:
            print("\n📈 By Symbol:")
            for symbol, data in summary['by_symbol'].items():
                print(f"  • {symbol}: {data['count']} positions | "
                      f"Profit: {data['total_profit']:.2f} | "
                      f"Volume: {data['total_volume']:.2f}")
        
        # Performance stats
        stats = self.get_performance_stats(days=1)
        print(f"\n📊 Today's Performance:")
        print(f"  • Total Trades: {stats['total_trades']}")
        print(f"  • Win Rate: {stats['win_rate']:.2f}%")
        print(f"  • Net Profit: {stats['net_profit']:.2f}")
        print(f"  • Profit Factor: {stats['profit_factor']:.2f}")
        
        print("\n" + "="*60)
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()


# Example usage
if __name__ == "__main__":
    # Create manager instance
    manager = F_INX_Robot3Manager(magic_number=20251115)  # Default magic number from EA
    
    try:
        # Connect to MT5
        if manager.connect():
            print("✅ Connected to MT5")
            
            # Print status
            manager.print_status()
            
            # Get detailed performance stats
            print("\n📈 Detailed Performance (Last 7 days):")
            stats = manager.get_performance_stats(days=7)
            for key, value in stats.items():
                print(f"  • {key}: {value}")
            
        else:
            print("❌ Failed to connect to MT5")
    
    except Exception as e:
        print(f"❌ Error: {e}")
    
    finally:
        manager.disconnect()

