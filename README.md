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

Copy the skill folders into your Claude Code user skills directory:

```sh
cp -r skills/* ~/.claude/skills/
```

Then in Claude Code, invoke with `/kmad` (or `/kmad-story`, `/kmad-dev`, etc.).

Card tracking uses the fizzy.do MCP server (`fizzy_*` tools). Set it up with
`npx fizzy-do-mcp@latest configure` and register it in your user-level MCP config.

## Start here

Run `/kmad` for the method and to bind a project to a board.
