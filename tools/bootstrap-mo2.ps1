#Requires -Version 5.1
<#
.SYNOPSIS
  Download and extract Mod Organizer 2 portable into .\mo2
.NOTES
  Idempotent: skips download if the cached archive exists; re-extracts only with -Force.
#>
[CmdletBinding()]
param(
  [string]$Version = '2.5.2',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
# tools/bootstrap-mo2.ps1 -> repo root is parent of tools
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Mo2.ps1')   # Find-7Zip, Test-Mo2Running (shared)
$CacheDir = Join-Path $Root '.cache'
$Mo2Dir = Join-Path $Root 'mo2'
$ArchiveName = "Mod.Organizer-$Version.7z"
$ArchivePath = Join-Path $CacheDir $ArchiveName
$Url = "https://github.com/ModOrganizer2/modorganizer/releases/download/v$Version/$ArchiveName"

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

if ($Force -or -not (Test-Path $ArchivePath)) {
  Write-Host "Downloading MO2 $Version ..."
  Invoke-WebRequest -Uri $Url -OutFile $ArchivePath -UseBasicParsing
} else {
  Write-Host "Using cached $ArchivePath"
}

$exe = Join-Path $Mo2Dir 'ModOrganizer.exe'
if ((Test-Path $exe) -and -not $Force) {
  Write-Host "MO2 already present at $Mo2Dir (use -Force to re-extract)"
  exit 0
}

if (Test-Path $Mo2Dir) {
  # Re-extracting deletes the mo2 tree; MO2 must be closed or file locks/undefined state result.
  if (Test-Mo2Running) { Assert-Mo2NotRunning -ScriptHint './tools/bootstrap-mo2.ps1 -Force' }
  # Preserve user data if re-extracting.
  # portable.txt MUST survive or MO2 reverts to global-instance mode on next launch.
  # Custom plugins (e.g. plugins/rootbuilder) are intentionally NOT preserved so a version
  # upgrade gets fresh base plugins; re-run tools/install-m1.ps1 afterwards to restore them.
  $preserve = @('mods', 'downloads', 'profiles', 'overwrite', 'ModOrganizer.ini', 'categories.dat', 'portable.txt')
  $backup = Join-Path $CacheDir ("mo2-preserve-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
  New-Item -ItemType Directory -Path $backup | Out-Null
  foreach ($p in $preserve) {
    $src = Join-Path $Mo2Dir $p
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $backup $p) -Recurse -Force
    }
  }
  Write-Host "Preserved instance data -> $backup"
  Remove-Item $Mo2Dir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $Mo2Dir | Out-Null
$seven = Find-7Zip
Write-Host "Extracting with $seven ..."
& $seven x -y "-o$Mo2Dir" $ArchivePath | Out-Host

if (-not (Test-Path (Join-Path $Mo2Dir 'ModOrganizer.exe'))) {
  # Some archives nest a single folder
  $nested = Get-ChildItem $Mo2Dir -Directory | Select-Object -First 1
  if ($nested -and (Test-Path (Join-Path $nested.FullName 'ModOrganizer.exe'))) {
    Get-ChildItem $nested.FullName -Force | Move-Item -Destination $Mo2Dir -Force
    Remove-Item $nested.FullName -Recurse -Force
  }
}

if (-not (Test-Path (Join-Path $Mo2Dir 'ModOrganizer.exe'))) {
  throw 'Extraction failed: ModOrganizer.exe not found'
}

# Ensure portable instance dirs
foreach ($d in @('mods', 'downloads', 'profiles', 'overwrite')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Mo2Dir $d) | Out-Null
}

Write-Host "MO2 $Version ready: $Mo2Dir"
if ($Force) {
  Write-Host "Re-extract done. Re-run tools/install-m1.ps1 to restore the Root Builder plugin."
}
Write-Host "Next: configure game path / run restore-mods.ps1"
