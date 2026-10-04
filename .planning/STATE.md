---
gsd_state_version: "1.0"
current_phase: 02
status: complete
stopped_at: Phase 2 complete (static verification only; VM validation owed to Phase 4)
last_updated: "2026-10-04T12:00:00.000Z"
state_head: b006c1e
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 5
  completed_plans: 5
  percent: 40
current_phase_name: Core Engine — Stage Integration
---

# AkariOS State

**Last updated:** 2026-10-04
**Current phase:** 02
**Phase status:** Complete (static verification only - runtime pending VM)
**Mode:** mvp

## Project Reference

See `.planning/PROJECT.md` for full project context.

**Core value:** The user clicks **Install AkariOS** once, and the machine walks
itself through all three WinSux stages across the reboots with visible progress —
no console menus, no typed numbers, no re-launching anything by hand.

**Current focus:** Phase 02 — Core Engine — Stage Integration
compiled `akarios.ps1` with a working WPF GUI shell, reboot-surviving state
machine, pre-flight checks, admin elevation, confirmation gating, logging
infrastructure, and progress reporting.

## Phase Progress

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 1 | Foundation — Shell + State Machine | Complete (PROG-03 partial) | PREF-01..03, SAFE-02..04, PROG-01..02, DIAG-01 |
| 2 | Core Engine — Stage Integration | Complete (static verification only; VM validation owed to Phase 4) | FLOW-01..03, DIAG-02 |
| 3 | Hardening — Destructive Stage Hardening + Branding + Diagnostics | Not started | SAFE-01, BRND-01, DIAG-03..04 |
| 4 | Testing — VM-Based Validation | Not started | (validation only) |
| 5 | Distribution — Security + Packaging | Not started | (packaging only) |

## Key Risks

- **RunOnce hive divergence:** HKLM vs HKCU behavior in Safe Mode needs VM validation
- **State file location:** Must survive `cleanmgr` and `C:\Windows\Temp\*` deletion
- **TrustedInstaller binPath repointing:** Must be restored reliably or Windows Update breaks
- **Safeboot flag:** Must be cleared at START of Stage 2, not end, to avoid Safe Mode loop
- **Power-cycle mid-stage:** Recovery script needed for interrupted installs
- **RunOnce fires at LOGON, not at boot — and Safe Mode does not auto-logon (D-11, the project's highest listed risk):** the `*!stepone` entry and the `!` prefix's Safe Mode behaviour are both **unproven** and cannot be checked statically. Safe Mode also skips RunOnce entirely for a non-elevated logged-on user, and WinSux configures no auto-logon. **Phase 4 MUST include an explicit "log on as an administrator at the Safe Mode prompt" step, or it will report a false failure.** No auto-logon is configured (D-11).
- **Stage 3 destroys all RunOnce keys** (`steptwo.ps1:324-333`, HKCU + HKLM + WOW6432Node). Any RunOnce-based GUI relaunch after the final reboot is dead on arrival. See the relaunch deviation in the Decisions Log.
- **Phase 1 open defect: `Progress.ps1:101` passes `-Status "installing"`**, which is absent from the `ValidateSet` at `State.ps1:111`. The call throws into its own catch, so **within-stage progress is never persisted to `state.json`**. Not fixed in Phase 2 (it is a Phase 1 defect, and adding a status constant would change Phase 1's validated schema). Phase 2 works around it by treating `Get-ResumePoint` as the source of truth. Phase 4 must observe it as a real defect.
- **Phase 1 open defect D-01: pre-flight checks never auto-run**, so the Install button stays disabled until the user opens the Check tab. **This blocks manual testing of Phase 2's single-click flow** and should be fixed before Phase 4 begins.

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
| Engine scripts embedded byte-identical as base64 assets, never edited (D-06) | 2026-10-04 | RATIFIED as a one-way decision at 02-01's reversibility gate: "Ratify all three as written (recommended) — proceed to the tracer slice". The three WinSux stage scripts plus `reg.reg` ship as byte-identical base64 assets; AkariOS never patches them (not the `IWR` alias usage, not the `HKLM:` colon typo at `steptwo.ps1:332`). Undo = re-embed and re-test everything. Enforced by V8 in `02-VERIFICATION.md` and by `.gitattributes` pinning the four files `-text` (without it, `* text=auto` + `core.autocrlf=true` would CRLF-normalize them on a fresh VM checkout and break both the byte-identity check and the embedded base64) |
| The engine runs as a child `powershell.exe -File <decoded>` process, never in-process | 2026-10-04 | RATIFIED as a one-way decision at 02-01's reversibility gate, verbatim: "Process boundary — ratified: the engine runs behind a child-process boundary. `Invoke-AkariOSEngine` launches a child `powershell.exe -File <decoded>`, never an in-process runspace scriptblock. Undo = a second execution path." Two independent reasons: the engine self-elevates with `Start-Process -Verb RunAs` + `Exit` in its first four lines, so in-process would terminate our own runspace; and `Pause`, `Clear-Host` and `$Host.UI.RawUI` each need their own console host. A child process also yields a real `ExitCode` for D-10 |
| `Start-AkariOSInstall` is the published contract name | 2026-10-04 | RATIFIED as a one-way decision at 02-01's reversibility gate, verbatim: "`Start-AkariOSInstall` as a published contract name — ratified. `Confirm.ps1:233` already resolves that exact name by convention; renaming it later breaks a contract Phase 1 already shipped." The single-click flow goes live the moment the function exists, with no edit to a Phase 1 file |
| Error detection is an independent `Get-AkariOSStageFailure` check; it deliberately does NOT add a `ResumePoint` value | 2026-10-04 | RESEARCH §5 Decision 6 / §7 Decision 3. `Get-ResumePoint`'s decision table has no error branch, and `main.ps1`'s resume switch has none either. An independent additive check leaves Phase 1's verified D-03/D-05 behaviour byte-identical; adding a `ResumePoint = "error"` value would change verified Phase 1 behaviour and require re-verification. Asserted by `Test-Stage.ps1` ("no error case in the resume switch", "no new ResumePoint value introduced") and `Test-Diagnostics.ps1` |
| No auto-logon is configured (D-11) | 2026-10-04 | RunOnce fires at LOGON, not at boot, and Safe Mode does not auto-logon — so the flow can sit at the Safe Mode logon prompt forever with `safeboot` still set. But adding auto-logon is a new security-relevant change to machine state, it is outside Phase 2's boundary (Phase 3 owns hardening), and D-11 explicitly rules out belt-and-braces Safe Mode mechanisms. The cheapest available mitigation needs no engine change: a `Set-Status` / `StageHandoffHint` copy telling the user to log on as an administrator. `Test-Panels.ps1` asserts the hint names 'console', 'log on', 'Safe Mode', 'ADMINISTRATOR' and the Display Driver Uninstaller, and that no autologon change exists anywhere in `Stage.ps1`. The unresolved risk stays D-11 and is Phase 4's headline item |
| No post-Stage-3 `!AkariOS` relaunch RunOnce entry is written — DEVIATION from Phase 1's research | 2026-10-04 | `research/STACK.md` ("Stack Patterns by Variant") assumed one. It cannot work: `steptwo.ps1:324-333` deletes and recreates the RunOnce keys in HKCU, HKLM and WOW6432Node, destroying any entry written before or during Stage 3 — the entry would be dead on arrival. The post-final-reboot GUI relaunch is therefore left DETECTION-driven and its viability is a Phase 4 VM decision. Writing an entry that always dies is strictly worse than writing none, because an AkariOS RunOnce key that sometimes vanishes costs a debugging session. `Test-Stage.ps1` asserts it appears nowhere (`grep -c '!AkariOS' akarios.ps1` → 0). **An executor re-adding this mechanism is contradicted by this record** |
| AkariOS uses the existing `error` status; no new status constant is added | 2026-10-04 | The `ValidateSet` at `State.ps1:111` is unchanged and byte-identical to Phase 1's, asserted by `Test-Diagnostics.ps1`. The separate `Progress.ps1:101` `ValidateSet` mismatch (`"installing"`, not a member) is a **Phase 1 defect, left unfixed deliberately** — working around it by adding a status constant would change Phase 1's validated schema for no Phase 2 benefit. Phase 2's launch reconciliation works around it by using `Get-ResumePoint` as the source of truth and `state.json` only as log-line corroboration |

---
*State last updated: 2026-10-04*

## Session

**Last session:** 2026-10-04T12:00:00.000Z
**Stopped at:** Phase 2 complete — static verification only
**Resume file:** `.planning/phases/02-core-engine-stage-integration/02-VERIFICATION.md`
**Next step:** Phase 03 (Hardening). Before Phase 04 begins, read the ten
manual-only items in `02-VERIFICATION.md` — in particular **M9 (Phase 1 defect
D-01 blocks the single-click flow)**, **M1/M2 (log on as administrator at the
Safe Mode prompt)**, and **M10 (the `installing` status `ValidateSet` defect)**.
