#!/usr/bin/env python3
from pathlib import Path

p = Path(r"d:\Dev\TradBOT\mt5\SMC_Universal.mq5")
t = p.read_text(encoding="utf-8", errors="replace")

reps = [
    ('Print("ðŸ“¦ ENVOI IA: "', 'Print("[AI] ENVOI: "'),
    ('Print("ðŸ“¥ RÃ‰PONSE IA: "', 'Print("[AI] REPONSE: "'),
    ('Print("âŒ ERREUR IA: HTTP "', 'Print("[AI] ERREUR HTTP "'),
    ('Print("ðŸ”´ SWING HIGH CONFIRMÃ‰ - Prix: "', 'Print("[SH] SWING HIGH CONFIRME - Prix: "'),
    ('Print("ðŸ”µ SWING LOW CONFIRMÃ‰ - Prix: "', 'Print("[SL] SWING LOW CONFIRME - Prix: "'),
    ('Print("ðŸš¨ SPIKE DÃ‰TECTÃ‰ - Barre "', 'Print("[SPIKE] DETECTE - Barre "'),
    ('Print("ðŸ“Š BOOM/CRASH - Mouvement moyen: "', 'Print("[SPIKE] BOOM/CRASH - Mouvement moyen: "'),
    ('Print("ðŸ“ˆ MARCHÃ‰ NEUTRE: "', 'Print("[MKT] NEUTRE: "'),
    (
        'Print("âŒ ORDRE REJETÃ‰ â€” Connexion GOM indisponible â€” Toutes entrÃ©es bloquÃ©es");',
        'Print("[REJECT] ORDRE - Connexion GOM indisponible - entrees bloquees");',
    ),
    ("build=20261021-gomPass", "build=20261024-dowML"),
]

n = 0
for a, b in reps:
    c = t.count(a)
    if c:
        t = t.replace(a, b)
        n += c
        print(c, "->", b[:70])
    else:
        # try already-partial ascii variants
        print("MISS", repr(a[:50]))

p.write_text(t, encoding="utf-8", newline="\n")
print("done", n)
for s in ("[SH] SWING HIGH", "[AI] ENVOI", "[SPIKE] DETECTE", "build=20261024", "SMC_PriceNearDowLevel"):
    print(("OK" if s in t else "NO"), s)
