---
phase: 02-core-engine-stage-integration
plan: 02
type: execute
wave: 2
status: complete
requirements:
  - FLOW-02
  - FLOW-03
---

# Plan 02-02 Summary — Per-Stage Buttons + Safe Mode Handoff

## What shipped

Three individually runnable stage buttons behind the same pre-flight checks and
typed-token confirmation gate the main Install CTA uses, the Stage 2 Safe Mode
handoff copy, and a launch-time stage-status reconciliation.

| Task | Commit | Contents |
|------|--------|----------|
| 1 | `d96f750` | BtnStage1/2/3 in 02-Progress.xaml (plain `Name=`, IsEnabled="False", no `Click=`), `Invoke-BtnStage1/2/3` in Stage.ps1, `Test-Panels.ps1` |
| 2 | `ca834bd` | StageHandoffHint copy: console-only rendering, administrator log-on requirement, DDU's role in leaving Safe Mode, D-12 rationale comment |
| 3 | `0445cfc` | main.ps1 step 6 launch-time reconciliation + missing-asset banner line; 12 new Test-Stage assertions |

## Key files

- `AkariOS/xaml/panels/02-Progress.xaml` — BtnStage1, BtnStage2, BtnStage3, StageHandoffHint
- `AkariOS/functions/public/Stage.ps1` — Invoke-BtnStage1/2/3, Invoke-AkariOSSingleStage, Show-StageHandoffHint
- `AkariOS/scripts/main.ps1` — step 6 reconciliation, missing-asset banner
- `AkariOS/tools/Test-Panels.ps1` — ~70 assertions, live handler invocation with injected seams

## Deviations from the plan (3, all additive)

1. **`Invoke-AkariOSSingleStage`** added as a shared handler body, plus
   `Invoke-AkariOSStage -OnComplete`. Reason: three near-identical handler bodies
   would drift, and the button must re-enable on real completion rather than on
   the click. Default behaviour unchanged; purely additive.

2. **`Show-StageHandoffHint -PendingNote` / `-ProbePending`** with an injected
   `RunOnceInvoker`. The plan required "the dynamic still-pending check" but named
   no mechanism for it. This is the only registry read in the new code and it is
   read-only, behind the seam.

3. **`Test-Panels.ps1` exceeds the plan's "static checks only".** It dot-sources
   Stage.ps1 and actually invokes the three handlers with injected seams, asserting
   that a blocked pre-flight or a cancelled gate launches nothing and that stages
   2/3 write their RunOnce entry through the seam. Adopted from the 02-01 lesson
   that static assertions passed over two real PowerShell 5.1 bugs.

## Notable finding (carried forward, NOT fixed here)

`Progress.ps1:101` writes `-Status "installing"`, which is **not** in the
`ValidateSet` at `State.ps1:111`. That call throws into its own catch, so
**within-stage progress is never persisted to state.json**. Fixing it is out of
Phase 2's scope. Consequence: the launch-time reconciliation in step 6
deliberately uses `Get-ResumePoint` (bcdedit + RunOnce) as its source of truth per
D-01 and treats `state.json` as corroboration only — reading state.json would show
a stage the machine is not actually in. Flagged for Phase 4 VM validation: this
looks like a real Phase 1 defect, not just a cosmetic one.

## Verification actually run

| Check | Result |
|-------|--------|
| `Test-Panels.ps1` | `ALL PANEL TESTS PASSED` (~70 assertions) |
| `Test-Stage.ps1` | `ALL STAGE TESTS PASSED` |
| `Test-Assets.ps1` | `ALL ASSET TESTS PASSED` |
| `Test-Runspace.ps1` | `ALL RUNSPACE TESTS PASSED` |
| `Test-Resume.ps1` (P1 regression) | exit 0 |
| `Test-State.ps1` (P1 regression) | exit 0 |
| `Test-Check.ps1` (P1 regression) | exit 0 |
| `Test-Xaml.ps1` (P1 regression) | exit 0 |
| `Compile.ps1` | 4 assets embedded (reg.reg, stepone, steptwo, winsux), 4 panels spliced |
| Compiled `akarios.ps1` parse | `PARSE OK` |
| Panel XML | `XML OK` |
| Three plain-named stage buttons | `THREE PLAIN-NAMED STAGE BUTTONS` |
| Safe Mode hint text | `SAFE MODE HINT TEXT PRESENT` |
| Resume switch intact | `RESUME SWITCH INTACT` |
| No error case in resume switch | `NO ERROR CASE ADDED TO RESUME SWITCH` |
| Missing-asset banner | `MISSING-ASSET BANNER LINE PRESENT` |
| Phase 1 files untouched | `NO PHASE 1 FILE TOUCHED` |
| No auto-logon anywhere in AkariOS code | grep for autologon/AutoAdminLogon returns nothing |

Nothing state-touching was executed on the development machine: no reboot, no
registry write, no bcdedit, no process launch, no network call. Every such call
sits behind a seam whose default the harnesses override.

## Requires VM verification — cannot be checked statically

1. Each stage button actually launches its stage in the real GUI, gated by pre-flight and the typed-token confirmation.
2. The Stage 2 handoff copy renders correctly and the buttons enable/disable across a real reboot sequence.
3. The engine console window opens with exactly one UAC prompt and `Pause` has a host.
4. A failing stage reports "Failed — see log", not "Done" (needs the WPF dispatcher tick).
5. `*!stepone` fires in Safe Mode — log on as **administrator** (D-11, the highest listed risk in the phase).
