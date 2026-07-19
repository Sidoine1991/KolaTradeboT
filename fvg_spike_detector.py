#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FVG Spike Detector - Détection multi-timeframe pour Boom/Crash
Stratégies:
- BOOM/GAINX: FVG Supply M5 → Alerte | FVG Supply M1 → Exécution SELL
- CRASH/PAINX: FVG Demand M5 → Alerte | FVG Demand M1 → Exécution BUY
Risk Management: Max $2.50 perte par trade
"""

import logging
import numpy as np
import pandas as pd
from typing import List, Dict, Optional, Tuple, Literal
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum, auto
import asyncio

logger = logging.getLogger("fvg_spike_detector")


class FVGType(Enum):
    SUPPLY = "supply"   # Zone de vente (résistance) → SELL
    DEMAND = "demand"   # Zone d'achat (support) → BUY


class TimeFrame(Enum):
    M1 = "M1"
    M5 = "M5"


class SymbolDirection(Enum):
    """Classification des symboles selon leur direction unidirectionnelle"""
    BULLISH = "bullish"    # Boom, GAINX, TRENDX如同
    BEARISH = "bearish"    # Crash, PAINX如同


@dataclass
class FVG:
    """Représente un Fair Value Gap"""
    type: FVGType
    timeframe: TimeFrame
    start_price: float
    end_price: float
    start_time: datetime
    end_time: datetime
    volume_at_formation: float
    confidence: float = 0.0

    @property
    def size(self) -> float:
        return abs(self.end_price - self.start_price)

    @property
    def is_supply(self) -> bool:
        return self.type == FVGType.SUPPLY

    @property
    def is_demand(self) -> bool:
        return self.type == FVGType.DEMAND


@dataclass
class SpikeSignal:
    """Signal de spike détecté"""
    symbol: str
    direction: Literal["BUY", "SELL"]
    entry_price: float
    stop_loss: float
    take_profit: float
    lot_size: float
    confidence: float
    timeframe_confluence: List[TimeFrame]
    risk_amount: float
    fvg_m5: Optional[FVG] = None
    fvg_m1: Optional[FVG] = None
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class Alert:
    """Alerte M5 avant déclenchement"""
    symbol: str
    alert_type: str
    fvg: FVG
    message: str
    timestamp: datetime
    triggered: bool = False


def get_symbol_direction(symbol: str) -> SymbolDirection:
    """
    Détermine si un symbole est BULLISH ou BEARISH
    
    Boom/GAINX/TRENDX = seul SELL est réaliste pour suivre le spike
    Crash/PAINX = seul BUY est réaliste 
    """
    sym = str(symbol or "").upper().replace(" ", "")
    
    if any(k in sym for k in ["BOOM", "GAINX", "TRENDX", "GAIN"]):
        return SymbolDirection.BULLISH
    elif any(k in sym for k in ["CRASH", "PAINX", "PAIN"]):
        return SymbolDirection.BEARISH
    else:
        # Par défaut, détecter selon le comportement des prix (fallback)
        return SymbolDirection.BULLISH  # Default conservateur


def get_fvg_target_for_symbol(symbol: str) -> FVGType:
    """
    Retourne le type de FVG à surveiller selon le symbole:
    - Boom/GAINX → SUPPLY (zones de vente/résistance)
    - Crash/PAINX → DEMAND (zones d'achat/support)
    """
    direction = get_symbol_direction(symbol)
    if direction == SymbolDirection.BULLISH:
        return FVGType.SUPPLY  # Pour Boom: on cherche les gaps de supply (résistance) pour vendre
    else:
        return FVGType.DEMAND  # Pour Crash: on cherche les gaps de demand (support) pour acheter


def get_trade_direction_for_symbol(symbol: str) -> Literal["BUY", "SELL"]:
    """
    Retourne la direction du trade selon le symbole:
    - Boom/GAINX → SELL (car l'indice va exploser vers le haut, mais en pratique on trade le rejet/résistance)
    - Crash/PAINX → BUY (car l'indice va chuter, mais on cherche les rebonds/support)
    
    Note: En réalité, pour Boom on fait SELL sur résistance (supply)
    et pour Crash on fait BUY sur support (demand) pour suivre la tendance
    """
    direction = get_symbol_direction(symbol)
    if direction == SymbolDirection.BULLISH:
        return "SELL"  # Vendre à la résistance pour suivre le spike haussier
    else:
        return "BUY"   # Acheter au support pour suivre le spike baissier


class FVGCalculator:
    """Calculateur de FVG (Fair Value Gaps)"""

    @staticmethod
    def detect_fvg(df: pd.DataFrame, timeframe: TimeFrame, 
                   min_size_multiplier: float = 2.0) -> List[FVG]:
        """
        Détecte les FVG dans un DataFrame de prix
        """
        fvgs = []
        n = len(df)
        if n < 3:
            return fvgs

        # Calcul de la volatilité moyenne pour le seuil minimum
        avg_range = (df['high'] - df['low']).mean()
        if pd.isna(avg_range) or avg_range <= 0:
            return fvgs
        
        min_size = avg_range * min_size_multiplier

        for i in range(1, n - 1):
            prev_candle = df.iloc[i - 1]
            current_candle = df.iloc[i]
            next_candle = df.iloc[i + 1]

            # FVG Supply (Gap haussier entre high précédent et low suivant)
            # Exemple: Bougie 1 high=100, Bougie 2 (moyenne), Bougie 3 low=102
            # → Il y a un gap entre 100 et 102 que le prix doit "combler"
            if prev_candle['high'] < next_candle['low']:
                gap_size = next_candle['low'] - prev_candle['high']
                if gap_size >= min_size:
                    fvg = FVG(
                        type=FVGType.SUPPLY,
                        timeframe=timeframe,
                        start_price=float(prev_candle['high']),
                        end_price=float(next_candle['low']),
                        start_time=datetime.now(),
                        end_time=datetime.now(),
                        volume_at_formation=float(current_candle.get('volume', 0)),
                        confidence=min(gap_size / avg_range / 3.0, 1.0)
                    )
                    fvgs.append(fvg)

            # FVG Demand (Gap baissier entre low précédent et high suivant)
            # Exemple: Bougie 1 low=100, Bougie 2 (moyenne), Bougie 3 high=98  
            # → Il y a un gap entre 100 et 98 zone de "demand"
            if prev_candle['low'] > next_candle['high']:
                gap_size = prev_candle['low'] - next_candle['high']
                if gap_size >= min_size:
                    fvg = FVG(
                        type=FVGType.DEMAND,
                        timeframe=timeframe,
                        start_price=float(prev_candle['low']),
                        end_price=float(next_candle['high']),
                        start_time=datetime.now(),
                        end_time=datetime.now(),
                        volume_at_formation=float(current_candle.get('volume', 0)),
                        confidence=min(gap_size / avg_range / 3.0, 1.0)
                    )
                    fvgs.append(fvg)

        return fvgs


class RiskManager:
    """Gestionnaire de risque pour trades Boom/Crash"""

    def __init__(self, max_risk_usd: float = 2.50, 
                 leverage: float = 100.0,
                 pip_value: float = 0.01):
        self.max_risk_usd = max_risk_usd
        self.leverage = leverage
        self.pip_value = pip_value

    def calculate_lot_size(self, entry_price: float, stop_loss: float, 
                           symbol: str) -> float:
        """Calcule le lot pour risque max $2.50"""
        sl_distance = abs(entry_price - stop_loss)
        
        if sl_distance <= 0:
            logger.warning("Distance SL invalide")
            return 0.01
        
        sl_pips = sl_distance / self.pip_value
        
        if sl_pips <= 0:
            return 0.01
        
        lot_size = self.max_risk_usd / (sl_pips * 1.0)
        lot_size = max(0.01, min(lot_size, 10.0))
        lot_size = round(lot_size, 2)
        
        logger.info(f"[{symbol}] Lot: {lot_size} (SL={sl_pips:.1f}pips, Risk=${self.max_risk_usd})")
        return lot_size

    def calculate_stop_loss(self, entry_price: float, direction: str, 
                           atr: Optional[float] = None,
                           min_sl_pips: float = 5.0) -> float:
        """Stop Loss adaptatif pour Boom/Crash"""
        if atr and atr > 0:
            sl_distance = max(atr * 2.0, min_sl_pips * self.pip_value)
        else:
            sl_distance = min_sl_pips * self.pip_value
        
        if direction == "BUY":
            return entry_price - sl_distance
        else:  # SELL
            return entry_price + sl_distance

    def calculate_take_profit(self, entry_price: float, 
                              stop_loss: float,
                              direction: str,
                              rr_ratio: float = 2.0) -> float:
        """Take Profit avec ratio R:R"""
        sl_distance = abs(entry_price - stop_loss)
        tp_distance = sl_distance * rr_ratio
        
        if direction == "BUY":
            return entry_price + tp_distance
        else:  # SELL
            return entry_price - tp_distance


class FVGSpikeDetector:
    """
    Détecteur principal de spikes FVG multi-timeframe
    Direction UNIDIRECTIONNELLE adaptée au symbole:
    - Boom/GAINX (BULLISH) → FVG Supply → SELL 
    - Crash/PAINX (BEARISH) → FVG Demand → BUY
    """

    def __init__(self, 
                 max_risk_usd: float = 2.50,
                 alert_cooldown_seconds: int = 300,  # 5 minutes
                 signal_cooldown_seconds: int = 60,   # 1 minute
                 confidence_threshold: float = 0.7):
        
        self.max_risk_usd = max_risk_usd
        self.alert_cooldown = timedelta(seconds=alert_cooldown_seconds)
        self.signal_cooldown = timedelta(seconds=signal_cooldown_seconds)
        self.confidence_threshold = confidence_threshold
        
        self.fvg_calc = FVGCalculator()
        self.risk_manager = RiskManager(max_risk_usd=max_risk_usd)
        
        # Stockage des données par symbole
        self._m5_data: Dict[str, pd.DataFrame] = {}
        self._m1_data: Dict[str, pd.DataFrame] = {}
        
        # Historique des signaux pour éviter les doublons
        self._last_alert: Dict[str, datetime] = {}
        self._last_signal: Dict[str, datetime] = {}
        
        # Callbacks
        self._alert_callbacks: List[callable] = []
        self._signal_callbacks: List[callable] = []
        
        logger.info(f"FVGSpikeDetector initialisé (Risk=${max_risk_usd})")

    def register_alert_callback(self, callback: callable):
        """Enregistre un callback pour les alertes M5"""
        self._alert_callbacks.append(callback)

    def register_signal_callback(self, callback: callable):
        """Enregistre un callback pour les signaux d'ordre"""
        self._signal_callbacks.append(callback)

    async def process_m5_candle(self, symbol: str, df_m5: pd.DataFrame) -> Optional[Alert]:
        """
        Traite une bougie M5 et génère une alerte
        
        Pour Boom/GAINX: Alerte sur FVG Supply (résistance)
        Pour Crash/PAINX: Alerte sur FVG Demand (support)
        """
        now = datetime.now()
        
        # Vérifier le cooldown
        last_alert = self._last_alert.get(symbol)
        if last_alert and (now - last_alert) < self.alert_cooldown:
            return None
        
        # Déterminer quel type de FVG surveiller selon le symbole
        target_fvg_type = get_fvg_target_for_symbol(symbol)
        
        # Détecter les FVG sur M5
        fvgs = self.fvg_calc.detect_fvg(df_m5, TimeFrame.M5)
        
        # Filtrer selon le type de FVG recherché pour ce symbole
        matching_fvgs = [
            f for f in fvgs 
            if f.type == target_fvg_type and f.confidence >= self.confidence_threshold
        ]
        
        if not matching_fvgs:
            return None
        
        # Prendre le meilleur FVG
        best_fvg = max(matching_fvgs, key=lambda x: x.confidence)
        
        # Direction du trade pour cette alerte
        trade_direction = get_trade_direction_for_symbol(symbol)
        symbol_dir = get_symbol_direction(symbol)
        
        # Message personnalisé selon le type de symbole
        if target_fvg_type == FVGType.SUPPLY:
            type_str = "SUPPLY (Résistance)"
            action_str = f"Vente [{trade_direction}]"
        else:
            type_str = "DEMAND (Support)"
            action_str = f"Achat [{trade_direction}]"
        
        alert = Alert(
            symbol=symbol,
            alert_type=f"FVG_{target_fvg_type.name}_M5",
            fvg=best_fvg,
            message=f"🚨 FVG {type_str} M5 sur {symbol} | "
                   f"Confiance: {best_fvg.confidence:.1%} | "
                   f"Size: {best_fvg.size:.2f} | "
                   f"Action potentielle: {action_str} | "
                   f"En attente de confirmation M1...",
            timestamp=now
        )
        
        self._last_alert[symbol] = now
        self._m5_data[symbol] = df_m5
        
        logger.info(f"[{symbol}] ALERTE M5: FVG {target_fvg_type.name} détecté "
                   f"(conf={best_fvg.confidence:.1%}, size={best_fvg.size:.2f}) -> {action_str}")
        
        # Déclencher les callbacks d'alerte
        for callback in self._alert_callbacks:
            try:
                if asyncio.iscoroutinefunction(callback):
                    await callback(alert)
                else:
                    callback(alert)
            except Exception as e:
                logger.error(f"Erreur alert callback: {e}")
        
        return alert

    async def process_m1_candle(self, symbol: str, df_m1: pd.DataFrame,
                                m5_alert: Optional[Alert] = None) -> Optional[SpikeSignal]:
        """
        Traite une bougie M1 et génère un signal si confluence
        
        Pour Boom/GAINX: FVG Supply M1 + FVG Supply M5 → SELL
        Pour Crash/PAINX: FVG Demand M1 + FVG Demand M5 → BUY
        """
        now = datetime.now()
        
        # Vérifier le cooldown
        last_signal = self._last_signal.get(symbol)
        if last_signal and (now - last_signal) < self.signal_cooldown:
            return None
        
        # Vérifier si une alerte M5 est active
        m5_recent = self._last_alert.get(symbol)
        if not m5_recent or (now - m5_recent) > self.alert_cooldown:
            return None
        
        # Déterminer le type de FVG à rechercher
        target_fvg_type = get_fvg_target_for_symbol(symbol)
        
        # Détecter les FVG sur M1
        fvgs = self.fvg_calc.detect_fvg(df_m1, TimeFrame.M1)
        matching_fvgs = [f for f in fvgs if f.type == target_fvg_type and f.confidence >= self.confidence_threshold]
        
        if not matching_fvgs:
            return None
        
        best_fvg_m1 = max(matching_fvgs, key=lambda x: x.confidence)
        
        # Confluence M5+M1
        confluence_confidence = min(1.0, best_fvg_m1.confidence + 0.2)
        if confluence_confidence < self.confidence_threshold:
            return None
        
        # Calculer les niveaux
        entry_price = float(df_m1['close'].iloc[-1])
        atr_series = (df_m1['high'] - df_m1['low']).rolling(14).mean()
        atr = float(atr_series.iloc[-1]) if not atr_series.empty and not pd.isna(atr_series.iloc[-1]) else None

        # Direction du trade selon le symbole
        direction = get_trade_direction_for_symbol(symbol)
        
        # Stop Loss adaptatif
        stop_loss = self.risk_manager.calculate_stop_loss(
            entry_price, direction, atr=atr, min_sl_pips=3.0
        )
        
        # Take Profit avec ratio 1:2
        take_profit = self.risk_manager.calculate_take_profit(
            entry_price, stop_loss, direction, rr_ratio=2.0
        )
        
        # Calcul du lot pour max $2.50
        lot_size = self.risk_manager.calculate_lot_size(entry_price, stop_loss, symbol)
        
        # Ajustement SL si risque réel > $2.50
        sl_distance = entry_price - stop_loss if direction == "BUY" else stop_loss - entry_price
        actual_risk = abs(sl_distance) / 0.01 * lot_size * 1.0
        if actual_risk > self.max_risk_usd:
            sl_pips_needed = self.max_risk_usd / (lot_size * 1.0)
            sl_distance_adjusted = sl_pips_needed * 0.01
            if direction == "BUY":
                stop_loss = entry_price - sl_distance_adjusted
            else:
                stop_loss = entry_price + sl_distance_adjusted
        
        signal = SpikeSignal(
            symbol=symbol,
            direction=direction,
            entry_price=round(entry_price, 5),
            stop_loss=round(stop_loss, 5),
            take_profit=round(take_profit, 5),
            lot_size=lot_size,
            confidence=confluence_confidence,
            timeframe_confluence=[TimeFrame.M5, TimeFrame.M1],
            risk_amount=self.max_risk_usd,
            fvg_m5=m5_alert.fvg if m5_alert else None,
            fvg_m1=best_fvg_m1,
            timestamp=now
        )
        
        self._last_signal[symbol] = now
        self._m1_data[symbol] = df_m1
        
        # Log du signal avec détails du symbole
        symbol_dir = get_symbol_direction(symbol)
        logger.info(f"[{symbol}] SIGNAL ({symbol_dir.value}): Spike {direction}! "
                   f"Entry={signal.entry_price}, SL={signal.stop_loss}, "
                   f"TP={signal.take_profit}, Lot={signal.lot_size}, "
                   f"Conf={signal.confidence:.1%}")
        
        # Déclencher les callbacks de signal
        for callback in self._signal_callbacks:
            try:
                if asyncio.iscoroutinefunction(callback):
                    await callback(signal)
                else:
                    callback(signal)
            except Exception as e:
                logger.error(f"Erreur signal callback: {e}")
        
        return signal

    async def run_detection_cycle(self, symbol: str, df_m5: pd.DataFrame, 
                                  df_m1: pd.DataFrame) -> Tuple[Optional[Alert], Optional[SpikeSignal]]:
        """
        Cycle complet de détection: M5 alerte puis M1 signal
        La logique est adaptée automatiquement selon le symbole:
        - Boom/GAINX (BULLISH indices) → SUPPLY → SELL
        - Crash/PAINX (BEARISH indices) → DEMAND → BUY
        """
        alert = None
        signal = None
        
        # Étape 1: Alerte M5 (type de FVG adapté au symbole)
        alert = await self.process_m5_candle(symbol, df_m5)
        
        # Étape 2: Signal M1 (même type de FVG pour confluence)
        signal = await self.process_m1_candle(symbol, df_m1, alert)
        
        return alert, signal

    def get_status(self, symbol: str) -> Dict:
        """Retourne le statut actuel pour un symbole"""
        now = datetime.now()
        last_alert = self._last_alert.get(symbol)
        last_signal = self._last_signal.get(symbol)
        
        # Type de FVG surveillé pour ce symbole
        target_fvg = get_fvg_target_for_symbol(symbol)
        trade_dir = get_trade_direction_for_symbol(symbol)
        symbol_dir = get_symbol_direction(symbol)
        
        return {
            "symbol": symbol,
            "symbol_direction": symbol_dir.value,
            "fvg_target": target_fvg.value,
            "trade_direction": trade_dir,
            "last_alert": last_alert.isoformat() if last_alert else None,
            "last_signal": last_signal.isoformat() if last_signal else None,
            "alert_active": last_alert is not None and (now - last_alert) < self.alert_cooldown,
            "signal_active": last_signal is not None and (now - last_signal) < self.signal_cooldown,
            "max_risk_usd": self.max_risk_usd,
            "confidence_threshold": self.confidence_threshold,
        }


# Exemple d'utilisation
if __name__ == "__main__":
    async def test_alert_callback(alert: Alert):
        print(f"\n{'='*60}")
        print(f"📱 CALLBACK ALERTE M5")
        print(f"[{alert.symbol}] {alert.message}")
        print(f"{'='*60}\n")
    
    async def test_signal_callback(signal: SpikeSignal):
        print(f"\n{'='*60}")
        print(f"🚀 CALLBACK SIGNAL TRADE")
        print(f"Symbole: {signal.symbol} (Direction: {signal.direction})")
        print(f"Entry: {signal.entry_price}")
        print(f"SL: {signal.stop_loss} (${signal.risk_amount} max)")
        print(f"TP: {signal.take_profit}")
        print(f"Lot: {signal.lot_size}")
        print(f"Confiance: {signal.confidence:.1%}")
        print(f"{'='*60}\n")
    
    # Créer le détecteur
    detector = FVGSpikeDetector(max_risk_usd=2.50)
    detector.register_alert_callback(test_alert_callback)
    detector.register_signal_callback(test_signal_callback)
    
    # ============================================
    # TEST 1: Simulation BOOM/GAINX (BULLISH)
    # Attend: FVG Supply → SELL
    # ============================================
    print("\n" + "="*70)
    print("TEST 1: BOOM 500 (indices BULLISH)")
    print("Attendu: Alerte FVG SUPPLY → Signal SELL")
    print("="*70)
    
    dates_m5 = pd.date_range(start="2024-01-01 10:00", periods=10, freq="5min")
    df_m5_boom = pd.DataFrame({
        'open':  [100.0, 100.5, 101.0, 100.8, 100.5, 100.2, 99.8, 99.5, 99.2, 98.8],
        'high':  [100.5, 101.2, 101.8, 101.5, 101.0, 100.8, 100.5, 100.2, 99.8, 99.5],
        'low':   [99.8, 100.2, 100.5, 100.3, 100.0, 99.8, 99.2, 98.8, 98.5, 98.2],
        'close': [100.2, 100.8, 101.5, 101.2, 100.8, 100.5, 100.0, 99.8, 99.2, 98.8],
        'volume': [100, 120, 80, 90, 110, 150, 200, 180, 160, 140]
    }, index=dates_m5)
    
    dates_m1 = pd.date_range(start="2024-01-01 10:45", periods=5, freq="1min")
    df_m1_boom = pd.DataFrame({
        'open':  [99.0, 98.8, 98.5, 98.3, 98.0],
        'high':  [99.2, 99.0, 98.8, 98.5, 98.2],
        'low':   [98.5, 98.3, 98.0, 97.8, 97.5],
        'close': [98.8, 98.5, 98.3, 98.0, 97.8],
        'volume': [50, 60, 45, 70, 55]
    }, index=dates_m1)

    alert_boom, signal_boom = asyncio.run(
        detector.run_detection_cycle("Boom 500", df_m5_boom, df_m1_boom)
    )
    
    # ============================================
    # TEST 2: Simulation CRASH/PAINX (BEARISH)  
    # Attend: FVG Demand → BUY
    # ============================================
    print("\n" + "="*70)
    print("TEST 2: Crash 1000 (indices BEARISH)")
    print("Attendu: Alerte FVG DEMAND → Signal BUY")
    print("="*70)
    
    dates_m5_crash = pd.date_range(start="2024-01-01 10:00", periods=10, freq="5min")
    # Crash indices chutent: high/low/close décroissants
    df_m5_crash = pd.DataFrame({
        'open':  [100.0, 99.5, 99.0, 98.8, 98.5, 98.2, 97.8, 97.5, 97.2, 96.8],
        'high':  [100.2, 99.8, 99.3, 99.0, 98.8, 98.5, 98.0, 97.8, 97.5, 97.0],
        'low':   [99.5, 99.0, 98.5, 98.2, 97.8, 97.5, 97.2, 96.8, 96.5, 96.2],
        'close': [99.8, 99.3, 98.8, 98.5, 98.2, 97.8, 97.5, 97.2, 96.8, 96.5],
        'volume': [100, 120, 80, 90, 110, 150, 200, 180, 160, 140]
    }, index=dates_m5_crash)
    
    dates_m1_crash = pd.date_range(start="2024-01-01 10:45", periods=5, freq="1min")
    df_m1_crash = pd.DataFrame({
        'open':  [96.5, 96.3, 96.0, 95.8, 95.5],
        'high':  [96.8, 96.5, 96.2, 96.0, 95.8],
        'low':   [96.0, 95.8, 95.5, 95.3, 95.0],
        'close': [96.2, 96.0, 95.8, 95.5, 95.3],
        'volume': [50, 60, 45, 70, 55]
    }, index=dates_m1_crash)

    alert_crash, signal_crash = asyncio.run(
        detector.run_detection_cycle("Crash 1000", df_m5_crash, df_m1_crash)
    )
    
    print("\n" + "="*70)
    print("RÉSULTATS FINAUX")
    print("="*70)
    print(f"\nBoom 500 Status: {detector.get_status('Boom 500')}")
    print(f"Crash 1000 Status: {detector.get_status('Crash 1000')}")
