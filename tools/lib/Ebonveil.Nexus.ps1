# Shared Nexus / Skyrim helpers for Ebonveil restore + install scripts.
# Dot-source: . "$PSScriptRoot\lib\Ebonveil.Nexus.ps1"

function Get-EbonveilRoot {
  if ($PSScriptRoot) {
    # tools/lib -> repo root
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  }
  throw 'PSScriptRoot unavailable'
}

function Get-NexusApiKey {
  param([string]$RepoRoot)
  if ($env:NEXUS_API_KEY) { return $env:NEXUS_API_KEY }
  $keyFile = Join-Path $RepoRoot 'secrets\nexus_api_key.txt'
  if (Test-Path $keyFile) { return (Get-Content $keyFile -Raw).Trim() }
  return $null
}

function Invoke-NexusApi {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$ApiKey
  )
  $headers = @{
    apikey       = $ApiKey
    Accept       = 'application/json'
    'User-Agent' = 'EbonveilRestore/0.2 (MO2 portable; personal use)'
  }
  Invoke-RestMethod -Uri "https://api.nexusmods.com$Path" -Headers $headers -Method Get
}

function Get-SkyrimRuntime {
  param(
    [string]$GamePath = 'C:\Steam\steamapps\common\Skyrim Special Edition'
  )
  $exe = Join-Path $GamePath 'SkyrimSE.exe'
  if (-not (Test-Path -LiteralPath $exe)) { throw "SkyrimSE.exe not found at $exe" }

  $vi = (Get-Item -LiteralPath $exe).VersionInfo
  $fileVersion = [string]$vi.FileVersion
  $productVersion = [string]$vi.ProductVersion

  # Normalize to x.y.z (drop build)
  $normalized = $null
  foreach ($candidate in @($fileVersion, $productVersion)) {
    if ($candidate -match '(\d+\.\d+\.\d+)') {
      $normalized = $Matches[1]
      break
    }
  }
  if (-not $normalized) { throw "Could not parse Skyrim version from '$fileVersion' / '$productVersion'" }

  # Platform heuristic: GOG ships galaxy_api / gog files; Steam has steam_api64.dll
  $isGog = (Test-Path (Join-Path $GamePath 'Galaxy64.dll')) -or
           (Test-Path (Join-Path $GamePath 'gog.ico')) -or
           ($normalized -eq '1.6.1179')  # known GOG AE runtime
  $isSteam = (Test-Path (Join-Path $GamePath 'steam_api64.dll')) -and -not $isGog
  if (-not $isSteam -and -not $isGog) {
    # Default Steam if steam_api present, else unknown
    $isSteam = Test-Path (Join-Path $GamePath 'steam_api64.dll')
  }

  $platform = if ($isGog) { 'GOG' } elseif ($isSteam) { 'Steam' } else { 'Unknown' }

  [PSCustomObject]@{
    GamePath        = $GamePath
    FileVersion     = $fileVersion
    ProductVersion  = $productVersion
    Version         = $normalized
    VersionUnderscore = ($normalized -replace '\.', '_')
    Platform        = $platform
  }
}

function Test-NexusFileMainCategory {
  param($File)
  return ($File.category_id -eq 1) -or
         ($File.category_name -eq 'MAIN') -or
         ($File.category_name -eq 'Main')
}

function Select-NexusFileForRuntime {
  <#
  .SYNOPSIS
    Pick the best Nexus file for the local Skyrim runtime.
  .NOTES
    No hard version pins. Prefer latest MAIN compatible with platform + game version hints.
    Optional nexus.fileId is emergency-only and should be avoided.
  #>
  param(
    [Parameter(Mandatory)]$FileList,
    [Parameter(Mandatory)]$Mod,
    [Parameter(Mandatory)]$Runtime
  )

  if ($Mod.nexus.fileId) {
    Write-Warning "Mod $($Mod.id) has nexus.fileId=$($Mod.nexus.fileId) -- discouraged; prefer dynamic selection."
    $pinned = @($FileList | Where-Object { $_.file_id -eq [int]$Mod.nexus.fileId } | Select-Object -First 1)
    if (-not $pinned) { throw "Pinned fileId $($Mod.nexus.fileId) not found for $($Mod.id)" }
    return $pinned[0]
  }

  $candidates = @($FileList)
  $mainish = @($candidates | Where-Object { Test-NexusFileMainCategory $_ })
  if ($mainish.Count -gt 0) { $candidates = $mainish }

  # Soft include/exclude from manifest (patterns, not version pins)
  if ($Mod.nexus.fileNameExclude) {
    foreach ($ex in @($Mod.nexus.fileNameExclude)) {
      $candidates = @($candidates | Where-Object {
        $_.file_name -notmatch [regex]::Escape([string]$ex) -and
        ("$($_.description)" -notmatch [regex]::Escape([string]$ex))
      })
    }
  }
  if ($Mod.nexus.fileNameInclude) {
    $filtered = @()
    foreach ($inc in @($Mod.nexus.fileNameInclude)) {
      $filtered += @($candidates | Where-Object {
        $_.file_name -match [regex]::Escape([string]$inc) -or
        ("$($_.description)" -match [regex]::Escape([string]$inc))
      })
    }
    if ($filtered.Count -gt 0) { $candidates = @($filtered | Sort-Object file_id -Unique) }
  }

  # Platform-aware selection (SKSE and similar dual Steam/GOG uploads)
  $platformAware = $true
  if ($null -ne $Mod.selection -and $null -ne $Mod.selection.platformAware) {
    $platformAware = [bool]$Mod.selection.platformAware
  }
  if ($platformAware) {
    if ($Runtime.Platform -eq 'Steam') {
      $candidates = @($candidates | Where-Object {
        $_.file_name -notmatch '(?i)\bGOG\b' -and ("$($_.description)" -notmatch '(?i)\bGOG\b')
      })
    } elseif ($Runtime.Platform -eq 'GOG') {
      $gog = @($candidates | Where-Object {
        $_.file_name -match '(?i)\bGOG\b' -or ("$($_.description)" -match '(?i)\bGOG\b')
      })
      if ($gog.Count -gt 0) { $candidates = $gog }
    }
  }

  # Prefer files that mention this game version in name/description when present
  $matchGameVersion = $true
  if ($null -ne $Mod.selection -and $null -ne $Mod.selection.matchGameVersion) {
    $matchGameVersion = [bool]$Mod.selection.matchGameVersion
  }
  if ($matchGameVersion) {
    $ver = [regex]::Escape($Runtime.Version)
    $verUs = [regex]::Escape($Runtime.VersionUnderscore)
    $versionHits = @($candidates | Where-Object {
      $_.file_name -match $ver -or $_.file_name -match $verUs -or
      ("$($_.description)" -match $ver) -or ("$($_.description)" -match $verUs) -or
      ("$($_.version)" -match $ver)
    })
    if ($versionHits.Count -gt 0) { $candidates = $versionHits }
  }

  if ($candidates.Count -eq 0) {
    throw "No Nexus files left after runtime/platform filters for $($Mod.id) (Skyrim $($Runtime.Version) / $($Runtime.Platform))"
  }

  # Latest upload among remaining = usual correct choice
  $selected = $candidates | Sort-Object { $_.uploaded_timestamp } -Descending | Select-Object -First 1
  return $selected
}

function Find-DownloadByModId {
  param(
    [string]$DownloadsDir,
    [int]$ModId,
    [string[]]$NameExclude = @()
  )
  $files = @(Get-ChildItem -LiteralPath $DownloadsDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "-$ModId-" })
  foreach ($ex in $NameExclude) {
    $files = @($files | Where-Object { $_.Name -notmatch [regex]::Escape($ex) })
  }
  if ($files.Count -eq 0) { return $null }
  return $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Write-ResolvedManifest {
  param(
    [string]$Path,
    [hashtable]$Map
  )
  ($Map | ConvertTo-Json -Depth 6) | Set-Content -Path $Path -Encoding UTF8
}

# --- GraphQL v2 (requirements / metadata) ------------------------------------
# REST v1 has no requirements. GraphQL exposes author-declared deps (ADR 0015).
# Treat as HINTS only -- incomplete / no hard-vs-optional; manifest stays SoT.

function Get-NexusSkyrimSeGameId {
  # Nexus internal game id for Skyrim Special Edition (GraphQL mod(modId, gameId)).
  return '1704'
}

function Invoke-NexusGraphQl {
  param(
    [Parameter(Mandatory)][string]$Query,
    [hashtable]$Variables = $null,
    [string]$ApiKey
  )
  $payload = @{ query = $Query }
  if ($Variables) { $payload.variables = $Variables }
  $json = $payload | ConvertTo-Json -Depth 8 -Compress
  $headers = @{
    Accept       = 'application/json'
    'User-Agent' = 'EbonveilRestore/0.3 (MO2 portable; personal use)'
  }
  if ($ApiKey) { $headers.apikey = $ApiKey }
  # WebRequest avoids some PowerShell Invoke-RestMethod body quirks on Windows.
  $resp = Invoke-WebRequest -Uri 'https://api.nexusmods.com/v2/graphql' -Method Post `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([Text.Encoding]::UTF8.GetBytes($json)) `
    -Headers $headers -UseBasicParsing
  $parsed = $resp.Content | ConvertFrom-Json
  if ($parsed.errors) {
    $msg = ($parsed.errors | ForEach-Object { $_.message }) -join '; '
    throw "Nexus GraphQL error: $msg"
  }
  return $parsed.data
}

function Get-NexusModRequirements {
  <#
  .SYNOPSIS
    Fetch author-declared Nexus + DLC requirements for a mod (GraphQL v2).
  .NOTES
    Hints only (ADR 0015). Does not recurse -- use Get-NexusModRequirementTree.
  #>
  param(
    [Parameter(Mandatory)][int]$ModId,
    [string]$GameId = (Get-NexusSkyrimSeGameId),
    [string]$ApiKey,
    [int]$Count = 50
  )
  $query = @'
query ($modId: ID!, $gameId: ID!, $count: Int!) {
  mod(modId: $modId, gameId: $gameId) {
    name
    summary
    legacyModRequirementsEnabled
    modRequirements {
      nexusRequirements(count: $count) {
        totalCount
        nodes {
          modId
          modName
          url
          notes
          externalRequirement
          gameId
        }
      }
      dlcRequirements {
        notes
        gameExpansion { name id }
      }
    }
  }
}
'@
  $data = Invoke-NexusGraphQl -Query $query -ApiKey $ApiKey -Variables @{
    modId  = [string]$ModId
    gameId = [string]$GameId
    count  = $Count
  }
  if (-not $data.mod) {
    throw "Nexus GraphQL returned no mod for modId=$ModId gameId=$GameId"
  }
  $mod = $data.mod
  $nexus = @($mod.modRequirements.nexusRequirements.nodes | ForEach-Object {
      [PSCustomObject]@{
        modId               = [int]$_.modId
        modName             = [string]$_.modName
        gameId              = [string]$_.gameId
        externalRequirement = [bool]$_.externalRequirement
        notes               = [string]$_.notes
        url                 = [string]$_.url
      }
    })
  $dlc = @($mod.modRequirements.dlcRequirements | ForEach-Object {
      [PSCustomObject]@{
        name  = [string]$_.gameExpansion.name
        id    = [string]$_.gameExpansion.id
        notes = [string]$_.notes
      }
    })
  [PSCustomObject]@{
    modId                          = $ModId
    gameId                         = $GameId
    name                           = [string]$mod.name
    summary                        = [string]$mod.summary
    legacyModRequirementsEnabled   = [bool]$mod.legacyModRequirementsEnabled
    nexusRequirements              = $nexus
    dlcRequirements                = $dlc
  }
}

function Get-NexusModRequirementTree {
  <#
  .SYNOPSIS
    Walk declared Nexus requirements recursively (BFS). Caps depth/nodes.
  .NOTES
    Skips externalRequirement nodes for recursion (no Nexus modId to follow).
  #>
  param(
    [Parameter(Mandatory)][int]$ModId,
    [string]$GameId = (Get-NexusSkyrimSeGameId),
    [string]$ApiKey,
    [int]$MaxDepth = 4,
    [int]$MaxNodes = 40
  )
  $visited = [System.Collections.Generic.HashSet[int]]::new()
  $queue = [System.Collections.Generic.Queue[object]]::new()
  $nodes = [System.Collections.Generic.List[object]]::new()

  $root = Get-NexusModRequirements -ModId $ModId -GameId $GameId -ApiKey $ApiKey
  [void]$visited.Add($ModId)
  $nodes.Add([PSCustomObject]@{
      modId               = $root.modId
      name                = $root.name
      depth               = 0
      parentModId         = $null
      externalRequirement = $false
      notes               = ''
      url                 = ''
      dlcRequirements     = $root.dlcRequirements
      isRoot              = $true
    })
  foreach ($req in $root.nexusRequirements) {
    $queue.Enqueue([PSCustomObject]@{ ModId = $req.modId; Parent = $ModId; Depth = 1; Hint = $req })
  }

  while ($queue.Count -gt 0 -and $nodes.Count -lt $MaxNodes) {
    $item = $queue.Dequeue()
    if ($item.Depth -gt $MaxDepth) { continue }
    if ($item.Hint.externalRequirement) {
      $nodes.Add([PSCustomObject]@{
          modId               = $item.Hint.modId
          name                = $item.Hint.modName
          depth               = $item.Depth
          parentModId         = $item.Parent
          externalRequirement = $true
          notes               = $item.Hint.notes
          url                 = $item.Hint.url
          dlcRequirements     = @()
          isRoot              = $false
        })
      continue
    }
    if (-not $visited.Add([int]$item.ModId)) { continue }

    $info = Get-NexusModRequirements -ModId $item.ModId -GameId $GameId -ApiKey $ApiKey
    $nodes.Add([PSCustomObject]@{
        modId               = $info.modId
        name                = $info.name
        depth               = $item.Depth
        parentModId         = $item.Parent
        externalRequirement = $false
        notes               = $item.Hint.notes
        url                 = $item.Hint.url
        dlcRequirements     = $info.dlcRequirements
        isRoot              = $false
      })
    foreach ($req in $info.nexusRequirements) {
      if ($nodes.Count + $queue.Count -ge $MaxNodes) { break }
      $queue.Enqueue([PSCustomObject]@{ ModId = $req.modId; Parent = $info.modId; Depth = $item.Depth + 1; Hint = $req })
    }
  }

  [PSCustomObject]@{
    root  = $root
    nodes = @($nodes)
  }
}

function Compare-NexusRequirementsToManifest {
  <#
  .SYNOPSIS
    Classify declared requirement modIds against manifest/mods.json + local presence.
  #>
  param(
    [Parameter(Mandatory)]$RequirementNodes,
    [Parameter(Mandatory)][string]$RepoRoot
  )
  $manifestPath = Join-Path $RepoRoot 'manifest\mods.json'
  $manifestIds = @{}
  if (Test-Path -LiteralPath $manifestPath) {
    $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($mod in @($m.mods)) {
      if ($mod.nexus -and $mod.nexus.modId) {
        $manifestIds[[int]$mod.nexus.modId] = [string]$mod.id
      }
    }
  }
  $downloads = Join-Path $RepoRoot 'mo2\downloads'
  $modsDir = Join-Path $RepoRoot 'mo2\mods'

  $rows = @()
  foreach ($n in @($RequirementNodes)) {
    if ($n.isRoot) { continue }
    if ($n.externalRequirement) {
      $rows += [PSCustomObject]@{
        modId = $n.modId; name = $n.name; depth = $n.depth
        inManifest = $false; manifestId = $null
        downloaded = $false; installedMeta = $false
        external = $true; status = 'external'
      }
      continue
    }
    $mid = [int]$n.modId
    $inMan = $manifestIds.ContainsKey($mid)
    $dl = $null
    if (Test-Path $downloads) { $dl = Find-DownloadByModId -DownloadsDir $downloads -ModId $mid }
    $installed = $false
    if (Test-Path $modsDir) {
      $installed = [bool](Get-ChildItem -LiteralPath $modsDir -Directory -EA SilentlyContinue |
        Where-Object {
          $meta = Join-Path $_.FullName 'meta.ini'
          (Test-Path $meta) -and ((Get-Content $meta -Raw) -match "(?m)^modid=$mid\s*$")
        } | Select-Object -First 1)
    }
    $status = if ($inMan -and ($dl -or $installed)) { 'covered' }
              elseif ($inMan) { 'in-manifest' }
              elseif ($dl -or $installed) { 'local-only' }
              else { 'missing' }
    $rows += [PSCustomObject]@{
      modId        = $mid
      name         = $n.name
      depth        = $n.depth
      inManifest   = $inMan
      manifestId   = if ($inMan) { $manifestIds[$mid] } else { $null }
      downloaded   = [bool]$dl
      installedMeta = $installed
      external     = $false
      status       = $status
    }
  }
  return $rows
}
