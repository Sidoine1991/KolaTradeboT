"""
Gestionnaire de risque avancé pour le trading des indices synthétiques
Basé sur les principes de Vince Stanzione et les meilleures pratiques
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

class RiskManager:
    """
    Gestionnaire de risque avancé pour les indices synthétiques
    """
    
    def __init__(self, account_balance: float = 1000.0):
        self.account_balance = account_balance
        self.max_risk_per_trade = 0.02  # 2% par trade
        self.max_daily_risk = 0.06  # 6% par jour
        self.max_drawdown = 0.20  # 20% de drawdown maximum
        self.daily_losses = 0.0
        self.consecutive_losses = 0
        self.max_consecutive_losses = 3
        
    def calculate_position_size(self, entry_price: float, stop_loss: float, 
                              risk_amount: Optional[float] = None) -> Dict:
        """
        Calculer la taille de position basée sur le risque
        """
        if risk_amount is None:
            risk_amount = self.account_balance * self.max_risk_per_trade
        
        # Calculer la distance du stop loss
        stop_distance = abs(entry_price - stop_loss)
        
        if stop_distance == 0:
            return {
                'position_size': 0,
                'risk_amount': 0,
                'risk_percentage': 0,
                'error': 'Stop loss trop proche du prix d\'entrée'
            }
        
        # Calculer la taille de position
        position_size = risk_amount / stop_distance
        
        # Calculer le pourcentage de risque
        risk_percentage = (risk_amount / self.account_balance) * 100
        
        return {
            'position_size': position_size,
            'risk_amount': risk_amount,
            'risk_percentage': risk_percentage,
            'stop_distance': stop_distance,
            'max_loss': risk_amount
        }
    
    def calculate_stop_loss(self, entry_price: float, direction: str, 
                           volatility: float, atr: float) -> Dict:
        """
        Calculer le stop loss optimal basé sur la volatilité
        """
        if direction.upper() == 'BUY':
            # Stop loss pour position longue
            stop_loss = entry_price - (atr * 2)  # 2x ATR
            stop_loss = max(stop_loss, entry_price * 0.98)  # Maximum 2% de perte
        else:
            # Stop loss pour position courte
            stop_loss = entry_price + (atr * 2)  # 2x ATR
            stop_loss = min(stop_loss, entry_price * 1.02)  # Maximum 2% de perte
        
        return {
            'stop_loss': stop_loss,
            'stop_distance': abs(entry_price - stop_loss),
            'stop_percentage': abs(entry_price - stop_loss) / entry_price * 100
        }
    
    def calculate_take_profit(self, entry_price: float, direction: str, 
                            stop_loss: float, risk_reward_ratio: float = 2.0) -> Dict:
        """
        Calculer le take profit basé sur le ratio risque/récompense
        """
        stop_distance = abs(entry_price - stop_loss)
        
        if direction.upper() == 'BUY':
            take_profit = entry_price + (stop_distance * risk_reward_ratio)
        else:
            take_profit = entry_price - (stop_distance * risk_reward_ratio)
        
        return {
            'take_profit': take_profit,
            'profit_distance': abs(entry_price - take_profit),
            'profit_percentage': abs(entry_price - take_profit) / entry_price * 100,
            'risk_reward_ratio': risk_reward_ratio
        }
    
    def check_risk_limits(self, trade_risk: float) -> Dict:
        """
        Vérifier si le trade respecte les limites de risque
        """
        # Vérifier le risque par trade
        if trade_risk > self.max_risk_per_trade:
            return {
                'allowed': False,
                'reason': f'Risque par trade trop élevé: {trade_risk:.2%} > {self.max_risk_per_trade:.2%}'
            }
        
        # Vérifier le risque quotidien
        if self.daily_losses + trade_risk > self.max_daily_risk:
            return {
                'allowed': False,
                'reason': f'Risque quotidien dépassé: {self.daily_losses + trade_risk:.2%} > {self.max_daily_risk:.2%}'
            }
        
        # Vérifier les pertes consécutives
        if self.consecutive_losses >= self.max_consecutive_losses:
            return {
                'allowed': False,
                'reason': f'Trop de pertes consécutives: {self.consecutive_losses} >= {self.max_consecutive_losses}'
            }
        
        # Vérifier le drawdown
        current_drawdown = self.daily_losses / self.account_balance
        if current_drawdown > self.max_drawdown:
            return {
                'allowed': False,
                'reason': f'Drawdown trop élevé: {current_drawdown:.2%} > {self.max_drawdown:.2%}'
            }
        
        return {
            'allowed': True,
            'reason': 'Trade autorisé'
        }
    
    def update_trade_result(self, trade_result: float, trade_risk: float):
        """
        Mettre à jour les statistiques après un trade
        """
        if trade_result < 0:
            # Trade perdant
            self.daily_losses += abs(trade_result)
            self.consecutive_losses += 1
        else:
            # Trade gagnant
            self.consecutive_losses = 0
        
        # Mettre à jour le solde du compte
        self.account_balance += trade_result
    
    def get_risk_summary(self) -> Dict:
        """
        Obtenir un résumé de l'état du risque
        """
        daily_risk_used = (self.daily_losses / self.account_balance) * 100
        remaining_daily_risk = self.max_daily_risk - (self.daily_losses / self.account_balance)
        
        return {
            'account_balance': self.account_balance,
            'daily_losses': self.daily_losses,
            'daily_risk_used': daily_risk_used,
            'remaining_daily_risk': remaining_daily_risk,
            'consecutive_losses': self.consecutive_losses,
            'max_consecutive_losses': self.max_consecutive_losses,
            'can_trade': self.consecutive_losses < self.max_consecutive_losses and daily_risk_used < self.max_daily_risk * 100
        }
    
    def reset_daily_stats(self):
        """
        Réinitialiser les statistiques quotidiennes
        """
        self.daily_losses = 0.0
        self.consecutive_losses = 0
    
    def get_trading_recommendations(self, current_price: float, volatility: float, 
                                  atr: float, signal_strength: float) -> Dict:
        """
        Obtenir des recommandations de trading basées sur le risque
        """
        # Calculer le stop loss optimal
        stop_loss_info = self.calculate_stop_loss(current_price, 'BUY', volatility, atr)
        
        # Calculer la taille de position
        position_info = self.calculate_position_size(
            current_price, 
            stop_loss_info['stop_loss']
        )
        
        # Calculer le take profit
        take_profit_info = self.calculate_take_profit(
            current_price, 
            'BUY', 
            stop_loss_info['stop_loss']
        )
        
        # Vérifier les limites de risque
        risk_check = self.check_risk_limits(position_info['risk_percentage'] / 100)
        
        # Ajuster la taille de position si nécessaire
        if not risk_check['allowed']:
            # Réduire la taille de position
            max_risk = self.max_risk_per_trade * 0.5  # Réduire à 1%
            position_info = self.calculate_position_size(
                current_price, 
                stop_loss_info['stop_loss'],
                self.account_balance * max_risk
            )
        
        return {
            'entry_price': current_price,
            'stop_loss': stop_loss_info['stop_loss'],
            'take_profit': take_profit_info['take_profit'],
            'position_size': position_info['position_size'],
            'risk_amount': position_info['risk_amount'],
            'risk_percentage': position_info['risk_percentage'],
            'profit_potential': take_profit_info['profit_percentage'],
            'risk_reward_ratio': take_profit_info['risk_reward_ratio'],
            'trade_allowed': risk_check['allowed'],
            'risk_reason': risk_check['reason'],
            'recommendations': self._get_specific_recommendations(signal_strength, volatility)
        }
    
    def _get_specific_recommendations(self, signal_strength: float, volatility: float) -> List[str]:
        """
        Obtenir des recommandations spécifiques basées sur les conditions du marché
        """
        recommendations = []
        
        # Recommandations basées sur la force du signal
        if signal_strength > 0.8:
            recommendations.append("Signal très fort - Trade recommandé")
        elif signal_strength > 0.6:
            recommendations.append("Signal modéré - Trade avec prudence")
        else:
            recommendations.append("Signal faible - Éviter le trade")
        
        # Recommandations basées sur la volatilité
        if volatility > 0.05:  # 5% de volatilité
            recommendations.append("Volatilité élevée - Réduire la taille de position")
            recommendations.append("Utiliser des stops plus larges")
        elif volatility < 0.01:  # 1% de volatilité
            recommendations.append("Volatilité faible - Trade range-bound possible")
        
        # Recommandations basées sur les pertes consécutives
        if self.consecutive_losses >= 2:
            recommendations.append("Pertes consécutives - Réduire la taille de position")
            recommendations.append("Attendre un signal plus fort")
        
        # Recommandations basées sur le risque quotidien
        daily_risk_used = (self.daily_losses / self.account_balance) * 100
        if daily_risk_used > 3:  # 3% de perte quotidienne
            recommendations.append("Risque quotidien élevé - Arrêter de trader")
        
        return recommendations
    
    def calculate_portfolio_risk(self, positions: List[Dict]) -> Dict:
        """
        Calculer le risque du portefeuille
        """
        total_risk = 0
        total_exposure = 0
        
        for position in positions:
            position_risk = position.get('risk_amount', 0)
            position_exposure = position.get('position_size', 0) * position.get('entry_price', 0)
            
            total_risk += position_risk
            total_exposure += position_exposure
        
        portfolio_risk_percentage = (total_risk / self.account_balance) * 100
        leverage = total_exposure / self.account_balance
        
        return {
            'total_risk': total_risk,
            'total_exposure': total_exposure,
            'portfolio_risk_percentage': portfolio_risk_percentage,
            'leverage': leverage,
            'risk_status': 'HIGH' if portfolio_risk_percentage > 10 else 'MODERATE' if portfolio_risk_percentage > 5 else 'LOW'
        }
    
    def get_risk_metrics(self, df: pd.DataFrame) -> Dict:
        """
        Calculer les métriques de risque basées sur les données historiques
        """
        if df.empty:
            return {}
        
        # Calculer les retours
        returns = df['close'].pct_change().dropna()
        
        # Métriques de risque
        volatility = returns.std() * np.sqrt(252)  # Volatilité annualisée
        sharpe_ratio = returns.mean() / returns.std() * np.sqrt(252) if returns.std() > 0 else 0
        max_drawdown = self._calculate_max_drawdown(returns)
        var_95 = np.percentile(returns, 5)  # Value at Risk 95%
        
        # Calculer les probabilités de perte
        loss_probability = (returns < 0).mean()
        large_loss_probability = (returns < -0.02).mean()  # Probabilité de perte > 2%
        
        return {
            'volatility': volatility,
            'sharpe_ratio': sharpe_ratio,
            'max_drawdown': max_drawdown,
            'var_95': var_95,
            'loss_probability': loss_probability,
            'large_loss_probability': large_loss_probability,
            'risk_level': self._assess_risk_level(volatility, max_drawdown, large_loss_probability)
        }
    
    def _calculate_max_drawdown(self, returns: pd.Series) -> float:
        """
        Calculer le drawdown maximum
        """
        cumulative = (1 + returns).cumprod()
        running_max = cumulative.expanding().max()
        drawdown = (cumulative - running_max) / running_max
        return drawdown.min()
    
    def _assess_risk_level(self, volatility: float, max_drawdown: float, 
                          large_loss_probability: float) -> str:
        """
        Évaluer le niveau de risque
        """
        risk_score = 0
        
        if volatility > 0.3:
            risk_score += 3
        elif volatility > 0.2:
            risk_score += 2
        elif volatility > 0.1:
            risk_score += 1
        
        if max_drawdown < -0.3:
            risk_score += 3
        elif max_drawdown < -0.2:
            risk_score += 2
        elif max_drawdown < -0.1:
            risk_score += 1
        
        if large_loss_probability > 0.1:
            risk_score += 2
        elif large_loss_probability > 0.05:
            risk_score += 1
        
        if risk_score >= 6:
            return 'VERY_HIGH'
        elif risk_score >= 4:
            return 'HIGH'
        elif risk_score >= 2:
            return 'MODERATE'
        else:
            return 'LOW'
