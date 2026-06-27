import sys; sys.stdout.reconfigure(encoding='utf-8')
import warnings; warnings.filterwarnings('ignore')
import pandas as pd, numpy as np

CAP=10000.0; RISK=0.3; SPD=0.1; SL_M=2.5; TP_M=3.0; ATR_P=14; EMA_F=20; EMA_S=50; RSI_P=14
path = r'D:\Dev\TradBOT\Bomm & Crash Deriv\Crash 500 Index\Crash 500 Index_M1.CSV'
df = pd.read_csv(path, sep=',', names=['date','hour','open','high','low','close','tick_volume'], skiprows=1)
df['time'] = pd.to_datetime(df['date']+' '+df['hour'], format='%Y.%m.%d %H:%M')
df = df[df.time >= '2020-01-01'].reset_index(drop=True)
rng = (df.high.values-df.low.values); pv = 0.1

df['atr'] = pd.concat([df.high-df.low,(df.high-df.close.shift()).abs(),(df.low-df.close.shift()).abs()],axis=1).max(axis=1).ewm(span=14, adjust=False).mean().values
df['ef'] = df.close.ewm(span=20, adjust=False).mean().values
df['eh'] = df.close.ewm(span=240, adjust=False).mean().values
df['htf'] = np.where(df.close.values > df['eh'].values, 1, -1)
d = df.close.diff()
g = d.where(d>0,0.0).ewm(alpha=1/14, min_periods=14, adjust=False).mean().values
lv = (-d).where(d<0,0.0).ewm(alpha=1/14, min_periods=14, adjust=False).mean().values
df['rsi'] = 100.0 - 100.0 / (1.0 + g / np.where(np.abs(lv)<1e-9,1e-9,lv))

c=df.close.values; h=df.high.values; lw=df.low.values
bull=np.empty_like(c); bear=np.empty_like(c); bull[:-1]=lw[1:]-h[:-1]; bull[-1]=0; bear[:-1]=lw[:-1]-h[1:]; bear[-1]=0
fvg_bear = (bear>=2.0*pv)&(bear>0)
df = df.dropna(subset=['atr','rsi','ef','es']).reset_index(drop=True)
c=df.close.values; h=df.high.values; lw=df.low.values
fvg_bear = fvg_bear[:len(df)]
htf = df['htf'].values; rsi_v = df['rsi'].values
fvg_dir = np.where(fvg_bear, -1, 0)
sig_base = np.zeros(len(df), dtype=np.int8)
ses = np.ones(len(df), dtype=bool)
sig_base[(fvg_dir==-1)&ses] = -1
sig_base[htf!=-1] = 0

# Spike cooldown
spk_ma = pd.Series(df['atr'].values).rolling(20, min_periods=1).mean().values
is_spike = df['atr'].values > spk_ma * 1.5

t_arr = df.time.values; px_arr = df.close.values; atr_v = df.atr.values
day_arr = np.array([str(t)[:10] for t in t_arr])

print("RSI_L  RSI_H  sig  trades   wr      pf      ret")
for rsi_l in [20,25,30,35]:
    for rsi_h in [65,70,75,80]:
        sig = sig_base.copy()
        rsi_ok = (rsi_v>rsi_l)&(rsi_v<rsi_h)
        sig[~rsi_ok] = 0
        cd=0
        for i in range(len(df)):
            if is_spike[i]: cd=20
            if cd>0: sig[i]=0; cd-=1
        nonz=np.nonzero(sig)[0]
        if len(nonz)==0: continue
        start_i=int(nonz[0])
        need=max(EMA_S+10, ATR_P+10, 250, start_i)
        equity=CAP; peak=CAP; mdd=0.0; d_pnl={}; entry_bar=-999; in_pos=False
        pos_side=''; pos_ebar=0; pos_etime=None; pos_entry=0.0; pos_sl=0.0; pos_tp=0.0; pos_sz=0.0
        trades=0; wins=0; gross_p=0.0; gross_l=0.0
        for i in range(need, len(df)):
            ts=t_arr[i]; px=px_arr[i]; atr=atr_v[i]
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
                    pos_side='SELL'; pos_ebar=i; pos_etime=ts; pos_entry=px
                    pos_sl=px+sl_d; pos_tp=px-tp_d; pos_sz=sz; in_pos=True; entry_bar=i
        if trades>0:
            wr=wins/trades*100
            pf=gross_p/abs(gross_l) if gross_l!=0 else 999
            ret=(equity-CAP)/CAP
            flag=' <-- BEST' if wr>=55 and trades>=200 and pf>=1.1 else ''
            print(f'  {rsi_l:2d}   {rsi_h:2d}   {np.count_nonzero(sig):4d}  {trades:5d}   {wr:5.1f}  {pf:6.2f}  {ret*100:+7.1f}%{flag}')
