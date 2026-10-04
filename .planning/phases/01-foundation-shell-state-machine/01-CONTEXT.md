# Phase 1: Foundation — Shell + State Machine - Context

**Gathered:** 2026-10-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a compiled `akarios.ps1` with a working WPF GUI shell, a reboot-surviving
state machine, pre-flight checks, admin elevation, confirmation gating, logging
infrastructure, and progress reporting — the prerequisites for everything else.

</domain>

<decisions>
## Implementation Decisions

### State Machine Schema & Recovery

- **D-01:** Replicate WinSux's registry-based approach — RunOnce entries + bcdedit
  safeboot flag as the cross-reboot state. No separate state file for stage tracking.
  — **Reversibility:** reversible — state mechanism is internal, can be changed later

- **D-02:** Keep a lightweight `state.json` at `C:\ProgramData\AkariOS\state.json`
  for fine-grained within-stage progress (supports PROG-01 progress reporting).
  Cross-reboot stage tracking uses RunOnce + bcdedit only.
  — **Reversibility:** reversible — file format is internal

- **D-03:** On launch, check safeboot flag + RunOnce entries to determine resume
  point. If in Safe Mode → resume Stage 2. If normal boot + RunOnce has steptwo →
  resume Stage 3. If no RunOnce entries → fresh start.
  — **Reversibility:** reversible — detection logic is internal

- **D-04:** Log everything to `%ProgramData%\AkariOS\install.log` (DIAG-01).
  All actions and errors written with timestamps. Enables diagnostics and GitHub
  issue reporting.
  — **Reversibility:** reversible — log format is internal

- **D-05:** If the machine is in an inconsistent state (e.g., safeboot flag set
  but Stage 2 never completed), show "try again" message to the user. Do not
  attempt automatic recovery from inconsistent states.
  — **Reversibility:** reversible — recovery behavior is internal

### Claude's Discretion

The following areas were not discussed (user chose to start working):
- **Confirmation gate UX & flow** — How the typed "AKARIOS" acknowledgment works,
  how per-stage explanation panels (SAFE-03) integrate with the gate (SAFE-02)
- **Progress reporting architecture** — How runspaces report progress back to the
  WPF UI, how "Step N of 3" + current action text is displayed
- **Pre-flight check behavior & UX** — Which checks are blocking vs warning, how
  pass/fail is shown, how the UI prevents starting when blocking checks fail

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Full project context, constraints, key decisions
- `.planning/REQUIREMENTS.md` — 18 v1 requirements (PREF-01..03, SAFE-02..04, PROG-01..03, DIAG-01)
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, 6 plans
- `.planning/STATE.md` — Current state, key risks, decisions log

### Reference Sources (read-only)
- `WinSux-main/WinSux/winsux.ps1` — Stage 1 engine (RunOnce setup, bcdedit safeboot)
- `WinSux-main/WinSux/stepone.ps1` — Stage 2 engine (Safe Mode, TrustedInstaller)
- `WinSux-main/WinSux/steptwo.ps1` — Stage 3 engine (normal boot, heavy debloat)
- `AkariTool/Compile.ps1` — Single-file compilation pattern
- `AkariTool/scripts/start.ps1` — Admin elevation, WPF assembly loading, DWM P/Invoke
- `AkariTool/scripts/main.ps1` — XamlReader.Parse, control wiring, sidebar nav
- `AkariTool/xaml/MainWindow.xaml` — Shell XAML (styles, titlebar, sidebar, status bar)
- `AkariTool/functions/private/Invoke-RunInBackground.ps1` — Runspace pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **AkariTool shell** (MainWindow.xaml, start.ps1, main.ps1): Complete WPF shell with
  Mica backdrop, dark theme, sidebar nav, status bar. Directly reusable with AkariOS
  branding.
- **Compile.ps1**: Concatenation pipeline for single-file output. Reads scripts,
  embeds XAML at `@PANELS@` marker, base64-encodes assets.
- **Invoke-RunInBackground.ps1**: Runspace pattern for non-blocking operations with
  DispatcherTimer completion watcher.
- **WinSux scripts**: Three engine scripts that define the stage behavior, RunOnce
  mechanism, and bcdedit safeboot flow.

### Established Patterns
- **Single-file compilation**: All source concatenated into one .ps1 at build time
- **XamlReader.Parse**: XAML loaded at runtime, no compiled code-behind
- **Synchronized $sync hashtable**: Cross-runspace state sharing
- **DWM P/Invoke**: Mica backdrop via DwmSetWindowAttribute
- **RunOnce registry**: `*!` prefix for Safe Mode, `!` prefix for normal boot

### Integration Points
- **WinSux RunOnce mechanism**: AkariOS must write the same RunOnce entries that
  WinSux writes, so the stages can find each other across reboots
- **bcdedit safeboot flag**: AkariOS must set/clear this at the same points WinSux does
- **AkariTool status bar**: `Set-Status` function for runspaces to post progress

</code_context>

<specifics>
## Specific Ideas

- User wants to replicate WinSux's behavior exactly — "copy how WinSux handles it"
- User prefers action-oriented work — "I would like to start working on the project"
- User defers technical decisions to Claude when not sure

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-Foundation — Shell + State Machine*
*Context gathered: 2026-10-04*
