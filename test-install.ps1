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
