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
    Write-Warning "Mod $($Mod.id) has nexus.fileId=$($Mod.nexus.fileId) — discouraged; prefer dynamic selection."
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
