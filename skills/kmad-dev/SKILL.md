---
name: kmad-dev
description: 'KMAD dev — implement a single fizzy.do card end to end: load its brief, move it To Do → In Progress, code to the acceptance criteria only, toggle steps, log decisions, and close the card. Use when the user says "kmad dev", "/kmad-dev", "implement this card", "build the card", or "work the next card".'
---

# KMAD — Dev

Implement ONE card. The coding is the easy part; this skill's job is the board
choreography and scope discipline around it.

Boards have **To Do** and **In Progress** only. Never look for Building,
Review, Ready, or Done, and never report those names as missing.

## Pick the card
- Card id / title from the invocation args.
- If none given: take the card already in `In Progress`; if `In Progress` is
  empty, take the top of `To Do`.
- **WIP = 1**: if a card is already in `In Progress` and args name a different
  one, stop and ask — finish the in-flight card first.
- Resolve the board from the KMAD binding (`Board:` under the `## KMAD` heading
  in `AGENTS.md`, else `CLAUDE.md`); if absent, `fizzy_list_boards` and ask.

## Load the brief
`fizzy_get_card` → read `## Goal`, `## Acceptance criteria`, `## Plan`, `## Notes`.
Open any linked `docs/product-plan/*` and `docs/architecture/*`. That is the
whole brief — build to it, not beyond it.

## Move → In Progress
`fizzy_update_card` to the `In Progress` column if it isn't there already.

## Implement
Code to the acceptance criteria ONLY. Ruthless minimalism:
- Reuse platform / stdlib / already-installed deps before any new code or dependency.
- No abstraction, config, or flexibility a criterion didn't ask for.
- Keep the diff the shortest thing that satisfies the criteria and tests.
- Asset production goes through `/kmad-art` on whatever engine the game uses.
- On a PGP game, a new player verb is a `.pgpscn` and a `/kmad-playtest` tape
  before any generated-asset spend.
- On a Kaigen project, follow `/kmad-engine`. Do not use a PGP scene or tape.

As you go:
- `fizzy_toggle_step` each acceptance criterion the moment it passes.
- `fizzy_create_comment` for any non-obvious decision — that's the card's cold-start context.

## Contain scope
Anything discovered that isn't in this card's criteria → a NEW untriaged card
via `/kmad-story`. Never grow the current card.

## Finish
- Run the tests; read your own diff. Game criteria that a player must have
  *done* in the exe go through `/kmad-playtest`, not only `dotnet test`.
- A public engine change, a new shared behavior, or a game-side copy of
  something the engine should own goes through `/kmad-engine`. On PGP that
  moves the agent contract, `docs/llms-full.txt`, the example, and docfx
  with the code. On Kaigen it leaves the installed drop alone.
- For a large or sensitive diff, run `/kmad-party` or `/code-review` first.
- `fizzy_close_card`. Done is closing, not a column.
