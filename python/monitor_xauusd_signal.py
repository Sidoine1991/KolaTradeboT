#!/usr/bin/env python3
"""
Suivi XAUUSD BUY Signal — Verifie les TPs chaque heure
Utilise: python monitor_xauusd_signal.py [prix_actuel]
Exemple: python monitor_xauusd_signal.py 4345.50
"""
import sys
import json
from datetime import datetime
from pathlib import Path

# Signal
ENTRY1 = 4338
ENTRY2 = 4334
SL = 4226
TPS = [4342, 4346, 4350, 4354, 4358, 4362, 4368]
TP_LABELS = ["TP1", "TP2", "TP3", "TP4", "TP5", "TP6", "TP7"]

# Risks
RISK1 = ENTRY1 - SL  # 112 pips
RISK2 = ENTRY2 - SL  # 108 pips

def calculate_status(current_price, entry, sl, tps):
    """Calcule le statut du signal"""
    if current_price <= sl:
        return "SL HIT", -1, None

    # Trouver le TP le plus haut atteint
    hit_tp = None
    for i, tp in enumerate(tps):
        if current_price >= tp:
            hit_tp = i

    if hit_tp is not None:
        return "TP HIT", hit_tp, tps[hit_tp]

    # En cours
    distance_to_entry = current_price - entry
    return "IN PROGRESS", None, distance_to_entry


def monitor_signal(current_price_str):
    """Monitore le signal et affiche le statut"""
    try:
        current_price = float(current_price_str)
    except ValueError:
        print(f"[ERROR] Prix invalide: {current_price_str}")
        return

    print("\n" + "=" * 90)
    print(f"[SUIVI] XAUUSD BUY SIGNAL — {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print("=" * 90)

    print(f"\nPrix Actuel: {current_price:.2f}")
    print()

    # Verifier Entry 1 (4338)
    print("[ENTRY 1: 4338]")
    status1, tp_idx1, value1 = calculate_status(current_price, ENTRY1, SL, TPS)

    if status1 == "SL HIT":
        print(f"  Status: SL HIT [X]")
        print(f"  Loss: -{RISK1:.0f} pips (SL at {SL})")
        pnl1 = -RISK1
    elif status1 == "TP HIT":
        print(f"  Status: {TP_LABELS[tp_idx1]} HIT [OK]")
        print(f"  Profit: +{TPS[tp_idx1] - ENTRY1:.0f} pips")
        print(f"  RR: {(TPS[tp_idx1] - ENTRY1) / RISK1:.2f}x")
        pnl1 = TPS[tp_idx1] - ENTRY1
    else:
        print(f"  Status: IN PROGRESS [...]")
        print(f"  Distance to SL: {current_price - SL:.0f} pips")
        print(f"  Distance to entry: {value1:+.0f} pips")
        pnl1 = current_price - ENTRY1

    print()

    # Verifier Entry 2 (4334)
    print("[ENTRY 2: 4334]")
    status2, tp_idx2, value2 = calculate_status(current_price, ENTRY2, SL, TPS)

    if status2 == "SL HIT":
        print(f"  Status: SL HIT [X]")
        print(f"  Loss: -{RISK2:.0f} pips (SL at {SL})")
        pnl2 = -RISK2
    elif status2 == "TP HIT":
        print(f"  Status: {TP_LABELS[tp_idx2]} HIT [OK]")
        print(f"  Profit: +{TPS[tp_idx2] - ENTRY2:.0f} pips")
        print(f"  RR: {(TPS[tp_idx2] - ENTRY2) / RISK2:.2f}x")
        pnl2 = TPS[tp_idx2] - ENTRY2
    else:
        print(f"  Status: IN PROGRESS [...]")
        print(f"  Distance to SL: {current_price - SL:.0f} pips")
        print(f"  Distance to entry: {value2:+.0f} pips")
        pnl2 = current_price - ENTRY2

    print()
    print("=" * 90)
    print("[TP PROGRESSION]")
    print("-" * 90)

    for i, (tp, label) in enumerate(zip(TPS, TP_LABELS)):
        if current_price >= tp:
            print(f"  {label} ({tp}): [OK] HIT")
        elif current_price >= tp - 5:
            print(f"  {label} ({tp}): [NEAR] {tp - current_price:.2f} pips away")
        else:
            print(f"  {label} ({tp}): [...] {tp - current_price:.2f} pips away")

    print()
    print("=" * 90)
    print("[RESUME]")
    print("-" * 90)

    avg_pnl = (pnl1 + pnl2) / 2
    if avg_pnl > 0:
        avg_status = "GAGNANT [OK]"
    elif avg_pnl < -5:
        avg_status = "PERDANT [X]"
    else:
        avg_status = "NEUTRE [...]"

    print(f"  Entry 1 (4338): {pnl1:+.0f} pips")
    print(f"  Entry 2 (4334): {pnl2:+.0f} pips")
    print(f"  Moyenne: {avg_pnl:+.0f} pips — {avg_status}")
    print()

    # Sauvegarder le monitoring
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "current_price": current_price,
        "entry1_pnl": pnl1,
        "entry2_pnl": pnl2,
        "avg_pnl": avg_pnl,
        "status": avg_status,
        "tp_hit": tp_idx1 if status1 == "TP HIT" else (tp_idx2 if status2 == "TP HIT" else None),
    }

    log_file = Path(__file__).parent.parent / "logs" / "xauusd_signal_monitor.json"
    log_file.parent.mkdir(parents=True, exist_ok=True)

    existing = []
    if log_file.exists():
        try:
            existing = json.loads(log_file.read_text())
        except:
            pass

    existing.append(log_entry)
    log_file.write_text(json.dumps(existing, indent=2, ensure_ascii=False))

    print(f"  Log saved: {log_file}")
    print("=" * 90)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python monitor_xauusd_signal.py <prix_actuel>")
        print("Exemple: python monitor_xauusd_signal.py 4345.50")
        sys.exit(1)

    monitor_signal(sys.argv[1])
