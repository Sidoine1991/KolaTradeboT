---
description: "Close a work session: log what happened, update state, clear inbox."
---

Close the current TradBOT work session:

1. Run `git log --oneline -10` and extract commits made during this session.
2. Ask the user: "Quels blockers ou points ouverts dois-je noter?" (or "Any blockers or open items to note?")
3. Append a `## Session End` section to today's log at `data/logs/daily/<YYYY-MM-DD>.md` with:
   - **Commits this session** (from git log)
   - **What was accomplished** (3 bullet points max)
   - **Blockers / open items** (from user's answer)
   - **Next actions** (2–3 concrete to-dos)
   - **Reflection** (one sentence: what to do differently next time)
4. Update `data/state/current-session.md` with the open items and next actions.
5. Confirm: "Session fermée. Reprends avec /session-start la prochaine fois."
