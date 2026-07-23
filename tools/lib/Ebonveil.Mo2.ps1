# Shared MO2 process / ini / extraction helpers for Ebonveil.
# Dot-source: . "$PSScriptRoot\lib\Ebonveil.Mo2.ps1"
#
# WHY THIS EXISTS (read docs/decisions/0013-mo2-ini-clobber-and-shared-lib.md):
#   - MO2 reads ModOrganizer.ini + profile modlist/plugins ONLY at startup and REWRITES
#     them on exit. Any edit made while MO2 runs is clobbered. Scripts that touch those
#     files MUST assert MO2 is closed (Assert-Mo2NotRunning) or cycle it (Stop/Start-Mo2).
#   - The WindowsApps `7z.exe` execution-alias (NanaZip) is a 0-byte reparse stub that
#     launches detached and returns before extraction finishes -> silent empty output.
#     Find-7Zip must skip it and prefer a real install.
# Keep ONE implementation of each helper here so behavior can't drift between scripts.

function Find-7Zip {
  # Prefer a real 7-Zip/NanaZip install; never a WindowsApps execution-alias stub.
  $candidates = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
    (Get-Command 7z -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
  )
  $valid = @($candidates | Where-Object {
      $_ -and (Test-Path $_) -and ($_ -notlike '*\WindowsApps\*') -and
      ((Get-Item $_ -ErrorAction SilentlyContinue).Length -gt 0)
    })
  if ($valid.Count -eq 0) {
    throw '7-Zip not found (a real install is required; the WindowsApps 7z alias is unusable). Install it: winget install --id 7zip.7zip -e'
  }
  return $valid[0]
}

function Get-Mo2Paths {
  param([string]$RepoRoot)
  if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
  $mo2 = Join-Path $RepoRoot 'mo2'
  [PSCustomObject]@{
    Root   = $RepoRoot
    Mo2Dir = $mo2
    Exe    = Join-Path $mo2 'ModOrganizer.exe'
    Ini    = Join-Path $mo2 'ModOrganizer.ini'
  }
}

function Get-Mo2Process {
  # Only processes whose image path is THIS repo's ModOrganizer.exe, so we never touch a
  # different MO2 instance. Unreadable path (access denied) -> included (single-instance repo).
  param([string]$Exe)
  if (-not $Exe) { $Exe = (Get-Mo2Paths).Exe }
  @(Get-Process -Name ModOrganizer -ErrorAction SilentlyContinue | Where-Object {
      $p = $null
      try { $p = $_.Path } catch { }
      (-not $p) -or ($p -ieq $Exe)
    })
}

function Test-Mo2Running {
  param([string]$Exe)
  return (Get-Mo2Process -Exe $Exe).Count -gt 0
}

function Assert-Mo2NotRunning {
  # Fail fast (before downloads/edits) when MO2 is up and the caller will edit ini/profile.
  param([string]$Exe, [string]$ScriptHint = './tools/<script>.ps1')
  if (Test-Mo2Running -Exe $Exe) {
    throw @"
Mod Organizer 2 is running. It rewrites ModOrganizer.ini and the profile modlist/plugins
on exit, so edits made now would be clobbered (MO2 only reads them at startup).

Fix -- apply the edits while MO2 is down, then relaunch:
  pwsh -Command "& ./tools/restart-mo2.ps1 -Between { $ScriptHint }"

Or re-run with -RestartMo2 to let the script stop/start MO2 for you.
"@
  }
}

function Stop-Mo2 {
  # Returns $true if MO2 was running (so the caller knows to relaunch afterwards).
  param([string]$Exe, [int]$TimeoutSeconds = 20, [switch]$Force)
  if (-not $Exe) { $Exe = (Get-Mo2Paths).Exe }
  $procs = Get-Mo2Process -Exe $Exe
  if ($procs.Count -eq 0) { return $false }
  $ids = $procs.Id
  Write-Host "Stopping MO2 (PID $($ids -join ', '))..."
  if ($Force) { foreach ($p in $procs) { try { $p.Kill() } catch { } } }
  else { foreach ($p in $procs) { try { $null = $p.CloseMainWindow() } catch { } } }

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (@(Get-Process -Id $ids -ErrorAction SilentlyContinue).Count -eq 0) { break }
    Start-Sleep -Milliseconds 400
  }
  $alive = @(Get-Process -Id $ids -ErrorAction SilentlyContinue)
  if ($alive.Count -gt 0) {
    Write-Warning 'MO2 graceful close timed out; force-killing (a game/tool launched through MO2 may still be running).'
    foreach ($p in $alive) { try { $p.Kill() } catch { } }
    Start-Sleep -Milliseconds 500
  }
  Start-Sleep -Milliseconds 600  # let MO2 finish flushing ModOrganizer.ini to disk
  Write-Host 'MO2 stopped.'
  return $true
}

function Start-Mo2 {
  param([string]$Exe, [string[]]$Arguments)
  if (-not $Exe) { $Exe = (Get-Mo2Paths).Exe }
  if (-not (Test-Path -LiteralPath $Exe)) { throw "ModOrganizer.exe not found: $Exe" }
  $startArgs = @{ FilePath = $Exe; WorkingDirectory = (Split-Path $Exe -Parent); PassThru = $true }
  if ($Arguments) { $startArgs.ArgumentList = $Arguments }
  $proc = Start-Process @startArgs
  Write-Host "Started MO2 (PID $($proc.Id))."
  return $proc
}

function Confirm-Mo2Ini {
  # Cold restore: the live ini is gitignored, so generate it from the template first.
  param([string]$RepoRoot, [string]$GamePath)
  $paths = Get-Mo2Paths -RepoRoot $RepoRoot
  if (-not (Test-Path -LiteralPath $paths.Ini)) {
    Write-Host 'ModOrganizer.ini missing - generating from template (configure-mo2.ps1).'
    $cfg = Join-Path (Split-Path $PSScriptRoot -Parent) 'configure-mo2.ps1'
    if ($GamePath) { & $cfg -GamePath $GamePath } else { & $cfg }
  }
}

function Add-Mo2Executable {
  <#
  .SYNOPSIS
    Idempotently register a custom executable in ModOrganizer.ini (by unique title).
  .NOTES
    Caller must ensure MO2 is NOT running (Assert-Mo2NotRunning), else MO2 clobbers this
    on exit. Handles [customExecutables] being the last section (no trailing header).
  #>
  param(
    [Parameter(Mandatory)][string]$Ini,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Binary,      # forward-slash path
    [Parameter(Mandatory)][string]$WorkingDir,  # forward-slash path
    [string]$Arguments = '',
    [string]$SteamAppID = '',
    [switch]$Select                             # make it the selected executable
  )
  if (-not (Test-Path -LiteralPath $Ini)) { throw "ModOrganizer.ini not found: $Ini" }
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  $raw = Get-Content -LiteralPath $Ini -Raw
  if ($raw -match "(?m)^\d+\\title=$([regex]::Escape($Title))\s*$") {
    Write-Host "  MO2 executable '$Title' already registered"
    return $false
  }
  if ($raw -notmatch '\[customExecutables\]') { throw "customExecutables section missing in $Ini" }

  $lines = Get-Content -LiteralPath $Ini
  $inCustom = $false; $sizeLine = -1; $endLine = -1; $size = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq '[customExecutables]') { $inCustom = $true; continue }
    if ($inCustom -and $lines[$i] -match '^\[') { $endLine = $i; break }
    if ($inCustom -and $lines[$i] -match '^size=(\d+)$') { $sizeLine = $i; $size = [int]$Matches[1] }
  }
  if ($sizeLine -lt 0) { throw "customExecutables size line not found in $Ini" }
  if ($endLine -lt 0) { $endLine = $lines.Count }  # section is last in the file

  $idx = $size + 1
  $lines[$sizeLine] = "size=$idx"
  $argEsc = $Arguments -replace '"', '\"'
  $insert = @(
    "$idx\arguments=$argEsc"
    "$idx\binary=$Binary"
    "$idx\hide=false"
    "$idx\ownicon=true"
    "$idx\steamAppID=$SteamAppID"
    "$idx\title=$Title"
    "$idx\toolbar=false"
    "$idx\workingDirectory=$WorkingDir"
  )
  $out = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -eq $endLine) { foreach ($x in $insert) { $out.Add($x) } }
    if ($Select -and $lines[$i] -match '^MainWindow_executablesListBox_index=') {
      $out.Add("MainWindow_executablesListBox_index=$idx")
    } else {
      $out.Add($lines[$i])
    }
  }
  if ($endLine -eq $lines.Count) { foreach ($x in $insert) { $out.Add($x) } }
  [System.IO.File]::WriteAllLines($Ini, $out.ToArray(), $utf8NoBom)
  Write-Host "  registered MO2 executable '$Title' (#$idx)"
  return $true
}

# --- Separators (ADR 0014) ---------------------------------------------------
# MO2: first line of modlist.txt = HIGHEST priority = BOTTOM of the left pane
# (Overwrite is always last/highest). A separator owns the mods listed BEFORE it in
# the file (higher priority / closer to Overwrite), up to the previous separator.
# Visually those mods nest under the separator header. Caller must ensure MO2 is
# NOT running when writing modlist.txt.

function Get-Mo2SeparatorFolderName {
  param([Parameter(Mandatory)][string]$Name)
  $n = $Name.Trim()
  if ($n -match '_separator$') { return $n }
  return "${n}_separator"
}

function Get-Mo2SeparatorOrder {
  param([string]$RepoRoot)
  if (-not $RepoRoot) { $RepoRoot = (Get-Mo2Paths).Root }
  $path = Join-Path $RepoRoot 'manifest\separators.json'
  if (-not (Test-Path -LiteralPath $path)) {
    return @(
      'User Interface', 'Frameworks & Resources', 'Script Extender & Core',
      'Creation Club', 'Official DLC'
    )
  }
  $cfg = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  return @($cfg.order)
}

function Ensure-Mo2Separator {
  <#
  .SYNOPSIS
    Create the empty '<Name>_separator' mod folder (+ meta.ini) if missing.
  #>
  param(
    [Parameter(Mandatory)][string]$ModsDir,
    [Parameter(Mandatory)][string]$Name
  )
  $folder = Get-Mo2SeparatorFolderName -Name $Name
  $dir = Join-Path $ModsDir $folder
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $meta = Join-Path $dir 'meta.ini'
  if (-not (Test-Path -LiteralPath $meta)) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $lines = @(
      '[General]'
      'gameName=SkyrimSE'
      'modid=0'
      'version='
      'newestVersion='
      'category=-1'
      'installationFile='
      'repository='
      'ignoredVersion='
    )
    [System.IO.File]::WriteAllLines($meta, $lines, $utf8NoBom)
  }
  return $folder
}

function Get-Mo2ModlistEntryName {
  param([string]$Line)
  if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
  if ($Line[0] -in @('+', '-', '*')) { return $Line.Substring(1) }
  return $null
}

function Get-Mo2SeparatorInsertIndex {
  # Where a new separator line should go. Separators appear AFTER their children in
  # the file. Insert after the previous separator's children block.
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$SeparatorFolder,
    [string[]]$Order
  )
  $wantName = $SeparatorFolder -replace '_separator$', ''
  $wantRank = [array]::IndexOf(@($Order), $wantName)
  if ($wantRank -lt 0) { $wantRank = $Order.Count }

  $best = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    $n = Get-Mo2ModlistEntryName -Line $Lines[$i]
    if (-not $n -or -not $n.EndsWith('_separator')) { continue }
    $disp = $n -replace '_separator$', ''
    $rank = [array]::IndexOf(@($Order), $disp)
    if ($rank -lt 0) { $rank = $Order.Count }
    if ($rank -lt $wantRank) { $best = $i }
  }

  if ($best -ge 0) {
    return ($best + 1)  # immediately after the previous separator line
  }
  return 0
}

function Add-Mo2ModToModlist {
  <#
  .SYNOPSIS
    Idempotently enable a mod under its separator in the profile modlist.txt.
  .DESCRIPTION
    MO2 nests a mod under a separator when the mod appears BEFORE the separator
    line in modlist.txt (higher priority). This helper ensures the separator folder
    exists, strips any prior +/- entry for the mod, ensures the separator line, and
    inserts the mod immediately before that separator (after any siblings).
  #>
  param(
    [Parameter(Mandatory)][string]$ProfileDir,
    [Parameter(Mandatory)][string]$ModsDir,
    [Parameter(Mandatory)][string]$ModName,
    [Parameter(Mandatory)][string]$Separator,
    [string]$RepoRoot,
    [switch]$Disabled
  )
  $sepFolder = Ensure-Mo2Separator -ModsDir $ModsDir -Name $Separator
  $order = Get-Mo2SeparatorOrder -RepoRoot $RepoRoot
  $path = Join-Path $ProfileDir 'modlist.txt'
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false

  $raw = @()
  if (Test-Path -LiteralPath $path) {
    $raw = @(Get-Content -LiteralPath $path)
  }

  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $raw) {
    if ($line -match '^# This file was automatically') { continue }
    if ($line -eq "+$ModName" -or $line -eq "-$ModName") { continue }
    $lines.Add($line)
  }

  $sepLine = "+$sepFolder"
  $hasSep = $false
  foreach ($line in $lines) {
    if ($line -eq $sepLine -or $line -eq "-$sepFolder") { $hasSep = $true; break }
  }
  if (-not $hasSep) {
    $insertAt = Get-Mo2SeparatorInsertIndex -Lines $lines -SeparatorFolder $sepFolder -Order $order
    if ($insertAt -ge $lines.Count) { $lines.Add($sepLine) }
    else { $lines.Insert($insertAt, $sepLine) }
  } else {
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -eq "-$sepFolder") { $lines[$i] = $sepLine }
    }
  }

  # Insert immediately before the separator (after any existing siblings already above it).
  $sepIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq $sepLine) { $sepIdx = $i; break }
  }
  if ($sepIdx -lt 0) { throw "Separator line missing after ensure: $sepFolder" }

  $modLine = if ($Disabled) { "-$ModName" } else { "+$ModName" }
  $lines.Insert($sepIdx, $modLine)

  $out = [System.Collections.Generic.List[string]]::new()
  $out.Add('# This file was automatically generated by Mod Organizer / Ebonveil')
  foreach ($x in $lines) { $out.Add($x) }
  [System.IO.File]::WriteAllLines($path, $out.ToArray(), $utf8NoBom)
  Write-Host "  modlist: $ModName -> under '$Separator'"
}

function Update-Mo2ModlistPlacements {
  <#
  .SYNOPSIS
    Place multiple mods under their separators (batch). Each item: @{ Name; Separator }.
  #>
  param(
    [Parameter(Mandatory)][string]$ProfileDir,
    [Parameter(Mandatory)][string]$ModsDir,
    [Parameter(Mandatory)][object[]]$Placements,
    [string]$RepoRoot
  )
  foreach ($p in $Placements) {
    Add-Mo2ModToModlist -ProfileDir $ProfileDir -ModsDir $ModsDir `
      -ModName $p.Name -Separator $p.Separator -RepoRoot $RepoRoot
  }
}

function Sync-Mo2ManagedSeparators {
  <#
  .SYNOPSIS
    Ensure Official DLC and Creation Club managed (*) entries sit under their separators.
  .NOTES
    Rebuilds the managed tail of modlist.txt: curated (+/-) content first (unchanged
    order), then CC lines + Creation Club_separator, then DLC lines + Official DLC_separator.
  #>
  param(
    [Parameter(Mandatory)][string]$ProfileDir,
    [Parameter(Mandatory)][string]$ModsDir,
    [string]$RepoRoot
  )
  $ccSep = Ensure-Mo2Separator -ModsDir $ModsDir -Name 'Creation Club'
  $dlcSep = Ensure-Mo2Separator -ModsDir $ModsDir -Name 'Official DLC'
  $path = Join-Path $ProfileDir 'modlist.txt'
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false

  $raw = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)
  $curated = [System.Collections.Generic.List[string]]::new()
  $cc = [System.Collections.Generic.List[string]]::new()
  $dlc = [System.Collections.Generic.List[string]]::new()

  foreach ($line in $raw) {
    if ($line -match '^# This file was automatically') { continue }
    $n = Get-Mo2ModlistEntryName -Line $line
    if ($n -eq $ccSep -or $n -eq $dlcSep) { continue }
    if ($line.StartsWith('*') -and $n -like 'Creation Club:*') { $cc.Add($line); continue }
    if ($line.StartsWith('*') -and $n -like 'DLC:*') { $dlc.Add($line); continue }
    $curated.Add($line)
  }

  $out = [System.Collections.Generic.List[string]]::new()
  $out.Add('# This file was automatically generated by Mod Organizer / Ebonveil')
  foreach ($x in $curated) { $out.Add($x) }
  foreach ($x in $cc) { $out.Add($x) }
  $out.Add("+$ccSep")
  foreach ($x in $dlc) { $out.Add($x) }
  $out.Add("+$dlcSep")
  [System.IO.File]::WriteAllLines($path, $out.ToArray(), $utf8NoBom)
  Write-Host "  modlist: managed CC ($($cc.Count)) + DLC ($($dlc.Count)) under separators"
}

function Get-Mo2ManifestCategoryMap {
  # mod folder name / match key -> category (separator display name)
  param([string]$RepoRoot)
  $map = @{}
  $manifestPath = Join-Path $RepoRoot 'manifest\mods.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { return $map }
  $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  foreach ($mod in @($m.mods)) {
    if (-not $mod.category) { continue }
    $cat = [string]$mod.category
    if ($mod.match) { $map[[string]$mod.match] = $cat }
    if ($mod.name) { $map[[string]$mod.name] = $cat }
    if ($mod.id -eq 'ussep') { $map['USSEP'] = $cat }
    if ($mod.id -eq 'alternate-start-lal') { $map['Alternate Start - Live Another Life'] = $cat }
    if ($mod.id -eq 'skyui') { $map['SkyUI'] = $cat }
    if ($mod.id -eq 'address-library') { $map['Address Library for SKSE Plugins'] = $cat }
  }
  return $map
}

function Resolve-Mo2ModCategory {
  param([string]$ModName, [hashtable]$CategoryMap, [string]$FallbackSeparator)
  if ($CategoryMap) {
    if ($CategoryMap.ContainsKey($ModName)) { return $CategoryMap[$ModName] }
    foreach ($key in $CategoryMap.Keys) {
      if ($ModName -like "$key*" -or $ModName -match [regex]::Escape($key)) { return $CategoryMap[$key] }
    }
  }
  if ($FallbackSeparator) { return $FallbackSeparator }
  return 'Other Mods'
}

function Rebuild-Mo2ModlistStack {
  <#
  .SYNOPSIS
    Rebuild curated modlist.txt so separator blocks follow manifest/separators.json order.
  .DESCRIPTION
    Parses existing enabled/disabled curated mods, maps each to a category (manifest first,
    else the separator it currently sits under), ensures separator folders exist, then writes
    highest-priority-first blocks. Managed CC/DLC are re-attached via Sync-Mo2ManagedSeparators.
    Call this after installs so new separators are spliced into the stack (ADR 0016) instead of
    left in a wrong priority band.
  #>
  param(
    [Parameter(Mandatory)][string]$ProfileDir,
    [Parameter(Mandatory)][string]$ModsDir,
    [string]$RepoRoot
  )
  if (-not $RepoRoot) { $RepoRoot = (Get-Mo2Paths).Root }
  $order = @(Get-Mo2SeparatorOrder -RepoRoot $RepoRoot)
  $catMap = Get-Mo2ManifestCategoryMap -RepoRoot $RepoRoot
  $path = Join-Path $ProfileDir 'modlist.txt'
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  $raw = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)

  # Preserve managed rows before we rewrite curated content.
  $ccLines = [System.Collections.Generic.List[string]]::new()
  $dlcLines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $raw) {
    $n = Get-Mo2ModlistEntryName -Line $line
    if ($line.StartsWith('*') -and $n -like 'Creation Club:*') { $ccLines.Add($line) }
    if ($line.StartsWith('*') -and $n -like 'DLC:*') { $dlcLines.Add($line) }
  }

  $buckets = @{}  # category -> list of full lines (+/-Mod)
  foreach ($o in $order) { $buckets[$o] = [System.Collections.Generic.List[string]]::new() }
  $currentSep = $null

  foreach ($line in $raw) {
    if ($line -match '^# This file was automatically') { continue }
    if ($line.StartsWith('*')) { continue }  # managed reattached below
    $n = Get-Mo2ModlistEntryName -Line $line
    if (-not $n) { continue }
    if ($n.EndsWith('_separator')) {
      $currentSep = $n -replace '_separator$', ''
      if (-not $buckets.ContainsKey($currentSep)) {
        $buckets[$currentSep] = [System.Collections.Generic.List[string]]::new()
      }
      continue
    }
    $cat = Resolve-Mo2ModCategory -ModName $n -CategoryMap $catMap -FallbackSeparator $currentSep
    if (-not $buckets.ContainsKey($cat)) {
      $buckets[$cat] = [System.Collections.Generic.List[string]]::new()
    }
    $prefix = $line[0]
    $buckets[$cat].Add("$prefix$n")
  }

  $out = [System.Collections.Generic.List[string]]::new()
  $out.Add('# This file was automatically generated by Mod Organizer / Ebonveil')
  foreach ($sepName in $order) {
    if ($sepName -in @('Creation Club', 'Official DLC')) { continue }
    $mods = @($buckets[$sepName])
    if ($mods.Count -eq 0) { continue }
    [void](Ensure-Mo2Separator -ModsDir $ModsDir -Name $sepName)
    foreach ($m in $mods) { $out.Add($m) }
    $out.Add("+$($sepName)_separator")
  }
  foreach ($key in @($buckets.Keys | Sort-Object)) {
    if ($key -in $order) { continue }
    $mods = @($buckets[$key])
    if ($mods.Count -eq 0) { continue }
    [void](Ensure-Mo2Separator -ModsDir $ModsDir -Name $key)
    foreach ($m in $mods) { $out.Add($m) }
    $out.Add("+$($key)_separator")
  }

  # Reattach managed CC/DLC (do not rely on Sync reading a file that already dropped them).
  $ccSep = Ensure-Mo2Separator -ModsDir $ModsDir -Name 'Creation Club'
  $dlcSep = Ensure-Mo2Separator -ModsDir $ModsDir -Name 'Official DLC'
  foreach ($x in $ccLines) { $out.Add($x) }
  $out.Add("+$ccSep")
  foreach ($x in $dlcLines) { $out.Add($x) }
  $out.Add("+$dlcSep")

  [System.IO.File]::WriteAllLines($path, $out.ToArray(), $utf8NoBom)
  Write-Host "  modlist: rebuilt stack (CC=$($ccLines.Count) DLC=$($dlcLines.Count)); separators from separators.json"
}

function Get-Mo2ModDataRoot {
  # Mod folder may be Data-rooted or have files at top level (MO2 style).
  param([string]$ModDir)
  $data = Join-Path $ModDir 'Data'
  if (Test-Path -LiteralPath $data) { return $data }
  return $ModDir
}

function Scan-Mo2LooseFileConflicts {
  <#
  .SYNOPSIS
    Approximate MO2 loose-file conflicts: same relative path across enabled mods.
  .NOTES
    MO2 does not export a conflict report to disk (conflicts are computed in-memory /
    Conflicts UI / Python getFileOrigins). This scan covers loose files only -- not BSA/BA2.
    Winner = last mod in modlist.txt file order among providers (highest priority).
  #>
  param(
    [Parameter(Mandatory)][string]$ProfileDir,
    [Parameter(Mandatory)][string]$ModsDir,
    [string[]]$OnlyMods,          # optional: only report paths touched by these mod folders
    [string[]]$PathPrefixes,      # e.g. 'textures','meshes','scripts','SKSE\Plugins'
    [int]$MaxResults = 200
  )
  $modlist = @(Get-Content (Join-Path $ProfileDir 'modlist.txt') -ErrorAction SilentlyContinue)
  $enabled = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $modlist) {
    if ($line -notmatch '^\+') { continue }
    $n = Get-Mo2ModlistEntryName -Line $line
    if (-not $n -or $n.EndsWith('_separator')) { continue }
    $enabled.Add($n)
  }

  # path -> list of mod names in ascending priority (modlist order)
  $index = @{}
  foreach ($modName in $enabled) {
    $modDir = Join-Path $ModsDir $modName
    if (-not (Test-Path -LiteralPath $modDir)) { continue }
    $root = Get-Mo2ModDataRoot -ModDir $modDir
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
      $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
      if ($rel -match '(?i)^meta\.ini$' -or $rel -match '(?i)\.txt$' -or $rel -match '(?i)\.mohidden$') { return }
      if ($PathPrefixes -and $PathPrefixes.Count -gt 0) {
        $ok = $false
        foreach ($p in $PathPrefixes) {
          if ($rel -like "$p*") { $ok = $true; break }
        }
        if (-not $ok) { return }
      }
      $key = $rel.ToLowerInvariant()
      if (-not $index.ContainsKey($key)) { $index[$key] = [System.Collections.Generic.List[object]]::new() }
      $index[$key].Add([PSCustomObject]@{ Mod = $modName; Rel = $rel })
    }
  }

  $conflicts = [System.Collections.Generic.List[object]]::new()
  foreach ($key in $index.Keys) {
    $providers = @($index[$key])
    if ($providers.Count -lt 2) { continue }
    if ($OnlyMods -and $OnlyMods.Count -gt 0) {
      $touch = $false
      foreach ($p in $providers) { if ($OnlyMods -contains $p.Mod) { $touch = $true; break } }
      if (-not $touch) { continue }
    }
    $winner = $providers[-1].Mod
    $losers = @($providers[0..($providers.Count - 2)] | ForEach-Object { $_.Mod })
    $conflicts.Add([PSCustomObject]@{
        path   = $providers[-1].Rel
        winner = $winner
        losers = $losers
        count  = $providers.Count
      })
    if ($conflicts.Count -ge $MaxResults) { break }
  }
  return @($conflicts | Sort-Object path)
}
