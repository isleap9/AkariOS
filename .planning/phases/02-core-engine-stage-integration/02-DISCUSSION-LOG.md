---
phase: 02-core-engine-stage-integration
discussed: 2026-10-04
mode: discuss
areas_selected: [reboot-handoff, stage-failure, engine-fidelity, safe-mode-handoff]
resolution: single-decision — "for now lets copy winsux"
---

# Phase 02 Discussion Log

Human reference only — not consumed by downstream agents. The canonical record is
`02-CONTEXT.md`.

## How the discussion resolved

Four gray areas were surfaced. The user resolved all of them with one instruction:
**"for now lets copy winsux."** Where my analysis had recommended otherwise, the user
chose upstream fidelity. Recorded faithfully below, including the consequences.

## Areas and outcomes

### 1. Reboot handoff & what the user sees
- **Question:** WinSux calls `shutdown -r -t 00` with no warning. Warn/countdown, or
  verbatim? And does anything render between Stage 1 and the Safe Mode boot?
- **Claude's recommendation:** AkariOS owns the reboot — warn, countdown, then reboot.
- **User's choice:** Copy WinSux. Verbatim `shutdown -r -t 00`, no warning dialog.
- **Captured as:** D-07, D-08
- **Consequence recorded:** Interrupting the reboot would mean editing the engine.

### 2. Stage failure & the half-modified machine
- **Question:** WinSux reboots unconditionally. Stop and surface the error, or keep
  fire-and-forget?
- **Claude's recommendation:** Catch a non-zero exit, stop, surface the error with the
  log excerpt. Flagged explicitly that this diverges from upstream.
- **User's choice:** Copy WinSux. No live failure trap.
- **Captured as:** D-09, D-10
- **Consequence recorded:** A stage that dies mid-way still reboots; the machine can be
  left with Defender disabled and no boot entry, exactly as WinSux would leave it.
  FLOW-03 / DIAG-02 therefore become *post-reboot detection and reporting* rather than
  live interception. The requirement is met as detection after the fact.

### 3. Engine fidelity vs AkariOS control
- **Question:** Embed the engine verbatim (max fidelity, no live progress) or
  instrument it (real progress, divergence risk)?
- **Claude's recommendation:** Instrumented-but-minimal — progress/state callbacks only,
  tweak logic byte-identical.
- **User's choice:** Copy WinSux. Verbatim embedding.
- **Captured as:** D-06 — the governing decision of the phase
- **Consequence recorded:** No live progress from inside the engine. AkariOS can only
  report "running" and poll the log.

### 4. Stage 2 Safe Mode handoff
- **Question:** Trust the `*!` RunOnce prefix, or add a fallback? And does the GUI try to
  run in Safe Mode?
- **Claude's recommendation:** Keep `*!` as primary with `state.json` corroborating (no
  new mechanism); raw console in Safe Mode, never WPF.
- **User's choice:** Copy WinSux — `*!` only, no fallback mechanism.
- **Captured as:** D-11, D-12
- **Consequence recorded:** `*!` remains the project's highest listed risk and is
  explicitly a Phase 4 VM-validation target. `state.json` corroboration already exists
  free via Phase 1 D-03.

## Deferred ideas raised

- Reboot warning / countdown dialog — blocked on engine instrumentation (D-07)
- Live failure interception — blocked on engine instrumentation (D-09/D-10)
- Scheduled-task fallback for Safe Mode handoff — Phase 4 VM validation decides (D-11)

## Raised but outside Phase 2 scope

- **Phase 1 defect D-01** — pre-flight checks never auto-run, so the Install button stays
  disabled until the user manually opens the Check tab. Not Phase 2 scope, but it blocks
  the Phase 2 single-click happy path during manual testing. Should be fixed before VM
  validation.
- **Case-sensitive `AKARIOS` token** — no ruling given; one line to relax if preferred.

## Claude's discretion

- Base64 asset packing format and decode helper shape
- Stage buttons on the existing progress panel vs a new stage panel
- Runspace lifecycle details (creation, teardown, completion detection)
- Retry semantics for post-reboot error recovery (abort must always be available)