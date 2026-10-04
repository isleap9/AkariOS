---
gsd_state_version: "1.0"
current_phase: 2 — Core Engine — Stage Integration
status: complete
stopped_at: Phase 2 context gathered
last_updated: "2026-10-04T08:58:36.257Z"
state_head: 68dbb0b8691365288dfda5c9457f9b4e9917a9c4
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
  percent: 20
current_phase_name: Core Engine — Stage Integration
---

# AkariOS State

**Last updated:** 2026-10-04
**Current phase:** 2 — Core Engine — Stage Integration
**Phase status:** Complete (static verification only - runtime pending VM)
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
| 1 | Foundation — Shell + State Machine | Complete (PROG-03 partial) | PREF-01..03, SAFE-02..04, PROG-01..02, DIAG-01 |
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
| Confirm gate uses a modal Window + ShowDialog, not the XAML overlay | 2026-10-04 | A private DispatcherFrame loop hangs if its "finished" flag is never set; GetNewClosure captures by value and Add_Click returns $null. ShowDialog is WPF's own modal loop with explicit exit paths. Dead ConfirmOverlay grid removed from MainWindow.xaml |
| Confirmation token match is case-SENSITIVE (Ordinal) | 2026-10-04 | Stricter than the original draft; set per orchestrator instruction. Noted in 01-SUMMARY.md as the one decision taken without a spec ruling |
| State field names are CurrentStage / Progress | 2026-10-04 | Matched the state.json schema; earlier drafts used Stage / StagePercent and were corrected during task 6.3 |
| All .ps1 sources carry a UTF-8 BOM | 2026-10-04 | PowerShell 5.1 decodes BOM-less UTF-8 as ANSI and mangles the box-drawing and em-dash characters |
| PROG-03 left partial | 2026-10-04 | No code path sets ProgressBar1.IsIndeterminate = $true yet; deferred to Phase 2 alongside the real stage runner |

---
*State last updated: 2026-10-04*

## Session

**Last session:** 2026-10-04T08:58:36.171Z
**Stopped at:** Phase 2 context gathered
**Resume file:** .planning/phases/02-core-engine-stage-integration/02-CONTEXT.md
**Next step:** Phase 02 - embed the WinSux engine scripts in assets/text/ and implement Start-AkariOSInstall
