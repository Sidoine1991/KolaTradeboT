#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Liste canonique des symboles GOM — Deriv, Weltrade, Forex, Metal, Crypto, Indices."""

from typing import List, Tuple

ALL_ACTIVE_SYMBOLS: Tuple[str, ...] = (
    # Boom/Crash Deriv
    "Boom 50 Index", "Boom 150 Index", "Boom 200 Index",
    "Boom 300 Index", "Boom 500 Index", "Boom 600 Index",
    "Boom 900 Index", "Boom 1000 Index",
    "Crash 50 Index", "Crash 150 Index", "Crash 200 Index",
    "Crash 300 Index", "Crash 500 Index", "Crash 600 Index",
    "Crash 900 Index", "Crash 1000 Index",
    # Boom/Crash Weltrade
    "PainX 600", "PainX 1200",
    "GainX 400", "GainX 600", "GainX 800", "GainX 1200",
    # Volatility Deriv
    "Step Index",
    "Volatility 5 (1s) Index", "Volatility 10 (1s) Index",
    "Volatility 25 (1s) Index", "Volatility 30 (1s) Index",
    "Volatility 50 (1s) Index", "Volatility 75 (1s) Index",
    "Volatility 100 (1s) Index", "Volatility 150 (1s) Index",
    "Volatility 250 (1s) Index",
    "Volatility 10 Index", "Volatility 25 Index",
    "Volatility 50 Index", "Volatility 75 Index",
    "Volatility 100 Index", "Volatility 150 Index",
    "Volatility 250 Index",
    # Volatility Weltrade
    "FX Vol 20", "SFV Vol", "SFX Vol",
    # Forex
    "EURUSD", "GBPUSD", "USDJPY", "USDCAD", "AUDUSD", "USDCHF", "NZDUSD",
    "EURGBP", "EURJPY", "GBPJPY", "EURAUD", "GBPAUD", "AUDJPY",
    "EURNOK", "USDZAR",
    # Métaux
    "XAUUSD", "XAUEUR", "XAGUSD",
    # Indices
    "US30_x10",
    # Crypto
    "BTCUSD", "ETHUSD",
)


def all_gom_symbols(extra: List[str] | None = None) -> List[str]:
    """Liste dédupliquée pour poller / recalcul."""
    seen: set = set()
    out: List[str] = []
    for s in list(ALL_ACTIVE_SYMBOLS) + list(extra or []):
        key = str(s).strip().upper()
        if key and key not in seen:
            seen.add(key)
            out.append(str(s).strip())
    return out
