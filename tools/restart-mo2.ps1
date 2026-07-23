#Requires -Version 5.1
<#
.SYNOPSIS
  Cleanly stop this instance's Mod Organizer 2, optionally apply changes while it is
  down, then relaunch it.
.DESCRIPTION
  MO2 rewrites mo2/ModOrganizer.ini on exit. Any edit to that file (registering tool /
  SKSE executables, etc.) made while MO2 is running is clobbered on its next exit, and
  MO2 only reads the ini at startup. So the correct sequence after such changes is:
  stop MO2 -> apply edits -> start MO2. Use -Between to run the edits in the gap.

  Only processes whose image path is THIS repo's mo2/ModOrganizer.exe are touched, so a
  different MO2 instance elsewhere is left alone.
.PARAMETER Between
  Script block executed while MO2 is stopped (e.g. { ./tools/bootstrap-tools.ps1 }).
  Requires launching via `pwsh -Command` (a scriptblock cannot be passed to `-File`).
.PARAMETER NoStart
  Stop only; do not relaunch.
.PARAMETER Force
  Kill immediately instead of requesting a graceful window close first.
.PARAMETER TimeoutSeconds
  How long to wait for a graceful close before force-killing. Default 20.
.PARAMETER Arguments
  Extra arguments passed to ModOrganizer.exe on launch.
.EXAMPLE
  pwsh -File tools/restart-mo2.ps1
.EXAMPLE
  pwsh -Command "& ./tools/restart-mo2.ps1 -Between { ./tools/bootstrap-tools.ps1 }"
#>
[CmdletBinding()]
param(
  [scriptblock]$Between,
  [switch]$NoStart,
  [switch]$Force,
  [int]$TimeoutSeconds = 20,
  [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Mo2.ps1')

$paths = Get-Mo2Paths
if (-not (Test-Path -LiteralPath $paths.Exe)) {
  throw "ModOrganizer.exe not found: $($paths.Exe) (run tools/bootstrap-mo2.ps1 first)"
}

$wasRunning = Stop-Mo2 -Exe $paths.Exe -TimeoutSeconds $TimeoutSeconds -Force:$Force
if (-not $wasRunning) { Write-Host 'MO2 was not running.' }

if ($Between) {
  Write-Host 'Running -Between block (MO2 is down)...'
  try {
    & $Between
  } catch {
    Write-Warning "-Between block failed: $_"
  }
}

if ($NoStart) {
  Write-Host 'NoStart set - leaving MO2 closed.'
  return
}

Start-Mo2 -Exe $paths.Exe -Arguments $Arguments | Out-Null
