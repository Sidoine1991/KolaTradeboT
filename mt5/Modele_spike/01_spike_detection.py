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
    "BOOM1000":  {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "BOOM500":   {"direction": "up",   "atr_period": 14, "spike_atr_mult": 3.0},
    "CRASH1000": {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
    "CRASH500":  {"direction": "down", "atr_period": 14, "spike_atr_mult": 3.0},
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

    direction: "up"   -> on cherche les spikes haussiers (typique Boom)
               "down" -> on cherche les spikes baissiers (typique Crash)
    """
    df = df.copy()
    df["atr"] = compute_atr(df, atr_period)
    df["body"] = df["close"] - df["open"]
    df["range"] = df["high"] - df["low"]

    threshold = spike_atr_mult * df["atr"]

    if direction == "up":
        is_spike = (df["body"] > 0) & (df["body"] > threshold)
        df["spike_direction"] = np.where(is_spike, "up", None)
    else:
        is_spike = (df["body"] < 0) & (df["body"].abs() > threshold)
        df["spike_direction"] = np.where(is_spike, "down", None)

    # On garde egalement les contre-spikes (rares mais existent) pour
    # avoir un vrai historique bidirectionnel haussier/baissier
    opposite_is_spike = None
    if direction == "up":
        opposite_is_spike = (df["body"] < 0) & (df["body"].abs() > threshold)
        df.loc[opposite_is_spike, "spike_direction"] = "down"
    else:
        opposite_is_spike = (df["body"] > 0) & (df["body"] > threshold)
        df.loc[opposite_is_spike, "spike_direction"] = "up"

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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="CSV M1 avec colonnes time,open,high,low,close,volume")
    parser.add_argument("--symbol", required=True, choices=list(DEFAULT_PARAMS.keys()))
    parser.add_argument("--output", required=True, help="CSV de sortie: liste des evenements spike")
    parser.add_argument("--spike_atr_mult", type=float, default=None, help="Override du multiplicateur ATR")
    args = parser.parse_args()

    df = pd.read_csv(args.input)
    df.columns = [c.lower().strip() for c in df.columns]
    required = {"time", "open", "high", "low", "close"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes dans {args.input}: {missing}")

    params = DEFAULT_PARAMS[args.symbol].copy()
    if args.spike_atr_mult is not None:
        params["spike_atr_mult"] = args.spike_atr_mult

    df_marked = detect_spikes(df, params["direction"], params["atr_period"], params["spike_atr_mult"])
    spikes = extract_spike_events(df_marked, args.symbol)

    spikes.to_csv(args.output, index=False)
    print(f"[OK] {len(spikes)} spikes detectes sur {args.symbol} -> {args.output}")
    print(spikes["spike_direction"].value_counts())


if __name__ == "__main__":
    main()
