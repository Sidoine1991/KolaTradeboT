"""
Batch training: run spike detection + Markov + LightGBM + ONNX export
for all Weltrade synthetics and Deriv pairs.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
OUTPUT_DIR = os.path.join(BASE_DIR, "models")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SYMBOLS = [
    "PainX 400", "GainX 400", "PainX 600", "GainX 600",
    "PainX 800", "GainX 800", "PainX 999", "GainX 999",
    "PainX 1200", "GainX 1200",
    "FX Vol 20", "FX Vol 40", "FX Vol 60", "FX Vol 80", "FX Vol 99",
    "SFX Vol 20", "SFX Vol 40", "SFX Vol 60", "SFX Vol 80", "SFX Vol 99",
]


def run_step(script: str, args: list, desc: str) -> bool:
    cmd = [sys.executable, os.path.join(BASE_DIR, script)] + args
    print(f"\n{'='*60}")
    print(f"[{script}] {desc}")
    print(f"{'='*60}")
    start = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    elapsed = time.time() - start
    if result.returncode != 0:
        print(f"[FAIL] ({elapsed:.1f}s): {result.stderr[:500]}")
        print(result.stdout[-500:])
        return False
    print(f"[OK] ({elapsed:.1f}s)")
    for line in result.stdout.strip().split("\n"):
        print(f"  {line}")
    return True


def train_symbol(symbol: str) -> bool:
    safe = symbol.replace(" ", "_")
    csv_path = os.path.join(DATA_DIR, f"{safe}_M1.csv")
    if not os.path.exists(csv_path):
        print(f"[SKIP] {symbol}: no data at {csv_path}")
        return False

    sym_out_dir = os.path.join(OUTPUT_DIR, safe)
    os.makedirs(sym_out_dir, exist_ok=True)

    spikes_csv = os.path.join(sym_out_dir, "spikes.csv")
    markov_json = os.path.join(sym_out_dir, "markov.json")

    if not run_step("01_spike_detection.py", [
        "--input", csv_path, "--symbol", symbol, "--output", spikes_csv
    ], f"Spike detection: {symbol}"):
        return False

    if not run_step("02_markov_baseline.py", [
        "--input", spikes_csv, "--output", markov_json
    ], f"Markov matrix: {symbol}"):
        return False

    # Regression model: predict next spike AMPLITUDE (works for ALL symbols)
    if not run_step("02_train_spike_regression.py", [
        "--input", spikes_csv, "--output_dir", sym_out_dir, "--target", "amplitude"
    ], f"Amplitude regression: {symbol}"):
        return False

    # Regression model: predict next spike INTERVAL (time until next spike)
    if not run_step("02_train_spike_regression.py", [
        "--input", spikes_csv, "--output_dir", sym_out_dir, "--target", "interval"
    ], f"Interval regression: {symbol}"):
        return False

    # Direction classification model (only useful for symbols with both directions)
    is_bidirectional = "Vol" in symbol or "SFX" in symbol
    if is_bidirectional:
        if not run_step("03_train_correction_model.py", [
            "--input", spikes_csv, "--markov", markov_json, "--output_dir", sym_out_dir
        ], f"Direction + ONNX: {symbol}"):
            return False

        if not run_step("04_verify_onnx.py", [
            "--model_dir", sym_out_dir, "--input", spikes_csv, "--markov", markov_json
        ], f"ONNX verification: {symbol}"):
            return False

    print(f"[DONE] {symbol} -> {sym_out_dir}")
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--symbol", default=None, help="Train only one symbol (default: all)")
    parser.add_argument("--skip-models", action="store_true", help="Skip symbols with existing model")
    args = parser.parse_args()

    failed = []
    symbols = [args.symbol] if args.symbol else SYMBOLS

    for sym in symbols:
        if args.skip_models:
            safe = sym.replace(" ", "_")
            model_path = os.path.join(OUTPUT_DIR, safe, "spike_chain_model.onnx")
            if os.path.exists(model_path):
                print(f"[SKIP] {sym}: model already exists")
                continue
        if not train_symbol(sym):
            failed.append(sym)
        time.sleep(0.5)

    print(f"\n{'='*60}")
    print(f"Training complete. {len(symbols) - len(failed)}/{len(symbols)} succeeded.")
    if failed:
        print(f"Failed: {failed}")


if __name__ == "__main__":
    main()
