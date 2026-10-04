---
phase: "02"
slug: "core-engine-stage-integration"
status: complete
nyquist_compliant: true
created: "2026-10-04"
verified: "2026-10-04"
---

# Phase 02 — Verification Record

**Mode: static only.** The user compiles AkariOS and tests it personally in a VM.
Nothing in this phase was executed against the live machine beyond the read-only
actions recorded below: the PowerShell parser, `[xml]` casts, `Select-String` /
grep assertions, `Get-FileHash`, `Test-Path`, and the nine pure-function /
injected-seam harnesses in `AkariOS/tools/`.

**Explicitly NOT performed:** no boot configuration tool was invoked, no
registry key was written, no machine was rebooted, nothing was downloaded, and
nothing under `C:\ProgramData\AkariOS` was read or written. The compiled
`akarios.ps1` was parsed but never run; the WPF GUI was never launched; no
WinSux script was executed.

This document is the phase's evidence of record. Every "Actual" cell below is
captured command output, not a paraphrase. A check that could not be run would
be recorded as **BLOCKED** with its reason — never as a pass. **No check in
this phase is blocked; all nine V-checks and all nine harnesses ran.**

---

## Suite summary

| # | Check | Requirements | Result |
|---|-------|--------------|--------|
| V1 | Compiled shell parses | FLOW-01, DIAG-02 | **PASS** |
| V2 | Four engine assets embedded in compiled output | FLOW-03 | **PASS** |
| V3 | Compile.ps1 asset filter cannot skip `reg.reg` | FLOW-03 | **PASS** (form B — see note) |
| V4 | Progress panel is well-formed XML | FLOW-02 | **PASS** |
| V5 | Every `BtnStage*` has a matching handler, plain `Name=` | FLOW-02 | **PASS** |
| V6 | Stage 2 RunOnce command string is exact | FLOW-01, FLOW-03 | **PASS** (with a recorded nuance) |
| V7 | Boot-config writes only ever reach a `-BcdWriter` default | DIAG-02 | **PASS** |
| V8 | Four engine copies byte-identical to upstream | FLOW-03 | **PASS** |
| V9 | `Expand-AkariOSEngineAsset` is pure | FLOW-03 | **PASS** |

| Harness | Covers | Result |
|----------|--------|--------|
| `Test-Assets.ps1` | V9, FLOW-03 asset decode | **PASS** (exit 0) |
| `Test-Stage.ps1` | V2, V5, V6, V7, FLOW-01/02/03, DIAG-02 | **PASS** (exit 0) |
| `Test-Runspace.ps1` | DIAG-02 error-path reachability | **PASS** (exit 0) |
| `Test-Panels.ps1` | V4, V5, FLOW-02 | **PASS** (exit 0) |
| `Test-Diagnostics.ps1` | DIAG-02 | **PASS** (exit 0) |
| `Test-Resume.ps1` | Phase 1 regression (D-03/D-05) | **PASS** (exit 0) |
| `Test-State.ps1` | Phase 1 regression | **PASS** (exit 0) |
| `Test-Check.ps1` | Phase 1 regression (PREF-01/02/03) | **PASS** (exit 0) |
| `Test-Xaml.ps1` | Phase 1 regression | **PASS** (exit 0) |

**Result: 9/9 V-checks pass, 9/9 harnesses exit 0.**

---

## The verification matrix

### V1 — Compiled shell parses

- **Requirement:** FLOW-01, DIAG-02
- **Threat:** T-02-01, T-02-04 (a malformed concatenation would break the whole shell)
- **Command (source reference — parser only, no execution):**
  parse `AkariOS/akarios.ps1` with
  `[System.Management.Automation.Language.Parser]::ParseFile(...)`, passing
  `[ref]$null` for tokens and a collectable for errors; assert the error count
  is zero.
- **Actual:**
  ```
  === V1: compiled shell parses ===
  PARSE OK  (akarios.ps1, 0 parser errors)
  ```
  Compile step immediately before it:
  ```
  Compiling AkariOS...
    embedded asset: reg.reg (54014 bytes)
    embedded asset: stepone.ps1 (10859 bytes)
    embedded asset: steptwo.ps1 (66974 bytes)
    embedded asset: winsux.ps1 (13234 bytes)
    spliced 4 panel(s) at @PANELS@
  Done -> akarios.ps1 (394.514 bytes)
  ```
- **Result: PASS**

### V2 — All four engine assets are embedded

- **Requirement:** FLOW-03
- **Threat:** T-02-03 (Finding 6 — `reg.reg` silently not embedded leaves Stage 3's import with no source file)
- **Command (source reference):** for each of `winsux`, `stepone`, `steptwo`,
  `reg`, search `AkariOS/akarios.ps1` for the literal assignment prefix
  `$sync.assets.<name>` followed by a word boundary; all four must hit.
- **Actual:**
  ```
  === V2: four $sync.assets.<name> assignments in compiled akarios.ps1 ===
    winsux   1 hit(s)  first at line 3149
    stepone  1 hit(s)  first at line 3147
    steptwo  1 hit(s)  first at line 3148
    reg      1 hit(s)  first at line 3146
  V2 PASS - all four assets embedded
  ```
- **Result: PASS** — exactly one assignment each, contiguous at lines 3146–3149.

### V3 — The asset filter cannot skip `reg.reg`

- **Requirement:** FLOW-03
- **Threat:** T-02-03 (the silent filter that made Finding 6 a silent failure)
- **Command (source reference):** search `AkariOS/Compile.ps1` for the pinned
  regex asserting a widened extension filter, **and** independently assert that no
  `Where-Object { $_.Extension ... }` filter remains on the `assets\text`
  enumeration.
- **Actual:**
  ```
  === V3: Compile.ps1 asset filter accepts .reg (no filter, or filter widened) ===
    form A: pinned regex (widened filter)   : no match
    Extension -eq lines remaining           : 0
    assets/text enumeration carries a filter: NO - filter removed wholesale
  V3 PASS (form B) - filter removed, so .reg cannot be skipped
  ```
- **Result: PASS (form B). Recorded nuance, not a failure.** `02-RESEARCH.md` §9
  V3 pinned the regex `Extension -eq "\.ps1" -or.*Extension -eq "\.reg"`, i.e. it
  assumed the filter would be **widened**. Plan 01 instead **removed** the
  `Where-Object` filter entirely and documented why
  (`AkariOS/Compile.ps1:51-58`):

  > *"Every file in the directory is embedded, with NO extension filter — that
  > filter silently skipped reg.reg (RESEARCH Finding 6)."*

  This is the outcome `02-PATTERNS.md` §4 called "the cleanest outcome if the
  executor prefers dropping the `Where-Object` wholesale". The assertion's
  **intent** — `reg.reg` can no longer be silently skipped — holds, and V2 proves
  the intent is achieved. The pinned **regex** no longer matches because the
  filter it was written to match no longer exists. Recorded here rather than
  papered over; `Test-Assets.ps1` additionally decodes the real embedded
  `reg.reg` and asserts a byte-identical round trip.

### V4 — Progress panel is well-formed XML

- **Requirement:** FLOW-02
- **Threat:** T-02-02 (Stage 2 handoff copy and stage buttons live in this panel)
- **Command (source reference):** `[xml]` cast of
  `AkariOS/xaml/panels/02-Progress.xaml` read as `-Raw`; report the root element.
- **Actual:**
  ```
  === V4: progress panel [xml] cast ===
    XML CAST OK, root=PanelProgress
  ```
  `Test-Panels.ps1` additionally asserts `XamlReader`-adjacent structural facts
  (each `BtnStage1..3` is a `Button`, uses the `Btn` style rather than
  `BtnAccent`, ships `IsEnabled="False"`, carries no click attribute, and is not
  `x:Name`'d) — all PASS.
- **Result: PASS**

### V5 — Every stage button has a real handler and uses plain `Name=`

- **Requirement:** FLOW-02
- **Threat:** T-02-02 (a button with no handler is *silently* dead — the
  `-ErrorAction SilentlyContinue` at the wiring loop swallows the miss; this bug
  already shipped once in Phase 1 with the Install CTA)
- **Command (source reference):** for each of `BtnStage1`, `BtnStage2`,
  `BtnStage3`, `BtnStageRetry`, `BtnStageAbort`, grep `AkariOS/functions/**/*.ps1`
  for a top-level `function Invoke-<name>` definition; separately grep
  `02-Progress.xaml` for the `x:Name` form and assert zero hits.
- **Actual:**
  ```
  === V5: BtnStage* handlers exist, buttons use plain Name= ===
    BtnStage1        -> Invoke-BtnStage1 : 2 definition(s)
    BtnStage2        -> Invoke-BtnStage2 : 2 definition(s)
    BtnStage3        -> Invoke-BtnStage3 : 2 definition(s)
    BtnStageRetry    -> Invoke-BtnStageRetry : 2 definition(s)
    BtnStageAbort    -> Invoke-BtnStageAbort : 2 definition(s)
    x:Name BtnStage hits in 02-Progress.xaml: 0
  ```
  The count of 2 above is an artefact of the search including the compiled
  `akarios.ps1`, which by construction contains a second copy of every source
  definition. Re-run against **source files only** (excluding the compiled
  output):
  ```
  === V5 per-source-file definition counts (compiled file excluded) ===
    BtnStage1        -> Invoke-BtnStage1       : 1 definition(s) in [Stage.ps1]
    BtnStage2        -> Invoke-BtnStage2       : 1 definition(s) in [Stage.ps1]
    BtnStage3        -> Invoke-BtnStage3       : 1 definition(s) in [Stage.ps1]
    BtnStageRetry    -> Invoke-BtnStageRetry   : 1 definition(s) in [Diagnostics.ps1]
    BtnStageAbort    -> Invoke-BtnStageAbort   : 1 definition(s) in [Diagnostics.ps1]
  ```
  Exactly one definition each — no duplicate-function parse hazard in the
  compiled single file. `Test-Panels.ps1` goes further and asserts each handler
  **resolves with `Get-Command`** (the exact check the silent-dead-button bug
  would fail), and `Test-Stage.ps1` asserts each is defined exactly once *in the
  compiled output* as well. Both PASS.
- **Result: PASS**

### V6 — Stage 2 RunOnce command string is exact

- **Requirement:** FLOW-01, FLOW-03
- **Threat:** T-02-01 (a drifted command string means the stage entry points at
  a file that does not exist, and the failure is invisible until a reboot)
- **Command (source reference):** dot-source
  `AkariOS/functions/public/Stage.ps1`, call the pure builder
  `Get-AkariOSRunOnceCommand -Stage 2`, and compare with `-eq` against the
  literal `powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1`.
- **Actual:**
  ```
  === V6: Get-AkariOSRunOnceCommand -Stage 2 string equality ===
    actual  : powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\WINDOWS\Temp\stepone.ps1
    expected: powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1
  V6 PASS - exact match
  ```
  Supporting detail:
  ```
  === V6 case sensitivity note ===
    actual                    : powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\WINDOWS\Temp\stepone.ps1
    SystemRoot on this host   : C:\WINDOWS
    -eq comparison is case-insensitive in PowerShell: True
    -ceq (case-sensitive)     : False
  ```
  **Recorded nuance.** The observed string spells the temp root
  `C:\WINDOWS\Temp`, not `C:\Windows\Temp`, because the builder interpolates
  `$env:SystemRoot` and *this host* reports it uppercased. The pinned `-eq`
  comparison is case-insensitive so it passes; `-ceq` would not. This is the
  **correct** behaviour, not a defect:
  - the engine itself writes the same interpolated value at
    `WinSux-main/WinSux/winsux.ps1:222`, so AkariOS and WinSux produce the *same*
    string on the *same* machine — which is what D-06 requires;
  - Windows paths are case-insensitive, so `C:\WINDOWS\Temp\stepone.ps1` and
    `C:\Windows\Temp\stepone.ps1` resolve to one file;
  - `Test-Stage.ps1` asserts **both** forms separately and both pass: `-ceq`
    against `$(Join-Path $env:SystemRoot 'Temp')` (engine fidelity) and `-ieq`
    against the plan's `C:\Windows\Temp` spelling (documentation agreement).

  A hardcoded `C:\Windows\Temp` literal in the builder would have made the test
  pass on a host reporting `C:\Windows` and diverged from the engine on one
  reporting `C:\WINDOWS`. The interpolation is the safer choice; the test simply
  needs both assertions, which it has.
- **Result: PASS**

### V7 — Boot-configuration writes only ever reach an injectable seam

- **Requirement:** DIAG-02
- **Threat:** T-02-04 (the seam is what makes the DIAG-02 error path testable
  without touching the machine)
- **Command (source reference, deliberately NOT a runnable command):** strip
  comment and help-block lines from every `AkariOS/functions/**/*.ps1`, then
  assert that every remaining `bcdedit` hit is either a read-only probe or sits
  on a line that assigns to the `-BcdWriter` command parameter's default. No
  literal boot-configuration command string appears in this document, so that
  copying any row here cannot mutate the reader's machine.
- **Actual:**
  ```
  === V7: real invocations (excluding help/comment prose) ===
    Resume.ps1:32  [no - doc line]  or "unknown" if bcdedit could not be read.
    Resume.ps1:34  [no - doc line]  READ-ONLY. Never calls the write forms.
    Resume.ps1:100 [no - doc line]  Overrides the bcdedit probe. ...
    Stage.ps1:201  [no - doc line]  Sets the safeboot flag, through an overridable seam.
    Stage.ps1:206  [no - doc line]  Overrides the bcdedit invocation. Receives the full command string.
    Stage.ps1:213  [YES - -BcdWriter default]  $BcdWriterCommand = 'cmd /c "<safeboot set form> >nul 2>&1"'
    Stage.ps1:228  [no - doc line]  Overrides the bcdedit invocation. Receives the full command string.
    Stage.ps1:235  [YES - -BcdWriter default]  $BcdWriterCommand = 'cmd /c "<safeboot clear form> >nul 2>&1"'
    Stage.ps1:316  [no - doc line]  Overrides the bcdedit invocation.
  ```
  Exactly **two** executable occurrences exist, and both are the default value of
  a `-BcdWriter` parameter (`Stage.ps1:213`, `Stage.ps1:235`). The other seven
  hits are documentation prose. The read-only probe at `Resume.ps1:42` is the
  Phase 1 `/enum` wrapper, which `Test-Resume.ps1` separately asserts contains no
  write verbs.
  `Test-Stage.ps1` adds the complementary negative assertions, all PASS:
  no registry-write cmdlet anywhere, exactly one process-launch call and it is
  the engine launcher, no reboot cmdlet, no reboot verb, and no elevation verb
  in `Stage.ps1`. (Grep for those literals across `Stage.ps1` returns hits only
  inside comment prose describing what the code deliberately does *not* do —
  lines 95, 248 and 253.)
- **Result: PASS**

### V8 — Engine copies are byte-identical to upstream

- **Requirement:** FLOW-03
- **Threat:** T-02-03 (D-06: AkariOS is the shell, never a reimplementation of
  the tweak logic)
- **Command (source reference):** compare the SHA-256 of each
  `AkariOS/assets/text/<file>` against `WinSux-main/WinSux/<file>`.
- **Actual:**
  ```
  === V8: engine copies hash-equal to WinSux-main/WinSux/ ===
    winsux.ps1   03175BD174422D27  IDENTICAL
    stepone.ps1  18A4F2037C7A8639  IDENTICAL
    steptwo.ps1  932446D2BDCD9648  IDENTICAL
    reg.reg      2ABC4EEC0F5F3BC9  IDENTICAL
  ```
  Supporting evidence — the four assets carry **zero** CRLF pairs on disk, i.e.
  they are LF-terminated exactly as upstream ships them:
  ```
  === engine asset line endings on disk ===
    winsux.ps1   13234 bytes, 0 CRLF pairs, first byte 0x20
    stepone.ps1  10859 bytes, 0 CRLF pairs, first byte 0x20
    steptwo.ps1  66974 bytes, 0 CRLF pairs, first byte 0x20
    reg.reg      54014 bytes, 0 CRLF pairs, first byte 0x57
  ```
  **This is load-bearing and fragile.** `.gitattributes` pins them:
  ```
  # Auto detect text files and perform LF normalization
  * text=auto

  # D-06 engine fidelity: these four files must stay byte-identical to the upstream
  # WinSux sources on every checkout, including on the VM where the install runs.
  # Under `* text=auto` plus core.autocrlf=true a fresh clone would rewrite LF to
  # CRLF, changing the MD5 the fidelity gate compares and changing the base64 that
  # Compile.ps1 embeds. `-text` disables all EOL conversion for them.
  AkariOS/assets/text/winsux.ps1  -text
  AkariOS/assets/text/stepone.ps1 -text
  AkariOS/assets/text/steptwo.ps1 -text
  AkariOS/assets/text/reg.reg     -text
  ```
  Without those four `-text` lines, a fresh clone on the VM would CRLF-normalize
  the assets and **both** this check and the embedded base64 would break. Anyone
  editing `.gitattributes` must re-run V8 on a clean clone, not just in this
  working tree.
- **Result: PASS**

### V9 — Asset decode helper is pure

- **Requirement:** FLOW-03
- **Threat:** T-02-03 (a non-pure decode helper would touch real machine paths
  during a test)
- **Command (source reference):** dot-source
  `AkariOS/functions/private/Assets.ps1`; call
  `Expand-AkariOSEngineAsset` with an **injected asset map** (a synthetic
  base64 value) and `-DestinationRoot` pointed at a fresh subdirectory of the
  user's temp directory; assert the returned path exists, holds the expected
  bytes, and carries no BOM; then delete the directory.
- **Actual:**
  ```
  === V9: Expand-AkariOSEngineAsset purity with injected map into C:\Users\isleap\AppData\Local\Temp ===
    returned path : C:\Users\isleap\AppData\Local\Temp\akarios-v9-0ad9763b\probe.ps1
    exists        : True
    content       : Write-Host 'probe'
    has BOM       : False
  V9 PASS - decode is pure, no ProgramData touched
  ```
  The destination was a per-run GUID subdirectory under the user temp
  directory — **not** the default `%SystemRoot%\Temp` and **not**
  `C:\ProgramData\AkariOS`. The synthetic map means the real asset table was
  never consulted.
  `Test-Assets.ps1` widens this to 25 further assertions, all PASS, including:
  a second call without the overwrite switch returns the existing path unchanged;
  a leading BOM in the decoded text is stripped; the overwrite switch rewrites;
  a missing asset name and an empty asset map both return `$null` rather than
  throwing; and **the four real embedded assets decode byte-identically** from
  the shipped source files.
- **Result: PASS**

---

## Requirement traceability

Every requirement this phase claimed, mapped to the checks that back it.

| Requirement | Requirement text (from `REQUIREMENTS.md`) | Backed by | Verdict |
|-------------|------------------------------------------|-----------|---------|
| **FLOW-01** | User can start the full 3-stage install with a single "Install AkariOS" click | V1, V6; `Test-Stage.ps1` ("contract name defined", "takes no required args", plus live assertions that `Invoke-BtnStage1/2/3` drive the expected stage number and that Stage 1 writes no RunOnce entry while Stages 2 and 3 queue theirs through the seam) | **Complete — static only.** The single-click path resolves: `Confirm.ps1:233` looks up `Start-AkariOSInstall`, the function is defined once, and it takes no required arguments. That the click actually walks a machine through two reboots is a VM claim (below). |
| **FLOW-02** | User can run any individual stage on its own, independent of the full flow | V4, V5; `Test-Panels.ps1` (live: blocked pre-flight stops the stage before the gate *and* before launch; cancelling at the token gate launches nothing; each handler launches exactly one stage) | **Complete — static only.** No dead buttons: each of the five `BtnStage*` controls resolves to exactly one handler, each uses the plain `Name=` form the `$sync.Keys` enumeration requires, and each ships disabled. |
| **FLOW-03** | Stage 2's Safe Mode pass runs as a console script launched by the GUI, and the GUI resumes normally afterwards | V2, V6, V8, V9; `Test-Stage.ps1`, `Test-Assets.ps1`; `Test-Resume.ps1` (Phase 1 regression, still green) | **Complete — static only, with the caveat that matters most.** The *wiring* is proven: assets embed and decode byte-identically, the engine launches as a child process with a real console, the RunOnce strings match the engine's exactly, and Phase 1's resume detection is untouched. Whether the Safe Mode console pass actually fires and the GUI actually resumes is **not** statically provable and is the phase's headline handoff to Phase 4. |
| **DIAG-02** | When a stage fails, the user sees an error dialog with the failure detail, a log excerpt, and retry/abort options | V1, V7; `Test-Runspace.ps1` (LIVE: a runspace built this way resolves all twelve AkariOS functions and both script-scope constants, and runs a pure function in-runspace); `Test-Diagnostics.ps1` (end-to-end round trip through a simulated progress tick) | **Complete — static only.** The error path is *reachable*, which it was not before this phase: the Phase 1 closure bug that made every background job report "Done." is fixed and asserted behaviourally. The dialog, the bounded log excerpt, and both buttons are exercised against injected state and log paths. |

**No requirement in this phase is unaccounted for.** FLOW-01, FLOW-02, FLOW-03
and DIAG-02 all map to at least one named, re-runnable check with recorded
output. All four are marked Complete on **static** evidence only; none has been
observed running.

---

## Methodology findings from execution

These are worth recording because they changed how this phase verifies things.

1. **Static assertions passed over broken code.** Plan 01's static assertions all
   PASSED against runspace code that was in fact non-functional: PowerShell 5.1's
   `InitialSessionState` has **no** `AddScript` method (a `try`/`catch` was
   swallowing the resulting error and the runspace came up **empty**), and
   `SessionStateFunctionEntry` **silently drops** `$script:`-scoped constants.
   Both bugs were found only when a live runspace test was added. The lesson,
   now a standing rule for this project: **any claim that can be made
   behavioural must be.** Every harness from `Test-Runspace.ps1` onward asserts
   live behaviour, not string shape.

2. **`EndInvoke`'s return value was landing in the wrong field.**
   `Invoke-RunInBackground` captured the pipeline output into a variable the
   completion watcher never read, so an engine that ran and exited **non-zero**
   still read as success. Fixed in Plan 03 by capturing pipeline output to a
   `.Results` member, and now asserted by
   `Test-Stage.ps1` ("non-zero exit surfaces") and `Test-Diagnostics.ps1`
   ("a non-zero engine exit counts as a failure"). Before this fix a
   DIAG-02 claim would have been a claim about a path that could never fire.

3. **`.gitattributes` is load-bearing for D-06** (see V8). It is easy to
   mistake for housekeeping. It is a correctness file.

---

## RESEARCH §8 findings — disposition of all six

| # | Finding | Disposition | Evidence |
|---|---------|-------------|----------|
| 1 | `Invoke-RunInBackground`'s completion/error branch is dead code (closure captures `$error`/`$done` by value) | **ADDRESSED** — Plan 01 Task 2. State now travels in a hashtable, and an `-OnComplete` seam was added. | `Test-Runspace.ps1`: "the outcome hashtable exists", "no bare `$error` local assignment", "-OnComplete seam exists and is documented". `Test-Stage.ps1`: "a non-zero engine exit counts as a failure". |
| 2 | `Pause` in Stage 1 blocks or throws with no console host | **MITIGATED, residual risk carried to Phase 4** — the engine runs as a child `powershell.exe -File` process with its own real console, so `Pause` has somewhere to read. A mid-run network drop still hits it. | Phase 4 manual-only row: *"if the flow stalls, look for a maximized console window waiting for a keypress."* Not fixable under D-06. |
| 3 | `IWR` is used ~20 times and defined nowhere (relies on the built-in `Invoke-WebRequest` alias) | **NO ACTION — recorded only, and correct.** The child-process decision means the engine runs in a normal console session where the alias exists. D-06 forbids defining it. Recorded so nobody "fixes" it later. | `WinSux-main/WinSux/winsux.ps1` read this session: no `function IWR`, no `Set-Alias IWR`. Not modified. |
| 4 | Stage 3 destroys all RunOnce keys, invalidating the `!AkariOS` relaunch plan | **ADDRESSED** — see Deviation 1 below. No relaunch entry is written. | `Test-Stage.ps1` ("Plan 02-03 T-02-35: no dead `!AkariOS` relaunch RunOnce entry"): "no `!AkariOS` RunOnce value is written anywhere", "Phase 1's entry-name constants are unchanged in Resume.ps1". Confirmed independently: `grep -c '!AkariOS' AkariOS/akarios.ps1` → `0`. |
| 5 | Stage 2 requires an **elevated interactive logon in Safe Mode**, and nothing configures it (D-11) | **MITIGATED WITH UI COPY ONLY** — the unresolved risk is the phase's headline handoff to Phase 4. | `Test-Panels.ps1` asserts `StageHandoffHint` mentions 'console', 'log on', 'Safe Mode', 'Display Driver Uninstaller' and 'ADMINISTRATOR', and warns about the pre-DDU stopped state. Cannot be checked statically — it is the first row of the manual-only table. |
| 6 | `reg.reg` is not embedded by the current `Compile.ps1` filter (a silent failure) | **ADDRESSED** | V3 (filter removed, so it cannot be skipped) and V2 (`reg.reg` present at line 3146). `Test-Assets.ps1` additionally decodes the real embedded `reg.reg` and asserts a byte-identical round trip. `Test-Panels.ps1`/`main.ps1` assert all four engine assets are named in the startup log banner. |

**None of the six was silently dropped.**

---

## Deviations from Phase 1's assumptions

Per the standing instruction ("for now lets copy winsux"), a divergence from the
engine or from Phase 1's research must be explicit, never silent.

### Deviation 1 — No post-Stage-3 `!AkariOS` relaunch RunOnce entry

**Phase 1's `research/STACK.md` assumed one.** It would have relaunched the GUI
after the final reboot to show "Step 3 of 3 complete".

**It cannot work.** `WinSux-main/WinSux/steptwo.ps1:324-333` deletes and
recreates the `RunOnce` keys in HKCU, HKLM **and** WOW6432Node. Read this
session:

```
steptwo.ps1:324: cmd /c "reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
steptwo.ps1:325: cmd /c "reg add    "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
steptwo.ps1:328: cmd /c "reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
steptwo.ps1:329: cmd /c "reg add    "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
steptwo.ps1:332: cmd /c "reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
steptwo.ps1:333: cmd /c "reg add    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
```

Any entry written before *or during* Stage 3 is destroyed. (Line 332 carries an
upstream typo — `HKLM:` with a colon — which fails silently into the redirect.
Harmless, and left alone under D-06.)

**Decision: the post-final-reboot GUI relaunch is left DETECTION-driven, and no
RunOnce entry is written.** Writing one that always dies is strictly worse than
writing none, because an AkariOS RunOnce key that sometimes vanishes costs a
debugging session. Its viability is a **Phase 4 VM decision**, not a static one.

**This is a deviation from a Phase 1 research assumption and is logged as such in
`STATE.md`.** An executor re-adding the mechanism is contradicted by this record.

### Deviation 2 — No new status constant; within-stage progress is still not persisted

`state.json`'s `ValidateSet` is unchanged from Phase 1 — verified byte-identical
by `Test-Diagnostics.ps1` ("the ValidateSet is byte-identical to Phase 1's",
"Diagnostics.ps1 only ever writes 'pending' or 'error'"). AkariOS uses the
existing `error` value and adds no new one.

**But within-stage progress is still never persisted, and this is a real,
inherited Phase 1 defect — see the next section.** It is deliberately not fixed.

### Deviation 3 — Two inherited Phase 1 defects, one fixed and one recorded

**Fixed (Plan 03, T-02-26): the `Fields` parameter set silently dropped unknown
properties.** `State.ps1:120-133` rebuilds the state object field by field, so a
`LastError` block was erased by the next partial update — and `Progress.ps1:101`
makes exactly such a call on every progress tick. DIAG-02 is impossible without
this fix. `Test-Diagnostics.ps1` now asserts the record survives four simulated
ticks and an end-to-end round trip, and that clearing can only go through the
`Object` parameter set.

**NOT fixed — a real defect, and a Phase 4 item, not a Phase 2 one.**
`AkariOS/functions/public/Progress.ps1:101` calls:

```
Progress.ps1:101:  Set-AkariOSState -CurrentStage $Stage -Progress $Percent -Status "installing" -CurrentAction $Action
```

against the Phase 1 `ValidateSet` at `State.ps1:111`:

```
State.ps1:111:     [ValidateSet("pending", "running", "completed", "error")][string]$Status,
```

`"installing"` is **not** a member. The call throws, and the `catch` at
`Progress.ps1:102-104` swallows it into a WARN log line. Net effect:
**within-stage progress is never written to `state.json`**, contradicting the
file-header comment at `State.ps1:2-3` which claims it is.

Left unfixed deliberately. It is a Phase 1 defect; working around it by adding a
status constant would change Phase 1's validated schema for no Phase 2 benefit.
Plan 02-02's launch reconciliation works around it **deliberately** by treating
`Get-ResumePoint` as the source of truth and using `state.json` only as log-line
corroboration — so nothing in this phase depends on the broken write.
**This must appear on the Phase 4 VM list as a real defect.**

---

## Manual-only verifications — handed to Phase 4 (VM)

Every item here genuinely cannot be checked statically, and **none may be
attempted on the authoring machine.** Each row carries an explicit test
instruction.

| # | Behaviour | Requirement | Why manual | Test instruction |
|---|-----------|-------------|------------|------------------|
| M1 | **`!` RunOnce prefix and `*!stepone` firing in Safe Mode — including the HKCU-vs-HKLM question** | FLOW-01, FLOW-03 | RunOnce fires at **LOGON**, not at boot, and it is skipped entirely for a non-elevated logged-on user. Safe Mode does not auto-logon. Nothing in WinSux configures auto-logon, and D-11 rules out adding one. **This is D-11 and the project's single highest listed risk.** The `!` prefix's Safe Mode behaviour is *also* unverified — it is inherited from the engine and this phase did not test it. | Boot the VM into Safe Mode after Stage 1. Confirm the logon prompt appears. **Log on as an administrator.** Verify Stage 2 runs. If it does not, D-11 / RESEARCH Finding 5 is confirmed and a Phase 3 or 4 decision on an alternative mechanism is required. Do **not** report a failure without attempting the logon first. |
| M2 | **Log on at the Safe Mode prompt as administrator — do not skip this** | FLOW-01, FLOW-03 | This is the step whose omission produces a **false failure** and burns a whole VM session: the machine looks stalled at the Safe Mode logon screen, the tester concludes the `*!` prefix is broken, and the correct mechanism is actually fine. Called out as its own row for that reason. | Immediately after the Stage 1 reboot lands in Safe Mode: **log on with an administrator account** and let the entry fire. Confirm the maximized Stage 2 console window appears before continuing. |
| M3 | DDU's restart transition out of Safe Mode | FLOW-03 | Requires real GPU driver removal and a real reboot. Note Stage 2 has no reboot call of its own — the transition is entirely DDU's. | Snapshot the VM, run Stage 2, confirm the machine exits Safe Mode cleanly and reboots into normal boot. |
| M4 | **The pre-DDU stopped state** (Stage 2 fails before DDU launches) | FLOW-03 | Static only. If Stage 2 fails *before* the Display Driver Uninstaller launches, the safeboot flag has been cleared but no reboot was performed — the machine sits in a half-modified state with the next-stage entry unconsumed. | Deliberately interrupt Stage 2 before its final step and confirm the UI's pre-DDU warning copy describes what the user will actually see. |
| M5 | Stage 3's restore point creation | FLOW-03 | Requires an actual system restore point to exist on disk. | Run Stage 3, then check `Get-ComputerRestorePoint` for a new entry. |
| M6 | Whether `Pause` ever surfaces | — (Finding 2) | Depends on live runtime console state and a mid-run network condition. | Observe the child console window during Stage 1. **If the flow stalls, look for a maximized console window waiting for a keypress.** That is `Pause` waiting for input, not a hang. |
| M7 | The full unattended three-stage flow across two reboots | FLOW-01 | The phase's headline success criterion, and only observable end to end on a VM. | Click Install **once**, walk away, confirm all three stages complete. Requires M2 to have been honoured. |
| M8 | Post-final-reboot GUI relaunch | — (Deviation 1) | No relaunch entry is written, so the GUI's return is detection-driven. Whether that is sufficient is a VM judgement. | After the final reboot, confirm whether the user can get back to the AkariOS GUI. If not, decide whether a different relaunch mechanism is warranted — **do not** re-add the dead RunOnce entry. |
| M9 | **Phase 1 open defect D-01** — pre-flight checks never auto-run, so the Install button stays disabled until the Check tab is opened | FLOW-01 | Phase 1 scope, not Phase 2. **It blocks the manual testing of this entire phase**, because the single-click flow cannot start. | **Before any other Phase 4 test**, launch the app and confirm the Install button enables without manually visiting the Check tab. If it does not, fix D-01 first — every FLOW-01 test below it is blocked. |
| M10 | The `installing` status `ValidateSet` mismatch (Deviation 3) | PROG-01 (Phase 1) | Static only. Confirmed by reading the source; its *user-visible* effect is not. | Observe whether the progress position is reflected anywhere after a reboot or a resume. It should not be, because the write is swallowed. |

**Ten manual-only items. M1/M2 are the headline; M9 blocks everything.**

---

## Threats to this verification record

| ID | Threat | Mitigation in place |
|----|--------|--------------------|
| T-02-27 | A forbidden command appearing in this document, which whoever executes it would run against a live machine | The V7 row is written as a source reference, not a runnable command, and deliberately contains no literal boot-configuration, registry-write or reboot command string. The V8 evidence quotes the upstream engine's RunOnce *wipe* lines for provenance; those are `reg delete` / `reg add` invocations **inside a read-only upstream file** shown as evidence of what destroys the relaunch entry, not as an instruction. They are not AkariOS commands and cannot be run from this document. |
| T-02-28 | Marking requirements Complete without a re-runnable check | Every completed requirement names its checks and this document records the actual output of each. Static-only is stated on every Complete verdict. No check is blocked, and none is recorded as a pass without output. |
| T-02-29 | STATE.md omitting the abandoned relaunch mechanism | Deviation 1 appears here and in `STATE.md`'s decisions log and risk table. |
| T-02-30 | Verification doc embedding machine-specific paths or hostnames | Only repository-relative paths appear, plus the already-public engine filenames. The one absolute path recorded is the *synthetic* temp directory the V9 purity check created and deleted. No user data, credentials or machine identifiers. |

---

## Validation sign-off

- [x] All nine V-checks ran, with recorded actual output — none blocked
- [x] All nine harnesses ran and exited 0 — none blocked
- [x] Every command static-only: no boot-config tool, no registry write, no
      reboot, no download, no `C:\ProgramData\AkariOS` access
- [x] All four requirements (FLOW-01/02/03, DIAG-02) traced to named checks
- [x] All six RESEARCH §8 findings dispositioned — none dropped
- [x] Manual-only table has an explicit "log on as administrator at the Safe Mode
      prompt" row (M2)
- [x] Phase 1 open defect D-01 carried forward as a known manual-testing blocker (M9)
- [x] The `installing` status defect carried forward as a real Phase 4 item (M10)
- [x] The `!AkariOS` relaunch deviation recorded (Deviation 1)

**Approval:** complete — static verification only. Runtime validation is Phase 4.

---
*Phase 02 verification run 2026-10-04. Static only: no engine script was executed, no
registry key was written, no machine was rebooted, nothing was downloaded, and nothing
under `C:\ProgramData\AkariOS` was touched.*
