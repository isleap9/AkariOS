---
phase: 03-hardening-branding-diagnostics
plan: 01
subsystem: relaunch-and-diagnostics
tags: [powershell, schtasks, diag-04, mutation-testing, log-evidence, wpf]

requires:
  - phase: 02-core-engine-stage-integration
    provides: Invoke-AkariOSStage with its five injectable seams, Get-AkariOSStageFailure's independent-check pattern, the LastError block, the $stateDone predicate at Resume.ps1:122

provides:
  - AkariOS/functions/public/Summary.ps1 — the completion gate, the DIAG-04 change catalog, the bounded log-evidence state machine, the reveal function, and the two button handlers
  - AkariOS/xaml/panels/04-Summary.xaml + NavSummary + registration in all three of $panels/$navMap/$navNames
  - AkariOS/tools/Test-Summary.ps1 — 250+ behavioural assertions, all re-runnable
  - Test-AkariOSInstallCompletedOn in Resume.ps1 — the ONE implementation of the completion rule (D-16), called by both Get-ResumePoint and the new check
  - main.ps1 step 8 — completion screen shown, THEN the relaunch task deleted
  - A mutation gate with 5 RED/GREEN pairs recorded

affects: [03-02-safe-restore-point, 03-03-log-export, 03-04-branding, 04-vm-testing]

actuals:
  tasks: 2
  commits: 2

key-decisions:
  - "The completion predicate is EXTRACTED into Test-AkariOSInstallCompletedOn (Resume.ps1), not restated in Summary.ps1. Two copies of a rule that must not disagree is worse than one copy"
  - "The extraction is PROVEN behaviour-preserving: the harness runs the extracted helper and the original inline expression against the same six state shapes and asserts they agree"
  - "Only TWO of nineteen catalog items claim log evidence, and both are stage-scoped. AkariOS supervises one child per stage and the engine writes nothing back to install.log, so 'stage N completed' is the only thing the log can prove - inventing a per-item signal would be a lie"
  - "Show-AkariOSChangeSummary does NOT touch panel visibility. Show-Panel owns it; the reveal also hard-fails on [System.Windows.Visibility] before PresentationFramework is loaded, which the harness caught"
  - "Test-Summary.ps1 asserts on the COMPILED artefact, not the sources: Name= present / x:Name= absent, [xml] cast, //*[@Name] reachability, ten symbols defined once, zero parser errors"

patterns-established:
  - "Strip comments AND XML comments before asserting on source. Three compiled-UI comments literally contain the string 'Click=' while forbidding it, and a step-8 slicing assertion initially matched its own prose"
  - "A mutation gate restores BYTES, not text. A Set-Content -Encoding UTF8 restore added a BOM and double-encoded the box-drawing comment rules, so 'restored' was not restored"
  - "Disabling a call in place does not test a POSITIONAL assertion. Mutation (d2) actually relocates the call, because IndexOf still finds text that has not moved"

requirements-completed: [DIAG-04]

coverage:
  - id: S1
    description: "Completion detection shares ONE implementation with Resume.ps1:122, proven behaviour-preserving"
    requirement: DIAG-04
    verification:
      - kind: unit
        ref: "AkariOS/tools/Test-Summary.ps1 section T-03-07 (D-16)"
        status: pass
    human_judgment: false
  - id: S2
    description: "No item is reported applied without log evidence; empty log applies nothing"
    requirement: DIAG-04
    verification:
      - kind: unit
        ref: "Test-Summary.ps1 T-03-09 (D-21); mutation (b) RED"
        status: pass
    human_judgment: false
  - id: S3
    description: "The log read is bounded; a 5000-line log reflects only the -LogCount tail"
    requirement: DIAG-04
    verification:
      - kind: unit
        ref: "Test-Summary.ps1 'BOUNDED READ' block"
        status: pass
    human_judgment: false
  - id: S4
    description: "The panel and all ten symbols reach the compiled artefact and parse"
    requirement: DIAG-04
    verification:
      - kind: other
        ref: "Test-Summary.ps1 T-03-14; `Compile.ps1` -> 5 panels spliced, 712,753 bytes, PARSE OK"
        status: pass
    human_judgment: false
  - id: S5
    description: "Both harnesses were mutation-tested and every mutation turned one RED"
    requirement: DIAG-04
    verification:
      - kind: other
        ref: "Five RED/GREEN pairs in the table below"
        status: pass
    human_judgment: false
  - id: S6
    description: "Confirm.ps1 and start.ps1 untouched; the four engine assets match upstream by MD5; WinSux-main clean"
    requirement: DIAG-04
    verification:
      - kind: other
        ref: "git diff empty for both files; 4/4 MD5 match; git status --porcelain -- WinSux-main = 0 lines"
        status: pass
    human_judgment: false
  - id: S7
    description: "The GUI actually relaunches after Stage 3 and the window is VISIBLE, not on session 0's phantom desktop"
    requirement: DIAG-04
    verification: []
    human_judgment: true
    rationale: "Not statically provable by construction, and this is the single most likely way for this plan to appear to work while failing. A /RU SYSTEM task runs in session 0, which has no visible desktop - the completion window would exist on a screen the user cannot see. VM-only, Phase 4."

# Metrics
duration: 95min
status: complete
---

# Phase 3 Plan 1: Completion check, DIAG-04 summary, panel and compiled artefact

**The relaunch now has something to relaunch *into*. 16/16 harnesses green, five mutations proven
RED then GREEN, and one real defect found by the harness rather than by reading the code.**

## Checkpoint verdict (Task 1, ratified by the human — recorded verbatim)

All four relaunch decisions stand as ratified, and the plan proceeded on exactly that basis:

1. **Task Scheduler over RunOnce over a Startup shortcut (D-13).** A RunOnce entry is the natural
   fit for the project's other hand-offs and is exactly wrong here: `steptwo.ps1:324-333` deletes
   and recreates `RunOnce` under HKCU, HKLM and WOW6432Node, so any entry written before Stage 3
   starts is unconditionally destroyed. A Startup shortcut survives but re-runs elevation and the
   pre-flight checklist at every logon. Task Scheduler is untouched by the wipe.
2. **Interactive-user context, not `/RU SYSTEM` (D-14).** A SYSTEM task runs in session 0, which
   has **no visible desktop**. `/IT` + `/RL HIGHEST` against the interactive user, falling back to
   `/RU SYSTEM` **with a logged WARN** rather than aborting, so the degradation is never silent.
3. **The relaunch target is a staged copy under `%ProgramData%\AkariOS\` (D-15)** — the user may
   have run `akarios.ps1` from Downloads and deleted it since.
4. **`Start-AkariOSInstall` remains the single entry point**; task creation hangs off Stage 3 inside
   `Invoke-AkariOSStage`, never off the button handler — so no cancelled-after-gate machine is left
   with a live task.

**Wave ordering confirmed:** Wave 1 precedes Waves 2–4, and BRND-01 branding runs from *this*
relaunched session, not before Stage 3, because the engine writes its own black wallpaper at
`steptwo.ps1:763-780` and branding applied earlier would be silently overwritten (D-25).

No overturn. `Relaunch.ps1` was not deleted.

## Accomplishments

- **One implementation of the completion rule exists in the codebase.** The predicate was extracted
  into `Test-AkariOSInstallCompletedOn` in `Resume.ps1` and is called by both `Get-ResumePoint` and
  the new `Test-AkariOSInstallCompleted`. This is the ONE sanctioned edit to a Phase 2 contract file,
  and it is *measured* behaviour-preserving rather than assumed to be: the harness runs the
  extracted helper and the original inline expression against the same six state shapes and asserts
  they agree.
- **The summary cannot claim anything it cannot prove.** Nineteen catalog items, of which exactly
  **two** carry log evidence — because AkariOS supervises one child per stage and the engine writes
  nothing back to `install.log`, so "stage N ran to completion" is the only thing the log can
  corroborate. Inventing a per-item signal would have been a lie; the third state
  (`not-confirmed`, rendered `[ ]`) is what makes the screen trustworthy.
- **The read is provably bounded.** A 5000-line log whose evidence sits outside a `-LogCount` tail
  applies *nothing*, while the same log with a wider tail applies two. That pair is the only
  assertion that can catch an unbounded read — it looks correct in every other test.
- **The panel is proven in the shipped artefact**, not in the source: `Name=` present, `x:Name=`
  absent, `[xml]` cast succeeds, every name reachable by `main.ps1`'s `//*[@Name]` loop, ten
  symbols defined exactly once, zero parser errors.
- **A real defect was found by the harness, not by inspection.**

## The defect the harness found

`Show-AkariOSChangeSummary` ended its reveal action with
`$syncRef["PanelSummary"].Visibility = [System.Windows.Visibility]::Visible`. That line hard-fails
with *"Unable to find type [System.Windows.Visibility]"* whenever `PresentationFramework` is not
yet loaded — and it was **redundant**: `Show-Panel` already owns panel visibility and `main.ps1`
calls it. A function that only fills a panel should not decide whether the panel is shown, and
certainly should not acquire a WPF-type dependency to do it. Removed; the harness now asserts the
positive form (the reveal leaves visibility alone). This is the third instance in this project of
code that passes review and dies at load time.

## Verification results (actual)

| Check | Result | Key output |
|-------|--------|------------|
| Full suite (16 harnesses) | **PASS 16 / FAIL 0** | incl. `Test-Relaunch`, `Test-Summary` |
| Compile | pass | 5 panels spliced, `akarios.ps1` 712,753 bytes |
| Compiled parse | **PARSE OK** | 0 parser errors |
| Summary panel in compiled XAML | **PASS** | 10/10 names `Name=` ×1, `x:Name=` ×0 |
| All new symbols | **PASS** | 10/10 defined exactly once |
| Engine MD5 | **4/4 MATCH** | `winsux` `eb37352…`, `stepone` `38c27c6…`, `steptwo` `428f4d8…`, `reg.reg` `382736c2…` |
| `WinSux-main/` untouched | **PASS** | `git status --porcelain` → 0 lines |
| `Confirm.ps1` / `start.ps1` | **PASS** | `git diff --name-only` → 0 lines |
| `!AkariOS` RunOnce | **PASS** | 0 non-comment hits across `functions/` + `scripts/` |
| Predicate implementations | **PASS** | exactly 1 file (`Resume.ps1`) |

## Mutation gate (T-03-15) — every pair recorded

Runner restores **bytes**, not text. The first attempt used `Set-Content -Encoding UTF8` for the
restore, which added a BOM and double-encoded the box-drawing characters in the comment rules — so
"restored" was not restored and the post-run diff was dirty. The Python runner holds the original
bytes in memory; `git status` after the final run is clean, which is the proof.

| Mutation | Harness | RED (exit / PASSED line) | GREEN (exit / PASSED line) | First assertion to fail |
|---|---|---|---|---|
| **(a)** `Remove-AkariOSRelaunchTask` throws on a missing task | Test-Relaunch | **1** / absent | **0** / present | idempotency: absent task must not throw |
| **(b)** `Get-AkariOSChangeSummary` marks unevidenced items `applied` | Test-Summary | **1** / absent | **0** / present | `an empty log applies nothing` |
| **(c)** `Test-AkariOSInstallCompleted` counts stage 2 as complete | Test-Summary | **1** / absent | **0** / present | `completed at stage 2 is NOT completed` |
| **(d)** Stage 3 never stages the script or creates the task | Test-Relaunch | **1** / absent | **0** / present | `the branch is Get-Command guarded` |
| **(d2)** `Set-AkariOSRelaunchTask` **relocated after the supervisor** | Test-Relaunch | **1** / absent | **0** / present | `it is called inside the Stage 3 branch` + 2 more |

**All five turned RED with a non-zero exit and an absent PASSED line, and all five returned GREEN
after restore. No mutation failed to go red.**

`(d2)` is an addition to the plan's list, and it is the one that matters most. The plan's `(d)` was
implemented by disabling the branch in place — and that **would have been a vacuous test**, because
`Test-Relaunch`'s ordering assertion is positional (`IndexOf`), so text left sitting where it was
would still satisfy it. `(d2)` therefore genuinely *moves* the call to just before the engine
supervisor. It fails three assertions, including `both happen BEFORE the engine child is launched`.
Had `(d)` been the only ordering check, the harness would have passed a mutation it claims to catch.

## Task commits

1. **Task 3 — completion check + DIAG-04 summary:** `a8c1009`
2. **Task 4 — panel, nav registration, launch step, compiled artefact:** `b95fe82`

## Files created / modified

- `AkariOS/functions/public/Summary.ps1` — **new.** `Test-AkariOSInstallCompleted`,
  `Test-AkariOSLogEvidence`, `Get-AkariOSChangeSummary`, `Format-AkariOSChangeGroup`,
  `Show-AkariOSChangeSummary`, `Invoke-AkariOSShellOpenDefault`, `Invoke-BtnOpenRestorePoint`,
  `Invoke-BtnOpenLog`, `$script:AkariOSChangeCatalog`, `$script:AkariOSSummaryLogCount`,
  `$script:AkariOSSummaryStageErrorPattern`
- `AkariOS/functions/public/Resume.ps1` — **the one sanctioned edit.** Added
  `Test-AkariOSInstallCompletedOn`; `$stateDone` now calls it. Decision table unchanged.
- `AkariOS/scripts/main.ps1` — step 8 added; `PanelSummary`/`NavSummary` in all three lists
- `AkariOS/xaml/panels/04-Summary.xaml` — **new**
- `AkariOS/xaml/MainWindow.xaml` — `NavSummary` sidebar row
- `AkariOS/tools/Test-Summary.ps1` — **new**

## Constraints honoured

- **WinSux-main/ untouched** (`git status` clean) and **all four engine assets byte-identical** by MD5.
- **Nothing destructive executed.** No `schtasks`, no registry read or write in `Summary.ps1`
  (asserted), no `Restart-Computer`, no `shutdown -r`, no engine script run, no
  `SystemPropertiesProtection.exe`, no `explorer.exe`. `C:\ProgramData` never touched — state and
  log live in a `$env:TEMP` scratch dir and every call passes `-StatePath`/`-LogPath`/`-ShellInvoker`.
- **Every outside-world call sits behind a seam with a real default:** `-StatePath`, `-LogPath`,
  `-LogCount`, `-ShellInvoker`.
- **Null-invoker fallback present on both button handlers** (T-02-32) — and proven by *replacing the
  real launcher with a recorder and asserting it was REACHED*, not by grepping for the pattern, which
  would pass even if the fallback were unreachable.
- **No by-value closure outcome.** No dialog outcome is returned from a handler here; where an
  outcome crosses a closure the by-reference hashtable pattern is used.
- **`Get-ResumePoint`'s decision table and `main.ps1`'s resume switch are byte-unchanged.** No new
  case, no new `ResumePoint` value (D-22). Asserted in the harness.
- **Compile.ps1 globs verified, not assumed** — `functions\public\*.ps1` and `xaml\panels\*.xaml`
  are both asserted, because a narrowing of those globs has silently broken the compiled build before.

## Deviations from plan

1. **The plan anticipated "restated vs extracted"; the extracted helper was chosen**, as the plan
   preferred. `Resume.ps1` changed by exactly one added function plus one changed line.
2. **Only two catalog items carry log evidence, not all of them.** The plan asked for `Evidence` on
   every item and separately allowed `RequiresLogEvidence = $false`. Giving all 19 items a stage-
   completion string would have made every item "applied" the moment stage 3 logged one line — which
   is precisely the "summary that says applied for something that is not" failure the plan names as
   worse than no summary. Two evidenced, seventeen honestly unverified.
3. **Mutation (d) was supplemented with (d2).** (d) alone is vacuous against a positional assertion;
   this is the finding the task exists to produce.
4. **`Show-AkariOSChangeSummary` does not set panel visibility** (deviation from the plan's literal
   wording, in the direction of correctness — see the defect above).

## Cannot be verified here — VM-only, Phase 4

These are the properties this plan exists to produce, and **none of them was observed**:

1. **That the GUI actually relaunches after Stage 3's reboot.**
2. **That the relaunched window is VISIBLE rather than on session 0's phantom desktop (D-14).** The
   single most likely way for this plan to appear to work and still fail: if the task shows as
   running and completed but no window appeared, the context is wrong.
3. **That the summary reflects a real install's log contents on a real machine.** The harness proves
   the state machine; it cannot prove an engine wrote what the catalog predicts.
4. That the task self-deletes, and that the second logon does *not* relaunch.
5. That both buttons work — System Protection opens, the log opens in Explorer.

Static green here means the mechanism is wired correctly and honestly. It does not mean the machine
comes back.

## Issues encountered

- Three of my own harness assertions failed for reasons that were **my tooling, not the codebase**,
  and each is worth recording because a less careful run would have logged a false result:
  - `$args` as a local in `Invoke-BtnOpenLog` — an automatic variable. Renamed to `$selectArg`
    *in the production code*, because it was a real bug there, not in the test.
  - Step-number headers are comments, so matching them against comment-stripped source was an
    always-fail. Matched against raw source instead.
  - The `Click=` assertion matched three XML comments that literally contain the string `Click=`
    while explaining that no `Click=` attribute may be used. Now XML comments are stripped first,
    with a companion assertion proving the strip is what made it pass.
  - The step-8 slicing assertion matched its own comment prose ("a throw between here and
    `ShowDialog()`"). Slicing on the real `$sync.window.ShowDialog()` call instead. Same class of
    bug as the previous one, and the reason the brief's warning about comment-stripping is a
    standing instruction rather than a one-time precaution.
- The mutation gate's own first implementation was wrong in a way that would have produced a **false
  GREEN**: its `ErrorActionPreference = Stop` turned a mutated harness's stderr into a terminating
  error and killed the gate before it could record the RED. The mutation had actually worked.

## Next phase readiness

**Ready:** SAFE-01 (Plan 03-02) has a screen to appear on and a `RestorePoint` state block with a
reader already in place, tested against its absence. Plan 03-03 (log export) can reuse
`Test-AkariOSLogEvidence`'s bounded read.

**Cautions:**
1. **Nothing here proves the relaunch works.** Items 1–5 above are Phase 4.
2. **Wave 4 branding must run from the relaunched session**, per D-25, or the engine's wallpaper wins.
3. **`Summary.ps1` is the file whose honesty rules are easiest to erode.** Adding a catalog item
   with `RequiresLogEvidence = $true` and an Evidence string nothing ever logs would silently make
   the screen worse, and the harness's mechanical Evidence check exists precisely to stop that.

---
*Phase: 03-hardening-branding-diagnostics*
*Plan: 01*
*Completed: 2026-10-04*