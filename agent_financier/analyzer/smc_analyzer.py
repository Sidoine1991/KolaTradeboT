#!/usr/bin/env python3
"
Analyseur SMC (Smart Money Concepts).
Détecte Order Blocks, Fair Value Gaps, Break of Structure, Liquidity Sweeps.
"
import numpy as np
import pandas as pd
from typing import List, Dict, Tuple, Any, Optional
from dataclasses import dataclass
from enum import Enum
import logging

logger = logging.getLogger(__name__)

class SetupType(Enum):
    ORDER_BLOCK = "Order Block"
    FVG = "Fair Value Gap"
    LIQUIDITY_SWEEP = "Liquidity Sweep"
    BREAK_OF_STRUCTURE = "Break of Structure"
    MITIGATION = "Mitigation"

@dataclass
class SMC_Setup:
    setup_type: SetupType
    direction: str  # BUY ou SELL
    entry_price: float
    stop_loss: float
    take_profit_1: float
    take_profit_2: float
    take_profit_3: float
    confidence: int  # 0-100
    timeframe: str
    symbol: str
    description: str
    risk_reward: float
    
class SMC_Analyzer:
    """Analyse technique professionnelle selon Smart Money Concepts."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        logger.info("Analyseur SMC initialisé")
    
    def detect_order_blocks(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Détecte les Order Blocks (imbalance + structure)."""
        obs = []
        if len(df) < 10:
            return obs
        
        closes = df['close'].values
        opens = df['open'].values
        highs = df['high'].values
        lows = df['low'].values
        
        for i in range(3, min(len(df) - 3, len(df))):
            # Order Block haussier: forte bougie baissière suivie d'une explosion haussière
            if closes[i] < opens[i] and closes[i-1] > opens[i-1] and closes[i+1] > opens[i+1]:
                if closes[i+1] > highs[i-1]:  # Break de la zone
                    ob_low = min(lows[i-2:i+1])
                    ob_high = max(highs[i-2:i+1])
                    obs.append({
                        'type': 'bullish',
                        'low': ob_low,
                        'high': ob_high,
                        'index': i,
                        'confidence': 75
                    })
            
            # Order Block baissier
            elif closes[i] > opens[i] and closes[i-1] < opens[i-1] and closes[i+1] < opens[i+1]:
                if closes[i+1] < lows[i-1]:
                    ob_low = min(lows[i-2:i+1])
                    ob_high = max(highs[i-2:i+1])
                    obs.append({
                        'type': 'bearish',
                        'low': ob_low,
                        'high': ob_high,
                        'index': i,
                        'confidence': 75
                    })
        return obs
    
    def detect_fvg(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Détecte les Fair Value Gaps."""
        fvgs = []
        if len(df) < 5:
            return fvgs
        
        highs = df['high'].values
        lows = df['low'].values
        
        for i in range(2, len(df) - 1):
            # FVG baissier: low[i] > high[i-2]
            if lows[i] > highs[i-2]:
                fvgs.append({
                    'type': 'bearish',
                    'top': lows[i],
                    'bottom': highs[i-2],
                    'index': i,
                    'confidence': 80
                })
            
            # FVG haussier: high[i] < lows[i-2]
            elif highs[i] < lows[i-2]:
                fvgs.append({
                    'type': 'bullish',
                    'top': lows[i-2],
                    'bottom': highs[i],
                    'index': i,
                    'confidence': 80
                })
        
        return fvgs
    
    def generate_setup(self, symbol: str, df: pd.DataFrame, timeframe: str = "H1") -> Optional[SMC_Setup]:
        """Génère un setup SMC complet avec entry, SL, TP."""
        obs = self.detect_order_blocks(df)
        fvgs = self.detect_fvg(df)
        
        if not obs and not fvgs:
            return None
        
        # Priorité aux setups les plus confiants
        current_price = df['close'].iloc[-1]
        
        if obs:
            best_ob = max(obs, key=lambda x: x['confidence'])
            is_bullish = best_ob['type'] == 'bullish'
            
            entry = best_ob['high'] if is_bullish else best_ob['low']
            sl = best_ob['low'] - (current_price * 0.002) if is_bullish else best_ob['high'] + (current_price * 0.002)
            rr = 2.0
            tp = entry + (entry - sl) * rr if is_bullish else entry - (sl - entry) * rr
            
            return SMC_Setup(
                setup_type=SetupType.ORDER_BLOCK,
                direction="BUY" if is_bullish else "SELL",
                entry_price=round(entry, 5),
                stop_loss=round(sl, 5),
                take_profit_1=round(tp, 5),
                take_profit_2=round(tp * 1.5, 5),
                take_profit_3=round(tp * 2.0, 5),
                confidence=best_ob['confidence'],
                timeframe=timeframe,
                symbol=symbol,
                description=f"Order Block {'haussier' if is_bullish else 'baissier'} sur {timeframe}",
                risk_reward=rr
            )
        
        return None

if __name__ == "__main__":
    analyzer = SMC_Analyzer()
    print("Analyseur SMC prêt")
