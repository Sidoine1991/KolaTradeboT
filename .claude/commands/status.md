---
description: "Morning briefing: git status, server health, recent errors, and next actions."
---

Run the TradBOT morning status check:

1. Run `git log --oneline -5` and report recent commits in one line each.
2. Run `git status --short` and list any modified or untracked files by category (strategy, server, docs).
3. Read `data/state/current-session.md` for the active context and last known system state.
4. Read `data/state/system-status.md` for deployment health.
5. Check `data/inbox/` for any queued tasks and list them.
6. Output a compact briefing:
   - **Recent commits** (5 lines max)
   - **Dirty files** grouped by type
   - **Active context** (1–2 sentences from current-session.md)
   - **Queued tasks** (bullet list from inbox/)
   - **Recommended next action** (one sentence)
