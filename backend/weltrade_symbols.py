"""
Détection des symboles Weltrade / MT5 : suffixes broker (.pro, .ecn, …)
et indices propriétaires (PAINX, GAIN, etc.) pour routage ML.
"""
from __future__ import annotations

from typing import Tuple

# Symboles MT5 typiques PainX / GainX (espaces comme dans le Market Watch).
# Surcharge possible : variable d'environnement AI_WELTRADE_STARTUP_SYMBOLS (liste séparée par des virgules).
WELTRADE_STARTUP_TRAIN_SYMBOLS: Tuple[str, ...] = (
    "PainX 300",
    "GainX 300",
    "PainX 600",
    "GainX 600",
    "PainX 800",
    "GainX 800",
    "PainX 999",
    "GainX 999",
    "PainX 1200",
    "GainX 1200",
)

# Suffixes fréquents Weltrade / ECN (minuscules, comparaison en endswith)
WELTRADE_BROKER_SUFFIXES: Tuple[str, ...] = (
    ".pro",
    ".ecn",
    ".wt",
    ".weltrade",
    ".fix",
    ".m",
    ".i",
    ".raw",
    ".std",
    ".cent",
)


def normalize_broker_symbol(symbol: str) -> str:
    """Retire un suffixe broker du nom affiché MT5 (ex. EURUSD.pro → EURUSD)."""
    s = (symbol or "").strip()
    if not s:
        return ""
    lower = s.lower()
    for suf in WELTRADE_BROKER_SUFFIXES:
        if lower.endswith(suf):
            return s[: -len(suf)].upper().strip()
    return s.upper().strip()


def is_weltrade_synth_index(symbol: str) -> bool:
    """
    Indices / paires synthétiques type Weltrade (hors FX majeur classique).
    PAINX, GAIN*, variantes INX — à garder restrictif pour éviter les faux positifs.
    """
    u = normalize_broker_symbol(symbol)
    if not u:
        return False
    if "PAINX" in u:
        return True
    if "GAINX" in u:
        return True
    if "PAIN" in u and "INX" in u:
        return True
    if "GAININDEX" in u.replace(" ", "") or "GAIN INDEX" in u:
        return True
    # Symbole court broker type « GAIN » ou « GAIN.pro » → normalisé « GAIN »
    if u == "GAIN" or (u.startswith("GAIN") and len(u) <= 8 and not any(
        c in u for c in ("USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD")
    )):
        return True
    return False


def is_weltrade_pain_synth(symbol: str) -> bool:
    """PainX / Pain INX : pas de BUY (équivalent logique « anti-BUY sur Crash »)."""
    u = normalize_broker_symbol(symbol).replace(" ", "")
    if not u:
        return False
    if "PAINX" in u:
        return True
    if "PAIN" in u and "INX" in u:
        return True
    return False


def is_weltrade_gain_synth(symbol: str) -> bool:
    """GainX / GAIN court broker : pas de SELL (équivalent « anti-SELL sur Boom »)."""
    if is_weltrade_pain_synth(symbol):
        return False
    u = normalize_broker_symbol(symbol).replace(" ", "")
    if not u:
        return False
    if "GAINX" in u:
        return True
    if "GAININDEX" in u or "GAIN INDEX" in (symbol or "").upper():
        return True
    nu = normalize_broker_symbol(symbol).upper().strip()
    if nu == "GAIN" or (nu.startswith("GAIN") and len(nu) <= 8 and not any(
        c in nu for c in ("USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD")
    )):
        return True
    return False
