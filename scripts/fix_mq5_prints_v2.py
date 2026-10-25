#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(r"d:\Dev\TradBOT")
PATH = ROOT / "mt5" / "SMC_Universal.mq5"


def main() -> None:
    # Ne PAS git checkout — conserve les correctifs ML/DOW de la session
    t = PATH.read_text(encoding="utf-8", errors="replace")

    # Exact broken literals commonly seen in the file (mojibake of UTF-8)
    exact = [
        ('Print("\u00f0\u0178\u201d\u00b4 SWING HIGH CONFIRM\u00c3\u2030 - Prix: "', 'Print("[SH] SWING HIGH CONFIRME - Prix: "'),
        ('Print("\u00f0\u0178\u201d\u00b5 SWING LOW CONFIRM\u00c3\u2030 - Prix: "', 'Print("[SL] SWING LOW CONFIRME - Prix: "'),
    ]

    # Regex: any Print containing these markers -> clean ASCII
    patterns: list[tuple[str, str]] = [
        (r'Print\("[^"]*SWING HIGH CONFIRM[^"]*Prix:\s*"', 'Print("[SH] SWING HIGH CONFIRME - Prix: "'),
        (r'Print\("[^"]*SWING LOW CONFIRM[^"]*Prix:\s*"', 'Print("[SL] SWING LOW CONFIRME - Prix: "'),
        (r'Print\("[^"]*SPIKE D[^"]{0,8}TECT[^"]{0,8}-\s*Barre\s*"', 'Print("[SPIKE] DETECTE - Barre "'),
        (r'Print\("[^"]*BOOM/CRASH - Mouvement moyen:\s*"', 'Print("[SPIKE] BOOM/CRASH - Mouvement moyen: "'),
        (r'Print\("[^"]*ENVOI IA:\s*"', 'Print("[AI] ENVOI: "'),
        (r'Print\("[^"]*R[^"]{0,6}PONSE IA:\s*"', 'Print("[AI] REPONSE: "'),
        (r'Print\("[^"]*ERREUR IA:\s*HTTP\s*"', 'Print("[AI] ERREUR HTTP "'),
        (r'Print\("[^"]*ERREUR IA[^"]{0,40}chec des deux serveurs:\s*"', 'Print("[AI] ERREUR - Echec des deux serveurs: "'),
        (r'Print\("[^"]*MARCH[^"]{0,6} NEUTRE:\s*"', 'Print("[MKT] NEUTRE: "'),
        (
            r'Print\("[^"]*ORDRE REJET[^"]*Connexion GOM indisponible[^"]*"\s*;',
            'Print("[REJECT] ORDRE - Connexion GOM indisponible - entrees bloquees");',
        ),
        (
            r'Print\("[^"]*ORDRE REJET[^"]*Filtre d.opportunit[^"]*"\s*;',
            'Print("[REJECT] ORDRE - Filtre opportunite - conditions defavorables");',
        ),
        (
            r'Print\("[^"]*MARKET BLOQU[^"]*verdict GOM courant WAIT"\s*;',
            'Print("[BLOCK] MARKET - ", symbol, " - verdict GOM courant WAIT");',
        ),
        (r"build=20261021-gomPass", "build=20261024-dowML"),
        (r"MARKET BLOQUE — ", "MARKET BLOQUE - "),
        (r" — GOM=WAIT", " - GOM=WAIT"),
        (r"GOOD exige LIMIT DOW", "GOOD exige LIMIT DOW"),
    ]

    n_total = 0
    for a, b in exact:
        c = t.count(a)
        if c:
            t = t.replace(a, b)
            n_total += c
            print("exact", c, b[:50])

    for pat, rep in patterns:
        t2, n = re.subn(pat, rep, t, flags=re.IGNORECASE)
        if n:
            print("re", n, rep[:60])
            t = t2
            n_total += n

    PATH.write_text(t, encoding="utf-8", newline="\n")
    print("total_replacements", n_total)
    for s in (
        "[SH] SWING HIGH CONFIRME",
        "[AI] ENVOI:",
        "[SPIKE] DETECTE",
        "build=20261024-dowML",
        "[SL] SWING LOW CONFIRME",
    ):
        print(("OK" if s in t else "MISSING"), s)


if __name__ == "__main__":
    main()
