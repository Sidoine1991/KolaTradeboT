---
description: "Log an architectural or trading decision as an ADR."
---

Log a decision for TradBOT:

The user has described a decision they are making or have made. Your job is to capture it as an ADR (Architecture Decision Record) so it survives across sessions.

1. Ask (if not already provided):
   - What is the decision? (one sentence)
   - What is the context / problem it solves?
   - What alternatives were considered?
   - What are the consequences (good and bad)?

2. Write the ADR to `data/decisions/<YYYY-MM-DD>-<kebab-slug>.md` using this format:

```
# ADR: <Title>

**Date**: <YYYY-MM-DD>
**Status**: Accepted

## Context
<1–2 sentences on the problem>

## Decision
<The choice made>

## Alternatives Considered
- <Option A>
- <Option B>

## Consequences
**Positive**: <benefit>
**Negative / Risk**: <trade-off>
```

3. Append a one-line entry to `data/logs/daily/<YYYY-MM-DD>.md`: `- Decision logged: <title>`.
4. Confirm: "Décision enregistrée dans data/decisions/."
