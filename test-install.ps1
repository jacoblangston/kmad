# ponytail: one check for the only logic that can eat user data - the ~/.claude.json merge.
# Run: .\test-install.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'install.ps1')

function Assert { param([bool]$Cond, [string]$Msg) if (-not $Cond) { throw "FAIL: $Msg" } }

$cfg = Join-Path $env:TEMP "kmad-test-$([guid]::NewGuid()).json"
try {
  # existing config with unrelated keys and an existing server
  @{
    numStartups = 42
    projects    = @{ 'c:\work\sample' = @{ mcpServers = @{} } }
    mcpServers  = @{ 'fizzy-do' = @{ type = 'stdio'; command = 'cmd'; args = @('/c', 'npx --yes fizzy-do-mcp@latest'); env = @{} } }
  } | ConvertTo-Json -Depth 100 | Set-Content $cfg -Encoding UTF8

  Assert (Test-McpServer -Name 'fizzy-do' -ConfigPath $cfg) 'existing server should be detected'
  Assert (-not (Test-McpServer -Name 'azure' -ConfigPath $cfg)) 'absent server should not be detected'

  Add-McpServer -Name 'azure' -Command @('cmd', '/c', 'npx -y @azure/mcp@latest server start') -ConfigPath $cfg
  $r = Get-Content $cfg -Raw | ConvertFrom-Json
  Assert ($r.numStartups -eq 42) 'unrelated top-level keys must survive'
  Assert ($null -ne $r.projects.'c:\work\sample') 'nested keys must survive'
  Assert ($null -ne $r.mcpServers.'fizzy-do') 'existing server must survive'
  Assert ($r.mcpServers.azure.command -eq 'cmd') 'new server command'
  Assert (($r.mcpServers.azure.args -join ' ') -eq '/c npx -y @azure/mcp@latest server start') 'new server args'
  Assert ((Get-ChildItem "$cfg.bak-*").Count -eq 1) 'backup must be written'

  # idempotent: second call is a no-op, not a duplicate or a crash
  Add-McpServer -Name 'azure' -Command @('cmd', '/c', 'whatever') -ConfigPath $cfg
  $r2 = Get-Content $cfg -Raw | ConvertFrom-Json
  Assert (($r2.mcpServers.azure.args -join ' ') -eq '/c npx -y @azure/mcp@latest server start') 're-run must not overwrite'
  Assert ((Get-ChildItem "$cfg.bak-*").Count -eq 1) 're-run must not re-backup'

  # a real ~/.claude.json can have keys differing only in case - ConvertFrom-Json refuses it.
  # We must refuse to rewrite rather than throw or truncate.
  $dup = Join-Path $env:TEMP "kmad-test-$([guid]::NewGuid()).json"
  '{"mcpServers":{},"projects":{"c:/git/x":{},"C:/git/x":{}}}' | Set-Content $dup -Encoding UTF8
  $before = Get-Content $dup -Raw
  Add-McpServer -Name 'azure' -Command @('cmd', '/c', 'x') -ConfigPath $dup 3>$null
  Assert ((Get-Content $dup -Raw) -eq $before) 'unparseable config must be left byte-identical'
  Assert (-not (Get-ChildItem "$dup.bak-*" -ErrorAction SilentlyContinue)) 'no backup for a file we refused to touch'
  Remove-Item $dup -Force

  # no config file yet
  $fresh = Join-Path $env:TEMP "kmad-test-$([guid]::NewGuid()).json"
  Add-McpServer -Name 'azure' -Command @('cmd', '/c', 'x') -ConfigPath $fresh
  Assert (Test-McpServer -Name 'azure' -ConfigPath $fresh) 'must create a config when none exists'
  Remove-Item $fresh -Force

  Write-Host 'OK' -ForegroundColor Green
}
finally {
  Remove-Item $cfg, "$cfg.bak-*" -Force -ErrorAction SilentlyContinue
}

# Skill copy: core always, game seats only when named. Other folders stay.
$src = Join-Path $env:TEMP "kmad-skills-src-$([guid]::NewGuid())"
$dst = Join-Path $env:TEMP "kmad-skills-dst-$([guid]::NewGuid())"
try {
  foreach ($n in @($CoreSkills + $GameSkills)) {
    $dir = Join-Path $src $n
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content (Join-Path $dir 'SKILL.md') $n -Encoding UTF8
  }
  $Force = $true
  Install-Skills -Source $src -Dest $dst -Names $CoreSkills
  foreach ($n in $CoreSkills) { Assert (Test-Path (Join-Path $dst $n)) "core skill $n should be installed" }
  foreach ($n in $GameSkills) { Assert (-not (Test-Path (Join-Path $dst $n))) "game skill $n should not be installed with the core set" }

  New-Item -ItemType Directory -Path (Join-Path $dst 'other-skill') -Force | Out-Null
  Set-Content (Join-Path $dst 'other-skill\SKILL.md') 'keep' -Encoding UTF8
  Install-Skills -Source $src -Dest $dst -Names ($CoreSkills + $GameSkills)
  foreach ($n in $GameSkills) { Assert (Test-Path (Join-Path $dst $n)) "game skill $n should be installed when named" }
  Assert ((Get-Content (Join-Path $dst 'other-skill\SKILL.md') -Raw).Trim() -eq 'keep') 'non-kmad skill must survive'

  # a name that is not in the source is reported and does not throw
  $out = Install-Skills -Source $src -Dest $dst -Names @('kmad-missing') 3>&1 | Out-String
  Assert (-not (Test-Path (Join-Path $dst 'kmad-missing'))) 'missing source skill must not be created'
  Assert ($out -match 'kmad-missing') 'missing source skill must be warned'

  Write-Host 'OK skills' -ForegroundColor Green
}
finally {
  Remove-Item $src, $dst -Recurse -Force -ErrorAction SilentlyContinue
}

# Blank workspace: empty project list, chosen path, nothing personal, re-run keeps edits.
$ws = Join-Path $env:TEMP "kmad-ws-$([guid]::NewGuid())"
try {
  Assert ((ConvertTo-YamlSingleQuoted "C:\it's") -eq "'C:\it''s'") 'single quotes in a path must be doubled'

  Install-Workspace -Path $ws -TemplateRoot (Get-RepoRoot)
  $full = [IO.Path]::GetFullPath($ws)
  $agents = Get-Content (Join-Path $ws 'AGENTS.md') -Raw
  $yaml = Get-Content (Join-Path $ws 'workspace.yaml') -Raw
  Assert ($agents -match 'projects` starts empty|`projects` starts empty') 'AGENTS.md should describe an empty map'
  Assert ($yaml -match 'projects:\s*\[\]') 'workspace.yaml should start with an empty project list'
  Assert ($yaml -match [regex]::Escape((ConvertTo-YamlSingleQuoted $full))) 'workspace_root should be the chosen directory'
  Assert ($yaml -notmatch '(?m)^#\s+fizzy_board:') 'no tracker means no fizzy_board key'
  Assert ($yaml -notmatch '(?m)^#\s+azure_board:') 'no tracker means no azure_board key'

  function Assert-BoardKeys([string]$Text, [bool]$FizzyKey, [bool]$AzureKey) {
    Assert (($Text -match '(?m)^#\s+fizzy_board:') -eq $FizzyKey) "fizzy_board key expected $FizzyKey"
    Assert (($Text -match '(?m)^#\s+azure_board:') -eq $AzureKey) "azure_board key expected $AzureKey"
  }
  $root = Get-RepoRoot
  foreach ($case in @(
    @{ Name = 'fizzy'; Trackers = @('fizzy'); Fizzy = $true; Azure = $false }
    @{ Name = 'azure'; Trackers = @('azure'); Fizzy = $false; Azure = $true }
    @{ Name = 'both'; Trackers = @('fizzy', 'azure'); Fizzy = $true; Azure = $true }
  )) {
    $dir = Join-Path $env:TEMP "kmad-ws-$($case.Name)-$([guid]::NewGuid())"
    Install-Workspace -Path $dir -TemplateRoot $root -Trackers $case.Trackers
    $text = Get-Content (Join-Path $dir 'workspace.yaml') -Raw
    Assert ($text -match 'projects:\s*\[\]') "$($case.Name) workspace stays empty"
    Assert-BoardKeys $text $case.Fizzy $case.Azure
    Remove-Item $dir -Recurse -Force
  }
  Assert ($agents -notmatch '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}') 'AGENTS.md must not contain an email'
  Assert ($yaml -notmatch '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}') 'workspace.yaml must not contain an email'
  Assert ($agents -notmatch '\b03[a-z0-9]{20,}\b') 'AGENTS.md must not contain a board id'
  Assert ($yaml -notmatch '\b03[a-z0-9]{20,}\b') 'workspace.yaml must not contain a board id'

  Set-Content (Join-Path $ws 'AGENTS.md') 'KEEP' -Encoding UTF8 -NoNewline
  Set-Content (Join-Path $ws 'workspace.yaml') "workspace_root: 'x'`nprojects:`n- name: 'Mine'`n" -Encoding UTF8 -NoNewline
  Install-Workspace -Path $ws -TemplateRoot (Get-RepoRoot)
  Assert ((Get-Content (Join-Path $ws 'AGENTS.md') -Raw) -eq 'KEEP') 'existing AGENTS.md must be kept'
  Assert ((Get-Content (Join-Path $ws 'workspace.yaml') -Raw) -match 'Mine') 'existing workspace.yaml must be kept'

  $bare = Join-Path $env:TEMP "kmad-ws-bare-$([guid]::NewGuid())"
  $warns = Install-Workspace -Path $bare -TemplateRoot (Join-Path $env:TEMP 'kmad-no-template') 3>&1 | Out-String
  Assert ($warns -match 'template missing') 'missing template must be warned'
  Assert (-not (Test-Path (Join-Path $bare 'workspace.yaml'))) 'missing template must not write workspace.yaml'
  Remove-Item $bare -Recurse -Force -ErrorAction SilentlyContinue

  Write-Host 'OK workspace' -ForegroundColor Green
}
finally {
  Remove-Item $ws -Recurse -Force -ErrorAction SilentlyContinue
}

Assert ((Get-SkillDest -Agent claude -Scope user) -eq (Join-Path $env:USERPROFILE '.claude\skills')) 'claude skills dir'
Assert ((Get-SkillDest -Agent grok -Scope user) -eq (Join-Path $env:USERPROFILE '.grok\skills')) 'grok skills dir'
Assert ((Get-SkillDest -Agent openai -Scope user) -eq (Join-Path $env:USERPROFILE '.agents\skills')) 'openai skills dir'
$proj = Join-Path $env:TEMP "kmad-proj-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $proj | Out-Null
try {
  Push-Location $proj
  Assert ((Get-SkillDest -Agent grok -Scope project) -eq (Join-Path (Get-Location).Path '.grok\skills')) 'project scope stays in the current directory'
}
finally {
  Pop-Location
  Remove-Item $proj -Recurse -Force -ErrorAction SilentlyContinue
}
Assert ((@(Resolve-Agents -Requested claude,openai) -join ',') -eq 'claude,openai') 'named agents are kept in order'
Assert ((@(Resolve-Agents -Requested all) -join ',') -eq 'claude,grok,openai') 'all means the three agents'
Assert ((@(Resolve-Agents -Requested 'grok, claude') -join ',') -eq 'grok,claude') 'a comma-separated agent list splits'
$bad = $false
try { Resolve-Agents -Requested nope } catch { $bad = $true }
Assert $bad 'an unknown agent must fail'
Write-Host 'OK agents' -ForegroundColor Green
