---
phase: 02-core-engine-stage-integration
plan: 01
subsystem: engine-integration
tags: [powershell, wpf, winsux, base64-assets, runspace, injectable-seams]

# Dependency graph
requires:
  - phase: 01-shell-and-ui-foundation
    provides: WPF shell, state.json persistence, install.log, RunOnce/safeboot resume detection, confirmation gate
provides:
  - Four WinSux engine assets embedded byte-identically as $sync.assets.<name>
  - Expand-AkariOSEngineAsset decoding helper with injectable asset map and destination root
  - Get-AkariOSRunOnceCommand pure string builder matching winsux.ps1:222/:225 verbatim
  - Set-AkariOSRunOnceEntry / Set-BcdSafebootValue / Clear-BcdSafebootValue seam wrappers
  - Invoke-AkariOSEngine child-process launcher behind an injectable seam
  - Invoke-AkariOSStage runner and the Start-AkariOSInstall published contract entry point
  - Repaired Invoke-RunInBackground (hashtable outcome, -OnComplete, dot-sourced runspace)
  - Test-Assets.ps1 / Test-Stage.ps1 / Test-Runspace.ps1 harnesses
affects: [02-02, 02-03, 02-04, phase-04-vm-validation]

actuals:
  tokens: 152000
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - "Injectable-seam wrapper: every state-touching call lives only inside a parameter default scriptblock"
    - "Cross-reboot handoff strings built by a pure function and asserted byte-for-byte against upstream"
    - "Background runspace dot-sources the function files so $script: constants travel with the definitions"

key-files:
  created:
    - AkariOS/assets/text/winsux.ps1
    - AkariOS/assets/text/stepone.ps1
    - AkariOS/assets/text/steptwo.ps1
    - AkariOS/assets/text/reg.reg
    - AkariOS/functions/private/Assets.ps1
    - AkariOS/tools/Test-Assets.ps1
    - AkariOS/tools/Test-Stage.ps1
    - AkariOS/tools/Test-Runspace.ps1
  modified:
    - AkariOS/Compile.ps1
    - AkariOS/functions/private/Invoke-RunInBackground.ps1
    - AkariOS/functions/public/Stage.ps1
    - .gitattributes

key-decisions:
  - "Checkpoint task 1: user ratified all three one-way decisions as written - engine fidelity (D-06), the child-process boundary, and Start-AkariOSInstall as the contract name"
  - "T-02-14: the runspace dot-sources the function files; SessionStateFunctionEntry silently drops $script: constants"
  - "Engine assets pinned as -text in .gitattributes so D-06 byte-identity survives checkout under core.autocrlf=true"

patterns-established:
  - "Seam naming: -RunOnceWriter / -BcdWriter / -EngineInvoker / -AssetInvoker - each receives the full command string or asset name, so a test asserts the exact text without executing it"
  - "Harness shape mirrors Test-Resume.ps1: dot-source, Assert helper, injected values, PASSED line, exit code"

requirements-completed: [FLOW-01, FLOW-03]

coverage:
  - id: D1
    description: "The four engine assets embed into the compiled script and match upstream byte for byte (D-06, FLOW-03)"
    requirement: FLOW-03
    verification:
      - kind: other
        ref: "bash: md5sum comparison of AkariOS/assets/text/* vs WinSux-main/WinSux/* -> HASHES MATCH"
        status: pass
      - kind: other
        ref: "powershell -File AkariOS/Compile.ps1 -> 'embedded asset' count == 4"
        status: pass
      - kind: unit
        ref: "AkariOS/tools/Test-Assets.ps1#decodes byte-identically"
        status: pass
    human_judgment: false
  - id: D2
    description: "One confirmation reaches a real child powershell.exe launch: Invoke-BtnInstall -> Start-AkariOSInstall -> Invoke-AkariOSStage -Stage 1 -> decoded engine -> child process, with Confirm.ps1 unmodified"
    requirement: FLOW-01
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#contract name defined / Invoke-AkariOSStage has -AssetInvoker"
        status: pass
      - kind: other
        ref: "bash: git diff --name-only over Confirm.ps1 Resume.ps1 scripts/start.ps1 is empty"
        status: pass
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#invoker received the path / exit code returned"
        status: pass
    human_judgment: true
    rationale: "The child-process launch itself was never executed - it would start the WinSux engine, which is forbidden on this machine. Only the injected-seam path is proven. A VM run must confirm the console window appears and the engine self-elevates."
  - id: D3
    description: "The RunOnce handoff strings AkariOS builds are byte-identical to winsux.ps1:222/:225"
    requirement: FLOW-03
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#stage 2 string exact / stage 3 string exact"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every bcdedit, registry, process-launch and reboot path is reachable only through an overridable seam"
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Stage.ps1#no bcdedit outside a -BcdWriter default / no registry cmdlets / exactly one Start-Process / no Restart-Computer / no shutdown -r"
        status: pass
    human_judgment: false
  - id: D5
    description: "A failing background job is reported as a failure, not as Done (DIAG-02 prerequisite)"
    requirement: DIAG-02
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Runspace.ps1#outcome hashtable exists / no bare $done or $error locals"
        status: pass
      - kind: integration
        ref: "AkariOS/tools/Test-Runspace.ps1#LIVE block - real runspace resolves functions, honours an injected seam"
        status: pass
    human_judgment: true
    rationale: "The DispatcherTimer tick path that actually flips the status to the red failure branch cannot run here - it needs a WPF dispatcher thread. The static assertions prove the by-value capture is gone; the red branch itself is VM-only."
  - id: D6
    description: "AkariOS's own functions and $script: constants resolve inside a real background runspace"
    requirement: DIAG-02
    verification:
      - kind: integration
        ref: "AkariOS/tools/Test-Runspace.ps1#LIVE - 12 functions resolve, $script:AkariOSStage2Entry == '*!stepone', asset table == reg.reg"
        status: pass
    human_judgment: false

# Metrics
duration: 14min
completed: 2026-10-04
status: complete
---

# Phase 2 Plan 1: Engine Embedding and Stage Launch Summary

**The WinSux engine ships as four byte-identical base64 assets and one confirmation now reaches a real child `powershell.exe -File` launch — every state-touching call behind an overridable seam, and a failing background job is finally reported as a failure.**

## Checkpoint Task 1 — Reversibility Gate (VERDICT RECORDED VERBATIM)

Gate: `blocking-human`. The user's answer, verbatim:

> Ratify all three as written (recommended) — proceed to the tracer slice

That ratifies all three one-way decisions as written:

1. **Engine fidelity (D-06) — ratified.** The three WinSux stage scripts ship as
   byte-identical base64 assets; AkariOS never patches them (not the `IWR` alias usage,
   not the `HKLM:` colon typo at `steptwo.ps1:332`). Undo = re-embed and re-test everything.
2. **Process boundary — ratified: the engine runs behind a child-process boundary.**
   `Invoke-AkariOSEngine` launches a child `powershell.exe -File <decoded>`, never an
   in-process runspace scriptblock. Undo = a second execution path.
3. **`Start-AkariOSInstall` as a published contract name — ratified.** `Confirm.ps1:233`
   already resolves that exact name by convention; renaming it later breaks a contract
   Phase 1 already shipped.

No overturn. No file in this plan's `files_modified` list was written before this
checkpoint resolved (`684dc5d`).

## Performance

- **Duration:** 14 min
- **Started:** 2026-10-04T10:06:49Z
- **Completed:** 2026-10-04T10:20:10Z
- **Tasks:** 3 (plus the checkpoint)
- **Files modified:** 14 (4 new engine assets, 4 new source/test files, 4 modified, 1 deleted, 1 gitattributes)

## Accomplishments

- `assets/text/` holds the four engine files with MD5s matching `WinSux-main/WinSux/`
  exactly, and they are committed byte-identical to the working tree (verified as blob ==
  working tree == upstream for all four).
- `Compile.ps1` embeds every file in `assets/text/` with no extension filter, so
  `reg.reg` is no longer silently skipped (RESEARCH Finding 6).
- `Expand-AkariOSEngineAsset` decodes an injected asset map into an injected
  destination root, strips a BOM, writes UTF-8 without one, returns the path, and
  returns `$null` instead of throwing on a missing key.
- `Start-AkariOSInstall` exists, so `Confirm.ps1:233` takes its first branch — FLOW-01
  landed without editing a single Phase 1 contract file.
- The Stage 1 handoff strings are byte-identical to `winsux.ps1:222` / `:225`.
- `Invoke-RunInBackground` no longer reports every background job as "Done." — the
  by-value closure capture is replaced with a hashtable, and a failing job now takes
  the red failure branch.
- A real runspace built the way the runner builds one resolves all AkariOS functions
  **and** their `$script:` constants, and honours an injected seam.

## Task Commits

1. **Checkpoint: one-way architecture decisions** — `684dc5d` (docs)
2. **Tracer: end-to-end Install click, assets to child process** — `8304b09` (feat)
3. **Engine asset fidelity survives checkout** — `d7c34ad` (fix)
4. **Task 2: repair the runspace supervisor** — `aef33c6` (fix)
5. **Task 3: compile and prove the tracer slice** — `619c1bb` (test)

## Files Created/Modified

- `AkariOS/assets/text/{winsux,stepone,steptwo}.ps1`, `reg.reg` — byte-identical WinSux engine (D-06)
- `AkariOS/assets/text/.gitkeep` — **deleted** (empty BaseName would emit `$sync.assets. = '...'`)
- `AkariOS/functions/private/Assets.ps1` — `Get-AkariOSAssetFileName` + `Expand-AkariOSEngineAsset`
- `AkariOS/functions/public/Stage.ps1` — appended `Get-AkariOSRunOnceCommand`, `Set-AkariOSRunOnceEntry`, `Set-BcdSafebootValue`, `Clear-BcdSafebootValue`, `Invoke-AkariOSEngine`, `Invoke-AkariOSStage`, `Start-AkariOSInstall` (the stage-explanation block above is unchanged)
- `AkariOS/functions/private/Invoke-RunInBackground.ps1` — hashtable outcome, `-OnComplete`, dot-sourced runspace
- `AkariOS/Compile.ps1` — extension filter removed, real file name reported, plain byte count
- `.gitattributes` — the four engine assets pinned `-text`
- `AkariOS/tools/Test-{Assets,Stage,Runspace}.ps1` — static + live harnesses

## Decisions Made

- **The runspace dot-sources the function files.** `SessionStateFunctionEntry` looks
  like the right API and is not: it carries the function definitions across but
  silently drops every `$script:` constant, so `$script:AkariOSStage2Entry` was empty
  in the worker and the RunOnce entry names went missing with no error. Dot-sourcing
  brings both. Commented in the source so nobody "simplifies" it back.
- **Asset key → file name is a table, not a concatenation.** `$sync.assets` keys are
  `$_.BaseName` (no extension) but the RunOnce values name `stepone.ps1` and
  `steptwo.ps1` imports `reg.reg`, so a bare `Join-Path $Root $Name` would write a file
  no entry points at. `Get-AkariOSAssetFileName` maps the four keys explicitly.
- **No RunOnce entry after Stage 3 starts**, as the plan requires —
  `steptwo.ps1:324-333` wipes the keys itself, so a relaunch entry written afterwards is
  dead. Recorded for `02-04.md`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] `InitialSessionState` has no `AddScript`; the plan's mechanism produces an empty runspace**
- **Found during:** Task 2 (T-02-14)
- **Issue:** The plan specified "`AddScript` the contents of every `functions/**/*.ps1`
  file and pass it to `CreateRunspace($iss)`". `System.Management.Automation.Runspaces.InitialSessionState`
  on PowerShell 5.1 exposes only `ImportPSModule`, `ImportPSSnapIn`, and the
  `Commands`/`Variables`/`Types` collections — there is no `AddScript` method. Written
  as planned, the surrounding `try/catch` swallowed the `MethodNotFoundException`,
  every file was skipped, and the runspace came up empty: the worker could not call
  `Invoke-AkariOSEngine` or anything else of ours. The static assertions the plan
  specified would all have passed on this broken code.
- **Fix:** Probed the real API surface, then dot-sourced the files into the runspace
  via a prelude added with `$ps.AddScript(...)` before the job's scriptblock. Verified
  live: 12 AkariOS functions resolve, `Get-AkariOSRunOnceCommand` returns the correct
  string inside the runspace, and an injected `-BcdWriter` seam is honoured there.
- **Files modified:** `AkariOS/functions/private/Invoke-RunInBackground.ps1`,
  `AkariOS/tools/Test-Runspace.ps1`
- **Verification:** `Test-Runspace.ps1` LIVE block —
  `ALL RUNSPACE TESTS PASSED`, exit 0
- **Committed in:** `aef33c6`

**2. [Rule 2 - Missing Critical] `SessionStateFunctionEntry` drops `$script:` constants**
- **Found during:** Task 2, while proving the fix for deviation 1
- **Issue:** The first working-looking approach — parse each file and add every
  `FunctionDefinitionAst` as a `SessionStateFunctionEntry` — resolved all 51 functions
  in a real runspace but left `$script:AkariOSStage2Entry` **empty** and
  `$script:AkariOSStages` **undefined**, because the entries carry only function
  definitions. `Set-AkariOSRunOnceEntry` would have taken its "no entry for this stage"
  branch in the worker and silently written nothing.
- **Fix:** Dot-sourcing instead of AST entries; added explicit LIVE assertions for
  `$script:AkariOSStage2Entry -eq "*!stepone"` and the asset table.
- **Files modified:** `AkariOS/functions/private/Invoke-RunInBackground.ps1`,
  `AkariOS/tools/Test-Runspace.ps1`
- **Verification:** `Test-Runspace.ps1` — `script-scope entry name survives`,
  `script-scope asset table survives`, both PASS
- **Committed in:** `aef33c6`

**3. [Rule 1 - Bug] CRLF normalisation would have broken D-06 on a fresh checkout**
- **Found during:** Task 1 (commit hygiene)
- **Issue:** `.gitattributes` had `* text=auto` and the repo sets `core.autocrlf=true`.
  Git warned `LF will be replaced by CRLF` on all four engine files at commit time. On
  the VM, a fresh checkout would have rewritten them, changing both the MD5 the
  fidelity gate compares and the base64 `Compile.ps1` embeds. `WinSux-main/` is
  gitignored, so there is nothing in-repo to re-derive the originals from.
- **Fix:** Pinned the four engine assets `-text` in `.gitattributes` and
  `git add --renormalize`d them (no content change staged).
- **Files modified:** `.gitattributes`
- **Verification:** committed blob MD5 == working-tree MD5 == upstream MD5 for all
  four files
- **Committed in:** `d7c34ad`

**4. [Rule 1 - Bug] Asset file names lost their extension, pointing RunOnce at nothing**
- **Found during:** Task 1 (T-02-02)
- **Issue:** `Expand-AkariOSEngineAsset` wrote `Join-Path $Root $Name`, so asset key
  `stepone` produced `C:\WINDOWS\Temp\stepone` — while the RunOnce value AkariOS builds
  names `C:\WINDOWS\Temp\stepone.ps1`. The stage-2 handoff would have pointed at a
  file that does not exist. Caught by `Test-Assets.ps1` on first run.
- **Fix:** Added `Get-AkariOSAssetFileName`, an explicit key → file-name table
  (`reg` → `reg.reg`, the rest → `*.ps1`), with pass-through for unknown dotted keys.
- **Files modified:** `AkariOS/functions/private/Assets.ps1`, `AkariOS/tools/Test-Assets.ps1`
- **Verification:** `Test-Assets.ps1` — `reg.reg writes to its bare name` and the three
  `*.ps1` equivalents, all PASS
- **Committed in:** `8304b09`

**5. [Rule 3 - Blocking] `$env:SystemRoot` is `C:\WINDOWS` uppercase on this host**
- **Found during:** Task 1 (T-02-05)
- **Issue:** The plan pins the expected string as
  `powershell.exe ... -f C:\Windows\Temp\stepone.ps1`, but the engine interpolates
  `$env:SystemRoot` itself, so on this machine WinSux writes `C:\WINDOWS\Temp\...`.
  Comparing case-sensitively against the plan's spelling failed — the builder was
  right and the literal was wrong for this host.
- **Fix:** The harness derives the expected value the same way the engine does and
  asserts case-SENSITIVE equality against it, plus a case-INSENSITIVE check against
  the plan's `C:\Windows\...` spelling so a case change in our builder is still caught.
  The production code was not changed — matching the engine exactly is the requirement.
- **Files modified:** `AkariOS/tools/Test-Stage.ps1`
- **Verification:** `stage 2 string exact`, `stage 3 string exact`,
  `stage 2/3 matches the plan spelling`, all PASS
- **Committed in:** `8304b09`

**6. [Rule 1 - Bug] Compile.ps1 misreported asset sizes**
- **Found during:** Task 1
- **Issue:** `{1:N0}` renders with this host's locale separator, so the compile printed
  `reg.reg (54.014 bytes)` for a 54,014-byte file — reading as 54 bytes. The plan
  already required fixing the neighbouring `{0}.ps1` name interpolation in the same
  expression.
- **Fix:** Plain `{1}` byte count.
- **Files modified:** `AkariOS/Compile.ps1`
- **Verification:** compile now prints `reg.reg (54014 bytes)`
- **Committed in:** `8304b09`

**7. [Rule 1 - Bug] Harness param-block regex truncated at `[Parameter(Mandatory)]`**
- **Found during:** Task 2 (T-02-15)
- **Issue:** `param\s*\((.*?)\)` is non-greedy and stopped at the closing paren inside
  `[Parameter(Mandatory)]`, so two legitimate assertions failed on a correct file.
- **Fix:** Balanced-paren regex `param\s*\(((?:[^()]|\([^()]*\))*)\)` plus an explicit
  "param block extracted" assertion so the regex can never silently degrade again.
- **Files modified:** `AkariOS/tools/Test-Runspace.ps1`
- **Verification:** `Test-Runspace.ps1` exit 0
- **Committed in:** `aef33c6`

---

**Total deviations:** 7 auto-fixed (4 correctness bugs, 2 blocking issues, 1 host-portability issue)
**Impact on plan:** Two deviations (1, 2) were latent showstoppers in the plan's own
specified mechanism — the prescribed `AddScript` call does not exist on PowerShell 5.1
and would have shipped an empty runspace that reported every job as "Done." The static
test the plan specified would have passed on it. Both are now covered by live assertions.
No scope was added; every fix stays inside the plan's seam and harness design.

## Issues Encountered

- **`* text=auto` + `core.autocrlf=true`** — the D-06 fidelity guarantee depended on a
  Git setting that would have rewritten the engine on the VM's checkout. Fixed by
  `.gitattributes`; worth remembering for any other vendored-byte-identical asset.
- **`GetNewClosure()` is by value** — `Invoke-AkariOSEngine` passes `$enginePath` through
  the job's `.GetNewClosure()`, so the value is captured at closure creation. That is
  correct here (the path does not change mid-stage) but is the same by-value mechanism
  that caused the `$done`/`$error` bug; noted so a future edit does not reintroduce a
  by-value assumption where a reference is needed.

## User Setup Required

None.

## Verification Performed (all static; nothing executed on this machine)

Every command below was actually run; outputs are as reported.

| Check | Result |
|---|---|
| `Test-Assets.ps1` | `ALL ASSET TESTS PASSED`, exit 0 |
| `Test-Stage.ps1` | `ALL STAGE TESTS PASSED`, exit 0 |
| `Test-Runspace.ps1` | `ALL RUNSPACE TESTS PASSED`, exit 0 (incl. 17 live assertions) |
| MD5 of 4 assets vs upstream | `HASHES MATCH` |
| `grep -c Where-Object Compile.ps1` | `0` → `NO EXTENSION FILTER` |
| 4 files in `assets/text`, 4 embedded | `EXACTLY FOUR ASSET FILES, FOUR EMBEDDED` |
| `Compile.ps1` embedded count | `4` |
| 4 `$sync.assets.<name>` in `akarios.ps1` | `ALL FOUR ASSETS COMPILED IN` |
| `Parser::ParseFile akarios.ps1` | `PARSE OK` |
| `Parser::ParseFile Invoke-RunInBackground.ps1` | `PARSE OK` |
| `grep -c '^function Start-AkariOSInstall'` | `1` → `CONTRACT NAME EXACTLY ONCE` |
| `git diff` over Confirm/Resume/start | empty → `NO PHASE 1 CONTRACT FILE TOUCHED` |
| committed blob == working tree == upstream MD5 | all 4 MATCH |

**Nothing on this machine was rebooted, no registry key written, no `bcdedit` invoked,
no process launched, no network request made.** Every state-touching call in the new
code sits behind a seam whose default was overridden in the harnesses that ran.

## Manual / VM-Only Verification the User Must Run

These cannot be proven here and are the real Phase 4 targets:

1. **The child engine window actually appears and self-elevates.** The launch path is
   proven only through an injected `-EngineInvoker`. On the VM, click Install and confirm
   a `powershell.exe` console window opens, the engine's own UAC prompt appears (not
   two), and `Pause` in `winsux.ps1` has a console host to read from.
2. **The red "Failed - see log" status branch.** The DispatcherTimer tick that flips it
   needs a WPF dispatcher thread. Confirm a failing stage shows red, not "Done.".
3. **`*!stepone` fires in Safe Mode (D-11).** The project's highest listed risk. Log on
   as an **administrator** at the Safe Mode prompt — RunOnce fires at logon, not boot,
   and nothing configures auto-logon. The `Set-Status` hint is in place but is text only.
4. **End-to-end reboot sequence.** Stage 1 → Safe Mode boot → Stage 2 console → normal
   boot → Stage 3 → reboot to complete.
5. **Payload downloads.** Stage 1's own `IWR` calls are upstream behaviour under D-06;
   their viability is a VM/Phase 3 matter (SAFE-01).

## Next Phase Readiness

- `02-02` can add per-stage run buttons: `Invoke-AkariOSStage -Stage <n>` already takes
  every dependency as an injectable parameter and `Get-AkariOSStage` is unchanged.
- `02-03` inherits a supervisor that actually reports failure, which is DIAG-02's
  prerequisite. `-OnComplete` is the hook to build retry/abort on.
- `02-04` must record: **no post-Stage-3 `!AkariOS` relaunch entry is written**, because
  `steptwo.ps1:324-333` wipes the RunOnce keys itself and an entry written afterwards is
  dead. This deviates from the Phase 1 research assumption.
- Blockers: none. The one Phase 1 defect the plan told us not to fix remains —
  `Progress.ps1:101` passes `-Status "installing"`, which is not in the
  `State.ps1:111` `ValidateSet`, so within-stage progress is never persisted. The runner
  does not read live progress out of `state.json` (it uses `Write-AkariOSLog` as the
  truthful record), so nothing here depends on it. Out of Phase 2 scope.

---
*Phase: 02-core-engine-stage-integration*
*Plan: 01*
*Completed: 2026-10-04*