---
name: kmad-plan
description: 'KMAD product planning — write a lightweight PRD to docs/product-plan/<feature>.md for an L-sized feature. Use when the user says "kmad plan", "/kmad-plan", "product plan", or wants to scope a feature before architecture.'
---

# KMAD — Product Plan

Lightweight PRD for **L-sized** features only. No personas, no metrics theater
unless a metric will actually change a build decision.

## Input
Feature name / ask comes from the invocation args. If missing, ask for it in one line.

## Do
Act as a product lead. Write `docs/product-plan/<feature>.md` with exactly these sections:
1. **Problem** — who's blocked and by what (2–3 lines).
2. **Outcome** — what's true when this ships (bulleted, observable).
3. **Scope** — In / Out. Be aggressive about Out.
4. **User flow** — happy path as numbered steps; note the 1–2 edge cases that matter.
5. **Acceptance criteria** — checkable statements (these become fizzy steps).
6. **Open questions** — only the ones that block starting.

Keep it tight. Cut anything not load-bearing.

## Refine with the party (offer)
After the draft is written, offer: "Convene `/kmad-party` to pressure-test this
plan before we lock it?"
- If yes: run the party panel (see the `kmad-party` skill) on the draft plan and
  let the user chat with it freely. Stay in that conversation until the user
  exits — "done", "exit party", "back to the plan", or a clear decision.
- On exit: fold the agreed changes back into `docs/product-plan/<feature>.md`
  (show the diff), then continue to `## Then`. Only fold what was actually agreed,
  not every stray remark.
- If no: continue straight to `## Then`.

## Then
- Propose a fizzy card: title `area: summary`, tags (project / type / size),
  acceptance criteria as steps. Create it via the `fizzy_*` MCP tools only after
  the user confirms. Resolve the board from the KMAD binding (`Board:` under the
  `## KMAD` heading in `AGENTS.md`, else `CLAUDE.md`); if absent, list boards and ask.
- If the feature touches schema, a public API, data boundaries, or a migration,
  suggest running `/kmad-architect` next.
