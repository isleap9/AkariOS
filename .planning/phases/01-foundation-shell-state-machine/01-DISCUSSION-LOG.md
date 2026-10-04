# Phase 1: Foundation — Shell + State Machine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-04
**Phase:** 1-Foundation — Shell + State Machine
**Areas discussed:** State machine schema & recovery

---

## State Machine Schema & Recovery

### Question 1: What states should the state machine track?

| Option | Description | Selected |
|--------|-------------|----------|
| Linear pipeline with explicit states | idle → pre-flight → confirming → stage1 → reboot-pending → stage2-safe-mode → reboot-pending → stage3 → completed. Plus error/cancelled branches. | |
| Minimal — stage number + status only | Just: not-started, in-progress (with stage number 1/2/3), completed, error. Simpler schema, less granular tracking. | |
| You decide | You decide the state schema based on what WinSux's RunOnce mechanism actually requires. | |

**User's choice:** "dunno lets copy how WinSux handles it and try to replicate it for AkariOS"
**Notes:** User wants to follow WinSux's approach exactly.

---

### Question 2: How should the app detect where it is when it wakes up after a reboot?

| Option | Description | Selected |
|--------|-------------|----------|
| Registry-based detection (WinSux style) | On launch, check bcdedit safeboot flag + RunOnce entries. If in Safe Mode → resume Stage 2. If normal boot + RunOnce has steptwo → resume Stage 3. If no RunOnce entries → fresh start. | |
| Hybrid — state.json + RunOnce | Keep the state.json decision from STATE.md but ALSO use RunOnce/bcdedit. state.json tracks fine-grained progress, RunOnce tracks which stage is next. | |
| You decide | You decide the detection mechanism based on what's most reliable across reboots and Safe Mode. | |

**User's choice:** "if winsux does it in that way we should try to replicate it"
**Notes:** User confirms registry-based approach.

---

### Question 3: Should we keep a minimal state.json for fine-grained progress within a stage?

| Option | Description | Selected |
|--------|-------------|----------|
| Pure WinSux — no state file | No state.json at all. RunOnce + bcdedit are the only state. Progress within a stage is tracked in-memory only. | |
| Hybrid — RunOnce + minimal state.json | RunOnce + bcdedit for cross-reboot stage tracking, PLUS a lightweight state.json for fine-grained progress within a stage. | |

**User's choice:** "if state.json helps with the project sure we should keep it"
**Notes:** User wants state.json kept if it helps with progress reporting.

---

### Question 4: When something goes wrong mid-install, what should the app do?

| Option | Description | Selected |
|--------|-------------|----------|
| Show error, user decides | If something goes wrong, the app shows an error dialog explaining what happened and offers options: retry, skip, or abort. | |
| Auto-retry, then show error | The app tries to recover on its own — e.g., if Stage 2 fails, it retries once before showing an error. | |
| You decide | You decide what makes sense based on WinSux's behavior and the project's needs. | |

**User's choice:** "drop a log so we can see what went wrong and also the user can report it on github"
**Notes:** User wants logging for diagnostics and GitHub issue reporting.

---

### Question 5: If the app launches and finds the machine in a weird state, what should it do?

| Option | Description | Selected |
|--------|-------------|----------|
| Detect interrupted state, warn user | If the app launches and finds the machine is in a transitional state, it shows a warning and offers to resume or abort. | |
| Always try to resume | The app always tries to resume from where it left off, even if the state looks inconsistent. | |
| You decide | You decide the recovery behavior based on what's safest for the user's machine. | |

**User's choice:** "the app should say try again"
**Notes:** User wants simple "try again" message for inconsistent states.

---

## Claude's Discretion

The following areas were not discussed (user chose to start working):
- Confirmation gate UX & flow
- Progress reporting architecture
- Pre-flight check behavior & UX

## Deferred Ideas

None — discussion stayed within phase scope
