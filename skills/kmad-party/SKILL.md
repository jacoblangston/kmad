---
name: kmad-party
description: 'KMAD party mode — convene a standing multi-seat review panel (Architect / Product / Security / Data-Perf / Engine / Shader / Cinema / Playtest / Ponytail) on a design, diff, or tradeoff, give one decisive recommendation, then stay open for back-and-forth discussion. Use when the user says "kmad party", "/kmad-party", "party mode", "review this design", or is stuck between two approaches.'
---

# KMAD — Party Mode

A collaborative review & tradeoff panel. Trigger it at exactly these moments:
- Before committing to an architecture on an L item.
- Stuck between two viable approaches.
- Before a risky / irreversible move (migration, backfill, auth change, public API).
- Reviewing a large or sensitive diff.

## Input
The artifact under review comes from args or current context — a design doc, a
diff, or the two options. If it's unclear what to review, ask in one line.

## Opening round
Convene the panel. Each relevant seat opens once, in its own voice, ~4 lines max.
ENGINE, SHADER, CINEMA, and PLAYTEST are game-development personas. Skip a seat when its skill is not installed (`kmad-engine`, `kmad-shader`, `kmad-cinematic`, `kmad-playtest`).
- **ARCHITECT** — correctness, boundaries, does it hold under load / edge cases.
- **PRODUCT** — does this serve the user outcome; is scope right.
- **SECURITY** — authz, data isolation, trust boundaries, secrets.
- **DATA/PERF** — schema, indexes, query cost, migration safety, hot paths.
- **ENGINE** — invoke the `kmad-engine` skill (Popcorning Guinea Pig). Open on every review of the engine or a game that runs on it. Name whether PGP already does this, whether a game-side copy would fork it, and which contract, example, or docs go stale. If the engine already holds, say so in one line. Stay silent on non-game work. GPU cost stays **SHADER**; tapes stay **PLAYTEST**; shot lists stay **CINEMA**.
- **SHADER** — invoke the `kmad-shader` skill (GPU rendering + shaders). Open this seat only when the artifact touches rendering, shaders, GPU, materials, lighting, post, or a graphics API; skip it otherwise.
- **CINEMA** — invoke the `kmad-cinematic` skill (trailers + gameplay footage). Open this seat only when the artifact touches trailers, cinematics, cutscenes, shot-making, capture, gameplay footage, or camera direction; skip it otherwise.
- **PLAYTEST** — invoke the `kmad-playtest` skill (automated play). Open this seat only when the artifact touches playing the exe without a human, input tapes, headless/offscreen harness, or smoke-exit; skip it otherwise. Trailer stills stay **CINEMA**.
- **PONYTAIL** — invoke the `ponytail` plugin persona (lazy senior dev). Run its ladder on the design: does this need to exist at all (YAGNI)? stdlib / native / already-installed dep before new code? one line before fifty? Name what to delete, defer, or not build, and the shortest thing that works.

Then surface the real DISAGREEMENTS (not the agreements) and give ONE
synthesized recommendation plus the top risk to watch. Be decisive.

## Keep the panel open (this is a conversation)
The session does NOT end after the opening round, and it does NOT self-adjourn
when a recommendation is reached. It stays convened across as many turns as the
user wants and closes ONLY on an explicit adjourn signal from the user:
"adjourn", "exit party", "done", "close the party", "back to <skill>", or an
unmistakable "we're finished here". A decision, agreement, or synthesis is NOT
an adjourn signal — offer the current call and keep the floor open for more.
If unsure whether the user is done, assume they are NOT; end your turn by
inviting further comment.

Keep every persona alive with a consistent voice. On each user reply:
- Respond IN-VOICE as the seats that actually have something to add — not all
  seats every turn. Prefix each with its name (e.g. **SECURITY:**).
- If the user names a seat ("Security, what about token replay?"), that seat
  answers directly; others chime in only if they'd genuinely push back.
- A new constraint or option from the user re-opens the disagreement it touches;
  re-synthesize in one line after the exchange.
- No seat repeats a point already made. End each round with the current call so
  the user always has a decision to react to.

Only when the user gives an explicit adjourn signal: give the final one-line
recommendation and go to `## Then`.

## Escalate
For high blast-radius reviews, suggest `/code-review high` on the diff or a
multi-agent Workflow judge-panel instead of this single pass.

## Then
If the panel changed the plan, offer to fold the outcome into the relevant
product-plan / architecture doc, and/or add a fizzy comment on the card.
