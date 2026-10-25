"""
============================================================
MODULE 1 - DETECTION DES SPIKES (Boom & Crash M1)
============================================================
Objectif : identifier chaque spike (mouvement brutal caracteristique
des indices synthetiques Boom/Crash), le caracteriser (direction,
amplitude, vitesse), et reconstruire la sequence chronologique
des spikes = la "chaine de spikes".

Entree attendue (CSV) avec au minimum les colonnes :
    time, open, high, low, close, volume  (optionnel: tick_volume, spread)

Sur Boom (spikes haussiers ponctuels dans tendance baissiere globale)
et Crash (spikes baissiers ponctuels dans tendance haussiere globale),
un "spike" est une bougie (ou courte sequence de bougies) dont le
mouvement depasse un seuil dynamique base sur l'ATR / volatilite locale,
dans le sens caracteristique de l'indice.

Usage:
    python 01_spike_detection.py --input boom1000_M1.csv --symbol BOOM1000 --output spikes_boom1000.csv
"""

import argparse
import numpy as np
import pandas as pd


# ------------------------------------------------------------------
# Parametres par defaut (a ajuster selon l'indice - Boom1000 != Boom500)
# ------------------------------------------------------------------
DEFAULT_PARAMS = {
    # Boom/Crash (Deriv) — spikes up/down respectively
    "BOOM1000":  {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "BOOM500":   {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "CRASH1000": {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "CRASH500":  {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    # PainX (spikes down) / GainX (spikes up) — Weltrade
    "PainX_400":  {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "GainX_400":  {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "PainX_600":  {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "GainX_600":  {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "PainX_800":  {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "GainX_800":  {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "PainX_999":  {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "GainX_999":  {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "PainX_1200": {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "GainX_1200": {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    # Volatility indices — mean-reverting, spikes in both directions
    "FX_Vol_20":  {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.0},
    "FX_Vol_40":  {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.0},
    "FX_Vol_60":  {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.0},
    "FX_Vol_80":  {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.0},
    "FX_Vol_99":  {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.0},
    "SFX_Vol_20": {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.5},
    "SFX_Vol_40": {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.5},
    "SFX_Vol_60": {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.5},
    "SFX_Vol_80": {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.5},
    "SFX_Vol_99": {"direction": "both", "atr_period": 14, "spike_atr_mult": 2.5},
}


def compute_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    high, low, close = df["high"], df["low"], df["close"]
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs(),
    ], axis=1).max(axis=1)
    return tr.rolling(period, min_periods=period).mean()


def detect_spikes(df: pd.DataFrame, direction: str, atr_period: int, spike_atr_mult: float) -> pd.DataFrame:
    """
    Marque chaque bougie comme spike si son range (ou son deplacement close-open)
    depasse spike_atr_mult * ATR, dans le sens attendu pour l'indice.

    direction: "up"   -> on cherche les spikes haussiers (typique Boom/GainX)
               "down" -> on cherche les spikes baissiers (typique Crash/PainX)
               "both" -> on cherche les deux directions (Volatility indices)
    """
    df = df.copy()
    df["atr"] = compute_atr(df, atr_period)
    df["body"] = df["close"] - df["open"]
    df["range"] = df["high"] - df["low"]

    threshold = spike_atr_mult * df["atr"]
    df["spike_direction"] = None

    if direction == "up":
        up_spike = (df["body"] > 0) & (df["body"] > threshold)
        down_spike = (df["body"] < 0) & (df["body"].abs() > threshold)
        df.loc[up_spike, "spike_direction"] = "up"
        df.loc[down_spike, "spike_direction"] = "down"
    elif direction == "down":
        down_spike = (df["body"] < 0) & (df["body"].abs() > threshold)
        up_spike = (df["body"] > 0) & (df["body"] > threshold)
        df.loc[down_spike, "spike_direction"] = "down"
        df.loc[up_spike, "spike_direction"] = "up"
    else:
        up_spike = (df["body"] > 0) & (df["body"] > threshold)
        down_spike = (df["body"] < 0) & (df["body"].abs() > threshold)
        df.loc[up_spike, "spike_direction"] = "up"
        df.loc[down_spike, "spike_direction"] = "down"

    df["is_spike"] = df["spike_direction"].notna()
    return df


def extract_spike_events(df: pd.DataFrame, symbol: str) -> pd.DataFrame:
    """
    Reduit le dataframe complet a la seule liste des evenements spike,
    avec les features necessaires a l'etage 2 (Markov + LightGBM).
    """
    spikes = df[df["is_spike"]].copy()
    spikes["amplitude_pips"] = spikes["body"].abs()
    spikes["amplitude_atr"] = spikes["body"].abs() / spikes["atr"]
    spikes["time"] = pd.to_datetime(spikes["time"])

    # temps ecoule depuis le spike precedent (en minutes, car M1)
    spikes["minutes_since_prev_spike"] = spikes["time"].diff().dt.total_seconds() / 60.0

    # vitesse de formation approximee : amplitude / duree de la bougie (ici fixe = 1 min sur M1,
    # mais si plusieurs bougies constituent le spike, on capte la range/atr comme proxy de velocite)
    spikes["velocity_proxy"] = spikes["range"] / spikes["atr"]

    # heure de la journee (utile : les spikes ne sont pas uniformement distribues sur 24h)
    spikes["hour"] = spikes["time"].dt.hour
    spikes["minute"] = spikes["time"].dt.minute

    spikes["symbol"] = symbol

    cols = [
        "time", "symbol", "spike_direction", "amplitude_pips", "amplitude_atr",
        "velocity_proxy", "minutes_since_prev_spike", "hour", "minute",
        "close", "atr",
    ]
    return spikes[cols].reset_index(drop=True)


def _param_key(symbol: str) -> str:
    return symbol.replace(" ", "_")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="CSV M1 avec colonnes time,open,high,low,close,volume")
    parser.add_argument("--symbol", required=True, help="Nom du symbole (ex: PainX 999)")
    parser.add_argument("--output", required=True, help="CSV de sortie: liste des evenements spike")
    parser.add_argument("--spike_atr_mult", type=float, default=None, help="Override du multiplicateur ATR")
    args = parser.parse_args()

    df = pd.read_csv(args.input)
    df.columns = [c.lower().strip() for c in df.columns]
    required = {"time", "open", "high", "low", "close"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes dans {args.input}: {missing}")

    key = _param_key(args.symbol)
    if key not in DEFAULT_PARAMS:
        print(f"[WARN] Symbole '{args.symbol}' non dans DEFAULT_PARAMS, utilisation defauts direction=both")
        params = {"direction": "both", "atr_period": 14, "spike_atr_mult": 3.5}
    else:
        params = DEFAULT_PARAMS[key].copy()
    if args.spike_atr_mult is not None:
        params["spike_atr_mult"] = args.spike_atr_mult

    df_marked = detect_spikes(df, params["direction"], params["atr_period"], params["spike_atr_mult"])
    spikes = extract_spike_events(df_marked, args.symbol)

    spikes.to_csv(args.output, index=False)
    print(f"[OK] {len(spikes)} spikes detectes sur {args.symbol} -> {args.output}")
    print(spikes["spike_direction"].value_counts())


if __name__ == "__main__":
    main()
