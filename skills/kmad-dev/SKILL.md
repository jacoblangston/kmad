---
name: kmad-dev
description: 'KMAD dev — implement a single fizzy.do card end to end: load its brief, move it Building → Review, code to the acceptance criteria only, toggle steps and log decisions on the board. Use when the user says "kmad dev", "/kmad-dev", "implement this card", "build the card", or "work the next card".'
---

# KMAD — Dev

Implement ONE card. The coding is the easy part; this skill's job is the board
choreography and scope discipline around it.

## Pick the card
- Card id / title from the invocation args.
- If none given: take the card already in `Building`; if `Building` is empty,
  take the top of `Ready`.
- **WIP = 1**: if a card is already in `Building` and args name a different one,
  stop and ask — finish the in-flight card first.
- Resolve the board from the KMAD binding (`Board:` under the `## KMAD` heading
  in `AGENTS.md`, else `CLAUDE.md`); if absent, `fizzy_list_boards` and ask.

## Load the brief
`fizzy_get_card` → read `## Goal`, `## Acceptance criteria`, `## Plan`, `## Notes`.
Open any linked `docs/product-plan/*` and `docs/architecture/*`. That is the
whole brief — build to it, not beyond it.

## Move → Building
`fizzy_update_card` to the `Building` column if it isn't there already.

## Implement
Code to the acceptance criteria ONLY. Ruthless minimalism:
- Reuse platform / stdlib / already-installed deps before any new code or dependency.
- No abstraction, config, or flexibility a criterion didn't ask for.
- Keep the diff the shortest thing that satisfies the criteria and tests.

As you go:
- `fizzy_toggle_step` each acceptance criterion the moment it passes.
- `fizzy_create_comment` for any non-obvious decision — that's the card's cold-start context.

## Contain scope
Anything discovered that isn't in this card's criteria → a NEW card in `Triage`
via `/kmad-story`. Never grow the current card.

## Finish
- Run the tests; read your own diff.
- For a large or sensitive diff, run `/kmad-party` or `/code-review` first.
- `fizzy_update_card` → `Review`. After review passes, move → `Done` or
  `fizzy_close_card`.
