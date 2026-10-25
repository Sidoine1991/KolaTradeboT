from __future__ import annotations
from dataclasses import dataclass
from typing import Optional, Tuple, List, Dict


@dataclass
class FiboLevels:
    zero: float
    fifty: float
    seventy_eight: float
    eighty_eight: float
    one: float

    def classify_zone(self, price: float, trend: str) -> str:
        # trend: 'bullish' or 'bearish'
        if self.zero <= self.one:
            low, high = self.zero, self.one
        else:
            low, high = self.one, self.zero
        # Normalize
        p = max(min(price, high), low)
        if trend == 'bullish':
            if p <= self.fifty:
                return 'buy_zone_safe_0_0.5'
            elif p <= self.seventy_eight:
                return 'mid_zone_0.5_0.78'
            else:
                return 'sell_ote_0.78_1'
        else:
            if p >= self.fifty:
                return 'sell_zone_safe_1_0.5'
            elif p >= self.seventy_eight:
                return 'mid_zone_0.5_0.78'
            else:
                return 'buy_ote_0_0.22'


def compute_fibo_levels(high: float, low: float) -> FiboLevels:
    # From low -> high (impulse direction)
    zero = low
    one = high
    rng = one - zero
    fifty = zero + 0.5 * rng
    seventy_eight = zero + 0.78 * rng
    eighty_eight = zero + 0.88 * rng
    return FiboLevels(zero=zero, fifty=fifty, seventy_eight=seventy_eight, eighty_eight=eighty_eight, one=one)


def detect_bos(highs: List[float], lows: List[float]) -> Optional[str]:
    # Simple BOS: new swing high above previous swing high -> bullish; vice versa for bearish
    if len(highs) < 3 or len(lows) < 3:
        return None
    last_high = highs[-1]
    prev_high = highs[-3]
    last_low = lows[-1]
    prev_low = lows[-3]
    if last_high > prev_high:
        return 'bullish'
    if last_low < prev_low:
        return 'bearish'
    return None


def find_order_block(opens: List[float], highs: List[float], lows: List[float], closes: List[float], trend: str) -> Optional[Tuple[float, float]]:
    # Return OB price range (low, high)
    n = len(opens)
    if n == 0:
        return None
    rng = range(max(0, n - 50), n)  # last 50 bars
    if trend == 'bullish':
        # Look for last bearish candle body before impulse up
        for i in reversed(list(rng)):
            if closes[i] < opens[i]:
                ob_low = min(opens[i], closes[i], lows[i])
                ob_high = max(opens[i], closes[i], highs[i])
                return (ob_low, ob_high)
    else:
        for i in reversed(list(rng)):
            if closes[i] > opens[i]:
                ob_low = min(opens[i], closes[i], lows[i])
                ob_high = max(opens[i], closes[i], highs[i])
                return (ob_low, ob_high)
    return None


@dataclass
class EntryDecision:
    side: str  # 'BUY' | 'SELL' | 'HOLD'
    reason: str
    entry: float
    sl: float
    tp: float


def decide_entry(price: float,
                 highs: List[float],
                 lows: List[float],
                 opens: List[float],
                 closes: List[float],
                 trend: Optional[str],
                 atr: float,
                 rr_min: float = 2.0) -> EntryDecision:
    """Implements core rules:
    - BUY in 0.0-0.5 when bullish BOS; SELL in 0.78-1.0 (OTE) when bearish BOS
    - Prefer OB test, SL beyond OB, TP via RR
    """
    if not highs or not lows or price <= 0:
        return EntryDecision('HOLD', 'insufficient_data', 0, 0, 0)

    # Determine impulse leg (simple: last 50 bars high/low)
    win = max(10, min(50, len(highs)))
    swing_high = max(highs[-win:])
    swing_low = min(lows[-win:])
    fib = compute_fibo_levels(high=swing_high, low=swing_low)

    bos_dir = trend or detect_bos(highs, lows) or 'neutral'
    zone = fib.classify_zone(price, bos_dir if bos_dir in ('bullish', 'bearish') else 'bullish')

    # OB
    ob = find_order_block(opens, highs, lows, closes, trend=bos_dir if bos_dir in ('bullish', 'bearish') else 'bullish')

    def build(side: str, reason: str) -> EntryDecision:
        entry = price
        sl = 0.0
        if ob:
            ob_low, ob_high = ob
            if side == 'BUY':
                sl = min(ob_low, entry - 1.0 * atr)
            else:
                sl = max(ob_high, entry + 1.0 * atr)
        else:
            sl = entry - 1.0 * atr if side == 'BUY' else entry + 1.0 * atr
        risk = abs(entry - sl)
        tp = entry + rr_min * risk if side == 'BUY' else entry - rr_min * risk
        return EntryDecision(side, reason, entry, sl, tp)

    # Rules
    if bos_dir == 'bullish' and zone == 'buy_zone_safe_0_0.5':
        return build('BUY', f'bullish_bos + zone={zone}')
    if bos_dir == 'bearish' and zone == 'sell_ote_0.78_1':
        return build('SELL', f'bearish_bos + zone={zone}')

    # Otherwise hold
    return EntryDecision('HOLD', f'bos={bos_dir} zone={zone}', 0, 0, 0)
