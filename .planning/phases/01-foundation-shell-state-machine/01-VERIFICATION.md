---
phase: 01-foundation-shell-state-machine
plan: 01-PLAN.md
status: passed
verified: 2026-10-04
verification_mode: static-only (no VM / no live-machine execution)
requirements_passed: [PREF-01, PREF-02, PREF-03, SAFE-02, SAFE-03, SAFE-04, PROG-01, PROG-02, DIAG-01]
requirements_partial: [PROG-03]
requirements_failed: []
open_defects: 1
---

# Phase 01 Verification — Foundation — Shell + State Machine

Verified by the orchestrator (the delegated verifier aborted after 27s without
producing output, so verification was done inline).

**Verification mode: STATIC ONLY.** Per the user's explicit instruction, nothing
was executed against the live machine — no launch, no `bcdedit`, no registry
writes, no `C:\ProgramData\AkariOS`, no WinSux stage script. Everything below is
established by reading code plus PowerShell parser / XAML parse / grep checks.

## Requirement traceability

| ID | Verdict | Evidence |
|----|---------|----------|
| PREF-01 | PASS (static) | Six checks implemented in `functions/public/Check.ps1:46-243`: `Test-WindowsVersion` (build ≥19042), `Test-AdminElevation`, `Test-InternetConnectivity` (TCP probe, no data), `Test-DiskSpace` (≥4 GB), `Test-PendingReboot` (read-only, `Check.ps1:178-215`), `Test-PowerState`. Aggregate in `Invoke-PreFlightChecks:245`. |
| PREF-02 | PASS | `Invoke-PreFlightChecks` is the single source of truth (`Check.ps1:284-297` → `CanInstall = ($blockingFails.Count -eq 0)`). `Set-InstallButtonEnabled:390` is the only place the button's `IsEnabled` is written. `main.ps1:188` disables it at launch. Defense in depth: `Invoke-BtnInstall` re-runs the checks and refuses regardless of button state (`Confirm.ps1:217-225`). A throwing check degrades to non-blocking Warning rather than reading as a pass (`Check.ps1:274-281`). |
| PREF-03 | PASS | Self-elevation via `Start-Process -Verb RunAs` in `scripts/start.ps1`, with a UAC-decline path. AppUserModelID `AkariOS.Setup`. Independently re-verified by `Test-AdminElevation` at runtime. |
| SAFE-02 | PASS (static) | Typed `AKARIOS` gate in `Confirm.ps1:85-207`, modal `Window` + `ShowDialog()`. Every exit path sets `DialogResult` explicitly — no unbounded wait. Cancel/Escape/close all return `$false`. |
| SAFE-03 | PASS (static) | Per-stage copy as data in `functions/public/Stage.ps1` (`Get-StageExplanation`), seeded into the progress panel at `main.ps1:131-135`. Includes cost/reversibility notes. |
| SAFE-04 | PASS (static) | `Get-CanCancel` in `functions/public/Cancel.ps1:26-56` returns `$true` only for `CurrentStage -eq 1` and not in a transitional (rebooting) state. `Sync-CancelButton` applied at launch (`main.ps1:185`). |
| PROG-01 | PASS (static) | `Update-ProgressDisplay` in `functions/public/Progress.ps1` renders "Step N of 3", sets `ProgressBar1.Value` clamped 0-100, and action/detail text. Uses `$sync.window.Dispatcher.Invoke` for runspace marshalling. |
| PROG-02 | PASS (static) | `Get-ResumePoint` in `functions/public/Resume.ps1` checks the bcdedit safeboot flag and both RunOnce entries through injectable wrappers. Launch integration at `main.ps1:141-182` handles `fresh` / `stageN` / `inconsistent`, the last surfacing no CTA (D-05). Wrapped in try/catch — detection failure never blocks startup. |
| PROG-03 | **PARTIAL** | Confirmed absent: `grep -rn "IsIndeterminate" AkariOS/` returns nothing. No code sets `ProgressBar1.IsIndeterminate = $true`, so the bar shows no activity during long blocking work. Acceptably deferred to Phase 2, where stage integration supplies real progress. |
| DIAG-01 | PASS (static) | `functions/private/Logging.ps1`: ISO8601 timestamps, 5 MB rotation with 3 archives, never throws. Initialised first thing at launch (`main.ps1:119-128`) so post-init failures are captured. |

## Open defect (non-blocking, must fix before Phase 2 UX sign-off)

**D-01 — Pre-flight checks never run automatically; the Install button stays
permanently disabled until the user manually visits the Check tab.**

Evidence: `main.ps1:188` calls `Set-InstallButtonEnabled -Enabled $false` at
launch. The only caller of `Invoke-PreFlightChecks` on the UI path is
`Invoke-BtnRunChecks` (`Check.ps1:407`), which is wired to `BtnRunChecks` in
`xaml/panels/01-Check.xaml:23`. Nothing invokes it at startup.

Consequence: a user who launches the app, sees Home, and clicks "Install
AkariOS" finds the button dead with the hint "Run the pre-flight checks first to
enable this button." — with no indication that a separate Check tab exists. The
gating itself is correct (PREF-02 holds); the discoverability is not.

Fix (small, Phase 1 scope): kick `Invoke-BtnRunChecks` once at launch on a
background runspace — the network probe already runs off-thread — so the gate
resolves itself within a few seconds. Alternatively surface a "Run checks" CTA
directly on the Home panel next to the disabled Install button.

## Deviations accepted

1. **Confirmation gate is a modal `Window`, not the `ConfirmOverlay` grid** in
   `01-UI-SPEC.md`. Justified: driving the in-window overlay required a private
   `DispatcherFrame`/`PushFrame` loop, and `ScriptBlock.GetNewClosure()` captures
   locals **by value**, so a mutated `$confirmed` never propagates out — the gate
   hung with no escape path. `Add_Click` also returns `$null`, so
   `Remove_Click($null)` throws and leaks a handler per invocation. `ShowDialog()`
   uses WPF's own loop; shared state is a hashtable; behaviour and copy are
   unchanged. The dead overlay grid was removed from `MainWindow.xaml`.
2. **`Test-AkariOSConfirmation` is case-SENSITIVE** (`Ordinal`). Rejecting
   `akarios` in lowercase is stricter than a "type this word" gate implies. Set at
   the orchestrator's instruction with no spec ruling behind it. Recommend relaxing
   to `OrdinalIgnoreCase` unless deliberately intended as a friction gate.
3. **All `.ps1` sources carry a UTF-8 BOM.** Required: PowerShell 5.1 decodes
   BOM-less UTF-8 as ANSI and mangles the em dashes and box-drawing glyphs in
   `Stage.ps1`.

## Bugs found and fixed during execution (confirmed absent in the final tree)

- **State field-name mismatch.** `Cancel.ps1` / `Progress.ps1` were written
  against `Stage` / `StagePercent` while the schema is `CurrentStage` /
  `Progress`. Would have broken cancel and progress at runtime. Now consistent:
  `Cancel.ps1:56` reads `[int]$State.CurrentStage`; `Progress.ps1:101` calls
  `Set-AkariOSState -CurrentStage $Stage -Progress $Percent`.
- **Install CTA had no handler.** Task 6.3 would have wired nothing.
  `main.ps1:104-114` now binds every `Btn*` control to its `Invoke-*` function.
- **`$sync.assets` dereferenced unguarded** — now `if ($sync.assets)` at
  `main.ps1:121`.
- **Two PowerShell/WPF hang traps** (closure by value; `Add_Click` returning
  `$null`) — both eliminated by the modal-dialog rewrite.

## Runtime verification still owed (VM only — NOT performed)

Every behavioural claim above is static. On a VM, in order:

1. Launch → window renders; Mica or graceful fallback.
2. UAC prompt appears; declining exits cleanly.
3. **Pre-flight checks auto-run and Install enables** (or reproduce D-01).
4. Click Install → confirmation gate; `AKARIOS` accepted, wrong token rejected,
   Escape/cancel returns safely, and **the gate cannot hang**.
5. Case-sensitivity of the token (confirm deviation 2 behaves as intended).
6. `C:\ProgramData\AkariOS\install.log` written with ISO8601 timestamps.
7. `state.json` created and updated atomically; kill the process mid-write and
   confirm no corruption.
8. Resume banner: fresh install shows "Ready to install"; fabricated stage state
   shows "Resuming Step N of 3"; inconsistent state shows no CTA.
9. Cancel disabled after stage 1 begins.
10. `.\Compile.ps1` reproduces a byte-comparable `akarios.ps1`.