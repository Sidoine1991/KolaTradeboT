"""
Export de l'historique des trades MT5 (un trade = une position ouverte puis fermée).
Produit :
  - trades_history.csv : un trade par ligne, avec prix d'entrée/sortie, durée,
    résultat net, MFE/MAE (excursions) calculées sur les bougies M1.
  - deals_raw.csv      : toutes les transactions brutes (utile en cas de doute).

Usage :
  python export_trades.py --start 2026-09-01 --end 2026-10-17
  python export_trades.py --magic 123456      # filtrer sur le magic number de l'EA
"""
import argparse
from datetime import datetime, timedelta

import MetaTrader5 as mt5
import pandas as pd

DEAL_TYPE = {0: "BUY", 1: "SELL"}
DEAL_ENTRY = {0: "IN", 1: "OUT", 2: "INOUT", 3: "OUT_BY"}
DEAL_REASON = {
    0: "CLIENT", 1: "MOBILE", 2: "WEB", 3: "EXPERT",
    4: "SL", 5: "TP", 6: "STOP_OUT", 7: "ROLLOVER", 8: "VMARGIN", 9: "SPLIT",
}


def compute_excursions(symbol, side, open_time, close_time, open_price):
    """MFE/MAE en unités de prix, à partir des bougies M1 entre ouverture et fermeture."""
    rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, open_time, close_time)
    if rates is None or len(rates) == 0:
        return None, None
    highs, lows = rates["high"], rates["low"]
    if side == "BUY":
        mfe = float(highs.max() - open_price)
        mae = float(open_price - lows.min())
    else:
        mfe = float(open_price - lows.min())
        mae = float(highs.max() - open_price)
    return round(max(mfe, 0.0), 5), round(max(mae, 0.0), 5)


def main():
    parser = argparse.ArgumentParser()
    default_start = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")
    parser.add_argument("--start", default=default_start, help="AAAA-MM-JJ")
    parser.add_argument("--end", default=datetime.now().strftime("%Y-%m-%d"), help="AAAA-MM-JJ")
    parser.add_argument("--magic", type=int, default=None, help="Filtrer sur le magic number de l'EA")
    parser.add_argument("--no-excursions", action="store_true", help="Ne pas calculer MFE/MAE (plus rapide)")
    args = parser.parse_args()

    if not mt5.initialize():
        print("Échec de connexion à MT5 :", mt5.last_error())
        return

    start = datetime.strptime(args.start, "%Y-%m-%d")
    end = datetime.strptime(args.end, "%Y-%m-%d") + timedelta(days=1)
    deals = mt5.history_deals_get(start, end)
    if deals is None or len(deals) == 0:
        print("Aucune transaction trouvée sur cette période :", mt5.last_error())
        mt5.shutdown()
        return

    raw = pd.DataFrame([d._asdict() for d in deals])
    if args.magic is not None:
        raw = raw[raw["magic"] == args.magic]

    # Transactions de trading uniquement (exclut dépôts, crédits, etc. : type 0 = BUY, 1 = SELL)
    raw = raw[raw["type"].isin([0, 1])].copy()
    raw["time"] = pd.to_datetime(raw["time"], unit="s")
    raw.to_csv("deals_raw.csv", index=False)

    trades = []
    for pos_id, grp in raw.groupby("position_id"):
        grp = grp.sort_values("time")
        ins = grp[grp["entry"] == 0]
        outs = grp[grp["entry"].isin([1, 3])]
        if ins.empty or outs.empty:
            continue  # position encore ouverte ou données incomplètes
        entry, exit_ = ins.iloc[0], outs.iloc[-1]
        side = DEAL_TYPE[int(entry["type"])]
        symbol = entry["symbol"]
        open_time, close_time = entry["time"], exit_["time"]
        open_price, close_price = float(entry["price"]), float(exit_["price"])

        mfe = mae = None
        if not args.no_excursions:
            mfe, mae = compute_excursions(
                symbol, side,
                open_time.to_pydatetime(), close_time.to_pydatetime(), open_price,
            )

        net = float(grp["profit"].sum() + grp["swap"].sum() + grp["commission"].sum())
        trades.append({
            "position_id": pos_id,
            "symbol": symbol,
            "side": side,
            "volume": float(entry["volume"]),
            "open_time": open_time,
            "open_price": open_price,
            "close_time": close_time,
            "close_price": close_price,
            "duration_min": round((close_time - open_time).total_seconds() / 60, 1),
            "exit_reason": DEAL_REASON.get(int(exit_["reason"]), str(exit_["reason"])),
            "gross_profit": round(float(grp["profit"].sum()), 2),
            "swap": round(float(grp["swap"].sum()), 2),
            "commission": round(float(grp["commission"].sum()), 2),
            "net_profit": round(net, 2),
            "mfe_price": mfe,
            "mae_price": mae,
            "magic": int(entry["magic"]),
            "entry_comment": entry["comment"],
            "exit_comment": exit_["comment"],
        })

    if not trades:
        print("Aucun trade clôturé trouvé.")
    else:
        df = pd.DataFrame(trades).sort_values("open_time")
        df.to_csv("trades_history.csv", index=False)
        wins = (df["net_profit"] > 0).sum()
        print(f"{len(df)} trades exportés -> trades_history.csv")
        print(f"Gagnants : {wins} | Perdants : {len(df) - wins} | Net total : {df['net_profit'].sum():.2f}")
        print("Transactions brutes -> deals_raw.csv")

    mt5.shutdown()


if __name__ == "__main__":
    main()