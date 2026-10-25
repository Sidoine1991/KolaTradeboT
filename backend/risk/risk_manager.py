"""
Gestionnaire de risque pour l'application de trading
"""
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
import pandas as pd
import numpy as np
import logging
from enum import Enum, auto
from datetime import datetime, timedelta

# Configuration du logger
logger = logging.getLogger(__name__)

class RiskLevel(Enum):
    """Niveaux de risque"""
    LOW = auto()
    MODERATE = auto()
    HIGH = auto()
    EXTREME = auto()

@dataclass
class Position:
    """Représente une position ouverte"""
    symbol: str
    position_type: str  # 'BUY' ou 'SELL'
    entry_price: float
    stop_loss: float
    take_profit: float
    size: float  # Taille de la position (en lots, unités, ou montant)
    entry_time: datetime = field(default_factory=datetime.utcnow)
    current_price: float = 0.0
    unrealized_pnl: float = 0.0
    risk_reward_ratio: float = 0.0
    risk_per_trade: float = 0.0  # En pourcentage du capital
    metadata: dict = field(default_factory=dict)

class RiskManager:
    """Gestionnaire de risque pour le trading"""
    
    def __init__(self, config: dict = None):
        """
        Initialise le gestionnaire de risque
        
        Args:
            config: Configuration du gestionnaire de risque
        """
        self.config = {
            'max_risk_per_trade': 0.02,  # 2% de risque par trade
            'max_daily_risk': 0.05,      # 5% de risque quotidien
            'max_portfolio_risk': 0.25,   # 25% de risque total du portefeuille
            'max_drawdown': 0.10,         # 10% de drawdown maximum
            'max_position_size': 0.1,     # 10% du capital par position
            'max_correlation': 0.7,       # Corrélation maximale entre positions
            'min_risk_reward': 1.5,       # Ratio risque/rendement minimum
            'volatility_period': 21,      # Période pour le calcul de la volatilité (jours)
            'max_leverage': 10.0,         # Effet de levier maximum
        }
        
        # Mise à jour avec la configuration fournie
        if config:
            self.config.update(config)
        
        # État interne
        self.positions: Dict[str, Position] = {}
        self.equity_curve = []  # Historique de l'équité
        self.trade_history = []  # Historique des trades
        self.daily_pnl = []     # PnL quotidien
        
        # Métriques de risque
        self.current_drawdown = 0.0
        self.max_drawdown = 0.0
        self.sharpe_ratio = 0.0
        self.sortino_ratio = 0.0
        self.win_rate = 0.0
        self.profit_factor = 0.0
        
        logger.info("Gestionnaire de risque initialisé")
    
    def calculate_position_size(
        self, 
        entry_price: float, 
        stop_loss: float, 
        account_balance: float,
        risk_per_trade: Optional[float] = None
    ) -> Tuple[float, float]:
        """
        Calcule la taille de position optimale en fonction du risque
        
        Args:
            entry_price: Prix d'entrée
            stop_loss: Niveau de stop loss
            account_balance: Solde du compte
            risk_per_trade: Pourcentage du capital à risquer (optionnel, utilise la valeur par défaut si non fourni)
            
        Returns:
            Tuple (taille de position, montant en risque)
        """
        if risk_per_trade is None:
            risk_per_trade = self.config['max_risk_per_trade']
        
        # Calcul du risque par unité
        risk_per_unit = abs(entry_price - stop_loss)
        
        if risk_per_unit <= 0 or account_balance <= 0:
            return 0.0, 0.0
        
        # Calcul du montant à risquer
        risk_amount = account_balance * risk_per_trade
        
        # Calcul de la taille de position
        position_size = risk_amount / risk_per_unit
        
        # Vérification de la taille maximale de position
        max_position_size = account_balance * self.config['max_position_size'] / entry_price
        position_size = min(position_size, max_position_size)
        
        return position_size, risk_amount
    
    def validate_trade(
        self, 
        symbol: str, 
        position_type: str, 
        entry_price: float, 
        stop_loss: float, 
        take_profit: float, 
        position_size: float,
        account_balance: float,
        market_data: Optional[pd.DataFrame] = None
    ) -> Tuple[bool, str]:
        """
        Valide un trade potentiel par rapport aux règles de risque
        
        Args:
            symbol: Symbole du trade
            position_type: Type de position ('BUY' ou 'SELL')
            entry_price: Prix d'entrée
            stop_loss: Niveau de stop loss
            take_profit: Niveau de take profit
            position_size: Taille de la position
            account_balance: Solde du compte
            market_data: Données de marché pour analyse supplémentaire
            
        Returns:
            Tuple (est_valide, raison)
        """
        # Vérification des paramètres de base
        if entry_price <= 0 or position_size <= 0 or account_balance <= 0:
            return False, "Paramètres de trade invalides"
        
        # Calcul du risque/rendement
        risk = abs(entry_price - stop_loss)
        reward = abs(take_profit - entry_price)
        
        if risk <= 0:
            return False, "Le stop loss doit être différent du prix d'entrée"
        
        risk_reward_ratio = reward / risk
        
        # Vérification du ratio risque/rendement minimum
        if risk_reward_ratio < self.config['min_risk_reward']:
            return False, f"Ratio risque/rendement ({risk_reward_ratio:.2f}) inférieur au minimum requis ({self.config['min_risk_reward']})"
        
        # Calcul du risque en pourcentage du capital
        risk_percent = (risk * position_size) / account_balance
        
        # Vérification du risque par trade
        if risk_percent > self.config['max_risk_per_trade']:
            return False, f"Risque par trade ({risk_percent*100:.2f}%) supérieur au maximum autorisé ({self.config['max_risk_per_trade']*100}%)"
        
        # Vérification de la taille de position
        position_value = position_size * entry_price
        max_position_value = account_balance * self.config['max_position_size']
        
        if position_value > max_position_value:
            return False, f"Taille de position ({position_value:.2f}) supérieure au maximum autorisé ({max_position_value:.2f})"
        
        # Vérification de la corrélation avec les positions existantes
        if self._has_high_correlation(symbol, market_data):
            return False, "Corrélation élevée avec une position existante"
        
        # Vérification du risque quotidien
        if self._exceeds_daily_risk(account_balance):
            return False, "Risque quotidien maximum atteint"
        
        # Vérification du drawdown
        if self.current_drawdown > self.config['max_drawdown']:
            return False, f"Drawdown actuel ({self.current_drawdown*100:.2f}%) supérieur au maximum autorisé ({self.config['max_drawdown']*100}%)"
        
        return True, "Trade valide"
    
    def add_position(self, position: Position):
        """
        Ajoute une position au gestionnaire de risque
        
        Args:
            position: Position à ajouter
        """
        position_id = f"{position.symbol}_{position.entry_time.strftime('%Y%m%d_%H%M%S')}"
        self.positions[position_id] = position
        logger.info(f"Position ajoutée: {position_id}")
    
    def update_position(self, position_id: str, current_price: float):
        """
        Met à jour le prix actuel d'une position et calcule le PnL non réalisé
        
        Args:
            position_id: Identifiant de la position
            current_price: Prix actuel du marché
        """
        if position_id not in self.positions:
            logger.warning(f"Position non trouvée: {position_id}")
            return
        
        position = self.positions[position_id]
        position.current_price = current_price
        
        # Calcul du PnL non réalisé
        if position.position_type.upper() == 'BUY':
            position.unrealized_pnl = (current_price - position.entry_price) * position.size
        else:  # SELL
            position.unrealized_pnl = (position.entry_price - current_price) * position.size
        
        # Mise à jour du risque/rendement
        if position.entry_price != position.stop_loss:
            risk = abs(position.entry_price - position.stop_loss)
            reward = abs(position.take_profit - position.entry_price)
            position.risk_reward_ratio = reward / risk if risk > 0 else 0.0
    
    def close_position(self, position_id: str, exit_price: float, exit_time: Optional[datetime] = None):
        """
        Ferme une position et met à jour les métriques de risque
        
        Args:
            position_id: Identifiant de la position
            exit_price: Prix de sortie
            exit_time: Heure de sortie (par défaut maintenant)
        """
        if position_id not in self.positions:
            logger.warning(f"Position non trouvée: {position_id}")
            return None
        
        position = self.positions[position_id]
        exit_time = exit_time or datetime.utcnow()
        
        # Calcul du PnL réalisé
        if position.position_type.upper() == 'BUY':
            pnl = (exit_price - position.entry_price) * position.size
        else:  # SELL
            pnl = (position.entry_price - exit_price) * position.size
        
        # Mise à jour de l'historique
        trade = {
            'position_id': position_id,
            'symbol': position.symbol,
            'position_type': position.position_type,
            'entry_price': position.entry_price,
            'exit_price': exit_price,
            'size': position.size,
            'entry_time': position.entry_time,
            'exit_time': exit_time,
            'pnl': pnl,
            'pnl_pct': (pnl / (position.entry_price * position.size)) * 100 if position.entry_price > 0 else 0.0,
            'risk_reward_ratio': position.risk_reward_ratio,
            'risk_per_trade': position.risk_per_trade,
            'duration': (exit_time - position.entry_time).total_seconds() / 60  # en minutes
        }
        
        self.trade_history.append(trade)
        
        # Mise à jour des métriques de performance
        self._update_performance_metrics()
        
        # Suppression de la position
        del self.positions[position_id]
        
        logger.info(f"Position fermée: {position_id} - PnL: {pnl:.2f}")
        
        return trade
    
    def _has_high_correlation(self, symbol: str, market_data: Optional[pd.DataFrame] = None) -> bool:
        """Vérifie si le symbole est fortement corrélé avec des positions existantes"""
        # Implémentation simplifiée - à améliorer avec une analyse de corrélation réelle
        if not self.positions:
            return False
        
        # Vérification des symboles identiques
        for pos_id, position in self.positions.items():
            if position.symbol == symbol:
                return True
        
        # Ici, on pourrait ajouter une analyse de corrélation basée sur les données de marché
        
        return False
    
    def _exceeds_daily_risk(self, account_balance: float) -> bool:
        """Vérifie si le risque quotidien maximum est dépassé"""
        if not self.daily_pnl:
            return False
        
        # Calcul du PnL quotidien
        today = datetime.utcnow().date()
        today_pnl = sum(
            trade['pnl'] for trade in self.trade_history 
            if trade['exit_time'].date() == today
        )
        
        # Calcul du risque quotidien
        daily_risk = abs(today_pnl) / account_balance if account_balance > 0 else 0.0
        
        return daily_risk > self.config['max_daily_risk']
    
    def _update_performance_metrics(self):
        """Met à jour les métriques de performance"""
        if not self.trade_history:
            return
        
        # Calcul du PnL total
        total_pnl = sum(trade['pnl'] for trade in self.trade_history)
        
        # Taux de réussite
        winning_trades = [t for t in self.trade_history if t['pnl'] > 0]
        self.win_rate = len(winning_trades) / len(self.trade_history) if self.trade_history else 0.0
        
        # Profit factor
        gross_profit = sum(t['pnl'] for t in self.trade_history if t['pnl'] > 0)
        gross_loss = abs(sum(t['pnl'] for t in self.trade_history if t['pnl'] < 0))
        self.profit_factor = gross_profit / gross_loss if gross_loss > 0 else float('inf')
        
        # Mise à jour de la courbe d'équité
        self.equity_curve.append({
            'timestamp': datetime.utcnow(),
            'equity': total_pnl,
            'drawdown': self._calculate_drawdown()
        })
        
        # Mise à jour du drawdown
        self.current_drawdown = self._calculate_drawdown()
        self.max_drawdown = max(self.max_drawdown, self.current_drawdown)
        
        # Calcul des ratios de performance (simplifié)
        self._calculate_performance_ratios()
    
    def _calculate_drawdown(self) -> float:
        """Calcule le drawdown actuel"""
        if not self.equity_curve:
            return 0.0
        
        equity_values = [e['equity'] for e in self.equity_curve]
        peak = max(equity_values)
        current = equity_values[-1]
        
        return (peak - current) / peak if peak > 0 else 0.0
    
    def _calculate_performance_ratios(self):
        """Calcule les ratios de performance (Sharpe, Sortino, etc.)"""
        if len(self.equity_curve) < 2:
            return
        
        # Calcul des rendements
        returns = []
        for i in range(1, len(self.equity_curve)):
            prev_equity = self.equity_curve[i-1]['equity']
            curr_equity = self.equity_curve[i]['equity']
            returns.append((curr_equity - prev_equity) / prev_equity if prev_equity > 0 else 0.0)
        
        if not returns:
            return
        
        # Ratio de Sharpe (simplifié, sans taux sans risque)
        mean_return = np.mean(returns)
        std_return = np.std(returns)
        self.sharpe_ratio = mean_return / std_return if std_return > 0 else 0.0
        
        # Ratio de Sortino (simplifié, ne considère que les rendements négatifs)
        negative_returns = [r for r in returns if r < 0]
        downside_std = np.std(negative_returns) if negative_returns else 0.0
        self.sortino_ratio = mean_return / downside_std if downside_std > 0 else 0.0
    
    def get_risk_level(self) -> RiskLevel:
        """Retourne le niveau de risque actuel"""
        if self.current_drawdown > self.config['max_drawdown'] * 0.8:
            return RiskLevel.EXTREME
        elif self.current_drawdown > self.config['max_drawdown'] * 0.5:
            return RiskLevel.HIGH
        elif self.current_drawdown > 0:
            return RiskLevel.MODERATE
        return RiskLevel.LOW
    
    def get_risk_report(self) -> dict:
        """Génère un rapport de risque détaillé"""
        return {
            'current_drawdown': self.current_drawdown,
            'max_drawdown': self.max_drawdown,
            'sharpe_ratio': self.sharpe_ratio,
            'sortino_ratio': self.sortino_ratio,
            'win_rate': self.win_rate,
            'profit_factor': self.profit_factor,
            'open_positions': len(self.positions),
            'total_trades': len(self.trade_history),
            'winning_trades': len([t for t in self.trade_history if t['pnl'] > 0]),
            'losing_trades': len([t for t in self.trade_history if t['pnl'] <= 0]),
            'total_pnl': sum(t['pnl'] for t in self.trade_history),
            'risk_level': self.get_risk_level().name
        }
