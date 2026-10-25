#!/usr/bin/env python3
"""Scan Weltrade expert logs for overnight loss tickets (stream, no full load)."""
from __future__ import annotations

from pathlib import Path

LOGS = [
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261025.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261024.log"),
]

TICKETS = {
    "590825462",
    "590823949",
    "590815597",
    "590809381",
    "590806315",
    "590801029",
    "590794844",
    "590783921",
    "590774308",
    "590770446",
}

KEYWORDS = (
    "FERMETURE D",
    "DOW TOUCH",
    "DOW 1st",
    "STRAT-DOW",
    "MARKET BLOQUE",
    "Raison:",
    "POSITION OUVERTE",
    "SafeOrderSend",
    "LIMIT DOW",
    "GATE FINAL",
    "giveback",
    "7min",
    "WAIT auto",
    "Perte max",
    "SPIKE CAPT",
    "UNIFIED] tentative",
)

hits: dict[str, list[str]] = {t: [] for t in TICKETS}
closes: list[str] = []
entries: list[str] = []


def ascii(s: str) -> str:
    return "".join(ch if 32 <= ord(ch) < 127 else "?" for ch in s)


for log in LOGS:
    if not log.exists():
        print("missing", log)
        continue
    print("scanning", log.name, "bytes", log.stat().st_size)
    with log.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            # overnight window heuristic: 23:xx or 00:xx or 01:xx on Experts
            if "23:" not in line and " 00:" not in line and " 01:" not in line:
                # still catch tickets anytime
                if not any(t in line for t in TICKETS):
                    continue
            for t in TICKETS:
                if t in line:
                    if len(hits[t]) < 8:
                        hits[t].append(ascii(line.strip())[:240])
            low = line
            if "FERMETURE D" in low and ("PainX" in low or "GainX" in low or "Painx" in low or "Gainx" in low):
                if any(x in low for x in ("23:", " 00:", " 01:")):
                    closes.append(ascii(low.strip())[:260])
            if any(k in low for k in ("DOW TOUCH MARKET", "STRAT-DOW-LIMIT] ", "UNIFIED] tentative", "1st BOUNCE", "SPIKE MARKET")):
                if ("PainX 600" in low or "GainX 600" in low or "GainX 1200" in low) and any(
                    x in low for x in ("23:", " 00:", " 01:")
                ):
                    if len(entries) < 80:
                        entries.append(ascii(low.strip())[:260])

print("\n=== TICKET HITS ===")
for t, lines in hits.items():
    print(f"\n-- {t} ({len(lines)}) --")
    for L in lines:
        print(L)

print("\n=== CLOSES (PainX/GainX overnight) sample ===")
# dedupe by ticket substring
seen = set()
for L in closes:
    key = L
    for t in TICKETS:
        if t in L:
            key = t
            break
    if key in seen and key in TICKETS:
        continue
    if key in TICKETS:
        seen.add(key)
    print(L)

print("\n=== ENTRIES sample ===")
for L in entries[:40]:
    print(L)
