---
phase: 02-core-engine-stage-integration
plan: 01
subsystem: engine-integration
tags: [powershell, wpf, winsux, base64-assets, runspace, seams]

# Dependency graph
requires:
  - phase: 01-shell-and-ui-foundation
    provides: WPF shell, state.json persistence, install.log, RunOnce/safeboot resume detection, confirmation gate
provides:
  - Four WinSux engine assets embedded byte-identically as $sync.assets.<name>
  - Expand-AkariOSEngineAsset decoding helper with injectable asset map and destination root
  - Get-AkariOSRunOnceCommand pure string builder matching winsux.ps1 verbatim
  - Set-AkariOSRunOnceEntry / Set-BcdSafebootValue / Clear-BcdSafebootValue seam wrappers
  - Invoke-AkariOSEngine child-process launcher behind an injectable seam
  - Invoke-AkariOSStage runner and Start-AkariOSInstall published contract entry point
  - Repaired Invoke-RunInBackground (hashtable outcome, -OnComplete, InitialSessionState)
  - Test-Assets.ps1 / Test-Stage.ps1 / Test-Runspace.ps1 static harnesses
affects: [02-02, 02-03, 02-04, phase-04-vm-validation]

actuals:
  tokens: 0
  tasks: 3
  commits: 0

tech-stack:
  added: []
  patterns:
    - "Injectable-seam wrapper: every state-touching call lives only inside a parameter default scriptblock"
    - "Cross-reboot handoff strings built by a pure function and asserted byte-for-byte against upstream"

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

key-decisions:
  - "Checkpoint task 1 resolved: all three one-way decisions ratified as written"

requirements-completed: [FLOW-01, FLOW-03]

coverage: []

duration: 0min
completed: 2026-10-04
status: in_progress
---

# Phase 2 Plan 1: Engine Embedding and Stage Launch Summary

**WinSux engine embedded as byte-identical base64 assets and launched as a child `powershell.exe -File` process behind injectable seams — one confirmation now reaches a real stage launch.**

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
checkpoint resolved.

## Performance

- **Duration:** in progress
- **Started:** 2026-10-04T10:06:49Z
- **Completed:** pending
- **Tasks:** 1 of 3 (checkpoint resolved; execution in progress)
- **Files modified:** pending

## Accomplishments

- One-way architecture decisions ratified and recorded before any code was written.

## Decisions Made

See the checkpoint verdict above; no further decisions taken yet.

## Deviations from Plan

None so far.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

Work in progress.

---
*Phase: 02-core-engine-stage-integration*
*Plan: 01 (in progress)*