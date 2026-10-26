<#
.SYNOPSIS
  Installs the KMAD skills for Claude, Grok, or OpenAI, with an optional blank
  workspace, optional game-development party seats, and optional fizzy.do and Azure plugins.
.EXAMPLE
  .\install.ps1
.EXAMPLE
  .\install.ps1 -Force -Games -WorkspacePath C:\work -Fizzy -FizzyToken $t -Azure -Subscription 0000-... -InstallPrereqs
.EXAMPLE
  irm https://raw.githubusercontent.com/jacoblangston/kmad/main/install.ps1 | iex
#>
#requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('user', 'project')][string]$Scope = 'user',
  [Alias('Agents')][string[]]$AgentList,
  [switch]$Force,
  [switch]$Games,
  [switch]$Workspace,
  [string]$WorkspacePath,
  [switch]$Fizzy,
  [string]$FizzyToken,
  [switch]$Reconfigure,
  [switch]$Azure,
  [string]$Subscription,
  [switch]$InstallPrereqs
)

$ErrorActionPreference = 'Stop'
$RepoZip = 'https://github.com/jacoblangston/kmad/archive/refs/heads/main.zip'
$skipped = @()
$CoreSkills = @('kmad', 'kmad-story', 'kmad-plan', 'kmad-architect', 'kmad-dev', 'kmad-party')
$GameSkills = @('kmad-engine', 'kmad-shader', 'kmad-cinematic', 'kmad-playtest', 'kmad-art')

function Ask {
  param([string]$Question, [bool]$Default, [string]$Switch)
  if (-not [Environment]::UserInteractive) { throw "Non-interactive session: pass -$Switch to answer '$Question'" }
  $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
  $a = (Read-Host "$Question $hint").Trim()
  if (-not $a) { return $Default }
  return $a -match '^y'
}

function Have { param([string]$Exe) [bool](Get-Command $Exe -ErrorAction SilentlyContinue) }

function Update-Path {
  # ponytail: winget/choco set the machine PATH, not ours. Re-read both scopes.
  $env:PATH = ([Environment]::GetEnvironmentVariable('PATH', 'Machine'), [Environment]::GetEnvironmentVariable('PATH', 'User')) -join ';'
}

function Get-RepoRoot {
  if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'skills'))) { return $PSScriptRoot }
  if ($script:DownloadedRoot) { return $script:DownloadedRoot }
  Write-Host 'No local skills\ found - downloading the repo...' -ForegroundColor DarkGray
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $tmp = Join-Path $env:TEMP "kmad-install-$([guid]::NewGuid())"
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp 'kmad.zip'
  Invoke-WebRequest -Uri $RepoZip -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $script:TempSource = $tmp
  $script:DownloadedRoot = Join-Path $tmp 'kmad-main'
  return $script:DownloadedRoot
}

function Get-SkillSource { Join-Path (Get-RepoRoot) 'skills' }

function Get-SkillDest {
  param([string]$Agent, [ValidateSet('user', 'project')][string]$Scope = 'user')
  $folder = switch ($Agent) {
    'claude' { '.claude\skills' }
    'grok'   { '.grok\skills' }
    'openai' { '.agents\skills' }
    default  { throw "Unknown agent '$Agent'. Use claude, grok, or openai." }
  }
  $root = if ($Scope -eq 'project') { (Get-Location).Path } else { $env:USERPROFILE }
  Join-Path $root $folder
}

function Resolve-Agents {
  param([string[]]$Requested)
  $known = @('claude', 'grok', 'openai')
  if (-not $Requested -or @($Requested).Count -eq 0) {
    # ponytail: a non-interactive run with no -Agents keeps the old default, Claude.
    if (-not [Environment]::UserInteractive) { return @('claude') }
    $entered = (Read-Host 'Install skills for which agents? claude, grok, openai [claude]').Trim()
    if (-not $entered) { return @('claude') }
    $Requested = @($entered -split '[,\s]+' | Where-Object { $_ })
  }
  $picked = @()
  foreach ($name in @($Requested)) {
    foreach ($part in @($name -split '[,\s]+' | Where-Object { $_ })) {
      $n = $part.ToLower()
      if ($n -eq 'all') { return @($known) }
      if ($known -notcontains $n) { throw "Unknown agent '$part'. Use claude, grok, or openai." }
      if ($picked -notcontains $n) { $picked += $n }
    }
  }
  if (-not $picked) { throw 'No agents selected.' }
  return @($picked)
}

function ConvertTo-YamlSingleQuoted {
  param([string]$Value)
  "'" + ($Value -replace "'", "''") + "'"
}

function Install-Workspace {
  param([string]$Path, [string]$TemplateRoot, [string[]]$Trackers = @())
  $dest = [IO.Path]::GetFullPath($Path)
  New-Item -ItemType Directory -Path $dest -Force | Out-Null

  $template = Join-Path $TemplateRoot 'workspace\AGENTS.md'
  if (-not (Test-Path $template)) {
    Write-Warning "Workspace template missing: $template"
    $script:skipped += 'workspace (template missing)'
    return
  }

  $agents = Join-Path $dest 'AGENTS.md'
  if (Test-Path $agents) { Write-Host "Kept existing $agents" -ForegroundColor Yellow }
  else { Copy-Item $template $agents; Write-Host "Wrote $agents" -ForegroundColor Green }

  $yamlPath = Join-Path $dest 'workspace.yaml'
  if (Test-Path $yamlPath) { Write-Host "Kept existing $yamlPath" -ForegroundColor Yellow; return }

  # Only the trackers that actually configured get a board-id key. null means
  # that tracker is in use and this project has no board yet.
  $lines = @(
    "workspace_root: $(ConvertTo-YamlSingleQuoted $dest)"
    'projects: []'
    '# Add a project when the user names a repo.'
    "# - name: 'My App'"
    "#   path: '<path-to-repo>'"
  )
  if ($Trackers -contains 'fizzy') {
    $lines += '# fizzy_board: null means Fizzy is configured and this project has no board yet.'
    $lines += '#   fizzy_board: null'
  }
  if ($Trackers -contains 'azure') {
    $lines += '# azure_board: null means Azure Boards is configured and this project has no board yet.'
    $lines += '#   azure_board: null'
  }
  if (-not $Trackers) {
    $lines += '# No tracker configured. After Fizzy or Azure Boards is configured, add fizzy_board or azure_board. null means no board yet.'
  }
  $lines -join "`n" | Set-Content $yamlPath -Encoding UTF8
  Write-Host "Wrote $yamlPath" -ForegroundColor Green
}

function Install-Skills {
  param([string]$Source, [string]$Dest, [string[]]$Names)
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  $present = @($Names | Where-Object { Test-Path (Join-Path $Source $_) })
  $missing = @($Names | Where-Object { -not (Test-Path (Join-Path $Source $_)) })
  if ($missing) { Write-Warning "Not in this source, skipped: $($missing -join ', ')" }
  if (-not $present) { return }

  $existing = @($present | Where-Object { Test-Path (Join-Path $Dest $_) })
  $copy = @($present)
  if ($existing -and -not $Force) {
    if (-not (Ask "Overwrite existing skills ($($existing -join ', '))?" $true 'Force')) {
      Write-Host 'Kept existing skills.' -ForegroundColor Yellow
      # Still copy skills from this run that are not on disk yet.
      $copy = @($present | Where-Object { $existing -notcontains $_ })
    }
  }
  # ponytail: only the named folders are touched; anything else in the skills dir is left alone.
  foreach ($n in $copy) {
    $target = Join-Path $Dest $n
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item (Join-Path $Source $n) $target -Recurse
  }
  if ($copy) { Write-Host "Installed $($copy.Count) skills to $Dest" -ForegroundColor Green }
}

function Get-McpConfigPath { Join-Path $env:USERPROFILE '.claude.json' }

function Read-McpConfig {
  # ponytail: a real ~/.claude.json can hold keys that differ only in case (c:\ vs C:\),
  # which ConvertFrom-Json refuses. Return $null rather than throw - callers must not
  # rewrite a file they can't faithfully parse.
  param([string]$ConfigPath)
  if (-not (Test-Path $ConfigPath)) { return [pscustomobject]@{} }
  try { return Get-Content $ConfigPath -Raw | ConvertFrom-Json }
  catch { return $null }
}

function Test-McpServer {
  param([string]$Name, [string]$ConfigPath = (Get-McpConfigPath))
  $cfg = Read-McpConfig $ConfigPath
  if (-not $cfg) { return $false }
  [bool]($cfg.PSObject.Properties['mcpServers'] -and $cfg.mcpServers.PSObject.Properties[$Name])
}

function Add-McpServer {
  param([string]$Name, [string[]]$Command, [string]$ConfigPath = (Get-McpConfigPath))
  if (Test-McpServer -Name $Name -ConfigPath $ConfigPath) { Write-Host "MCP '$Name' already registered." -ForegroundColor DarkGray; return }

  if ((Have 'claude') -and $ConfigPath -eq (Get-McpConfigPath)) {
    & claude mcp add --scope user $Name -- @Command
    if ($LASTEXITCODE -eq 0) { Write-Host "Registered MCP '$Name' via the claude CLI." -ForegroundColor Green; return }
    Write-Warning "claude mcp add failed (exit $LASTEXITCODE); falling back to editing $ConfigPath"
  }

  $cfg = Read-McpConfig $ConfigPath
  $entry = [pscustomobject]@{ type = 'stdio'; command = $Command[0]; args = @($Command[1..($Command.Count - 1)]); env = [pscustomobject]@{} }

  if (-not $cfg) {
    Write-Warning "Can't safely rewrite $ConfigPath (PowerShell couldn't parse it - duplicate keys?). Nothing was changed."
    Write-Host "Add this to `"mcpServers`" in $ConfigPath yourself, or install the claude CLI and re-run:" -ForegroundColor Yellow
    Write-Host "  `"$Name`": $($entry | ConvertTo-Json -Depth 5 -Compress)"
    $script:skipped += "$Name MCP registration (config not parseable)"
    return
  }

  if (Test-Path $ConfigPath) { Copy-Item $ConfigPath "$ConfigPath.bak-$(Get-Date -Format yyyyMMddHHmmss)" }
  if (-not $cfg.PSObject.Properties['mcpServers']) { $cfg | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) }
  $cfg.mcpServers | Add-Member -NotePropertyName $Name -NotePropertyValue $entry
  $cfg | ConvertTo-Json -Depth 100 | Set-Content $ConfigPath -Encoding UTF8
  Write-Host "Registered MCP '$Name' in $ConfigPath (backup written)." -ForegroundColor Green
}

function Install-Prereq {
  param([string]$Exe, [string]$WingetId, [string]$ChocoId, [string]$Label)
  if (Have $Exe) { return $true }

  $mgr = if (Have 'winget') { 'winget' } elseif (Have 'choco') { 'choco' } else { $null }
  if (-not $mgr) {
    if (-not ($InstallPrereqs -or (Ask "$Label is missing and neither winget nor choco is available. Install Chocolatey?" $false 'InstallPrereqs'))) { return $false }
    Write-Host 'Installing Chocolatey (needs an elevated shell)...' -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Update-Path
    if (-not (Have 'choco')) { Write-Warning 'Chocolatey install did not land. Re-run from an elevated shell.'; return $false }
    $mgr = 'choco'
  }

  if (-not ($InstallPrereqs -or (Ask "Install $Label via $mgr?" $false 'InstallPrereqs'))) { return $false }
  if ($mgr -eq 'winget') { & winget install --id $WingetId -e --accept-source-agreements --accept-package-agreements }
  else { & choco install $ChocoId -y }
  Update-Path
  if (Have $Exe) { return $true }
  Write-Warning "$Label was installed but isn't on this session's PATH. Open a new shell and re-run."
  return $false
}

function Install-FizzyPlugin {
  if (-not (Install-Prereq -Exe 'npx' -WingetId 'OpenJS.NodeJS.LTS' -ChocoId 'nodejs-lts' -Label 'Node.js')) {
    $script:skipped += 'fizzy (Node.js missing - winget install OpenJS.NodeJS.LTS)'
    return $false
  }
  $status = (& npx --yes fizzy-do-mcp@latest status 2>&1 | Out-String)
  if ($status -match 'Status:\s*Configured') {
    Write-Host ($status -split "`n" | Where-Object { $_ -match 'Account:|Token:' }) -ForegroundColor DarkGray
    if (-not ($Reconfigure -or (Ask 'Fizzy is already configured. Reconfigure?' $false 'Reconfigure'))) {
      Add-McpServer -Name 'fizzy-do' -Command @('cmd', '/c', 'npx --yes fizzy-do-mcp@latest')
      return $true
    }
  }
  # ponytail: no -t when interactive - let fizzy prompt for the token so it never
  # hits our command line, our transcript, or the process list.
  if ($FizzyToken) { & npx --yes fizzy-do-mcp@latest configure -t $FizzyToken }
  else { & npx --yes fizzy-do-mcp@latest configure }

  $who = (& npx --yes fizzy-do-mcp@latest whoami 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Fizzy setup failed:`n$who"
    $script:skipped += 'fizzy (setup failed)'
    return $false
  }
  Write-Host 'Fizzy configured.' -ForegroundColor Green
  # configure auto-registers the MCP server; only write it ourselves if it didn't.
  Add-McpServer -Name 'fizzy-do' -Command @('cmd', '/c', 'npx --yes fizzy-do-mcp@latest')
  return $true
}

function Install-AzurePlugin {
  if (-not (Install-Prereq -Exe 'az' -WingetId 'Microsoft.AzureCLI' -ChocoId 'azure-cli' -Label 'Azure CLI')) {
    $script:skipped += 'azure (Azure CLI missing - winget install Microsoft.AzureCLI)'
    return $false
  }
  if (-not (Install-Prereq -Exe 'npx' -WingetId 'OpenJS.NodeJS.LTS' -ChocoId 'nodejs-lts' -Label 'Node.js')) {
    $script:skipped += 'azure (Node.js missing - winget install OpenJS.NodeJS.LTS)'
    return $false
  }

  & az account show -o none 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Not signed in to Azure - launching az login...' -ForegroundColor Cyan
    & az login -o none
    if ($LASTEXITCODE -ne 0) { Write-Warning 'az login failed.'; $script:skipped += 'azure (login failed)'; return $false }
  }

  if ($Subscription) { & az account set --subscription $Subscription }
  else {
    $subs = @(& az account list --query '[].{name:name,id:id}' -o json | ConvertFrom-Json)
    if ($subs.Count -gt 1) {
      for ($i = 0; $i -lt $subs.Count; $i++) { Write-Host "  [$i] $($subs[$i].name)  $($subs[$i].id)" }
      $pick = (Read-Host "Default subscription [0-$($subs.Count - 1)], blank to keep current").Trim()
      if ($pick -match '^\d+$' -and [int]$pick -lt $subs.Count) { & az account set --subscription $subs[[int]$pick].id }
    }
  }
  Write-Host "Azure account: $(& az account show --query name -o tsv)" -ForegroundColor Green
  Add-McpServer -Name 'azure' -Command @('cmd', '/c', 'npx -y @azure/mcp@latest server start')
  return $true
}

function Main {
  $agents = @(Resolve-Agents -Requested $AgentList)
  Write-Host "`nKMAD installer" -ForegroundColor Cyan
  foreach ($agent in $agents) {
    Write-Host "  $agent skills -> $(Get-SkillDest -Agent $agent -Scope $Scope)"
  }
  Write-Host "  game development (engine, shader, cinematic, playtest, art) is opt-in"
  Write-Host "  workspace: blank, opt-in"
  Write-Host "  plugins: fizzy.do and Azure are opt-in`n"

  # ponytail: default is no, so a non-interactive run without -Games declines
  # instead of throwing. -Games is the only unattended opt-in.
  $names = @($CoreSkills)
  $installGames = [bool]$Games
  if (-not $installGames -and [Environment]::UserInteractive) {
    $installGames = Ask 'Install support for game development?' $false 'Games'
  }
  if ($installGames) { $names += $GameSkills } else { $skipped += 'game development (declined)' }

  # Same rule as -Games: a non-interactive run declines unless a switch opts in.
  # -WorkspacePath implies yes. -Workspace alone uses the default directory.
  $wantWorkspace = [bool]($Workspace -or $WorkspacePath)
  if (-not $wantWorkspace -and [Environment]::UserInteractive) {
    $wantWorkspace = Ask 'Configure a workspace?' $false 'Workspace'
  }
  $wsPath = $null
  if ($wantWorkspace) {
    $wsPath = $WorkspacePath
    if (-not $wsPath) {
      $defaultWs = Join-Path $env:USERPROFILE 'workspace'
      if ([Environment]::UserInteractive) {
        $entered = (Read-Host "Where should the workspace be configured? [$defaultWs]").Trim()
        if ($entered) { $wsPath = $entered } else { $wsPath = $defaultWs }
      } else { $wsPath = $defaultWs }
    }
  } else { $skipped += 'workspace (declined)' }

  try {
    $repoRoot = Get-RepoRoot
    foreach ($agent in $agents) {
      Install-Skills -Source (Join-Path $repoRoot 'skills') -Dest (Get-SkillDest -Agent $agent -Scope $Scope) -Names $names
    }
    # Board-id keys are written only for trackers that finished configuring.
    $trackers = @()
    if ($Fizzy -or (Ask 'Enable the fizzy.do plugin (card tracking)?' $false 'Fizzy')) {
      if ((@(Install-FizzyPlugin)[-1]) -eq $true) { $trackers += 'fizzy' }
    } else { $skipped += 'fizzy (declined)' }
    if ($Azure -or (Ask 'Enable the Azure plugin (Azure MCP via az login)?' $false 'Azure')) {
      if ((@(Install-AzurePlugin)[-1]) -eq $true) { $trackers += 'azure' }
    } else { $skipped += 'azure (declined)' }
    if ($wsPath) { Install-Workspace -Path $wsPath -TemplateRoot $repoRoot -Trackers $trackers }
  }
  finally {
    if ($script:TempSource) { Remove-Item $script:TempSource -Recurse -Force -ErrorAction SilentlyContinue }
  }

  Write-Host ''
  foreach ($s in $skipped) { Write-Host "Skipped: $s" -ForegroundColor Yellow }
  Write-Host "`nDone. Restart the agent you installed for, then run /kmad. In Codex, run `$kmad." -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') { Main }
