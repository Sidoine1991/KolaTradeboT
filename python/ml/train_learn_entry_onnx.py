#!/usr/bin/env python3
"""Train a LightGBM entry model on SMC_Learn shadow CSV and export ONNX.

Label = 1 if signed 15-minute return (ret15_atr) > 0.
Features = context at signal time only (never ret5/ret15/mfe/mae).
ATR-like distances are winsorized at +/- WINSOR_ATR.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
from datetime import datetime, timezone
from glob import glob
from typing import Tuple

import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier
from sklearn.metrics import roc_auc_score, classification_report, brier_score_loss

WINSOR_ATR = 10.0
# Label smarter (v1.57): edge ATR minimum — pas seulement ret15>0 (WR~40%).
# Un trade est "win" si (mfe-mae)/ATR >= EDGE_ATR OU ret15_atr >= RET15_EDGE.
EDGE_ATR = 0.25
RET15_EDGE = 0.15
HARD_BLOCK = {"GainX 800", "GainX 999", "PainX 999", "PainX 1200"}
FEATURE_ORDER = [
    "dir_is_buy",
    "vn_abs",
    "vn_aligned",
    "coh",
    "qual",
    "m1_align",
    "m5_align",
    "m15_align",
    "delta_w",
    "cvd_w",
    "poc_d",
    "vah_d",
    "val_d",
    "in_va",
    "flow20",
    "flow3",
    "atr_pct",
    "rsi14",
    "ema_gap",
    "spread_w",
    "hour",
    "dow",
    "imminence",
    "ai_conf",
    "gom_conn",
    "fam_fxvol",
    "fam_pain",
    "fam_gain",
]

LEAK_COLS = {"ret5_atr", "ret15_atr", "mfe_atr", "mae_atr"}


def _num(s, default=np.nan):
    try:
        if s is None or (isinstance(s, float) and np.isnan(s)):
            return default
        v = float(str(s).strip().replace(",", "."))
        if not np.isfinite(v):
            return default
        return v
    except (TypeError, ValueError):
        return default


def _tf_sign(v) -> float:
    s = str(v or "").strip().upper()
    if s in ("BULL", "BUY", "UP", "LONG"):
        return 1.0
    if s in ("BEAR", "SELL", "DOWN", "SHORT"):
        return -1.0
    return 0.0


def _family(sym: str) -> str:
    u = str(sym or "").upper().replace(" ", "")
    if "FXVOL" in u or "VOLATILITY" in u or "SFXVOL" in u:
        return "fxvol"
    if "PAIN" in u or "BOOM" in u:
        return "pain"
    if "GAIN" in u or "CRASH" in u:
        return "gain"
    return "other"


def _winsor(x, lo, hi):
    return float(np.clip(_num(x, 0.0), lo, hi))


def find_shadow_files(extra_dirs):
    files = []
    seen = set()
    for d in extra_dirs:
        if not d or not os.path.isdir(d):
            continue
        for p in glob(os.path.join(d, "shadow_*.csv")):
            key = os.path.basename(p).lower()
            # Prefer the largest file per basename (terminal local > tiny Common copy)
            prev = next((f for f in files if os.path.basename(f).lower() == key), None)
            if prev is None:
                files.append(p)
                seen.add(key)
            elif os.path.getsize(p) > os.path.getsize(prev):
                files = [p if f == prev else f for f in files]
    return files


def load_shadows(files) -> pd.DataFrame:
    frames = []
    for p in files:
        try:
            df = pd.read_csv(p, low_memory=False)
        except Exception as e:
            print(f"[WARN] skip {p}: {e}")
            continue
        if "ret15_atr" not in df.columns:
            print(f"[WARN] no ret15_atr in {p}")
            continue
        df["__src"] = p
        frames.append(df)
        print(f"[DATA] {os.path.basename(p)}: {len(df)} rows")
    if not frames:
        raise SystemExit("No shadow CSV with ret15_atr found")
    out = pd.concat(frames, ignore_index=True)
    if "time" in out.columns:
        out["_t"] = pd.to_datetime(out["time"], errors="coerce")
        out = out.sort_values("_t").drop_duplicates(subset=["time", "symbol", "side", "price"], keep="last")
    print(f"[DATA] merged unique rows: {len(out)}")
    return out.reset_index(drop=True)


def _label_win(rec) -> Tuple[int, float]:
    """Smarter label: edge ATR (mfe-mae) ou ret15 au-dessus du seuil."""
    r15 = _num(rec.get("ret15_atr"))
    mfe = _num(rec.get("mfe_atr"))
    mae = _num(rec.get("mae_atr"))
    edge = np.nan
    if np.isfinite(mfe) and np.isfinite(mae):
        edge = mfe - mae
    score = r15 if np.isfinite(r15) else edge
    if not np.isfinite(score):
        return -1, np.nan
    win = 0
    if np.isfinite(edge) and edge >= EDGE_ATR:
        win = 1
    elif np.isfinite(r15) and r15 >= RET15_EDGE:
        win = 1
    return win, float(score if np.isfinite(score) else 0.0)


def build_xy(df: pd.DataFrame, exclude_hardblock: bool = True):
    rows = []
    y = []
    ret15 = []
    symbols = []
    for rec in df.to_dict("records"):
        sym = str(rec.get("symbol") or "").strip()
        if exclude_hardblock and sym in HARD_BLOCK:
            continue
        win, score = _label_win(rec)
        if win < 0 or not np.isfinite(score):
            continue
        side = str(rec.get("side") or "").upper()
        dsign = 1.0 if side == "BUY" else -1.0 if side == "SELL" else 0.0
        if dsign == 0.0:
            continue
        fam = _family(sym)
        vn = _num(rec.get("vn"), 0.0)
        feat = {
            "dir_is_buy": 1.0 if dsign > 0 else 0.0,
            "vn_abs": abs(vn),
            "vn_aligned": vn * dsign,
            "coh": _winsor(rec.get("coh"), 0.0, 100.0),
            "qual": _winsor(rec.get("qual"), 0.0, 100.0),
            "m1_align": _tf_sign(rec.get("tf_m1")) * dsign,
            "m5_align": _tf_sign(rec.get("tf_m5")) * dsign,
            "m15_align": _tf_sign(rec.get("tf_m15")) * dsign,
            "delta_w": _winsor(rec.get("delta"), -100.0, 100.0),
            "cvd_w": _winsor(rec.get("cvd"), -300.0, 300.0),
            "poc_d": _winsor(rec.get("poc_d"), -WINSOR_ATR, WINSOR_ATR),
            "vah_d": _winsor(rec.get("vah_d"), -WINSOR_ATR, WINSOR_ATR),
            "val_d": _winsor(rec.get("val_d"), -WINSOR_ATR, WINSOR_ATR),
            "in_va": _winsor(rec.get("in_va"), 0.0, 1.0),
            "flow20": _winsor(rec.get("flow20"), -5.0, 5.0),
            "flow3": _winsor(rec.get("flow3"), -5.0, 5.0),
            "atr_pct": _winsor(rec.get("atr_pct"), 0.0, 1.0),
            "rsi14": _winsor(rec.get("rsi14"), 0.0, 100.0),
            "ema_gap": _winsor(rec.get("ema_gap"), -WINSOR_ATR, WINSOR_ATR),
            "spread_w": _winsor(rec.get("spread_pts"), 0.0, 2000.0),
            "hour": _winsor(rec.get("hour"), 0.0, 23.0),
            "dow": _winsor(rec.get("dow"), 0.0, 6.0),
            "imminence": _winsor(rec.get("imminence"), 0.0, 100.0),
            "ai_conf": _winsor(rec.get("ai_conf"), 0.0, 1.0),
            "gom_conn": _winsor(rec.get("gom_conn"), 0.0, 1.0),
            "fam_fxvol": 1.0 if fam == "fxvol" else 0.0,
            "fam_pain": 1.0 if fam == "pain" else 0.0,
            "fam_gain": 1.0 if fam == "gain" else 0.0,
        }
        rows.append([feat[k] for k in FEATURE_ORDER])
        y.append(win)
        ret15.append(score)
        symbols.append(sym)
    X = np.asarray(rows, dtype=np.float32)
    y = np.asarray(y, dtype=np.int32)
    ret15 = np.asarray(ret15, dtype=np.float64)
    return X, y, ret15, symbols


def print_symbol_metrics(raw: pd.DataFrame):
    print("\n[METRICS] expectancy / WR par symbole (label edge ATR)")
    print(f"{'symbol':16s} {'n':>6s} {'WR%':>6s} {'E[edge]':>8s} {'E[ret15]':>8s}")
    rows = []
    for sym, g in raw.groupby(raw["symbol"].astype(str)):
        n = len(g)
        edges = []
        wins = 0
        r15s = []
        for rec in g.to_dict("records"):
            win, score = _label_win(rec)
            if win < 0:
                continue
            wins += win
            edges.append(_num(rec.get("mfe_atr"), 0.0) - _num(rec.get("mae_atr"), 0.0))
            r15s.append(_num(rec.get("ret15_atr"), np.nan))
        if not edges:
            continue
        r15_clean = [x for x in r15s if np.isfinite(x)]
        rows.append((sym, len(edges), 100.0 * wins / len(edges), float(np.mean(edges)),
                     float(np.mean(r15_clean)) if r15_clean else float("nan")))
    for sym, n, wr, e, r in sorted(rows, key=lambda x: -x[3]):
        flag = " OK" if e > 0.1 else (" BAD" if e < -0.3 else "")
        print(f"{sym:16s} {n:6d} {wr:6.1f} {e:+8.3f} {r:+8.3f}{flag}")


def point_biserial(x, y):
    if x.std() < 1e-12 or y.std() < 1e-12:
        return 0.0
    return float(np.corrcoef(x, y)[0, 1])


def time_split(n, frac=0.25):
    cut = max(20, int(n * (1.0 - frac)))
    cut = min(cut, n - 10) if n > 30 else n
    return slice(0, cut), slice(cut, n)


def calibrate_threshold(proba, ret15, min_n=30, min_wr=0.42):
    """Lowest probability that still has positive ATR expectancy on holdout."""
    best = {"threshold": 1.01, "n": 0, "wr": 0.0, "exp_atr": 0.0, "coverage": 0.0}
    for thr in np.round(np.linspace(0.30, 0.85, 56), 3):
        mask = proba >= thr
        n = int(mask.sum())
        if n < min_n:
            continue
        wr = float((ret15[mask] > 0).mean())
        exp = float(ret15[mask].mean())
        if wr >= min_wr and exp > best["exp_atr"]:
            best = {
                "threshold": float(thr),
                "n": n,
                "wr": wr,
                "exp_atr": exp,
                "coverage": n / len(proba),
            }
    # Fallback: meilleur expectancy meme si WR un peu sous le seuil
    if best["n"] <= 0:
        for thr in np.round(np.linspace(0.40, 0.75, 36), 3):
            mask = proba >= thr
            n = int(mask.sum())
            if n < max(20, min_n // 2):
                continue
            exp = float(ret15[mask].mean())
            wr = float((ret15[mask] > 0).mean())
            if exp > 0.05 and exp > best["exp_atr"]:
                best = {
                    "threshold": float(thr),
                    "n": n,
                    "wr": wr,
                    "exp_atr": exp,
                    "coverage": n / len(proba),
                    "note": "fallback_exp_only",
                }
    return best


def export_onnx(model, path, n_features):
    from onnxmltools import convert_lightgbm
    from onnxmltools.convert.common.data_types import FloatTensorType

    initial_type = [("input", FloatTensorType([None, n_features]))]
    kwargs = dict(initial_types=initial_type, target_opset=12)
    try:
        onnx_model = convert_lightgbm(model, zipmap=False, **kwargs)
    except TypeError:
        onnx_model = convert_lightgbm(model, **kwargs)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(onnx_model.SerializeToString())
    try:
        import onnx

        m = onnx.load(path)
        print("[ONNX] inputs:", [(i.name, [d.dim_value for d in i.type.tensor_type.shape.dim]) for i in m.graph.input])
        print("[ONNX] outputs:", [(o.name, [d.dim_value for d in o.type.tensor_type.shape.dim]) for o in m.graph.output])
    except Exception as e:
        print("[ONNX] inspect skipped:", e)
    return path


def deploy_copies(onnx_path, meta_path, dest_dirs):
    for d in dest_dirs:
        if not d:
            continue
        os.makedirs(d, exist_ok=True)
        shutil.copy2(onnx_path, os.path.join(d, os.path.basename(onnx_path)))
        shutil.copy2(meta_path, os.path.join(d, os.path.basename(meta_path)))
        print(f"[DEPLOY] {d}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shadow-dir", action="append", default=[])
    ap.add_argument("--output-dir", default=os.path.join("mt5", "SMC_Learn", "models"))
    args = ap.parse_args()

    appdata = os.environ.get("APPDATA", "")
    defaults = []
    if appdata:
        term = os.path.join(appdata, "MetaQuotes", "Terminal")
        if os.path.isdir(term):
            for name in os.listdir(term):
                p = os.path.join(term, name, "MQL5", "Files", "SMC_Learn")
                defaults.append(p)
        defaults.append(os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "TradBOT", "SMC_Learn"))
    dirs = args.shadow_dir + defaults
    files = find_shadow_files(dirs)
    print(f"[DATA] shadow files: {len(files)}")
    raw = load_shadows(files)
    leak = [c for c in raw.columns if c.lower() in LEAK_COLS]
    print(f"[DATA] outcome cols kept out of X: {leak}")
    print_symbol_metrics(raw)

    X, y, ret15, symbols = build_xy(raw, exclude_hardblock=True)
    print(f"\n[DATA] usable={len(y)} (hard-block exclus)  winrate={(y.mean()*100):.1f}%  "
          f"score mean={ret15.mean():.3f} std={ret15.std():.3f}")
    print(f"[DATA] label = (mfe-mae)>= {EDGE_ATR} OR ret15>= {RET15_EDGE}")
    print(f"[DATA] score p01={np.quantile(ret15,0.01):.2f} p99={np.quantile(ret15,0.99):.2f}")

    print("\n[CORR] point-biserial vs win(label)")
    for i, name in enumerate(FEATURE_ORDER):
        print(f"  {name:16s} {point_biserial(X[:, i], y):+.3f}")

    if len(y) < 80:
        raise SystemExit(f"Too few samples ({len(y)}) for a stable ONNX model")

    tr, te = time_split(len(y), 0.25)
    Xtr, Xte, ytr, yte = X[tr], X[te], y[tr], y[te]
    rtr, rte = ret15[tr], ret15[te]
    print(f"\n[SPLIT] train={len(ytr)} test={len(yte)} (time-ordered, last 25%)")

    scale_pos = max(1.0, (len(ytr) - ytr.sum()) / max(1, ytr.sum()))
    model = LGBMClassifier(
        n_estimators=280,
        max_depth=5,
        learning_rate=0.03,
        num_leaves=16,
        min_child_samples=20,
        subsample=0.85,
        colsample_bytree=0.85,
        reg_lambda=1.0,
        scale_pos_weight=scale_pos,
        random_state=42,
        verbosity=-1,
    )
    model.fit(Xtr, ytr)
    pte = model.predict_proba(Xte)[:, 1]
    try:
        auc = roc_auc_score(yte, pte)
    except ValueError:
        auc = float("nan")
    brier = brier_score_loss(yte, pte)
    print(f"[TEST] AUC={auc:.3f}  Brier={brier:.3f}")
    print(classification_report(yte, (pte >= 0.5).astype(int), digits=3, zero_division=0))

    # Gate metrics at calibrated thresholds
    print("\n[GATE SIM] holdout — trades retenus si P(win)>=thr")
    for thr in (0.45, 0.50, 0.55, 0.60, 0.65):
        mask = pte >= thr
        n = int(mask.sum())
        if n < 5:
            print(f"  thr={thr:.2f}  n={n}  (trop peu)")
            continue
        wr = float((rte[mask] > 0).mean()) * 100
        exp = float(rte[mask].mean())
        cov = 100.0 * n / len(pte)
        print(f"  thr={thr:.2f}  n={n:4d}  cov={cov:5.1f}%  WR={wr:5.1f}%  E[score]={exp:+.3f}")

    print("[IMPORTANCE]")
    for name, imp in sorted(zip(FEATURE_ORDER, model.feature_importances_), key=lambda x: -x[1])[:12]:
        print(f"  {name:16s} {imp}")

    cal = calibrate_threshold(pte, rte, min_n=max(25, len(yte) // 8))
    print(f"[CAL] {cal}")
    if cal["n"] <= 0:
        cal = {"threshold": 1.01, "n": 0, "wr": 0.0, "exp_atr": 0.0, "coverage": 0.0, "note": "no profitable bucket"}
        print("[CAL] no profitable holdout bucket — gate will fail-open")

    # Refit on all data for deployment
    model.fit(X, y)

    out_dir = args.output_dir
    os.makedirs(out_dir, exist_ok=True)
    onnx_path = os.path.join(out_dir, "learn_entry.onnx")
    export_onnx(model, onnx_path, len(FEATURE_ORDER))
    meta = {
        "model": "learn_entry",
        "feature_order": FEATURE_ORDER,
        "n_features": len(FEATURE_ORDER),
        "winsor_atr": WINSOR_ATR,
        "label": f"(mfe-mae)>= {EDGE_ATR} OR ret15_atr>= {RET15_EDGE}",
        "hard_block_excluded": sorted(HARD_BLOCK),
        "n_training_examples": int(len(y)),
        "train_winrate": float(y.mean()),
        "test_auc": None if np.isnan(auc) else float(auc),
        "test_brier": float(brier),
        "threshold": cal["threshold"],
        "threshold_holdout": cal,
        "training_date": datetime.now(timezone.utc).isoformat(),
        "notes": (
            "Input float32 [1, n_features] in feature_order. "
            "Output probabilities [P(lose), P(win)]. Use P(win) >= threshold. "
            "ret5/ret15/mfe/mae are outcomes, never features. "
            "Hard-block symbols excluded from training; EA also blocks them via LJ_HardBlockSymbols."
        ),
    }
    meta_path = os.path.join(out_dir, "learn_entry_metadata.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"[OK] {onnx_path}")
    print(f"[OK] {meta_path}")

    dest = [out_dir]
    if appdata:
        dest.append(os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "TradBOT", "SMC_Learn"))
        term = os.path.join(appdata, "MetaQuotes", "Terminal")
        if os.path.isdir(term):
            for name in os.listdir(term):
                files_dir = os.path.join(term, name, "MQL5", "Files", "SMC_Learn")
                parent = os.path.join(term, name, "MQL5", "Files")
                if os.path.isdir(parent):
                    dest.append(files_dir)
    deploy_copies(onnx_path, meta_path, dest)


if __name__ == "__main__":
    main()
