import sys; sys.stdout.reconfigure(encoding='utf-8')
import warnings; warnings.filterwarnings('ignore')
import pandas as pd, numpy as np

CAP=10000.0; RISK=0.3; SPD=0.1; SL_M=2.5; TP_M=3.0; ATR_P=14; EMA_F=20; EMA_S=50; SPIKE_R=1.5; POST_SPK_B=20
path = r'D:\Dev\TradBOT\Bomm & Crash Deriv\Crash 500 Index\Crash 500 Index_M1.CSV'
df0 = pd.read_csv(path, sep=',', names=['date','hour','open','high','low','close','tick_volume'], skiprows=1)
df0['time'] = pd.to_datetime(df0['date']+' '+df0['hour'], format='%Y.%m.%d %H:%M')
df0 = df0[df0.time >= '2020-01-01'].reset_index(drop=True)
df0['atr'] = pd.concat([df0.high-df0.low,(df0.high-df0.close.shift()).abs(),(df0.low-df0.close.shift()).abs()],axis=1).max(axis=1).ewm(span=14, adjust=False).mean().values
df0['ef']  = df0.close.ewm(span=20, adjust=False).mean().values
df0['es']  = df0.close.ewm(span=50, adjust=False).mean().values
df0['eh']  = df0.close.ewm(span=240, adjust=False).mean().values
df0['htf'] = np.where(df0.close.values > df0['eh'].values, 1, -1)
d = df0.close.diff()
g = d.where(d>0,0.0).ewm(alpha=1/14, min_periods=14, adjust=False).mean().values
lv = (-d).where(d<0,0.0).ewm(alpha=1/14, min_periods=14, adjust=False).mean().values
df0['rsi'] = 100.0 - 100.0 / (1.0 + g / np.where(np.abs(lv)<1e-9, 1e-9, lv))

c=df0.close.values; lw=df0.low.values
bear=np.empty_like(c); bear[:-1]=lw[:-1]-c[1:]; bear[-1]=0
pv=0.1; fvg_bear=(bear>=2.0*pv)&(bear>0)
bos_se = c < pd.Series(lw).rolling(10,min_periods=10).min().shift(1).fillna(1e9).values

df = df0.dropna(subset=['atr','rsi','ef','es']).reset_index(drop=True)
c=df.close.values; lw=df.low.values
fvg_bear2=fvg_bear[:len(df)]
bos_se2=bos_se[:len(df)]
htf=df['htf'].values; rsi_v=df['rsi'].values; ef_v=df['ef'].values; es_v=df['es'].values

t_arr=df.time.values; px_arr=df.close.values; atr_v=df.atr.values
day_arr=np.array([str(t)[:10] for t in t_arr])

print("Mode           RSI     sig trades   WR     PF    Ret")
for mode in ['fvg+bos+htf', 'fvg+bos+htf+trend', 'fvg+bos+htf+htf_trend',
             'bOS only', 'FVG only', 'BOS+HTF+EMAfast', 'BOS+HTF+EMAslow']:
    if mode=='fvg+bos+htf':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(fvg_bear2)&ses]=-1; sig[(bos_se2)&(~np.isin(np.where(fvg_bear2,-1,0),[-1]))&ses]=-1
    elif mode=='fvg+bos+htf+trend':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(fvg_bear2)&ses]=-1; sig[(bos_se2)&(~np.isin(np.where(fvg_bear2,-1,0),[-1]))&ses]=-1
        sig[htf!=-1]=0; sig[c>=ef_v]=0  # close must be below EMA fast
    elif mode=='fvg+bos+htf+htf_trend':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(fvg_bear2)&ses]=-1; sig[(bos_se2)&(~np.isin(np.where(fvg_bear2,-1,0),[-1]))&ses]=-1
        sig[htf!=-1]=0  # already in HTF=-1
    elif mode=='bOS only':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(bos_se2)&ses]=-1; sig[htf!=-1]=0
    elif mode=='FVG only':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(fvg_bear2)&ses]=-1; sig[htf!=-1]=0
    elif mode=='BOS+HTF+EMAfast':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(bos_se2)&ses]=-1; sig[htf!=-1]=0; sig[c>=ef_v]=0
    elif mode=='BOS+HTF+EMAslow':
        sig=np.zeros(len(df),dtype=np.int8); ses=np.ones(len(df),dtype=bool)
        sig[(bos_se2)&ses]=-1; sig[htf!=-1]=0; sig[c>=es_v]=0

    spk_ma=pd.Series(df['atr'].values).rolling(20,min_periods=1).mean().values
    is_spike=df['atr'].values>spk_ma*SPIKE_R
    cd=0
    for i in range(len(df)):
        if is_spike[i]: cd=POST_SPK_B
        if cd>0: sig[i]=0; cd-=1

    nonz=np.nonzero(sig)[0]
    if len(nonz)==0: continue
    need=max(EMA_S+10, ATR_P+10, 250, int(nonz[0]))
    equity=CAP; peak=CAP; mdd=0.0; d_pnl={}; entry_bar=-999; in_pos=False
    pos_entry=0.0; pos_sl=0.0; pos_tp=0.0; pos_sz=0.0
    trades=0; wins=0; gross_p=0.0; gross_l=0.0
    for i in range(need, len(df)):
        px=px_arr[i]; atr=atr_v[i]
        if equity>peak: peak=equity
        dd_h=(peak-equity)/peak*100
        if dd_h>mdd: mdd=dd_h
        day=day_arr[i]
        if day in d_pnl and d_pnl[day]<=-CAP*3/100:
            if in_pos: in_pos=False
            continue
        if in_pos:
            pnl=(pos_entry-px)*pos_sz-SPD*pos_sz
            if px<=pos_sl or px>=pos_tp or pnl>=0.80*(CAP/10000.0):
                equity+=pnl; d_pnl[day]=d_pnl.get(day,0.0)+pnl
                if pnl>0: wins+=1; gross_p+=pnl
                else: gross_l+=pnl
                trades+=1; in_pos=False; entry_bar=i
            continue
        if (not in_pos) and (i-entry_bar)>=1 and sig[i]==-1:
            a=atr if (not np.isnan(atr) and atr>0) else 0.3
            sl_d=SL_M*a; tp_d=TP_M*sl_d
            if sl_d>0:
                sz=round(min(max((equity*RISK/100)/sl_d,0.01),10.0),2)
                pos_entry=px; pos_sl=px+sl_d; pos_tp=px-tp_d; pos_sz=sz; in_pos=True; entry_bar=i
    if trades>0:
        wr=wins/trades*100; pf=gross_p/abs(gross_l) if gross_l!=0 else 999
        ret=(equity-CAP)/CAP
        flag=' <-- BEST' if wr>=50 and trades>=300 else ''
        print(f'  {mode:30s}  {np.count_nonzero(sig):4d}  {trades:5d}  {wr:5.1f}  {pf:6.2f}  {ret*100:+7.1f}%{flag}')
