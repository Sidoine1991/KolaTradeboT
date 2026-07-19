"""
Agent 3 — Dynamic Risk Optimizer
Computes optimal lot size per symbol using Kelly Criterion + ATR-based risk.
Enforces drawdown protection, daily loss limits, and per-symbol exposure caps.
"""

import json
import os
import sqlite3
import requests
from typing import Dict, Any, List, Optional
from .agent_base import AgentBase

AI_SERVER = "http://127.0.0.1:8000"

# Paths to local data
DB_PATHS = [
    "D:/Dev/TradBOT/python/data/trades.db",
    "D:/Dev/TradBOT/data/trades.db",
    "D:/Dev/TradBOT/trades.db",
]

# Conservative risk config — overridable via env
DEFAULT_RISK_CONFIG = {
    "account_balance": float(os.getenv("ACCOUNT_BALANCE", "1000")),
    "max_risk_pct": 0.02,         # 2% per trade
    "max_daily_loss_pct": 0.06,   # 6% max daily drawdown
    "max_open_positions": 5,
    "kelly_fraction": 0.25,        # Quarter-Kelly (conservative)
    "min_lot": 0.01,
    "max_lot": 1.0,
}

# MT5 terminals
MT5_TERMINALS = [
    {"login": 5026526, "server": "Deriv-MT5-Real", "name": "Weltrade"},
    {"login": 5026526, "server": "Deriv-MT5-Real", "name": "Deriv"},
]

def _fetch_mt5_balances() -> dict:
    """Récupère les vrais soldes/equity des 2 terminaux MT5."""
    result = {"balance": 0.0, "equity": 0.0, "margin_free": 0.0, "positions": 0, "daily_pnl": 0.0}
    try:
        import MetaTrader5 as mt5
        if not mt5.initialize():
            return result
        for terminal in MT5_TERMINALS:
            try:
                if mt5.login(terminal["login"], server=terminal["server"]):
                    acc = mt5.account_info()
                    if acc:
                        result["balance"] += acc.balance
                        result["equity"] += acc.equity
                        result["margin_free"] += acc.margin_free
                    positions = mt5.positions_get()
                    if positions:
                        result["positions"] += len(positions)
                        for pos in positions:
                            result["daily_pnl"] += pos.profit
                    # Deals du jour
                    from datetime import datetime, timedelta
                    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                    deals = mt5.history_deals_get(today, datetime.now())
                    if deals:
                        for deal in deals:
                            result["daily_pnl"] += deal.profit + deal.commission + deal.swap
            except Exception as e:
                logger.warning(f"[RiskAgent] MT5 {terminal['name']}: {e}")
        mt5.shutdown()
    except ImportError:
        logger.warning("[RiskAgent] MetaTrader5 module non disponible")
    except Exception as e:
        logger.error(f"[RiskAgent] MT5 error: {e}")
    return result

# ATR multiplier per symbol category (from known volatility profiles)
ATR_PROFILE = {
    "Boom": {"sl_atr": 1.5, "tp_atr": 3.0},
    "Crash": {"sl_atr": 1.5, "tp_atr": 3.0},
    "XAUUSD": {"sl_atr": 2.0, "tp_atr": 3.0},
    "EURUSD": {"sl_atr": 1.8, "tp_atr": 2.7},
    "BTCUSD": {"sl_atr": 2.5, "tp_atr": 4.0},
    "default": {"sl_atr": 2.0, "tp_atr": 3.0},
}


class RiskOptimizerAgent(AgentBase):
    agent_id = "risk"
    agent_name = "Dynamic Risk Optimizer"
    description = "Kelly Criterion lot sizing, drawdown protection, daily loss limits, per-symbol exposure."
    version = "1.0.0"
    interval_seconds = 60

    def __init__(self):
        super().__init__()
        self._db_path = self._find_db()
        self._config = DEFAULT_RISK_CONFIG.copy()
        self._daily_pnl: float = 0.0
        self._open_positions: int = 0

    def analyze(self) -> Dict[str, Any]:
        self._refresh_account_state()
        stats = self._load_symbol_stats()

        # --- Peer intelligence: Pattern + Regime + TradingAgents ---
        pattern_out = self.get_peer("pattern")
        regime_out  = self.get_peer("regime")
        ta_out      = self.get_peer("trading_agents")

        evolved_thresholds = pattern_out.get("evolved_thresholds", {})
        symbol_regimes     = regime_out.get("symbol_regimes", {})
        global_regime_info = regime_out.get("global_regime", {})
        global_regime      = global_regime_info.get("regime", "UNKNOWN")

        # Agent 7: TradingAgents WR override for the deep-analysed symbol
        ta_symbol  = ta_out.get("symbol", "")
        ta_wr_pct  = float(ta_out.get("ta_win_rate_override", 0.0))  # 0 = no override

        # VOLATILE/RANGING global regime → reduce max_open_positions by 1
        regime_pos_cap = self._config["max_open_positions"]
        if global_regime in ("VOLATILE", "RANGING"):
            regime_pos_cap = max(1, regime_pos_cap - 1)

        recommendations: Dict[str, Dict] = {}
        for sym, stat in stats.items():
            # If pattern agent has evolved thresholds with expected WR, use them
            evolved = evolved_thresholds.get(sym, {})
            if evolved.get("expected_wr"):
                stat["win_rate"] = max(stat["win_rate"], evolved["expected_wr"] / 100.0)

            # Agent 7 WR boost: when TradingAgents ran a full deep analysis
            if sym == ta_symbol and ta_wr_pct > 0:
                ta_wr_frac = ta_wr_pct / 100.0
                if ta_wr_frac > stat["win_rate"]:
                    stat["win_rate"] = round(ta_wr_frac, 3)
                    stat["wr_source"] = "TA7_override"

            # Per-symbol regime: VOLATILE → cap lot at half
            sym_regime = symbol_regimes.get(sym, {}).get("regime", global_regime)
            rec = self._compute_recommendation(sym, stat)

            if sym_regime == "VOLATILE":
                rec["recommended_lot"] = round(rec["recommended_lot"] * 0.5, 2)
                rec["lot_adjusted_by"] = "regime=VOLATILE"
            elif sym_regime == "RANGING":
                rec["recommended_lot"] = round(rec["recommended_lot"] * 0.7, 2)
                rec["lot_adjusted_by"] = "regime=RANGING"

            recommendations[sym] = rec

        daily_budget = self._daily_budget()
        risk_level = self._assess_risk_level()
        mt5_data = _fetch_mt5_balances()

        return {
            "recommendations": recommendations,
            "daily_pnl": round(self._daily_pnl, 2),
            "daily_budget_remaining": round(daily_budget, 2),
            "open_positions": self._open_positions,
            "risk_level": risk_level,
            "config": self._config,
            "can_trade": daily_budget > 0 and self._open_positions < regime_pos_cap,
            "mt5_accounts": {
                "balance": round(mt5_data["balance"], 2),
                "equity": round(mt5_data["equity"], 2),
                "margin_free": round(mt5_data["margin_free"], 2),
                "positions": mt5_data["positions"],
            },
            "peer_context": {
                "global_regime": global_regime,
                "regime_pos_cap": regime_pos_cap,
                "evolved_symbols": list(evolved_thresholds.keys()),
                "ta7_wr_override": f"{ta_symbol}={ta_wr_pct:.0f}%" if ta_wr_pct > 0 else "none",
            },
        }

    # ------------------------------------------------------------------
    # Core calculations
    # ------------------------------------------------------------------

    def _compute_recommendation(self, symbol: str, stat: Dict) -> Dict:
        win_rate = stat.get("win_rate", 0.5)
        avg_win = stat.get("avg_win", 10.0)
        avg_loss = stat.get("avg_loss", 5.0)
        atr = stat.get("atr", 1.0)
        balance = self._config["account_balance"]

        # Kelly fraction = W/L - (1-W)/R  where R = avg_win/avg_loss
        ratio = avg_win / max(avg_loss, 0.01)
        kelly = (win_rate * ratio - (1 - win_rate)) / max(ratio, 0.01)
        kelly = max(0.0, kelly) * self._config["kelly_fraction"]  # fractional Kelly

        # Risk $ per trade
        risk_usd = balance * self._config["max_risk_pct"]
        daily_remaining = self._daily_budget()
        risk_usd = min(risk_usd, daily_remaining * 0.5)  # never more than half the remaining budget

        # SL distance in price units
        profile = self._get_atr_profile(symbol)
        sl_dist = atr * profile["sl_atr"]

        # Lot = risk_usd / (sl_distance * pip_value)
        pip_value = self._pip_value(symbol)
        lot = risk_usd / max(sl_dist * pip_value, 0.01)
        lot = lot * (kelly if kelly > 0 else 0.5)

        # Clamp to safe range
        min_lot = self._config["min_lot"]
        max_lot = min(self._config["max_lot"], balance * 0.002)  # at most 0.2% balance per 0.01 lot
        lot = round(max(min_lot, min(max_lot, lot)), 2)

        return {
            "symbol": symbol,
            "recommended_lot": lot,
            "kelly_pct": round(kelly * 100, 1),
            "win_rate": round(win_rate * 100, 1),
            "risk_usd": round(risk_usd, 2),
            "sl_distance": round(sl_dist, 5),
            "tp_distance": round(atr * profile["tp_atr"], 5),
            "rr_ratio": round(profile["tp_atr"] / profile["sl_atr"], 2),
            "trades_sampled": stat.get("total_trades", 0),
        }

    def _kelly_criterion(self, win_rate: float, avg_win: float, avg_loss: float) -> float:
        if avg_loss == 0:
            return 0.0
        b = avg_win / avg_loss
        return max(0.0, (b * win_rate - (1 - win_rate)) / b)

    # ------------------------------------------------------------------
    # Data loading
    # ------------------------------------------------------------------

    def _load_symbol_stats(self) -> Dict[str, Dict]:
        stats: Dict[str, Dict] = {}
        if not self._db_path:
            return self._default_stats()
        try:
            conn = sqlite3.connect(self._db_path, timeout=3)
            cur = conn.cursor()
            cur.execute("""
                SELECT symbol,
                       COUNT(*) as total,
                       AVG(CASE WHEN profit > 0 THEN 1.0 ELSE 0.0 END) as wr,
                       AVG(CASE WHEN profit > 0 THEN profit ELSE NULL END) as avg_win,
                       ABS(AVG(CASE WHEN profit < 0 THEN profit ELSE NULL END)) as avg_loss
                FROM trades
                WHERE date(close_time) >= date('now', '-30 days')
                GROUP BY symbol
                HAVING total >= 5
            """)
            for row in cur.fetchall():
                sym, total, wr, avg_win, avg_loss = row
                stats[sym] = {
                    "total_trades": total,
                    "win_rate": float(wr or 0.5),
                    "avg_win": float(avg_win or 10.0),
                    "avg_loss": float(avg_loss or 5.0),
                    "atr": 1.0,
                }
            conn.close()
        except Exception as e:
            self.logger.warning("DB read error: %s", e)
        return stats or self._default_stats()

    def _default_stats(self) -> Dict[str, Dict]:
        defaults = {}
        for cat in ["Boom500Index", "Crash500Index", "XAUUSD", "EURUSD"]:
            defaults[cat] = {"win_rate": 0.52, "avg_win": 10.0, "avg_loss": 7.0, "atr": 1.0, "total_trades": 0}
        return defaults

    def _refresh_account_state(self):
        # Priorité: données MT5 réelles
        mt5_data = _fetch_mt5_balances()
        if mt5_data["balance"] > 0:
            self._config["account_balance"] = mt5_data["balance"]
            self._open_positions = mt5_data["positions"]
            self._daily_pnl = mt5_data["daily_pnl"]
            return
        # Fallback: AI server
        try:
            r = requests.get(f"{AI_SERVER}/market-state", timeout=3)
            if r.status_code == 200:
                data = r.json()
                self._open_positions = int(data.get("open_positions", 0))
                self._daily_pnl = float(data.get("daily_pnl", 0.0))
        except Exception:
            pass

    def _daily_budget(self) -> float:
        max_loss = self._config["account_balance"] * self._config["max_daily_loss_pct"]
        return max(0.0, max_loss + self._daily_pnl)

    def _assess_risk_level(self) -> str:
        budget = self._daily_budget()
        max_loss = self._config["account_balance"] * self._config["max_daily_loss_pct"]
        usage = 1 - (budget / max(max_loss, 0.01))
        if usage < 0.3:
            return "NORMAL"
        if usage < 0.6:
            return "CAUTION"
        if usage < 0.85:
            return "HIGH"
        return "CRITICAL"

    def _get_atr_profile(self, symbol: str) -> Dict:
        for key in ATR_PROFILE:
            if key in symbol:
                return ATR_PROFILE[key]
        return ATR_PROFILE["default"]

    def _pip_value(self, symbol: str) -> float:
        if "XAU" in symbol:
            return 10.0
        if "JPY" in symbol:
            return 0.01
        if "BTC" in symbol or "ETH" in symbol:
            return 1.0
        if "Boom" in symbol or "Crash" in symbol:
            return 0.1
        return 1.0

    def _find_db(self) -> Optional[str]:
        for p in DB_PATHS:
            if os.path.exists(p):
                return p
        return None
