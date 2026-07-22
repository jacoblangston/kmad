# Windows installer (`install.ps1`)

## Problem
The only install instruction is `cp -r skills/* ~/.claude/skills/` — a POSIX command
that fails in PowerShell. Fizzy setup is a separate undocumented step, and there's no
Azure path at all. A Windows user has to reverse-engineer the install from the README.

## Outcome
- `.\install.ps1` on a fresh clone puts all six kmad skills in `%USERPROFILE%\.claude\skills`; `/kmad` works in the next Claude Code session.
- Fizzy is opt-in. Decline → no fizzy config, no MCP entry. Accept → `fizzy-do-mcp status` reports **Configured**.
- Azure is opt-in. Accept → Azure MCP server registered at user scope, auth inherited from `az login`, no secret stored by us.
- Re-running is idempotent: no duplicate MCP entries, no re-prompt for a token already stored.
- Base install needs no admin rights and installs nothing the user didn't say yes to.
- Every prompt has a matching switch, so a fully unattended run is possible.

## Scope
**In**
- `install.ps1` at repo root. Windows PowerShell 5.1 + PowerShell 7.
- Two entry paths: local `.\install.ps1` from a clone, and the piped one-liner
  `irm https://raw.githubusercontent.com/jacoblangston/kmad/main/install.ps1 | iex`.
  When `$PSScriptRoot` has no `skills\` beside it, the script downloads the repo zip to
  a temp dir, installs from that, and deletes it. Prompts-only in that mode — no params.
- Copy `skills/*` → `$env:USERPROFILE\.claude\skills\` (`-Scope project` writes `.\.claude\skills\` instead).
- Optional fizzy plugin: token prompt → `npx fizzy-do-mcp@latest configure -t <token>` (it stores the token in `~/.config/fizzy-do-mcp/config.json` and registers the MCP server itself). We verify the entry landed and only write it ourselves if it didn't.
- Optional Azure plugin: ensure `az` → `az login` → default subscription → register Azure MCP server (`npx -y @azure/mcp@latest server start`) at user scope.
- MCP registration helper: use `claude mcp add --scope user` when `claude` is on PATH,
  otherwise edit `~/.claude.json` directly (timestamped backup first). Assume nothing
  about the environment.
- Prereq handling: detect `winget` / `choco`; if neither, offer to install choco; then offer to install each missing prereq (Node, az).
- README install section rewritten.

**Out**
- Uninstaller. (Deleting six folders is a one-liner; print it on request.)
- macOS/Linux script — the existing `cp` line already works.
- Auto-update / version pinning / publishing kmad to winget or the PowerShell Gallery.
- Installing Claude Code itself — if it's absent, the user isn't here yet.
- Binding a project to a fizzy board — that's `/kmad` init, and it's per-project, not per-machine.
- Credential vaults, DPAPI, service principals. Fizzy owns its token file; Azure owns its own cache.
- Azure DevOps, any second tracker.

## Install questions
Every prompt has a switch that pre-answers it; supply all of them and the run is silent.

| # | Question | Asked when | Default | Switch |
|---|----------|-----------|---------|--------|
| 1 | Install for this user or this project? | never — parameter only | user | `-Scope user\|project` |
| 2 | Overwrite existing kmad skill folders? | folders already present | Yes | `-Force` |
| 3 | Enable the fizzy.do plugin? | always | **No** | `-Fizzy` |
| 4 | Fizzy access token | fizzy accepted **and** not already configured | — | `-FizzyToken` |
| 5 | Reconfigure fizzy? (shows current identity) | fizzy accepted and already configured | No | `-Reconfigure` |
| 6 | Enable the Azure plugin? | always | **No** | `-Azure` |
| 7 | Install Chocolatey? | a prereq is missing and neither winget nor choco exists | No | `-InstallPrereqs` |
| 8 | Install `<Node\|az>` via `<winget\|choco>`? | that prereq is missing | No | `-InstallPrereqs` |
| 9 | Run `az login` now? | azure accepted and `az account show` fails | Yes | `-Azure` implies yes |
| 10 | Which subscription is the default? | azure accepted and >1 subscription | current | `-Subscription` |

Question 4 uses `Read-Host -AsSecureString`; the token is never echoed, never logged, never
passed on a visible command line.

## User flow
1. `git clone` → `.\install.ps1` (or `powershell -ExecutionPolicy Bypass -File install.ps1`), **or** the `irm | iex` one-liner, which downloads the repo zip to temp first.
2. Script prints what it will do, then copies the six skill folders — asking Q2 only if they already exist.
3. Q3 fizzy. No → step 6.
4. `fizzy-do-mcp status`: already configured → print identity, ask Q5. Otherwise ask Q4 and run `configure -t`.
5. Verify with `whoami`, and confirm a `fizzy-do` entry now exists in the user MCP config — write it only if `configure` didn't. On failure print the error, leave nothing half-written, and continue.
6. Q6 azure. No → step 9.
7. `az` missing → prereq flow (Q7/Q8). Still missing or declined → skip azure with the exact install command printed.
8. `az account show` → logged out runs `az login`; >1 subscription asks Q10 and `az account set`. Then register the Azure MCP server at user scope if it isn't already there.
9. Summary: what was installed, what was skipped and why, and "restart Claude Code, then run `/kmad`".

**Edge cases that matter**
- **Non-interactive session** (CI, no console): any unanswered prompt fails fast with the switch name to use, rather than hanging.
- **Fresh PATH after a prereq install**: winget/choco put `node`/`az` on the machine PATH but not the current process's. Re-resolve the exe from its known install dir; if that fails, tell the user to reopen the shell and re-run — never claim success on a tool we can't invoke.
- **`~/.claude.json` hand-edit**: it's the live Claude Code config and can be large. Back it up, preserve everything else — if `claude` is on PATH, prefer the CLI and skip this path entirely.
- **Unparseable `~/.claude.json`**: real configs contain project keys differing only in case (`c:\git\x` vs `C:\git\x`), which `ConvertFrom-Json` rejects outright. Confirmed on the author's machine. Refuse to rewrite, print the snippet to paste, and carry on — never truncate a config we can't round-trip.

## Acceptance criteria
- [ ] Runs on Windows PowerShell 5.1 and PowerShell 7 without admin (base install).
- [ ] Defaults-only run (No to both plugins) leaves six kmad folders under `$env:USERPROFILE\.claude\skills`, exit 0, and zero changes to any MCP config.
- [ ] Non-kmad skill folders in that directory are never modified or deleted.
- [ ] Declining overwrite leaves existing folders byte-identical and still exits 0.
- [ ] Declining fizzy leaves no `~/.config/fizzy-do-mcp/config.json` and no `fizzy-do` MCP entry.
- [ ] Accepting fizzy with a valid token ends with `status` = Configured and `whoami` printing the account; the token appears in no console output, transcript, or log.
- [ ] An invalid fizzy token is reported, leaves no partial config, and does not abort the rest of the install.
- [ ] Fizzy already configured → identity printed, no token prompt, unless `-Reconfigure`.
- [ ] Accepting azure with `az` missing offers choco (when neither package manager exists), prompts before any install, and skips azure cleanly on decline.
- [ ] Accepting azure while logged out runs `az login` and sets the chosen default subscription when more than one exists.
- [ ] After an azure run, the Azure MCP server is registered at user scope; a second run adds no duplicate.
- [ ] Node/npx missing → both plugin steps skip with the exact install command printed; the skill copy still succeeds.
- [ ] `-Force -Fizzy -FizzyToken <t> -Azure -Subscription <id>` completes with no prompts.
- [ ] MCP registration works both ways: with `claude` on PATH (CLI) and with it absent (`~/.claude.json` edited, backup written, unrelated keys preserved).
- [ ] A `~/.claude.json` that PowerShell can't parse is left byte-identical, with no backup written and the manual snippet printed.
- [ ] The `irm | iex` one-liner installs the skills on a machine with no clone, and removes its temp download afterward.
- [ ] README install section leads with the PowerShell path and keeps the `cp` line for mac/Linux.

## Open questions
None blocking. Resolved during planning:
- `fizzy-do-mcp configure` self-registers the MCP entry, so the installer only *verifies* it and writes one if it's missing — no duplicate.
- MCP registration: `claude mcp add --scope user` when available, else a backed-up edit of `~/.claude.json`.
- Ship the `irm | iex` one-liner alongside the local script; piped mode is prompts-only and downloads the repo zip.
