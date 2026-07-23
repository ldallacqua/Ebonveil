#Requires -Version 5.1
<#
.SYNOPSIS
  Write / patch MO2 meta.ini with Nexus download identity (ADR 0005).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ModDir,
  [Parameter(Mandatory = $true)][string]$ModName,
  [Parameter(Mandatory = $true)][int]$NexusModId,
  [string]$Domain = 'skyrimspecialedition',
  [string]$Version = '',
  [string]$InstallationFile = '',
  # MO2 meta.ini gameName is the game SHORT name (gameShortName()), e.g. SkyrimSE - NOT the display name.
  [string]$GameName = 'SkyrimSE'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $ModDir)) { throw "Mod dir missing: $ModDir" }

$url = "https://www.nexusmods.com/$Domain/mods/$NexusModId"
$metaPath = Join-Path $ModDir 'meta.ini'

$lines = @(
  '[General]'
  "gameName=$GameName"
  "modid=$NexusModId"
  "version=$Version"
  'newestVersion='
  'category=0'
  "installationFile=$InstallationFile"
  'repository=Nexus'
  "url=$url"
  "nexusUrl=$url"
  ''
  '[installedFiles]'
  'size=0'
  ''
  '[Source]'
  "url=$url"
)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($metaPath, $lines, $utf8NoBom)
Write-Host "Wrote Nexus metadata for '$ModName' -> $url"
