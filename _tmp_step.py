import sys; sys.stdout.reconfigure(encoding='utf-8')
import warnings; warnings.filterwarnings('ignore')
import pandas as pd
import numpy as np

def load(path):
    df = pd.read_csv(path, sep=',', names=['date','hour','open','high','low','close','tick_volume'], skiprows=1)
    df['time'] = pd.to_datetime(df['date']+' '+df['hour'], format='%Y.%m.%d %H:%M')
    return df.drop(columns=['date','hour']).sort_values('time').reset_index(drop=True)

def compute(df):
    tr = pd.concat([df.high-df.low, (df.high-df.close.shift()).abs(), (df.low-df.close.shift()).abs()], axis=1).max(axis=1)
    df['atr'] = tr.ewm(span=14, adjust=False).mean().values
    df['ef'] = df.close.ewm(span=20, adjust=False).mean().values
    df['es'] = df.close.ewm(span=50, adjust=False).mean().values
    df['eh'] = df.close.ewm(span=240, adjust=False).mean().values
    df['htf'] = np.where(df.close.values > df['eh'].values, 1, -1)
    d = df.close.diff()
    g = d.where(d>0, 0.0).ewm(alpha=1/14, min_periods=14, adjust=False).mean().values
    lv = (-d).where(d<0, 0.0).ewm(alpha=1/14, min_periods=14, adjust=False).mean().values
    df['rsi'] = 100.0 - 100.0 / (1.0 + g / np.where(np.abs(lv)<1e-9, 1e-9, lv))
    df['session'] = (df.time.dt.hour.values >= 0) & (df.time.dt.hour.values < 24)
    return df

def detect(df, pv):
    c = df.close.values; h = df.high.values; lw = df.low.values
    bull = np.empty_like(c); bear = np.empty_like(c)
    bull[:-1] = lw[1:]-h[:-1]; bull[-1]=0
    bear[:-1] = lw[:-1]-h[1:]; bear[-1]=0
    df['fvg_bull'] = (bull>=3.0*pv)&(bull>0)
    df['fvg_bear'] = (bear>=3.0*pv)&(bear>0)
    df['bos_bull'] = c > pd.Series(h).rolling(10,min_periods=10).max().shift(1).fillna(0).values
    df['bos_bear'] = c < pd.Series(lw).rolling(10,min_periods=10).min().shift(1).fillna(1e9).values
    return df

path = r'D:\Dev\TradBOT\Bomm & Crash Deriv\Boom 1000 Index\Boom 1000 Index_M1.CSV'
df = load(path)
df = df[df.time >= '2020-01-01'].reset_index(drop=True)
rng = (df.high.values-df.low.values); rng_m = np.median(rng[rng>0]); pv = 0.1 if rng_m > 10 else (1.0 if rng_m > 100 else 0.01)
df = compute(df); df = detect(df, pv)
df = df.dropna(subset=['atr','rsi','ef','es']).reset_index(drop=True)
N = len(df)
print(f'N={N}')

fvg_dir = np.where(df['fvg_bull'].values, 1, np.where(df['fvg_bear'].values, -1, 0))
sig = np.zeros(N, dtype=np.int8)
ses = df.session.values
htf = df.htf.values
rsi_v = df.rsi.values
ddir = 1

# FVG
sig[(fvg_dir==1)&ses] = 1
print(f'Apres FVG: {np.count_nonzero(sig)}', flush=True)

# BOS fallback
bos_fb = (df['bos_bull'].values)&(~np.isin(fvg_dir,[1]))&ses
print(f'BOS fb candidates: {np.count_nonzero(bos_fb)}', flush=True)
sig[bos_fb] = 1
print(f'Apres BOS: {np.count_nonzero(sig)}', flush=True)

# RSI
rsi_ok = (rsi_v>22)&(rsi_v<78)
bad_count = np.count_nonzero(~rsi_ok)
print(f'RSI bad: {bad_count}, range={rsi_v.min():.1f}->{rsi_v.max():.1f}', flush=True)
sig[~rsi_ok] = 0
print(f'Apres RSI: {np.count_nonzero(sig)}', flush=True)

# HTF
htf_ok = (htf==ddir)
print(f'HTF ok for BUY: {np.count_nonzero(htf_ok)}', flush=True)
sig[~htf_ok] = 0
print(f'Apres HTF: {np.count_nonzero(sig)}', flush=True)

# Spike cooldown
spk = np.zeros(N, dtype=bool)
cd = 0
for i in range(N):
    if spk[i]: cd = 60
    if cd > 0:
        sig[i] = 0
        cd -= 1
print(f'Apres spike CD: {np.count_nonzero(sig)}', flush=True)
