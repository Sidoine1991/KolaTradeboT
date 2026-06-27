import pandas as pd
for sym in ["Boom 500", "Crash 1000", "Crash 500"]:
    df = pd.read_csv(rf"D:\Dev\TradBOT\Bomm & Crash Deriv\{sym} Index\{sym} Index_M1.CSV", sep=",", names=["date","hour","open","high","low","close","tick_volume"], skiprows=1)
    df["time"] = pd.to_datetime(df["date"] + " " + df["hour"], format="%Y.%m.%d %H:%M")
    yr = df[df["time"] >= "2020-01-01"]
    t = len(df)
    y = len(yr)
    print(f"{sym}: total={t} bougies | 2020+={y} bougies | {yr['time'].min().date()} -> {yr['time'].max().date()}")
