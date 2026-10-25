#!/usr/bin/env python3
"""Clean MT5 Journal prints: strip [EMOJI], fix mojibake accents to ASCII."""
from __future__ import annotations

from pathlib import Path

PATH = Path(r"d:\Dev\TradBOT\mt5\SMC_Universal.mq5")

# UTF-8 French mis-decoded as Latin-1/CP1252 then saved
MOJI = [
    ("CONFIRMÃ‰E", "CONFIRMEE"),
    ("CONFIRMÃ‰", "CONFIRME"),
    ("DÃ‰TECTÃ‰E", "DETECTEE"),
    ("DÃ‰TECTÃ‰", "DETECTE"),
    ("DÃ‰SACTIVÃ‰E", "DESACTIVEE"),
    ("DÃ‰SACTIVÃ‰", "DESACTIVE"),
    ("RÃ‰PONSE", "REPONSE"),
    ("RÃ‰ENTRÃ‰E", "REENTREE"),
    ("Ã‰CHEC", "ECHEC"),
    ("Ã‰chec", "Echec"),
    ("Ã‰puisement", "Epuisement"),
    ("Ã‰PUISEMENT", "EPUISEMENT"),
    ("PRÃ‰-SPIKE", "PRE-SPIKE"),
    ("PRÃ‰COCE", "PRECOCE"),
    ("CHAÃŽNE", "CHAINE"),
    ("complÃ¨te", "complete"),
    ("COMPLÃˆTE", "COMPLETE"),
    ("fermÃ©", "ferme"),
    ("FermÃ©", "Ferme"),
    ("FERMÃ‰", "FERME"),
    ("entrÃ©e", "entree"),
    ("EntrÃ©e", "Entree"),
    ("entrÃ©es", "entrees"),
    ("dÃ©jÃ ", "deja "),
    ("dÃ©jÃ", "deja"),
    ("Ã¢ge", "age"),
    ("Ã‚ge", "Age"),
    ("CatÃ©gorie", "Categorie"),
    ("appelÃ©e", "appelee"),
    ("DonnÃ©es", "Donnees"),
    ("gÃ©rÃ©", "gere"),
    ("protÃ©gÃ©", "protege"),
    ("annulÃ©", "annule"),
    ("ajustÃ©", "ajuste"),
    ("ajustÃ©s", "ajustes"),
    ("placÃ©", "place"),
    ("placÃ©s", "places"),
    ("dÃ©tectÃ©s", "detectes"),
    ("dÃ©tectÃ©", "detecte"),
    ("BLOQUÃ‰", "BLOQUE"),
    ("bloquÃ©", "bloque"),
    ("REJETÃ‰", "REJETE"),
    ("ACTIVÃ‰", "ACTIVE"),
    ("COUPÃ‰S", "COUPES"),
    ("changÃ©", "change"),
    ("APPLIQUÃ‰", "APPLIQUE"),
    ("insuffisante", "insuffisante"),
    ("insuffisant", "insuffisant"),
    ("sensibilitÃ©", "sensibilite"),
    ("mÃ©moire", "memoire"),
    ("mÃªme", "meme"),
    ("alignÃ©s", "alignes"),
    ("confirmÃ©", "confirme"),
    ("confirmÃ©es", "confirmees"),
    ("refusÃ©", "refuse"),
    ("rÃ©solue", "resolue"),
    ("SERRÃ‰S", "SERRES"),
    ("INVALIDE", "INVALIDE"),
    ("Ã©largi", "elargi"),
    ("Ãªtre", "etre"),
    ("prÃ©coce", "precoce"),
    ("Ã©viter", "eviter"),
    ("rÃ©alisÃ©", "realise"),
    ("immÃ©diate", "immediate"),
    ("immÃ©diat", "immediat"),
    ("dÃ¨s", "des"),
    ("Ã ", "a "),
    ("Ã©", "e"),
    ("Ã¨", "e"),
    ("Ãª", "e"),
    ("Ã«", "e"),
    ("Ã¡", "a"),
    ("Ã¢", "a"),
    ("Ã£", "a"),
    ("Ã¤", "a"),
    ("Ã§", "c"),
    ("Ã­", "i"),
    ("Ã®", "i"),
    ("Ã¯", "i"),
    ("Ã±", "n"),
    ("Ã³", "o"),
    ("Ã´", "o"),
    ("Ã¶", "o"),
    ("Ãº", "u"),
    ("Ã»", "u"),
    ("Ã¼", "u"),
    ("Ã‰", "E"),
    ("Ãˆ", "E"),
    ("ÃŠ", "E"),
    ("Ã€", "A"),
    ("Ã‡", "C"),
    ("ÃŽ", "I"),
    ("Ã”", "O"),
    ("Ã™", "U"),
    ("â€”", "-"),
    ("â€“", "-"),
    ("â€¦", "..."),
    ("â€™", "'"),
    ("â€˜", "'"),
    ("â€œ", '"'),
    ("â€", '"'),
    ("â†’", "->"),
    ("â†", "<-"),
    ("â‰¥", ">="),
    ("â‰¤", "<="),
    ("Â°", " deg"),
    ("Â ", " "),
    ("Â", ""),
]


def main() -> None:
    t = PATH.read_text(encoding="utf-8", errors="replace")
    n = 0

    # Specific high-visibility tags first
    tagged = [
        ('Print("[EMOJI] SWING HIGH CONFIRME - Prix: "', 'Print("[SH] SWING HIGH CONFIRME - Prix: "'),
        ('Print("[EMOJI] SWING HIGH CONFIRMÃ‰ - Prix: "', 'Print("[SH] SWING HIGH CONFIRME - Prix: "'),
        ('Print("[EMOJI] SWING LOW CONFIRMÃ‰ - Prix: "', 'Print("[SL] SWING LOW CONFIRME - Prix: "'),
        ('Print("[EMOJI] SWING LOW CONFIRME - Prix: "', 'Print("[SL] SWING LOW CONFIRME - Prix: "'),
        ('Print("[EMOJI] SPIKE DÃ‰TECTÃ‰ - Barre "', 'Print("[SPIKE] DETECTE - Barre "'),
        ('Print("[EMOJI] SPIKE DETECTE - Barre "', 'Print("[SPIKE] DETECTE - Barre "'),
        ('Print("[EMOJI] ENVOI IA: "', 'Print("[AI] ENVOI: "'),
        ('Print("[EMOJI] BOOM/CRASH - Mouvement moyen: "', 'Print("[SPIKE] BOOM/CRASH - Mouvement moyen: "'),
        ("build=20261021-gomPass", "build=20261024-dowML"),
        ("MARKET BLOQUE — ", "MARKET BLOQUE - "),
    ]
    for a, b in tagged:
        c = t.count(a)
        if c:
            t = t.replace(a, b)
            n += c
            print(f"tag {c}: {b[:60]}")

    for a, b in MOJI:
        c = t.count(a)
        if c:
            t = t.replace(a, b)
            n += c

    # Remaining [EMOJI] prefix in strings -> empty (keeps message readable)
    c = t.count("[EMOJI] ")
    if c:
        t = t.replace("[EMOJI] ", "")
        n += c
        print(f"strip [EMOJI] prefix: {c}")
    c = t.count("[EMOJI]")
    if c:
        t = t.replace("[EMOJI]", "")
        n += c
        print(f"strip [EMOJI] bare: {c}")

    PATH.write_text(t, encoding="utf-8", newline="\n")
    print("TOTAL ops", n)
    for s in (
        "[SH] SWING HIGH CONFIRME",
        "[AI] ENVOI:",
        "[SPIKE] DETECTE",
        "build=20261024-dowML",
        "[EMOJI]",
        "CONFIRMÃ‰",
        "Ã©",
    ):
        print(("STILL" if s in t else "clean"), repr(s))


if __name__ == "__main__":
    main()
