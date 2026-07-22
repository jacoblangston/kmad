<#
.SYNOPSIS
  Installs the KMAD skills for Claude Code, with optional fizzy.do and Azure plugins.
.EXAMPLE
  .\install.ps1
.EXAMPLE
  .\install.ps1 -Force -Fizzy -FizzyToken $t -Azure -Subscription 0000-... -InstallPrereqs
.EXAMPLE
  irm https://raw.githubusercontent.com/jacoblangston/kmad/main/install.ps1 | iex
#>
#requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('user', 'project')][string]$Scope = 'user',
  [switch]$Force,
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

function Get-SkillSource {
  if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'skills'))) { return Join-Path $PSScriptRoot 'skills' }
  Write-Host 'No local skills\ found - downloading the repo...' -ForegroundColor DarkGray
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $tmp = Join-Path $env:TEMP "kmad-install-$([guid]::NewGuid())"
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp 'kmad.zip'
  Invoke-WebRequest -Uri $RepoZip -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $script:TempSource = $tmp
  return (Join-Path $tmp 'kmad-main\skills')
}

function Install-Skills {
  param([string]$Source, [string]$Dest)
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  $names = Get-ChildItem $Source -Directory | Select-Object -ExpandProperty Name
  $existing = $names | Where-Object { Test-Path (Join-Path $Dest $_) }
  if ($existing -and -not $Force) {
    if (-not (Ask "Overwrite existing skills ($($existing -join ', '))?" $true 'Force')) {
      Write-Host 'Kept existing skills.' -ForegroundColor Yellow
      return
    }
  }
  # ponytail: only our own folders are touched; anything else in the skills dir is left alone.
  foreach ($n in $names) {
    $target = Join-Path $Dest $n
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item (Join-Path $Source $n) $target -Recurse
  }
  Write-Host "Installed $($names.Count) skills to $Dest" -ForegroundColor Green
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
    return
  }
  $status = (& npx --yes fizzy-do-mcp@latest status 2>&1 | Out-String)
  if ($status -match 'Status:\s*Configured') {
    Write-Host ($status -split "`n" | Where-Object { $_ -match 'Account:|Token:' }) -ForegroundColor DarkGray
    if (-not ($Reconfigure -or (Ask 'Fizzy is already configured. Reconfigure?' $false 'Reconfigure'))) {
      Add-McpServer -Name 'fizzy-do' -Command @('cmd', '/c', 'npx --yes fizzy-do-mcp@latest')
      return
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
    return
  }
  Write-Host 'Fizzy configured.' -ForegroundColor Green
  # configure auto-registers the MCP server; only write it ourselves if it didn't.
  Add-McpServer -Name 'fizzy-do' -Command @('cmd', '/c', 'npx --yes fizzy-do-mcp@latest')
}

function Install-AzurePlugin {
  if (-not (Install-Prereq -Exe 'az' -WingetId 'Microsoft.AzureCLI' -ChocoId 'azure-cli' -Label 'Azure CLI')) {
    $script:skipped += 'azure (Azure CLI missing - winget install Microsoft.AzureCLI)'
    return
  }
  if (-not (Install-Prereq -Exe 'npx' -WingetId 'OpenJS.NodeJS.LTS' -ChocoId 'nodejs-lts' -Label 'Node.js')) {
    $script:skipped += 'azure (Node.js missing - winget install OpenJS.NodeJS.LTS)'
    return
  }

  & az account show -o none 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Not signed in to Azure - launching az login...' -ForegroundColor Cyan
    & az login -o none
    if ($LASTEXITCODE -ne 0) { Write-Warning 'az login failed.'; $script:skipped += 'azure (login failed)'; return }
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
}

function Main {
  Write-Host "`nKMAD installer" -ForegroundColor Cyan
  $dest = if ($Scope -eq 'project') { Join-Path (Get-Location) '.claude\skills' } else { Join-Path $env:USERPROFILE '.claude\skills' }
  Write-Host "  skills -> $dest"
  Write-Host "  plugins: fizzy.do and Azure are opt-in`n"

  try {
    Install-Skills -Source (Get-SkillSource) -Dest $dest
    if ($Fizzy -or (Ask 'Enable the fizzy.do plugin (card tracking)?' $false 'Fizzy')) { Install-FizzyPlugin } else { $skipped += 'fizzy (declined)' }
    if ($Azure -or (Ask 'Enable the Azure plugin (Azure MCP via az login)?' $false 'Azure')) { Install-AzurePlugin } else { $skipped += 'azure (declined)' }
  }
  finally {
    if ($script:TempSource) { Remove-Item $script:TempSource -Recurse -Force -ErrorAction SilentlyContinue }
  }

  Write-Host ''
  foreach ($s in $skipped) { Write-Host "Skipped: $s" -ForegroundColor Yellow }
  Write-Host "`nDone. Restart Claude Code, then run /kmad" -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') { Main }
