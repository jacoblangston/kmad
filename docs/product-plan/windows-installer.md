# Windows installer (`install.ps1`)

## Problem
The only install instruction is `cp -r skills/* ~/.claude/skills/` — a POSIX command
that fails in PowerShell. Fizzy setup is a separate undocumented step, and there's no
Azure path at all. A Windows user has to reverse-engineer the install from the README.

## Outcome
- `.\install.ps1` on a fresh clone asks which agents to install for. Enter, or a non-interactive run with no `-Agents`, puts the six core kmad skills in `%USERPROFILE%\.claude\skills`. Grok goes to `%USERPROFILE%\.grok\skills`. OpenAI goes to `%USERPROFILE%\.agents\skills`.
- Game development is opt-in. Decline → `kmad-engine`, `kmad-shader`, `kmad-cinematic`, and `kmad-playtest` are not copied. Accept → those four party seats are installed. Already-installed game skills are left in place on a later decline.
- A workspace is opt-in and blank. Decline → no workspace directory is created. Accept → the chosen directory gets `AGENTS.md` and a `workspace.yaml` with `projects: []`. The commented project shape includes `fizzy_board` only when Fizzy configured, `azure_board` only when Azure configured, and both when both did. No sample projects, paths, or board ids are written. An existing `AGENTS.md` or `workspace.yaml` is left untouched.
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
- Copy the six core skills into the skill directory of each agent the user picked. User scope: `.claude\skills`, `.grok\skills`, `.agents\skills` under `$env:USERPROFILE`. `-Scope project` uses those same folder names under the current directory. The four game-development party seats are copied only when the user accepts game development or passes `-Games`.
- Optional blank workspace: copy `workspace/AGENTS.md` into the directory the user names, and write `workspace.yaml` with `workspace_root` set to that directory and `projects: []`. Board-id keys in the comment match the trackers that configured (`fizzy_board`, `azure_board`). The file is written after those plugin steps.
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

## Install questions
Every prompt has a switch that pre-answers it; supply all of them and the run is silent.

| # | Question | Asked when | Default | Switch |
|---|----------|-----------|---------|--------|
| 1 | Install for this user or this project? | never — parameter only | user | `-Scope user\|project` |
| 1b | Install skills for which agents? | interactive, and `-Agents` not passed | **claude** | `-Agents claude,grok,openai` |
| 2 | Overwrite existing kmad skill folders? | folders already present | Yes | `-Force` |
| 2b | Install support for game development? | interactive session | **No** | `-Games` |
| 2c | Configure a workspace? | interactive session | **No** | `-Workspace` |
| 2d | Where should the workspace be configured? | workspace accepted and no `-WorkspacePath` | `%USERPROFILE%\workspace` | `-WorkspacePath` |
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
2. Q1b agents. Enter, or a non-interactive run with no `-Agents`, means Claude only. A list or `-Agents` installs for those agents. `all` means Claude, Grok, and OpenAI.
3. Script prints where each agent's skills will go, then asks Q2b. No → core skills only. Yes or `-Games` → also the four game-development party seats. A non-interactive run without `-Games` takes the default (no) and does not throw.
4. Copies that set into each chosen agent's skill directory — asking Q2 only if any of those folders already exist. Declining overwrite keeps those folders and still copies selected skills that are not there yet.
5. Q2c workspace. No → step 6, and no workspace directory is created. Yes → Q2d unless `-WorkspacePath` was passed. Remember the directory; write the files in step 9, after the tracker plugins. A non-interactive run without `-Workspace` or `-WorkspacePath` takes the default (no). `-Workspace` alone uses `%USERPROFILE%\workspace`.
6. Q3 fizzy. No → step 9. A successful Fizzy setup marks `fizzy` for the workspace file.
7. `fizzy-do-mcp status`: already configured → print identity, ask Q5. Otherwise ask Q4 and run `configure -t`.
8. Verify with `whoami`, and confirm a `fizzy-do` entry now exists in the user MCP config — write it only if `configure` didn't. On failure print the error, leave nothing half-written, and continue.
9. Q6 azure. No → step 12. A successful Azure setup marks `azure` for the workspace file. Then, if a workspace directory was chosen, write `AGENTS.md` and an empty `workspace.yaml`. The commented project includes `fizzy_board` and/or `azure_board` only for trackers that configured. Does not copy the author's projects. Existing files in that directory stay as they are.
10. `az` missing → prereq flow (Q7/Q8). Still missing or declined → skip azure with the exact install command printed.
11. `az account show` → logged out runs `az login`; >1 subscription asks Q10 and `az account set`. Then register the Azure MCP server at user scope if it isn't already there.
12. Summary: what was installed, what was skipped and why, and "restart the agent you installed for, then run `/kmad`". Codex uses `$kmad`.

**Edge cases that matter**
- **Non-interactive session** (CI, no console): any unanswered prompt fails fast with the switch name to use, rather than hanging. Agents, game development, and the workspace are the exceptions: omitting their switches means the default (Claude only, no games, no workspace) and does not throw. `-Workspace` with no `-WorkspacePath` uses `%USERPROFILE%\workspace` and does not prompt.
- **Fresh PATH after a prereq install**: winget/choco put `node`/`az` on the machine PATH but not the current process's. Re-resolve the exe from its known install dir; if that fails, tell the user to reopen the shell and re-run — never claim success on a tool we can't invoke.
- **`~/.claude.json` hand-edit**: it's the live Claude Code config and can be large. Back it up, preserve everything else — if `claude` is on PATH, prefer the CLI and skip this path entirely.
- **Unparseable `~/.claude.json`**: real configs contain project keys differing only in case (`c:\git\x` vs `C:\git\x`), which `ConvertFrom-Json` rejects outright. Confirmed on the author's machine. Refuse to rewrite, print the snippet to paste, and carry on — never truncate a config we can't round-trip.

## Acceptance criteria
- [ ] Runs on Windows PowerShell 5.1 and PowerShell 7 without admin (base install).
- [ ] Defaults-only run (Enter for agents, No to game development and both plugins) leaves the six core kmad folders under `$env:USERPROFILE\.claude\skills`, does not copy the four game-development skills, exit 0, and zero changes to any MCP config.
- [ ] `-Agents grok` writes those skills under `$env:USERPROFILE\.grok\skills`. `-Agents openai` writes them under `$env:USERPROFILE\.agents\skills`. `-Agents all` writes all three. An unknown name fails before copying.
- [ ] Accepting game development, or passing `-Games`, also copies `kmad-engine`, `kmad-shader`, `kmad-cinematic`, and `kmad-playtest`.
- [ ] A non-interactive run without `-Games` skips game development and does not prompt or throw for that question.
- [ ] Accepting a workspace, or passing `-WorkspacePath`, writes only `AGENTS.md` and a `workspace.yaml` with `projects: []` and `workspace_root` set to that directory. The files contain no sample project, path, or real board id.
- [ ] `workspace.yaml`'s commented project includes `fizzy_board` only when Fizzy configured, `azure_board` only when Azure configured, both when both did, and neither key when neither did.
- [ ] A second workspace run leaves an existing `AGENTS.md` and `workspace.yaml` byte-identical.
- [ ] A non-interactive run without `-Workspace` and without `-WorkspacePath` skips the workspace and does not create a directory.
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
- [ ] `-Force -Games -Fizzy -FizzyToken <t> -Azure -Subscription <id>` completes with no prompts. Without `-Games`, the same line still completes and skips game development.
- [ ] MCP registration works both ways: with `claude` on PATH (CLI) and with it absent (`~/.claude.json` edited, backup written, unrelated keys preserved).
- [ ] A `~/.claude.json` that PowerShell can't parse is left byte-identical, with no backup written and the manual snippet printed.
- [ ] The `irm | iex` one-liner installs the skills on a machine with no clone, and removes its temp download afterward.
- [ ] README install section leads with the PowerShell path and keeps the `cp` line for mac/Linux.

## Open questions
None blocking. Resolved during planning:
- `fizzy-do-mcp configure` self-registers the MCP entry, so the installer only *verifies* it and writes one if it's missing — no duplicate.
- MCP registration: `claude mcp add --scope user` when available, else a backed-up edit of `~/.claude.json`.
- Ship the `irm | iex` one-liner alongside the local script; piped mode is prompts-only and downloads the repo zip.
