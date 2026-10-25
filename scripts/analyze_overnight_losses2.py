#!/usr/bin/env python3
"""Broader overnight close/entry scan without ticket dependency."""
from pathlib import Path

paths = [
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261025.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261024.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\logs\20261025.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\logs\20261025.log"),
]

syms = ("PainX 600", "GainX 600", "GainX 1200", "painx 600", "gainx 600", "gainx 1200")
needles = (
    "FERMETURE D",
    "Raison:",
    "DOW TOUCH MARKET",
    "STRAT-DOW-LIMIT]",
    "STRAT-DOW-EP-MKT",
    "UNIFIED] tentative",
    "POSITION OUVERTE",
    "deal #",
    "order #",
    "done in",
)


def ascii(s: str) -> str:
    return "".join(ch if 32 <= ord(ch) < 127 else "?" for ch in s)


for path in paths:
    if not path.exists():
        print("SKIP", path)
        continue
    print("\n####", path, "size", path.stat().st_size)
    closes = []
    entries = []
    deals = []
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            # time window overnight broker/server: 23:50-01:30 appears as 23: or 00: or 01:
            if not any(t in line for t in ("23:5", "23:5", " 23:", "\t23:", " 00:", "\t00:", " 01:", "\t01:")):
                # also match HH:MM without leading space variants like 00:02:13
                if not (
                    "00:0" in line
                    or "00:1" in line
                    or "00:2" in line
                    or "00:3" in line
                    or "00:4" in line
                    or "00:5" in line
                    or "01:0" in line
                    or "01:1" in line
                    or "01:2" in line
                    or "23:5" in line
                ):
                    continue
            if not any(s in line for s in syms) and "5907" not in line and "5908" not in line:
                continue
            a = ascii(line.strip())
            if "FERMETURE" in line or "Raison:" in line:
                closes.append(a[:280])
            elif any(k in line for k in ("DOW TOUCH", "STRAT-DOW", "UNIFIED] tentative", "GATE FINAL", "BOUNCE")):
                entries.append(a[:280])
            elif any(k in line for k in ("deal", "order", "Buy", "Sell", "buy", "sell")) and (
                "5907" in line or "5908" in line
            ):
                deals.append(a[:280])

    print("closes", len(closes), "entries", len(entries), "deals", len(deals))
    print("-- closes sample --")
    for L in closes[:25]:
        print(L)
    print("-- entries sample --")
    for L in entries[:25]:
        print(L)
    print("-- deals sample --")
    for L in deals[:25]:
        print(L)
