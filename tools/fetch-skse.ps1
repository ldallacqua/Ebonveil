#Requires -Version 5.1
<#
.SYNOPSIS
  Fallback SKSE fetch from silverlock /beta/ when Nexus is unavailable.
.NOTES
  Primary path is Nexus mod 30379 via MO2 or restore-mods.ps1 (ADR 0005).
#>
[CmdletBinding()]
param(
  [string]$GamePath = 'C:\Steam\steamapps\common\Skyrim Special Edition'
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Downloads = Join-Path $Root 'mo2\downloads'
$CacheDir = Join-Path $Root '.cache\skse'
New-Item -ItemType Directory -Force -Path $Downloads, $CacheDir | Out-Null

Write-Warning 'fetch-skse.ps1 is FALLBACK only. Prefer Nexus mod 30379 via MO2 Downloads.'

$exe = Join-Path $GamePath 'SkyrimSE.exe'
if (-not (Test-Path $exe)) { throw "SkyrimSE.exe not found at $exe" }

$fv = [version](Get-Item $exe).VersionInfo.FileVersion
$pv = (Get-Item $exe).VersionInfo.ProductVersion
Write-Host "SkyrimSE.exe FileVersion = $fv ; ProductVersion = $pv"

$Known = @(
  @{ Match = '1.6.1170'; Tag = 'Steam AE'; Url = 'https://skse.silverlock.org/beta/skse64_2_02_06.7z'; Archive = 'skse64_2_02_06.7z' }
  @{ Match = '1.6.1179'; Tag = 'GOG AE'; Url = 'https://skse.silverlock.org/beta/skse64_2_02_06_gog.7z'; Archive = 'skse64_2_02_06_gog.7z' }
  @{ Match = '1.5.97'; Tag = 'SSE 1.5.97'; Url = 'https://skse.silverlock.org/beta/skse64_2_00_20.7z'; Archive = 'skse64_2_00_20.7z' }
)

$verString = $fv.ToString()
$hit = $Known | Where-Object { $verString.StartsWith($_.Match) } | Select-Object -First 1
if (-not $hit -and $pv) {
  foreach ($k in $Known) {
    if ($pv -like "$($k.Match)*") { $hit = $k; break }
  }
}
if (-not $hit) {
  Start-Process 'https://www.nexusmods.com/skyrimspecialedition/mods/30379'
  throw "Unmapped Skyrim runtime $fv / $pv - use Nexus 30379 instead of guessing."
}

$dest = Join-Path $Downloads $hit.Archive
if (-not (Test-Path $dest)) {
  Write-Host "Downloading fallback $($hit.Url)"
  Invoke-WebRequest -Uri $hit.Url -OutFile $dest -UseBasicParsing
} else {
  Write-Host "Already present: $dest"
}

Write-Host "Fallback archive ready: $dest"
Write-Host 'Install via MO2, then run tools/write-mo2-nexus-meta.ps1 only if you later replace with Nexus copy (modid 30379).'
Write-Host 'Preferred: download https://www.nexusmods.com/skyrimspecialedition/mods/30379 inside MO2 so meta/url are native.'
