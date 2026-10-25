import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import streamlit as st
import time
import json
from backend.alert_system import alert_system
from backend.trade_history import log_trade

class TradingAgent:
    """Agent de trading automatisé pour exécuter les ordres"""
    
    def __init__(self):
        self.positions = []
        self.orders = []
        self.risk_management = {
            'max_position_size': 0.02,  # 2% du capital par position
            'max_daily_loss': 0.05,     # 5% de perte maximale par jour
            'stop_loss_pct': 0.02,      # 2% de stop loss
            'take_profit_pct': 0.04,    # 4% de take profit
            'max_positions': 5          # Maximum 5 positions simultanées
        }
        self.performance_metrics = {
            'total_trades': 0,
            'winning_trades': 0,
            'losing_trades': 0,
            'total_pnl': 0.0,
            'win_rate': 0.0,
            'avg_win': 0.0,
            'avg_loss': 0.0
        }
    
    def calculate_position_size(self, capital: float, risk_per_trade: float, 
                              entry_price: float, stop_loss: float) -> float:
        """Calcule la taille de position basée sur la gestion des risques"""
        risk_amount = capital * risk_per_trade
        price_risk = abs(entry_price - stop_loss)
        
        if price_risk > 0:
            position_size = risk_amount / price_risk
            return min(position_size, capital * self.risk_management['max_position_size'])
        return 0.0
    
    def validate_signal(self, signal: Dict, current_price: float, market_data: pd.DataFrame, ml_proba: float = 0.0, context: dict = {}, ml_threshold: float = 0.6) -> bool:
        """Valide un signal de trading avant exécution. Version débridée : autorise tous les signaux sauf NEUTRAL."""
        if not signal or signal.get('signal') == 'NEUTRAL':
            return False
        # Suppression de tous les blocages : autorise l'exécution automatique
        return True
    
    def execute_order(self, signal, symbol, current_price, capital, volume_risk_pct=0.01, manual_volume=None):
        if not signal or signal.get('confidence', 0) < 0.7:
            alert_system.add_alert(f"Ordre sur {symbol} non exécuté (dummy): Confiance trop faible ({signal.get('confidence',0):.2f})", "warning")
            return None
        
        order_type = signal['signal']
        # Use manual_volume if provided, else fallback to volume_risk_pct logic
        if manual_volume is not None:
            order_volume = manual_volume
        else:
            order_volume = (capital * volume_risk_pct) / current_price if volume_risk_pct is not None else 0.01
            order_volume = max(0.01, round(order_volume, 2))
        
        if "BOOM" in symbol.upper() or "CRASH" in symbol.upper():
            if order_type == 'BUY': sl = current_price * 0.998; tp = current_price * 1.005
            else: sl = current_price * 1.002; tp = current_price * 0.995
        else:
            if order_type == 'BUY': sl = current_price * 0.99; tp = current_price * 1.015
            else: sl = current_price * 1.01; tp = current_price * 0.985
        
        new_position = {
            'id': st.session_state.total_trades + 1,
            'symbol': symbol,
            'type': order_type,
            'volume': order_volume,
            'entry_price': current_price,
            'open_time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'stop_loss': sl,
            'take_profit': tp,
            'unrealized_pnl': 0.0
        }
        st.session_state.open_positions_list.append(new_position)
        st.session_state.total_trades += 1
        alert_system.add_alert(f"✅ EXÉCUTÉ (dummy): {order_type} {order_volume:.2f} {symbol} @ {current_price:.5f}", "success")
        return new_position
    
    def update_positions(self, current_prices: Dict[str, float]):
        """Met à jour les positions avec les prix actuels"""
        for position in self.positions:
            if position['status'] != 'OPEN':
                continue
            
            symbol = position['symbol']
            if symbol not in current_prices:
                continue
            
            current_price = current_prices[symbol]
            entry_price = position['entry_price']
            position_size = position['position_size']
            
            # Calculer le PnL non réalisé
            if position['type'] == 'BUY':
                unrealized_pnl = (current_price - entry_price) * position_size
            else:  # SELL
                unrealized_pnl = (entry_price - current_price) * position_size
            
            position['unrealized_pnl'] = unrealized_pnl
            position['current_price'] = current_price
            
            # Vérifier les stop loss et take profit
            if position['type'] == 'BUY':
                if current_price <= position['stop_loss']:
                    self.close_position(position, current_price, 'STOP_LOSS')
                elif current_price >= position['take_profit']:
                    self.close_position(position, current_price, 'TAKE_PROFIT')
            else:  # SELL
                if current_price >= position['stop_loss']:
                    self.close_position(position, current_price, 'STOP_LOSS')
                elif current_price <= position['take_profit']:
                    self.close_position(position, current_price, 'TAKE_PROFIT')
    
    def close_position(self, position: Dict, exit_price: float, reason: str):
        """Ferme une position"""
        entry_price = position['entry_price']
        position_size = position['position_size']
        
        # Calculer le PnL réalisé
        if position['type'] == 'BUY':
            realized_pnl = (exit_price - entry_price) * position_size
        else:  # SELL
            realized_pnl = (entry_price - exit_price) * position_size
        
        position['exit_price'] = exit_price
        position['exit_time'] = datetime.now()
        position['realized_pnl'] = realized_pnl
        position['status'] = 'CLOSED'
        position['close_reason'] = reason
        
        # Enregistrement dans l'historique des trades
        log_trade({
            'timestamp': datetime.now().isoformat(),
            'symbol': position.get('symbol', ''),
            'type': position.get('type', ''),
            'volume': position.get('position_size', ''),
            'entry_price': position.get('entry_price', ''),
            'exit_price': exit_price,
            'open_time': position.get('open_time', ''),
            'close_time': datetime.now().isoformat(),
            'stop_loss': position.get('stop_loss', ''),
            'take_profit': position.get('take_profit', ''),
            'result': realized_pnl,
            'confidence': position.get('confidence', ''),
            'reason': reason,
            'status': 'CLOSED'
        })
        # Mettre à jour les métriques de performance
        self.update_performance_metrics(realized_pnl)
    
    def update_performance_metrics(self, pnl: float):
        """Met à jour les métriques de performance"""
        self.performance_metrics['total_trades'] += 1
        self.performance_metrics['total_pnl'] += pnl
        
        if pnl > 0:
            self.performance_metrics['winning_trades'] += 1
            self.performance_metrics['avg_win'] = (
                (self.performance_metrics['avg_win'] * (self.performance_metrics['winning_trades'] - 1) + pnl) /
                self.performance_metrics['winning_trades']
            )
        else:
            self.performance_metrics['losing_trades'] += 1
            self.performance_metrics['avg_loss'] = (
                (self.performance_metrics['avg_loss'] * (self.performance_metrics['losing_trades'] - 1) + abs(pnl)) /
                self.performance_metrics['losing_trades']
            )
        
        # Calculer le taux de réussite
        if self.performance_metrics['total_trades'] > 0:
            self.performance_metrics['win_rate'] = (
                self.performance_metrics['winning_trades'] / self.performance_metrics['total_trades']
            )
    
    def get_performance_summary(self) -> Dict:
        """Récupère un résumé des performances"""
        return {
            'total_trades': self.performance_metrics['total_trades'],
            'win_rate': f"{self.performance_metrics['win_rate']:.2%}",
            'total_pnl': f"${self.performance_metrics['total_pnl']:.2f}",
            'avg_win': f"${self.performance_metrics['avg_win']:.2f}",
            'avg_loss': f"${self.performance_metrics['avg_loss']:.2f}",
            'open_positions': len([p for p in self.positions if p['status'] == 'OPEN']),
            'total_positions': len(self.positions)
        }
    
    def get_open_positions(self) -> List[Dict]:
        """Récupère les positions ouvertes"""
        return [p for p in self.positions if p['status'] == 'OPEN']
    
    def get_closed_positions(self) -> List[Dict]:
        """Récupère les positions fermées"""
        return [p for p in self.positions if p['status'] == 'CLOSED']
    
    def reset_agent(self):
        """Réinitialise l'agent de trading"""
        self.positions = []
        self.orders = []
        self.performance_metrics = {
            'total_trades': 0,
            'winning_trades': 0,
            'losing_trades': 0,
            'total_pnl': 0.0,
            'win_rate': 0.0,
            'avg_win': 0.0,
            'avg_loss': 0.0
        }

    def update_positions_pnl(self, current_prices: Dict[str, float]):
        """Alias for update_positions for frontend compatibility with the Streamlit frontend."""
        return self.update_positions(current_prices)

# Instance globale de l'agent de trading
trading_agent = TradingAgent() 