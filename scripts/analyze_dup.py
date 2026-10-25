#!/usr/bin/env python3
from pathlib import Path
import subprocess

wl = Path(r"d:\Dev\TradBOT\mt5\SMC_Universal.mq5").read_text(encoding="utf-8-sig", errors="replace").splitlines()
gl = (
    subprocess.check_output(["git", "show", "HEAD:mt5/SMC_Universal.mq5"], cwd=r"d:\Dev\TradBOT")
    .decode("utf-8", errors="replace")
    .splitlines()
)
print("work", len(wl), "git", len(gl))

same = 0
for i in range(min(len(gl), len(wl))):
    if gl[i] == wl[i]:
        same += 1
    else:
        print("first_diff", i)
        print(" git:", gl[i][:100])
        print(" work:", wl[i][:100])
        break
print("same_prefix", same)

# Is work = modified_git + something?
# Check if unique end-marker of git appears twice in work
end_marker = gl[-5]
print("git_end_marker", end_marker[:80])
occ = [i for i, l in enumerate(wl) if l == end_marker]
print("end_marker_occ", occ)

# Search for second '#property strict'
strict = [i for i, l in enumerate(wl) if "#property strict" in l or l.strip() == "#property strict"]
print("strict", strict)

# Search duplicate of UpdateMLMetricsDisplay definition
upd = [i for i, l in enumerate(wl) if l.startswith("void UpdateMLMetricsDisplay()")]
print("UpdateMLMetricsDisplay", upd)

draw = [i for i, l in enumerate(wl) if l.startswith("void SMC_DrawMLMetricsLabel()")]
print("DrawML def", draw)

# Size of unique content: count distinct function defs
funcs = [i for i, l in enumerate(wl) if l.startswith("void ") or l.startswith("bool ") or l.startswith("int ")]
print("top_levelish", len(funcs))

# Check if lines 0..N match lines N..2N for some N
best = None
for N in range(29000, 31000, 50):
    if 2 * N > len(wl):
        break
    m = sum(1 for a, b in zip(wl[:200], wl[N : N + 200]) if a == b)
    if best is None or m > best[0]:
        best = (m, N)
print("best_self_align", best)

# Maybe content after git-length is a second almost-full copy of OUR modified file
N = len(gl)
m = sum(1 for a, b in zip(wl[:500], wl[N : N + 500]) if a == b)
print(f"align_at_gitlen_{N}", m, "/500")
print("line_at_N", wl[N][:90] if N < len(wl) else None)
print("line_at_0", wl[0][:90])
