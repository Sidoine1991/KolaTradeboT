#!/usr/bin/env python3
"""
Système de Trading Simplifié - Support/Résistance + IB/OB
Détecte les niveaux confirmés et exécute des trades avec SL/TP bien calculés
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class SupportResistanceLevel:
    """Niveau de support ou résistance"""
    price: float
    level_type: str  # 'support' ou 'resistance'
    strength: float  # Force du niveau (0-1)
    touches: int    # Nombre de touches
    method: str      # Méthode de détection
    zone_top: float  # Zone haute
    zone_bottom: float  # Zone basse
    confirmed: bool  # Niveau confirmé
    last_contact: datetime  # Dernier contact

@dataclass
class ImbalanceZone:
    """Zone d'imbalance (FVG - Fair Value Gap)"""
    top: float
    bottom: float
    zone_type: str  # 'IB_BUY' ou 'IB_SELL'
    strength: float
    formed_time: datetime
    filled: bool
    confirmed: bool

@dataclass
class OrderBlock:
    """Order Block (bloc d'ordres institutionnels)"""
    high: float
    low: float
    ob_type: str  # 'OB_BUY' ou 'OB_SELL'
    formed_time: datetime
    strength: float
    invalidated: bool
    confirmed: bool

@dataclass
class TradeSignal:
    """Signal de trading généré"""
    symbol: str
    action: str  # 'BUY' ou 'SELL'
    entry_price: float
    sl_price: float
    tp_price: float
    confidence: float
    reason: str
    key_level: float
    risk_reward: float


class SimplifiedSMTradingSystem:
    """Système de trading simplifié basé sur SMC"""
    
    def __init__(self):
        self.symbols = [
            "Boom 1000 Index", "Boom 900 Index", "Boom 600 Index",
            "Boom 500 Index", "Boom 300 Index", "Boom 150 Index",
            "Crash 1000 Index", "Crash 900 Index", "Crash 600 Index",
            "Crash 500 Index", "Crash 300 Index", "Crash 150 Index"
        ]
        
        # Configuration trading
        self.lot_size = 0.01
        self.max_positions = 2
        self.max_daily_loss = 10.0
        self.max_daily_trades = 10
        
        # Configuration S/R
        self.min_touches = 2  # Minimum de touches pour confirmer
        self.tolerance_pct = 0.001  # Tolérance pour fusion (0.1%)
        self.min_strength = 0.6  # Force minimale
        
        # Configuration IB/OB
        self.min_fvg_size = 0.0005  # Taille minimale FVG (0.05%)
        self.min_ob_bodies = 3  # Minimum de corps de bougies pour OB
        
        # Configuration SL/TP
        self.min_rr_ratio = 2.0  # Risk/Reward minimum (1:2)
        self.sl_atr_multiplier = 2.0  # SL à 2x ATR
        self.tp_atr_multiplier = 4.0  # TP à 4x ATR (ratio 1:2)
        
        self.active_positions = []
        self.daily_loss = 0.0
        self.daily_trades = 0
        
        # Initialiser MT5
        self._init_mt5()
    
    def _init_mt5(self):
        """Initialise MT5"""
        if not mt5.initialize():
            logger.error("Échec initialisation MT5")
            return False
        logger.info("✅ MT5 initialisé")
        return True
    
    def detect_support_resistance(self, symbol: str, periods=200) -> List[SupportResistanceLevel]:
        """Détecte les supports et résistances confirmés"""
        try:
            # Obtenir les données
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, periods)
            if rates is None:
                return []
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            
            levels = []
            current_price = df['close'].iloc[-1]
            
            # 1. Détection swing highs/lows
            swing_highs = []
            swing_lows = []
            
            window = 5
            for i in range(window, len(df) - window):
                # Swing High
                if all(df['high'].iloc[i] >= df['high'].iloc[i-j] for j in range(1, window+1)):
                    if all(df['high'].iloc[i] >= df['high'].iloc[i+j] for j in range(1, window+1)):
                        swing_highs.append({
                            'price': df['high'].iloc[i],
                            'index': i,
                            'time': df['time'].iloc[i]
                        })
                
                # Swing Low
                if all(df['low'].iloc[i] <= df['low'].iloc[i-j] for j in range(1, window+1)):
                    if all(df['low'].iloc[i] <= df['low'].iloc[i+j] for j in range(1, window+1)):
                        swing_lows.append({
                            'price': df['low'].iloc[i],
                            'index': i,
                            'time': df['time'].iloc[i]
                        })
            
            # 2. Fusionner les niveaux proches
            merged_levels = self._merge_nearby_levels(df, current_price)
            
            # 3. Compter les touches et calculer la force
            for level_data in merged_levels:
                touches = self._count_touches(df, level_data['price'], level_data['type'])
                strength = min(touches / 3.0, 1.0)  # Force basée sur le nombre de touches
                
                if touches >= self.min_touches and strength >= self.min_strength:
                    level = SupportResistanceLevel(
                        price=level_data['price'],
                        level_type=level_data['type'],
                        strength=strength,
                        touches=touches,
                        method='swing',
                        zone_top=level_data['price'] * 1.0005,
                        zone_bottom=level_data['price'] * 0.9995,
                        confirmed=True,
                        last_contact=df['time'].iloc[-1]
                    )
                    levels.append(level)
            
            return levels
            
        except Exception as e:
            logger.error(f"Erreur détection S/R {symbol}: {e}")
            return []
    
    def _merge_nearby_levels(self, df: pd.DataFrame, current_price: float) -> List[Dict]:
        """Fusionne les niveaux proches"""
        levels = []
        
        # Analyser la structure pour trouver les zones
        swing_points = []
        
        # Swing highs
        for i in range(5, len(df) - 5):
            if (df['high'].iloc[i] >= df['high'].iloc[i-5:i].max() and
                df['high'].iloc[i] >= df['high'].iloc[i+1:i+6].max()):
                swing_points.append({'price': df['high'].iloc[i], 'type': 'resistance'})
        
        # Swing lows
        for i in range(5, len(df) - 5):
            if (df['low'].iloc[i] <= df['low'].iloc[i-5:i].min() and
                df['low'].iloc[i] <= df['low'].iloc[i+1:i+6].min()):
                swing_points.append({'price': df['low'].iloc[i], 'type': 'support'})
        
        # Fusionner les points proches
        if not swing_points:
            return []
        
        sorted_points = sorted(swing_points, key=lambda x: x['price'])
        merged = []
        current_group = [sorted_points[0]]
        
        for point in sorted_points[1:]:
            if abs(point['price'] - current_group[-1]['price']) / current_group[-1]['price'] <= self.tolerance_pct:
                current_group.append(point)
            else:
                # Fusionner le groupe
                avg_price = np.mean([p['price'] for p in current_group])
                merged.append({'price': avg_price, 'type': current_group[0]['type']})
                current_group = [point]
        
        if current_group:
            avg_price = np.mean([p['price'] for p in current_group])
            merged.append({'price': avg_price, 'type': current_group[0]['type']})
        
        return merged
    
    def _count_touches(self, df: pd.DataFrame, level: float, level_type: str) -> int:
        """Compte le nombre de touches d'un niveau"""
        touches = 0
        
        for idx, row in df.iterrows():
            if level_type == 'support':
                if abs(row['low'] - level) / level <= self.tolerance_pct:
                    touches += 1
            else:  # resistance
                if abs(row['high'] - level) / level <= self.tolerance_pct:
                    touches += 1
        
        return touches
    
    def detect_imbalance_zones(self, symbol: str, periods=50) -> List[ImbalanceZone]:
        """Détecte les zones d'imbalance (FVG)"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, periods)
            if rates is None:
                return []
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            
            imbalances = []
            
            # Règle FVG: 3 bougies consécutives
            # FVG haussier: bougie 1 bas < bougie 3 bas (gap vers le haut)
            # FVG baissier: bougie 1 haut > bougie 3 haut (gap vers le bas)
            
            for i in range(2, len(df)):
                candle1 = df.iloc[i-2]
                candle2 = df.iloc[i-1]
                candle3 = df.iloc[i]
                
                # FVG haussier (IB Buy)
                if candle1['low'] < candle3['low']:
                    gap_bottom = candle1['high']
                    gap_top = candle3['low']
                    
                    # Vérifier que c'est un vrai gap
                    if gap_top > gap_bottom and (gap_top - gap_bottom) / gap_bottom >= self.min_fvg_size:
                        imbalances.append(ImbalanceZone(
                            top=gap_top,
                            bottom=gap_bottom,
                            zone_type='IB_BUY',
                            strength=1.0 if gap_top - gap_bottom > df['close'].iloc[-1] * 0.001 else 0.7,
                            formed_time=candle3['time'],
                            filled=False,
                            confirmed=True
                        ))
                
                # FVG baissier (IB Sell)
                if candle1['high'] > candle3['high']:
                    gap_top = candle1['low']
                    gap_bottom = candle3['high']
                    
                    # Vérifier que c'est un vrai gap
                    if gap_bottom < gap_top and (gap_top - gap_bottom) / gap_bottom >= self.min_fvg_size:
                        imbalances.append(ImbalanceZone(
                            top=gap_top,
                            bottom=gap_bottom,
                            zone_type='IB_SELL',
                            strength=1.0 if gap_top - gap_bottom > df['close'].iloc[-1] * 0.001 else 0.7,
                            formed_time=candle3['time'],
                            filled=False,
                            confirmed=True
                        ))
            
            # Filtrer les imbálances remplies
            current_price = df['close'].iloc[-1]
            valid_imbalances = []
            
            for imb in imbalances:
                # Vérifier si la zone est remplie
                if imb.zone_type == 'IB_BUY':
                    # Zone remplie si le prix a touché le bas
                    if current_price <= imb.bottom:
                        imb.filled = True
                    else:
                        valid_imbalances.append(imb)
                else:  # IB_SELL
                    # Zone remplie si le prix a touché le haut
                    if current_price >= imb.top:
                        imb.filled = True
                    else:
                        valid_imbalances.append(imb)
            
            return valid_imbalances
            
        except Exception as e:
            logger.error(f"Erreur détection IB {symbol}: {e}")
            return []
    
    def detect_order_blocks(self, symbol: str, periods=100) -> List[OrderBlock]:
        """Détecte les Order Blocks institutionnels"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, periods)
            if rates is None:
                return []
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            
            order_blocks = []
            
            # Règle Order Block simplifiée:
            # - 3+ bougies consécutives dans la même direction (OB Buy ou OB Sell)
            # - Suivi d'un renversement (preuve de consommation)
            # - Zone devient bloc d'ordres institutionnels
            
            for i in range(self.min_ob_bodies, len(df) - 1):
                # Vérifier si c'est une série de bougies dans la même direction
                bullish_streak = True
                bearish_streak = True
                
                for j in range(self.min_ob_bodies):
                    if df.iloc[i-j]['close'] < df.iloc[i-j]['open']:
                        bullish_streak = False
                    if df.iloc[i-j]['close'] > df.iloc[i-j]['open']:
                        bearish_streak = False
                
                # OB Buy: série de bougies baissières suivie d'une haussière
                if bearish_streak and df.iloc[i+1]['close'] > df.iloc[i+1]['open']:
                    high = max(df.iloc[i-self.min_ob_bodies+1:i+1]['high'])
                    low = min(df.iloc[i-self.min_ob_bodies+1:i+1]['low'])
                    
                    order_blocks.append(OrderBlock(
                        high=high,
                        low=low,
                        ob_type='OB_BUY',
                        formed_time=df['time'].iloc[i],
                        strength=1.0,
                        invalidated=False,
                        confirmed=True
                    ))
                
                # OB Sell: série de bougies haussières suivie d'une baissière
                if bullish_streak and df.iloc[i+1]['close'] < df.iloc[i+1]['open']:
                    high = max(df.iloc[i-self.min_ob_bodies+1:i+1]['high'])
                    low = min(df.iloc[i-self.min_ob_bodies+1:i+1]['low'])
                    
                    order_blocks.append(OrderBlock(
                        high=high,
                        low=low,
                        ob_type='OB_SELL',
                        formed_time=df['time'].iloc[i],
                        strength=1.0,
                        invalidated=False,
                        confirmed=True
                    ))
            
            return order_blocks[:5]  # Limiter à 5 OB
            
        except Exception as e:
            logger.error(f"Erreur détection OB {symbol}: {e}")
            return []
    
    def calculate_sl_tp(self, symbol: str, entry_price: float, 
                        action: str, key_level: float = None) -> Tuple[float, float]:
        """Calcule le SL et TP intelligemment"""
        try:
            # Calculer ATR
            atr = self._calculate_atr(symbol, 14)
            
            if action == 'BUY':
                # SL: soit sous le key_level, soit 2x ATR
                if key_level and key_level < entry_price:
                    sl = key_level * 0.9995  # Légèrement sous le niveau
                else:
                    sl = entry_price - (atr * self.sl_atr_multiplier)
                
                # TP: Ratio 1:2 minimum, ou jusqu'au prochain niveau
                tp = entry_price + (atr * self.tp_atr_multiplier)
                
            else:  # SELL
                # SL: soit au-dessus du key_level, soit 2x ATR
                if key_level and key_level > entry_price:
                    sl = key_level * 1.0005  # Légèrement au-dessus
                else:
                    sl = entry_price + (atr * self.sl_atr_multiplier)
                
                # TP: Ratio 1:2 minimum
                tp = entry_price - (atr * self.tp_atr_multiplier)
            
            # Vérifier le ratio R:R
            risk = abs(entry_price - sl)
            reward = abs(tp - entry_price) if action == 'BUY' else abs(entry_price - tp)
            
            if risk > 0:
                rr_ratio = reward / risk
                if rr_ratio < self.min_rr_ratio:
                    # Ajuster le TP pour atteindre le ratio minimum
                    if action == 'BUY':
                        tp = entry_price + (risk * self.min_rr_ratio)
                    else:
                        tp = entry_price - (risk * self.min_rr_ratio)
            
            return sl, tp
            
        except Exception as e:
            logger.error(f"Erreur calcul SL/TP {symbol}: {e}")
            return 0.0, 0.0
    
    def _calculate_atr(self, symbol: str, period: int) -> float:
        """Calcule l'ATR"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, period + 1)
            if rates is None:
                return 0.0
            
            df = pd.DataFrame(rates)
            
            # Calculer TR
            df['high_low'] = df['high'] - df['low']
            df['high_close'] = abs(df['high'] - df['close'].shift())
            df['low_close'] = abs(df['low'] - df['close'].shift())
            df['tr'] = df[['high_low', 'high_close', 'low_close']].max(axis=1)
            
            atr = df['tr'].tail(period).mean()
            
            return atr if not pd.isna(atr) else 0.0
            
        except Exception as e:
            logger.error(f"Erreur ATR {symbol}: {e}")
            return 0.0
    
    def generate_signals(self, symbol: str) -> List[TradeSignal]:
        """Génère les signaux de trading"""
        signals = []
        
        try:
            # 1. Détecter les niveaux S/R
            sr_levels = self.detect_support_resistance(symbol)
            
            # 2. Détecter les zones d'imbalance
            imbalances = self.detect_imbalance_zones(symbol)
            
            # 3. Détecter les Order Blocks
            order_blocks = self.detect_order_blocks(symbol)
            
            # 4. Obtenir le prix actuel
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                return signals
            
            current_price = tick.bid
            entry_price = tick.ask if tick.ask else tick.bid
            
            # 5. Analyser chaque type de signal
            
            # Signal basé sur S/R
            for level in sr_levels:
                distance = abs(current_price - level.price) / current_price
                
                if distance <= 0.002:  # Prix proche (0.2%)
                    if level.level_type == 'support' and current_price > level.price:
                        # Signal BUY proche du support
                        sl, tp = self.calculate_sl_tp(symbol, entry_price, 'BUY', level.price)
                        
                        if sl > 0 and tp > 0:
                            rr = abs(tp - entry_price) / abs(entry_price - sl) if abs(entry_price - sl) > 0 else 0
                            
                            signal = TradeSignal(
                                symbol=symbol,
                                action='BUY',
                                entry_price=entry_price,
                                sl_price=sl,
                                tp_price=tp,
                                confidence=level.strength * 0.8,
                                reason=f"Support confirmé {level.touches}t",
                                key_level=level.price,
                                risk_reward=rr
                            )
                            signals.append(signal)
                    
                    elif level.level_type == 'resistance' and current_price < level.price:
                        # Signal SELL proche de la résistance
                        sl, tp = self.calculate_sl_tp(symbol, entry_price, 'SELL', level.price)
                        
                        if sl > 0 and tp > 0:
                            rr = abs(entry_price - tp) / abs(sl - entry_price) if abs(sl - entry_price) > 0 else 0
                            
                            signal = TradeSignal(
                                symbol=symbol,
                                action='SELL',
                                entry_price=entry_price,
                                sl_price=sl,
                                tp_price=tp,
                                confidence=level.strength * 0.8,
                                reason=f"Résistance confirmée {level.touches}t",
                                key_level=level.price,
                                risk_reward=rr
                            )
                            signals.append(signal)
            
            # Signal basé sur IB Buy
            for imb in imbalances:
                if imb.zone_type == 'IB_BUY':
                    if imb.bottom <= current_price <= imb.top:
                        sl, tp = self.calculate_sl_tp(symbol, entry_price, 'BUY', imb.bottom)
                        
                        if sl > 0 and tp > 0 and abs(tp - entry_price) / abs(entry_price - sl) >= 2.0:
                            signal = TradeSignal(
                                symbol=symbol,
                                action='BUY',
                                entry_price=entry_price,
                                sl_price=sl,
                                tp_price=tp,
                                confidence=imb.strength,
                                reason="Zone IB Buy (gap haussier)",
                                key_level=imb.bottom,
                                risk_reward=abs(tp - entry_price) / abs(entry_price - sl) if abs(entry_price - sl) > 0 else 0
                            )
                            signals.append(signal)
            
            # Signal basé sur IB Sell
            for imb in imbalances:
                if imb.zone_type == 'IB_SELL':
                    if imb.bottom <= current_price <= imb.top:
                        sl, tp = self.calculate_sl_tp(symbol, entry_price, 'SELL', imb.top)
                        
                        if sl > 0 and tp > 0 and abs(entry_price - tp) / abs(sl - entry_price) >= 2.0:
                            signal = TradeSignal(
                                symbol=symbol,
                                action='SELL',
                                entry_price=entry_price,
                                sl_price=sl,
                                tp_price=tp,
                                confidence=imb.strength,
                                reason="Zone IB Sell (gap baissier)",
                                key_level=imb.top,
                                risk_reward=abs(entry_price - tp) / abs(sl - entry_price) if abs(sl - entry_price) > 0 else 0
                            )
                            signals.append(signal)
            
            # Signal basé sur OB Buy
            for ob in order_blocks:
                if ob.ob_type == 'OB_BUY' and not ob.invalidated:
                    if current_price <= ob.high:
                        sl, tp = self.calculate_sl_tp(symbol, entry_price, 'BUY', ob.low)
                        
                        if sl > 0 and tp > 0:
                            rr = abs(tp - entry_price) / abs(entry_price - sl) if abs(entry_price - sl) > 0 else 0
                            
                            if rr >= 2.0:
                                signal = TradeSignal(
                                    symbol=symbol,
                                    action='BUY',
                                    entry_price=entry_price,
                                    sl_price=sl,
                                    tp_price=tp,
                                    confidence=ob.strength,
                                    reason="Order Block Buy actif",
                                    key_level=ob.low,
                                    risk_reward=rr
                                )
                                signals.append(signal)
            
            # Signal basé sur OB Sell
            for ob in order_blocks:
                if ob.ob_type == 'OB_SELL' and not ob.invalidated:
                    if current_price >= ob.low:
                        sl, tp = self.calculate_sl_tp(symbol, entry_price, 'SELL', ob.high)
                        
                        if sl > 0 and tp > 0:
                            rr = abs(entry_price - tp) / abs(sl - entry_price) if abs(sl - entry_price) > 0 else 0
                            
                            if rr >= 2.0:
                                signal = TradeSignal(
                                    symbol=symbol,
                                    action='SELL',
                                    entry_price=entry_price,
                                    sl_price=sl,
                                    tp_price=tp,
                                    confidence=ob.strength,
                                    reason="Order Block Sell actif",
                                    key_level=ob.high,
                                    risk_reward=rr
                                )
                                signals.append(signal)
            
            # Trier par confiance
            signals.sort(key=lambda x: x.confidence, reverse=True)
            
            return signals[:3]  # Top 3 signaux
            
        except Exception as e:
            logger.error(f"Erreur génération signaux {symbol}: {e}")
            return []
    
    def execute_trade(self, signal: TradeSignal) -> bool:
        """Exécute un trade"""
        try:
            if len(self.active_positions) >= self.max_positions:
                logger.info("Limite de positions atteinte")
                return False
            
            # Préparer la requête
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": signal.symbol,
                "volume": self.lot_size,
                "type": mt5.ORDER_TYPE_BUY if signal.action == 'BUY' else mt5.ORDER_TYPE_SELL,
                "price": signal.entry_price,
                "sl": signal.sl_price,
                "tp": signal.tp_price,
                "deviation": 20,
                "magic": 888001,
                "comment": signal.reason,
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            result = mt5.order_send(request)
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"✅ Trade exécuté: {signal.action} {signal.symbol} - R:R {signal.risk_reward:.2f}")
                self.active_positions.append({
                    'ticket': result.order,
                    'signal': signal
                })
                self.daily_trades += 1
                return True
            else:
                logger.error(f"❌ Échec trade: {result.comment}")
                return False
                
        except Exception as e:
            logger.error(f"Erreur exécution trade: {e}")
            return False
    
    def run(self):
        """Boucle principale du système"""
        logger.info("🚀 Démarrage système SMC simplifié")
        
        while True:
            try:
                for symbol in self.symbols:
                    # Générer les signaux
                    signals = self.generate_signals(symbol)
                    
                    # Exécuter les meilleurs signaux
                    for signal in signals:
                        if signal.confidence >= 0.65 and signal.risk_reward >= 2.0:
                            self.execute_trade(signal)
                            break  # Un seul trade par symbole à la fois
                    
                    # Petite pause
                    import time
                    time.sleep(0.5)
                
                # Vérifier les positions actives
                self._check_positions()
                
                # Attendre avant la prochaine itération
                import time
                time.sleep(10)  # 10 secondes entre les scans
                
            except KeyboardInterrupt:
                logger.info("Arrêt demandé")
                break
            except Exception as e:
                logger.error(f"Erreur boucle principale: {e}")
                import time
                time.sleep(30)
    
    def _check_positions(self):
        """Vérifie les positions actives"""
        try:
            for pos in self.active_positions[:]:
                if not mt5.positions_get(ticket=pos['ticket']):
                    self.active_positions.remove(pos)
        except Exception as e:
            logger.error(f"Erreur vérification positions: {e}")


def main():
    """Fonction principale"""
    system = SimplifiedSMTradingSystem()
    
    try:
        system.run()
    except KeyboardInterrupt:
        logger.info("Arrêt demandé par l'utilisateur")
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    main()
