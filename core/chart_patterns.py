"""
Chart Pattern Manager — Détection temps réel des patterns SMC
===============================================================

Patterns supportés (Smart Money Concepts):
  - BOS   (Break of Structure)   → Cassure de structure haussière/baissière
  - CHoCH (Change of Character)  → Changement de caractère du marché
  - FVG   (Fair Value Gap)       → Zone de liquidité non comblée
  - OB    (Order Block)          → Bloc d'ordres institutionnels
  - MSS   (Market Structure Shift) → Changement de structure

Chaque pattern est scoré (0-100) et horodaté pour exploitation avec GOM.
"""

import time
import logging
try:
    import MetaTrader5 as mt5
    _MT5_OK = True
except ImportError:
    mt5 = None
    _MT5_OK = False
import numpy as np
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Tuple, Any
from datetime import datetime
from enum import Enum

logger = logging.getLogger("tradbot.chart_patterns")

# ──────────────────────────────────────────────────────────────
# Types
# ──────────────────────────────────────────────────────────────

class PatternType(str, Enum):
    BOS = "BOS"
    CHOCH = "CHoCH"
    FVG = "FVG"
    ORDER_BLOCK = "OB"
    MSS = "MSS"

class PatternDirection(str, Enum):
    BULLISH = "bullish"
    BEARISH = "bearish"
    NEUTRAL = "neutral"

@dataclass
class DetectedPattern:
    pattern_type: PatternType
    direction: PatternDirection
    symbol: str
    timeframe: str
    price: float
    strength: float  # 0.0 - 1.0
    confidence: float  # 0.0 - 1.0
    timestamp: float = 0.0
    details: Dict = field(default_factory=dict)
    is_active: bool = True

    def to_dict(self) -> Dict:
        return asdict(self)


class ChartPatternManager:
    """
    Analyse en temps réel les bougies MT5 pour détecter les patterns SMC.
    Compatible avec tous les timeframes (M1, M5, M15, H1).
    """

    def __init__(self):
        self._detected_patterns: List[DetectedPattern] = []
        self._last_scan: Dict[str, float] = {}

    # ──────────────────────────────────────────────────────────
    # Public API
    # ──────────────────────────────────────────────────────────

    def scan_symbol(self, symbol: str, timeframe: str = "M15") -> List[DetectedPattern]:
        """
        Analyse complète d'un symbole sur un timeframe donné.
        Retourne tous les patterns détectés.
        """
        if not _MT5_OK:
            logger.warning(f"scan_symbol: MT5 non disponible, impossible de scanner {symbol}")
            return []
        tf = self._parse_tf(timeframe)
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, 60)
        if rates is None or len(rates) < 20:
            logger.warning(f"scan_symbol: données insuffisantes pour {symbol} {timeframe}")
            return []

        closes = np.array([r["close"] for r in rates], dtype=float)
        highs = np.array([r["high"] for r in rates], dtype=float)
        lows = np.array([r["low"] for r in rates], dtype=float)
        opens = np.array([r["open"] for r in rates], dtype=float)
        times = [r["time"] for r in rates]

        patterns = []
        patterns.extend(self._detect_bos(symbol, timeframe, closes, highs, lows, times))
        patterns.extend(self._detect_choch(symbol, timeframe, closes, highs, lows, times))
        patterns.extend(self._detect_fvg(symbol, timeframe, opens, highs, lows, times))
        patterns.extend(self._detect_order_blocks(symbol, timeframe, opens, highs, lows, closes, times))

        # Marquer les patterns inactifs (cassés)
        self._update_active_status(symbol, prices=closes[-1])

        self._detected_patterns.extend(patterns)
        self._last_scan[symbol] = time.time()

        return patterns

    def get_active_patterns(self, symbol: Optional[str] = None,
                            pattern_type: Optional[PatternType] = None) -> List[DetectedPattern]:
        """Retourne les patterns actifs, filtrés optionnellement."""
        result = [p for p in self._detected_patterns if p.is_active]
        if symbol:
            result = [p for p in result if p.symbol == symbol]
        if pattern_type:
            result = [p for p in result if p.pattern_type == pattern_type]
        return result

    def get_pattern_summary(self, symbol: str) -> Dict:
        """Résumé des patterns actifs pour un symbole."""
        active = self.get_active_patterns(symbol)
        return {
            "symbol": symbol,
            "total_active": len(active),
            "bullish_count": sum(1 for p in active if p.direction == PatternDirection.BULLISH),
            "bearish_count": sum(1 for p in active if p.direction == PatternDirection.BEARISH),
            "patterns": [p.to_dict() for p in active],
            "last_scan": self._last_scan.get(symbol, 0),
            "bias": self._compute_bias(active),
        }

    def get_tradeable_patterns(self, symbol: str, gom_direction: str,
                               min_confidence: float = 0.6) -> List[DetectedPattern]:
        """
        Retourne les patterns alignés avec la direction GOM,
        avec confiance >= min_confidence.
        """
        gom_dir = PatternDirection.BULLISH if gom_direction.upper() in ("BUY", "GOOD") else \
                  PatternDirection.BEARISH if gom_direction.upper() in ("SELL", "PERFECT") else \
                  PatternDirection.NEUTRAL

        active = self.get_active_patterns(symbol)
        aligned = []
        for p in active:
            if p.direction == gom_dir and p.confidence >= min_confidence:
                aligned.append(p)
            elif gom_dir == PatternDirection.NEUTRAL:
                if p.confidence >= min_confidence:
                    aligned.append(p)
        return sorted(aligned, key=lambda x: -x.confidence)

    # ──────────────────────────────────────────────────────────
    # Détection BOS (Break of Structure)
    # ──────────────────────────────────────────────────────────

    def _detect_bos(self, symbol: str, tf: str, closes: np.ndarray,
                    highs: np.ndarray, lows: np.ndarray,
                    times: List) -> List[DetectedPattern]:
        """Break of Structure: cassure d'un swing high/low précédent."""
        patterns = []
        n = len(closes)
        if n < 15:
            return patterns

        # Trouver les swing highs/lows
        swing_highs = self._find_swing_highs(highs, 5)
        swing_lows = self._find_swing_lows(lows, 5)

        # BOS haussier: cassure d'un swing high
        for idx in swing_highs:
            if idx < 5 or idx >= n - 1:
                continue
            swing_level = highs[idx]
            prev_highs = highs[max(0, idx - 5):idx]
            if len(prev_highs) == 0:
                continue

            # La cassure est confirmée si close > swing_level
            if closes[-1] > swing_level:
                strength = min(1.0, abs(closes[-1] - swing_level) / (np.std(closes[-20:]) + 1e-10) * 0.5)
                patterns.append(DetectedPattern(
                    pattern_type=PatternType.BOS,
                    direction=PatternDirection.BULLISH,
                    symbol=symbol, timeframe=tf, price=closes[-1],
                    strength=strength, confidence=0.5 + strength * 0.4,
                    timestamp=times[-1],
                    details={"swing_level": swing_level, "swing_index": idx,
                             "break_price": closes[-1]}
                ))

        # BOS baissier: cassure d'un swing low
        for idx in swing_lows:
            if idx < 5 or idx >= n - 1:
                continue
            swing_level = lows[idx]
            prev_lows = lows[max(0, idx - 5):idx]
            if len(prev_lows) == 0:
                continue

            if closes[-1] < swing_level:
                strength = min(1.0, abs(swing_level - closes[-1]) / (np.std(closes[-20:]) + 1e-10) * 0.5)
                patterns.append(DetectedPattern(
                    pattern_type=PatternType.BOS,
                    direction=PatternDirection.BEARISH,
                    symbol=symbol, timeframe=tf, price=closes[-1],
                    strength=strength, confidence=0.5 + strength * 0.4,
                    timestamp=times[-1],
                    details={"swing_level": swing_level, "swing_index": idx,
                             "break_price": closes[-1]}
                ))

        return patterns

    # ──────────────────────────────────────────────────────────
    # Détection CHoCH (Change of Character)
    # ──────────────────────────────────────────────────────────

    def _detect_choch(self, symbol: str, tf: str, closes: np.ndarray,
                      highs: np.ndarray, lows: np.ndarray,
                      times: List) -> List[DetectedPattern]:
        """
        Change of Character: un plus haut plus bas que le précédent
        (ou un plus bas plus haut) signale un changement de tendance.
        """
        patterns = []
        n = len(closes)
        if n < 20:
            return patterns

        swing_highs = self._find_swing_highs(highs, 5)
        swing_lows = self._find_swing_lows(lows, 5)

        # CHoCH baissier: un swing high plus bas que le précédent
        if len(swing_highs) >= 3:
            last_three = swing_highs[-3:]
            if len(last_three) == 3:
                h1, h2, h3 = highs[last_three[0]], highs[last_three[1]], highs[last_three[2]]
                if h2 > h1 and h3 < h2:
                    strength = min(1.0, abs(h2 - h3) / (np.std(closes[-20:]) + 1e-10))
                    patterns.append(DetectedPattern(
                        pattern_type=PatternType.CHOCH,
                        direction=PatternDirection.BEARISH,
                        symbol=symbol, timeframe=tf, price=closes[-1],
                        strength=strength, confidence=0.55 + strength * 0.35,
                        timestamp=times[-1],
                        details={"prev_high": h1, "top_high": h2, "lower_high": h3}
                    ))

        # CHoCH haussier: un swing low plus haut que le précédent
        if len(swing_lows) >= 3:
            last_three = swing_lows[-3:]
            if len(last_three) == 3:
                l1, l2, l3 = lows[last_three[0]], lows[last_three[1]], lows[last_three[2]]
                if l2 < l1 and l3 > l2:
                    strength = min(1.0, abs(l3 - l2) / (np.std(closes[-20:]) + 1e-10))
                    patterns.append(DetectedPattern(
                        pattern_type=PatternType.CHOCH,
                        direction=PatternDirection.BULLISH,
                        symbol=symbol, timeframe=tf, price=closes[-1],
                        strength=strength, confidence=0.55 + strength * 0.35,
                        timestamp=times[-1],
                        details={"prev_low": l1, "bottom_low": l2, "higher_low": l3}
                    ))

        return patterns

    # ──────────────────────────────────────────────────────────
    # Détection FVG (Fair Value Gap)
    # ──────────────────────────────────────────────────────────

    def _detect_fvg(self, symbol: str, tf: str, opens: np.ndarray,
                    highs: np.ndarray, lows: np.ndarray,
                    times: List) -> List[DetectedPattern]:
        """
        Fair Value Gap: écart entre 3 bougies consécutives.
        - FVG haussier: low(bougie3) > high(bougie1)
        - FVG baissier: high(bougie3) < low(bougie1)
        """
        patterns = []
        n = len(opens)
        if n < 5:
            return patterns

        for i in range(n - 3):
            # Gap haussier
            if lows[i + 2] > highs[i]:
                gap_top = lows[i + 2]
                gap_bottom = highs[i]
                gap_size = gap_top - gap_bottom
                avg_atr = np.mean([abs(highs[j] - lows[j]) for j in range(max(0, i-5), i+3)])
                if avg_atr > 0:
                    strength = min(1.0, gap_size / avg_atr * 2)
                    patterns.append(DetectedPattern(
                        pattern_type=PatternType.FVG,
                        direction=PatternDirection.BULLISH,
                        symbol=symbol, timeframe=tf,
                        price=(gap_top + gap_bottom) / 2,
                        strength=strength,
                        confidence=min(0.9, 0.5 + strength * 0.4),
                        timestamp=times[i + 2],
                        details={"gap_top": gap_top, "gap_bottom": gap_bottom,
                                 "gap_size": gap_size, "candle_index": i + 2}
                    ))

            # Gap baissier
            if highs[i + 2] < lows[i]:
                gap_top = lows[i]
                gap_bottom = highs[i + 2]
                gap_size = gap_top - gap_bottom
                avg_atr = np.mean([abs(highs[j] - lows[j]) for j in range(max(0, i-5), i+3)])
                if avg_atr > 0:
                    strength = min(1.0, gap_size / avg_atr * 2)
                    patterns.append(DetectedPattern(
                        pattern_type=PatternType.FVG,
                        direction=PatternDirection.BEARISH,
                        symbol=symbol, timeframe=tf,
                        price=(gap_top + gap_bottom) / 2,
                        strength=strength,
                        confidence=min(0.9, 0.5 + strength * 0.4),
                        timestamp=times[i + 2],
                        details={"gap_top": gap_top, "gap_bottom": gap_bottom,
                                 "gap_size": gap_size, "candle_index": i + 2}
                    ))

        return patterns

    # ──────────────────────────────────────────────────────────
    # Détection Order Blocks
    # ──────────────────────────────────────────────────────────

    def _detect_order_blocks(self, symbol: str, tf: str, opens: np.ndarray,
                             highs: np.ndarray, lows: np.ndarray,
                             closes: np.ndarray, times: List) -> List[DetectedPattern]:
        """
        Order Block: dernière bougie opposée avant un fort mouvement.
        - OB haussier: bougie baissière avant un fort mouvement haussier
        - OB baissier: bougie haussière avant un fort mouvement baissier
        """
        patterns = []
        n = len(opens)
        if n < 10:
            return patterns

        for i in range(5, n - 3):
            # Taille du mouvement après la bougie i
            move_bullish = closes[i + 2] - highs[i + 1] > np.std(closes[max(0, i-10):i+3]) * 1.5
            move_bearish = lows[i + 1] - closes[i + 2] > np.std(closes[max(0, i-10):i+3]) * 1.5

            # OB haussier: bougie rouge ➔ fort mouvement vert
            if closes[i] < opens[i] and move_bullish:
                strength = min(1.0, abs(closes[i + 2] - highs[i + 1]) / (np.std(closes[max(0, i-10):i+3]) + 1e-10))
                patterns.append(DetectedPattern(
                    pattern_type=PatternType.ORDER_BLOCK,
                    direction=PatternDirection.BULLISH,
                    symbol=symbol, timeframe=tf, price=closes[i + 2],
                    strength=strength, confidence=0.5 + strength * 0.4,
                    timestamp=times[i],
                    details={"ob_high": highs[i], "ob_low": lows[i],
                             "ob_close": closes[i], "ob_index": i}
                ))

            # OB baissier: bougie verte ➔ fort mouvement rouge
            if closes[i] > opens[i] and move_bearish:
                strength = min(1.0, abs(lows[i + 1] - closes[i + 2]) / (np.std(closes[max(0, i-10):i+3]) + 1e-10))
                patterns.append(DetectedPattern(
                    pattern_type=PatternType.ORDER_BLOCK,
                    direction=PatternDirection.BEARISH,
                    symbol=symbol, timeframe=tf, price=closes[i + 2],
                    strength=strength, confidence=0.5 + strength * 0.4,
                    timestamp=times[i],
                    details={"ob_high": highs[i], "ob_low": lows[i],
                             "ob_close": closes[i], "ob_index": i}
                ))

        return patterns

    # ──────────────────────────────────────────────────────────
    # Utilitaires
    # ──────────────────────────────────────────────────────────

    def _find_swing_highs(self, highs: np.ndarray, lookback: int = 5) -> List[int]:
        indices = []
        n = len(highs)
        for i in range(lookback, n - lookback):
            if highs[i] == max(highs[i - lookback:i + lookback + 1]):
                if i > 0 and highs[i] != highs[i - 1]:  # Éviter les doublons
                    indices.append(i)
        return indices

    def _find_swing_lows(self, lows: np.ndarray, lookback: int = 5) -> List[int]:
        indices = []
        n = len(lows)
        for i in range(lookback, n - lookback):
            if lows[i] == min(lows[i - lookback:i + lookback + 1]):
                if i > 0 and lows[i] != lows[i - 1]:
                    indices.append(i)
        return indices

    def _update_active_status(self, symbol: str, prices: float) -> None:
        """Marque les patterns comme inactifs si le prix les a cassés."""
        for p in self._detected_patterns:
            if not p.is_active or p.symbol != symbol:
                continue

            if p.pattern_type == PatternType.FVG:
                if p.direction == PatternDirection.BULLISH and prices < p.details.get("gap_bottom", 0):
                    p.is_active = False
                elif p.direction == PatternDirection.BEARISH and prices > p.details.get("gap_top", 0):
                    p.is_active = False

            if p.pattern_type == PatternType.ORDER_BLOCK:
                if p.direction == PatternDirection.BULLISH and prices < p.details.get("ob_low", 0):
                    p.is_active = False
                elif p.direction == PatternDirection.BEARISH and prices > p.details.get("ob_high", 0):
                    p.is_active = False

    def _compute_bias(self, patterns: List[DetectedPattern]) -> str:
        """Calcule le biais global basé sur les patterns actifs."""
        if not patterns:
            return "neutral"
        score = sum(p.confidence * (1 if p.direction == PatternDirection.BULLISH else -1) for p in patterns)
        if score > 1.5:
            return "bullish"
        if score < -1.5:
            return "bearish"
        return "neutral"

    @staticmethod
    def _parse_tf(timeframe: str) -> int:
        mapping = {
            "M1": mt5.TIMEFRAME_M1, "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15, "M30": mt5.TIMEFRAME_M30,
            "H1": mt5.TIMEFRAME_H1, "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1,
        }
        return mapping.get(timeframe.upper(), mt5.TIMEFRAME_M15)
