#Requires -Version 5.1
<#
.SYNOPSIS
  Generate the live mo2/ModOrganizer.ini from the committed sanitized template,
  substituting machine-specific paths so cold restores stay path-portable.
.NOTES
  The live ini is gitignored (MO2 rewrites it constantly with absolute paths and
  volatile GUI geometry). This only seeds a first-run ini; MO2 owns it afterwards.
  Re-run with -Force (MO2 closed) to regenerate from the template.
  The SKSE launch entry is injected separately by tools/install-m1.ps1.
#>
[CmdletBinding()]
param(
  [string]$GamePath,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Mo2 = Join-Path $Root 'mo2'
$Template = Join-Path $Mo2 'ModOrganizer.ini.template'
$Live = Join-Path $Mo2 'ModOrganizer.ini'

if (-not (Test-Path -LiteralPath $Template)) { throw "Template missing: $Template" }

if (-not $GamePath) {
  $manifestPath = Join-Path $Root 'manifest\mods.json'
  if (Test-Path -LiteralPath $manifestPath) {
    $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($m.gamePath) { $GamePath = [string]$m.gamePath }
  }
}
if (-not $GamePath) { $GamePath = 'C:\Steam\steamapps\common\Skyrim Special Edition' }
$GamePath = $GamePath.TrimEnd('\', '/')

if ((Test-Path -LiteralPath $Live) -and -not $Force) {
  Write-Warning "Live ini already exists: $Live"
  Write-Host 'Refusing to overwrite a working config. Close MO2 and re-run with -Force to regenerate.'
  return
}

$instanceFs = ($Mo2 -replace '\\', '/')
$gameFs = ($GamePath -replace '\\', '/')
$gameBs = $GamePath.Replace('\', '\\')

$text = Get-Content -LiteralPath $Template -Raw
$text = $text.Replace('{{GAME_PATH_BS}}', $gameBs).
              Replace('{{GAME_PATH_FS}}', $gameFs).
              Replace('{{INSTANCE_PATH_FS}}', $instanceFs)

# Drop human-only comment lines; Qt QSettings ini parser does not support them.
$lines = @($text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*;' })
while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[0])) {
  $lines = @($lines[1..($lines.Count - 1)])
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($Live, $lines, $utf8NoBom)

Write-Host "Wrote $Live"
Write-Host "  game path : $GamePath"
Write-Host "  instance  : $instanceFs"
Write-Host 'Next: tools/install-m1.ps1 stages mods and adds the SKSE launch entry.'
