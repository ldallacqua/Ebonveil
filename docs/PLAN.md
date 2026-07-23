# Ebonveil — architecture plan

## Goals

1. Portable MO2 instance under `C:\Modding\Ebonveil` (git-backed configs).
2. Steam SSE tree stays clean / revertible (Root Builder primary; Stock Game optional later).
3. Reproducible restore: clone → bootstrap MO2 → Nexus auth → `restore-mods.ps1`.
4. Load order theme: immersion, graphics, romance, NSFW.

## Pipeline

```
manifest/mods.json ──► tools/restore-mods.ps1 ──► mo2/downloads/*.7z|*.zip
                                              └──► (future) auto-install into mo2/mods
profiles/*          ──► git ──► load order / enabled flags
tools/bootstrap-mo2 ──► mo2/ModOrganizer.exe (not in git)
Root Builder        ──► deploy root/ from mods → game root on launch
```

## Milestones

| ID | Scope | Status |
|----|--------|--------|
| M0 | Repo, docs, ADRs, MO2 portable bootstrap, gitignore | Done |
| M1 | Root Builder + SKSE (Nexus 30379) + Address Library + SkyUI | In progress — remove silverlock hand-pack; install via Nexus + RB |
| M1b | BethINI Pie optimal profile INIs | Pending (INI missing dialog is OK until then) |
| M2 | Engine fixes (SSE Engine Fixes, .NET, VC redists already host-level), Crash Logger, Papyrus Util, etc. | Pending |
| M3 | Graphics baseline (SMIM, landscapes, weather, ENB/CS via Root Builder) | Pending |
| M4 | Immersion / romance / NSFW stack (explicit curated list) | Pending |
| M5 | Full cold-restore dry-run on clean path | Pending |

## Automation limits (honest)

| Task | Automatable now? | Notes |
|------|------------------|-------|
| MO2 portable fetch/extract | Yes | `bootstrap-mo2.ps1` |
| SKSE pin + download | Yes | silverlock `/beta/` URLs |
| SKSE → MO2 mod folder | Yes | `install-skse-mod.ps1` |
| Root Builder / SkyUI / Address Library download | Needs Nexus API key (+ often Premium for CDN) | `nexus-auth.ps1` + `restore-mods.ps1` |
| FOMOD wizard answers | Partial / future | Many FOMODs need recorded choices in manifest |
| Root Builder first-time GUI setup | Low confidence unattended | You should click through once; we document |
| Stock Game copy (~20GB) | Scriptable later | Deferred ADR 0002 |

## Naming

**Ebonveil** — dark / immersive / intimate tone. Rename only via ADR if you hate it.
