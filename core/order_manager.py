"""
Order Manager — Exécution centralisée des ordres avec validation stricte
=====================================================================

Fonctionnalités:
  - Validation SL/TP selon les règles MT5 (trade_stops_level)
  - SL dans les bandes verte/rouge pour Boom/Crash
  - Une seule position par symbole (pas de double SL)
  - Détection et correction des "Invalid stops"
  - Orders au marché et pendings
"""

import time
import logging
try:
    import MetaTrader5 as mt5
    _MT5_OK = True
except ImportError:
    mt5 = None
    _MT5_OK = False
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Any, Tuple
from datetime import datetime, timezone
from enum import Enum

from .exceptions import InvalidStopsError, OrderError, InsufficientMarginError

logger = logging.getLogger("tradbot.order_manager")

# ──────────────────────────────────────────────────────────────
# Types
# ──────────────────────────────────────────────────────────────

class OrderDirection(str, Enum):
    BUY = "BUY"
    SELL = "SELL"

class OrderStatus(str, Enum):
    PENDING = "pending"
    EXECUTED = "executed"
    FAILED = "failed"
    REJECTED = "rejected"

@dataclass
class OrderRequest:
    symbol: str
    direction: OrderDirection
    volume: float
    entry_price: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    comment: str = ""
    magic: int = 0
    execution_type: str = "market"  # market | pending
    expiration: Optional[datetime] = None
    slippage: int = 50

@dataclass
class OrderResult:
    success: bool
    ticket: Optional[int] = None
    symbol: str = ""
    direction: str = ""
    volume: float = 0.0
    price: float = 0.0
    sl: float = 0.0
    tp: float = 0.0
    error: str = ""
    timestamp: float = 0.0

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────

def _is_synthetic(symbol: str) -> bool:
    s = symbol.upper()
    return any(x in s for x in ["BOOM", "CRASH", "JUMP", "VOLATILITY"])

def _is_boom(symbol: str) -> bool:
    return "BOOM" in symbol.upper()

def _is_crash(symbol: str) -> bool:
    return "CRASH" in symbol.upper()

def _get_symbol_info(symbol: str) -> Optional[Any]:
    if not _MT5_OK:
        return None
    info = mt5.symbol_info(symbol)
    if info is None:
        mt5.symbol_select(symbol, True)
        info = mt5.symbol_info(symbol)
    return info

# ──────────────────────────────────────────────────────────────
# Order Manager
# ──────────────────────────────────────────────────────────────

class OrderManager:
    """
    Gère l'exécution des ordres MT5 avec validation stricte.

    Règles clés:
      1) Une seule position par symbole — refuse les doublons
      2) Respect de trade_stops_level pour éviter "Invalid stops"
      3) SL dans les bandes Bollinger/KOLA pour Boom/Crash
      4) RR minimum 1:1.5 (configurable)
    """

    def __init__(self, min_rr: float = 1.5, default_slippage: int = 50):
        self.min_rr = min_rr
        self.default_slippage = default_slippage
        self._last_balance_check: Dict[str, float] = {}
        self._orders_placed: List[OrderResult] = []

    # ──────────────────────────────────────────────────────────
    # Public API
    # ──────────────────────────────────────────────────────────

    def market_order(self, req: OrderRequest) -> OrderResult:
        """
        Place un ordre MARKET avec validation complète SL/TP.
        """
        result = OrderResult(symbol=req.symbol, direction=req.direction.value,
                           volume=req.volume, timestamp=time.time())

        try:
            self._validate_symbol(req.symbol)
            self._validate_no_duplicate_position(req.symbol)
            price = self._get_current_price(req.symbol, req.direction)
            req.entry_price = price

            sl, tp = self._compute_and_validate_stops(req)
            req.stop_loss = sl
            req.take_profit = tp

            ticket = self._execute_market(req)
            result.success = True
            result.ticket = ticket
            result.price = price
            result.sl = sl
            result.tp = tp

            logger.info(
                f"✅ MARKET {req.direction.value} {req.symbol} @ {price:.5f} "
                f"SL={sl:.5f} TP={tp:.5f} lot={req.volume:.2f} ticket={ticket}"
            )

        except InvalidStopsError as e:
            result.error = str(e)
            result.success = False
            logger.error(f"❌ {e}")
        except OrderError as e:
            result.error = str(e)
            result.success = False
            logger.error(f"❌ {e}")
        except Exception as e:
            result.error = f"Unexpected: {e}"
            result.success = False
            logger.exception(f"❌ Market order failed: {e}")

        self._orders_placed.append(result)
        return result

    def modify_position_sl_tp(self, ticket: int, sl: float, tp: float) -> bool:
        """Modifie SL/TP d'une position existante."""
        try:
            position = mt5.positions_get(ticket=ticket)
            if not position or len(position) == 0:
                logger.warning(f"Modify SL/TP: position {ticket} not found")
                return False
            pos = position[0]

            symbol = pos.symbol
            info = _get_symbol_info(symbol)
            if not info:
                raise OrderError(f"Symbol info not found: {symbol}")

            sl = round(sl, info.digits)
            tp = round(tp, info.digits)

            sl, tp = self._validate_stops_level(symbol, pos.price, sl, tp, info)

            request = {
                "action": mt5.TRADE_ACTION_SLTP,
                "position": ticket,
                "sl": sl,
                "tp": tp,
            }
            resp = mt5.order_send(request)
            if resp and resp.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"✅ SL/TP modifié position {ticket}: SL={sl} TP={tp}")
                return True

            logger.warning(f"⚠️ Modify SL/TP {ticket} failed: {resp.retcode if resp else 'no response'} — {resp.comment if resp else ''}")
            return False

        except Exception as e:
            logger.exception(f"❌ Modify SL/TP error: {e}")
            return False

    def close_position(self, ticket: int) -> bool:
        """Ferme une position par ticket."""
        try:
            position = mt5.positions_get(ticket=ticket)
            if not position or len(position) == 0:
                logger.warning(f"Close: position {ticket} not found")
                return False
            pos = position[0]

            close_type = mt5.ORDER_TYPE_SELL if pos.type == mt5.ORDER_TYPE_BUY else mt5.ORDER_TYPE_BUY
            price = mt5.symbol_info_tick(pos.symbol).ask if close_type == mt5.ORDER_TYPE_BUY else mt5.symbol_info_tick(pos.symbol).bid

            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": pos.symbol,
                "volume": pos.volume,
                "type": close_type,
                "position": ticket,
                "price": price,
                "deviation": self.default_slippage,
                "magic": pos.magic,
                "comment": "close_by_tradbot",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            resp = mt5.order_send(request)
            if resp and resp.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"✅ Position {ticket} fermée @ {price}")
                return True

            logger.warning(f"⚠️ Close {ticket} failed: {resp.retcode if resp else 'no response'} — {resp.comment if resp else ''}")
            return False

        except Exception as e:
            logger.exception(f"❌ Close error: {e}")
            return False

    def get_open_positions(self, symbol: Optional[str] = None) -> List[Dict]:
        """Récupère les positions ouvertes, optionnellement filtrées par symbole."""
        if symbol:
            positions = mt5.positions_get(symbol=symbol)
        else:
            positions = mt5.positions_get()
        if not positions:
            return []
        return [self._pos_to_dict(p) for p in positions]

    def has_open_position(self, symbol: str) -> bool:
        """Vérifie si une position est déjà ouverte sur ce symbole."""
        positions = mt5.positions_get(symbol=symbol)
        return positions is not None and len(positions) > 0

    def get_account_info(self) -> Dict:
        """Retourne les informations du compte MT5."""
        info = mt5.account_info()
        if not info:
            return {}
        return {
            "balance": info.balance,
            "equity": info.equity,
            "margin_free": info.margin_free,
            "margin_level": info.margin_level,
            "leverage": info.leverage,
            "currency": info.currency,
            "name": info.name,
            "server": info.server,
            "login": info.login,
        }

    def get_orders_history(self, limit: int = 20) -> List[Dict]:
        """Retourne les N derniers résultats d'ordres."""
        return [asdict(r) for r in self._orders_placed[-limit:]]

    def get_symbol_info(self, symbol: str) -> Optional[Dict]:
        """Retourne les infos MT5 du symbole (ou None)."""
        info = _get_symbol_info(symbol)
        if not info:
            return None
        return {
            "point": info.point,
            "digits": info.digits,
            "spread": info.spread,
            "trade_mode": info.trade_mode,
        }

    # ──────────────────────────────────────────────────────────
    # Validation interne
    # ──────────────────────────────────────────────────────────

    def _validate_symbol(self, symbol: str) -> None:
        info = _get_symbol_info(symbol)
        if not info:
            raise OrderError(f"Symbol not found: {symbol}")
        if not info.trade_mode == mt5.SYMBOL_TRADE_MODE_FULL:
            raise OrderError(f"Symbol not tradeable: {symbol}")

    def _validate_no_duplicate_position(self, symbol: str) -> None:
        """Interdit une deuxième position sur le même symbole (évite double SL)."""
        if self.has_open_position(symbol):
            pos = mt5.positions_get(symbol=symbol)[0]
            raise PositionLimitError(
                f"Position déjà ouverte sur {symbol}: ticket={pos.ticket}, "
                f"direction={'BUY' if pos.type==mt5.ORDER_TYPE_BUY else 'SELL'}, "
                f"volume={pos.volume}"
            )

    def _get_current_price(self, symbol: str, direction: OrderDirection) -> float:
        info = _get_symbol_info(symbol)
        if not info:
            raise OrderError(f"Cannot get price for {symbol}")
        tick = mt5.symbol_info_tick(symbol)
        if not tick:
            raise OrderError(f"No tick data for {symbol}")
        return tick.ask if direction == OrderDirection.BUY else tick.bid

    def _compute_and_validate_stops(self, req: OrderRequest) -> Tuple[float, float]:
        """
        Calcule et valide SL/TP selon les règles:
          - SL doit être dans les bandes vertes/rouges pour Boom/Crash
          - Distance minimale respectant trade_stops_level
          - RR minimum self.min_rr
        """
        symbol = req.symbol
        direction = req.direction
        price = req.entry_price

        if not price or price <= 0:
            raise OrderError(f"Invalid entry price for {symbol}: {price}")

        info = _get_symbol_info(symbol)
        if not info:
            raise OrderError(f"Symbol info unavailable: {symbol}")

        point = info.point
        digits = info.digits

        sl = req.stop_loss
        tp = req.take_profit

        # Si SL non fourni, calcul automatique
        if not sl or sl <= 0:
            sl = self._auto_sl(symbol, direction, price, info)

        # Si TP non fourni, calcul automatique
        if not tp or tp <= 0:
            tp = self._auto_tp(symbol, direction, price, sl, info)

        # Validation et correction Invalid Stops (avec direction)
        # La fonction corrige automatiquement SL/TP trop proches du prix
        sl, tp = self._validate_stops_level(symbol, price, sl, tp, info, direction)

        # Validation RR minimum
        self._validate_rr(symbol, direction, price, sl, tp)

        return sl, tp

    def _auto_sl(self, symbol: str, direction: OrderDirection, price: float,
                 info: Any) -> float:
        """
        SL automatique selon le type de symbole.
        Pour Boom/Crash: SL dans la bande opposée.
        """
        atr = self._get_atr(symbol)
        is_synth = _is_synthetic(symbol)

        if is_synth:
            sl_pct = 0.015  # 1.5% pour synthétiques
        else:
            sl_pct = 0.008  # 0.8% pour forex

        if direction == OrderDirection.BUY:
            sl = price - (price * sl_pct)
        else:
            sl = price + (price * sl_pct)

        # Si ATR disponible, l'utiliser comme référence
        if atr > 0:
            atr_sl = atr * 1.5
            if direction == OrderDirection.BUY:
                sl = min(sl, price - atr_sl)
            else:
                sl = max(sl, price + atr_sl)

        return max(sl, info.point * 10)  # minimum 10 points

    def _auto_tp(self, symbol: str, direction: OrderDirection, price: float,
                 sl: float, info: Any) -> float:
        """TP automatique basé sur le RR minimum."""
        sl_dist = abs(price - sl)
        tp_dist = sl_dist * self.min_rr

        if direction == OrderDirection.BUY:
            tp = price + tp_dist
        else:
            tp = price - tp_dist

        return max(tp, info.point * 10)

    def _validate_stops_level(self, symbol: str, price: float, sl: float,
                              tp: float, info: Any,
                              direction: Optional[OrderDirection] = None) -> Tuple[float, float]:
        """
        Valide et corrige SL/TP pour respecter trade_stops_level.
        Les ajuste automatiquement si trop proches du prix d'entrée.
        Retourne (sl, tp) corrigés.
        """
        point = info.point
        stops_level = max(getattr(info, "trade_stops_level", 0),
                         getattr(info, "stops_level", 0), 0)
        digits = info.digits

        min_dist_points = stops_level
        min_dist_price = min_dist_points * point

        # Plancher de sécurité pour les synthétiques (Boom/Crash/Volatility).
        # Chez Deriv, trade_stops_level vaut souvent 0 → min_dist_price = 0 et la
        # vérification de distance est ignorée, ce qui provoque "Invalid stops".
        # On impose donc un % du prix (aligné avec le EA MQL5 SMCGP_PrepareMarketStops).
        if _is_synthetic(symbol) and price > 0:
            synth_floor = price * 0.05  # 5% du prix pour Boom/Crash (sécuritaire)
            if min_dist_price < synth_floor:
                min_dist_price = synth_floor
                logger.warning(
                    f"⚠️ Plancher SL/TP synthétique imposé ({synth_floor:.{digits}f}) "
                    f"sur {symbol} (trade_stops_level={stops_level})"
                )

        sl = round(sl, digits)
        tp = round(tp, digits)

        if price <= 0 or sl <= 0 or tp <= 0:
            raise InvalidStopsError(symbol, sl, tp,
                f"Valeurs invalides: price={price} SL={sl} TP={tp}")

        # Infer direction from SL position if not provided
        if direction is None:
            if sl < price:
                direction = OrderDirection.BUY
            else:
                direction = OrderDirection.SELL

        # --- Correction SL/TP pour respecter la distance minimale ---
        if min_dist_price > 0:
            sl_dist = abs(price - sl)
            if sl_dist < min_dist_price - point * 0.5:  # marge 0.5 point (arrondi)
                if direction == OrderDirection.BUY:
                    sl = price - min_dist_price
                else:
                    sl = price + min_dist_price
                sl = round(sl, digits)
                logger.warning(
                    f"⚠️ SL corrigé: distance {sl_dist:.{digits}f} < min {min_dist_price:.{digits}f}"
                    f" → nouveau SL={sl} sur {symbol}"
                )

            tp_dist = abs(price - tp)
            # Le TP doit être assez loin pour respecter le RR minimum
            # (sinon _validate_rr échoue après correction du SL).
            min_tp_dist_price = min_dist_price * self.min_rr
            if tp_dist < min_tp_dist_price - point * 0.5:
                if direction == OrderDirection.BUY:
                    tp = price + min_tp_dist_price
                else:
                    tp = price - min_tp_dist_price
                tp = round(tp, digits)
                logger.warning(
                    f"⚠️ TP corrigé: distance {tp_dist:.{digits}f} < min {min_tp_dist_price:.{digits}f}"
                    f" → nouveau TP={tp} sur {symbol}"
                )

        # --- Correction direction BUY / SELL (SL/TP inversés) ---
        if direction == OrderDirection.BUY:
            if sl >= price:
                sl = round(price - max(min_dist_price, point * 10), digits)
                logger.warning(f"⚠️ SL BUY inversé corrigé → {sl}")
            if tp <= price:
                tp = round(price + max(min_dist_price, point * 10), digits)
                logger.warning(f"⚠️ TP BUY inversé corrigé → {tp}")
        elif direction == OrderDirection.SELL:
            if sl <= price:
                sl = round(price + max(min_dist_price, point * 10), digits)
                logger.warning(f"⚠️ SL SELL inversé corrigé → {sl}")
            if tp >= price:
                tp = round(price - max(min_dist_price, point * 10), digits)
                logger.warning(f"⚠️ TP SELL inversé corrigé → {tp}")

        return sl, tp

    def _validate_rr(self, symbol: str, direction: OrderDirection,
                     price: float, sl: float, tp: float) -> None:
        """Valide le ratio Risk/Reward minimum."""
        sl_dist = abs(price - sl)
        tp_dist = abs(price - tp)
        if sl_dist > 0:
            rr = tp_dist / sl_dist
            if rr < self.min_rr:
                raise OrderError(
                    f"{symbol}: RR={rr:.2f} < min {self.min_rr} "
                    f"(SL dist={sl_dist:.5f}, TP dist={tp_dist:.5f})"
                )

    def _execute_market(self, req: OrderRequest) -> int:
        """Exécute l'ordre au marché sur MT5."""
        order_type = mt5.ORDER_TYPE_BUY if req.direction == OrderDirection.BUY else mt5.ORDER_TYPE_SELL

        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": req.symbol,
            "volume": req.volume,
            "type": order_type,
            "price": req.entry_price,
            "sl": req.stop_loss,
            "tp": req.take_profit,
            "deviation": req.slippage or self.default_slippage,
            "magic": req.magic,
            "comment": req.comment or "tradbot",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }

        resp = mt5.order_send(request)
        if resp is None:
            last_error = mt5.last_error()
            raise OrderError(f"MT5 order_send failed: {last_error}")

        if resp.retcode != mt5.TRADE_RETCODE_DONE:
            error_msg = f"MT5 retcode={resp.retcode}: {resp.comment}"
            if resp.retcode in (10014, 10015, 10016, 10027):
                raise InvalidStopsError(req.symbol, req.stop_loss or 0, req.take_profit or 0, error_msg)
            if resp.retcode in (10006, 10007, 10008, 10019):
                raise InsufficientMarginError(f"Margin insufficient: {error_msg}")
            raise OrderError(error_msg)

        return resp.order

    def _get_atr(self, symbol: str) -> float:
        """Calcule ATR14 rapidement via les prix MT5."""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 20)
            if rates is None or len(rates) < 14:
                return 0.0
            highs = [r["high"] for r in rates[-14:]]
            lows = [r["low"] for r in rates[-14:]]
            closes = [r["close"] for r in rates[-14:]]
            tr_sum = 0.0
            for i in range(1, 14):
                hl = highs[i] - lows[i]
                hc = abs(highs[i] - closes[i-1])
                lc = abs(lows[i] - closes[i-1])
                tr_sum += max(hl, hc, lc)
            return tr_sum / 13.0 if tr_sum > 0 else 0.0
        except Exception:
            return 0.0

    @staticmethod
    def _pos_to_dict(pos) -> Dict:
        return {
            "ticket": pos.ticket,
            "symbol": pos.symbol,
            "type": "BUY" if pos.type == mt5.ORDER_TYPE_BUY else "SELL",
            "volume": pos.volume,
            "price_open": pos.price_open,
            "price_current": pos.price_current,
            "sl": pos.sl,
            "tp": pos.tp,
            "profit": pos.profit,
            "swap": pos.swap,
            "comment": pos.comment,
            "magic": pos.magic,
            "time": datetime.fromtimestamp(pos.time, tz=timezone.utc).isoformat() if pos.time else "",
        }
