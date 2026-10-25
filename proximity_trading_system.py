#!/usr/bin/env python3
"""
Système de Trading basé sur la Proximité des Supports/Résistances
Exécute des trades quand le prix est proche d'une résistance (SELL) ou d'un support (BUY)
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import logging
import json
import time
from dataclasses import dataclass

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('proximity_trading.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class SupportResistanceLevel:
    """Représente un niveau de support ou résistance"""
    price: float
    level_type: str  # 'support' ou 'resistance'
    strength: float
    method: str
    distance: float
    confidence: float

@dataclass
class TradingSignal:
    """Représente un signal de trading"""
    symbol: str
    action: str  # 'BUY' ou 'SELL'
    entry_price: float
    sl: float
    tp: float
    confidence: float
    proximity_level: SupportResistanceLevel
    reason: str

class ProximityTradingSystem:
    """Système de trading basé sur la proximité des supports/résistances"""
    
    def __init__(self):
        self.symbols = [
            "Boom 1000 Index", "Boom 900 Index", "Boom 600 Index", 
            "Boom 500 Index", "Boom 300 Index", "Boom 150 Index",
            "Crash 1000 Index", "Crash 900 Index", "Crash 600 Index",
            "Crash 500 Index", "Crash 300 Index", "Crash 150 Index"
        ]
        
        # Configuration de trading
        self.max_positions = 2
        self.lot_size = 0.01
        self.max_lot_size = 1.0
        self.max_daily_loss = 10.0
        self.max_daily_trades = 10
        
        # Configuration de proximité
        self.proximity_threshold = 0.002  # 0.2% du prix
        self.min_strength = 0.6  # Force minimale du niveau
        self.min_confidence = 0.7  # Confiance minimale pour trader
        
        # Variables de suivi
        self.active_positions = []
        self.daily_loss = 0.0
        self.daily_trades = 0
        self.last_reset_date = datetime.now().date()
        
        # Initialiser MT5
        self._initialize_mt5()
    
    def _initialize_mt5(self):
        """Initialise la connexion MT5"""
        try:
            if not mt5.initialize():
                logger.error("Échec de l'initialisation MT5")
                return False
            
            account_info = mt5.account_info()
            if account_info is None:
                logger.error("Impossible d'obtenir les informations du compte")
                return False
            
            logger.info(f"MT5 initialisé - Compte: {account_info.login}")
            logger.info(f"Solde: {account_info.balance} {account_info.currency}")
            return True
            
        except Exception as e:
            logger.error(f"Erreur d'initialisation MT5: {e}")
            return False
    
    def detect_support_resistance_levels(self, symbol: str, timeframe=mt5.TIMEFRAME_M1, periods=100) -> List[SupportResistanceLevel]:
        """Détecte les niveaux de support et résistance pour un symbole"""
        try:
            # Obtenir les données historiques
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, periods)
            if rates is None:
                logger.error(f"Impossible d'obtenir les données pour {symbol}")
                return []
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            
            levels = []
            
            # 1. Détection des swing highs et lows
            swing_levels = self._detect_swing_levels(df)
            levels.extend(swing_levels)
            
            # 2. Détection des pivot points
            pivot_levels = self._detect_pivot_levels(df)
            levels.extend(pivot_levels)
            
            # 3. Détection des niveaux psychologiques
            psychological_levels = self._detect_psychological_levels(df)
            levels.extend(psychological_levels)
            
            # 4. Détection des niveaux de volume
            volume_levels = self._detect_volume_levels(df)
            levels.extend(volume_levels)
            
            # 5. Fusionner et valider les niveaux
            merged_levels = self._merge_nearby_levels(levels)
            
            # 6. Calculer les distances et confiances
            current_price = df['close'].iloc[-1]
            for level in merged_levels:
                level.distance = abs(level.price - current_price) / current_price
                level.confidence = self._calculate_confidence(level, df)
            
            # 7. Filtrer par proximité et force
            relevant_levels = [
                level for level in merged_levels
                if level.distance <= self.proximity_threshold and
                   level.strength >= self.min_strength
            ]
            
            # 8. Trier par proximité et force
            relevant_levels.sort(key=lambda x: (x.distance, -x.strength))
            
            return relevant_levels
            
        except Exception as e:
            logger.error(f"Erreur lors de la détection des niveaux pour {symbol}: {e}")
            return []
    
    def _detect_swing_levels(self, df: pd.DataFrame) -> List[SupportResistanceLevel]:
        """Détecte les swing highs et lows"""
        levels = []
        
        # Swing highs (résistances)
        for i in range(2, len(df) - 2):
            if (df['high'].iloc[i] > df['high'].iloc[i-1] and 
                df['high'].iloc[i] > df['high'].iloc[i-2] and
                df['high'].iloc[i] > df['high'].iloc[i+1] and 
                df['high'].iloc[i] > df['high'].iloc[i+2]):
                
                levels.append(SupportResistanceLevel(
                    price=df['high'].iloc[i],
                    level_type='resistance',
                    strength=1.0,
                    method='swing_high',
                    distance=0.0,
                    confidence=0.0
                ))
        
        # Swing lows (supports)
        for i in range(2, len(df) - 2):
            if (df['low'].iloc[i] < df['low'].iloc[i-1] and 
                df['low'].iloc[i] < df['low'].iloc[i-2] and
                df['low'].iloc[i] < df['low'].iloc[i+1] and 
                df['low'].iloc[i] < df['low'].iloc[i+2]):
                
                levels.append(SupportResistanceLevel(
                    price=df['low'].iloc[i],
                    level_type='support',
                    strength=1.0,
                    method='swing_low',
                    distance=0.0,
                    confidence=0.0
                ))
        
        return levels
    
    def _detect_pivot_levels(self, df: pd.DataFrame) -> List[SupportResistanceLevel]:
        """Détecte les pivot points"""
        levels = []
        
        for i in range(1, len(df)):
            high = df['high'].iloc[i-1]
            low = df['low'].iloc[i-1]
            close = df['close'].iloc[i-1]
            
            # Pivot classique
            pivot = (high + low + close) / 3
            r1 = (2 * pivot) - low
            s1 = (2 * pivot) - high
            r2 = pivot + (high - low)
            s2 = pivot - (high - low)
            
            # Ajouter les niveaux de résistance
            levels.append(SupportResistanceLevel(
                price=r1, level_type='resistance', strength=0.8, method='pivot_r1',
                distance=0.0, confidence=0.0
            ))
            levels.append(SupportResistanceLevel(
                price=r2, level_type='resistance', strength=0.6, method='pivot_r2',
                distance=0.0, confidence=0.0
            ))
            
            # Ajouter les niveaux de support
            levels.append(SupportResistanceLevel(
                price=s1, level_type='support', strength=0.8, method='pivot_s1',
                distance=0.0, confidence=0.0
            ))
            levels.append(SupportResistanceLevel(
                price=s2, level_type='support', strength=0.6, method='pivot_s2',
                distance=0.0, confidence=0.0
            ))
        
        return levels
    
    def _detect_psychological_levels(self, df: pd.DataFrame) -> List[SupportResistanceLevel]:
        """Détecte les niveaux psychologiques (nombres ronds)"""
        levels = []
        current_price = df['close'].iloc[-1]
        
        # Déterminer l'échelle des niveaux psychologiques
        if current_price > 1000:
            base_levels = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
        elif current_price > 100:
            base_levels = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
        elif current_price > 10:
            base_levels = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        else:
            base_levels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        
        # Générer les niveaux psychologiques autour du prix actuel
        min_price = current_price * 0.8
        max_price = current_price * 1.2
        
        for base in base_levels:
            for multiplier in range(1, 20):
                level = base * multiplier
                if min_price <= level <= max_price:
                    level_type = 'support' if level < current_price else 'resistance'
                    levels.append(SupportResistanceLevel(
                        price=level,
                        level_type=level_type,
                        strength=0.7,
                        method='psychological',
                        distance=0.0,
                        confidence=0.0
                    ))
        
        return levels
    
    def _detect_volume_levels(self, df: pd.DataFrame) -> List[SupportResistanceLevel]:
        """Détecte les niveaux basés sur le volume"""
        levels = []
        
        if 'tick_volume' not in df.columns:
            return levels
        
        # Analyser les pics de volume
        volume_mean = df['tick_volume'].mean()
        volume_std = df['tick_volume'].std()
        
        for i in range(len(df)):
            if df['tick_volume'].iloc[i] > volume_mean + volume_std:
                # Niveau de résistance (pic de volume à un high)
                if df['high'].iloc[i] > df['close'].iloc[i]:
                    levels.append(SupportResistanceLevel(
                        price=df['high'].iloc[i],
                        level_type='resistance',
                        strength=0.8,
                        method='volume_high',
                        distance=0.0,
                        confidence=0.0
                    ))
                
                # Niveau de support (pic de volume à un low)
                if df['low'].iloc[i] < df['close'].iloc[i]:
                    levels.append(SupportResistanceLevel(
                        price=df['low'].iloc[i],
                        level_type='support',
                        strength=0.8,
                        method='volume_low',
                        distance=0.0,
                        confidence=0.0
                    ))
        
        return levels
    
    def _merge_nearby_levels(self, levels: List[SupportResistanceLevel]) -> List[SupportResistanceLevel]:
        """Fusionne les niveaux proches"""
        if not levels:
            return []
        
        # Trier par prix
        levels.sort(key=lambda x: x.price)
        
        merged = []
        current_group = [levels[0]]
        
        for level in levels[1:]:
            # Vérifier si le niveau est proche du groupe actuel
            if abs(level.price - current_group[0].price) / current_group[0].price < 0.001:  # 0.1%
                current_group.append(level)
            else:
                # Fusionner le groupe actuel
                if current_group:
                    merged.append(self._merge_level_group(current_group))
                current_group = [level]
        
        # Ajouter le dernier groupe
        if current_group:
            merged.append(self._merge_level_group(current_group))
        
        return merged
    
    def _merge_level_group(self, group: List[SupportResistanceLevel]) -> SupportResistanceLevel:
        """Fusionne un groupe de niveaux"""
        avg_price = np.mean([level.price for level in group])
        max_strength = max([level.strength for level in group])
        methods = list(set([level.method for level in group]))
        
        return SupportResistanceLevel(
            price=avg_price,
            level_type=group[0].level_type,
            strength=max_strength,
            method='+'.join(methods),
            distance=0.0,
            confidence=0.0
        )
    
    def _calculate_confidence(self, level: SupportResistanceLevel, df: pd.DataFrame) -> float:
        """Calcule la confiance d'un niveau"""
        confidence = 0.0
        
        # Facteur de force
        confidence += level.strength * 0.3
        
        # Facteur de méthode
        method_weights = {
            'swing_high': 0.9, 'swing_low': 0.9,
            'pivot_r1': 0.8, 'pivot_s1': 0.8,
            'pivot_r2': 0.6, 'pivot_s2': 0.6,
            'psychological': 0.7,
            'volume_high': 0.8, 'volume_low': 0.8
        }
        confidence += method_weights.get(level.method, 0.5) * 0.3
        
        # Facteur de récence (plus récent = plus confiant)
        recent_factor = 1.0  # À améliorer avec l'analyse temporelle
        confidence += recent_factor * 0.2
        
        # Facteur de volume (si disponible)
        volume_factor = 1.0  # À améliorer avec l'analyse de volume
        confidence += volume_factor * 0.2
        
        return min(confidence, 1.0)
    
    def generate_trading_signals(self, symbol: str) -> List[TradingSignal]:
        """Génère les signaux de trading basés sur la proximité des niveaux"""
        signals = []
        
        try:
            # Détecter les niveaux de support/résistance
            levels = self.detect_support_resistance_levels(symbol)
            
            if not levels:
                return signals
            
            # Obtenir le prix actuel
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                return signals
            
            current_price = tick.bid
            
            # Analyser chaque niveau proche
            for level in levels:
                if level.confidence < self.min_confidence:
                    continue
                
                # Calculer la distance en pourcentage
                distance_pct = abs(level.price - current_price) / current_price
                
                if distance_pct > self.proximity_threshold:
                    continue
                
                # Générer le signal selon le type de niveau
                if level.level_type == 'support' and current_price > level.price:
                    # Prix au-dessus d'un support -> Signal BUY
                    signal = self._create_buy_signal(symbol, current_price, level)
                    if signal:
                        signals.append(signal)
                
                elif level.level_type == 'resistance' and current_price < level.price:
                    # Prix en-dessous d'une résistance -> Signal SELL
                    signal = self._create_sell_signal(symbol, current_price, level)
                    if signal:
                        signals.append(signal)
            
            return signals
            
        except Exception as e:
            logger.error(f"Erreur lors de la génération des signaux pour {symbol}: {e}")
            return signals
    
    def _create_buy_signal(self, symbol: str, current_price: float, level: SupportResistanceLevel) -> Optional[TradingSignal]:
        """Crée un signal d'achat basé sur un support"""
        try:
            # Calculer SL et TP
            sl = level.price * 0.998  # SL légèrement en-dessous du support
            tp = current_price * 1.01  # TP à 1% de profit
            
            # Vérifier les distances minimales
            if not self._validate_sl_tp_distances(symbol, current_price, sl, tp):
                return None
            
            return TradingSignal(
                symbol=symbol,
                action='BUY',
                entry_price=current_price,
                sl=sl,
                tp=tp,
                confidence=level.confidence,
                proximity_level=level,
                reason=f"Proximité du support à {level.price:.2f} (distance: {abs(level.price - current_price):.2f})"
            )
            
        except Exception as e:
            logger.error(f"Erreur lors de la création du signal BUY: {e}")
            return None
    
    def _create_sell_signal(self, symbol: str, current_price: float, level: SupportResistanceLevel) -> Optional[TradingSignal]:
        """Crée un signal de vente basé sur une résistance"""
        try:
            # Calculer SL et TP
            sl = level.price * 1.002  # SL légèrement au-dessus de la résistance
            tp = current_price * 0.99  # TP à 1% de profit
            
            # Vérifier les distances minimales
            if not self._validate_sl_tp_distances(symbol, current_price, sl, tp):
                return None
            
            return TradingSignal(
                symbol=symbol,
                action='SELL',
                entry_price=current_price,
                sl=sl,
                tp=tp,
                confidence=level.confidence,
                proximity_level=level,
                reason=f"Proximité de la résistance à {level.price:.2f} (distance: {abs(level.price - current_price):.2f})"
            )
            
        except Exception as e:
            logger.error(f"Erreur lors de la création du signal SELL: {e}")
            return None
    
    def _validate_sl_tp_distances(self, symbol: str, entry_price: float, sl: float, tp: float) -> bool:
        """Valide les distances SL/TP"""
        try:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                return False
            
            point = symbol_info.point
            stop_level = symbol_info.trade_stops_level * point
            
            if stop_level <= 0:
                stop_level = 10 * point
            
            # Vérifier la distance SL
            sl_distance = abs(entry_price - sl)
            if sl_distance < stop_level:
                return False
            
            # Vérifier la distance TP
            tp_distance = abs(tp - entry_price)
            if tp_distance < stop_level:
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la validation des distances: {e}")
            return False
    
    def execute_trading_signal(self, signal: TradingSignal) -> bool:
        """Exécute un signal de trading"""
        try:
            # Vérifier les limites quotidiennes
            if not self._check_daily_limits():
                return False
            
            # Vérifier le nombre de positions
            if len(self.active_positions) >= self.max_positions:
                logger.info(f"Nombre maximum de positions atteint: {len(self.active_positions)}")
                return False
            
            # Préparer la requête de trade
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": signal.symbol,
                "volume": self.lot_size,
                "type": mt5.ORDER_TYPE_BUY if signal.action == 'BUY' else mt5.ORDER_TYPE_SELL,
                "price": signal.entry_price,
                "sl": signal.sl,
                "tp": signal.tp,
                "deviation": 20,
                "magic": 880011,
                "comment": f"Proximity {signal.proximity_level.level_type}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            # Envoyer l'ordre
            result = mt5.order_send(request)
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Échec de l'ordre: {result.retcode} - {result.comment}")
                return False
            
            # Enregistrer la position
            position = {
                'ticket': result.order,
                'symbol': signal.symbol,
                'action': signal.action,
                'entry_price': signal.entry_price,
                'sl': signal.sl,
                'tp': signal.tp,
                'confidence': signal.confidence,
                'reason': signal.reason,
                'timestamp': datetime.now()
            }
            
            self.active_positions.append(position)
            self.daily_trades += 1
            
            logger.info(f"Trade exécuté: {signal.action} {signal.symbol} - Ticket: {result.order}")
            logger.info(f"Confiance: {signal.confidence:.2f} - Raison: {signal.reason}")
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de l'exécution du signal: {e}")
            return False
    
    def _check_daily_limits(self) -> bool:
        """Vérifie les limites quotidiennes"""
        current_date = datetime.now().date()
        
        # Réinitialiser les compteurs si nouveau jour
        if current_date != self.last_reset_date:
            self.daily_loss = 0.0
            self.daily_trades = 0
            self.last_reset_date = current_date
            logger.info("Limites quotidiennes réinitialisées")
        
        # Vérifier les limites
        if self.daily_loss >= self.max_daily_loss:
            logger.warning(f"Limite de perte quotidienne atteinte: {self.daily_loss}")
            return False
        
        if self.daily_trades >= self.max_daily_trades:
            logger.warning(f"Limite de trades quotidienne atteinte: {self.daily_trades}")
            return False
        
        return True
    
    def monitor_and_trade(self):
        """Boucle principale de monitoring et trading"""
        logger.info("Démarrage du système de trading par proximité")
        
        while True:
            try:
                # Vérifier les limites quotidiennes
                if not self._check_daily_limits():
                    time.sleep(60)  # Attendre 1 minute
                    continue
                
                # Analyser chaque symbole
                for symbol in self.symbols:
                    try:
                        # Générer les signaux
                        signals = self.generate_trading_signals(symbol)
                        
                        # Exécuter les signaux
                        for signal in signals:
                            if len(self.active_positions) >= self.max_positions:
                                break
                            
                            logger.info(f"Signal détecté pour {symbol}: {signal.action} - {signal.reason}")
                            
                            if self.execute_trading_signal(signal):
                                logger.info(f"Signal exécuté avec succès pour {symbol}")
                            else:
                                logger.warning(f"Échec de l'exécution du signal pour {symbol}")
                        
                        # Petite pause entre les symboles
                        time.sleep(0.1)
                        
                    except Exception as e:
                        logger.error(f"Erreur lors de l'analyse de {symbol}: {e}")
                        continue
                
                # Surveiller les positions actives
                self._monitor_positions()
                
                # Attendre avant la prochaine itération
                time.sleep(5)  # 5 secondes
                
            except KeyboardInterrupt:
                logger.info("Arrêt demandé par l'utilisateur")
                break
            except Exception as e:
                logger.error(f"Erreur dans la boucle principale: {e}")
                time.sleep(10)
    
    def _monitor_positions(self):
        """Surveille les positions actives"""
        try:
            # Obtenir les positions depuis MT5
            positions = mt5.positions_get()
            
            if positions is None:
                return
            
            # Vérifier chaque position
            for mt5_position in positions:
                self._check_position_status(mt5_position)
                
        except Exception as e:
            logger.error(f"Erreur lors de la surveillance des positions: {e}")
    
    def _check_position_status(self, mt5_position):
        """Vérifie le statut d'une position"""
        try:
            # Trouver la position dans notre liste
            local_position = None
            for pos in self.active_positions:
                if pos['ticket'] == mt5_position.ticket:
                    local_position = pos
                    break
            
            if local_position is None:
                return
            
            # Vérifier si la position est fermée
            if mt5_position.profit is not None:
                # Position fermée
                self._handle_position_closed(local_position, mt5_position)
                
        except Exception as e:
            logger.error(f"Erreur lors de la vérification du statut: {e}")
    
    def _handle_position_closed(self, local_position: dict, mt5_position):
        """Gère une position fermée"""
        try:
            # Calculer le profit/perte
            profit = mt5_position.profit
            self.daily_loss += abs(profit) if profit < 0 else 0
            
            # Retirer de la liste active
            self.active_positions.remove(local_position)
            
            # Logger le résultat
            if profit > 0:
                logger.info(f"Position fermée avec profit: {profit:.2f} - Ticket: {local_position['ticket']}")
            else:
                logger.warning(f"Position fermée avec perte: {profit:.2f} - Ticket: {local_position['ticket']}")
            
        except Exception as e:
            logger.error(f"Erreur lors de la gestion de position fermée: {e}")
    
    def get_status(self) -> dict:
        """Retourne le statut du système"""
        return {
            'active_positions': len(self.active_positions),
            'daily_trades': self.daily_trades,
            'daily_loss': self.daily_loss,
            'max_daily_loss': self.max_daily_loss,
            'max_daily_trades': self.max_daily_trades,
            'positions': self.active_positions
        }

def main():
    """Fonction principale"""
    print("🎯 Système de Trading par Proximité des Supports/Résistances")
    print("=" * 60)
    
    # Créer le système
    trading_system = ProximityTradingSystem()
    
    try:
        # Démarrer le monitoring
        trading_system.monitor_and_trade()
        
    except KeyboardInterrupt:
        print("\n⏹️ Arrêt du système demandé")
    except Exception as e:
        print(f"❌ Erreur: {e}")
    finally:
        # Nettoyage
        mt5.shutdown()
        print("🔚 Système arrêté")

if __name__ == "__main__":
    main()
