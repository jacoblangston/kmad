# KMAD — Kanban Minimal AI Development

A small process for a solo dev: no sprints, continuous Kanban, [fizzy.do](https://fizzy.do)
as the only tracker. Docs live in the repo; cards live in fizzy via the `fizzy_*`
MCP tools. A set of Claude Code skills.

## Skills

| Skill | Does |
|-------|------|
| `kmad` | Overview, board setup, Definition of Ready, sizing rules, run-a-feature loop. |
| `kmad-story` | Create one fizzy card from a one-line ask. |
| `kmad-plan` | Lightweight PRD for L-sized features. |
| `kmad-architect` | Smallest-correct system design + per-feature architecture doc. |
| `kmad-dev` | Implement one card end to end and drive its board moves. |
| `kmad-party` | Multi-seat review panel for designs, diffs, and tradeoffs. |

## Install

**Windows** — `.\install.ps1` from a clone, or with no clone at all:

```powershell
irm https://raw.githubusercontent.com/jacoblangston/kmad/main/install.ps1 | iex
```

It copies the skills, then offers two opt-in plugins: **fizzy.do** (card tracking —
prompts for your token) and **Azure** (Azure MCP server, auth inherited from
`az login`). Both default to no; missing prereqs are offered via winget or choco.
Switches for an unattended run: `-Force -Fizzy -FizzyToken <t> -Azure -Subscription <id> -InstallPrereqs`.

**macOS / Linux**:

```sh
cp -r skills/* ~/.claude/skills/
npx fizzy-do-mcp@latest configure   # optional: card tracking
```

Then in Claude Code, invoke with `/kmad` (or `/kmad-story`, `/kmad-dev`, etc.).

## Start here

Run `/kmad` for the method and to bind a project to a board.
