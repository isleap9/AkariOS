# Phase 2: Core Engine — Stage Integration - Context

**Gathered:** 2026-10-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire FR33THY's three WinSux stage scripts into the existing AkariOS WPF shell so a
single click drives the whole flow across two reboots and a Safe Mode session.

**In scope:** embedding the engine scripts as base64 assets; Stage 1 and Stage 3
execution as background runspaces; Stage 2 execution as a Safe Mode console script;
the single-click full flow; individual per-stage run buttons; post-reboot auto-resume;
error detection, reporting, and retry/abort.

**Out of scope:** the shell, state machine, pre-flight gating, confirmation gate,
logging, and progress rendering — all delivered and verified in Phase 1. Also out of
scope: hardening WinSux's destructive operations (Phase 3), branding (Phase 3),
VM validation (Phase 4), packaging and signing (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Engine fidelity — the governing decision of this phase

- **D-06: Replicate WinSux exactly.** The user chose "for now lets copy winsux" as the
  resolution for all four gray areas. AkariOS is the shell, the flow state machine, and
  the rebranding layer — never a reimplementation of the tweak logic. Where AkariOS and
  WinSux disagree, **WinSux wins**. This is the user's standing preference: ground truth
  from the real tool beats independent design decisions.
  — **Reversibility:** costly — the engine is embedded as base64 inside the compiled
  single-file output, so changing the fidelity model later means re-embedding all three
  scripts and re-testing the full reboot sequence.

### Reboot handoff

- **D-07: Keep `shutdown -r -t 00` verbatim.** WinSux reboots instantly with no warning
  or countdown (`winsux.ps1:234`, `steptwo.ps1:1224`). AkariOS does not add a warning
  dialog or countdown, because intercepting the reboot would mean editing the engine.
  — **Reversibility:** costly — changing this later requires instrumenting the engine
  scripts, i.e. undoing D-06.
- **D-08: Nothing of ours runs between stage 1 and the Safe Mode boot.** The GUI cannot
  survive a reboot. On next launch the resume banner does the work, driven by safeboot +
  RunOnce detection per Phase 1 D-03. `scripts/main.ps1:163-167` already assumes this and
  needs no change. — **Reversibility:** reversible.

### Stage failure and the half-modified machine

- **D-09: Do not intercept engine failure.** Because the engine is verbatim, a stage that
  fails mid-way still reboots — the machine can be left with Defender disabled and no boot
  entry, exactly as WinSux would leave it. AkariOS does not add a live failure trap.
  — **Reversibility:** costly — undoing this means instrumenting the engine (D-06).
- **D-10: FLOW-03 / DIAG-02 are scoped as post-reboot detection and reporting.** Because
  AkariOS cannot intercept a live failure (D-09), error surfacing works by: detecting a
  stage that ended in an error state via `state.json` on next launch; reading the failure
  detail and log excerpt from `%ProgramData%\AkariOS\install.log`; and offering retry/abort
  in the GUI. The requirement is met honestly as *detection after the fact*, not live
  interception. — **Reversibility:** reversible.

### Stage 2 / Safe Mode handoff

- **D-11: Trust the `*!` RunOnce prefix, with `state.json` as corroboration only.** Keep
  WinSux's proven mechanism as the primary path (`winsux.ps1:222`). Do NOT add a
  belt-and-braces alternative mechanism such as a scheduled task. Phase 1 D-03 already
  has resume detection reading both signals, so the corroboration exists for free.
  This remains the project's highest listed risk (`*!` firing in Safe Mode is documented
  but thinly proven across builds) and is explicitly a Phase 4 VM-validation target.
  — **Reversibility:** costly — a fallback mechanism added later means a second code path
  through stage handoff, plus re-testing both.
- **D-12: Raw console in Safe Mode, never WPF.** Stage 2 runs as WinSux's plain
  console script (`powershell -nop -ep bypass -WindowStyle Maximized`). The AkariOS GUI
  does not render in Safe Mode — WPF there depends on undocumented Render Tier 0
  (BasicDisplay.sys + WARP) and is unreliable, which is the wrong thing to bet a
  half-completed system modification on. — **Reversibility:** costly — the Safe Mode
  window is maximized console by contract; any GUI there needs new Safe Mode-safe
  rendering work.

### Carried forward from Phase 1 (not re-discussed)

- **D-01:** RunOnce entries + `bcdedit` are the cross-reboot mechanism. AkariOS writes the
  same entries WinSux writes, so the stages find each other.
- **D-02:** Lightweight `state.json` at `C:\ProgramData\AkariOS\state.json`.
- **D-03:** Resume point derived from safeboot flag + RunOnce entries on launch.
- **D-05:** Inconsistent state → no CTA, manual resolution by the user.
- **D-04:** Everything logged to `%ProgramData%\AkariOS\install.log`.

### Claude's Discretion

- Exact base64 asset packing format and the decode helper's shape (Compile.ps1 already
  has an asset-embedding path to follow).
- Whether per-stage run buttons live on the existing progress panel or a new stage panel.
- Runspace lifecycle details: creation, teardown, and how completion is detected via the
  existing `Invoke-RunInBackground` pattern.
- Retry semantics for D-10: whether retry re-runs a whole stage or offers a manual
  handoff, as long as abort is always available.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Engine source of truth (read-only, never edit)
- `WinSux-main/WinSux/winsux.ps1` — Stage 1. Payload download, writes both RunOnce
  entries at L222/L225, `bcdedit /set {current} safeboot minimal` at L228, reboots at
  L234 via `shutdown -r -t 00`.
- `WinSux-main/WinSux/stepone.ps1` — Stage 2. Runs in Safe Mode as TrustedInstaller;
  clears `safeboot` at L148; also clears `allowedinmemorysettings` / `isolatedcontext` /
  `hypervisorlaunchtype` at L122-124.
- `WinSux-main/WinSux/steptwo.ps1` — Stage 3. Wipes RunOnce in HKCU, HKLM, and
  `WOW6432Node` at L324-333; reboots at L1224.
- `WinSux-main/WinSux/reg.reg` — registry import applied by Stage 3.

### Project context
- `.planning/PROJECT.md` — core value, constraints, evolution rules
- `.planning/REQUIREMENTS.md` — FLOW-01, FLOW-02, FLOW-03, DIAG-02
- `.planning/ROADMAP.md` — Phase 2 goal and success criteria
- `.planning/STATE.md` — decisions log and key risks
- `.planning/phases/01-foundation-shell-state-machine/01-CONTEXT.md` — D-01..D-05
- `.planning/phases/01-foundation-shell-state-machine/01-VERIFICATION.md` — what Phase 1
  proved statically, the VM procedures still owed, and open defect D-01 (pre-flight
  checks never auto-run, so the Install button stays disabled until the Check tab is
  opened)

### Shell reference (read-only)
- `AkariTool/functions/private/Invoke-RunInBackground.ps1` — runspace pattern this phase
  builds on
- `AkariOS/scripts/main.ps1` — where stage launch, resume detection, and the `Btn*` →
  `Invoke-*` wiring live
- `AkariOS/Compile.ps1` — the base64 asset-embedding path to extend

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AkariOS/functions/private/Invoke-RunInBackground.ps1`: ported from AkariTool. Gives
  Stage 1 and Stage 3 a background runspace with Dispatcher-marshalled status updates —
  no new concurrency machinery needed.
- `AkariOS/Compile.ps1`: already base64-encodes `assets/text/`. Stage scripts drop into
  `AkariOS/assets/text/` and need only a decode step at startup.
- `AkariOS/functions/public/Resume.ps1`: `Get-ResumePoint` already reads safeboot and both
  RunOnce entries through injectable wrappers — this is the entry point for auto-resume.
- `AkariOS/functions/public/Progress.ps1`: `Set-CurrentStage` / `Update-ProgressDisplay`
  render "Step N of 3". Stage integration drives these; it does not rebuild them.
- `AkariOS/functions/public/State.ps1`: atomic `state.json` persistence with schema
  validation — the channel for recording stage outcome.

### Established Patterns
- Single-file compilation by concatenation; XAML via `XamlReader.Parse`; synchronized
  `$sync` hashtable for cross-runspace state; no compiled assembly, no external deps.
- Buttons are wired by convention: a control named `Btn*` is dispatched to `Invoke-*`.
  New stage buttons must follow it or they will silently do nothing — this exact bug
  shipped once in Phase 1 (the Install CTA had no handler).

### Integration Points
- **WinSux RunOnce mechanism** — AkariOS writes the identical entries so stages find
  each other across reboots.
- **`bcdedit safeboot` flag** — set by Stage 1, cleared at the *start* of Stage 2
  (Phase 1 decision; clearing at the end risks a Safe Mode loop).
- **`Set-Status`** — the runspace → UI status channel (Phase 1 already routes through it).

</code_context>

<specifics>
## Specific Ideas

- "for now lets copy winsux" — the user resolved all four gray areas in favor of exact
  upstream replication. "For now" leaves room to revisit fidelity later; record any
  divergence from WinSux as an explicit deviation rather than a silent divergence.

</specifics>

<deferred>
## Deferred Ideas

- **Reboot warning / countdown dialog** (D-07) — deferred; would require instrumenting
  the engine. Revisit if the instant reboot proves too jarring in practice.
- **Live failure interception of a running stage** (D-09/D-10) — deferred; same blocker.
- **Scheduled-task fallback for Safe Mode stage handoff** (D-11) — deferred; `*!` stays
  primary, and VM validation in Phase 4 is what decides whether it is needed.
- **Phase 1 open defect D-01** (pre-flight checks never auto-run, so the Install button
  stays disabled until the user opens the Check tab) — not Phase 2 scope, but it will
  block the Phase 2 single-click flow's happy path in manual testing. Fix before VM
  validation.
- **Case-sensitive `AKARIOS` confirmation token** (Phase 1 deviation 2) — no ruling yet;
  one line to relax if case-insensitive is preferred.

</deferred>

---

*Phase: 2-Core Engine — Stage Integration*
*Context gathered: 2026-10-04*