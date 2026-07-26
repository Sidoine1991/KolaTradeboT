"""
Modified pipeline for one-directional spike instruments (PainX, GainX, Boom, Crash).
Instead of predicting next-spike direction (always the same), predict:
  1) Time until next spike (minutes) — regression
  2) Amplitude of next spike (in ATR multiples) — regression
These are directly useful for position sizing, stop placement, and timing.
"""
import argparse
import json
import os

import numpy as np
import pandas as pd
from lightgbm import LGBMRegressor, LGBMClassifier
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import mean_absolute_error, r2_score, accuracy_score


FEATURE_COLUMNS = [
    "amplitude_atr",          # spike intensity (in ATR units)
    "velocity_proxy",         # how fast the spike formed
    "minutes_since_prev",     # minutes since last spike
    "hour",                   # time-of-day
    "minute",                 # minute-of-hour
    "close_zscore",           # distance from recent mean
    "spikes_last_60min",      # spike frequency in last hour
    "avg_amplitude_last_5",   # average amplitude of last 5 spikes (ATR)
    "amplitude_ratio",        # current amp / avg of last 5
    "chain_len",              # spikes in current chain (consecutive within 15min)
]

TARGETS = {
    "amplitude": "next_amplitude_atr",     # amplitude of next spike (ATR multiples)
    "interval":  "next_interval_minutes",   # minutes until next spike
    "large":     "next_is_large",            # 1 if next spike is > median amplitude
}


def compute_close_zscore(close: pd.Series, span: int = 100) -> pd.Series:
    ma = close.rolling(span, min_periods=span).mean()
    std = close.rolling(span, min_periods=span).std()
    return (close - ma) / std.replace(0, np.nan)


def build_frame(spikes: pd.DataFrame, target: str) -> pd.DataFrame:
    s = spikes.copy()
    s["minutes_since_prev"] = s["minutes_since_prev_spike"].fillna(
        s["minutes_since_prev_spike"].median()
    )
    s["close_zscore"] = compute_close_zscore(s["close"])
    s["close_zscore"] = s["close_zscore"].fillna(0)

    s["avg_amplitude_last_5"] = s["amplitude_atr"].rolling(5, min_periods=1).mean().shift(1)
    s["avg_amplitude_last_5"] = s["avg_amplitude_last_5"].fillna(s["amplitude_atr"].median())
    s["amplitude_ratio"] = s["amplitude_atr"] / s["avg_amplitude_last_5"].replace(0, np.nan)
    s["amplitude_ratio"] = s["amplitude_ratio"].fillna(1.0)

    spike_count_last_60 = []
    chain_len = []
    for i in range(len(s)):
        t = s["time"].iloc[i]
        window_start = t - pd.Timedelta(minutes=60)
        count = ((s["time"].iloc[:i] >= window_start) & (s["time"].iloc[:i] < t)).sum()
        spike_count_last_60.append(count)
        msp = s["minutes_since_prev"].iloc[i]
        if i == 0 or pd.isna(msp) or msp > 15:
            chain_len.append(1)
        else:
            chain_len.append(chain_len[-1] + 1)
    s["spikes_last_60min"] = spike_count_last_60
    s["chain_len"] = chain_len

    if target == "amplitude":
        s["next_target"] = s["amplitude_atr"].shift(-1)
    elif target == "interval":
        s["next_target"] = s["minutes_since_prev"].shift(-1)
    elif target == "large":
        med = s["amplitude_atr"].median()
        s["next_is_large"] = (s["amplitude_atr"].shift(-1) > med).astype(int)
        s["next_target"] = s["next_is_large"]

    s = s.dropna(subset=["next_target"])
    return s.reset_index(drop=True)


def train_model(feat_df: pd.DataFrame, target_name: str) -> tuple:
    X = feat_df[FEATURE_COLUMNS]
    y = feat_df["next_target"]

    is_classification = target_name == "large"

    tscv = TimeSeriesSplit(n_splits=5)
    scores = []

    for fold, (train_idx, test_idx) in enumerate(tscv.split(X)):
        if is_classification:
            model = LGBMClassifier(
                n_estimators=200, max_depth=4, learning_rate=0.05,
                num_leaves=15, min_child_samples=20, subsample=0.8,
                colsample_bytree=0.8, random_state=42, verbosity=-1,
            )
        else:
            model = LGBMRegressor(
                n_estimators=200, max_depth=4, learning_rate=0.05,
                num_leaves=15, min_child_samples=20, subsample=0.8,
                colsample_bytree=0.8, random_state=42, verbosity=-1,
            )
        model.fit(X.iloc[train_idx], y.iloc[train_idx])
        pred = model.predict(X.iloc[test_idx])

        if is_classification:
            acc = accuracy_score(y.iloc[test_idx], (pred >= 0.5).astype(int))
            scores.append(acc)
            print(f"  Fold {fold+1}: accuracy={acc:.4f}")
        else:
            mae = mean_absolute_error(y.iloc[test_idx], pred)
            r2 = r2_score(y.iloc[test_idx], pred)
            scores.append((mae, r2))
            print(f"  Fold {fold+1}: MAE={mae:.4f}  R2={r2:.4f}")

    # Final model on all data
    if is_classification:
        final = LGBMClassifier(
            n_estimators=200, max_depth=4, learning_rate=0.05,
            num_leaves=15, min_child_samples=20, subsample=0.8,
            colsample_bytree=0.8, random_state=42, verbosity=-1,
        )
    else:
        final = LGBMRegressor(
            n_estimators=200, max_depth=4, learning_rate=0.05,
            num_leaves=15, min_child_samples=20, subsample=0.8,
            colsample_bytree=0.8, random_state=42, verbosity=-1,
        )
    final.fit(X, y)

    print("\nFeature importance:")
    for name, imp in sorted(zip(FEATURE_COLUMNS, final.feature_importances_), key=lambda x: -x[1]):
        print(f"  {name:24s} {imp}")

    return final


def export_onnx_model(model, output_path: str, n_features: int):
    from onnxmltools import convert_lightgbm
    from onnxmltools.convert.common.data_types import FloatTensorType

    initial_type = [("input", FloatTensorType([None, n_features]))]
    onnx_model = convert_lightgbm(model, initial_types=initial_type, target_opset=15)
    with open(output_path, "wb") as f:
        f.write(onnx_model.SerializeToString())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Spike events CSV (output of 01_spike_detection.py)")
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--target", default="amplitude", choices=list(TARGETS.keys()),
                        help="Prediction target: amplitude, interval, or large")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    spikes = pd.read_csv(args.input, parse_dates=["time"])
    print(f"[INFO] {len(spikes)} spike events loaded from {args.input}")
    print(f"       Direction counts: {spikes['spike_direction'].value_counts().to_dict()}")

    feat_df = build_frame(spikes, args.target)
    print(f"[INFO] {len(feat_df)} training examples (target={args.target})")

    if len(feat_df) < 50:
        print("[WARN] Too few examples for a reliable model")

    model = train_model(feat_df, args.target)

    model_name = f"spike_{args.target}.onnx"
    onnx_path = os.path.join(args.output_dir, model_name)
    export_onnx_model(model, onnx_path, n_features=len(FEATURE_COLUMNS))
    print(f"[OK] ONNX model exported -> {onnx_path}")

    # Feature metadata
    meta = {
        "symbol": spikes["symbol"].iloc[0] if "symbol" in spikes.columns else "unknown",
        "model_type": "classification" if args.target == "large" else "regression",
        "n_training_examples": len(feat_df),
        "feature_order": FEATURE_COLUMNS,
        "target": args.target,
        "target_description": TARGETS[args.target],
        "notes": "Use with OnnxRuntime in MQL5. Input order must match feature_order exactly.",
    }
    with open(os.path.join(args.output_dir, f"model_metadata_{args.target}.json"), "w") as f:
        json.dump(meta, f, indent=2)

    print(f"[OK] Metadata saved")


if __name__ == "__main__":
    main()
