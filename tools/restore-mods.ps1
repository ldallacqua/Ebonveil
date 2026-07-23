#Requires -Version 5.1
<#
.SYNOPSIS
  Download manifested Nexus mods into mo2/downloads using runtime-aware file selection.
#>
[CmdletBinding()]
param(
  [string]$Milestone = 'M1',
  [switch]$SkipSkse
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Nexus.ps1')

$ManifestPath = Join-Path $Root 'manifest\mods.json'
$Downloads = Join-Path $Root 'mo2\downloads'
$CacheDir = Join-Path $Root '.cache'
$ResolvedPath = Join-Path $Downloads '.ebonveil-resolved.json'

if (-not (Test-Path (Join-Path $Root 'mo2\ModOrganizer.exe'))) {
  throw 'MO2 missing. Run tools/bootstrap-mo2.ps1 first.'
}

New-Item -ItemType Directory -Force -Path $Downloads, $CacheDir | Out-Null
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$gamePath = if ($manifest.gamePath) { $manifest.gamePath } else { 'C:\Steam\steamapps\common\Skyrim Special Edition' }
$runtime = Get-SkyrimRuntime -GamePath $gamePath
Write-Host "Skyrim runtime: $($runtime.Version) ($($runtime.Platform))  file=$($runtime.FileVersion)"

$apiKey = Get-NexusApiKey -RepoRoot $Root
if (-not $apiKey) {
  Write-Warning 'No Nexus API key. Set NEXUS_API_KEY or run tools/nexus-auth.ps1. Nexus mods will be skipped.'
}

$targets = @($manifest.mods | Where-Object { $_.milestone -eq $Milestone -or $Milestone -eq '*' })
Write-Host "Restoring milestone $Milestone ($($targets.Count) entries)"

$resolved = @{}
if (Test-Path -LiteralPath $ResolvedPath) {
  try {
    $prev = Get-Content -LiteralPath $ResolvedPath -Raw | ConvertFrom-Json
    foreach ($p in $prev.PSObject.Properties) {
      $resolved[$p.Name] = @{
        modId          = $p.Value.modId
        domain         = $p.Value.domain
        fileId         = $p.Value.fileId
        fileName       = $p.Value.fileName
        version        = $p.Value.version
        skyrimVersion  = $p.Value.skyrimVersion
        skyrimPlatform = $p.Value.skyrimPlatform
        url            = $p.Value.url
        archivePath    = $p.Value.archivePath
      }
    }
  } catch { }
}

foreach ($mod in $targets) {
  Write-Host "`n=== $($mod.name) [$($mod.id)] ==="

  if ($mod.source -eq 'silverlock' -and -not $SkipSkse) {
    Write-Warning "Manifest entry $($mod.id) still marked silverlock - prefer Nexus. Running fallback fetch only."
    & (Join-Path $PSScriptRoot 'fetch-skse.ps1')
    continue
  }

  if ($mod.source -ne 'nexus') {
    Write-Host "No automated handler for source=$($mod.source)"
    continue
  }

  if (-not $apiKey) {
    Write-Host "SKIP (no API key): nexus mod $($mod.nexus.modId) - $($mod.name)"
    Write-Host "  Manual: https://www.nexusmods.com/$($mod.nexus.domain)/mods/$($mod.nexus.modId)"
    continue
  }

  try {
    $files = Invoke-NexusApi -ApiKey $apiKey -Path "/v1/games/$($mod.nexus.domain)/mods/$($mod.nexus.modId)/files.json"
    $fileList = @($files.files)
    if (-not $fileList.Count) { throw 'No files returned' }

    $chosen = Select-NexusFileForRuntime -FileList $fileList -Mod $mod -Runtime $runtime
    Write-Host "Selected: $($chosen.file_name) (file_id=$($chosen.file_id), version=$($chosen.version), uploaded=$($chosen.uploaded_time))"

    $dest = Join-Path $Downloads $chosen.file_name
    if (-not (Test-Path -LiteralPath $dest)) {
      $links = Invoke-NexusApi -ApiKey $apiKey -Path "/v1/games/$($mod.nexus.domain)/mods/$($mod.nexus.modId)/files/$($chosen.file_id)/download_link.json"
      $uri = @($links)[0].URI
      if (-not $uri) { throw 'No download URI - Premium may be required for API CDN links' }
      Write-Host "  -> $dest"
      Invoke-WebRequest -Uri $uri -OutFile $dest -UseBasicParsing
      Write-Host 'Downloaded.'
    } else {
      Write-Host "Already in downloads: $dest"
    }

    $resolved[$mod.id] = @{
      modId           = $mod.nexus.modId
      domain          = $mod.nexus.domain
      fileId          = $chosen.file_id
      fileName        = $chosen.file_name
      version         = $chosen.version
      skyrimVersion   = $runtime.Version
      skyrimPlatform  = $runtime.Platform
      url             = "https://www.nexusmods.com/$($mod.nexus.domain)/mods/$($mod.nexus.modId)"
      archivePath     = $dest
    }
  }
  catch {
    Write-Warning "Nexus fetch failed for $($mod.id): $_"
    Write-Host "  Fallback: open https://www.nexusmods.com/$($mod.nexus.domain)/mods/$($mod.nexus.modId) via MO2 nxm handler"
  }
}

($resolved | ConvertTo-Json -Depth 6) | Set-Content -Path $ResolvedPath -Encoding UTF8
Write-Host "`nWrote selection map: $ResolvedPath"
Write-Host 'Done. Run tools/install-m1.ps1 (or later installers) to stage into mo2/mods.'
