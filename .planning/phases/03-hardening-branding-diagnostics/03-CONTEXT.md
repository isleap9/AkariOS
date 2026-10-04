# Phase 3: Hardening, Branding & Diagnostics — Context

**Gathered:** 2026-10-04 (after Phase 2 live VM validation)
**Status:** Ready for planning
**Supersedes:** the ROADMAP's flat 9-item plan list — see "Plan ordering" below.

<domain>
## Phase Boundary

Make the install *legible* to the user: recoverable before it starts, visible after
it ends, diagnosable on demand, and visibly branded.

**In scope:**
- The missing **GUI relaunch after Stage 3** (unimplemented gap, not polish).
- **DIAG-04** — the post-install "what changed" summary, with links to the restore
  point and the log.
- **SAFE-01** — a restore point **before** Stage 1, with explicit confirmation.
- **DIAG-03** — log export with system info to a user-chosen location.
- **BRND-01** — OEM information, logo, wallpaper/lockscreen, system branding.

**Out of scope:** everything the ROADMAP's nine-item list also named but the user
deferred — Edge-removal hardening, scheduled-task-deletion blocklisting, BitLocker
pre-check, Windows-Update-pause configurability, DISM error handling, and payload hash
verification. Those are Phase 3 *roadmap* items, not Phase 3 *requirement* items: they
would all require patching the vendored engine, which D-06 forbids. **BRND-01 is the
exception** and is implemented in AkariOS code, not engine code. Shell, state machine,
pre-flight, confirmation gate, logging, progress rendering, and stage integration are
Phase 1/2 deliverables and are not reworked here.

</domain>

<the_defect>
## The one outstanding defect from Phase 2 live validation

Phase 2 was validated for real in a VM across two reboots and a Safe Mode session.
All three WinSux stages executed. **After `steptwo.ps1` reboots, the AkariOS GUI never
comes back.** The user lands on a clean desktop with no route into the GUI except
re-running `akarios.ps1` by hand.

**Verified root cause:** there is no relaunch mechanism anywhere in the codebase. No
`!AkariOS` RunOnce entry, no relaunch code path, no Startup-folder shortcut. Phase 2
recorded the absence as an explicit deviation (T-02-35 in `Test-Stage.ps1` asserts no
`!AkariOS` RunOnce value is written anywhere) — deliberately, because of the blocker below.

**The blocker that makes the obvious fix wrong:** the vendored
`WinSux-main/WinSux/steptwo.ps1` (READ-ONLY, must stay byte-identical) wipes the RunOnce
key three times near its end:

```
324: cmd /c "reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
325: cmd /c "reg add    "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
328: cmd /c "reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
329: cmd /c "reg add    "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
332: cmd /c "reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
333: cmd /c "reg add    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce" /f >nul 2>&1"
```

Any RunOnce entry written **before** Stage 3 starts is unconditionally destroyed. A
Startup-folder shortcut is not destroyed, but it re-runs elevation and pre-flight on
**every logon** until something deletes it, which is noisy and user-visible.

**Task Scheduler is not touched by that wipe.** It is the only one of the three
surviving mechanisms.

</the_defect>

<decisions>
## Implementation Decisions

### Post-install relaunch

- **D-13: A scheduled task, created before Stage 3 launches.** Not RunOnce (destroyed
  by `steptwo.ps1:324-333`), not a Startup-folder shortcut (re-runs elevation on every
  logon). The task is a *one-shot UI affordance*, not a persistence mechanism, and it
  self-deletes on the first post-install launch. — **Reversibility:** costly — a task
  left behind relaunches the GUI at every logon until removed, and removing it by hand
  requires knowing the name. Mitigated by a self-delete that is idempotent and tolerant
  of the task already being absent, plus a documented `schtasks /delete` recovery
  command in the plan.

- **D-14: ONLOGON in the interactive user session, not `/RU SYSTEM`.** A task running
  as SYSTEM executes in session 0, which has **no visible desktop** — the WPF window
  would exist on a desktop the user cannot see, and the completion screen would still
  be invisible, which defeats the entire purpose. The task therefore targets the
  interactive user with `/IT` and `/RL HIGHEST`, and falls back to `/RU SYSTEM` only if
  the interactive account cannot be resolved, logging a WARN so the fallback is never
  silent. — **Reversibility:** costly — the visible-vs-invisible distinction cannot be
  verified statically; it is a VM verification item with an explicit pass criterion.

- **D-15: The relaunch target is a copy of the running script staged under
  `%ProgramData%\AkariOS\`.** The user may have launched `akarios.ps1` from Downloads,
  a temp path, or a deleted file. Staging a copy makes the task's command line stable
  and independent of where the user happened to run it from. — **Reversibility:**
  reversible.

- **D-16: Completion detection reuses `Get-ResumePoint`, it does not reinvent it.**
  `Resume.ps1:122` already computes
  `$stateDone = ($State.Status -eq "completed" -and $State.CurrentStage -ge 3)`.
  That exact predicate is the gate for the completion screen. No second copy of the
  rule may appear anywhere. — **Reversibility:** reversible.

- **D-17: Self-delete runs on the first launch that observes completion.** Idempotent:
  a missing task is a no-op returning `$false`, never an exception. The delete happens
  *after* the summary is computed so a failure mid-way cannot leave the user with
  neither screen nor task. — **Reversibility:** reversible.

### Restore point

- **D-18: SAFE-01's restore point is AkariOS's own, created before Stage 1, and it is
  additive to the engine's.** `steptwo.ps1:1217` already calls
  `Checkpoint-Computer -Description "backup"` at the END of Stage 3 — after everything
  has been removed. That is too late to be the safety net SAFE-01 asks for. AkariOS
  creates its own, before Stage 1, through an injectable seam. The engine's is left
  alone (D-06). — **Reversibility:** cheap — a restore point is additive and cannot
  break anything if unused.
- **D-19: Confirmation is explicit and truthful.** "Created" is shown only when the
  seam returned success. A failure (System Protection off, frequency-limited restore
  points, domain policy) is reported as a failure with the reason, and Stage 1 is
  **blocked** until the user acknowledges it — SAFE-02's pattern, reused. — 
  **Reversibility:** reversible.
- **D-20: The confirmation records the restore point identity** (description, sequence
  number, timestamp) in `state.json` so DIAG-04's "link to the restore point" can name
  a real thing instead of opening an unfiltered list. — **Reversibility:** reversible.

### "What changed"

- **D-21: The summary is a catalog plus log corroboration, never introspection.**
  Under D-06 the engine is verbatim and exposes no structured output, so AkariOS cannot
  ask "what did you remove". The summary lists what each WinSux stage does (a static
  catalog derived from the vendored scripts) and marks each item *applied* or
  *not confirmed in the log* by looking for the stage's completion evidence in
  `install.log`. An item is never reported as applied when the log does not support it.
  — **Reversibility:** reversible.
- **D-22: No live-failure interception, no new `ResumePoint`.** Same reasoning as D-09 /
  D-10 and the same Phase 2 invariant: `Get-ResumePoint`'s decision table and
  `main.ps1`'s resume switch stay byte-identical, and completion is an *independent*
  check layered on top. — **Reversibility:** reversible.

### Log export

- **D-23: Export writes a new file; it never moves or truncates `install.log`.** The
  live log is the DIAG-01 record and must survive. Export is read-only against it.
  — **Reversibility:** reversible.
- **D-24: The destination is chosen through an injectable dialog seam.** The real
  default is a folder-picker (`System.Windows.Forms.FolderBrowserDialog`), and the
  harness never shows it. — **Reversibility:** reversible.

### Branding

- **D-25: Branding is applied by AkariOS, after Stage 3, from the same relaunched
  session.** `steptwo.ps1:763-780` generates a black wallpaper and lockscreen at
  Stage 3. Anything written before that is overwritten. So branding runs on the
  post-install relaunch (D-13's GUI), which is exactly why the relaunch mechanism has
  to land first. — **Reversibility:** costly — reordering branding before the relaunch
  work means it silently loses to the engine's wallpaper write.
- **D-26: Every branding write goes through a `-RegistryWriter` seam; every image
  generation goes through a `-ImageWriter` seam.** Nothing in the branding path calls
  `reg.exe`, `System.Drawing`, or `rundll32` outside a default. — **Reversibility:**
  reversible.
- **D-27: Computer name is NOT renamed by AkariOS.** A computer-name change requires a
  second reboot and the engine has already rebooted once at the end. Out of scope;
  recorded so it is not mistaken for an omission.

</decisions>

### Verification doctrine (this phase is stricter than Phase 2)

Phase 2 was nearly shipped with a grep-only harness that passed green while **three real
runtime bugs were live**: a `$ps.Free` / `$psd.Free` typo, a `GetNewClosure()`-across-
runspace bug, and a null `-EngineInvoker` reaching `& $null`. Every harness in this phase
must **execute real behaviour**. Specifically, for the launch / registry / scheduled-
task / process paths, a stub that merely records the argument it was handed is **not
acceptable as the only assertion** — the harness must also drive the function's
decision logic, its idempotency, and its failure branch with real values and read real
results back off disk. Every new harness must additionally be **mutation-tested**: the
plan step reverts the fix, asserts the harness goes RED, restores the fix, and asserts
GREEN.

**Nothing destructive is executed on the authoring machine.** No real `bcdedit`, no
registry writes, no scheduled-task creation, no reboot, no stage execution, no engine
child process. Static checks only (PowerShell parser, XAML `[xml]` cast, grep, MD5) plus
harnesses with injected seams.

### Carried forward (not re-litigated)

- **D-06:** the four engine assets stay byte-identical to `WinSux-main/`. Every plan
  here re-verifies by MD5. No branding, restore-point or relaunch work may touch
  `WinSux-main/` or `AkariOS/assets/text/`.
- **D-07:** the engine owns the reboot. AkariOS code contains no `shutdown`,
  `Restart-Computer`, or bare `bcdedit` outside a wrapper default.
- **D-09 / D-10:** post-hoc detection and reporting, never live interception.
- **V7:** every outside-world call sits behind an injectable scriptblock parameter whose
  default is the real call. Phase 3 adds these seams: `-TaskWriter`, `-ScriptCopier`,
  `-ShellInvoker`, `-RestorePointInvoker`, `-RestorePointReader`, `-SystemInfoReader`,
  `-RegistryWriter`, `-ImageWriter`.

</decisions>

<plan_ordering>
## Plan ordering (user decision — this overrides the ROADMAP list)

| Wave | Plan | Requirement | Why here |
|------|------|-------------|-----------|
| 1 | `03-01-PLAN.md` | **DIAG-04 + the GUI relaunch mechanism** | Without the relaunch the completion screen can never be shown, so DIAG-04 is unobservable. This is a genuine unimplemented gap, not polish. |
| 2 | `03-02-PLAN.md` | SAFE-01 | Restore point before Stage 1. Depends on the summary's restore-point *link* (D-20) existing in Wave 1. |
| 3 | `03-03-PLAN.md` | DIAG-03 | Log export. Independent of 01 and 02. |
| 4 | `03-04-PLAN.md` | BRND-01 | Branding. **Must be last** — it runs from the relaunched session (D-25) and the engine's Stage 3 overwrites wallpaper written earlier. |

Each plan depends on the one before it (`depends_on:` in the frontmatter), and the
checkpoints are ordered so that no irreversible system change happens before its
design gate.

</plan_ordering>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before implementing.**

### Engine source of truth (read-only, never edit)
- `WinSux-main/WinSux/steptwo.ps1` — Stage 3. RunOnce wipe at L324-333; black
  wallpaper/lockscreen generation and its registry writes at L763-780; BitLocker
  disable at L437-444; `Checkpoint-Computer` at L1217; `shutdown -r -t 00` at L1224.
- `WinSux-main/WinSux/winsux.ps1` — Stage 1. RunOnce entries L222/L225, safeboot L228,
  reboot L234.
- `WinSux-main/WinSux/stepone.ps1` — Stage 2. Clears safeboot L148.
- `WinSux-main/WinSux/reg.reg` — the registry import Stage 3 applies (1494 lines; the
  source of the DIAG-04 "applied" catalog).

### Project context
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`,
  `.planning/STATE.md`
- `.planning/phases/02-core-engine-stage-integration/02-CONTEXT.md` — D-06..D-12
- `.planning/phases/02-core-engine-stage-integration/02-VERIFICATION.md` — the ten
  manual-only items Phase 4 inherits
- `.planning/phases/02-core-engine-stage-integration/02-01-PLAN.md` — the plan format
  every Phase 3 plan copies

### Existing shell the work builds on
- `AkariOS/functions/private/State.ps1` — the state schema. Valid statuses are exactly
  `pending`, `running`, `installing`, `completed`, `error` (`State.ps1:71` and the
  `ValidateSet` at `:134`). The write path is atomic; the `Object` parameter set is the
  lossless one.
- `AkariOS/functions/public/Resume.ps1:122` — `$stateDone`, the completion predicate
  Wave 1 reuses.
- `AkariOS/functions/public/Diagnostics.ps1` — the DIAG-02 failure path and the
  house `Reveal-*` / `Show-*` marshalling idiom to copy.
- `AkariOS/functions/public/Stage.ps1` — `Invoke-AkariOSStage`, where the relaunch task
  must be created (Stage 3, before the engine child starts).
- `AkariOS/scripts/main.ps1` — launch-time integration. Steps 1-7; Wave 1 adds step 8.
- `AkariOS/xaml/MainWindow.xaml:430-435` — the sidebar nav; a new panel needs a
  `NavXyz`, a `xaml/panels/NN-Xyz.xaml` fragment, and registration in `main.ps1`'s
  `$panels` / `$navMap` / `$navNames`.
- `AkariOS/tools/Test-Stage.ps1`, `Test-Diagnostics.ps1` — the harness house style:
  dot-source, `Assert($label, $cond)`, scratch dir under `$env:TEMP`, `exit 1` on
  failure, `<ALL X TESTS PASSED>` line.

</canonical_refs>

<deferred>
## Deferred Ideas

- **Edge-removal hardening, scheduled-task-deletion blocklist, BitLocker pre-check,
  Windows-Update-pause configurability, DISM error handling, payload hash verification**
  (the ROADMAP's Phase 3 items 1-6) — all require patching the vendored engine, which
  D-06 forbids. They are not v1 requirements. Tracked here so they are not mistaken for
  omissions.
- **Computer-name rename** (D-27) — would need a second reboot after Stage 3's.
- **Live per-action progress streaming** (LIVE-01) and **dry-run mode** (LIVE-02) —
  v2 requirements; both need structured output from the engine.
- **Rollback / undo of individual changes** — explicitly Out of Scope. The restore
  point is the supported recovery path.

</deferred>

---

*Phase: 3-Hardening, Branding & Diagnostics*
*Context gathered: 2026-10-04*
