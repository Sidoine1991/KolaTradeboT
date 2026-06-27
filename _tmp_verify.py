import sys; sys.stdout.reconfigure(encoding='utf-8')
import warnings; warnings.filterwarnings('ignore')
import pandas as pd
import numpy as np

# Load backtest_smc_universal as module to access its exact functions
import importlib.util
spec = importlib.util.spec_from_file_location("bt", r"D:\Dev\TradBOT\backtest_smc_universal.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

name = 'Boom 1000'
path = mod.SYM_CFG[name]['csv']
df = mod.load(path)
df = df[df.time >= '2020-01-01'].reset_index(drop=True)
rng = (df.high.values-df.low.values); rng_m = np.median(rng[rng>0]); pv = 0.1 if rng_m > 10 else (1.0 if rng_m > 100 else 0.01)

df2 = mod.compute(df.copy())
df3 = mod.detect(df2, pv)
df4 = df3.dropna(subset=['atr','rsi','ef','es']).reset_index(drop=True)
N = len(df4)
print(f'After dropna N={N}')

# Now construct sig INSIDE backtest() style
fvg_dir = np.where(df4.fvg_bull.values, 1, np.where(df4.fvg_bear.values, -1, 0))
print(f'fvg_dir unique: {np.unique(fvg_dir)}')
print(f'fvg_bull sum: {df4.fvg_bull.values.sum()}')
print(f'fvg_bear sum: {df4.fvg_bear.values.sum()}')

sig = np.zeros(N, dtype=np.int8)
ses = df4.session.values
htf = df4.htf.values
rsi_v = df4.rsi.values
ddir = 1
sig[(fvg_dir==1)&ses] = 1
bos_fb = df4.bos_bull.values & (~np.isin(fvg_dir,[1])) & ses
print(f'bos_fb candidates: {np.count_nonzero(bos_fb)}', flush=True)
sig[bos_fb] = 1
print(f'apres BOS fb: {np.count_nonzero(sig)}', flush=True)
rsi_ok = (rsi_v>22)&(rsi_v<78)
print(f'rsi_ok sum: {rsi_ok.sum()} range={rsi_v.min():.1f}->{rsi_v.max():.1f}', flush=True)
print(f'rsi_v[0:10]={rsi_v[:10]}', flush=True)
sig[~rsi_ok] = 0
print(f'apres RSI: {np.count_nonzero(sig)}', flush=True)
sig[htf!=ddir] = 0
print(f'apres HTF: {np.count_nonzero(sig)}', flush=True)

nz = np.nonzero(sig)[0]
print(f'first_sig_idx={nz[0] if len(nz)>0 else -1}', flush=True)
if len(nz)>0:
    for idx in nz[:2]:
        print(f'  i={idx} t={df4.time.iat[idx]} c={df4.close.iat[idx]:.2f} atr={df4.atr.iat[idx]:.3f} htf={htf[idx]} rsi={rsi_v[idx]:.1f}', flush=True)
