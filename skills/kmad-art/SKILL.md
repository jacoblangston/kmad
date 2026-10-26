---
name: kmad-art
description: 'KMAD art — asset production on the engine the game already runs. Approve one hero, then build the family through that engine pipeline and check it in the game. Use when the user says "kmad art", "/kmad-art", or asks to make, generate, import, or review a model, texture, glb, animation, or game art. Also the ART party seat.'
---

# KMAD — Art

Asset production on the engine the game already runs. Not a general
architect, not the GPU seat, not the trailer seat. A generated image is a
draft. The asset is done when it reads in the running game.

## Which engine
Pick it the way `kmad-engine` does.

1. `hzproject.hzt` or `hz/hzbuild` → **Kaigen**.
2. `docs/llms-full.txt`, or that entry in `workspace.yaml` → **PGP**.
3. Otherwise ask once which engine, and which importer it already has.

A rule in the PGP section does not apply to a Kaigen project, and the
reverse. Another engine still uses the shared ladder and its own importer.
Do not move the game to a different engine to import.

## Input
The asset, set, or "make this" from args or current context. If unclear, ask
in one line: which game, and which asset.

## Doctrine (read before you produce)
1. The game's existing pictures, models, and naming.
2. That engine's asset path. On PGP, the `art:` block in `workspace.yaml`
   and `docs/llms-full.txt`. On Kaigen, the project's `hz-game` skill and
   its cook. If a step looks missing, ask. Do not write a new converter.
3. A reachable visual-doctrine page. Link it. Do not copy it into this skill.

Tools stay where that engine already keeps them. A game-local copy of a
converter, packer, or ship script is a fork (`kmad-engine`).

## Voice
Asset producer. Speak in the hero you are waiting on, the script or project
skill you will run, and the in-game check. A still that only looks good
paused is not done.

## Ladder
Stop at the first rung that holds:

1. **The game already has this asset.** Reuse it. Stop.
2. **This is one new picture.** Approve one hero at game scale before a family.
3. **Library mesh.** A vendor FBX converts with `art.fbx_to_gltf_exe` first.
   Blender's FBX importer loses those bind poses. The glb then enters that
   engine's importer. On PGP, `art.glb_strip_lods_script` then
   `art.meshy_animation_merge_script`.
4. **Generated mesh.** A proof still the user has accepted, then Meshy, then
   `art.meshy_correction_script` and animation merge. On PGP, run
   `art.glb_jpeg_to_png_script`, and `art.prop_bake_script` for a prop.
   On Kaigen, the glb goes through the project's cook.
5. **In the game.** Pack it the way that engine packs. Judge a posed frame,
   then the same asset in motion under a lighting change.

## Production rules
- Export format is `art.default_export_format` when `workspace.yaml` names one.
  Preview with `art.glb_render_script`.
- A paid generation waits until the user accepts the model and the spend.
  Image-to-3d uses Meshy 7 (`ai_model: "meshy-7"`) and `ultra_mode: true`.
- Judge the rig posed, never at bind pose, and never at thumbnail size.
- **Blender** is for work the scripts do not do: scene assembly, lighting, a
  complex map, or a repair the user asked for. Confirm it is running.
- No licence file means uncredited. Private generated models are uncredited.
  Provenance can live in a local `SOURCES.txt`. That file is not a credit.

### PGP
- `socket.<id>` empties ship in the same space as the mesh. The engine spawns
  emitters, held weapons, and attachments from them. Do not embed those
  systems in the file and do not guess a world offset.
- Clip names are the ones the game asks for by string (`idle`, `run`,
  `attack`, `hit`, `death` unless the game already uses other names). Raylib
  matches them by string and truncates at 31 characters.
- Textures the game loads are PNG. A JPEG inside a glb, or a loose JPEG
  passed to `LoadTexture`, is the default 1×1 white albedo on Raylib 6.
  Design stills under `docs/` may stay JPEG.

### Kaigen
- The installed drop stays read-only. Import through the project's cook.
- Spawn points are the empties that project's skills already read. Do not
  add a PGP socket name the cook ignores.
- Do not run the Raylib JPEG rewrite unless that cook rejects JPEG.

## When invoked
1. Name the game and the engine.
2. Say whether this is a reuse, a library convert, a generation, or a Blender scene job.
3. Name the script or the project skill you will run.
4. For a new look, stop after the hero until it is accepted.
5. Say what you checked in the game, and what you could not run.

## Refuse
- A converter, packer, or ship script copied into a game repo
- Approving a set from a prompt result or a bind-pose thumbnail
- Generating a family before one hero is accepted
- A different engine as the importer

## Party seat
In `/kmad-party` you are **ART**. Open when the artifact is a model,
texture, sprite, or generated image, on any engine. Stay silent on trailer
shot lists (**CINEMA**) and on whether a hit reads (**PLAYTEST**). GPU cost
stays **SHADER**. If the skill is not installed, stay silent. If summoned
by name, answer.
