---
gsd_state_version: "1.0"
current_phase: 01
status: unknown
stopped_at: Phase 1 UI-SPEC approved
last_updated: "2026-10-04T08:06:21.456Z"
state_head: 1465c9ce9c4aca412ef5242b37648c446d790f3b
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 1
  completed_plans: 0
  percent: 0
current_phase_name: Foundation — Shell + State Machine
---

# AkariOS State

**Last updated:** 2026-10-04
**Current phase:** 01
**Phase status:** Not started
**Mode:** mvp

## Project Reference

See `.planning/PROJECT.md` for full project context.

**Core value:** The user clicks **Install AkariOS** once, and the machine walks
itself through all three WinSux stages across the reboots with visible progress —
no console menus, no typed numbers, no re-launching anything by hand.

**Current focus:** Phase 01 — Foundation — Shell + State Machine
compiled `akarios.ps1` with a working WPF GUI shell, reboot-surviving state
machine, pre-flight checks, admin elevation, confirmation gating, logging
infrastructure, and progress reporting.

## Phase Progress

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 1 | Foundation — Shell + State Machine | Not started | PREF-01..03, SAFE-02..04, PROG-01..03, DIAG-01 |
| 2 | Core Engine — Stage Integration | Not started | FLOW-01..03, DIAG-02 |
| 3 | Hardening — Destructive Stage Hardening + Branding + Diagnostics | Not started | SAFE-01, BRND-01, DIAG-03..04 |
| 4 | Testing — VM-Based Validation | Not started | (validation only) |
| 5 | Distribution — Security + Packaging | Not started | (packaging only) |

## Key Risks

- **RunOnce hive divergence:** HKLM vs HKCU behavior in Safe Mode needs VM validation
- **State file location:** Must survive `cleanmgr` and `C:\Windows\Temp\*` deletion
- **TrustedInstaller binPath repointing:** Must be restored reliably or Windows Update breaks
- **Safeboot flag:** Must be cleared at START of Stage 2, not end, to avoid Safe Mode loop
- **Power-cycle mid-stage:** Recovery script needed for interrupted installs

## Decisions Log

| Decision | Date | Rationale |
|----------|------|-----------|
| Use HKLM RunOnce for system-level resume | 2026-10-04 | Fires regardless of which user logs in; correct hive for system-level boot handoff |
| Clear safeboot at START of stepone.ps1 | 2026-10-04 | If script crashes later, machine still boots normally — strictly safer |
| Write state to `C:\ProgramData\AkariOS\state.json` | 2026-10-04 | Survives disk cleanup that deletes `%TEMP%` |
| Embed engine scripts as base64, download payloads at runtime | 2026-10-04 | Engine must match GUI version; payloads are large binaries that change frequently |
| Modify WinSux scripts where pitfalls identified | 2026-10-04 | Preserve overall structure and intent; document all deviations from upstream |

---
*State last updated: 2026-10-04*

## Session

**Last session:** 2026-10-04T07:11:50.611Z
**Stopped at:** Phase 1 UI-SPEC approved
**Resume file:** .planning/phases/01-foundation-shell-state-machine/01-UI-SPEC.md
