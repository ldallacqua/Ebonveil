#Requires -Version 5.1
<#
.SYNOPSIS
  Install M1 essentials into the Ebonveil MO2 instance from mo2/downloads.
.NOTES
  Uses .ebonveil-resolved.json from restore-mods.ps1 when present; otherwise picks
  newest download matching -<modId>- (never hardcodes archive versions).
#>
[CmdletBinding()]
param(
  [switch]$RestartMo2   # if MO2 is running, stop it, install, then relaunch (safe ini/profile edits)
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Nexus.ps1')
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Mo2.ps1')

$Mo2 = Join-Path $Root 'mo2'
$Ini = Join-Path $Mo2 'ModOrganizer.ini'
$Downloads = Join-Path $Mo2 'downloads'
$Mods = Join-Path $Mo2 'mods'
$Plugins = Join-Path $Mo2 'plugins'
$ProfileDir = Join-Path $Mo2 'profiles\Default'
$ResolvedPath = Join-Path $Downloads '.ebonveil-resolved.json'
$GamePath = 'C:\Steam\steamapps\common\Skyrim Special Edition'
$seven = Find-7Zip

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$resolved = $null
if (Test-Path -LiteralPath $ResolvedPath) {
  $resolved = Get-Content -LiteralPath $ResolvedPath -Raw | ConvertFrom-Json
}

function Get-ArchiveForMod {
  param(
    [string]$ModKey,
    [int]$ModId,
    [string[]]$NameExclude = @()
  )
  if ($resolved -and $resolved.$ModKey -and $resolved.$ModKey.fileName) {
    $p = Join-Path $Downloads $resolved.$ModKey.fileName
    if (Test-Path -LiteralPath $p) { return Get-Item -LiteralPath $p }
  }
  $hit = Find-DownloadByModId -DownloadsDir $Downloads -ModId $ModId -NameExclude $NameExclude
  if (-not $hit) { throw "No download found for $ModKey (nexus modId $ModId). Run tools/restore-mods.ps1 first." }
  return $hit
}

function Write-MetaIni {
  param(
    [string]$ModDir,
    [int]$ModId,
    [string]$Version,
    [string]$InstallationFile,
    [string]$Url,
    [int]$FileId = 0
  )
  # meta.ini gameName MUST be the MO2 game SHORT name (gameShortName()), not the display name.
  # SkyrimSE plugin: gameShortName()="SkyrimSE"; display gameName()="Skyrim Special Edition".
  # Wrong value triggers MO2's "this mod is for a different game" flag (ADR 0008).
  $lines = @(
    '[General]'
    'gameName=SkyrimSE'
    "modid=$ModId"
    "version=$Version"
    'newestVersion='
    'category=0'
    "installationFile=$InstallationFile"
    'repository=Nexus'
    "url=$Url"
    "nexusUrl=$Url"
    'ignoredVersion='
    ''
    '[installedFiles]'
    "1\modid=$ModId"
    "1\fileid=$FileId"
    'size=1'
  )
  [System.IO.File]::WriteAllLines((Join-Path $ModDir 'meta.ini'), $lines, $utf8NoBom)
}

function Get-ResolvedMeta {
  param([string]$ModKey, [int]$FallbackModId, [string]$FallbackUrl)
  if ($resolved -and $resolved.$ModKey) {
    return [PSCustomObject]@{
      ModId   = [int]$resolved.$ModKey.modId
      Version = [string]$resolved.$ModKey.version
      FileId  = [int]$resolved.$ModKey.fileId
      Url     = [string]$resolved.$ModKey.url
    }
  }
  return [PSCustomObject]@{
    ModId = $FallbackModId; Version = ''; FileId = 0; Url = $FallbackUrl
  }
}

function Install-RootBuilder {
  $archive = Get-ArchiveForMod -ModKey 'root-builder' -ModId 31720
  $dest = Join-Path $Plugins 'rootbuilder'
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  $tmp = Join-Path $Root '.cache\install-rb'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  & $seven x -y "-o$tmp" $archive.FullName | Out-Null
  if (-not (Test-Path (Join-Path $tmp 'rootbuilder\__init__.py'))) {
    throw 'Root Builder archive layout unexpected'
  }
  Copy-Item (Join-Path $tmp 'rootbuilder') $Plugins -Recurse -Force
  Write-Host "Root Builder plugin -> $dest (from $($archive.Name))"
}

function Install-Skse {
  $runtime = Get-SkyrimRuntime -GamePath $GamePath
  $exclude = @()
  if ($runtime.Platform -eq 'Steam') { $exclude = @('GOG') }
  $archive = Get-ArchiveForMod -ModKey 'skse64' -ModId 30379 -NameExclude $exclude
  $meta = Get-ResolvedMeta -ModKey 'skse64' -FallbackModId 30379 -FallbackUrl 'https://www.nexusmods.com/skyrimspecialedition/mods/30379'
  $verLabel = if ($meta.Version) { $meta.Version } else { 'latest' }
  $modName = "SKSE64 $verLabel"
  $modDir = Join-Path $Mods $modName

  # Remove prior SKSE64* installs
  Get-ChildItem -LiteralPath $Mods -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'SKSE64*' } |
    Remove-Item -Recurse -Force

  $tmp = Join-Path $Root '.cache\install-skse'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  & $seven x -y "-o$tmp" $archive.FullName | Out-Null

  $inner = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName 'skse64_loader.exe')
  } | Select-Object -First 1
  if (-not $inner) { throw 'SKSE extract missing skse64_loader.exe' }

  New-Item -ItemType Directory -Force -Path (Join-Path $modDir 'root') | Out-Null
  $scripts = Join-Path $inner.FullName 'Data\Scripts'
  if (-not (Test-Path $scripts)) { throw 'SKSE extract missing Data\Scripts' }
  Copy-Item $scripts (Join-Path $modDir 'Scripts') -Recurse -Force
  Copy-Item (Join-Path $inner.FullName 'skse64_loader.exe') (Join-Path $modDir 'root\skse64_loader.exe') -Force
  $dlls = @(Get-ChildItem -LiteralPath $inner.FullName -Filter 'skse64_*.dll' -File)
  if ($dlls.Count -eq 0) { throw 'SKSE extract missing skse64_*.dll' }
  foreach ($dll in $dlls) {
    Copy-Item $dll.FullName (Join-Path $modDir "root\$($dll.Name)") -Force
  }

  Write-MetaIni -ModDir $modDir -ModId $meta.ModId -Version $verLabel -InstallationFile $archive.Name `
    -Url $meta.Url -FileId $meta.FileId
  Write-Host "SKSE mod -> $modDir (from $($archive.Name); runtime $($runtime.Version)/$($runtime.Platform))"
  return $modName
}

function Install-AddressLibrary {
  $archive = Get-ArchiveForMod -ModKey 'address-library' -ModId 32444
  $meta = Get-ResolvedMeta -ModKey 'address-library' -FallbackModId 32444 -FallbackUrl 'https://www.nexusmods.com/skyrimspecialedition/mods/32444'
  $modName = 'Address Library for SKSE Plugins'
  $modDir = Join-Path $Mods $modName
  if (Test-Path $modDir) { Remove-Item $modDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $modDir | Out-Null
  & $seven x -y "-o$modDir" $archive.FullName | Out-Null
  if (-not (Test-Path (Join-Path $modDir 'SKSE\Plugins'))) { throw 'Address Library layout unexpected' }
  $ver = if ($meta.Version) { $meta.Version } else { '' }
  Write-MetaIni -ModDir $modDir -ModId $meta.ModId -Version $ver -InstallationFile $archive.Name `
    -Url $meta.Url -FileId $meta.FileId
  Write-Host "Address Library -> $modDir (from $($archive.Name))"
  return $modName
}

function Install-SkyUi {
  $archive = Get-ArchiveForMod -ModKey 'skyui' -ModId 12604
  $meta = Get-ResolvedMeta -ModKey 'skyui' -FallbackModId 12604 -FallbackUrl 'https://www.nexusmods.com/skyrimspecialedition/mods/12604'
  $modName = 'SkyUI'
  $modDir = Join-Path $Mods $modName
  if (Test-Path $modDir) { Remove-Item $modDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $modDir | Out-Null
  & $seven x -y "-o$modDir" $archive.FullName | Out-Null
  if (-not (Test-Path (Join-Path $modDir 'SkyUI_SE.esp'))) { throw 'SkyUI missing esp' }
  $ver = if ($meta.Version) { $meta.Version } else { '' }
  Write-MetaIni -ModDir $modDir -ModId $meta.ModId -Version $ver -InstallationFile $archive.Name `
    -Url $meta.Url -FileId $meta.FileId
  Write-Host "SkyUI -> $modDir (from $($archive.Name))"
  return $modName
}

function Update-PluginsTxt {
  $path = Join-Path $ProfileDir 'plugins.txt'
  $lines = @()
  if (Test-Path $path) { $lines = @(Get-Content $path) }
  $lines = @($lines | Where-Object { $_ -notmatch 'SkyUI_SE\.esp' -and $_ -notmatch '^# This file was automatically' })
  $lines = @('# This file was automatically generated by Mod Organizer / Ebonveil') + $lines + @('*SkyUI_SE.esp')
  [System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

  $lo = Join-Path $ProfileDir 'loadorder.txt'
  $loLines = @()
  if (Test-Path $lo) { $loLines = @(Get-Content $lo) }
  $loLines = @($loLines | Where-Object { $_ -ne 'SkyUI_SE.esp' -and $_ -notmatch '^# This file was automatically' })
  $loLines = @('# This file was automatically generated by Mod Organizer / Ebonveil') + $loLines + @('SkyUI_SE.esp')
  [System.IO.File]::WriteAllLines($lo, $loLines, $utf8NoBom)
  Write-Host 'Enabled SkyUI_SE.esp in plugins/loadorder'
}

function Update-SkseExecutable {
  # Idempotent SKSE launch entry via the shared registrar (handles last-section case).
  $loader = ($GamePath -replace '\\', '/') + '/skse64_loader.exe'
  $wd = ($GamePath -replace '\\', '/')
  [void](Add-Mo2Executable -Ini $Ini -Title 'SKSE' -Binary $loader -WorkingDir $wd `
      -SteamAppID '489830' -Select)
}

Write-Host '=== Ebonveil M1 install ==='
# This script edits ModOrganizer.ini AND the profile modlist/plugins, all of which MO2
# rewrites on exit. Refuse if MO2 is running unless -RestartMo2 cycles it for us.
$mo2WasRunning = $false
if (Test-Mo2Running) {
  if ($RestartMo2) { $mo2WasRunning = Stop-Mo2 }
  else { Assert-Mo2NotRunning -ScriptHint './tools/install-m1.ps1' }
}
Confirm-Mo2Ini -RepoRoot $Root -GamePath $GamePath
Install-RootBuilder
$skse = Install-Skse
$addr = Install-AddressLibrary
$sky = Install-SkyUi
# Place each mod under its manifest category separator (ADR 0014).
Update-Mo2ModlistPlacements -ProfileDir $ProfileDir -ModsDir $Mods -RepoRoot $Root -Placements @(
  @{ Name = $sky;  Separator = 'User Interface' }
  @{ Name = $addr; Separator = 'Frameworks & Resources' }
  @{ Name = $skse; Separator = 'Script Extender & Core' }
)
Sync-Mo2ManagedSeparators -ProfileDir $ProfileDir -ModsDir $Mods -RepoRoot $Root
Update-PluginsTxt
Update-SkseExecutable
Write-Host '=== M1 install complete ==='
if ($mo2WasRunning) {
  Start-Mo2 | Out-Null
} else {
  Write-Host 'Restart MO2 if it is open so the Root Builder plugin + executables load.'
}
Write-Host 'Launch via SKSE executable after Root Builder deploys on run.'