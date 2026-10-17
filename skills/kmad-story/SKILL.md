---
name: kmad-story
description: 'KMAD story — create a single well-formed fizzy.do card (issue) from a one-line ask, using the KMAD card template. Use when the user says "kmad story", "/kmad-story", "new card", "new issue", or "add a story".'
---

# KMAD — Story

Create ONE fizzy card from a short ask. This is the unit of work — no docs, no
ceremony. For L features that need planning first, use `/kmad-plan` and
`/kmad-architect`; this skill just captures a single issue.

Boards have **To Do** and **In Progress** only. Never create Ready, Building,
Review, or Done, and never report those names as missing.

## Input
The ask comes from the invocation args. If missing, ask for it in one line.

## Board
- Resolve the board from the KMAD binding: read the `Board:` id under the
  `## KMAD` heading in `AGENTS.md` if it exists, else `CLAUDE.md`.
- If no binding exists, call `fizzy_list_boards` and ask which board (or suggest
  running `/kmad` init to create the board + binding).
- Default: leave the card in fizzy's untriaged pile (Triage). Put it on
  `To Do` only if the ask already meets the Definition of Ready (clear goal +
  checkable criteria + size). Resolve the column id with `fizzy_list_columns`
  if you need To Do / In Progress; do not offer to create other columns.

## Draft
Build the card, then show it for a quick confirm (skip the confirm if the user
said "just create it"):
- **Title**: `area: imperative summary`.
- **Tags**: project · type (`feat`/`bug`/`chore`/`spike`) · size (`s`/`m`/`l`). Infer, don't interrogate.
- **Description** (markdown):
```markdown
## Goal
<one sentence — the user outcome>

## Why
<1–3 lines, only if not obvious>

## Acceptance criteria
- [ ] ...

## Plan
<doc links, or "n/a (small)">

## Notes
<gotchas / links, if any>
```

## Create
On confirm, via the `fizzy_*` MCP tools:
1. `fizzy_create_card` (board + column + title + description).
2. `fizzy_create_step` for each acceptance criterion (mirror the checklist as steps).
3. `fizzy_tag_card` for each tag.

Report the created card id/link. Keep it to one card — extra work discovered
becomes separate stories, not scope on this one.
