"""
Genere des donnees M1 synthetiques plausibles pour Boom1000 et Crash1000,
juste pour valider que le pipeline (modules 1-2-3) tourne de bout en bout
AVANT de brancher le vrai historique MT5/Deriv.

A NE PAS utiliser pour un entrainement final : remplace ensuite --input
par ton vrai export M1 (MT5 -> CSV, ou ton flux Kaggle habituel).
"""
import numpy as np
import pandas as pd

np.random.seed(42)


def generate_synthetic(symbol: str, n_candles: int = 200_000, spike_direction: str = "up") -> pd.DataFrame:
    dt = pd.date_range("2025-01-01", periods=n_candles, freq="1min")

    # bruit de base tres faible (caracteristique des synthetics = pas de gaps macro)
    base_vol = 0.5
    returns = np.random.normal(0, base_vol, n_candles)

    # injection de spikes rares et violents dans le sens caracteristique de l'indice
    spike_prob = 0.008  # ~0.8% des bougies = spike, plausible pour Boom/Crash 1000
    spike_mask = np.random.rand(n_candles) < spike_prob
    spike_sign = 1 if spike_direction == "up" else -1

    spike_amplitude = np.random.gamma(shape=3.0, scale=15.0, size=n_candles)  # queue lourde = gros spikes rares
    returns[spike_mask] += spike_sign * spike_amplitude[spike_mask]

    # rares contre-spikes (retracement violent) pour rendre les chaines non triviales
    counter_mask = np.random.rand(n_candles) < spike_prob * 0.25
    returns[counter_mask] -= spike_sign * spike_amplitude[counter_mask] * 0.6

    close = 10000 + np.cumsum(returns)
    open_ = np.roll(close, 1)
    open_[0] = close[0]

    high = np.maximum(open_, close) + np.abs(np.random.normal(0, base_vol * 0.5, n_candles))
    low = np.minimum(open_, close) - np.abs(np.random.normal(0, base_vol * 0.5, n_candles))
    volume = np.random.randint(50, 500, n_candles)

    df = pd.DataFrame({
        "time": dt, "open": open_, "high": high, "low": low, "close": close, "volume": volume,
    })
    return df


if __name__ == "__main__":
    boom = generate_synthetic("BOOM1000", spike_direction="up")
    crash = generate_synthetic("CRASH1000", spike_direction="down")
    boom.to_csv("boom1000_M1_synthetic.csv", index=False)
    crash.to_csv("crash1000_M1_synthetic.csv", index=False)
    print("[OK] boom1000_M1_synthetic.csv et crash1000_M1_synthetic.csv generes")
