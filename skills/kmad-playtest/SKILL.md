---
name: kmad-playtest
description: 'KMAD playtest — author and run automated play of a PGP game: Given/When/Then mapped onto xUnit, smoke-exit, a JSON input tape the engine exe plays, capture stills, or feel. Use when the user says "kmad playtest", "/kmad-playtest", "playtest", "automate playing the game", "QA the demo", "scripted input", or asks for a game test plan that actually plays.'
---

# KMAD — Playtest

Author and run tests that **play the game**. Not a general architect. Not a
new test framework. The engine is the player; this skill writes the plan and
runs it.

## Input
The game, card, Demo/Full SKU, or feature from args or current context. If
unclear, ask in one line: which exe, and what must a player have *done*?

## Doctrine (project first)
Look in this order and treat the first hit as law:
1. Paths named in `AGENTS.md` / `CLAUDE.md` (testing, `--playtest`, `--capture`,
   `--smoke-exit`).
2. Engine playtest docs / wiki `headless-game-verification`.
3. Existing `qa/*.json` tapes, shot books, and `*.Core.Tests`.

PGP games: consume the engine as a package. **Never** invent a Unity / Unreal /
Godot runner, Reqnroll/SpecFlow, GDS `test-framework`, or a per-game harness.
If `--playtest` (or the engine equivalent) is missing, stop: that is engine
work (PGP #407). Do not work around it in the game.

## Layers
Stamp every scenario with exactly one. Play is required when the user cares
that a human could do it in the exe.

| Layer | Means | Runs |
|---|---|---|
| `unit` | Rules with no window (`World` + `InputSnapshot`, catalogs, SKU) | `dotnet test` |
| `smoke` | Boot, register, load first scenes, known exit | `--smoke-exit` (local; no GPU on CI) |
| `play` | Injected pointer/keys through the **real** input path for N frames | `<exe> --playtest <tape.json>` |
| `capture` | Posed still/clip (store, camp tiers). Not play. | `--capture` / shot book |
| `feel` | Weight, readability under motion, music vs horde | Human or Grok-on-PNG. Never an assert |

`play` must not teleport, freeze sim, or set a walk vector the way capture
does. Right-click is a right-click. Capture `Walk` is not a playtest.

Gherkin `.feature` files are optional **docs**. Do not add a Gherkin runtime.
The executable play format is a JSON input tape (System.Text.Json; same idea
as shot books). Reqnroll, Gauge, LightBDD, and GDS scaffolds are out.

## Tape (play layer)
Engine owns the schema and the injector. Games fill ids and asserts. A tape
is seed + timed input + asserts + optional PNG:

```json
{
  "id": "demo-veronica-walk",
  "seed": 1234,
  "skipSplash": true,
  "steps": [
    { "click": "mission.veronica" },
    { "waitScene": "PlayScene" },
    { "rightClickGround": { "x": 8, "z": 4 } },
    { "frames": 90 }
  ],
  "assert": [
    { "scene": "PlayScene" },
    { "playerOnGround": true }
  ],
  "shot": "qa/demo-veronica-walk.png"
}
```

Put tapes in the game repo (`qa/` or wherever the README already points).
Do not put game click names in this skill.

## When invoked
1. Name the exe / SKU and whether the engine playtest flag exists.
2. List what already runs (`dotnet test`, smoke, capture, tapes).
3. Write scenarios as Given / When / Then, each with `PRIORITY` and a layer.
4. Implement: xUnit for `unit`; tape(s) for `play`; do not grow capture into play.
5. Run the layers that exist. `play` fail = non-zero process exit. PNG is
   evidence, not the pass.
6. New pixels: Grok (or a human) may **judge** a first PNG. Grok is not the
   player. Later runs assert files/state, not an LLM.

## Ladder
Stop at the first rung that holds:

1. **Is this already a Core unit test?** If Raylib is not required, xUnit.
2. **Is this boot?** `--smoke-exit`.
3. **Must a player have done it in the exe?** JSON tape + engine playtest.
4. **Is it a still for art/store?** Capture book. Not a playtest.
5. **Is it feel?** Manual / Grok-on-PNG. Do not fake it.

## Refuse
- A game-local play harness because the engine flag is not shipped yet
- Going *around* picking (inject `InputSnapshot` into `World` and call it
  product play — that is `unit`)
- Pixel-perfect image diff as the first slice
- `grok -p` as CI green/red
- Scaffolding GDS / Unity Test Framework / Unreal Automation / GUT

## Party seat
In `/kmad-party` you are **PLAYTEST**. Open only when the artifact touches
automated play, input tapes, headless/offscreen harness, smoke-exit, or
whether a criterion is playable without a human. Stay silent on trailer
shot lists (that is **CINEMA**). If summoned by name, answer.
