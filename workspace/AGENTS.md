# AGENTS.md — Workspace

This folder is a blank multi-project workspace. The repos live somewhere else.
`workspace.yaml` beside this file lists them.

## Map
`workspace.yaml` is the source of truth for project locations and board ids.

- `projects` starts empty. When the user names a repo, add `name` and `path`.
- The board-id key matches the tracker that was configured:
  - Fizzy → `fizzy_board`
  - Azure Boards → `azure_board`
- Both keys are present only when both trackers are configured. Omit a key for a tracker that is not.
- A key set to `null` means that tracker is in use and this project has no board yet. Do not create a board, and do not ask again until there is a card to track.
- Do not invent projects, paths, or board ids.

## Work in a project
1. Load `workspace.yaml` and pick the project.
2. In that repo, read `AGENTS.md` if it exists, else `CLAUDE.md`.
3. The KMAD board binding is a `## KMAD` heading with `Board: <board_id>`. If it is missing, ask which board only when there is work to track.
4. Use the KMAD skills (`/kmad` and the siblings installed with it). Columns are **To Do** and **In Progress** only. Done is closing the card.
