#!/usr/bin/env python3
"""Analyze overnight PainX/GainX losses from UTF-16 MT5 expert logs."""
from __future__ import annotations

from pathlib import Path

LOG = Path(
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261025.log"
)
LOG24 = Path(
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\logs\20261024.log"
)


def ascii(s: str) -> str:
    return "".join(ch if 32 <= ord(ch) < 127 else "?" for ch in s)


def in_window(line: str) -> bool:
    # Experts timestamp is like: XX\t0\tHH:MM:SS.mmm\t
    # overnight: 23:50-01:30
    for h in ("23:5", "23:5", "00:0", "00:1", "00:2", "00:3", "00:4", "00:5", "01:0", "01:1", "01:2"):
        if f"\t{h}" in line or f" {h}" in line:
            return True
    return False


def interesting_sym(line: str) -> bool:
    return any(
        s in line
        for s in (
            "PainX 600",
            "GainX 600",
            "GainX 1200",
            "PainX 400",
            "GainX 400",
        )
    )


def scan(path: Path, label: str) -> None:
    if not path.exists():
        print("missing", path)
        return
    print(f"\n==== {label} {path.name} ====")
    closes = []
    entries = []
    blocks = []
    with path.open("r", encoding="utf-16", errors="replace") as f:
        for line in f:
            if not in_window(line):
                continue
            if not interesting_sym(line) and "ticket=" not in line.lower():
                # still keep FERMETURE lines that mention those syms in message body
                if not any(s in line for s in ("PainX 600", "GainX 600", "GainX 1200")):
                    continue
            a = ascii(line.rstrip())
            if "FERMETURE" in line or "Raison:" in line or "TENTATIVE FERMETURE" in line:
                closes.append(a[:300])
            elif any(
                k in line
                for k in (
                    "DOW TOUCH MARKET",
                    "DOW 1st",
                    "STRAT-DOW-LIMIT]",
                    "STRAT-DOW-EP-MKT",
                    "UNIFIED] tentative",
                    "GATE FINAL",
                    "POSITION OUVERTE",
                    "done (",
                    "market buy",
                    "market sell",
                    "buy limit",
                    "sell limit",
                )
            ):
                entries.append(a[:300])
            elif any(
                k in line
                for k in (
                    "MARKET BLOQUE",
                    "CORRECTION",
                    "refus:",
                    "giveback",
                    "7min",
                    "Perte max",
                    "WAIT auto",
                    "EXIT-GATE",
                )
            ):
                if len(blocks) < 60:
                    blocks.append(a[:300])

    # Deduplicate FERMETURE by ticket id if present
    print(f"closes={len(closes)} entries={len(entries)} blocks={len(blocks)}")
    print("\n-- CLOSES (dedup) --")
    seen = set()
    for L in closes:
        key = L
        if "ticket=" in L:
            key = L.split("ticket=")[-1][:12]
        elif "Ticket:" in L:
            key = L.split("Ticket:")[-1][:15]
        if key in seen:
            continue
        seen.add(key)
        print(L)

    print("\n-- ENTRIES --")
    for L in entries[:50]:
        print(L)

    print("\n-- BLOCKS/EXITS --")
    for L in blocks[:40]:
        print(L)


scan(LOG, "today")
# late night may still be end of 24th file
print("\n(scanning last part of 20261024 for 23:5x only)")
if LOG24.exists():
    closes = []
    entries = []
    with LOG24.open("r", encoding="utf-16", errors="replace") as f:
        # seek near end: read last ~30MB worth by skipping
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 40_000_000), 0)
        f.readline()  # sync
        for line in f:
            if "\t23:5" not in line and "\t23:5" not in line:
                if not (line.find("\t23:") >= 0 and any(x in line[line.find("\t23:") : line.find("\t23:") + 6] for x in ("23:5", "23:5"))):
                    # accept any 23:5x
                    idx = line.find("\t23:")
                    if idx < 0 or not line[idx + 1 : idx + 5].startswith("23:5"):
                        continue
            if not any(s in line for s in ("PainX 600", "GainX 600", "GainX 1200")):
                continue
            a = ascii(line.rstrip())
            if "FERMETURE" in line or "Raison:" in line:
                closes.append(a[:300])
            elif any(k in line for k in ("DOW TOUCH", "STRAT-DOW", "UNIFIED] tentative", "GATE FINAL")):
                entries.append(a[:300])
    print("night24 closes", len(closes), "entries", len(entries))
    seen = set()
    for L in closes:
        key = L[50:120]
        if key in seen:
            continue
        seen.add(key)
        print(L)
    for L in entries[:30]:
        print(L)
