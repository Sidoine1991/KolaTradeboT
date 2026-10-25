#!/usr/bin/env python3
"""
Analyse du journal SMC_TradeJournal.csv écrit par SMC_Universal.mq5 (v1.35).

Usage :
    python analyze_journal.py [chemin_du_csv] [--min N]

Par défaut cherche SMC_TradeJournal.csv dans le dossier courant, puis dans
%APPDATA%\\MetaQuotes\\Terminal\\Common\\Files.

Objectif : arrêter de deviner. Pour chaque axe (symbole, stratégie, heure,
verdict GOM, alignement des timeframes, ER, spread...) on affiche le nombre de
trades, le taux de réussite, l'espérance par trade et le facteur de profit.
En dessous de --min trades (défaut 15) un groupe est marqué « peu fiable » :
ne rien conclure sur si peu de trades.
"""
import csv
import os
import statistics as st
import sys
from collections import defaultdict


def find_csv(argv):
    for a in argv:
        if not a.startswith("--") and a.lower().endswith(".csv"):
            return a
    if os.path.exists("SMC_TradeJournal.csv"):
        return "SMC_TradeJournal.csv"
    appdata = os.environ.get("APPDATA", "")
    p = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "SMC_TradeJournal.csv")
    return p if os.path.exists(p) else None


def f(x, default=0.0):
    try:
        return float(str(x).replace(",", "."))
    except (TypeError, ValueError):
        return default


def load(path):
    rows = []
    with open(path, newline="", encoding="utf-8", errors="replace") as fh:
        for r in csv.DictReader(fh, delimiter=";"):
            if not r.get("symbol"):
                continue
            r["_profit"] = f(r.get("profit"))
            r["_mfe"] = f(r.get("mfe"))
            r["_mae"] = f(r.get("mae"))
            r["_dur"] = f(r.get("duration_s"))
            r["_er"] = f(r.get("er20"), -1)
            r["_spread"] = f(r.get("spread_pts"), -1)
            r["_vn"] = int(f(r.get("gom_vn"), 0))
            rows.append(r)
    return rows


def stats(rows):
    n = len(rows)
    if n == 0:
        return None
    wins = [r["_profit"] for r in rows if r["_profit"] > 0.05]
    losses = [r["_profit"] for r in rows if r["_profit"] < -0.05]
    be = n - len(wins) - len(losses)
    gp, gl = sum(wins), -sum(losses)
    total = sum(r["_profit"] for r in rows)
    decided = len(wins) + len(losses)
    return {
        "n": n,
        "win%": (100.0 * len(wins) / decided) if decided else 0.0,
        "avg_win": (gp / len(wins)) if wins else 0.0,
        "avg_loss": (-gl / len(losses)) if losses else 0.0,
        "be": be,
        "exp": total / n,
        "pf": (gp / gl) if gl > 0 else float("inf") if gp > 0 else 0.0,
        "total": total,
    }


def line(label, s, min_n):
    flag = "" if s["n"] >= min_n else "  (peu fiable)"
    pf = "inf" if s["pf"] == float("inf") else f"{s['pf']:.2f}"
    return (f"  {label:<26} n={s['n']:<4} win={s['win%']:5.1f}%  "
            f"gain moy={s['avg_win']:+.2f}  perte moy={s['avg_loss']:+.2f}  "
            f"esp={s['exp']:+.3f}  PF={pf:<5} total={s['total']:+.2f}{flag}")


def group(rows, keyfn, title, min_n, sort_by_exp=True):
    g = defaultdict(list)
    for r in rows:
        k = keyfn(r)
        if k is not None:
            g[k].append(r)
    if not g:
        return
    print(f"\n── {title}")
    items = [(k, stats(v)) for k, v in g.items()]
    items.sort(key=lambda kv: (-kv[1]["exp"]) if sort_by_exp else kv[0])
    for k, s in items:
        print(line(str(k), s, min_n))


def aligned_count(r):
    side = r.get("side", "")
    want = "BULL" if side == "BUY" else "BEAR"
    tfs = [r.get("tf_m1", ""), r.get("tf_m5", ""), r.get("tf_m15", ""), r.get("tf_h1", "")]
    known = [t for t in tfs if t]
    if not known:
        return None
    return sum(1 for t in known if t.upper() == want)


def er_bucket(r):
    er = r["_er"]
    if er < 0:
        return None
    return "ER <0.20 (range)" if er < 0.20 else ("ER 0.20-0.35" if er < 0.35 else "ER >=0.35 (tendance)")


def spread_bucket(r):
    sp, sl0, en = r["_spread"], f(r.get("sl0")), f(r.get("entry"))
    if sp < 0:
        return None
    return f"spread {int(sp // 2) * 2}-{int(sp // 2) * 2 + 1} pts"


def hour_key(r):
    t = r.get("open_time", "")
    return t[11:13] + "h" if len(t) >= 13 else None


def main():
    argv = sys.argv[1:]
    min_n = 15
    if "--min" in argv:
        min_n = int(argv[argv.index("--min") + 1])
    path = find_csv(argv)
    if not path:
        print("CSV introuvable. Lance : python analyze_journal.py chemin\\SMC_TradeJournal.csv")
        return 1
    rows = load(path)
    print(f"Fichier : {path}  —  {len(rows)} trades")
    if not rows:
        return 0

    tot = stats(rows)
    print("\n══ GLOBAL")
    print(line("tous les trades", tot, min_n))
    if tot["n"] < 100:
        print(f"  ⚠ {tot['n']} trades : trop peu pour conclure. Vise 100+ trades par réglage testé.")

    group(rows, lambda r: r["symbol"], "PAR SYMBOLE", min_n)
    group(rows, lambda r: r.get("comment", "").split("|")[0][:26] or "(sans tag)", "PAR TAG D'ENTRÉE", min_n)
    group(rows, lambda r: r.get("side"), "PAR SENS", min_n)
    group(rows, lambda r: r.get("reason"), "PAR RAISON DE SORTIE", min_n)
    group(rows, lambda r: hour_key(r), "PAR HEURE D'OUVERTURE (heure serveur)", min_n, sort_by_exp=False)
    group(rows, lambda r: f"vn={r['_vn']:+d}", "PAR VERDICT GOM À L'ENTRÉE", min_n)
    group(rows, lambda r: (lambda a: None if a is None else f"{a}/4 TF alignées")(aligned_count(r)),
          "PAR ALIGNEMENT DES TIMEFRAMES (M1,M5,M15,H1)", min_n)
    group(rows, er_bucket, "PAR ER (EFFICACITÉ) À L'ENTRÉE", min_n)
    group(rows, spread_bucket, "PAR SPREAD À L'ENTRÉE", min_n, sort_by_exp=False)

    # ── MFE / MAE : la question « attendre d'être en profit »
    wins = [r for r in rows if r["_profit"] > 0.05]
    losses = [r for r in rows if r["_profit"] < -0.05]
    print("\n══ MFE / MAE (gain max et perte max latents pendant le trade)")
    if wins:
        print(f"  Gagnants : perte latente max avant de gagner — médiane {st.median(r['_mae'] for r in wins):+.2f}, "
              f"pire {min(r['_mae'] for r in wins):+.2f}")
        print(f"             gain final / gain max atteint    — médiane "
              f"{st.median(r['_profit'] / r['_mfe'] for r in wins if r['_mfe'] > 0):.0%} (100% = sortie au sommet)")
    if losses:
        avg_win = st.mean(r["_profit"] for r in wins) if wins else 0.0
        touched = [r for r in losses if avg_win > 0 and r["_mfe"] >= 0.5 * avg_win]
        print(f"  Perdants : gain latent max avant de perdre  — médiane {st.median(r['_mfe'] for r in losses):+.2f}")
        if avg_win > 0:
            print(f"             {len(touched)}/{len(losses)} perdants ({100 * len(touched) / len(losses):.0f}%) avaient atteint "
                  f"au moins la moitié d'un gain moyen ({0.5 * avg_win:+.2f}).")
            if len(touched) / len(losses) >= 0.4:
                print("             → beaucoup de perdants étaient en profit : un break-even / trailing plus tôt aurait aidé.")
            else:
                print("             → peu de perdants passent par un profit : le problème est l'ENTRÉE, pas la sortie.")
    if wins and losses:
        dur_w = st.median(r["_dur"] for r in wins)
        dur_l = st.median(r["_dur"] for r in losses)
        print(f"  Durée médiane : gagnants {dur_w:.0f}s, perdants {dur_l:.0f}s"
              + ("  → les perdants traînent plus que les gagnants." if dur_l > 1.5 * dur_w else ""))

    print("\nLecture : cherche les groupes avec esp > 0 ET n >= "
          f"{min_n}. Coupe ce qui a une espérance négative, garde ce qui marche, et re-mesure.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
