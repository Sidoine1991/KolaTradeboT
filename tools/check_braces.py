import re
from pathlib import Path

path = Path(r"D:/Dev/TradBOT/mt5/SMC_Universal.mq5")
text = path.read_text(encoding="utf-8", errors="replace")
lines_raw = text.splitlines()
lines = []
for line in lines_raw:
    if "//" in line:
        line = line[: line.find("//")]
    lines.append(line)
text = "\n".join(lines)
text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)

depth = 0
for i, line in enumerate(text.splitlines(), 1):
    for ch in line:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
    if depth < 0:
        print(f"extra }} at line {i}: depth={depth}")
        print(" ", lines_raw[i - 1][:100])
        break
else:
    print(f"final depth={depth}")
    if depth != 0:
        print("UNBALANCED - missing", depth, "closing braces")
    else:
        print("OK - braces balanced")

depth = 0
for i, line in enumerate(text.splitlines(), 1):
    for ch in line:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
    if 5830 <= i <= 5860:
        safe = lines_raw[i-1][:70].encode('ascii', 'replace').decode('ascii')
        print(f"{i:5d} depth={depth:2d} | {safe}")
