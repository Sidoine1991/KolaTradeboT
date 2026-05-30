"""
Symbol Mapping & Normalization Module

Gère la conversion entre symboles TradingView et MT5.
Évite les mismatches de symboles qui causaient des trades sur le mauvais instrument.
"""

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


def is_boom_crash(symbol: str) -> bool:
    """Vérifie si c'est un symbole Boom/Crash"""
    return "Boom" in symbol or "Crash" in symbol


def is_boom(symbol: str) -> bool:
    """Vérifie si c'est un Boom (BUY seulement)"""
    return "Boom" in symbol


def is_crash(symbol: str) -> bool:
    """Vérifie si c'est un Crash (SELL seulement)"""
    return "Crash" in symbol


def get_symbol_category(symbol: str) -> Optional[str]:
    """Récupère la catégorie du symbole (boom_crash, forex, metal, etc)"""
    mapping = get_symbol_mapping(symbol)
    return mapping["category"] if mapping else None


def get_all_boom_crash_symbols() -> list[str]:
    """Retourne liste de tous symboles Boom/Crash"""
    return [sym for sym, map_data in SYMBOL_MAPPINGS.items()
            if map_data["category"] == "boom_crash"]


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
