class TradBOTError(Exception):
    pass

class OrderError(TradBOTError):
    pass

class InvalidStopsError(OrderError):
    def __init__(self, symbol: str, sl: float, tp: float, reason: str = ""):
        self.symbol = symbol
        self.sl = sl
        self.tp = tp
        self.reason = reason
        super().__init__(f"[InvalidStops] {symbol} SL={sl} TP={tp} — {reason}")

class InsufficientMarginError(OrderError):
    pass

class PositionLimitError(OrderError):
    pass

class PatternError(TradBOTError):
    pass

class GOMError(TradBOTError):
    pass
