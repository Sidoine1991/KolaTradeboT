"""
============================================================
MODULE 3 - MODELE CORRECTIF (LightGBM) + EXPORT ONNX
============================================================
Le Markov (module 2) donne un prior simple. Ici on entraine un
classifieur gradient boosting qui predit la direction du PROCHAIN
spike (up/down) a partir du contexte complet :

    - direction du spike courant
    - amplitude (pips + multiples ATR)
    - velocite proxy
    - temps ecoule depuis le spike precedent
    - heure / minute (saisonnalite intra-journaliere)
    - probabilite Markov "prior" comme feature supplementaire
      (le modele apprend a corriger ou faire confiance au prior)
    - (optionnel) regime latent RAE si disponible en colonne 'rae_regime'

Sortie: modele .onnx pret a etre charge dans MT5 (OnnxCreate),
+ un fichier de metadonnees JSON (ordre des features, mapping labels).

Usage:
    python 03_train_correction_model.py --input spikes_boom1000.csv --markov markov_boom1000.json --output_dir models/boom1000
"""

import argparse
import json
import os

import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import accuracy_score, log_loss, classification_report


FEATURE_COLUMNS = [
    "dir_is_up",            # 1 si spike courant haussier, 0 sinon
    "amplitude_pips",
    "amplitude_atr",
    "velocity_proxy",
    "minutes_since_prev_spike",
    "hour",
    "minute",
    "markov_prior_up",      # probabilite Markov P(next=up | etat courant)
]


def attach_markov_prior(spikes: pd.DataFrame, markov: dict) -> pd.DataFrame:
    simple = markov["simple_transition"]
    s = spikes.copy()
    s["markov_prior_up"] = s["spike_direction"].map(lambda d: simple.get(d, {}).get("up", 0.5))
    return s


def build_feature_frame(spikes: pd.DataFrame, markov: dict) -> pd.DataFrame:
    s = attach_markov_prior(spikes, markov)
    s["dir_is_up"] = (s["spike_direction"] == "up").astype(int)

    # label = direction du spike SUIVANT (ce qu'on veut predire)
    s["next_direction"] = s["spike_direction"].shift(-1)
    s["label"] = (s["next_direction"] == "up").astype(int)

    # premiere ligne de chaque fichier peut avoir minutes_since_prev_spike = NaN
    s["minutes_since_prev_spike"] = s["minutes_since_prev_spike"].fillna(s["minutes_since_prev_spike"].median())

    s = s.dropna(subset=["next_direction"]).reset_index(drop=True)
    return s


def train_model(feat_df: pd.DataFrame) -> LGBMClassifier:
    X = feat_df[FEATURE_COLUMNS]
    y = feat_df["label"]

    # Split temporel (pas de shuffle aleatoire : on respecte la chronologie
    # des spikes pour eviter le leakage, critique en serie temporelle)
    tscv = TimeSeriesSplit(n_splits=5)
    scores = []
    for fold, (train_idx, test_idx) in enumerate(tscv.split(X)):
        model = LGBMClassifier(
            n_estimators=200,
            max_depth=4,
            learning_rate=0.05,
            num_leaves=15,
            min_child_samples=20,
            subsample=0.8,
            colsample_bytree=0.8,
            random_state=42,
            verbosity=-1,
        )
        model.fit(X.iloc[train_idx], y.iloc[train_idx])
        pred = model.predict(X.iloc[test_idx])
        proba = model.predict_proba(X.iloc[test_idx])[:, 1]
        acc = accuracy_score(y.iloc[test_idx], pred)
        try:
            ll = log_loss(y.iloc[test_idx], proba, labels=[0, 1])
        except ValueError:
            ll = float("nan")
        scores.append((acc, ll))
        print(f"  Fold {fold+1}: accuracy={acc:.4f}  log_loss={ll:.4f}")

    accs = [s[0] for s in scores]
    print(f"\n[CV] Accuracy moyenne: {np.mean(accs):.4f} (+/- {np.std(accs):.4f})")

    # Modele final entraine sur TOUT l'historique dispo
    final_model = LGBMClassifier(
        n_estimators=200, max_depth=4, learning_rate=0.05, num_leaves=15,
        min_child_samples=20, subsample=0.8, colsample_bytree=0.8,
        random_state=42, verbosity=-1,
    )
    final_model.fit(X, y)

    print("\nRapport de classification (in-sample, indicatif seulement):")
    print(classification_report(y, final_model.predict(X), target_names=["down", "up"]))

    print("\nImportance des features:")
    for name, imp in sorted(zip(FEATURE_COLUMNS, final_model.feature_importances_), key=lambda x: -x[1]):
        print(f"  {name:28s} {imp}")

    return final_model


def export_onnx(model: LGBMClassifier, output_path: str, n_features: int):
    # LightGBM n'est pas couvert par skl2onnx (reserve a scikit-learn natif) :
    # on utilise onnxmltools qui a un convertisseur dedie LightGBM -> ONNX.
    from onnxmltools import convert_lightgbm
    from onnxmltools.convert.common.data_types import FloatTensorType

    initial_type = [("input", FloatTensorType([None, n_features]))]
    onnx_model = convert_lightgbm(model, initial_types=initial_type, target_opset=15)
    with open(output_path, "wb") as f:
        f.write(onnx_model.SerializeToString())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="CSV des spikes (sortie module 1)")
    parser.add_argument("--markov", required=True, help="JSON de la matrice Markov (sortie module 2)")
    parser.add_argument("--output_dir", required=True)
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    spikes = pd.read_csv(args.input)
    with open(args.markov) as f:
        markov = json.load(f)

    feat_df = build_feature_frame(spikes, markov)
    print(f"[INFO] {len(feat_df)} exemples d'entrainement (paires spike->spike_suivant)")

    if len(feat_df) < 100:
        print("[ATTENTION] Moins de 100 exemples : le modele risque de surapprendre. "
              "Recolte plus d'historique avant de faire confiance aux resultats.")

    model = train_model(feat_df)

    onnx_path = os.path.join(args.output_dir, "spike_chain_model.onnx")
    export_onnx(model, onnx_path, n_features=len(FEATURE_COLUMNS))
    print(f"\n[OK] Modele ONNX exporte -> {onnx_path}")

    meta = {
        "feature_order": FEATURE_COLUMNS,
        "label_mapping": {"0": "down", "1": "up"},
        "n_training_examples": len(feat_df),
        "markov_source": args.markov,
        "notes": (
            "Le vecteur d'entree ONNX doit respecter EXACTEMENT l'ordre de feature_order. "
            "markov_prior_up doit etre recalcule cote MQL5 avec la meme matrice simple_transition "
            "que celle stockee dans le fichier markov JSON (ou recopiee en dur dans l'EA)."
        ),
    }
    meta_path = os.path.join(args.output_dir, "model_metadata.json")
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)
    print(f"[OK] Metadonnees sauvegardees -> {meta_path}")


if __name__ == "__main__":
    main()
