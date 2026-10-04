# Requirements: AkariOS

**Defined:** 2026-10-04
**Core Value:** The user clicks **Install AkariOS** once, and the machine walks itself through all three WinSux stages across the reboots with visible progress — no console menus, no typed numbers, no re-launching anything by hand.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Pre-Flight

- [ ] **PREF-01**: User sees a pre-flight checklist on launch covering Windows version/build, administrator elevation, internet connectivity, free disk space (≥4 GB), pending reboot state, and battery/AC power on laptops
- [ ] **PREF-02**: User cannot start the install while a blocking pre-flight check is failing; the reason is shown next to the failing check
- [ ] **PREF-03**: App self-elevates via UAC on launch and shows a clear error if elevation is declined

### Safety

- [ ] **SAFE-01**: User can create a system restore point before Stage 1, and sees explicit confirmation that it was created
- [ ] **SAFE-02**: User must type an acknowledgment ("AKARIOS") at a confirmation gate before the destructive stages run, and the gate states exactly what will be changed
- [ ] **SAFE-03**: User sees a per-stage explanation panel describing in plain English what that stage does to the PC and what it costs in security or reversibility
- [ ] **SAFE-04**: User can cancel during Stage 1 (before the first reboot); cancel is disabled once the machine is in a transitional state, and the UI says why

### Progress & Resume

- [ ] **PROG-01**: User sees "Step N of 3" plus a per-stage progress bar and the current action text at all times during the install
- [ ] **PROG-02**: The install state persists to disk before each reboot, and the app auto-resumes on next launch showing "Resuming Step N of 3" with no user action required
- [ ] **PROG-03**: The flow survives all reboots unattended — including the Safe Mode stage — when started via the single-click path

### Flow

- [ ] **FLOW-01**: User can start the full 3-stage install with a single "Install AkariOS" click
- [ ] **FLOW-02**: User can run any individual stage on its own, independent of the full flow
- [ ] **FLOW-03**: Stage 2's Safe Mode pass runs as a console script launched by the GUI, and the GUI resumes normally afterwards

### Branding

- [ ] **BRND-01**: The install rebrands the machine as AkariOS — OEM information, logo, wallpaper/lockscreen, and system branding

### Diagnostics

- [ ] **DIAG-01**: All actions and errors are written to a timestamped log at `%ProgramData%\AkariOS\install.log`
- [ ] **DIAG-02**: When a stage fails, the user sees an error dialog with the failure detail, a log excerpt, and retry/abort options
- [ ] **DIAG-03**: User can export the log (with system info) to a location of their choosing
- [ ] **DIAG-04**: After the install completes, the user sees a "what changed" summary listing what was removed, disabled, and applied, with links to the restore point and the log

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Live Feedback

- **LIVE-01**: Per-action progress streams from the underlying stage scripts to the UI in real time (requires structured output from the engine scripts)
- **LIVE-02**: Dry-run / preview mode shows the intended changes without executing them

### Resilience

- **RESL-01**: Offline mode — payloads can be pre-staged locally and are used in preference to downloading
- **RESL-02**: Crash-recovery script restores a machine interrupted mid-stage (TrustedInstaller binPath, safeboot flag, Defender state)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Per-tweak opt-out | Requires refactoring WinSux from monolithic scripts to modular functions — a significant architecture change. The product is an install flow, not a tweak picker. |
| Rollback / undo of individual changes | Requires registry snapshots before every modification; app removal is not cleanly reversible. The restore point is the supported recovery path. |
| Unattended / silent mode | Depends on per-tweak opt-out; also removes the confirmation gate that this destructive flow requires. |
| Automatic driver installation after DDU | Hardware-specific; requires detecting GPU/audio and fetching the right driver. Separate tool's job — the app links to vendor sites instead. |
| Windows Update integration | Conflicts with the flow's own update-pausing behavior; Windows already does this. |
| Telemetry dashboard | O&O ShutUp10's job; duplicates functionality and adds maintenance burden. |
| Multi-language support | Engine scripts are English-only; target audience is comfortable with English. |
| Social features (shared configs, community presets) | Requires a backend, accounts, and moderation — a different product. |
| GUI inside Safe Mode | WPF rendering in Safe Mode is unreliable; Stage 2 deliberately stays a console script. |
| Bundling payloads locally | ~500 MB of binaries; makes the script huge and hard to update. Downloaded at runtime, same as WinSux. |
| Reimplementing the engine in C# | Project constraint is a single self-contained `.ps1`; the WPF-via-PowerShell approach is proven by AkariTool. |
| The 8 FR33THY Ultimate tweak tabs from AkariTool | AkariOS is the WinSux install flow, not a general tweak panel. Only the shell is reused. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PREF-01 | TBD | Pending |
| PREF-02 | TBD | Pending |
| PREF-03 | TBD | Pending |
| SAFE-01 | TBD | Pending |
| SAFE-02 | TBD | Pending |
| SAFE-03 | TBD | Pending |
| SAFE-04 | TBD | Pending |
| PROG-01 | TBD | Pending |
| PROG-02 | TBD | Pending |
| PROG-03 | TBD | Pending |
| FLOW-01 | TBD | Pending |
| FLOW-02 | TBD | Pending |
| FLOW-03 | TBD | Pending |
| BRND-01 | TBD | Pending |
| DIAG-01 | TBD | Pending |
| DIAG-02 | TBD | Pending |
| DIAG-03 | TBD | Pending |
| DIAG-04 | TBD | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 0
- Unmapped: 18 ⚠️

---
*Requirements defined: 2026-10-04*
*Last updated: 2026-10-04 after initial definition*
