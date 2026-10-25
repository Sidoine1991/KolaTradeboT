#!/usr/bin/env python3
from pathlib import Path

p = Path(r"d:\Dev\TradBOT\mt5\SMC_Universal.mq5")
raw = p.read_bytes()
if raw.startswith(b"\xef\xbb\xbf"):
    text = raw[3:].decode("utf-8", errors="replace")
else:
    text = raw.decode("utf-8", errors="replace")

lines = text.splitlines(True)
print("total", len(lines))
oninit = [i for i, l in enumerate(lines) if "int OnInit()" in l]
props = [i for i, l in enumerate(lines) if l.startswith("#property copyright")]
canplace = [i for i, l in enumerate(lines) if l.startswith("bool CanPlaceMarketOrder")]
print("OnInit", oninit)
print("copyright", props)
print("CanPlaceMarketOrder", canplace)

if len(props) < 2 and len(oninit) < 2:
    print("no duplicate detected")
    raise SystemExit(0)

# Start of second copy: second #property copyright block header
anchor = props[1] if len(props) >= 2 else oninit[1]
start2 = anchor
for j in range(anchor, max(0, anchor - 40), -1):
    if lines[j].startswith("//+") and "----" in lines[j]:
        start2 = j
        # keep scanning for the outermost header of the second file
        continue
print("cut_at", start2, "preview=", lines[start2][:60].rstrip())

new_lines = lines[:start2]
while new_lines and new_lines[-1].strip() == "":
    new_lines.pop()
new_lines.append("\n")
p.write_text("".join(new_lines), encoding="utf-8", newline="\n")
print("written", len(new_lines))
