#Requires -Version 5.1
<#
.SYNOPSIS
  Probe author-declared Nexus mod requirements (GraphQL v2) and compare to the Ebonveil manifest.
.DESCRIPTION
  Requirements are HINTS only (ADR 0015) -- not a closed world. Manifest remains the source of
  truth for what we install. Output is structured so a future web UI / install AI can consume
  the same JSON (-Json / -OutFile).

.EXAMPLE
  pwsh -File tools/probe-mod-requirements.ps1 -ModId 272
.EXAMPLE
  pwsh -File tools/probe-mod-requirements.ps1 -ModId 272 -Recurse -Json -OutFile .cache/lal-deps.json
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][int]$ModId,
  [string]$GameDomain = 'skyrimspecialedition',
  [string]$GameId,
  [switch]$Recurse,
  [switch]$Json,
  [string]$OutFile,
  [int]$MaxDepth = 4
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Nexus.ps1')

if (-not $GameId) { $GameId = Get-NexusSkyrimSeGameId }
$apiKey = Get-NexusApiKey -RepoRoot $RepoRoot
# GraphQL requirements reads work without a key; send it when present (downloads still need it).

$caveats = @(
  'Author-declared Nexus requirements only -- incomplete and untyped (no hard vs optional).'
  'Manifest (manifest/mods.json) is the source of truth for installs; treat this as a hint.'
  'Plugin masters (.esm/.esp) are a separate signal (future: scan after download).'
)

if ($Recurse) {
  $tree = Get-NexusModRequirementTree -ModId $ModId -GameId $GameId -ApiKey $apiKey -MaxDepth $MaxDepth
  $modInfo = $tree.root
  $nodes = $tree.nodes
} else {
  $modInfo = Get-NexusModRequirements -ModId $ModId -GameId $GameId -ApiKey $apiKey
  $nodes = @(
    [PSCustomObject]@{
      modId = $modInfo.modId; name = $modInfo.name; depth = 0; parentModId = $null
      externalRequirement = $false; notes = ''; url = ''; dlcRequirements = $modInfo.dlcRequirements; isRoot = $true
    }
  ) + @($modInfo.nexusRequirements | ForEach-Object {
      [PSCustomObject]@{
        modId = $_.modId; name = $_.modName; depth = 1; parentModId = $modInfo.modId
        externalRequirement = $_.externalRequirement; notes = $_.notes; url = $_.url
        dlcRequirements = @(); isRoot = $false
      }
    })
}

$coverage = @(Compare-NexusRequirementsToManifest -RequirementNodes $nodes -RepoRoot $RepoRoot)

$result = [PSCustomObject]@{
  schemaVersion = 1
  generatedAt   = (Get-Date).ToUniversalTime().ToString('o')
  source        = 'nexus-graphql-v2'
  gameDomain    = $GameDomain
  gameId        = $GameId
  root          = [PSCustomObject]@{
    modId   = $modInfo.modId
    name    = $modInfo.name
    summary = $modInfo.summary
    url     = "https://www.nexusmods.com/$GameDomain/mods/$($modInfo.modId)"
  }
  declaredRequirements = @($modInfo.nexusRequirements)
  dlcRequirements      = @($modInfo.dlcRequirements)
  tree                 = @($nodes)
  coverage             = @($coverage)
  summary              = [PSCustomObject]@{
    declaredCount = @($modInfo.nexusRequirements).Count
    missing       = @($coverage | Where-Object { $_.status -eq 'missing' }).Count
    covered       = @($coverage | Where-Object { $_.status -eq 'covered' }).Count
    inManifest    = @($coverage | Where-Object { $_.status -eq 'in-manifest' }).Count
    external      = @($coverage | Where-Object { $_.status -eq 'external' }).Count
  }
  caveats = $caveats
  # Future UI / install AI: suggest adding missing Nexus deps to the manifest (human/AI confirms).
  suggestedManifestAdds = @(
    $coverage | Where-Object { $_.status -eq 'missing' -and -not $_.external } | ForEach-Object {
      [PSCustomObject]@{
        action     = 'consider-add-to-manifest'
        nexusModId = $_.modId
        name       = $_.name
        url        = "https://www.nexusmods.com/$GameDomain/mods/$($_.modId)"
        reason     = "Declared requirement of $($modInfo.name) (mod $($modInfo.modId)); not in manifest/mods.json"
      }
    }
  )
}

$jsonText = $result | ConvertTo-Json -Depth 10
if ($OutFile) {
  $full = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $RepoRoot $OutFile }
  $parent = Split-Path $full -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  [System.IO.File]::WriteAllText($full, $jsonText, [Text.UTF8Encoding]::new($false))
  Write-Host "Wrote $full"
}

if ($Json) {
  Write-Output $jsonText
  return
}

Write-Host "=== Requirements probe: $($modInfo.name) ($ModId) ==="
Write-Host $result.root.url
Write-Host ''
Write-Host 'Declared Nexus requirements:'
if (@($modInfo.nexusRequirements).Count -eq 0) {
  Write-Host '  (none declared)'
} else {
  foreach ($r in $modInfo.nexusRequirements) {
    $ext = if ($r.externalRequirement) { ' [external]' } else { '' }
    Write-Host ("  - {0} (modId {1}){2}" -f $r.modName, $r.modId, $ext)
    if ($r.notes) { Write-Host "      notes: $($r.notes)" }
  }
}
if (@($modInfo.dlcRequirements).Count -gt 0) {
  Write-Host 'DLC requirements:'
  foreach ($d in $modInfo.dlcRequirements) { Write-Host "  - $($d.name)" }
}

Write-Host ''
Write-Host 'Coverage vs Ebonveil manifest / local:'
foreach ($c in $coverage) {
  Write-Host ("  [{0}] {1} ({2})" -f $c.status, $c.name, $c.modId)
}
if (@($result.suggestedManifestAdds).Count -gt 0) {
  Write-Host ''
  Write-Host 'Suggested manifest adds (hints -- confirm before installing):'
  foreach ($s in $result.suggestedManifestAdds) {
    Write-Host ("  + {0} -- {1}" -f $s.name, $s.url)
  }
}
Write-Host ''
Write-Host 'Caveats:'
foreach ($c in $caveats) { Write-Host "  - $c" }
Write-Host ''
Write-Host 'Tip: -Json / -OutFile for machine-readable output (future UI + install AI).'
