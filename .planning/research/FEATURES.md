# Feature Research

**Domain:** Multi-stage Windows installer/setup GUI (power-user debloat + rebrand tool)
**Researched:** 2026-10-04
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Pre-flight system checks | Users expect an installer to verify the environment before making changes. Windows Setup checks edition/build; NTLite checks image compatibility; WinUtil checks admin rights. Without this, users blame the tool for failures caused by wrong OS version, no admin, no disk space, or pending reboots. | LOW | Check: Windows version/build (Win10 1809+ / Win11), admin elevation, internet connectivity, free disk space (≥4 GB for payloads), pending reboot flag, battery/AC power (laptops). Surface results as a checklist panel before the install button is enabled. |
| Restore-point creation before destructive stages | The flow disables Defender, UAC, memory integrity, VBS, and wipes GPU drivers. If anything goes wrong, the user needs a way back. Windows installers create restore points; NTLite prompts for one; DDU can create one (`-createsystemrestorepoint`). Without this, users will not run the tool. | LOW | Use `Checkpoint-Computer` or `Enable-ComputerRestore` + `WmiRestorePoint`. Create before Stage 1 (first destructive action). Show confirmation that the restore point was created. |
| Clear stage/step progress indication | The flow has 3 stages with 2 reboots. Users need to know where they are. Windows Setup shows "Step 1 of 3" / "Installing Windows"; Calamares shows a progress bar with stage labels; NTLite shows a progress log. Without this, users think it's frozen and hard-reset. | MEDIUM | Show "Step N of 3" prominently. Per-stage progress bar. Current action text (e.g., "Installing 7-Zip...", "Removing Edge..."). Status bar at bottom. Progress must persist across reboots. |
| Resumability across reboots | The flow reboots twice (Safe Mode + normal boot). If the GUI doesn't come back automatically, the user has to manually relaunch and figure out where they were. Windows Setup uses `SetupPhase` registry keys; NTLite uses RunOnce; WinUtil doesn't handle reboots (single-stage). This is the #1 table-stakes feature for this tool. | HIGH | Persist current stage + state to a file or registry key before each reboot. On launch, check for in-progress state and auto-resume. Use RunOnce to relaunch the GUI after reboot. Show "Resuming Step 2 of 3..." on launch. |
| Cancel/abort behavior | Users need a way to stop if something looks wrong. Windows Setup has no cancel after a point; Calamares has no cancel during install; NTLite has no cancel during apply. But users expect a cancel button. The key is: cancel must be safe (not leave the system half-modified). | MEDIUM | Cancel button available during Stage 1 (before reboot). After reboot, cancel is disabled (system is in a transitional state). If user cancels mid-stage, offer to roll back to restore point. Never allow cancel during Safe Mode stage. |
| Logging | When something fails, users need to see what happened. Windows Setup logs to `C:\Windows\Panther`; Calamares logs to `/var/log/installation.log`; NTLite has a log window; WinUtil has no logging. Without logs, support is impossible. | LOW | Write a timestamped log file to `%ProgramData%\AkariOS\install.log`. Capture all PowerShell output, registry changes, download status, errors. Show log viewer in the UI. |
| Error surfacing | If a stage fails, the user needs to know immediately, not after the next reboot. Windows Setup shows error codes; NTLite shows error dialogs; Calamares shows error notifications. Silent failures are unacceptable for a destructive tool. | MEDIUM | Catch errors in each stage. Show error dialog with details + log excerpt. Offer retry or abort. If a stage fails before reboot, allow retry. If after reboot, show recovery options. |
| Final "what changed / how to undo" summary | After a 3-stage install that modifies hundreds of registry keys, removes apps, and changes drivers, users need a summary. Windows Setup shows a "Getting ready" screen; Calamares shows a finish page; NTLite shows a summary. Without this, users don't know what was done. | LOW | Post-install summary screen: list of apps removed, features disabled, drivers wiped, power plan applied, branding changes. Link to restore point. Link to log file. |
| Confirmation gate before destructive stages | The flow is destructive by nature. Users must explicitly confirm. O&O ShutUp10 shows recommendation levels; NTLite shows a summary of changes; Windows Setup shows license agreement. A typed acknowledgment is stronger than a checkbox. | LOW | Before Stage 1: show what will be done, require typing "AKARIOS" to confirm. Before Stage 2 (Safe Mode): show warning about Defender/UAC disable. Before Stage 3: show warning about Edge removal. Each gate is a separate confirmation. |
| Admin elevation check | The tool modifies system-wide settings. Windows installers require admin; WinUtil requires admin; NTLite requires admin. Without admin, nothing works. | LOW | Check `IsInRole(Administrator)` on launch. If not elevated, prompt for UAC elevation. Show clear error if elevation fails. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Live per-action progress streaming from underlying scripts | WinSux scripts use `Write-Host` for stage labels but have no per-action progress. Streaming real-time progress to the GUI would make the install feel alive and reduce "is it stuck?" anxiety. Calamares does this with its progress bar; NTLite does this with its log window. | HIGH | Requires modifying WinSux scripts to emit structured progress (e.g., JSON lines or a progress file). The GUI tails the file and updates the UI. This is the biggest UX improvement possible. |
| Dry-run / preview mode | Let users see what will change before committing. NTLite shows a summary of changes; O&O ShutUp10 shows current vs. proposed state. For a destructive tool, this builds trust. | MEDIUM | Parse the WinSux scripts to extract intended changes (registry keys, apps to remove, features to disable). Show a preview panel. Does not execute anything. |
| Per-tweak opt-out | WinSux is all-or-nothing. Let users skip specific tweaks (e.g., "don't remove Edge", "don't disable Defender"). O&O ShutUp10 does this with individual toggles; WinUtil does this with categorized tweaks. | HIGH | Requires refactoring WinSux from monolithic scripts to modular functions. Each tweak becomes a toggle. The GUI shows a checklist. This is a significant architecture change. |
| Rollback / undo | Let users revert specific changes after install. O&O ShutUp10 has "Undo changes"; WinUtil has "Undo Selected Tweaks"; NTLite has no rollback. For a tool that disables security features, rollback is valuable. | HIGH | Requires snapshotting registry keys before modification. Store original values. Provide a rollback UI. This is complex because some changes (app removal) are not easily reversible. |
| Exportable logs | Let users share logs for support. Calamares copies logs to the target system; NTLite has export; WinUtil has no logs. For a power-user tool, this is expected. | LOW | Add "Export Log" button that copies the log file to a user-chosen location. Include system info (OS version, build, installed apps). |
| Offline mode | Let users run the install without internet (payloads pre-downloaded). NTLite works offline; WinUtil requires internet for winget. For environments with poor connectivity, this is valuable. | MEDIUM | Bundle payloads locally (7-Zip, VC++ redists, DDU, Helium, DirectX). Check for local files before downloading. Increases script size significantly. |
| Unattended / silent mode | Let users run the install with no interaction (for IT deployment). Windows Setup has unattended XML; NTLite has silent mode; Calamares has automated mode. For power users deploying to multiple machines, this is valuable. | LOW | Add a `--silent` flag that skips all confirmation gates (assumes pre-authorized). Requires a config file for tweak selection. Log everything. |
| "What will this do to my PC" explanation panel per stage | WinSux scripts are opaque. A plain-English explanation of what each stage does builds trust and helps users decide. O&O ShutUp10 does this with recommendation levels; NTLite does this with descriptions. | LOW | For each stage, show a panel: "Stage 2 will: disable Defender real-time protection, disable UAC, wipe GPU drivers. This reduces security but improves performance." |
| AkariOS branding / rebranding | The tool rebrands Windows as AkariOS (OEM info, logo, wallpaper). This is unique — no other tool does this. It's a differentiator but also a risk (users may not want it). | LOW | Set OEM info in registry (`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation`). Set custom wallpaper + lockscreen. Show branding in System Properties. Make it optional. |
| Per-stage individual run buttons | Let users run individual stages without the full flow. WinUtil does this with individual tweaks; NTLite does this with individual components. For power users who want to re-run a stage, this is valuable. | LOW | Each stage gets a "Run" button. Stage 1 runs winsux.ps1. Stage 2 runs stepone.ps1 (requires Safe Mode). Stage 3 runs steptwo.ps1. Show progress for each. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time registry monitoring | Users want to see every registry change as it happens. | WinSux makes hundreds of registry changes. Real-time monitoring would flood the UI and slow the install. | Log all changes to a file. Show a summary at the end. |
| Automatic driver installation after DDU | Users want the tool to install new drivers after wiping old ones. | Driver installation is hardware-specific. The tool would need to detect GPU/ audio hardware and download the correct driver. This is a separate tool's job. | After DDU, show a message: "Please install your GPU drivers from the manufacturer's website." Provide links. |
| Windows Update integration | Users want the tool to install Windows updates. | Windows Update is already built-in. Adding it creates conflicts with WinSux's update-disabling tweaks. | Let Windows Update run separately. The tool focuses on debloat + rebrand. |
| Telemetry dashboard | Users want to see what data Windows is collecting. | This is O&O ShutUp10's job. Adding it duplicates functionality and creates maintenance burden. | Link to O&O ShutUp10 as a companion tool. |
| Multi-language support | Users want the tool in their language. | WinSux scripts are English-only. Translating the UI requires maintaining multiple language files. The target audience (power users) is comfortable with English. | Ship English-only. Add language support later if demand exists. |
| GUI inside Safe Mode | Users want the full GUI experience during the Safe Mode stage. | WPF rendering in Safe Mode is unreliable (no DWM, limited drivers). WinSux already uses a console script for this reason. | Keep Stage 2 as a console script. Show a simple progress console. The GUI resumes in Stage 3. |
| Bundling all payloads locally | Users want a single file with no downloads. | Payloads (7-Zip, VC++ redists, DDU, Helium, DirectX) total ~500 MB. Bundling them makes the script huge and hard to update. | Download at runtime from FR33THY's releases. Cache downloads for re-use. |
| Reimplementing WinSux natively in C# | Users want a "real" compiled app. | The project constraint is a single self-contained `.ps1` file. Reimplementing in C# requires a build pipeline, dependencies, and maintenance. The WPF-via-PowerShell approach works and is proven. | Keep the WPF-via-PowerShell approach. Focus on the GUI and flow, not the engine. |
| Social features (share config, community presets) | Users want to share their tweak configurations. | This requires a backend, accounts, and moderation. It's a different product. | Let users export/import config files manually. No backend. |

## Feature Dependencies

```
[Resumability across reboots]
    └──requires──> [State persistence to file/registry]
                       └──requires──> [Pre-flight system checks]

[Live per-action progress streaming]
    └──requires──> [Structured progress output from WinSux scripts]
                       └──requires──> [Logging]

[Per-tweak opt-out]
    └──requires──> [Modular WinSux scripts]
                       └──requires──> [Dry-run / preview mode]

[Rollback / undo]
    └──requires──> [Registry snapshot before modification]
                       └──requires──> [Logging]

[Confirmation gate before destructive stages]
    └──requires──> [Restore-point creation]

[Final "what changed" summary]
    └──requires──> [Logging]

[Exportable logs]
    └──requires──> [Logging]

[Unattended / silent mode]
    └──requires──> [Per-tweak opt-out]
    └──requires──> [Logging]

[Live per-action progress streaming] ──enhances──> [Clear stage/step progress indication]

[Per-tweak opt-out] ──conflicts──> [Unattended / silent mode] (silent mode assumes all tweaks selected)
```

### Dependency Notes

- **Resumability requires state persistence:** The GUI must write the current stage + state to a file or registry key before each reboot. On launch, it checks for this state and auto-resumes. Without persistence, resumability is impossible.
- **Live progress streaming requires structured output:** WinSux scripts currently use `Write-Host` for stage labels. To stream per-action progress, the scripts must emit structured output (e.g., JSON lines or a progress file). This requires modifying WinSux.
- **Per-tweak opt-out requires modular scripts:** WinSux is currently monolithic. To allow opt-out, the scripts must be refactored into modular functions. This is a significant architecture change.
- **Rollback requires registry snapshots:** To undo changes, the tool must snapshot registry keys before modification. This requires knowing which keys will be modified, which requires parsing the scripts.
- **Confirmation gate requires restore point:** The confirmation gate is only meaningful if there's a way to undo. The restore point is that way.
- **Final summary requires logging:** The "what changed" summary is only possible if all changes are logged.
- **Exportable logs require logging:** Export is only possible if logs exist.
- **Silent mode requires per-tweak opt-out:** Silent mode assumes all tweaks are selected. If the user wants to skip some, they need the opt-out UI.
- **Live progress enhances progress indication:** Live progress makes the progress bar more accurate and reduces anxiety.
- **Per-tweak opt-out conflicts with silent mode:** Silent mode assumes all tweaks. If the user wants to skip some, they need the UI. These are incompatible unless silent mode accepts a config file.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Pre-flight system checks — verify environment before install
- [ ] Restore-point creation before Stage 1 — safety net for destructive changes
- [ ] Clear stage/step progress indication — "Step N of 3" + progress bar + current action
- [ ] Resumability across reboots — persist state, auto-resume after each reboot
- [ ] Cancel/abort behavior — cancel button during Stage 1, disabled after reboot
- [ ] Logging — timestamped log file with all actions and errors
- [ ] Error surfacing — error dialog with details + log excerpt
- [ ] Final "what changed" summary — post-install summary screen
- [ ] Confirmation gate before destructive stages — typed acknowledgment
- [ ] Admin elevation check — prompt for UAC if not elevated
- [ ] Single-click "Install AkariOS" — runs the full 3-stage flow
- [ ] Per-stage individual run buttons — power-user path
- [ ] AkariOS branding — OEM info, wallpaper, system branding

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Live per-action progress streaming — when WinSux scripts emit structured output
- [ ] Dry-run / preview mode — when users ask "what will this do?"
- [ ] Exportable logs — when users ask for support
- [ ] "What will this do to my PC" explanation panel — when users ask for clarity
- [ ] Offline mode — when users report connectivity issues

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Per-tweak opt-out — requires modular WinSux scripts, significant architecture change
- [ ] Rollback / undo — requires registry snapshots, complex
- [ ] Unattended / silent mode — requires per-tweak opt-out first
- [ ] Automatic driver installation — separate tool's job
- [ ] Telemetry dashboard — O&O ShutUp10's job
- [ ] Multi-language support — maintenance burden, limited demand
- [ ] Social features — different product

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Pre-flight system checks | HIGH | LOW | P1 |
| Restore-point creation | HIGH | LOW | P1 |
| Clear stage/step progress indication | HIGH | MEDIUM | P1 |
| Resumability across reboots | HIGH | HIGH | P1 |
| Cancel/abort behavior | MEDIUM | MEDIUM | P1 |
| Logging | HIGH | LOW | P1 |
| Error surfacing | HIGH | MEDIUM | P1 |
| Final "what changed" summary | MEDIUM | LOW | P1 |
| Confirmation gate before destructive stages | HIGH | LOW | P1 |
| Admin elevation check | HIGH | LOW | P1 |
| Single-click "Install AkariOS" | HIGH | LOW | P1 |
| Per-stage individual run buttons | MEDIUM | LOW | P1 |
| AkariOS branding | MEDIUM | LOW | P1 |
| Live per-action progress streaming | HIGH | HIGH | P2 |
| Dry-run / preview mode | MEDIUM | MEDIUM | P2 |
| Exportable logs | MEDIUM | LOW | P2 |
| "What will this do" explanation panel | MEDIUM | LOW | P2 |
| Offline mode | MEDIUM | MEDIUM | P2 |
| Per-tweak opt-out | HIGH | HIGH | P3 |
| Rollback / undo | HIGH | HIGH | P3 |
| Unattended / silent mode | MEDIUM | LOW | P3 |
| Automatic driver installation | LOW | HIGH | P3 |
| Telemetry dashboard | LOW | HIGH | P3 |
| Multi-language support | LOW | MEDIUM | P3 |
| Social features | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | NTLite | WinUtil | O&O ShutUp10 | Windows Setup | Calamares (Linux) | Our Approach |
|---------|--------|---------|--------------|---------------|-------------------|--------------|
| Pre-flight checks | Checks image compatibility, Windows version | Checks admin rights | Checks Windows version/edition | Checks hardware, disk space, compatibility | Checks hardware, disk space | Check Windows version/build, admin, internet, disk space, pending reboots, battery |
| Restore point | Prompts before apply | No | No (but has backup/restore of settings) | Creates restore point automatically | No | Create before Stage 1, confirm to user |
| Progress indication | Progress log window | Tab-based, no progress bar | Toggle-based, no progress | "Step N of 3" + progress bar | Progress bar + stage labels | "Step N of 3" + progress bar + current action + status bar |
| Resumability | RunOnce for reboot | No (single-stage) | No (single-stage) | SetupPhase registry keys, RunOnce | No (single-stage) | Persist state to file, auto-resume via RunOnce |
| Cancel/abort | No cancel during apply | No cancel | No cancel | No cancel after point | No cancel during install | Cancel during Stage 1, disabled after reboot |
| Logging | Log window | No logging | No logging | C:\Windows\Panther logs | /var/log/installation.log | %ProgramData%\AkariOS\install.log |
| Error surfacing | Error dialogs | Console errors | No errors (non-destructive) | Error codes + logs | Error notifications | Error dialog + log excerpt + retry/abort |
| Final summary | Summary of changes | No summary | No summary | "Getting ready" screen | Finish page | Summary of changes + restore point link + log link |
| Confirmation gate | Summary of changes | No gate | Recommendation levels | License agreement | Summary + confirm | Typed acknowledgment per stage |
| Admin elevation | Required | Required | Required for HKLM | Required | Required | Required, prompt for UAC |
| Live progress | Log window | N/A | N/A | Progress bar | Progress bar | Stage labels (v1), per-action streaming (v2) |
| Dry-run / preview | Summary of changes | N/A | Current vs. proposed state | N/A | Summary of changes | Preview panel (v2) |
| Per-tweak opt-out | Individual components | Individual tweaks | Individual settings | N/A | N/A | Modular scripts (v3) |
| Rollback / undo | No | "Undo Selected Tweaks" | "Undo changes" | No | No | Registry snapshots (v3) |
| Exportable logs | Export log | N/A | N/A | N/A | Copy log | Export log (v2) |
| Offline mode | Yes (image-based) | No (winget) | Yes | No (requires internet for updates) | Yes | Local payloads (v2) |
| Unattended / silent | Silent mode | N/A | N/A | Unattended XML | Automated mode | --silent flag (v3) |
| Rebranding | No | No | No | No | No | OEM info + wallpaper (v1) |

## Sources

**Competitor products analyzed:**
- NTLite — Windows image configuration tool. Features: live editing of running Windows, apply with reboot, component removal, summary of changes, log window. Source: ntlite.com/features, ntlite.org/docs.html
- Chris Titus Tech WinUtil — PowerShell-based Windows debloat toolkit. Features: multi-tab GUI, categorized tweaks, presets, undo selected tweaks, bulk app install. Source: github.com/ChrisTitusTech/winutil, winutil.christitus.com/guides
- O&O ShutUp10 — Windows privacy configuration tool. Features: ~300 settings, traffic-light toggles, recommendation levels, undo changes, backup/restore. Source: manuals.oo-software.com/ooshutup10
- Windows Setup / OOBE — Microsoft's Windows installer. Features: SetupPhase registry keys, RunOnce, progress bar, "Step N of 3", Panther logs. Source: learn.microsoft.com, joymalya.com/modern-windows-provisioning-internals
- Calamares — Linux distribution-independent installer. Features: progress bar with stage labels, slideshow, finish page, installation.log. Source: calamares.io/docs/install, calamares.io/docs/finish
- DDU (Display Driver Uninstaller) — GPU driver removal tool. Features: Safe Mode operation, clean and restart, -silent flag, -createsystemrestorepoint. Source: wagnardsoft.com, gamerhardware.org

**Industry standards referenced:**
- Windows Installer (MSI) — RunOnce registry key for reboot resume. Source: devblogs.microsoft.com/oldnewthing, advancedInstaller.com
- InstallAware — Reboot and Resume command. Source: installaware.com/mh52/desktop/rebootandresume.htm
- Unattended (SourceForge) — .reboot directive for multi-stage install. Source: unattended.sourceforge.net/apps.php

**Key findings on reboot-resume patterns:**
- Windows Setup uses `HKLM\SYSTEM\Setup\SetupPhase` (0-6) and `SystemSetupInProgress` to track state across reboots. Winlogon defers logon and executes `CmdLine` when setup is in progress.
- NTLite uses RunOnce to relaunch itself after a reboot. The user sees the GUI come back automatically.
- InstallAware's "Reboot and Resume" writes to RunOnce and restarts the installation from the beginning (not from where it left off).
- Unattended's `.reboot` directive patches the registry to cause itself to run on next logon, providing a controlled, synchronous reboot-and-resume mechanism.
- DDU uses `-restart` flag to reboot after cleaning, and the user manually relaunches the next step.
- Calamares does not handle reboots (single-stage install). It shows a finish page and lets the user reboot manually.

**Key findings on progress indication:**
- Windows Setup shows "Step N of 3" + progress bar + "Getting things ready" / "This might take a few minutes".
- Calamares shows a progress bar with stage labels (e.g., "Copying files", "Creating users", "Installing bootloader").
- NTLite shows a log window with real-time output.
- WinUtil shows no progress (tweaks are fast).
- O&O ShutUp10 shows no progress (toggles are instant).

**Key findings on confirmation gating:**
- Windows Setup shows license agreement + "Install Now" button.
- Calamares shows a summary of changes + "Install" button.
- NTLite shows a summary of changes + "Apply" button.
- O&O ShutUp10 shows recommendation levels (green/yellow/red) per setting.
- WinUtil has no confirmation gate (tweaks are applied immediately).

**Key findings on error handling:**
- Windows Setup shows error codes + logs to C:\Windows\Panther.
- Calamares shows error notifications + logs to /var/log/installation.log.
- NTLite shows error dialogs + log window.
- WinUtil shows console errors.
- O&O ShutUp10 shows no errors (non-destructive).

---
*Feature research for: Multi-stage Windows installer/setup GUI (AkariOS)*
*Researched: 2026-10-04*
