---
phase: 02-core-engine-stage-integration
plan: 03
subsystem: diagnostics
tags: [powershell, wpf, state-machine, diagnostics, error-reporting]

requires:
  - phase: 02-core-engine-stage-integration
    provides: "Plan 01's Invoke-RunInBackground -OnComplete outcome hashtable (the closure fix), Invoke-AkariOSStage supervisor call, engine assets, Invoke-AkariOSRunOnceCommand and the three state-touching seams"
  - phase: 02-core-engine-stage-integration
    provides: "Plan 02-02's per-stage buttons, Show-StageHandoffHint, main.ps1 step 6 reconciliation, Test-Panels.ps1"
  - phase: 01-*
    provides: "State.ps1 (Set-AkariOSState with its Fields/Object parameter sets, Test-AkariOSState), Logging.ps1 (Get-AkariOSLogPath, Write-AkariOSLog, Get-AkariOSLogTail), Resume.ps1 (Get-ResumePoint, the two RunOnce entry-name constants)"

provides:
  - "Diagnostics.ps1: Get-AkariOSStageFailure, Set-AkariOSStageFailure, Clear-AkariOSStageFailure, Reveal-StageError, Show-StageError, Resolve-StageFailure, Invoke-BtnStageRetry, Invoke-BtnStageAbort"
  - "A LastError block in state.json that survives every partial Fields update (the Phase 1 defect that made DIAG-02 impossible)"
  - "StageErrorDetail card on the progress panel with the failure detail and a bounded log excerpt, plus BtnStageRetry / BtnStageAbort"
  - "Run-time failure recording via Invoke-AkariOSStage's -OnComplete, including non-zero engine exit codes"
  - "An independent launch-time detection step in main.ps1 that touches neither the resume switch nor Get-ResumePoint"
  - "Test-Diagnostics.ps1, a behavioural harness (76 assertions) that runs entirely under $env:TEMP"

affects: [03-post-reboot-verification, 04-hardening, diagnostics, state-schema]

actuals:
  tokens: 360000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Independent detection: a failure check that does NOT add a ResumePoint value and does not consult Get-ResumePoint"
    - "Lossless write path: state changes go through the Object parameter set, because the Fields set rebuilds the object field by field"
    - "Outcome-in-a-hashtable for every background callback (GetNewClosure captures by value)"
    - "Behavioural harnesses over static assertions, with the regression proven by running against the un-fixed writer"

key-files:
  created:
    - "AkariOS/functions/public/Diagnostics.ps1"
    - "AkariOS/tools/Test-Diagnostics.ps1"
  modified:
    - "AkariOS/functions/private/State.ps1 (LastError carry-through in the Fields branch)"
    - "AkariOS/functions/private/Invoke-RunInBackground.ps1 (EndInvoke output captured into $outcome.Results)"
    - "AkariOS/functions/public/Stage.ps1 (failure recording in the -OnComplete callback)"
    - "AkariOS/scripts/main.ps1 (new numbered step 7: launch-time failure detection)"
    - "AkariOS/xaml/panels/02-Progress.xaml (StageErrorDetail card + BtnStageRetry / BtnStageAbort)"
    - "AkariOS/tools/Test-Stage.ps1 (compiled-artefact and launch-step assertions, T-02-35)"

key-decisions:
  - "Carry LastError across the Fields write with ONE guarded assignment, not a copy-all-properties loop. A loop would silently start persisting whatever a future caller invents, and the plan's threat model treats that as its own risk."
  - "Detection is an independent check against state.json, not a new ResumePoint value. Phase 1's Get-ResumePoint decision table and main.ps1's resume switch are byte-identical after this plan."
  - "Reuse the existing 'error' ValidateSet member; no new status constant was invented."
  - "The log excerpt is bounded by Get-AkariOSLogTail -Count and rendered as plain TextBlock.Text, never Html/Rtf, so log content cannot inject markup."
  - "Escape, the X button and window-close all resolve the error dialog to 'abort', so it cannot hang the app."
  - "Retry re-runs the WHOLE stage. Under D-06 the engine is verbatim and exposes no partial-state introspection, so there is nothing finer-grained to resume."
  - "Abort clears ONLY the LastError block and touches neither RunOnce nor the boot flag. Clearing goes through Get-AkariOSState + PSObject.Properties.Remove + Set-AkariOSState -State, because the Fields set now re-carries the block and so can never clear it."
  - "No !AkariOS relaunch RunOnce entry is written anywhere (T-02-35 deviation): steptwo.ps1 wipes and recreates the RunOnce keys, so such an entry could never fire."

patterns-established:
  - "Reveal-StageError owns the error card AND both its buttons together, so a visible Retry can never be a disabled one, and the reveal/hide paths cannot drift."
  - "Every diagnostics function takes -StatePath / -LogPath / -LogCount and defaults through the house constants ($script:AkariOSStateDefaultPath, Get-AkariOSLogPath), so no test ever touches C:\\ProgramData."
  - "Prove a regression test can fail: the harness was run against the un-fixed Phase 1 State.ps1 (git stash) and failed 7 assertions, then passed all with the fix restored."

requirements-completed: [DIAG-02]

coverage:
  - id: D1
    description: "A LastError block written to state.json survives a subsequent partial Fields update (the Phase 1 defect that made DIAG-02 impossible)"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Diagnostics.ps1#T-02-26 the record survives a Fields partial update"
        status: pass
      - kind: other
        ref: "git stash of State.ps1 -> 7 assertions FAIL; fix restored -> all 76 PASS"
        status: pass
    human_judgment: false
  - id: D2
    description: "Get-AkariOSStageFailure returns $null for a healthy state and a populated Stage/Detail/ExitCode/RecordedAt object for a failed one, from an injectable state path"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Diagnostics.ps1#a fresh state file is healthy / Set-AkariOSStageFailure records a readable block"
        status: pass
    human_judgment: false
  - id: D3
    description: "The bounded log excerpt: Get-AkariOSLogTail -Count returns at most Count lines from an injected log path, and a missing log yields an empty excerpt rather than a throw"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Diagnostics.ps1#The log excerpt is bounded by -LogCount and read from -LogPath"
        status: pass
    human_judgment: false
  - id: D4
    description: "StageErrorDetail / StageErrorTitle / StageErrorMessage / StageErrorLog / BtnStageRetry / BtnStageAbort exist in the progress panel with plain Name=, no Click=, IsEnabled=False by default, and resolve in the real spliced XAML"
    verification:
      - kind: other
        ref: "[xml] cast + [Windows.Markup.XamlReader]::Parse on the spliced MainWindow -> 43 named controls, all six found, both buttons IsEnabled=False, card Collapsed"
        status: pass
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#compiled XAML declares/no x:Name/no Click= for each control"
        status: pass
    human_judgment: false
  - id: D5
    description: "Show-StageError is a real modal built on the Show-ConfirmationGate shape with the outcome in a hashtable, an explicit Close, and every exit path resolving to 'abort'; it returns the user's choice as 'retry' or 'abort'"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Diagnostics.ps1#Show-StageError returns the injected choice (retry and abort both travel back out)"
        status: pass
    human_judgment: true
    rationale: "The harness drives the choice through -DialogInvoker and asserts the contract, the modal shape and the closure capture. Whether the rendered dialog is readable, correctly sized and non-truncating with a real 20-line excerpt is a visual judgement no static assertion can make."
  - id: D6
    description: "Retry re-runs the whole stage through Invoke-AkariOSStage; Abort clears only the error block via the Object set and touches neither RunOnce nor the boot flag"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Diagnostics.ps1#Resolve-StageFailure: retry re-runs the stage / abort clears the record and touches nothing else"
        status: pass
      - kind: other
        ref: "Plan Task 2 verify: comment-stripped Diagnostics.ps1 contains neither 'bcdedit' nor 'Deletevalue {current} safeboot' -> ABORT TOUCHES NO BOOT STATE"
        status: pass
    human_judgment: false
  - id: D7
    description: "A failing stage records a LastError block at run time through Set-AkariOSStageFailure, including on a non-zero engine exit code; a clean finish clears a stale record"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#the callback records the failure / a non-zero engine exit counts as a failure / a clean finish clears a stale record"
        status: pass
    human_judgment: true
    rationale: "The recording branch is asserted statically and the state round-trip is proven behaviourally, but no stage has actually been run: this plan executes nothing on the host machine. Only a real VM session can confirm that a genuinely failing engine produces the expected block."
  - id: D8
    description: "The next launch shows the error card with detail and a bounded log excerpt, with Retry and Abort enabled, via an independent step that never consults Get-ResumePoint and is wrapped in try/catch"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#Plan 02-03: the failure is recorded at run time and surfaced at launch"
        status: pass
      - kind: unit
        ref: "AkariOS/tools/Test-Diagnostics.ps1#T-02-34 end-to-end round trip through a simulated progress tick"
        status: pass
    human_judgment: true
    rationale: "Step 7's control flow and its independence from the resume switch are asserted, but the window has never been opened: launching the GUI is forbidden on this host. The user must confirm on the VM that the card renders with the detail and excerpt and that both buttons respond."
  - id: D9
    description: "The compiled akarios.ps1 carries all four engine assets, every diagnostics function exactly once, all five Invoke-BtnStage* handlers, the error card in the XAML here-string, and parses with zero errors"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#compiled akarios.ps1 parses with zero errors + the four assets and the function set"
        status: pass
      - kind: other
        ref: "Compile.ps1 -> 4 'embedded asset' lines; Parser::ParseFile(akarios.ps1) -> PARSE OK"
        status: pass
    human_judgment: false
  - id: D10
    description: "T-02-35 deviation recorded: no !AkariOS relaunch RunOnce entry is written anywhere, and Stage.ps1 still interpolates Phase 1's entry-name constants rather than inlining them"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#Plan 02-03 T-02-35: no dead !AkariOS relaunch RunOnce entry"
        status: pass
      - kind: other
        ref: "Plan Task 3 verify grep across AkariOS/functions and AkariOS/scripts -> NO DEAD RELAUNCH RUNONCE ENTRY"
        status: pass
    human_judgment: false

duration: 47min
completed: 2026-10-04
status: complete
---

# Phase 2 Plan 03: Post-stage failure detection and reporting (DIAG-02)

**A recorded stage failure now survives the progress tick that used to erase it, and the next launch shows the detail, a bounded log excerpt, and a working Retry and Abort.**

## Performance

- **Duration:** ~47 min
- **Completed:** 2026-10-04T10:57:32Z
- **Tasks:** 3
- **Files changed:** 11 (+1438 / -16)
- **Commits:** 3

## Accomplishments

- **Fixed the Phase 1 state-writer defect that made DIAG-02 impossible.** `Set-AkariOSState`'s `Fields` branch rebuilt the state object field by field and dropped any property it did not know about, while `Progress.ps1:101` issues a partial update on every progress tick — so a recorded failure evaporated the instant the UI refreshed. One guarded assignment now carries `LastError` across, mirroring the `RebootPending` line above it.
- **Proved the regression test can fail.** With the fix stashed, `Test-Diagnostics.ps1` fails 7 assertions; with it restored, all 76 pass. Given that both prior plans shipped string assertions that passed against genuinely broken code, this was the load-bearing check of the plan.
- **Delivered the DIAG-02 user surface**: a `CardDanger` error card on the progress panel with the failure detail and the last N log lines, plus `BtnStageRetry` and `BtnStageAbort`, both defaulting to disabled.
- **Built the dialog on the `Show-ConfirmationGate` shape** — real `ShowDialog()`, outcome in a hashtable, explicit `Close()`, and Escape / X / window-close all falling through to `abort`. A plain local would have been captured by value and the dialog would always have answered `abort`: the same trap Plan 01 fixed in the runspace.
- **Closed the loop at run time and at launch.** `Invoke-AkariOSStage`'s `-OnComplete` records a `LastError` on a thrown job *or* a non-zero engine exit; `main.ps1` step 7 surfaces it as an independent check that never touches the resume switch.
- **Recorded the T-02-35 deviation explicitly**: no `!AkariOS` relaunch RunOnce entry is written anywhere, because `steptwo.ps1` wipes and recreates the RunOnce keys and such an entry could never fire.

## Task Commits

Each task was committed atomically:

1. **Task 1: Make the error record survive — the Fields-set drop fix** — `7a0b718` (feat)
2. **Task 2: The error dialog — detail, bounded log excerpt, Retry and Abort** — `7fe75a0` (feat)
3. **Task 3: Record the failure at run time, surface it at next launch, prove it compiles** — `da3eed2` (feat)

## Files Created/Modified

- `AkariOS/functions/public/Diagnostics.ps1` — **new.** `Get-AkariOSStageFailure` (independent detection; returns `$null` unless a `LastError` block exists or `Status` is `error`), `Set-AkariOSStageFailure` (idempotent — replaces, never nests), `Clear-AkariOSStageFailure` (the only mechanism that can actually clear the block), `Reveal-StageError` (fills and reveals/hides the card *and* both buttons together), `Show-StageError` (modal, returns `retry`/`abort`), `Resolve-StageFailure`, `Invoke-BtnStageRetry`, `Invoke-BtnStageAbort`.
- `AkariOS/functions/private/State.ps1` — one guarded assignment carrying `LastError` across the `Fields` partial write. `Test-AkariOSState` untouched.
- `AkariOS/functions/private/Invoke-RunInBackground.ps1` — `EndInvoke`'s return value is now captured into `$outcome.Results` instead of being discarded.
- `AkariOS/functions/public/Stage.ps1` — the `-OnComplete` callback records a failure on a thrown job or a non-zero engine exit code, and clears a stale record on a clean finish.
- `AkariOS/scripts/main.ps1` — new numbered step 7: launch-time failure detection, house three-step recipe, try/catch so it can never block `ShowDialog()`.
- `AkariOS/xaml/panels/02-Progress.xaml` — the `StageErrorDetail` card and its six controls.
- `AkariOS/tools/Test-Diagnostics.ps1` — **new.** 76 behavioural assertions, all against a scratch directory under `$env:TEMP`.
- `AkariOS/tools/Test-Stage.ps1` — compiled-artefact assertions (diagnostics functions, five `Invoke-BtnStage*` handlers, the card in the XAML here-string), launch-step assertions, and the T-02-35 deviation.

**Preserved byte-identical:** `Test-AkariOSState`, `Get-ResumePoint`, the `switch` at `main.ps1:151-178`, the `ValidateSet` status values. `Progress.ps1` and `Resume.ps1` were not touched at all.

## Decisions Made

All eight are recorded in the `key-decisions` frontmatter. The two worth surfacing:

- **One guarded assignment, not a copy-all-properties loop.** Copying arbitrary properties forward would silently start persisting anything a future caller invents — the plan's threat model treats that as its own risk, so `LastError` is named explicitly and everything else keeps its current behaviour.
- **`Reveal-StageError` owns the card and both buttons together.** The plan only asked for a visibility change; enabling the buttons in the same place means a visible Retry can never be a disabled one, and the reveal and hide paths cannot drift apart.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] The outcome hashtable could not carry the engine's exit code**
- **Found during:** Task 3 (record the failure at run time)
- **Issue:** The plan's T-02-32 says to treat "a non-zero exit code from the child engine process" as a failure, but `Invoke-RunInBackground` assigned `EndInvoke`'s return value straight to `$outcome.Error` and kept only the throw. `$Outcome.Results` did not exist. So the *only* detectable failure would have been a job that threw — and the overwhelmingly common case, an engine that ran and exited non-zero, would still have read as success. The whole DIAG-02 path would have been near-inert.
- **Fix:** `EndInvoke`'s pipeline output is now captured into `$outcome.Results`; `.Error` means only "the job threw". `Invoke-AkariOSStage` reads the exit code from `$Outcome.Results`.
- **Files modified:** `AkariOS/functions/private/Invoke-RunInBackground.ps1`, `AkariOS/functions/public/Stage.ps1`
- **Verification:** `Test-Stage.ps1` asserts both halves (`a non-zero engine exit counts as a failure`, `the engine exit code is read from the outcome`); `Test-Runspace.ps1` still green.
- **Committed in:** `da3eed2`

**2. [Rule 1 - Bug] `Clear-AkariOSStageFailure` was not in the plan's function list but was necessary**
- **Found during:** Task 1
- **Issue:** The plan specifies clearing via an inline sequence inside `Resolve-StageFailure`, and separately notes that `Set-AkariOSState -Fields` can never clear the block. Inlining that sequence would have duplicated a load-bearing, non-obvious mechanism across two call sites.
- **Fix:** Extracted it as `Clear-AkariOSStageFailure`, which both `Resolve-StageFailure` and `Invoke-BtnStageAbort` call. Same mechanism, single owner, directly testable.
- **Files modified:** `AkariOS/functions/public/Diagnostics.ps1`
- **Verification:** `Test-Diagnostics.ps1` asserts the clear works, that the `-Fields` shortcut genuinely cannot (proving why the `Object` set is needed), and that no `LastError` key remains in the file.
- **Committed in:** `7a0b718`

**3. [Rule 1 - Bug] `Reveal-StageError` was not in the plan's function list but the buttons would otherwise never enable**
- **Found during:** Task 2, caught by the harness
- **Issue:** The plan has `main.ps1` "reveal `StageErrorDetail` and enable `BtnStageRetry` / `BtnStageAbort`" — two separate things. Nothing owned the enabling, and the buttons default to `IsEnabled="False"` in XAML. A card that appears with two dead buttons is exactly the "silently dead button" failure mode the phase has already been bitten by twice.
- **Fix:** `Reveal-StageError` sets the card's visibility *and* both buttons' `IsEnabled` together, in both directions. `main.ps1` step 7 goes through it.
- **Files modified:** `AkariOS/functions/public/Diagnostics.ps1`, `AkariOS/scripts/main.ps1`
- **Verification:** `Test-Stage.ps1` asserts the launch path reveals via `Show-StageError`; the spliced-XAML probe confirms both buttons ship `IsEnabled=False` until a failure exists.
- **Committed in:** `da3eed2`

**4. [Rule 1 - Bug] Four harness assertions were wrong and were corrected**
- **Found during:** Tasks 1 and 3
- **Issue:** (a) A `Status = "error"` fixture omitted `UpdatedAt`, which every real state file carries, so `Set-AkariOSState` threw. (b) An assertion passed the *failure report* to `Test-AkariOSState` instead of a state object. (c) Two source-scan assertions matched text inside docstrings that legitimately *name* `bcdedit`/`safeboot`/`Get-ResumePoint` while explaining that they are never called — fixed by comment-stripping first, the same shape the plan's own verify steps use. (d) An assertion checked for a literal `*!stepone` in `Stage.ps1`, which correctly appears nowhere because the file interpolates `$script:AkariOSStage2Entry`.
- **Fix:** Corrected the fixtures and switched the three source scans to comment-stripped text. (d) became a stronger assertion: `Stage.ps1` never inlines a RunOnce entry name at all, and Phase 1's constants in `Resume.ps1` are unchanged.
- **Files modified:** `AkariOS/tools/Test-Diagnostics.ps1`, `AkariOS/tools/Test-Stage.ps1`
- **Verification:** Both harnesses green.
- **Committed in:** `7a0b718`, `da3eed2`

---

**Total deviations:** 4 auto-fixed (2 missing-critical/bug, 2 bug)
**Impact on plan:** Deviation 1 was necessary for the plan's central requirement to function at all. Deviations 2 and 3 each turned a mechanism the plan described inline into a single named owner. Deviation 4 corrected the harness, not the code. No scope creep; nothing outside the plan's stated surface was touched.

## Verification — nine harnesses, all green

Run before the work and again after every task:

| Harness | Exit | Result |
|---|---|---|
| `Test-Assets.ps1` | 0 | ALL ASSET TESTS PASSED |
| `Test-Stage.ps1` | 0 | ALL STAGE TESTS PASSED |
| `Test-Runspace.ps1` | 0 | ALL RUNSPACE TESTS PASSED |
| `Test-Panels.ps1` | 0 | ALL PANEL TESTS PASSED |
| `Test-Resume.ps1` | 0 | ALL RESUME TESTS PASSED |
| `Test-State.ps1` | 0 | ALL STATE TESTS PASSED |
| `Test-Check.ps1` | 0 | ALL CHECK TESTS PASSED |
| `Test-Xaml.ps1` | 0 | ALL XAML CHECKS PASSED |
| `Test-Diagnostics.ps1` *(new)* | 0 | ALL DIAGNOSTICS TESTS PASSED (76 assertions) |

Compile: `embedded asset` count **4** (reg.reg, stepone.ps1, steptwo.ps1, winsux.ps1), 4 panels spliced, `Parser::ParseFile(akarios.ps1)` → **PARSE OK**.

Plan verify gates, all passing verbatim: `LASTERROR CARRIED THROUGH FIELDS SET`, `DIAGNOSTICS SEAMS INJECTABLE`, `NO HARD PROGRAMDATA WRITE PATH`, `XML OK`, `ERROR CONTROLS PLAIN-NAMED`, `ALL SIX DIAGNOSTIC FUNCTIONS DEFINED ONCE`, `MODAL DIALOG WITH BOUNDED LOG EXCERPT`, `ABORT TOUCHES NO BOOT STATE`, `FAILURE RECORDED AT RUN TIME`, `FAILURE SURFACED AT LAUNCH`, `NO DEAD RELAUNCH RUNONCE ENTRY`, `PARSE OK`.

Beyond the plan, a spliced-XAML probe parsed the real assembled window through `[Windows.Markup.XamlReader]::Parse`: 43 named controls, all six new ones found, both buttons `IsEnabled=False`, card `Collapsed`.

**Nothing executed on this machine.** No bcdedit, no registry write, no reboot, no installer, no GUI launch, no compiled `akarios.ps1` run, and nothing touched `C:\ProgramData\AkariOS` — every diagnostics test points `-StatePath` and `-LogPath` at a scratch directory under `$env:TEMP`.

## Issues Encountered

- **`git stash` round-trip appeared to leave the fix un-restored** — a `diff` against a pre-stash copy reported a difference. Cause was line-ending normalisation (`LF` → `CRLF`), not lost content; the fix was intact and `Test-Diagnostics.ps1` confirmed it. Verified by grep and by a green harness run rather than by the diff.
- **One command hit an approval prompt** (a `powershell.exe -NoProfile -Command` invocation flagged as encoded-command execution). It was auto-approved and completed; nothing was denied, and no work was abandoned.

## User Setup Required

None — no external service configuration required.

## Requires VM verification (cannot be done here)

Nothing in this plan ran against a real install. The user should verify on the VM:

1. **A failing stage produces the card.** Break a stage deliberately (e.g. make an asset unreadable, or run a stage with no network). Relaunch AkariOS and confirm the Progress page shows `STAGE N FAILED`, the detail text, a log excerpt, and that **Retry this stage** and **Abort and clear the error** are both enabled.
2. **The record survives the run.** With a failure recorded, keep the app open across several progress refreshes and confirm the card does not disappear.
3. **Retry re-runs the whole stage** and the status bar says so. Confirm the user understands that a half-applied stage is re-run from the start — this is deliberate under D-06, not an oversight.
4. **Abort changes nothing else.** After Abort, check `HKCU\...\RunOnce` still holds `*!stepone` / `!steptwo` as it did before, and that `bcdedit /enum {current}` still shows the same `safeboot` value. Abort must not have touched either.
5. **Escape closes the dialog** and the app stays responsive.
6. **No relaunch after Stage 3.** After the final reboot, AkariOS should *not* try to reopen. That is expected — `steptwo.ps1` destroys the RunOnce keys, so no `!AkariOS` entry is ever written.

## Next Phase Readiness

- **DIAG-02 is complete** and its state schema (`LastError` as a block of `Stage`/`Detail`/`ExitCode`/`RecordedAt`) is now load-bearing. Per the plan's reversibility rating, changing that shape after Phase 3 builds on it needs a migration.
- **Deliberately still open, out of Phase 2 scope:** the `Progress.ps1:101` `-Status "installing"` ValidateSet defect (within-stage progress is still never persisted). DIAG-02 does not depend on it — detection reads state.json via the lossless `Object` set — but progress percentages will remain wrong until it is fixed.
- **Carried into 02-04 as a documented deviation:** the `!AkariOS` relaunch assumption, with the reasoning above.
- Not planned here and still open: log export (DIAG-03) and the "what changed" summary (DIAG-04), both Phase 3.

---
*Phase: 02-core-engine-stage-integration*
*Completed: 2026-10-04*
