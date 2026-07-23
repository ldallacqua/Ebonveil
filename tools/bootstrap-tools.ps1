#Requires -Version 5.1
<#
.SYNOPSIS
  Download external modding tools (LOOT, SSEEdit, BethINI Pie) into mo2/tools and
  register them as MO2 custom executables. Binaries are never committed (ADR 0012).
.NOTES
  GitHub tools need no auth. Nexus tools use the key from tools/nexus-auth.ps1 or
  env NEXUS_API_KEY; without it (or without Nexus Premium API downloads) the tool
  is skipped with a manual URL. Idempotent: re-run any time; -Force re-extracts.
#>
[CmdletBinding()]
param(
  [string[]]$Only,
  [switch]$Force,
  [switch]$RestartMo2   # if MO2 is running, stop it, install, then relaunch (safe ini edits)
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Nexus.ps1')
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Mo2.ps1')

$Mo2 = Join-Path $Root 'mo2'
$Ini = Join-Path $Mo2 'ModOrganizer.ini'
$Cfg = Get-Content (Join-Path $Root 'manifest\tools.json') -Raw | ConvertFrom-Json
$InstallRoot = Join-Path $Root ($Cfg.installDir -replace '/', '\')
$CacheDir = Join-Path $Root '.cache\tools'
$GamePath = 'C:\Steam\steamapps\common\Skyrim Special Edition'

New-Item -ItemType Directory -Force -Path $InstallRoot, $CacheDir | Out-Null
$Seven = Find-7Zip

function Resolve-ToolExe {
  param([string]$Dir, [string]$Hint)
  $all = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Filter *.exe -EA SilentlyContinue)
  if ($all.Count -eq 0) { return $null }
  if ($Hint) {
    $exact = $all | Where-Object { $_.Name -ieq $Hint } | Select-Object -First 1
    if ($exact) { return $exact }
    $base = [IO.Path]::GetFileNameWithoutExtension($Hint)
    $partial = $all | Where-Object { $_.BaseName -match [regex]::Escape($base) } | Select-Object -First 1
    if ($partial) { return $partial }
  }
  $filtered = @($all | Where-Object { $_.Name -notmatch '(?i)unins|setup|vc_?redist|crash|quickautoclean' })
  if ($filtered.Count -eq 0) { $filtered = $all }
  return ($filtered | Sort-Object Length -Descending | Select-Object -First 1)
}

function Expand-Into {
  param([string]$Archive, [string]$Dest)
  if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
  $tmp = Join-Path $CacheDir ('x-' + [IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  & $Seven x -y "-o$tmp" $Archive | Out-Null
  # collapse a single nested top-level folder (common in tool archives)
  $entries = @(Get-ChildItem -LiteralPath $tmp -Force)
  if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) {
    Move-Item $entries[0].FullName $Dest
    Remove-Item $tmp -Recurse -Force
  } else {
    Move-Item $tmp $Dest
  }
}

function Get-GithubAsset {
  param([string]$Repo, [string]$AssetMatch, [string]$OutDir)
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
    -Headers @{ 'User-Agent' = 'EbonveilTools/1.0'; Accept = 'application/vnd.github+json' }
  $asset = @($rel.assets | Where-Object { $_.name -match $AssetMatch } | Select-Object -First 1)
  if (-not $asset) { throw "No asset matching /$AssetMatch/ in $Repo $($rel.tag_name)" }
  $dest = Join-Path $OutDir $asset[0].name
  if (-not (Test-Path $dest)) {
    Write-Host "  downloading $($asset[0].name) ($([math]::Round($asset[0].size/1MB,1)) MB)"
    Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $dest -UseBasicParsing
  }
  return [PSCustomObject]@{ Path = $dest; Version = $rel.tag_name }
}

function Get-NexusToolArchive {
  param($Tool, [string]$OutDir, $Runtime, [string]$ApiKey)
  $files = Invoke-NexusApi -ApiKey $ApiKey -Path "/v1/games/$($Tool.nexus.domain)/mods/$($Tool.nexus.modId)/files.json"
  $list = @($files.files)
  if (-not $list.Count) { throw 'No Nexus files returned' }
  $modShape = [PSCustomObject]@{
    id        = $Tool.id
    nexus     = $Tool.nexus
    selection = [PSCustomObject]@{ platformAware = $false; matchGameVersion = $false }
  }
  $chosen = Select-NexusFileForRuntime -FileList $list -Mod $modShape -Runtime $Runtime
  $dest = Join-Path $OutDir $chosen.file_name
  if (-not (Test-Path $dest)) {
    $links = Invoke-NexusApi -ApiKey $ApiKey -Path "/v1/games/$($Tool.nexus.domain)/mods/$($Tool.nexus.modId)/files/$($chosen.file_id)/download_link.json"
    $uri = @($links)[0].URI
    if (-not $uri) { throw 'No download URI (Nexus Premium required for API downloads)' }
    Write-Host "  downloading $($chosen.file_name)"
    Invoke-WebRequest -Uri $uri -OutFile $dest -UseBasicParsing
  }
  return [PSCustomObject]@{ Path = $dest; Version = $chosen.version }
}

# --- run ---
# MO2 rewrites ModOrganizer.ini on exit, so tool registration must happen while it is
# closed. Refuse if MO2 is up (unless -RestartMo2, which cycles it for us).
$mo2WasRunning = $false
if (Test-Mo2Running) {
  if ($RestartMo2) { $mo2WasRunning = Stop-Mo2 }
  else { Assert-Mo2NotRunning -ScriptHint './tools/bootstrap-tools.ps1' }
}
Confirm-Mo2Ini -RepoRoot $Root -GamePath $GamePath

$runtime = $null
try { $runtime = Get-SkyrimRuntime -GamePath $GamePath } catch { }
$apiKey = Get-NexusApiKey -RepoRoot $Root

$targets = @($Cfg.tools | Where-Object { -not $Only -or $Only -contains $_.id })
Write-Host "=== Ebonveil tools bootstrap ($($targets.Count)) ==="

foreach ($tool in $targets) {
  Write-Host "`n--- $($tool.name) [$($tool.id)] ---"
  $dest = Join-Path $InstallRoot $tool.id
  $exe = Resolve-ToolExe -Dir $dest -Hint $tool.exe

  if ($exe -and -not $Force) {
    Write-Host "  present: $($exe.FullName)"
  } else {
    try {
      if ($tool.source -eq 'github') {
        $dl = Get-GithubAsset -Repo $tool.github.repo -AssetMatch $tool.github.assetMatch -OutDir $CacheDir
      } elseif ($tool.source -eq 'nexus') {
        if (-not $apiKey) {
          Write-Warning "  no Nexus API key; skipping. Manual: https://www.nexusmods.com/$($tool.nexus.domain)/mods/$($tool.nexus.modId)"
          continue
        }
        $dl = Get-NexusToolArchive -Tool $tool -OutDir $CacheDir -Runtime $runtime -ApiKey $apiKey
      } else {
        Write-Warning "  unknown source '$($tool.source)'"; continue
      }
      Expand-Into -Archive $dl.Path -Dest $dest
      $exe = Resolve-ToolExe -Dir $dest -Hint $tool.exe
      if (-not $exe) { throw "no .exe found after extracting to $dest" }
      Write-Host "  installed $($tool.name) $($dl.Version) -> $($exe.FullName)"
    } catch {
      Write-Warning "  failed: $_"
      if ($tool.source -eq 'nexus') {
        Write-Host "  Manual: https://www.nexusmods.com/$($tool.nexus.domain)/mods/$($tool.nexus.modId)"
      }
      continue
    }
  }

  if ($tool.mo2Executable -and $exe) {
    $binFs = $exe.FullName -replace '\\', '/'
    $wdFs = (Split-Path $exe.FullName -Parent) -replace '\\', '/'
    $toolArgs = if ($tool.mo2Executable.args) { [string]$tool.mo2Executable.args } else { '' }
    [void](Add-Mo2Executable -Ini $Ini -Title $tool.mo2Executable.title -Binary $binFs -WorkingDir $wdFs -Arguments $toolArgs)
  }
}

Write-Host "`n=== tools bootstrap complete ==="
if ($mo2WasRunning) {
  Start-Mo2 | Out-Null
} else {
  Write-Host 'Restart MO2 if open. Launch each tool from the MO2 executables dropdown.'
}
