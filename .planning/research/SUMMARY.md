# Project Research Summary

**Project:** AkariOS — guided Windows setup app wrapping WinSux
**Domain:** Multi-reboot Windows system modification orchestrator (WPF GUI + PowerShell engine)
**Researched:** 2026-10-04
**Confidence:** HIGH (mechanisms verified against Microsoft Learn, WinSux source, AkariTool reference, and community documentation)

## Executive Summary

AkariOS wraps FR33THY's WinSux — three sequential PowerShell scripts that debloat, optimize, and rebrand Windows across two reboots and a Safe Mode session — in a native WPF GUI with per-stage progress, confirmation gating, and automatic resume. The proven architecture is a single self-contained `.ps1` compiled by concatenation (AkariTool's pattern), embedding the WinSux engine scripts as base64 while downloading payloads (7-Zip, VC++ redists, DDU, Helium, DirectX) at runtime from FR33THY's GitHub releases.

The core technical risk is the reboot-surviving state machine: RunOnce registry entries, `bcdedit safeboot`, and an atomic JSON state file must coordinate across three boot modes (normal → Safe Mode → normal) with no manual intervention. The four researchers agree on the overall approach but diverge on specific implementation details — most notably HKCU vs HKLM RunOnce, safeboot clear timing, and whether to modify WinSux's destructive behaviors. These divergences are flagged below with recommended resolutions.

## Key Findings

### Recommended Stack

PowerShell 5.1 + WPF (.NET Framework 4.8) is the only viable stack: both are inbox on Windows 11, AkariTool already proves the single-file compilation pattern, and the `irm | iex` distribution model requires no installation. The GUI shell (MainWindow.xaml, Compile.ps1, start/main.ps1, runspace pattern, DWM Mica) is directly reusable from AkariTool. The WinSux engine (winsux.ps1, stepone.ps1, steptwo.ps1) is taken 1:1 as the modification logic — AkariOS is the orchestration and branding layer, not a reimplementation.

**Core technologies:**
- PowerShell 5.1 (Win11 inbox): Script engine + WPF host — no runtime install needed
- WPF .NET Framework 4.8 (inbox): GUI layer with Mica backdrop via DWM P/Invoke
- WinSux engine (3 scripts): Stage 1 downloads+prep+reboot, Stage 2 Safe Mode TrustedInstaller+DDU+reboot, Stage 3 debloat+brand+reboot
- bcdedit: Safe Mode boot flag — set by Stage 1, cleared by Stage 2
- RunOnce registry: Cross-reboot handoff — `*!` prefix forces Safe Mode execution, `!` prefix defers deletion
- Compile.ps1 (AkariTool pattern): Concatenate scripts + XAML + base64 assets into single .ps1

### Expected Features

**Must have (table stakes):**
- Pre-flight system checks (OS version, admin, internet, disk space, pending reboots, battery)
- Restore-point creation before Stage 1 — safety net for destructive changes
- Clear stage/step progress indication — "Step N of 3" + progress bar + current action, persisting across reboots
- Resumability across reboots — persist state to file, auto-resume via RunOnce (the #1 table-stakes feature)
- Cancel/abort behavior — cancel during Stage 1, disabled after reboot
- Logging — timestamped log file at `%ProgramData%\AkariOS\install.log`
- Error surfacing — error dialog with details + log excerpt + retry/abort
- Final "what changed / how to undo" summary — post-install summary screen
- Confirmation gate before destructive stages — typed acknowledgment ("AKARIOS")
- Admin elevation check — UAC prompt on launch
- Single-click "Install AkariOS" — runs full 3-stage flow
- Per-stage individual run buttons — power-user path
- AkariOS branding — OEM info, wallpaper, system branding

**Should have (competitive):**
- Live per-action progress streaming — requires structured output from WinSux scripts (JSON lines or progress file)
- Dry-run / preview mode — parse WinSux scripts to show intended changes without executing
- Exportable logs — copy log + system info to user-chosen location
- "What will this do to my PC" explanation panel per stage
- Offline mode — bundle payloads locally, check for local files before downloading

**Defer (v2+):**
- Per-tweak opt-out — requires refactoring WinSux from monolithic to modular (significant architecture change)
- Rollback / undo — requires registry snapshots before modification
- Unattended / silent mode — requires per-tweak opt-out first
- Automatic driver installation — separate tool's job
- Telemetry dashboard — O&O ShutUp10's job
- Multi-language support — maintenance burden, limited demand
- Social features — different product

### Architecture Approach

A WPF GUI shell wraps the WinSux engine via a reboot-surviving state machine. The GUI reads an atomic `state.json` on launch to determine which stage the machine is in, then either resumes the flow or starts fresh. Stage 1 and Stage 3 run in runspaces within the GUI process; Stage 2 runs as a separate console script in Safe Mode (WPF is unreliable in Safe Mode). Progress flows from stage scripts → log file → `Invoke-ProgressReporter` (DispatcherTimer) → WPF status bar within a boot, and via `state.json` across reboots. Stage metadata (names, descriptions, warnings, gating) is declared in `config/stages.json` and baked into the compiled file — no stage-specific text is hardcoded in XAML or PowerShell.

**Major components:**
1. **WPF GUI Shell** — MainWindow + panels (Home, Stage1-3, About), sidebar nav, status bar, Mica backdrop
2. **Orchestration Layer** — State machine (read/write state.json), Stage Runner (runspace), Progress Reporter (log tailing)
3. **WinSux Engine** — Three embedded scripts (winsux.ps1, stepone.ps1, steptwo.ps1) as base64 assets
4. **Persistence Layer** — state.json (atomic write), RunOnce registry (boot handoff), bcdedit safeboot (boot mode flag)
5. **Compile Pipeline** — Compile.ps1 concatenates scripts + functions + config + assets + XAML → akarios.ps1

### Critical Pitfalls

1. **RunOnce entries silently don't fire** — wrong hive (HKCU vs HKLM), wrong user context, or Safe Mode loading a different hive. *Resolution: Use HKLM RunOnce for system-level resume (Pitfall 1 recommendation — overrides STACK/ARCHITECTURE which specify HKCU). Verify entries by reading back after writing.*

2. **State file wiped by disk cleanup** — `steptwo.ps1` runs `cleanmgr` and deletes `C:\Windows\Temp\*`. If state is in `%TEMP%`, it's destroyed. *Resolution: Write state to `C:\ProgramData\AkariOS\state.json` (survives cleanup). Write completion marker BEFORE `shutdown -r`, not after. Use two-phase commit: "stage N started" → work → "stage N completed" → reboot.*

3. **TrustedInstaller binPath repointing fails or isn't restored** — if `sc.exe config` fails or the script crashes between repoint and restore, Windows Update and Installer break permanently. *Resolution: Export original binPath before repointing, verify restore after each `Run-Trusted` call, add watchdog scheduled task.*

4. **Safeboot flag left set** — if stepone.ps1 crashes before clearing safeboot, the machine boots into Safe Mode forever. *Resolution: Clear safeboot at the START of stepone.ps1 (before any destructive operations), not at the end. Add boot-count watchdog: if `HKLM\SOFTWARE\AkariOS\BootCount` exceeds 3, auto-clear safeboot.*

5. **Power-cycle mid-stage** — machine left with repointed TrustedInstaller, safeboot set, Defender partially disabled, or drivers deleted. *Resolution: Create recovery script at `C:\ProgramData\AkariOS\recover.ps1` that restores TrustedInstaller binPath, clears safeboot, re-enables Defender. GUI detects "crashed mid-stage" state on resume and offers recovery.*

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation — Shell + State Machine
**Rationale:** The GUI shell and reboot-surviving state machine are the highest-risk components. Everything else depends on them. AkariTool's shell is proven and reusable; the state machine is the novel part.
**Delivers:** Compiled akarios.ps1 with working WPF GUI, state.json read/write (atomic), RunOnce + bcdedit integration, pre-flight checks, admin elevation, confirmation gating, logging infrastructure.
**Addresses:** Pre-flight checks, admin elevation, confirmation gate, logging, resumability, cancel/abort.
**Avoids:** Pitfall 1 (RunOnce hive), Pitfall 2 (state file location), Pitfall 3 (UAC mid-flow), Pitfall 10 (safeboot clear timing).
**Research flags:** RunOnce HKLM vs HKCU needs validation in Safe Mode VM. State machine edge cases (power-cycle, stale state) need testing.

### Phase 2: Core Engine — Stage Integration
**Rationale:** With the shell and state machine working, integrate the three WinSux stages. Stage 1 and 3 run in runspaces; Stage 2 is a console script. Progress reporting must work across runspace and reboot boundaries.
**Delivers:** All three stages integrated, per-stage progress indication, resume after each reboot, error surfacing with retry/abort, per-stage individual run buttons.
**Addresses:** Clear stage/step progress, resumability, error surfacing, per-stage run buttons.
**Avoids:** Pitfall 4 (power-cycle recovery), Pitfall 5 (Safe Mode networking — pre-stage all payloads), Pitfall 6 (TrustedInstaller restore verification), Pitfall 7 (DDU in Safe Mode — remove `-Restart` flag, control reboot explicitly), Pitfall 10 (safeboot watchdog).
**Research flags:** TrustedInstaller repoint/restore needs VM validation. DDU behavior in Safe Mode needs testing. Progress marker protocol needs implementation in WinSux scripts.

### Phase 3: Integration — Destructive Stage Hardening
**Rationale:** WinSux's destructive behaviors (Edge removal, scheduled task deletion, BitLocker disable, Windows Update pause, DISM operations) have known failure modes. These must be hardened before release.
**Delivers:** Hardened Edge removal (target only Edge-specific subdirectories, not entire `C:\Program Files (x86)\Microsoft`), blocklist-based scheduled task deletion, BitLocker pre-check + skip system drive, configurable Windows Update pause (default 30 days, not 365), DISM error handling + servicing stack verification, hash verification for payload downloads.
**Addresses:** Final "what changed" summary, AkariOS branding.
**Avoids:** Pitfall 8 (scheduled task deletion), Pitfall 9 (Edge removal), Pitfall 11 (security feature disable — add post-setup security configuration), Pitfall 12 (BitLocker), Pitfall 13 (Windows Update pause), Pitfall 14 (DISM), Pitfall 15 (IWR downloads — add hash verification + retry).
**Research flags:** Edge removal impact on WebView2/Store needs testing on multiple app configurations. BitLocker scenarios need VM testing. DISM servicing stack health needs validation.

### Phase 4: Testing — VM-Based Validation
**Rationale:** The flow is destructive and multi-reboot — testing on physical hardware is impractical. VM-based testing with snapshots is the only safe validation approach.
**Delivers:** VM test suite (Hyper-V/VMware), snapshot-based testing per stage, power-cycle simulation, Safe Mode validation, multi-Windows-version testing (Win10 22H2, Win11 23H2/24H2), dry-run mode for scripts.
**Addresses:** All pitfall verification.
**Avoids:** Pitfall 19 (testing destructive flow), Pitfall 16 (7-Zip dependency verification).
**Research flags:** Safe Mode networking behavior varies by hardware — needs explicit testing. DDU behavior varies by GPU vendor.

### Phase 5: Distribution — Security + Packaging
**Rationale:** The tool exhibits malware-like behavior (disables Defender, modifies TrustedInstaller, deletes tasks). Code signing and AV whitelisting are necessary for distribution.
**Delivers:** Code signing (EV certificate), Defender allowlist guidance, user documentation (security implications, recovery instructions), distribution packaging.
**Avoids:** Pitfall 17 (antivirus flagging), Pitfall 18 (`irm | iex` integrity — add hash verification or distribute as compiled executable).
**Research flags:** EV code-signing certificate procurement process and cost. AV vendor whitelisting submission process.

### Phase Ordering Rationale

- **Phase 1 before Phase 2:** The state machine and GUI shell are prerequisites for stage integration. Without reliable resume, stages cannot be tested across reboots.
- **Phase 2 before Phase 3:** Stages must be integrated and running before their destructive behaviors can be hardened. Hardening requires a working baseline to test against.
- **Phase 3 before Phase 4:** Hardening must be complete before systematic testing begins — testing unhardened code wastes VM cycles on known failure modes.
- **Phase 4 before Phase 5:** Testing must pass before distribution. Distributing untested destructive software is irresponsible.
- **Phase 5 last:** Distribution depends on a tested, hardened product. Code signing and AV whitelisting are final packaging steps.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** RunOnce HKLM vs HKCU behavior in Safe Mode — needs VM validation. State machine edge cases (concurrent installs, stale state recovery) need design decisions.
- **Phase 2:** TrustedInstaller repoint/restore reliability — needs VM testing with multiple Windows versions. DDU behavior in Safe Mode varies by GPU vendor.
- **Phase 3:** Edge removal impact on WebView2-dependent apps (Discord, Teams) — needs testing. BitLocker disable scenarios (TPM states, recovery keys) need research.
- **Phase 4:** Safe Mode networking behavior varies by hardware — needs explicit testing matrix. Power-cycle recovery script needs design and testing.

Phases with standard patterns (skip research-phase):
- **Phase 5:** Code signing and AV whitelisting are well-documented processes with established vendors.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | PowerShell 5.1 + WPF proven by AkariTool; all components inbox on Win11 |
| Features | HIGH | Competitor analysis thorough; table stakes well-established in installer UX |
| Architecture | HIGH | AkariTool pattern proven; state machine design sound; WinSux engine taken 1:1 |
| Pitfalls | HIGH | 20 pitfalls identified with specific line references in WinSux source; prevention strategies concrete |

**Overall confidence:** HIGH

### Gaps to Address

- **RunOnce hive divergence:** STACK and ARCHITECTURE specify HKCU RunOnce; PITFALLS recommends HKLM. *Resolution: Use HKLM RunOnce for system-level resume — it fires regardless of which user logs in and is the correct hive for system-level boot handoff. Validate in Safe Mode VM during Phase 1.*
- **Safeboot clear timing divergence:** ARCHITECTURE says clear at end of stepone.ps1; PITFALLS says clear at start. *Resolution: Clear at START of stepone.ps1 — if the script crashes later, the machine still boots normally. This is strictly safer.*
- **WinSux modification scope:** PROJECT.md says "tweak logic is WinSux's, taken 1:1" but PITFALLS identifies several WinSux behaviors that need hardening (Edge removal, scheduled task deletion, BitLocker, Windows Update pause, DDU `-Restart` flag). *Resolution: Modify WinSux scripts where PITFALLS identifies concrete failure modes, but preserve the overall structure and intent. Document all deviations from upstream WinSux.*
- **Engine embedding vs payload download:** ARCHITECTURE recommends embedding engine scripts as base64; PROJECT.md says "download payloads at runtime." *Resolution: Embed the three engine scripts (winsux.ps1, stepone.ps1, steptwo.ps1) as base64 — they are the app's core logic and must match the GUI version. Download payloads (7-Zip, VC++ redists, DDU, Helium, DirectX) at runtime — they are large binaries that change frequently. This reconciles both positions.*
- **Code signing:** PITFALLS identifies this as necessary for distribution but PROJECT.md doesn't mention it. *Resolution: Include EV code-signing in Phase 5. Budget for certificate cost.*
- **Testing infrastructure:** PITFALLS recommends VM-based testing but no VM infrastructure is mentioned in PROJECT.md. *Resolution: Provision Hyper-V or VMware VMs with Windows 10 22H2, Windows 11 23H2, and Windows 11 24H2 for Phase 4.*

## Sources

### Primary (HIGH confidence)
- Microsoft Learn: RunOnce Registry Key — `*` prefix forces Safe Mode execution; `!` prefix defers deletion
- Microsoft Learn: BCDedit Command-Line Options — safeboot set/deletevalue semantics
- Microsoft Learn: TrustedInstaller and Windows Resource Protection — binPath repoint mechanism
- Microsoft Learn: Integrating XAML into PowerShell — XamlReader.Parse pattern, x:Class removal
- Microsoft Learn: Self-elevating PowerShell script — Start-Process -Verb RunAs pattern
- AkariTool source (Compile.ps1, start.ps1, main.ps1, Invoke-RunInBackground.ps1) — proven shell + build pattern
- WinSux source (winsux.ps1, stepone.ps1, steptwo.ps1) — engine being wrapped, 1:1 proven logic
- FR33THY WinSux GitHub repository — upstream engine reference

### Secondary (MEDIUM confidence)
- FuzzySecurity: Windows Userland Persistence — HKCU vs HKLM RunOnce semantics
- JumpSec: Running Once, Running Twice, Pwned! — Exclamation/asterisk prefix behavior
- Bytejmp: Windows Persistence — Scheduled Tasks ONSTART trigger
- NinjaOne: Set Lock Screen Wallpaper — PersonalizationCSP registry keys
- Spiceworks: Wallpaper GPO — Desktop wallpaper via registry
- O'Reilly: Changing Network Identity — Computer name registry keys
- DDU documentation — Safe Mode operation, -Restart flag behavior

### Tertiary (LOW confidence)
- Microsoft Learn: Microsoft Basic Display Driver — Safe Mode WPF rendering (undocumented, needs validation)
- Community: Windows 11 debloat guide discussions on Reddit — anecdotal, needs verification

---
*Research completed: 2026-10-04*
*Ready for roadmap: yes*
