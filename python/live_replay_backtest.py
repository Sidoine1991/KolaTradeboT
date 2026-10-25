#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Replay live des dernières heures : GOM réel + gate LIVE vs ancien gate.

Utilise les bougies du terminal MT5 déjà ouvert (pas le Strategy Tester).
"""
from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "python"))
sys.path.insert(0, str(ROOT))

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

os.environ.setdefault("MT5_INIT_TIMEOUT_SEC", "8")
os.environ.setdefault("MT5_CALL_TIMEOUT_SEC", "8")

import pandas as pd

SYMBOLS = [
    "PainX 800",
    "PainX 1200",
    "GainX 1200",
    "GainX 999",
    "PainX 400",
    "SFX Vol 20",
]
HOURS = 6
STEP_M5 = 1  # une évaluation GOM par bougie M5 (pas chaque M1)
LOT = 0.1
SL_USD = 1.0
TP_USD = 2.0
HOLD_BARS = 12
LIVE_AGAINST_ATR = 0.12
LIVE_CHASE_ATR = 2.20
LIVE_CHASE_ATR_SNIPER = 1.00
LIVE_IMPULSE_MAX_BARS = 3
LIVE_PULLBACK_ATR = 0.45


def _attach_mt5():
    import MetaTrader5 as mt5

    paths = [
        r"D:\Program Files\MetaTrader 5 - Copie\terminal64.exe",
        r"C:\Program Files\MetaTrader 5 - Copie\terminal64.exe",
        r"D:\Program Files\MetaTrader 5\terminal64.exe",
        r"C:\Program Files\MetaTrader 5\terminal64.exe",
        r"D:\Program Files\MetaTrader 5 - Copie (2)\terminal64.exe",
    ]
    last_err = None
    fallback = None
    for path in [p for p in paths if Path(p).is_file()]:
        try:
            mt5.shutdown()
        except Exception:
            pass
        time.sleep(0.4)
        t0 = time.time()
        try:
            ok = bool(mt5.initialize(path=path, portable=False))
        except Exception as exc:
            last_err = f"{path}: {exc}"
            print(f"[MT5] exception {path}: {exc}", flush=True)
            continue
        dt = time.time() - t0
        if not ok:
            last_err = mt5.last_error()
            print(f"[MT5] fail {dt:.1f}s path={path} err={last_err}", flush=True)
            continue
        ai = mt5.account_info()
        ti = mt5.terminal_info()
        login = getattr(ai, "login", None)
        server = getattr(ai, "server", None)
        has_painx = (
            mt5.symbol_info("PainX 1200") is not None
            or mt5.symbol_info("PainX 800") is not None
        )
        print(
            f"[MT5] {dt:.1f}s path={path} login={login} server={server} "
            f"PainX={'YES' if has_painx else 'NO'}",
            flush=True,
        )
        if not has_painx:
            last_err = f"pas de PainX sur {path} ({server})"
            continue
        if login == 34525102:
            return mt5, ai, ti
        fallback = (mt5, ai, ti)
        last_err = f"PainX ok mais compte {login} (voulu 34525102)"
    if fallback is not None:
        print(f"[MT5] fallback compte {getattr(fallback[1], 'login', None)}", flush=True)
        return fallback
    raise SystemExit(f"Aucun terminal Weltrade avec PainX: {last_err}")


def _rates_df(mt5, symbol: str, tf, bars: int) -> Optional[pd.DataFrame]:
    info = mt5.symbol_info(symbol)
    if info is None:
        return None
    if not info.visible:
        mt5.symbol_select(symbol, True)
    rates = mt5.copy_rates_from_pos(symbol, tf, 0, bars)
    if rates is None or len(rates) == 0:
        return None
    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")
    df.set_index("time", inplace=True)
    if "volume" not in df.columns:
        df["volume"] = df["tick_volume"] if "tick_volume" in df.columns else 1.0
    return df


def _slice_until(df: pd.DataFrame, ts) -> pd.DataFrame:
    return df.loc[df.index <= ts]


def _dir_txt(d: int) -> str:
    return "BULL" if d == 1 else ("BEAR" if d == -1 else "NEUT")


def _mtf_dir(calc, df: pd.DataFrame) -> Tuple[int, int]:
    if df is None or len(df) < 30:
        return 0, 50
    return calc.mtf_direction(df)


def _atr(series_high, series_low, series_close, n=14) -> float:
    prev = series_close.shift(1)
    tr = pd.concat(
        [
            (series_high - series_low),
            (series_high - prev).abs(),
            (series_low - prev).abs(),
        ],
        axis=1,
    ).max(axis=1)
    v = float(tr.ewm(alpha=1 / n, adjust=False).mean().iloc[-1])
    return v if v > 0 else float(series_high.iloc[-1] - series_low.iloc[-1]) or 1.0


def _sym_u(symbol: str) -> str:
    return (symbol or "").upper()


def _is_crash(symbol: str) -> bool:
    s = _sym_u(symbol)
    return "CRASH" in s or "PAINX" in s


def _is_boom(symbol: str) -> bool:
    s = _sym_u(symbol)
    return "BOOM" in s or "GAINX" in s


def _chase_atr(symbol: str) -> float:
    s = _sym_u(symbol)
    if "999" in s or ("400" in s and ("PAINX" in s or "GAINX" in s)):
        return LIVE_CHASE_ATR_SNIPER
    return LIVE_CHASE_ATR


def live_gate_ok(
    m1: pd.DataFrame, m5: pd.DataFrame, dir_sign: int, symbol: str = ""
) -> Tuple[bool, str]:
    """Replay : la dernière barre du slice est déjà close (pas de bougie 0 en formation)."""
    if dir_sign == 0 or m1 is None or len(m1) < 6:
        return False, "no_m1"
    if _is_crash(symbol) and dir_sign > 0:
        return False, "native_crash_no_buy"
    if _is_boom(symbol) and dir_sign < 0:
        return False, "native_boom_no_sell"
    atr = _atr(m1["high"], m1["low"], m1["close"])
    c = m1["close"].astype(float)
    o = m1["open"].astype(float)
    h = m1["high"].astype(float)
    l = m1["low"].astype(float)
    d1 = float(c.iloc[-1] - c.iloc[-2])
    d3 = float(c.iloc[-1] - c.iloc[-4])
    against = atr * LIVE_AGAINST_ATR
    if dir_sign > 0 and d1 < -against and d3 < -against:
        return False, "m1_1b3b_dump"
    if dir_sign < 0 and d1 > against and d3 > against:
        return False, "m1_1b3b_rally"
    body_min = 0.22 if ("VOL" in _sym_u(symbol) or "SFX" in _sym_u(symbol)) else 0.30
    rng = float(h.iloc[-1] - l.iloc[-1])
    body = abs(float(c.iloc[-1] - o.iloc[-1]))
    if rng <= 0 or body < rng * body_min:
        return False, "m1_doji"
    if dir_sign > 0 and not (c.iloc[-1] > o.iloc[-1]):
        return False, "m1_not_buy"
    if dir_sign < 0 and not (c.iloc[-1] < o.iloc[-1]):
        return False, "m1_not_sell"
    is_1200 = "1200" in _sym_u(symbol)
    is_vol = "VOL" in _sym_u(symbol) or "SFX" in _sym_u(symbol)
    need_m5 = is_vol or not is_1200
    if need_m5 and m5 is not None and len(m5) >= 2:
        m5c, m5o = float(m5["close"].iloc[-1]), float(m5["open"].iloc[-1])
        m5h, m5l = float(m5["high"].iloc[-1]), float(m5["low"].iloc[-1])
        m5rng = m5h - m5l
        m5body = abs(m5c - m5o)
        if m5rng <= 0 or m5body < m5rng * 0.28:
            return False, "m5_doji"
        if dir_sign > 0 and not (m5c > m5o):
            return False, "m5_not_buy"
        if dir_sign < 0 and not (m5c < m5o):
            return False, "m5_not_sell"
    impulse = abs(d3)
    impulse_bars = 0
    for i in range(1, min(6, len(c))):
        oi = float(o.iloc[-i])
        ci = float(c.iloc[-i])
        with_dir = (dir_sign > 0 and ci > oi) or (dir_sign < 0 and ci < oi)
        if not with_dir:
            break
        impulse_bars += 1
    px = float(c.iloc[-1])
    swing = float(l.iloc[-10:].min()) if dir_sign > 0 else float(h.iloc[-10:].max())
    near_pb = abs(px - swing) <= atr * LIVE_PULLBACK_ATR
    chase = _chase_atr(symbol)
    if impulse >= atr * chase and impulse_bars > LIVE_IMPULSE_MAX_BARS and not near_pb:
        return False, "chase"
    return True, "ok"


def simulate_trade(m1: pd.DataFrame, i: int, dir_sign: int, sl_dist: float, tp_dist: float) -> Dict[str, Any]:
    entry = float(m1["open"].iloc[i + 1]) if i + 1 < len(m1) else float(m1["close"].iloc[i])
    sl = entry - sl_dist if dir_sign > 0 else entry + sl_dist
    tp = entry + tp_dist if dir_sign > 0 else entry - tp_dist
    end = min(len(m1) - 1, i + 1 + HOLD_BARS)
    for j in range(i + 1, end + 1):
        hi = float(m1["high"].iloc[j])
        lo = float(m1["low"].iloc[j])
        if dir_sign > 0:
            if lo <= sl:
                return {"exit": sl, "bars": j - i, "reason": "SL"}
            if hi >= tp:
                return {"exit": tp, "bars": j - i, "reason": "TP"}
        else:
            if hi >= sl:
                return {"exit": sl, "bars": j - i, "reason": "SL"}
            if lo <= tp:
                return {"exit": tp, "bars": j - i, "reason": "TP"}
    last = float(m1["close"].iloc[end])
    return {"exit": last, "bars": end - i, "reason": "TIME"}


def pnl_usd(dir_sign: int, entry: float, exit_px: float, usd_per_point: float) -> float:
    move = (exit_px - entry) if dir_sign > 0 else (entry - exit_px)
    return round(move * usd_per_point, 2)


def usd_per_point(mt5, symbol: str, lot: float) -> float:
    info = mt5.symbol_info(symbol)
    if info is None:
        return 0.01
    tv = float(info.trade_tick_value or 0)
    ts = float(info.trade_tick_size or 0)
    if tv > 0 and ts > 0:
        # tick_value is usually for 1.0 lot
        return (tv / ts) * lot
    pt = float(info.point or 1)
    return (tv / pt) * lot if tv > 0 else 0.01


def replay_symbol(mt5, calc, pine, symbol: str) -> Dict[str, Any]:
    from gom_pine_calculator import enrich_m1_metrics, apply_m1_execution_gate, apply_price_reality_gate

    print(f"\n=== fetch {symbol} ...", flush=True)
    m1 = _rates_df(mt5, symbol, mt5.TIMEFRAME_M1, HOURS * 60 + 240)
    m5 = _rates_df(mt5, symbol, mt5.TIMEFRAME_M5, HOURS * 12 + 80)
    m15 = _rates_df(mt5, symbol, mt5.TIMEFRAME_M15, 200)
    h1 = _rates_df(mt5, symbol, mt5.TIMEFRAME_H1, 120)
    if m1 is None or m5 is None or len(m1) < 80 or len(m5) < 40:
        print(f"  SKIP no data m1={None if m1 is None else len(m1)} m5={None if m5 is None else len(m5)}", flush=True)
        return {"symbol": symbol, "error": "no M1/M5 data", "old": {"n": 0, "pnl": 0}, "new": {"n": 0, "pnl": 0}}

    upp = usd_per_point(mt5, symbol, LOT)
    start_ts = m5.index[-min(len(m5) - 25, HOURS * 12)]
    old_trades: List[Dict[str, Any]] = []
    new_trades: List[Dict[str, Any]] = []
    last_old_i = last_new_i = -99
    rejects: Dict[str, int] = {}

    print(f"=== {symbol} | M1={len(m1)} M5={len(m5)} {start_ts} -> {m5.index[-1]} | $/pt={upp:.4f}", flush=True)

    m1_times = m1.index
    for k, ts in enumerate(m5.index):
        if ts < start_ts or k < 25:
            continue
        s5 = m5.iloc[max(0, k - 119) : k + 1]
        s1 = m1.loc[m1_times <= ts].tail(120)
        if len(s1) < 40 or len(s5) < 30:
            continue
        s15 = m15.loc[m15.index <= ts].tail(80) if m15 is not None else s5
        sh1 = h1.loc[h1.index <= ts].tail(80) if h1 is not None else s5

        rec = calc.analyze_chart(s5, symbol)
        rec["symbol"] = symbol
        d_m1, r_m1 = _mtf_dir(calc, s1)
        d_m5, r_m5 = _mtf_dir(calc, s5)
        d_m15, _ = _mtf_dir(calc, s15)
        d_h1, _ = _mtf_dir(calc, sh1)
        rec["tf_m1_dir"] = _dir_txt(d_m1)
        rec["tf_m5_dir"] = _dir_txt(d_m5)
        rec["tf_m15_dir"] = _dir_txt(d_m15)
        rec["tf_h1_dir"] = _dir_txt(d_h1)
        rec["tf_h4_dir"] = rec["tf_h1_dir"]
        rec["tf_d1_dir"] = rec["tf_h1_dir"]
        rec["tf_m1_rsi"] = r_m1
        rec["tf_m5_rsi"] = r_m5
        enrich_m1_metrics(
            rec,
            s1["close"].astype(float).tolist(),
            s1["open"].astype(float).tolist(),
            s1["high"].astype(float).tolist(),
            s1["low"].astype(float).tolist(),
        )
        rec = pine.enrich_record(rec)
        vn = int(rec.get("verdict_num", 0) or 0)
        vn = apply_m1_execution_gate(rec, vn)
        if vn != 0:
            vn, _ = apply_price_reality_gate(rec, vn)
        if abs(vn) < 2:
            continue

        # index M1 de cette clôture M5
        loc = m1_times.get_indexer([ts], method="pad")[0]
        if loc < 0 or loc >= len(m1) - 2:
            continue
        dir_sign = 1 if vn > 0 else -1
        atr = _atr(s1["high"], s1["low"], s1["close"])
        sl_dist = SL_USD / max(upp, 1e-9)
        tp_dist = TP_USD / max(upp, 1e-9)

        if loc - last_old_i >= 8:
            entry = float(m1["open"].iloc[loc + 1])
            sim = simulate_trade(m1, loc, dir_sign, sl_dist, tp_dist)
            p = pnl_usd(dir_sign, entry, sim["exit"], upp)
            old_trades.append({
                "t": str(ts), "vn": vn, "dir": "BUY" if dir_sign > 0 else "SELL",
                "pnl": p, "reason": sim["reason"], "bars": sim["bars"],
            })
            last_old_i = loc

        ok, why = live_gate_ok(s1, s5, dir_sign, symbol)
        if not ok:
            rejects[why] = rejects.get(why, 0) + 1
        if ok and loc - last_new_i >= 8:
            entry = float(m1["open"].iloc[loc + 1])
            sim = simulate_trade(m1, loc, dir_sign, sl_dist, tp_dist)
            p = pnl_usd(dir_sign, entry, sim["exit"], upp)
            new_trades.append({
                "t": str(ts), "vn": vn, "dir": "BUY" if dir_sign > 0 else "SELL",
                "pnl": p, "reason": sim["reason"], "bars": sim["bars"], "gate": why,
            })
            last_new_i = loc

    def _stats(trades: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not trades:
            return {"n": 0, "wins": 0, "losses": 0, "pnl": 0.0, "wr": 0.0, "pf": 0.0}
        wins = [t for t in trades if t["pnl"] > 0]
        losses = [t for t in trades if t["pnl"] <= 0]
        gp = sum(t["pnl"] for t in wins)
        gl = abs(sum(t["pnl"] for t in losses))
        return {
            "n": len(trades),
            "wins": len(wins),
            "losses": len(losses),
            "pnl": round(sum(t["pnl"] for t in trades), 2),
            "wr": round(100.0 * len(wins) / len(trades), 1),
            "pf": round(gp / gl, 2) if gl > 0 else (99.0 if gp > 0 else 0.0),
        }

    out = {
        "symbol": symbol,
        "old": _stats(old_trades),
        "new": _stats(new_trades),
        "old_trades": old_trades[-12:],
        "new_trades": new_trades[-12:],
    }
    print(f"  OLD GOM-only {out['old']}", flush=True)
    print(f"  NEW live-gate {out['new']}  rejects={rejects}", flush=True)
    return out


def main():
    from gom_live_calculator import GOMSignalsLiveCalculator
    from gom_pine_calculator import GOMLPineCalculator

    mt5, ai, ti = _attach_mt5()
    calc = GOMSignalsLiveCalculator()
    pine = GOMLPineCalculator()
    results = []
    for sym in SYMBOLS:
        try:
            results.append(replay_symbol(mt5, calc, pine, sym))
        except Exception as exc:
            print(f"[ERR] {sym}: {exc}")
            results.append({"symbol": sym, "error": str(exc)})

    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "account": getattr(ai, "login", None),
        "server": getattr(ai, "server", None),
        "hours": HOURS,
        "symbols": results,
    }
    outp = ROOT / "backtest_results" / f"live_replay_{datetime.now().strftime('%Y%m%d_%H%M')}.json"
    outp.parent.mkdir(parents=True, exist_ok=True)
    outp.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    print("\n===== SYNTHÈSE =====")
    old_pnl = new_pnl = 0.0
    for r in results:
        if r.get("error") and not isinstance(r.get("old"), dict):
            print(f"{r['symbol']}: ERROR {r['error']}")
            continue
        o, n = r.get("old") or {}, r.get("new") or {}
        if "n" not in o:
            print(f"{r['symbol']}: ERROR {r.get('error', 'no data')}")
            continue
        old_pnl += o.get("pnl", 0)
        new_pnl += n.get("pnl", 0)
        print(
            f"{r['symbol']:14}  OLD n={o['n']:3} wr={o['wr']:5}% pnl={o['pnl']:7}  "
            f"NEW n={n['n']:3} wr={n['wr']:5}% pnl={n['pnl']:7}"
        )
    print(f"{'TOTAL':14}  OLD pnl={old_pnl:7.2f}   NEW pnl={new_pnl:7.2f}")
    print(f"Rapport: {outp}")
    try:
        mt5.shutdown()
    except Exception:
        pass


if __name__ == "__main__":
    main()
