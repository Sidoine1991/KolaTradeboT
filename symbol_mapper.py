"""
Symbol Mapping & Normalization Module

Gère la conversion entre symboles TradingView et MT5.
Évite les mismatches de symboles qui causaient des trades sur le mauvais instrument.
"""

import re
from typing import Dict, Optional

# Mappings canoniques: MT5 symbol → TradingView / API canonical form
SYMBOL_MAPPINGS: Dict[str, Dict[str, str]] = {
    # Boom/Crash Deriv — MT5 names avec espaces
    "Boom 300 Index": {
        "mt5": "Boom 300 Index",
        "tradingview": "Boom 300 Index",
        "api": "Boom300Index",
        "url": "Boom%20300%20Index",
        "category": "boom_crash",
    },
    "Boom 500 Index": {
        "mt5": "Boom 500 Index",
        "tradingview": "Boom 500 Index",
        "api": "Boom500Index",
        "url": "Boom%20500%20Index",
        "category": "boom_crash",
    },
    "Boom 600 Index": {
        "mt5": "Boom 600 Index",
        "tradingview": "Boom 600 Index",
        "api": "Boom600Index",
        "url": "Boom%20600%20Index",
        "category": "boom_crash",
    },
    "Boom 900 Index": {
        "mt5": "Boom 900 Index",
        "tradingview": "Boom 900 Index",
        "api": "Boom900Index",
        "url": "Boom%20900%20Index",
        "category": "boom_crash",
    },
    "Boom 1000 Index": {
        "mt5": "Boom 1000 Index",
        "tradingview": "Boom 1000 Index",
        "api": "Boom1000Index",
        "url": "Boom%20 1000%20Index",
        "category": "boom_crash",
    },
    "Crash 300 Index": {
        "mt5": "Crash 300 Index",
        "tradingview": "Crash 300 Index",
        "api": "Crash300Index",
        "url": "Crash%20300%20Index",
        "category": "boom_crash",
    },
    "Crash 500 Index": {
        "mt5": "Crash 500 Index",
        "tradingview": "Crash 500 Index",
        "api": "Crash500Index",
        "url": "Crash%20500%20Index",
        "category": "boom_crash",
    },
    "Crash 600 Index": {
        "mt5": "Crash 600 Index",
        "tradingview": "Crash 600 Index",
        "api": "Crash600Index",
        "url": "Crash%20600%20Index",
        "category": "boom_crash",
    },
    "Crash 900 Index": {
        "mt5": "Crash 900 Index",
        "tradingview": "Crash 900 Index",
        "api": "Crash900Index",
        "url": "Crash%20900%20Index",
        "category": "boom_crash",
    },
    "Crash 1000 Index": {
        "mt5": "Crash 1000 Index",
        "tradingview": "Crash 1000 Index",
        "api": "Crash1000Index",
        "url": "Crash%201000%20Index",
        "category": "boom_crash",
    },
    # Weltrade equivalents (PAINX = Boom, GAINX = Crash)
    "PAINX": {
        "mt5": "PAINX",
        "tradingview": "PAINX",
        "api": "PAINX",
        "url": "PAINX",
        "category": "boom_crash",
        "equivalent": "Boom (Weltrade)",
        "direction": "buy_only",
    },
    "GAINX": {
        "mt5": "GAINX",
        "tradingview": "GAINX",
        "api": "GAINX",
        "url": "GAINX",
        "category": "boom_crash",
        "equivalent": "Crash (Weltrade)",
        "direction": "sell_only",
    },
    # Deriv Volatility equivalents (FXVOL, SFVVOL)
    "FXVOL": {
        "mt5": "FXVOL",
        "tradingview": "FXVOL",
        "api": "FXVOL",
        "url": "FXVOL",
        "category": "volatility",
        "equivalent": "Volatility (Deriv FX)",
    },
    "SFVVOL": {
        "mt5": "SFVVOL",
        "tradingview": "SFVVOL",
        "api": "SFVVOL",
        "url": "SFVVOL",
        "category": "volatility",
        "equivalent": "Volatility (Deriv Stocks)",
    },
    "SFXVOL": {
        "mt5": "SFXVOL",
        "tradingview": "SFXVOL",
        "api": "SFXVOL",
        "url": "SFXVOL",
        "category": "volatility",
        "equivalent": "Volatility (Weltrade SFX)",
    },
    # Forex & métaux
    "XAUUSD": {
        "mt5": "XAUUSD",
        "tradingview": "XAUUSD",
        "api": "XAUUSD",
        "url": "XAUUSD",
        "category": "forex_metal",
    },
    "EURUSD": {
        "mt5": "EURUSD",
        "tradingview": "EURUSD",
        "api": "EURUSD",
        "url": "EURUSD",
        "category": "forex",
    },
}

# Ticker TradingView CDP (chart set-symbol) — DERIV:BOOM_500_INDEX vs MT5 "Boom 500 Index"
_TV_CDP_TICKERS: Dict[str, str] = {
    "XAUUSD": "OANDA:XAUUSD",
    "XAGUSD": "OANDA:XAGUSD",
    "EURUSD": "OANDA:EURUSD",
    "GBPUSD": "OANDA:GBPUSD",
    "USDJPY": "OANDA:USDJPY",
    "USDCHF": "OANDA:USDCHF",
    "AUDUSD": "OANDA:AUDUSD",
    "NZDUSD": "OANDA:NZDUSD",
    "USDCAD": "OANDA:USDCAD",
    "BTCUSD": "BITSTAMP:BTCUSD",
    "ETHUSD": "BITSTAMP:ETHUSD",
    "Boom 300 Index": "DERIV:BOOM_300_INDEX",
    "Boom 500 Index": "DERIV:BOOM_500_INDEX",
    "Boom 600 Index": "DERIV:BOOM_600_INDEX",
    "Boom 900 Index": "DERIV:BOOM_900_INDEX",
    "Boom 1000 Index": "DERIV:BOOM_1000_INDEX",
    "Crash 300 Index": "DERIV:CRASH_300_INDEX",
    "Crash 500 Index": "DERIV:CRASH_500_INDEX",
    "Crash 600 Index": "DERIV:CRASH_600_INDEX",
    "Crash 900 Index": "DERIV:CRASH_900_INDEX",
    "Crash 1000 Index": "DERIV:CRASH_1000_INDEX",
}

_TV_TO_MT5: Dict[str, str] = {v: k for k, v in _TV_CDP_TICKERS.items()}


def get_symbol_mapping(mt5_symbol: str) -> Optional[Dict[str, str]]:
    """
    Récupère le mapping complet pour un symbole MT5.

    Args:
        mt5_symbol: Symbole MT5 (ex: "Boom 500 Index", "XAUUSD")

    Returns:
        Dict avec clés: mt5, tradingview, api, url, category
        Ou None si symbole non trouvé

    Example:
        >>> get_symbol_mapping("Boom 500 Index")
        {'mt5': 'Boom 500 Index', 'api': 'Boom500Index', 'url': 'Boom%20500%20Index', ...}
    """
    return SYMBOL_MAPPINGS.get(mt5_symbol)


def normalize_for_url(symbol: str) -> str:
    """
    Normalise symbole pour URL (espaces → %20).

    Args:
        symbol: Symbole brut de MT5

    Returns:
        Symbole URL-encodé

    Example:
        >>> normalize_for_url("Boom 500 Index")
        "Boom%20500%20Index"
    """
    mapping = get_symbol_mapping(symbol)
    if mapping:
        return mapping["url"]
    # Fallback: encode manuellement
    return symbol.replace(" ", "%20")


def normalize_for_api(symbol: str) -> str:
    """
    Normalise symbole pour API (enlève espaces).

    Args:
        symbol: Symbole brut de MT5

    Returns:
        Symbole sans espaces

    Example:
        >>> normalize_for_api("Boom 500 Index")
        "Boom500Index"
    """
    mapping = get_symbol_mapping(symbol)
    if mapping:
        return mapping["api"]
    # Fallback: enlève espaces
    return symbol.replace(" ", "")


def is_weltrade_symbol(symbol: str) -> bool:
    """Symbole Weltrade (PainX/GainX/FX Vol…) — nécessite terminal MT5 Weltrade."""
    if not symbol:
        return False
    s = symbol.upper().replace(" ", "")
    if "PAINX" in s or "GAINX" in s:
        return True
    if re.search(r"(FX|SFV|SFX)?VOL", symbol, re.I):
        return True
    return s in ("PAINX", "GAINX", "FXVOL", "SFVVOL", "SFXVOL")


def is_boom_crash(symbol: str) -> bool:
    """Vérifie si c'est un symbole Boom/Crash (y compris équivalents Weltrade/Deriv)"""
    s = symbol.upper().replace(" ", "")
    return (
        "Boom" in symbol or "Crash" in symbol
        or "PAINX" in s or "GAINX" in s
    )


def is_boom(symbol: str) -> bool:
    """Vérifie si c'est un Boom (BUY seulement) - inclut PainX"""
    s = symbol.upper().replace(" ", "")
    return "Boom" in symbol or "PAINX" in s


def is_crash(symbol: str) -> bool:
    """Vérifie si c'est un Crash (SELL seulement) - inclut GainX"""
    s = symbol.upper().replace(" ", "")
    return "Crash" in symbol or "GAINX" in s


def is_volatility(symbol: str) -> bool:
    """Vérifie si c'est un symbole Volatility (FX Vol, SFVVOL, etc)"""
    s = symbol.upper().replace(" ", "")
    return (
        "Volatility" in symbol
        or s in ("FXVOL", "SFVVOL", "SFXVOL")
        or bool(re.search(r"(FX|SFV|SFX)?VOL\d+", s))
    )


def get_symbol_category(symbol: str) -> Optional[str]:
    """Récupère la catégorie du symbole (boom_crash, forex, metal, etc)"""
    mapping = get_symbol_mapping(symbol)
    return mapping["category"] if mapping else None


def get_all_boom_crash_symbols() -> list[str]:
    """Retourne liste de tous symboles Boom/Crash"""
    return [sym for sym, map_data in SYMBOL_MAPPINGS.items()
            if map_data["category"] == "boom_crash"]


def get_equivalent_symbol(symbol: str, target_broker: str = "deriv") -> str:
    """
    Convertit un symbole vers son équivalent sur une autre broker.

    Args:
        symbol: Symbole source (ex: "Boom 500 Index", "PAINX", "FXVOL")
        target_broker: Broker cible ("deriv", "weltrade", "xt", etc)

    Returns:
        Symbole équivalent sur la broker cible

    Examples:
        >>> get_equivalent_symbol("Boom 500 Index", "weltrade")
        "PAINX"
        >>> get_equivalent_symbol("PAINX", "deriv")
        "Boom 500 Index"
        >>> get_equivalent_symbol("Volatility 75 Index", "deriv")
        "FXVOL"
    """
    s = symbol.upper()

    # Déterminer la catégorie
    if is_boom(symbol):
        if target_broker.lower() == "weltrade":
            return "PAINX"
        elif target_broker.lower() == "deriv":
            # Chercher Boom équivalent
            for num in [300, 500, 600, 900, 1000]:
                if str(num) in symbol:
                    return f"Boom {num} Index"
            return "Boom 500 Index"

    elif is_crash(symbol):
        if target_broker.lower() == "weltrade":
            return "GAINX"
        elif target_broker.lower() == "deriv":
            # Chercher Crash équivalent
            for num in [300, 500, 600, 900, 1000]:
                if str(num) in symbol:
                    return f"Crash {num} Index"
            return "Crash 500 Index"

    elif is_volatility(symbol):
        if target_broker.lower() == "weltrade":
            return "FXVOL"  # ou "SFVVOL" selon le type
        elif target_broker.lower() == "deriv":
            return "Volatility 75 Index"

    # Pas de conversion nécessaire
    return symbol


def get_broker_from_symbol(symbol: str) -> str:
    """Détecte la broker à partir du symbole"""
    if is_weltrade_symbol(symbol):
        return "weltrade"
    if any(x in symbol for x in ["Boom", "Crash", "Volatility"]) and "Index" in symbol:
        return "deriv"
    s = symbol.upper()
    if s in ("XAUUSD", "EURUSD", "GBPUSD"):
        return "forex"
    return "unknown"


def _format_weltrade_painx(num: str) -> str:
    return f"PainX {num}" if num else "PainX"


def _format_weltrade_gainx(num: str) -> str:
    return f"GainX {num}" if num else "GainX"


def _format_weltrade_fxvol(num: str, prefix: str = "FX") -> str:
    return f"{prefix} Vol {num}" if num else f"{prefix} Vol"


def _register_weltrade_variants() -> None:
    """Enregistre les variantes Weltrade réelles (PainX 600, GainX 1200, FX Vol 20…)."""
    for num in ("400", "600", "800", "1200"):
        painx = _format_weltrade_painx(num)
        if painx not in SYMBOL_MAPPINGS:
            SYMBOL_MAPPINGS[painx] = {
                "mt5": painx,
                "tradingview": painx,
                "api": painx.replace(" ", ""),
                "url": painx.replace(" ", "%20"),
                "category": "boom_crash",
                "equivalent": "Boom (Weltrade)",
                "direction": "buy_only",
                "broker": "weltrade",
            }
        gainx = _format_weltrade_gainx(num)
        if gainx not in SYMBOL_MAPPINGS:
            SYMBOL_MAPPINGS[gainx] = {
                "mt5": gainx,
                "tradingview": gainx,
                "api": gainx.replace(" ", ""),
                "url": gainx.replace(" ", "%20"),
                "category": "boom_crash",
                "equivalent": "Crash (Weltrade)",
                "direction": "sell_only",
                "broker": "weltrade",
            }
    for num in ("20", "40", "60", "75"):
        for label, prefix in (("FX Vol", "FX"), ("SFV Vol", "SFV")):
            vol = f"{label} {num}"
            if vol not in SYMBOL_MAPPINGS:
                SYMBOL_MAPPINGS[vol] = {
                    "mt5": vol,
                    "tradingview": vol,
                    "api": vol.replace(" ", ""),
                    "url": vol.replace(" ", "%20"),
                    "category": "volatility",
                    "equivalent": "Volatility (Weltrade)",
                    "broker": "weltrade",
                }


_register_weltrade_variants()


def resolve_mt5_symbol(raw: str) -> str:
    """
    Résout toute variante MT5/TV vers le nom canonique MT5.
    Ex: Boom500Index, Boom 500Index, BOOM_500_INDEX, DERIV:BOOM_500_INDEX -> Boom 500 Index
    """
    if not raw:
        return "XAUUSD"
    s = raw.strip()
    if s.upper() in ("XAUEUR", "GOLD", "OR"):
        return "XAUUSD"

    mapping = get_symbol_mapping(s)
    if mapping:
        return mapping["mt5"]

    if s in _TV_TO_MT5:
        return _TV_TO_MT5[s]

    up = s.upper().replace("DERIV:", "").strip()
    if up in _TV_TO_MT5:
        return _TV_TO_MT5[up]

    compact = re.sub(r"[^A-Z0-9]", "", up)
    for canon, data in SYMBOL_MAPPINGS.items():
        api_key = re.sub(r"[^A-Z0-9]", "", data.get("api", "").upper())
        canon_key = re.sub(r"[^A-Z0-9]", "", canon.upper())
        if compact and compact in (api_key, canon_key):
            return canon

    m = re.match(r"^(BOOM|CRASH)[_]?(\d+)[_]?(INDEX)?$", compact)
    if m:
        kind = m.group(1).title()
        num = m.group(2)
        candidate = f"{kind} {num} Index"
        if get_symbol_mapping(candidate):
            return candidate

    m2 = re.match(r"^(BOOM|CRASH)(\d+)$", compact)
    if m2:
        candidate = f"{m2.group(1).title()} {m2.group(2)} Index"
        if get_symbol_mapping(candidate):
            return candidate

    # Weltrade PainX / GainX (PainX 600, PAINX600, PainX600)
    m_pain = re.match(r"^PAINX(\d+)?$", compact)
    if m_pain:
        return _format_weltrade_painx(m_pain.group(1) or "")

    m_gain = re.match(r"^GAINX(\d+)?$", compact)
    if m_gain:
        return _format_weltrade_gainx(m_gain.group(1) or "")

    # Weltrade FX Vol / SFV Vol (FX Vol 20, FXVOL20)
    m_fx = re.match(r"^(FX|SFV|SFX)?VOL(\d+)?$", compact)
    if m_fx:
        prefix_raw = (m_fx.group(1) or "FX").upper()
        prefix = "SFV" if prefix_raw in ("SFV", "SFX") else "FX"
        return _format_weltrade_fxvol(m_fx.group(2) or "20", prefix)

    return s


def mt5_to_tv_cdp_ticker(mt5_symbol: str) -> str:
    """Symbole MT5 -> ticker TradingView CDP (ex. DERIV:BOOM_500_INDEX)."""
    canon = resolve_mt5_symbol(mt5_symbol)
    return _TV_CDP_TICKERS.get(canon, canon)


def normalize_report_symbol(symbol: str, default: str = "Unknown") -> str:
    """
    Normalise symbole pour rapports.

    Utilisé par les rapports WhatsApp/email pour afficher le bon symbole,
    pas "XAUUSD" hardcoded.

    Args:
        symbol: Symbole brut de MT5
        default: Symbole par défaut si non trouvé

    Returns:
        Symbole formaté pour rapports

    Example:
        >>> normalize_report_symbol("Boom 500 Index")
        "Boom 500 Index"
        >>> normalize_report_symbol("Unknown")
        "Unknown"
    """
    mapping = get_symbol_mapping(symbol)
    if mapping:
        return mapping["mt5"]
    return default if symbol != "XAUUSD" else "XAUUSD"


# Test & validation
if __name__ == "__main__":
    print("Testing symbol_mapper.py...")

    # Test 1: Mapping lookup
    boom500 = get_symbol_mapping("Boom 500 Index")
    assert boom500 is not None
    assert boom500["api"] == "Boom500Index"
    print("[PASS] Test 1: Mapping lookup works")

    # Test 2: URL normalization
    assert normalize_for_url("Boom 500 Index") == "Boom%20500%20Index"
    print("[PASS] Test 2: URL normalization works")

    # Test 3: API normalization
    assert normalize_for_api("Boom 500 Index") == "Boom500Index"
    print("[PASS] Test 3: API normalization works")

    # Test 4: Category detection
    assert is_boom("Boom 500 Index") is True
    assert is_crash("Crash 300 Index") is True
    assert is_boom("XAUUSD") is False
    print("[PASS] Test 4: Boom/Crash detection works")

    # Test 5: Report symbol (NOT hardcoded to XAUUSD)
    assert normalize_report_symbol("Boom 500 Index") == "Boom 500 Index"
    assert normalize_report_symbol("XAUUSD") == "XAUUSD"
    print("[PASS] Test 5: Report symbol normalization works")

    # Test 6: Get all Boom/Crash
    boom_crash_list = get_all_boom_crash_symbols()
    assert "Boom 500 Index" in boom_crash_list
    assert "XAUUSD" not in boom_crash_list
    print("[PASS] Test 6: Found " + str(len(boom_crash_list)) + " Boom/Crash symbols")

    print("\n[PASS] All symbol_mapper tests passed!")
