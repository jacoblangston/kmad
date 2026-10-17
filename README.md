# KMAD — Kanban Minimal AI Development

KMAD is Kanban Minimal AI Development: continuous Kanban for one person building
with an AI agent. No sprints. The tracker is [fizzy.do](https://fizzy.do) or
Azure DevOps, whichever you configure. Docs live in the repo. Cards live on
that board. The method ships as skills for Claude, Grok, or OpenAI.

## Skills

| Skill | Does |
|-------|------|
| `kmad` | Overview, board setup, Definition of Ready, sizing rules, run-a-feature loop. |
| `kmad-story` | Create one fizzy card from a one-line ask. |
| `kmad-plan` | Lightweight PRD for L-sized features. |
| `kmad-architect` | Smallest-correct system design + per-feature architecture doc. |
| `kmad-dev` | Implement one card end to end and drive its board moves. |
| `kmad-party` | Multi-seat review panel for designs, diffs, and tradeoffs. |
| `kmad-shader` | Optional. GPU rendering and shader expert; also the **SHADER** party seat. |
| `kmad-cinematic` | Optional. Game cinematic director for trailers and gameplay footage; also the **CINEMA** party seat. |
| `kmad-playtest` | Optional. Automated play of a PGP game (JSON input tape + engine exe); also the **PLAYTEST** party seat. |
| `kmad-engine` | Optional. Popcorning Guinea Pig engine developer (contract, examples, engine-vs-game); also the **ENGINE** party seat. |

## Install

**Windows** — `.\install.ps1` from a clone, or with no clone at all:

```powershell
irm https://raw.githubusercontent.com/jacoblangston/kmad/main/install.ps1 | iex
```

It asks which agents to install for: Claude (`%USERPROFILE%\.claude\skills`),
Grok (`%USERPROFILE%\.grok\skills`), OpenAI (`%USERPROFILE%\.agents\skills`),
or any combination. Pressing Enter installs for Claude only. `-Agents` sets
the same list unattended, for example `-Agents claude,grok,openai`. A
non-interactive run with no `-Agents` installs for Claude. `-Scope project`
writes under the current directory instead of the user profile (`.claude\skills`,
`.grok\skills`, or `.agents\skills`).

It copies the six core skills, then asks whether to install game-development
support (the **ENGINE**, **SHADER**, **CINEMA**, and **PLAYTEST** party seats:
`kmad-engine`, `kmad-shader`, `kmad-cinematic`, `kmad-playtest`). That defaults
to no. It then asks whether to configure a blank workspace, and where
(`%USERPROFILE%\workspace` if you just press Enter). Accepting writes
`AGENTS.md` and a `workspace.yaml` whose `projects` list is empty. Each
project can store `fizzy_board`, `azure_board`, or both, matching the trackers
that finished configuring. It does not copy anyone's repos or board ids.
Files already in that directory are left alone. It then offers two opt-in plugins: **fizzy.do** (card tracking —
prompts for your token) and **Azure** (Azure MCP server, auth inherited from
`az login`). Both default to no; missing prereqs are offered via winget or choco.
Switches for an unattended run: `-Force -Games -WorkspacePath C:\work -Fizzy -FizzyToken <t> -Azure -Subscription <id> -InstallPrereqs`.
Omit `-Games` and a non-interactive run skips game development without asking.
Omit `-Workspace` and `-WorkspacePath` and it skips the workspace the same way.
`-Workspace` alone uses `%USERPROFILE%\workspace`.

**macOS / Linux**:

```sh
# copy the same folders into one or more of:
#   ~/.claude/skills   ~/.grok/skills   ~/.agents/skills
cp -r skills/kmad skills/kmad-story skills/kmad-plan skills/kmad-architect skills/kmad-dev skills/kmad-party ~/.claude/skills/
# optional game-development party seats:
cp -r skills/kmad-engine skills/kmad-shader skills/kmad-cinematic skills/kmad-playtest ~/.claude/skills/
# optional blank workspace — edit the directory, leave projects empty:
mkdir -p ~/workspace && cp workspace/AGENTS.md ~/workspace/AGENTS.md
printf "workspace_root: '%s'\nprojects: []\n" "$HOME/workspace" > ~/workspace/workspace.yaml
npx fizzy-do-mcp@latest configure   # optional: card tracking
```

Then invoke `/kmad` (or `/kmad-story`, `/kmad-dev`, and so on). In Codex, use `$kmad`.

## Start here

Run `/kmad` for the method and to bind a project to a board.

## License

[MIT](LICENSE)
