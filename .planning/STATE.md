---
gsd_state_version: "1.0"
current_phase: 03
status: in_progress
stopped_at: "Phase 3 Wave 1 Task 2 complete - relaunch mechanism built and verified. Tasks 3-4 of 03-01 remain: DIAG-04 summary panel, then mutation-test and ship."
last_updated: "2026-10-04T15:10:00.000Z"
state_head: 85dde3e
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 9
  completed_plans: 6
  percent: 44
current_phase_name: Hardening — Destructive Stage Hardening + Branding + Diagnostics
phase_03_plan_progress: "1 of 4 plans started; 03-01 task 2 of 4 complete"
---

# AkariOS State

**Last updated:** 2026-10-04 (resumed after Phase 2 VM validation)
**Current phase:** 03
**Phase status:** 02 COMPLETE and VM-VALIDATED (all three stages ran for real across two reboots and Safe Mode). 03 in progress.
**Mode:** mvp

## Project Reference

See `.planning/PROJECT.md` for full project context.

**Core value:** The user clicks **Install AkariOS** once, and the machine walks
itself through all three WinSux stages across the reboots with visible progress —
no console menus, no typed numbers, no re-launching anything by hand.

**Current focus:** Phase 03 Wave 1 — GUI relaunch + DIAG-04 summary

Phase 01 and 02 shipped: `akarios.ps1` compiles to a working WPF GUI shell with a
reboot-surviving state machine, pre-flight checks, admin elevation, confirmation
gating, logging, progress rendering, and all three WinSux stages executing for
real. Phase 03 adds the post-install relaunch, the "what changed" summary,
restore point, log export, and AkariOS branding.

## Phase Progress

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 1 | Foundation — Shell + State Machine | Complete | PREF-01..03, SAFE-02..04, PROG-01..02, DIAG-01 |
| 2 | Core Engine — Stage Integration | **Complete — VM-validated** | FLOW-01..03, DIAG-02 |
| 3 | Hardening — Hardening + Branding + Diagnostics | **In progress** (Wave 1 task 2 of 4) | SAFE-01, BRND-01, DIAG-03..04 |
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

## Session Continuity

Last session: 2026-10-04 (resumed via /gsd-resume-work)
Stopped at: Phase 03 Wave 1, plan 03-01, task 2 of 4 complete.
Resume file: none — no .continue-here or HANDOFF.json present.

### Where we left off
03-01 task 2 shipped the post-install relaunch mechanism in commits 495fff8
(mechanism) and 85dde3e (harness):

- `AkariOS/functions/public/Relaunch.ps1` (new): pure schtasks argument builder,
  `Set-AkariOSRelaunchTask` / `Remove-AkariOSRelaunchTask` behind a `-TaskWriter`
  seam, `Copy-AkariOSRelaunchScript` behind a `-FileCopier` seam. Both task
  functions carry the `Invoke-AkariOSEngine` null-invoker fallback and never throw.
- `Stage.ps1`: additive `-Stage 3` branch that stages the script, THEN creates the
  task, THEN launches the engine. Zero deletions in the diff — Stage 1 and
  Stage 2 branches byte-unchanged.
- `AkariOS/tools/Test-Relaunch.ps1` (new): behavioural, not grep-only.

Independently verified after the fact: 15/15 harnesses pass, all four engine
assets MD5-match WinSux-main, and two independent mutations both turned RED
(removing the null-invoker fallback -> 8 failures; flipping the absent-task log
from INFO to WARN -> 2 failures).

### Remaining in 03-01
- Task 3: the DIAG-04 "what changed" summary, driven by log evidence.
- Task 4: mutation-test both harnesses, then ship the panel and the compiled artefact.

### Owed to Phase 4 (VM only, cannot be checked here)
- That the GUI actually relaunches after Stage 3.
- That the relaunched window is VISIBLE, not on session 0's phantom desktop. The
  task uses ONLOGON + interactive user + /IT + /RL HIGHEST for exactly this
  reason, with a logged-WARN fallback to /RU SYSTEM.
- Safe Mode administrator logon at the prompt — RunOnce only fires at logon.

### Carried concerns
- Phase 03 roadmap originally listed 9 items; 6 were deferred by explicit user
  decision (Edge hardening, task-deletion blocklist, BitLocker pre-check, WU-pause
  configurability, DISM error handling, payload hashing) because they would require
  patching the vendored engine, which D-06 forbids. Consequence: WU pause stays
  at 365 days and there is no BitLocker pre-check.
- `.planning/phases/02-core-engine-stage-integration/02-VERIFICATION-PHASE.md` is
  untracked. The independent verifier returned human_needed, 14/16, zero gaps.
