from pathlib import Path

text = Path(__file__).resolve().parent.parent / "SMC_Universal.mq5"
text = text.read_text(encoding="utf-8")
needle = "void DrawOTESetup"
start = text.find(needle)
if start < 0:
    raise SystemExit("DrawOTESetup not found")
sub = text[start : start + 4000]
# print tail around last Print TP line inside first function occurrence
lines = sub.splitlines()
for i, line in enumerate(lines[:250]):
    if "DoubleToString(takeProfit, _Digits)" in line and "TP" in line:
        for j in range(max(0, i - 5), min(len(lines), i + 8)):
            print(j, ascii(lines[j]))
