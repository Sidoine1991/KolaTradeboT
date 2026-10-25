#!/usr/bin/env python3
"""
Système de Trading Automatique Amélioré pour EA SpikeHunter
Gestion intelligente des trades avec prédictions avancées

⚠️ SYSTÈME DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 pour l'exécution automatique
"""

# ===================================================================
# SYSTÈME D'EXÉCUTION AUTOMATIQUE DÉSACTIVÉ
# Ce fichier est désactivé - Le système unique d'exécution est maintenant
# centralisé dans l'EA MQL5 AngelOfSpike.mq5 avec probabilité M1
# ===================================================================

DISABLED = True  # SYSTÈME DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 uniquement

if DISABLED:
    print("⚠️ ENHANCED EA TRADING DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 pour l'exécution automatique")
    print("🎯 Système unifié: Probabilité M1 >= 85% pour exécution automatique")
    print("🚫 Interdiction totale des trades multiples")
    exit()

# Code original désactivé ci-dessous...

import json
import time
import requests
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
import threading
import queue

class EnhancedEATrading:
    def __init__(self):
        self.api_url = "http://localhost:8001/trend"
        self.trading_queue = queue.Queue()
        self.active_trades = {}
        self.trade_history = []
        self.max_concurrent_trades = 3
        self.max_daily_trades = 20
        self.daily_trade_count = 0
        self.last_reset_date = datetime.now().date()
        self.daily_realized_pnl = 0.0
        self.daily_unrealized_pnl = 0.0
        self.daily_stop_gain = 50.0  # Stop trading for the day if >= +$50
        self.daily_stop_loss = -10.0 # Stop trading for the day if <= -$10
        
        # Configuration de trading
        self.trading_config = {
            'min_confidence': 'ultra_high',  # Exiger la confiance maximale
            'max_risk_per_trade': 1.0,  # $1 max par trade
            'target_profit_per_trade': 1.5,  # $1.50 objectif
            'stop_loss_percentage': 0.2,  # 20% du capital par trade
            'take_profit_percentage': 0.3,  # 30% du capital par trade
            'cooldown_between_trades': 300,  # 5 minutes
            'max_daily_loss': 5.0,  # $5 max perte journalière
            'emergency_stop_loss': 10.0  # $10 arrêt d'urgence
        }

        # Etat de renforcement (reward) adaptatif
        self.reward_state = {
            'confidence_bias': 0,            # [-2, +2] appliqué au niveau min de confiance
            'lot_gain_multiplier': 1.0,      # multiplicateur supplémentaire pour la taille de lot
            'win_streak': 0,
            'loss_streak': 0
        }
        self._confidence_levels_order = ['low', 'medium', 'high', 'very_high', 'ultra_high']
        
        # Statistiques
        self.stats = {
            'total_trades': 0,
            'winning_trades': 0,
            'losing_trades': 0,
            'total_profit': 0.0,
            'total_loss': 0.0,
            'win_rate': 0.0,
            'avg_profit_per_trade': 0.0,
            'max_drawdown': 0.0,
            'current_drawdown': 0.0
        }
    
    def reset_daily_counters(self):
        """Remet à zéro les compteurs journaliers"""
        current_date = datetime.now().date()
        if current_date != self.last_reset_date:
            self.daily_trade_count = 0
            self.daily_realized_pnl = 0.0
            self.daily_unrealized_pnl = 0.0
            self.last_reset_date = current_date
            print(f"Compteurs journaliers reinitialises pour {current_date}")
    
    def get_trend_prediction(self, symbol: str) -> Optional[Dict]:
        """Récupère la prédiction de tendance depuis l'API"""
        try:
            response = requests.get(
                f"{self.api_url}?symbol={symbol}&timeframe=M1",
                timeout=5
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Erreur API: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"Erreur connexion API: {e}")
            return None
    
    def should_open_trade(self, prediction: Dict) -> bool:
        """Détermine si un trade doit être ouvert"""
        # Vérifier les limites journalières
        self.reset_daily_counters()
        # Gate by daily realized PnL
        if self.daily_realized_pnl >= self.daily_stop_gain:
            print("Objectif journalier atteint (+$50). Arrêt des entrées.")
            return False
        if self.daily_realized_pnl <= self.daily_stop_loss:
            print("Perte journalière atteinte (-$10). Arrêt des entrées.")
            return False
        if self.daily_trade_count >= self.trading_config.get('max_daily_trades', 20):
            print("Limite journaliere de trades atteinte")
            return False
        
        # Vérifier le nombre de trades simultanés
        if len(self.active_trades) >= 2:  # max 2 positions simultanées
            print("Nombre maximum de trades simultanes atteint")
            return False
        
        # Un seul trade par symbole simultanément
        symbol = prediction.get('symbol', 'EURUSD')
        if any(t.get('symbol') == symbol for t in self.active_trades.values()):
            print(f"Trade déjà ouvert pour {symbol}, on attend la clôture.")
            return False
        
        # Vérifier le niveau de confiance (avec biais adaptatif)
        confidence = prediction.get('confidence', 'low')
        min_confidence = self._get_dynamic_min_confidence()
        
        confidence_levels = {
            'ultra_high': 5,
            'very_high': 4,
            'high': 3,
            'medium': 2,
            'low': 1
        }
        
        if confidence_levels.get(confidence, 0) < confidence_levels.get(min_confidence, 0):
            print(f"Confiance insuffisante: {confidence} < {min_confidence}")
            return False
        
        # Vérifier le signal de trading
        trading_signal = prediction.get('trading_signal', 'MONITOR')
        if trading_signal != 'TRADE':
            print(f"Signal non favorable: {trading_signal}")
            return False
        
        # Vérifier la probabilité/niveau de spike >= 90%
        spike_probability = prediction.get('spike_probability', 0.0)
        if spike_probability < 0.9:
            print(f"Probabilite spike insuffisante: {spike_probability:.1%} < 90.0%")
            return False
        
        return True
    
    def calculate_trade_parameters(self, prediction: Dict) -> Dict:
        """Calcule les paramètres du trade"""
        symbol = prediction.get('symbol', 'EURUSD')
        direction = prediction.get('trend_direction', 'HOLD')
        confidence = prediction.get('confidence', 'medium')
        
        # Calculer la taille du lot selon la confiance
        base_lot = 0.1
        confidence_multipliers = {
            'ultra_high': 2.0,
            'very_high': 1.5,
            'high': 1.0,
            'medium': 0.5,
            'low': 0.1
        }
        
        lot_size = max(0.5, base_lot * confidence_multipliers.get(confidence, 0.5) * self._get_dynamic_lot_multiplier())
        
        # Calculer SL/TP
        current_price = prediction.get('current_price', 1.0000)
        stop_loss = prediction.get('stop_loss', current_price * 0.999)
        take_profit = prediction.get('take_profit', current_price * 1.001)
        
        # Ajuster selon la direction
        if direction == 'SELL':
            stop_loss, take_profit = take_profit, stop_loss
        
        return {
            'symbol': symbol,
            'direction': direction,
            'lot_size': lot_size,
            'entry_price': current_price,
            'stop_loss': stop_loss,
            'take_profit': take_profit,
            'confidence': confidence,
            'spike_probability': prediction.get('spike_probability', 0.5),
            'time_to_spike': prediction.get('time_to_spike', 300),
            'reasoning': prediction.get('reasoning', 'Analyse standard')
        }

    def _get_dynamic_min_confidence(self) -> str:
        """Calcule le niveau min de confiance avec biais de reward."""
        base_level = self.trading_config.get('min_confidence', 'high')
        try:
            base_idx = self._confidence_levels_order.index(base_level)
        except ValueError:
            base_idx = 2  # 'high'
        shifted = base_idx + self.reward_state.get('confidence_bias', 0)
        shifted = max(0, min(shifted, len(self._confidence_levels_order) - 1))
        return self._confidence_levels_order[shifted]

    def _get_dynamic_lot_multiplier(self) -> float:
        """Multiplicateur de lot plafonné pour éviter la sur-exposition."""
        mult = self.reward_state.get('lot_gain_multiplier', 1.0)
        return max(0.5, min(mult, 3.0))

    def _apply_reward_on_win(self):
        """Renforce les paramètres après un gain."""
        self.reward_state['win_streak'] += 1
        self.reward_state['loss_streak'] = 0
        if self.reward_state['win_streak'] >= 2:
            self.reward_state['confidence_bias'] = max(-1, self.reward_state['confidence_bias'] - 1)
        increment = 0.1 if self.reward_state['win_streak'] < 3 else 0.2
        self.reward_state['lot_gain_multiplier'] = min(3.0, self.reward_state['lot_gain_multiplier'] + increment)

    def _apply_penalty_on_loss(self):
        """Réduit le risque après une perte."""
        self.reward_state['loss_streak'] += 1
        self.reward_state['win_streak'] = 0
        bump = 1 if self.reward_state['loss_streak'] == 1 else 2
        self.reward_state['confidence_bias'] = min(2, self.reward_state['confidence_bias'] + bump)
        self.reward_state['lot_gain_multiplier'] = max(0.1, self.reward_state['lot_gain_multiplier'] * 0.6)
    
    def execute_trade(self, trade_params: Dict) -> bool:
        """Exécute un trade (simulation)"""
        try:
            trade_id = f"TRADE_{int(time.time())}"
            
            # Simuler l'exécution du trade
            trade = {
                'id': trade_id,
                'timestamp': time.time(),
                'symbol': trade_params['symbol'],
                'direction': trade_params['direction'],
                'lot_size': trade_params['lot_size'],
                'entry_price': trade_params['entry_price'],
                'stop_loss': trade_params['stop_loss'],
                'take_profit': trade_params['take_profit'],
                'confidence': trade_params['confidence'],
                'spike_probability': trade_params['spike_probability'],
                'status': 'OPEN',
                'profit_loss': 0.0,
                'reasoning': trade_params['reasoning']
            }
            
            # Ajouter aux trades actifs
            self.active_trades[trade_id] = trade
            self.daily_trade_count += 1
            self.stats['total_trades'] += 1
            
            print(f"Trade ouvert: {trade_id}")
            print(f"   Symbole: {trade['symbol']}")
            print(f"   Direction: {trade['direction']}")
            print(f"   Lot: {trade['lot_size']}")
            print(f"   Prix entrée: {trade['entry_price']}")
            print(f"   SL: {trade['stop_loss']}")
            print(f"   TP: {trade['take_profit']}")
            print(f"   Confiance: {trade['confidence']}")
            print(f"   Probabilité spike: {trade['spike_probability']:.1%}")
            print(f"   Raison: {trade['reasoning']}")
            
            return True
            
        except Exception as e:
            print(f"Erreur execution trade: {e}")
            return False
    
    def monitor_active_trades(self):
        """Surveille les trades actifs"""
        trades_to_close = []
        
        for trade_id, trade in self.active_trades.items():
            # Simuler la surveillance du trade
            # En réalité, récupérer les données depuis MT5
            
            # Vérifier si le trade doit être fermé
            should_close, close_reason = self._should_close_trade(trade)
            
            if should_close:
                trades_to_close.append((trade_id, close_reason))
        
        # Fermer les trades qui doivent être fermés
        for trade_id, close_reason in trades_to_close:
            self.close_trade(trade_id, close_reason)
    
    def _should_close_trade(self, trade: Dict) -> tuple:
        """Détermine si un trade doit être fermé"""
        # Vérifier le temps écoulé
        trade_age = time.time() - trade['timestamp']
        max_trade_duration = trade.get('time_to_spike', 300) + 60  # +1 minute de marge
        
        if trade_age > max_trade_duration:
            return True, "Timeout - Trade trop ancien"
        
        # Vérifier les niveaux SL/TP (simulation)
        # En réalité, vérifier les prix actuels depuis MT5
        current_profit = self._simulate_profit_loss(trade)
        
        # Fermer dès qu'il y a un gain positif (attente spike puis prise de profit)
        if current_profit > 0:
            return True, f"Gain positif capturé: ${current_profit:.2f}"
        
        if current_profit <= -self.trading_config['max_risk_per_trade']:
            return True, f"Stop Loss atteint: ${current_profit:.2f}"
        
        return False, ""
    
    def _simulate_profit_loss(self, trade: Dict) -> float:
        """Simule le profit/loss d'un trade"""
        # Simulation basée sur le temps et la probabilité de spike
        trade_age = time.time() - trade['timestamp']
        spike_probability = trade['spike_probability']
        
        # Simuler un profit/loss aléatoire basé sur la probabilité
        import random
        
        if spike_probability > 0.8:
            # Haute probabilité = plus de chance de profit
            return random.uniform(-0.5, 2.0)
        elif spike_probability > 0.6:
            # Probabilité moyenne
            return random.uniform(-1.0, 1.5)
        else:
            # Faible probabilité = plus de risque
            return random.uniform(-1.5, 1.0)
    
    def close_trade(self, trade_id: str, reason: str):
        """Ferme un trade"""
        if trade_id not in self.active_trades:
            return
        
        trade = self.active_trades[trade_id]
        trade['status'] = 'CLOSED'
        trade['close_reason'] = reason
        trade['close_time'] = time.time()
        
        # Calculer le profit/loss final
        final_profit = self._simulate_profit_loss(trade)
        trade['profit_loss'] = final_profit
        # Mettre à jour le PnL journalier
        self.daily_realized_pnl += final_profit
        
        # Mettre à jour les statistiques
        if final_profit > 0:
            self.stats['winning_trades'] += 1
            self.stats['total_profit'] += final_profit
            # Renforcement adaptatif
            self._apply_reward_on_win()
        else:
            self.stats['losing_trades'] += 1
            self.stats['total_loss'] += abs(final_profit)
            # Pénalité adaptative
            self._apply_penalty_on_loss()
        
        # Calculer le win rate
        total_completed = self.stats['winning_trades'] + self.stats['losing_trades']
        if total_completed > 0:
            self.stats['win_rate'] = (self.stats['winning_trades'] / total_completed) * 100
        
        # Calculer le profit moyen
        if self.stats['total_trades'] > 0:
            self.stats['avg_profit_per_trade'] = (
                self.stats['total_profit'] - self.stats['total_loss']
            ) / self.stats['total_trades']
        
        print(f"Trade ferme: {trade_id}")
        print(f"   Raison: {reason}")
        print(f"   Profit/Loss: ${final_profit:.2f}")
        print(f"   Durée: {trade['close_time'] - trade['timestamp']:.1f}s")
        
        # Déplacer vers l'historique
        self.trade_history.append(trade)
        del self.active_trades[trade_id]
    
    def get_trading_stats(self) -> Dict:
        """Retourne les statistiques de trading"""
        return {
            'active_trades': len(self.active_trades),
            'daily_trades': self.daily_trade_count,
            'stats': self.stats.copy(),
            'config': self.trading_config.copy()
        }
    
    def run_trading_cycle(self, symbols: List[str]):
        """Exécute un cycle de trading pour les symboles donnés"""
        print(f"Cycle de trading pour {len(symbols)} symboles")
        
        for symbol in symbols:
            try:
                # Récupérer la prédiction
                prediction = self.get_trend_prediction(symbol)
                
                if not prediction:
                    continue
                
                # Injecter le symbole manquant si besoin
                if 'symbol' not in prediction:
                    prediction['symbol'] = symbol
                
                # Vérifier si on doit ouvrir un trade
                if self.should_open_trade(prediction):
                    # Calculer les paramètres
                    trade_params = self.calculate_trade_parameters(prediction)
                    
                    # Exécuter le trade
                    self.execute_trade(trade_params)
                
                # Surveiller les trades actifs
                self.monitor_active_trades()
                
            except Exception as e:
                print(f"Erreur cycle trading {symbol}: {e}")
        
        # Afficher les statistiques
        self._display_stats()
    
    def _display_stats(self):
        """Affiche les statistiques actuelles"""
        stats = self.get_trading_stats()
        
        print(f"\nSTATISTIQUES DE TRADING")
        print(f"   Trades actifs: {stats['active_trades']}")
        print(f"   Trades aujourd'hui: {stats['daily_trades']}")
        print(f"   Total trades: {stats['stats']['total_trades']}")
        print(f"   Win rate: {stats['stats']['win_rate']:.1f}%")
        print(f"   Profit total: ${stats['stats']['total_profit']:.2f}")
        print(f"   Perte total: ${stats['stats']['total_loss']:.2f}")
        print(f"   Profit moyen: ${stats['stats']['avg_profit_per_trade']:.2f}")

# Instance globale du système de trading
enhanced_trading = EnhancedEATrading()

def run_enhanced_trading(symbols: List[str]):
    """Fonction principale pour exécuter le trading amélioré"""
    return enhanced_trading.run_trading_cycle(symbols)

def get_trading_stats() -> Dict:
    """Retourne les statistiques de trading"""
    return enhanced_trading.get_trading_stats()

if __name__ == "__main__":
    # Test du système de trading amélioré
    print("🧪 Test du Système de Trading Amélioré")
    print("=" * 60)
    
    test_symbols = ['EURUSD', 'Boom 1000 Index', 'Crash 1000 Index']
    
    # Exécuter plusieurs cycles de trading
    for cycle in range(3):
        print(f"\n🔄 Cycle {cycle + 1}/3")
        run_enhanced_trading(test_symbols)
        time.sleep(2)  # Pause entre les cycles
    
    print(f"\n📈 STATISTIQUES FINALES")
    final_stats = get_trading_stats()
    print(f"   Total trades exécutés: {final_stats['stats']['total_trades']}")
    print(f"   Trades gagnants: {final_stats['stats']['winning_trades']}")
    print(f"   Trades perdants: {final_stats['stats']['losing_trades']}")
    print(f"   Win rate: {final_stats['stats']['win_rate']:.1f}%")
    print(f"   Profit total: ${final_stats['stats']['total_profit']:.2f}")
    print(f"   Perte total: ${final_stats['stats']['total_loss']:.2f}")
    print(f"   Profit moyen par trade: ${final_stats['stats']['avg_profit_per_trade']:.2f}")
