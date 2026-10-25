import os
import importlib.util
import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier

spec = importlib.util.spec_from_file_location(
    "t", r"D:\Dev\TradBOT\python\ml\train_learn_entry_onnx.py"
)
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)

appdata = os.environ["APPDATA"]
term = os.path.join(appdata, "MetaQuotes", "Terminal")
dirs = [os.path.join(term, n, "MQL5", "Files", "SMC_Learn") for n in os.listdir(term)]
dirs.append(os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "TradBOT", "SMC_Learn"))
files = t.find_shadow_files(dirs)
raw = t.load_shadows(files)
X, y, ret15 = t.build_xy(raw)
tr, te = t.time_split(len(y), 0.25)
Xtr, Xte, ytr, yte = X[tr], X[te], y[tr], y[te]
rte = ret15[te]
scale_pos = max(1.0, (len(ytr) - ytr.sum()) / max(1, ytr.sum()))
cols = t.FEATURE_ORDER
m = LGBMClassifier(
    n_estimators=250, max_depth=4, learning_rate=0.03, num_leaves=12,
    min_child_samples=25, subsample=0.8, colsample_bytree=0.8, reg_lambda=1.0,
    scale_pos_weight=scale_pos, random_state=42, verbosity=-1,
)
m.fit(pd.DataFrame(Xtr, columns=cols), ytr)
p = m.predict_proba(pd.DataFrame(Xte, columns=cols))[:, 1]
print("test mean p", float(p.mean()), "p50", float(np.median(p)),
      "p90", float(np.quantile(p, 0.9)), "p95", float(np.quantile(p, 0.95)))
print(f"{'thr':>6} {'n':>5} {'cov':>6} {'wr':>6} {'exp':>7}")
for thr in [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80]:
    mask = p >= thr
    n = int(mask.sum())
    if n == 0:
        continue
    wr = float((rte[mask] > 0).mean())
    exp = float(rte[mask].mean())
    print(f"{thr:6.2f} {n:5d} {n/len(p):6.2%} {wr:6.1%} {exp:7.3f}")

idx = t.FEATURE_ORDER.index("fam_fxvol")
fx = Xte[:, idx] > 0.5
print("\nFXVOL only test n=", int(fx.sum()))
pf, rf = p[fx], rte[fx]
for thr in [0.40, 0.50, 0.55, 0.60, 0.65, 0.70]:
    mask = pf >= thr
    n = int(mask.sum())
    if n < 10:
        print(thr, "n", n)
        continue
    print(f"{thr:.2f} n={n} wr={(rf[mask]>0).mean():.1%} exp={rf[mask].mean():.3f}")
