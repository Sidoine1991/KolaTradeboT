#!/usr/bin/env python3
"""One-shot diagnosis: pending orders vs GOM verdicts."""
import json
import urllib.error
import urllib.request
from collections import Counter
from urllib.parse import quote

BASE = "http://127.0.0.1:8000"


def get(path: str):
    with urllib.request.urlopen(BASE + path, timeout=20) as r:
        return json.load(r)


def main():
    pause = get("/trading-pause")
    pending = get("/pending-orders")
    bulk = get("/gom-verdicts")
    items = bulk.get("verdicts") or []
    print("pause_active", pause.get("active"))
    print("pending_count", pending.get("count"), "orders", pending.get("orders"))
    print("gom_count", bulk.get("count"), "live", bulk.get("live_count"), "stale_skipped", bulk.get("stale_skipped"))
    print("verdict_hist", dict(Counter(str(x.get("verdict")) for x in items)))
    print("symbols", [x.get("symbol") for x in items])
    syn_keys = ("GAIN", "PAIN", "FXVOL", "VOL", "BOOM", "CRASH", "FLIP", "QUAD")
    syn = [s for s in (x.get("symbol") or "" for x in items) if any(k in s.upper() for k in syn_keys)]
    print("synthetics_live", syn)

    for want in ["GBPUSD.C", "EURNZD.C", "GainX 999", "FX Vol 20"]:
        try:
            v = get("/gom-verdict?symbol=" + quote(want))
            m1, m5, m15 = v.get("tf_m1_dir"), v.get("tf_m5_dir"), v.get("tf_m15_dir")
            h1, h4, d1 = v.get("tf_h1_dir"), v.get("tf_h4_dir"), v.get("tf_d1_dir")
            vn = int(v.get("verdict_num") or 0)
            direction = "BUY" if vn > 0 else ("SELL" if vn < 0 else "WAIT")
            side = "BULL" if direction == "BUY" else ("BEAR" if direction == "SELL" else "NEUT")
            tfs = [m1, m5, m15, h1, h4, d1]
            aligned_m1m5 = (
                (direction == "BUY" and str(m1).upper() in ("BULL", "BUY") and str(m5).upper() in ("BULL", "BUY"))
                or (direction == "SELL" and str(m1).upper() in ("BEAR", "SELL") and str(m5).upper() in ("BEAR", "SELL"))
            )
            count_side = sum(1 for d in tfs if str(d).upper() in (side, direction))
            print(
                f"--- {want} vn={vn} {v.get('verdict')} gate={v.get('gate')} "
                f"m1={m1} m5={m5} m15={m15} h1={h1} h4={h4} d1={d1} "
                f"price={v.get('price') or v.get('entry')} atr={v.get('atr')} "
                f"m1m5_aligned={aligned_m1m5} mtf_{count_side}/6"
            )
        except Exception as exc:
            print(f"--- {want} ERR {exc}")


if __name__ == "__main__":
    main()
