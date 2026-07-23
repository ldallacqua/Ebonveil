#Requires -Version 5.1
<#
.SYNOPSIS
  Probe Skyrim SE install for version / dirtiness (loose files beyond vanilla).
#>
[CmdletBinding()]
param(
  [string]$GamePath = 'C:\Steam\steamapps\common\Skyrim Special Edition'
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $GamePath 'SkyrimSE.exe'
if (-not (Test-Path $exe)) { throw "Not found: $exe" }

$item = Get-Item $exe
Write-Host "Path: $($item.FullName)"
Write-Host "FileVersion: $($item.VersionInfo.FileVersion)"
Write-Host "ProductVersion: $($item.VersionInfo.ProductVersion)"
Write-Host "Size: $([math]::Round($item.Length/1MB,2)) MB"

$vanillaRootHints = @(
  'SkyrimSE.exe','SkyrimSELauncher.exe','steam_api64.dll','bink2w64.dll',
  'High.ini','Low.ini','Medium.ini','Ultra.ini','Skyrim_Default.ini','Skyrim.ccc','installscript.vdf'
)

Write-Host "`nRoot entries:"
Get-ChildItem $GamePath | ForEach-Object {
  $flag = if ($_.Name -in $vanillaRootHints -or $_.Name -in @('Data','Creations','Skyrim','Mods')) { 'ok' } else { 'UNEXPECTED?' }
  "{0,-40} {1}" -f $_.Name, $flag
}

$data = Join-Path $GamePath 'Data'
if (Test-Path $data) {
  $plugins = Get-ChildItem $data -Include *.esp,*.esm,*.esl -File -ErrorAction SilentlyContinue
  Write-Host "`nData plugins ($($plugins.Count)):"
  $plugins | Select-Object -ExpandProperty Name
}
