---
name: kmad
description: 'KMAD (Kanban Minimal AI Development) overview and getting-started — the method, fizzy.do board columns, Definition of Ready, sizing rules, and how to run a feature end to end. Use when the user says "kmad", "/kmad", "kmad help", "start a feature", or asks how the method works.'
---

# KMAD — Kanban Minimal AI Development

Small process for a solo dev: no sprints, continuous Kanban, fizzy.do as the ONLY tracker.
Docs live in the repo; cards live in fizzy via the `fizzy_*` MCP tools directly.
No separate sync layer between story files and the board.

## Sibling skills
- `/kmad-story` — create a single fizzy card (issue) from a one-line ask.
- `/kmad-plan` — lightweight PRD for L-sized features.
- `/kmad-architect` — smallest-correct system design + per-feature doc.
- `/kmad-dev` — implement one card end to end + drive its board moves.
- `/kmad-party` — multi-seat review panel for designs, diffs, and tradeoffs.

## Init (once per project)
Before the first card, bind the project to a fizzy board and record it so the
other skills stop re-asking. Re-running init is a safe reconcile — only create
what's missing.
1. **Board** — reuse an existing board (`fizzy_list_boards`) or create one (`fizzy_create_board`).
2. **Columns** — create any missing of `Triage → Ready → Building (WIP=1) → Review → Done` via `fizzy_create_column`.
3. **Docs** — scaffold `docs/product-plan/` and `docs/architecture/architecture.md`.
4. **Bind** — record the board under a `## KMAD` heading in **`AGENTS.md` if it
   exists, else `CLAUDE.md`**: a line `Board: <board_id>  # fizzy.do`. This is
   the binding every kmad skill reads first.

## Board
`Triage → Ready → Building (WIP=1) → Review → Done` — planning is the
Triage→Ready transition, not a column.

## Definition of Ready (the only gate)
- Goal is one sentence.
- Acceptance criteria are checkable (mirrored as fizzy steps).
- Size tagged `s`/`m`/`l`.
- If `l`: product-plan + architecture docs linked in the card.

## Size → how much planning
- **S** (<~2h, reversible, no new schema/API/boundary): card + criteria only.
- **M** (contained new endpoint/entity): a few lines in the card `## Plan`; run architect inline if useful.
- **L** (module / migration / cross-cutting / integration / auth or tenancy surface): `/kmad-plan` + `/kmad-architect` + `/kmad-party` before building.
- Rule of thumb: if getting it wrong means a migration or a breaking change to undo, it's **L**.

## Run a feature (end to end)
1. **Capture** — create a fizzy card in `Triage` (`/kmad-story`; title `area: summary`, tag project + type).
2. **Size it** — s/m/l. S/M skip to step 5.
3. **Shape (L)** — `/kmad-plan` then `/kmad-architect`; link both docs in the card. Tag `shaping` while in Triage.
4. **Party (L/risky)** — `/kmad-party` on the architecture; decompose into the cards it names.
5. **Ready** — write criteria as fizzy steps, confirm Definition of Ready, move card → `Ready`.
6. **Build** — `/kmad-dev`: move → `Building` (WIP=1), code to the criteria only, toggle steps as they pass, log decisions as fizzy comments. New discoveries → new `Triage` cards, never scope-creep the current one.
7. **Review** — self-review + tests; `/kmad-party` or `/code-review` if the diff earns it. Move → `Review`.
8. **Done** — `fizzy_close_card` or move → `Done`.

## Card template (fizzy description, markdown)
```markdown
## Goal
<one sentence — the user outcome>

## Why
<1–3 lines of context>

## Acceptance criteria
- [ ] ...
(also mirror as fizzy steps)

## Plan
Product Plan: docs/product-plan/<feature>.md   ← or "n/a (small)"
Architecture: docs/architecture/<feature>.md    ← or "n/a"

## Notes
<decisions, links, gotchas — cold-start context>
```
