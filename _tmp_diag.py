import sys; sys.stdout.reconfigure(encoding='utf-8')
import warnings; warnings.filterwarnings('ignore')
import pandas as pd
import numpy as np

def load(path):
    df = pd.read_csv(path, sep=',', names=['date','hour','open','high','low','close','tick_volume'], skiprows=1)
    df['time'] = pd.to_datetime(df['date']+' '+df['hour'], format='%Y.%m.%d %H:%M')
    return df.drop(columns=['date','hour']).sort_values('time').reset_index(drop=True)

def prep(name, ddir):
    path = rf'D:\Dev\TradBOT\Bomm & Crash Deriv\{name} Index\{name} Index_M1.CSV'
    df = load(path)
    df = df[df.time >= '2020-01-01'].reset_index(drop=True)
    rng = (df.high.values-df.low.values); rng_m = np.median(rng[rng>0]); pv = 0.1 if rng_m > 10 else (1.0 if rng_m > 100 else 0.01)

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

    c = df.close.values; h = df.high.values; lw = df.low.values
    bull = np.empty_like(c); bear = np.empty_like(c)
    bull[:-1] = lw[1:]-h[:-1]; bull[-1]=0
    bear[:-1] = lw[:-1]-h[1:]; bear[-1]=0
    df['fvg_bull'] = (bull>=3.0*pv)&(bull>0)
    df['fvg_bear'] = (bear>=3.0*pv)&(bear>0)
    df['bos_bull'] = c > pd.Series(h).rolling(10,min_periods=10).max().shift(1).fillna(0).values
    df['bos_bear'] = c < pd.Series(lw).rolling(10,min_periods=10).min().shift(1).fillna(1e9).values
    df = df.dropna(subset=['atr','rsi','ef','es']).reset_index(drop=True)
    return df, ddir, pv

# Check each symbol
for name, ddir in [('Boom 1000',1),('Boom 500',1),('Crash 1000',-1),('Crash 500',-1)]:
    df, ddir, pv = prep(name, ddir)
    N = len(df)
    fvg_dir = np.where(df['fvg_bull'].values, 1, np.where(df['fvg_bear'].values, -1, 0))
    sig = np.zeros(N, dtype=np.int8)
    ses = np.ones(N, dtype=bool)
    htf = df['htf'].values
    rsi_v = df['rsi'].values

    if ddir > 0:
        sig[(fvg_dir==1)&ses] = 1
        sig[(df['bos_bull'].values)&(~np.isin(fvg_dir,[1]))&ses] = 1
    else:
        sig[(fvg_dir==-1)&ses] = -1
        sig[(df['bos_bear'].values)&(~np.isin(fvg_dir,[-1]))&ses] = -1

    rsi_ok = (rsi_v>22)&(rsi_v<78)
    sig[~rsi_ok] = 0
    sig[htf!=ddir] = 0

    print(f'{name} dir={ddir}: total_sig={np.count_nonzero(sig)}, rsi_in={rsi_ok.sum()}')

    # Show first few
    nz = np.nonzero(sig)[0]
    if len(nz)>0:
        for idx in nz[:2]:
            print(f'  first: i={idx} t={df.time.iat[idx]} c={df.close.iat[idx]:.2f} atr={df.atr.iat[idx]:.3f} htf={htf[idx]} rsi={rsi_v[idx]:.1f} fvg_dir={fvg_dir[idx]}')
    else:
        print(f'  NO SIGNALS - checking cascades...')
        fvg_ok = np.count_nonzero((fvg_dir==ddir)&ses)
        bos_ok = np.count_nonzero((df['bos_bull' if ddir>0 else 'bos_bear'].values)&(~np.isin(fvg_dir,[ddir]))&ses)
        rsi2 = np.count_nonzero(rsi_ok)
        htf2 = np.count_nonzero(htf==ddir)
        print(f'  FVG match={fvg_ok}, BOS fb={bos_ok}, RSIok={rsi2}, HTFok={htf2}')
