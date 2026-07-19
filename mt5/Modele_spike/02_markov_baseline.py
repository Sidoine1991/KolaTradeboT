"""
============================================================
MODULE 2 - MATRICE DE MARKOV (baseline) SUR LES CHAINES DE SPIKES
============================================================
A partir de la liste chronologique des spikes (sortie du module 1),
on construit :
  1) Une matrice de transition simple direction -> direction
     (up->up, up->down, down->up, down->down)
  2) Une matrice de transition "binned" par amplitude, pour capter
     des regularites du type "un gros spike haussier est plus souvent
     suivi d'un petit spike baissier de retracement" etc.

Cette matrice sert de PRIOR (probabilite de base) que le module 3
(LightGBM) vient ensuite corriger avec le contexte complet.

Usage:
    python 02_markov_baseline.py --input spikes_boom1000.csv --output markov_boom1000.json
"""

import argparse
import json

import numpy as np
import pandas as pd


def build_simple_transition_matrix(spikes: pd.DataFrame) -> dict:
    """Matrice de transition direction -> direction (ordre 1)."""
    directions = spikes["spike_direction"].tolist()
    pairs = list(zip(directions[:-1], directions[1:]))

    counts = {"up": {"up": 0, "down": 0}, "down": {"up": 0, "down": 0}}
    for a, b in pairs:
        counts[a][b] += 1

    matrix = {}
    for state, transitions in counts.items():
        total = sum(transitions.values())
        if total == 0:
            matrix[state] = {"up": 0.5, "down": 0.5}
        else:
            matrix[state] = {k: v / total for k, v in transitions.items()}
    return matrix


def build_amplitude_binned_matrix(spikes: pd.DataFrame, n_bins: int = 3) -> dict:
    """
    Matrice de transition conditionnee par l'amplitude (en multiples d'ATR)
    du spike courant, binnee en tertiles (petit/moyen/gros).
    """
    s = spikes.copy()
    s["amp_bin"] = pd.qcut(s["amplitude_atr"], q=n_bins, labels=["small", "medium", "large"], duplicates="drop")

    s["state"] = s["spike_direction"] + "_" + s["amp_bin"].astype(str)
    states = s["state"].tolist()
    next_dir = s["spike_direction"].shift(-1).tolist()

    matrix = {}
    for state in set(states[:-1]):
        idx = [i for i, st in enumerate(states[:-1]) if st == state]
        nxt = [next_dir[i] for i in idx]
        total = len(nxt)
        if total == 0:
            continue
        up_p = nxt.count("up") / total
        down_p = nxt.count("down") / total
        matrix[state] = {"up": up_p, "down": down_p, "n_obs": total}

    # bornes des bins pour pouvoir reappliquer la meme discretisation en inference
    bin_edges = pd.qcut(s["amplitude_atr"], q=n_bins, duplicates="drop").cat.categories
    edges = [float(interval.left) for interval in bin_edges] + [float(bin_edges[-1].right)]

    return {"matrix": matrix, "bin_edges": edges}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--n_bins", type=int, default=3)
    args = parser.parse_args()

    spikes = pd.read_csv(args.input)
    if len(spikes) < 30:
        print(f"[ATTENTION] Seulement {len(spikes)} spikes - la matrice de Markov sera peu fiable. "
              f"Vise au moins quelques centaines d'evenements pour un prior stable.")

    simple = build_simple_transition_matrix(spikes)
    binned = build_amplitude_binned_matrix(spikes, n_bins=args.n_bins)

    output = {
        "symbol": spikes["symbol"].iloc[0] if "symbol" in spikes.columns and len(spikes) else "unknown",
        "n_spikes": len(spikes),
        "simple_transition": simple,
        "amplitude_binned_transition": binned,
    }

    with open(args.output, "w") as f:
        json.dump(output, f, indent=2)

    print(f"[OK] Matrice de Markov sauvegardee -> {args.output}")
    print("Transition simple:", json.dumps(simple, indent=2))


if __name__ == "__main__":
    main()
