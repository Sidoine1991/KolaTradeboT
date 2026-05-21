---
description: "Add a task to the inbox queue for future sessions."
---

Add a task to the TradBOT inbox:

The user wants to queue a task for later. Capture it without acting on it now.

1. Ask (if not provided): "Décris la tâche en une phrase." (or "Describe the task in one sentence.")
2. Create a file `data/inbox/<YYYY-MM-DD>-<kebab-slug>.md` with:

```
# Task: <Title>

**Added**: <YYYY-MM-DD HH:MM>
**Priority**: <high / medium / low>
**Context**: <one sentence on why this matters>

## What to do
<2–4 bullet points describing the task>

## Agent
<which agent should handle it: @trading-optimizer / @ai-server / @debug / @researcher / @ops>
```

3. Confirm: "Tâche ajoutée à data/inbox/. Lance /status pour voir toutes les tâches en attente."
