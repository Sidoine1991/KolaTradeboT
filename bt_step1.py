"""Etape 1: charger CSV et verifier les dates."""
import pandas as pd
CSV_PATH = r"D:\Dev\TradBOT\data\XAUUSD_2010-2023.csv"
df = pd.read_csv(CSV_PATH, parse_dates=["time"])
print(f"Charge: {len(df):,} lignes | {df['time'].min()} -> {df['time'].max()}")
df20 = df[df["time"] >= "2020-01-01"].copy()
print(f"2020-2023: {len(df20):,} bougies")
df20.to_pickle(r"D:\Dev\TradBOT\df_xau_2020.pkl")
print("Pickle sauvegarde OK")
