---
name: kmad-architect
description: 'KMAD architect workflow — design the smallest correct system for a feature and write docs/architecture/<feature>.md, then decompose into fizzy cards. Use when the user says "kmad architect", "/kmad-architect", "architect this", or wants a system design before building.'
---

# KMAD — Architect

Design only. **No code.** Produce the smallest correct system, a per-feature
architecture doc, and the cards it decomposes into.

## Input
- Feature name / ask from the invocation args. If missing, ask in one line.
- If `docs/product-plan/<feature>.md` exists, read it first as the brief.
- Infer stack/constraints from the repo (read `CLAUDE.md` and project files). Ask
  only if a load-bearing constraint is genuinely unclear. Do NOT assume a framework.

## Do
Act as a senior architect. Design the SMALLEST correct system.

Rules of engagement:
- **REUSE FIRST**: platform features, stdlib, and already-installed deps before
  any new code or dependency. Name each thing you lean on.
- New abstraction or new dependency only where nothing existing fits — justify each in one line.
- Design to the invariants and data model, not to the framework.
- Rendering / shaders / GPU pipeline: follow the `kmad-shader` skill (and any
  project visual doctrine it finds) before proposing a pipeline.
- Cinematics / camera language / capture: follow the `kmad-cinematic` skill
  (and any project cinematic doctrine it finds) before proposing a cutscene stack.
- Automated play / headless harness / input tapes: follow the `kmad-playtest`
  skill. Engine owns the player; games own plans. Do not design a per-game
  test framework.
- Popcorning Guinea Pig API, examples, or a game about to reimplement the
  engine: follow the `kmad-engine` skill. Shared behavior is an engine change;
  the agent contract and the example move with it.

Write `docs/architecture/<feature>.md` with:
1. **Data model** — new/changed entities, ownership, invariants, key constraints/indexes.
2. **Persistence & migration** — the migration and its ROLLBACK / backfill plan.
   Flag anything irreversible or that locks a large table.
3. **Boundaries** — module/service seams, public vs internal, isolation risks
   (tenancy / auth / data leakage) called out explicitly.
4. **External surfaces** — API / events / jobs: minimal method + payload shape + who's allowed.
5. **Cross-cutting** — caching, background work, search/indexing, auth. ONLY if actually needed.
6. **Risks** — and the one thing most likely to bite.

End with the **3–5 fizzy cards** this decomposes into (title + size s/m/l each).

## Then
- Offer to create those cards in `Triage` on the project board via the `fizzy_*`
  MCP tools (tag project + type + size). Ask before creating. Resolve the board
  from the KMAD binding (`Board:` under the `## KMAD` heading in `AGENTS.md`, else
  `CLAUDE.md`); if absent, list boards and ask.
- If the design changes a system-wide truth, offer to update `docs/architecture/architecture.md`.
- For an L or risky design, suggest `/kmad-party` to pressure-test it before building.
