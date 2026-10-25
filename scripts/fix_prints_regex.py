#!/usr/bin/env python3
import re
from pathlib import Path

p = Path(r"d:\Dev\TradBOT\mt5\SMC_Universal.mq5")
t = p.read_text(encoding="utf-8", errors="replace")
patterns = [
    (r'Print\("[^"]*BOOM/CRASH - Mouvement moyen:\s*"', 'Print("[SPIKE] BOOM/CRASH - Mouvement moyen: "'),
    (r'Print\("[^"]*MARCH[^"]* NEUTRE:\s*"', 'Print("[MKT] NEUTRE: "'),
    (r'Print\("[^"]*SPIKE D[^"]*TECT[^"]*-\s*Direction:\s*"', 'Print("[SPIKE] DETECTE - Direction: "'),
]
n = 0
for pat, rep in patterns:
    t, c = re.subn(pat, rep, t)
    print(c, rep[:60])
    n += c
p.write_text(t, encoding="utf-8", newline="\n")
print("total", n)
