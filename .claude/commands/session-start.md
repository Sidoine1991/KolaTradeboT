---
description: "Bootstrap a new work session: load context, set focus, open inbox."
---

Start a new TradBOT work session:

1. Read `data/state/current-session.md` — load the previous session's active context and open items.
2. Read `data/logs/daily/` — find today's log file if it exists; if not, create `data/logs/daily/<YYYY-MM-DD>.md` with a `## Session Start` heading and the current timestamp.
3. Read `data/inbox/` — list all queued tasks.
4. Ask the user: "Quel est le focus de cette session?" (or "What is the focus of this session?")
5. Update `data/state/current-session.md` with:
   - Session date
   - Focus area
   - Open items carried from previous session
6. Output a session brief: focus, open items, and the first recommended action.
