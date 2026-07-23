#Requires -Version 5.1
<#
.SYNOPSIS
  Context-aware load-order review: separator stack, plugin order, loose-file conflicts.
.DESCRIPTION
  Implements the reviewer workflow from .cursor/skills/skyrim-modding (ADR 0016).
  MO2 does not export a conflict file -- loose conflicts are scanned from disk.
  Use -RebuildStack to rewrite modlist.txt from separators.json + manifest categories.
  Use -Json / -OutFile for a future UI / install AI.
#>
[CmdletBinding()]
param(
  [switch]$RebuildStack,
  [switch]$ScanConflicts,
  [string[]]$ConflictMods,
  [int]$MaxConflicts = 80,
  [switch]$RestartMo2,
  [switch]$Json,
  [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib\Ebonveil.Mo2.ps1')

$Mo2 = Join-Path $RepoRoot 'mo2'
$Mods = Join-Path $Mo2 'mods'
$ProfileDir = Join-Path $Mo2 'profiles\Default'
$order = @(Get-Mo2SeparatorOrder -RepoRoot $RepoRoot)

$mo2WasRunning = $false
if ($RebuildStack) {
  if (Test-Mo2Running) {
    if ($RestartMo2) { $mo2WasRunning = Stop-Mo2 }
    else { Assert-Mo2NotRunning -ScriptHint './tools/review-load-order.ps1 -RebuildStack -RestartMo2' }
  }
  Rebuild-Mo2ModlistStack -ProfileDir $ProfileDir -ModsDir $Mods -RepoRoot $RepoRoot
}

# --- parse current state ---
$modlist = @(Get-Content (Join-Path $ProfileDir 'modlist.txt') -EA SilentlyContinue)
$plugins = @(Get-Content (Join-Path $ProfileDir 'plugins.txt') -EA SilentlyContinue | Where-Object { $_ -notmatch '^#' })
$loadorder = @(Get-Content (Join-Path $ProfileDir 'loadorder.txt') -EA SilentlyContinue | Where-Object { $_ -notmatch '^#' })

$uiStack = [System.Collections.Generic.List[string]]::new()  # top→bottom as user sees
$sepBlocks = [System.Collections.Generic.List[object]]::new()
$cur = $null
$curMods = [System.Collections.Generic.List[string]]::new()
# Walk modlist reverse for UI order (file high-pri first → UI bottom first; reverse for display)
$fileBlocks = [System.Collections.Generic.List[object]]::new()
foreach ($line in $modlist) {
  if ($line -match '^#') { continue }
  $n = Get-Mo2ModlistEntryName -Line $line
  if (-not $n) { continue }
  if ($n.EndsWith('_separator')) {
    $disp = $n -replace '_separator$', ''
    $fileBlocks.Add([PSCustomObject]@{ Separator = $disp; Mods = @($curMods.ToArray()) })
    $curMods = [System.Collections.Generic.List[string]]::new()
    continue
  }
  if ($line.StartsWith('*')) { continue }
  if ($line.StartsWith('+') -or $line.StartsWith('-')) { $curMods.Add($line) }
}
# leftover orphans before first sep -- ignore

$critical = [System.Collections.Generic.List[string]]::new()
$likely = [System.Collections.Generic.List[string]]::new()
$watch = [System.Collections.Generic.List[string]]::new()

# Separator rank checks (UI top = low priority = late in order array for Bug Fixes)
$bugIdx = [array]::IndexOf($order, 'Bug Fixes')
$patchIdx = [array]::IndexOf($order, 'Patches & Compatibility')
# In order array, higher index = lower priority = closer to top of UI
# Bug Fixes should be AFTER Patches in the array (higher index) when both exist
if ($bugIdx -ge 0 -and $patchIdx -ge 0 -and $bugIdx -lt $patchIdx) {
  $critical.Add('separators.json ranks Bug Fixes higher priority than Patches & Compatibility -- general bug fixes should be early (top of UI), patches late.')
}

# Find USSEP placement
$ussepLine = $modlist | Where-Object { $_ -match '^\+USSEP$' -or $_ -match '^\+.*USSEP' } | Select-Object -First 1
$ussepUnder = $null
$seen = [System.Collections.Generic.List[string]]::new()
foreach ($line in $modlist) {
  $n = Get-Mo2ModlistEntryName -Line $line
  if (-not $n) { continue }
  if ($n.EndsWith('_separator')) {
    if ($seen -contains 'USSEP' -or ($seen | Where-Object { $_ -like '*USSEP*' })) {
      $ussepUnder = $n -replace '_separator$', ''
      break
    }
  }
  if ($line.StartsWith('+') -or $line.StartsWith('-')) { $seen.Add($n) }
}
if ($ussepUnder -eq 'Patches & Compatibility') {
  $critical.Add('USSEP is under Patches & Compatibility (late/high priority). Move to Bug Fixes (foundation / top of UI).')
} elseif ($ussepUnder -and $ussepUnder -ne 'Bug Fixes') {
  $likely.Add("USSEP is under '$ussepUnder'; expected Bug Fixes.")
} elseif (-not $ussepUnder -and ($modlist -match 'USSEP')) {
  $watch.Add('USSEP present but separator membership unclear.')
}

# Plugin order: USSEP should appear before LAL (MO2 may rewrite plugin name casing)
$pNames = @($plugins | ForEach-Object { $_.TrimStart('*', '-') })
function Find-PluginIndex([string]$Name) {
  for ($i = 0; $i -lt $pNames.Count; $i++) {
    if ($pNames[$i] -ieq $Name) { return $i }
  }
  return -1
}
$iUssep = Find-PluginIndex 'Unofficial Skyrim Special Edition Patch.esp'
$iLal = Find-PluginIndex 'Alternate Start - Live Another Life.esp'
if ($iUssep -ge 0 -and $iLal -ge 0 -and $iUssep -gt $iLal) {
  $likely.Add('Plugin order: USSEP loads after Alternate Start -- USSEP should load earlier (LOOT or manual).')
}
$ussepModOn = [bool](@($modlist | Where-Object { $_ -match '^\+.*USSEP' }).Count)
$lalModOn = [bool](@($modlist | Where-Object { $_ -match '^\+.*Alternate Start' }).Count)
if ($iUssep -lt 0 -and $ussepModOn) {
  $critical.Add('USSEP mod enabled but Unofficial Skyrim Special Edition Patch.esp not in plugins.txt.')
}
if ($iLal -lt 0 -and $lalModOn) {
  $critical.Add('Alternate Start mod enabled but its .esp is not in plugins.txt.')
}

$conflicts = @()
if ($ScanConflicts) {
  $conflicts = @(Scan-Mo2LooseFileConflicts -ProfileDir $ProfileDir -ModsDir $Mods `
      -OnlyMods $ConflictMods -MaxResults $MaxConflicts)
  if ($conflicts.Count -eq 0) {
    $watch.Add('Loose-file conflict scan found no overlapping paths among enabled mods (BSA/BA2 not scanned).')
  } else {
    $watch.Add("Loose-file conflict scan: $($conflicts.Count) overlapping path(s). Review winners below.")
  }
}

# UI stack preview (reverse file blocks that we care about)
$stackPreview = @()
foreach ($b in ($fileBlocks | Sort-Object { [array]::IndexOf($order, $_.Separator) } -Descending)) {
  $stackPreview += [PSCustomObject]@{
    separator = $b.Separator
    mods      = @($b.Mods | ForEach-Object { $_.Substring(1) })
  }
}

$result = [PSCustomObject]@{
  schemaVersion = 1
  generatedAt   = (Get-Date).ToUniversalTime().ToString('o')
  separatorOrderHighestFirst = $order
  stackPreviewUiTopFirst     = $stackPreview
  findings = [PSCustomObject]@{
    critical = @($critical)
    likely   = @($likely)
    watch    = @($watch)
  }
  plugins = @($pNames)
  conflictsLoose = @($conflicts)
  notes = @(
    'MO2 does not export a conflict report file; Conflicts UI / getFileOrigins are in-process only.'
    'Loose scan ignores BSA/BA2. Run LOOT through MO2 for plugin sort messages.'
    'Skill: .cursor/skills/skyrim-modding -- context-aware installs + reviewer rules.'
  )
}

$jsonText = $result | ConvertTo-Json -Depth 8
if ($OutFile) {
  $full = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $RepoRoot $OutFile }
  $parent = Split-Path $full -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  [IO.File]::WriteAllText($full, $jsonText, [Text.UTF8Encoding]::new($false))
  Write-Host "Wrote $full"
}

if ($Json) { Write-Output $jsonText; if ($mo2WasRunning) { Start-Mo2 | Out-Null }; return }

Write-Host '=== Load order review ==='
Write-Host ''
Write-Host 'Critical:'
if ($critical.Count -eq 0) { Write-Host '  (none)' } else { $critical | ForEach-Object { Write-Host "  - $_" } }
Write-Host 'Likely issues:'
if ($likely.Count -eq 0) { Write-Host '  (none)' } else { $likely | ForEach-Object { Write-Host "  - $_" } }
Write-Host 'Watch:'
if ($watch.Count -eq 0) { Write-Host '  (none)' } else { $watch | ForEach-Object { Write-Host "  - $_" } }
Write-Host ''
Write-Host 'Separator stack (UI top -> bottom, approx):'
foreach ($s in $stackPreview) {
  Write-Host "  [$($s.separator)] $($s.mods -join ', ')"
}
if ($conflicts.Count -gt 0) {
  Write-Host ''
  Write-Host "Loose conflicts (winner last; max $MaxConflicts):"
  $conflicts | Select-Object -First 25 | ForEach-Object {
    Write-Host ("  {0}" -f $_.path)
    Write-Host ("    winner={0}  losers={1}" -f $_.winner, ($_.losers -join ', '))
  }
}
Write-Host ''
Write-Host 'Tip: -RebuildStack -RestartMo2 to fix separator ranks; -ScanConflicts for loose overlaps.'

if ($mo2WasRunning) { Start-Mo2 | Out-Null }
