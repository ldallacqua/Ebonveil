# ADR 0013 — Guard against MO2's config rewrite; centralize MO2 helpers; robust 7-Zip

## Status

Accepted (2026-07-23)

## Context

Three related failure modes surfaced while wiring up the modding tools:

1. **MO2 clobbers config edits made while it runs.** MO2 reads `ModOrganizer.ini` and the
   profile `modlist.txt` / `plugins.txt` **only at startup**, and **rewrites them on exit**
   from its in-memory state. Registering the LOOT/SSEEdit/BethINI executables while MO2 was
   open worked on disk, but MO2 (holding the old 4-entry list) overwrote the ini back to
   `size=4` on its next exit — the tools silently vanished from the executables dropdown.
   The same hazard applies to `install-m1.ps1`, which edits both the ini (SKSE entry) and
   the profile modlist/plugins.

2. **Duplicated ini-editing logic drifts.** `install-m1.ps1` (`Update-SkseExecutable`) and
   `bootstrap-tools.ps1` (`Add-Mo2Executable`) each had their own custom-executable writer.
   They already diverged: the install-m1 version **throws** when `[customExecutables]` is the
   last section in the file (`$widgetsLine` never set), while the tools version handled it.

3. **7-Zip detection selected an unusable stub.** `install-m1.ps1` and `bootstrap-mo2.ps1`
   resolved `7z.exe` via `Get-Command 7z` (and even hardcoded the WindowsApps path). On this
   machine that is the **WindowsApps execution-alias for NanaZip** — a 0-byte reparse-point
   stub that launches **detached** and returns exit 0 *before* extraction finishes, producing
   empty output with no error. Extractions would silently yield nothing.

## Decision

- **Single shared library `tools/lib/Ebonveil.Mo2.ps1`**, dot-sourced by every MO2-touching
  script. One canonical implementation of each helper:
  - `Find-7Zip` — prefers a real `Program Files` 7-Zip; **skips `\WindowsApps\` stubs and
    0-byte files**; errors with an install hint if none found.
  - `Get-Mo2Process` / `Test-Mo2Running` — match **only this repo's** `mo2/ModOrganizer.exe`
    by image path (never touch another MO2 instance).
  - `Assert-Mo2NotRunning` — fail fast (before downloads/edits) with copy-paste remediation.
  - `Stop-Mo2` (graceful close → timeout → force-kill → flush delay; returns "was running")
    and `Start-Mo2`.
  - `Confirm-Mo2Ini` — generate the live ini from the template on cold restore (ADR 0009).
  - `Add-Mo2Executable` — idempotent by title; handles `[customExecutables]` as the last
    section; optional `-Select` + `-SteamAppID`.
- **Every script that edits the ini or profile guards on a running MO2.** Default: refuse
  via `Assert-Mo2NotRunning`. Opt-in `-RestartMo2` stops MO2, applies changes, relaunches.
  `bootstrap-mo2.ps1` guards its destructive `-Force` re-extract the same way.
- **`tools/restart-mo2.ps1 -Between { ... }`** is the canonical way to apply config edits
  safely: stop MO2 → run the block while it's down → relaunch. Agents should use this (or
  `-RestartMo2`) after any ini/profile change.

## Consequences

- `install-m1.ps1`, `bootstrap-tools.ps1`, `bootstrap-mo2.ps1`, and `restart-mo2.ps1` now
  dot-source `Ebonveil.Mo2.ps1`; their local `Find-7Zip` / `Add-Mo2Executable` /
  `Stop`/`Start` copies were removed.
- Bugs fixed: WindowsApps-stub extraction, last-section ini throw, and the config-clobber
  class of failure.
- New `-RestartMo2` switch on `install-m1.ps1` and `bootstrap-tools.ps1`.
- Prerequisite tightened: a **real** 7-Zip install (`winget install --id 7zip.7zip -e`);
  the WindowsApps alias is explicitly unsupported.
- All automation is catalogued in `docs/AUTOMATION.md` (the agent-facing reference).

## Golden rule for future agents

> Never edit `ModOrganizer.ini` or a profile's `modlist.txt`/`plugins.txt`/`loadorder.txt`
> while MO2 is running. Use `restart-mo2.ps1 -Between` or a script's `-RestartMo2` switch.
