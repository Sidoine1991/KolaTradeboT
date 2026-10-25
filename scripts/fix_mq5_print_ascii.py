#!/usr/bin/env python3
"""Sanitize mojibake + non-ASCII in MQL5 Print/Comment strings for MT5 Journal."""
from __future__ import annotations

import re
import unicodedata
from pathlib import Path

PATH = Path(r"d:\Dev\TradBOT\mt5\SMC_Universal.mq5")

EMOJI_MAP = {
    "🔴": "[SH]",
    "🔵": "[SL]",
    "📦": "[AI]",
    "📥": "[AI]",
    "❌": "[ERR]",
    "✅": "[OK]",
    "🚨": "[SPIKE]",
    "📊": "[INFO]",
    "📈": "[MKT]",
    "🔎": "[DBG]",
    "🚀": "[GO]",
    "🎯": "[HIT]",
    "⚠️": "[WARN]",
    "⚠": "[WARN]",
    "⏳": "[WAIT]",
    "🚫": "[BLOCK]",
    "🔒": "[LOCK]",
    "⚡": "[FAST]",
    "🛡️": "[PROT]",
    "🛡": "[PROT]",
    "⏰": "[TIME]",
    "🖼️": "[VP]",
    "🖼": "[VP]",
    "🔗": "[CHAIN]",
    "🔄": "[SYNC]",
    "ℹ️": "[INFO]",
    "ℹ": "[INFO]",
    "⛔": "[STOP]",
    "🟢": "[G]",
    "🟡": "[Y]",
    "⚪": "[W]",
    "🧠": "[ML]",
    "💡": "[TIP]",
    "🔥": "[HOT]",
    "💥": "[BOOM]",
    "📌": "[PIN]",
}


def try_fix_mojibake(s: str) -> str:
    try:
        fixed = s.encode("latin-1").decode("utf-8")
        markers = ("Ã", "Â", "ðŸ", "â")
        if any(m in s for m in markers) and sum(fixed.count(m) for m in markers) < sum(
            s.count(m) for m in markers
        ):
            return fixed
    except Exception:
        pass
    return s


def strip_accents(s: str) -> str:
    nk = unicodedata.normalize("NFKD", s)
    return "".join(c for c in nk if not unicodedata.combining(c))


def ascii_safe(s: str) -> str:
    for k, v in EMOJI_MAP.items():
        s = s.replace(k, v)
    s = re.sub(r"[\U0001F000-\U0001FAFF\U00002700-\U000027BF\U00002600-\U000026FF]", "", s)
    s = strip_accents(s)
    for a, b in [
        ("—", "-"),
        ("–", "-"),
        ("…", "..."),
        ("’", "'"),
        ("‘", "'"),
        ("“", '"'),
        ("”", '"'),
        ("→", "->"),
        ("←", "<-"),
        ("⇒", "=>"),
        ("•", "*"),
        ("œ", "oe"),
        ("Œ", "OE"),
        ("æ", "ae"),
        ("Æ", "AE"),
    ]:
        s = s.replace(a, b)
    return "".join(ch if ord(ch) < 128 else "?" for ch in s)


def main() -> None:
    text = PATH.read_text(encoding="utf-8", errors="surrogateescape")
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    changed = 0
    for line in lines:
        if any(x in line for x in ("Print(", "Comment(", "Alert(")):
            if any(x in line for x in ("Ã", "Â", "ðŸ", "â", "\u2014", "\u2013")) or any(
                ord(c) > 127 for c in line
            ):
                fixed = ascii_safe(try_fix_mojibake(line))
                if fixed != line and any(x in fixed for x in ("Print(", "Comment(", "Alert(")):
                    changed += 1
                    line = fixed
        out.append(line)
    new_text = "".join(out)
    new_text, nbuild = re.subn(r"build=20261021-gomPass", "build=20261024-dowML", new_text)
    PATH.write_text(new_text, encoding="utf-8", newline="\n")
    print(f"lines_changed={changed} build_tags={nbuild}")
    for needle in ("SWING HIGH", "ENVOI IA", "ERREUR IA", "SPIKE", "ORDRE REJET", "build="):
        for line in new_text.splitlines():
            if needle in line and "Print(" in line:
                print(" sample:", line.strip()[:140])
                break


if __name__ == "__main__":
    main()
