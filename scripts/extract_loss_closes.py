#!/usr/bin/env python3
from pathlib import Path

p = Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261025.log")

def ascii(s):
    return "".join(ch if 32 <= ord(ch) < 127 else "?" for ch in s)

seen = set()
with p.open("r", encoding="utf-16", errors="replace") as f:
    for line in f:
        if "FERMETURE D" not in line:
            continue
        if not any(s in line for s in ("PainX 600", "GainX 600", "GainX 1200", "GainX 400", "PainX 400")):
            continue
        # only 00:xx 01:xx early
        if not any(f"\t{h}" in line for h in ("00:", "01:", "02:", "03:")):
            continue
        if "Profit: -" not in line and "Profit: -" not in line:
            # keep negatives only
            if "Profit: -" not in line:
                # ascii might break minus? check raw
                if "Profit: -" not in line and "-2." not in line and "-1." not in line and "-3." not in line:
                    continue
        a = ascii(line.strip())
        if "Profit: -" not in a and "-2." not in a and "-1." not in a and "-3." not in a:
            continue
        # ticket key
        key = a
        if "Ticket:" in a:
            key = a.split("Ticket:")[1][:12]
        if key in seen:
            continue
        seen.add(key)
        print(a[:320])
print("count", len(seen))
