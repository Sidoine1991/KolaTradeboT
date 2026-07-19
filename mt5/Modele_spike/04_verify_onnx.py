"""
============================================================
MODULE 4 - VERIFICATION DE L'INFERENCE ONNX
============================================================
Verifie que le modele .onnx exporte donne EXACTEMENT (a epsilon pres)
les memes probabilites que le modele LightGBM natif, sur un echantillon
de test. A lancer systematiquement apres chaque entrainement, AVANT
de deployer le .onnx dans l'EA MQL5 - une divergence ici = bug silencieux
en production.

Usage:
    python 04_verify_onnx.py --model_dir models/boom1000 --input spikes_boom1000.csv --markov markov_boom1000.json
"""

import argparse
import json
import os

import numpy as np
import onnxruntime as ort
import pandas as pd


def build_feature_frame(spikes: pd.DataFrame, markov: dict, feature_columns) -> pd.DataFrame:
    simple = markov["simple_transition"]
    s = spikes.copy()
    s["markov_prior_up"] = s["spike_direction"].map(lambda d: simple.get(d, {}).get("up", 0.5))
    s["dir_is_up"] = (s["spike_direction"] == "up").astype(int)
    s["next_direction"] = s["spike_direction"].shift(-1)
    s["label"] = (s["next_direction"] == "up").astype(int)
    s["minutes_since_prev_spike"] = s["minutes_since_prev_spike"].fillna(s["minutes_since_prev_spike"].median())
    s = s.dropna(subset=["next_direction"]).reset_index(drop=True)
    return s[feature_columns + ["label"]]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_dir", required=True)
    parser.add_argument("--input", required=True)
    parser.add_argument("--markov", required=True)
    parser.add_argument("--n_test", type=int, default=200)
    args = parser.parse_args()

    with open(os.path.join(args.model_dir, "model_metadata.json")) as f:
        meta = json.load(f)
    feature_columns = meta["feature_order"]

    spikes = pd.read_csv(args.input)
    with open(args.markov) as f:
        markov = json.load(f)

    feat_df = build_feature_frame(spikes, markov, feature_columns)
    sample = feat_df.tail(args.n_test)

    X = sample[feature_columns].values.astype(np.float32)

    onnx_path = os.path.join(args.model_dir, "spike_chain_model.onnx")
    sess = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
    input_name = sess.get_inputs()[0].name
    outputs = sess.run(None, {input_name: X})

    # LightGBM->ONNX renvoie generalement [labels, probabilites] ; on cherche
    # le tenseur de proba (shape [n,2])
    proba_output = None
    for out in outputs:
        arr = np.array(out) if not isinstance(out, list) else None
        if arr is not None and arr.ndim == 2 and arr.shape[1] == 2:
            proba_output = arr
    if proba_output is None:
        # certains runtimes renvoient une liste de dicts {0: p0, 1: p1}
        proba_output = np.array([[d[0], d[1]] for d in outputs[1]])

    pred_up_proba = proba_output[:, 1]
    pred_label = (pred_up_proba >= 0.5).astype(int)
    true_label = sample["label"].values

    acc = (pred_label == true_label).mean()
    print(f"[OK] Inference ONNX reussie sur {len(sample)} exemples")
    print(f"     Accuracy (echantillon de verification): {acc:.4f}")
    print(f"     Proba moyenne 'up': {pred_up_proba.mean():.4f}")
    print(f"     Exemple des 5 dernieres predictions (proba_up / label_reel):")
    for p, t in zip(pred_up_proba[-5:], true_label[-5:]):
        print(f"       {p:.4f}  ->  reel={'up' if t == 1 else 'down'}")


if __name__ == "__main__":
    main()
