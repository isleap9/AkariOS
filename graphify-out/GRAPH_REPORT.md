# Graph Report - AkariOS  (2026-10-22)

## Corpus Check
- Large corpus: 371 files · ~828,415 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 868 nodes · 1355 edges · 258 communities (36 shown, 222 thin omitted)
- Extraction: 58% EXTRACTED · 42% INFERRED · 0% AMBIGUOUS · INFERRED: 567 edges (avg confidence: 0.85)
- Token cost: 364,884 input · 0 output

## Community Hubs (Navigation)
- Main Window XAML Shell
- Apps Step UI
- Entry Point and Phased Runs
- Restore Points and Legacy Rows
- Timer Resolution Service (C#)
- App Install Helpers
- Logging and Compat Shims
- Appx, Features, Winget
- Tweak Loader and State
- Controls XAML Styles
- Registry Engine and Runner
- Self-Update and About
- System and Hardware Helpers
- Real-User Paths and Folders
- Registry Reads and GPU Tweaks
- Plan: Guided UX and Presets
- Browser Installs and Updaters
- Glossary: Tweak Kinds
- M1 Engine Plan
- Runs, Phases, Outcomes
- Plan Docs and Milestones
- CLI and Run Outcomes
- Legacy Freeze and Optimize
- Tweak Format and Defaults
- Credits and Upstream Sources
- Release Workflow
- Start Pins and One-click Files
- M3 Port Batches
- Roadmap and Distribution
- Game Launcher Installs
- Agent Guide and Session Notes
- Revert to Windows Default
- Win11Debloat-style UI
- Legacy Frozen (ADR 0004)
- One-click Architecture
- AkariOS Wallpaper
- Core Layer Rules
- AkariOS Logo
- Console Banner
- Testing Rules
- Visible elevated console (live log)
- Apply
- Requirement (Win11, NVIDIA, Desktop...)
- Risk (Safe / Caution / Advanced)
- Section (Optimize, Customize, Hardware, 
- State (Optimized / Default / Custom / Un

## God Nodes (most connected - your core abstractions)
1. `Window` - 43 edges
2. `Set-Reg()` - 40 edges
3. `Get-AkariRegValue()` - 33 edges
4. `Remove-Reg()` - 26 edges
5. `Resolve-AkariRegPath()` - 25 edges
6. `Write-Log()` - 23 edges
7. `Invoke-AkariTweak()` - 23 edges
8. `WindowsService` - 21 edges
9. `Get-AkariState()` - 19 edges
10. `Get-AkariUserFolder()` - 18 edges

## Surprising Connections (you probably didn't know these)
- `Set-AkariDesktopWallpaper()` --shares_data_with--> `AkariOS Desktop Wallpaper (img.jpg)`  [INFERRED]
  Core/System.ps1 → OneClick/img.jpg
- `OneClick/start2.txt (encoded Start menu pins layout)` --semantically_similar_to--> `Tweaks/Customize/Start/Files/start2.txt (Start layout copy)`  [INFERRED] [semantically similar]
  OneClick/start2.txt → Tweaks/Customize/Start/Files/start2.txt
- `Get-AkariAppsView()` --calls--> `Get-AkariAppxPackages()`  [INFERRED]
  UI/Apps.ps1 → Core/Appx.ps1
- `Get-AkariAppsView()` --calls--> `Get-AkariAppxInstalled()`  [INFERRED]
  UI/Apps.ps1 → Core/Appx.ps1
- `Invoke-AkariOneClick()` --calls--> `Write-Host()`  [INFERRED]
  OneClick/OneClick.ps1 → Core/Compat.ps1

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M1 Core engine modules (Registry, Loader, State, Runner, Compat)** — docs_plans_2026_10_17_m1_engine_registry_helpers, docs_plans_2026_10_17_m1_engine_loader, docs_plans_2026_10_17_m1_engine_state, docs_plans_2026_10_17_m1_engine_runner, docs_plans_2026_10_17_m1_engine_compat_shims [EXTRACTED 1.00]
- **Guided choose → review → apply flow** — docs_plans_2026_10_19_m2a_manual_steps_selection, docs_plans_2026_10_19_m2a_manual_steps_cards, docs_plans_2026_10_19_m2a_manual_steps_steps, docs_plans_2026_10_19_m2a_manual_steps_apply_from_review, docs_plans_2026_10_19_m2a_manual_steps_restore_helper, docs_plans_2026_10_19_m2a_manual_steps_run_plan [EXTRACTED 1.00]
- **Upstream inspiration projects** — akarios_plan_zoicware, akarios_plan_win11debloat, akarios_plan_winhance, akarios_plan_winsux_ultimate, akarios_plan_winutil [EXTRACTED 1.00]
- **Release and self-update pipeline (version → tag → zip → updater)** — agents_version, _github_workflows_release_build_the_zip, _github_workflows_release_akarios_zip, agents_update, next_session_releasing_procedure [INFERRED 0.85]
- **Tweak kinds (Toggle, Choice, Action, Group/Entry)** — glossary_tweak, glossary_toggle, glossary_choice, glossary_action, glossary_group, glossary_entry [EXTRACTED 1.00]
- **Legacy freeze mechanism (ADR, Ported map, id fixture)** — docs_adr_0004_legacy_frozen, agents_legacy_tweaks, agents_ported_psd1, tests_fixtures_legacy_ids, glossary_legacy [EXTRACTED 1.00]

## Communities (258 total, 222 thin omitted)

### Community 0 - "Main Window XAML Shell"
Cohesion: 0.05
Nodes (57): Text, AboutLink, AppVersion, B, Bar, Body, C, CapClose (+49 more)

### Community 1 - "Apps Step UI"
Cohesion: 0.09
Nodes (50): Add-AkariAppRows(), Clear-AkariInstalls(), Complete-AkariFeatureRead(), Get-AkariAppSource(), Get-AkariAppsView(), Get-AkariFoundList(), Get-AkariInstallCards(), Get-AkariInstallList() (+42 more)

### Community 2 - "Entry Point and Phased Runs"
Cohesion: 0.10
Nodes (36): Import-AkariLegacyTweaks(), Write-ErrLog(), Clear-AkariRun(), Get-AkariResumeCommand(), Get-AkariRun(), Get-AkariRunTweaks(), Invoke-AkariBcdEdit(), New-AkariPresetRun() (+28 more)

### Community 3 - "Restore Points and Legacy Rows"
Cohesion: 0.10
Nodes (40): Get-AkariRestorePoint(), Invoke-AkariCheckpoint(), New-AkariRestorePoint(), Add-AkariRestoreFirst(), New-Row(), Update-Row(), Add-Log(), Confirm-Run() (+32 more)

### Community 4 - "Timer Resolution Service (C#)"
Cohesion: 0.08
Nodes (4): WindowsService, OnProcessStart, WindowsService, WindowsServiceInstaller

### Community 5 - "App Install Helpers"
Cohesion: 0.09
Nodes (10): Get-AkariMsi(), Get-AkariWingetExe(), Import-AkariAppSettings(), Import-AkariRegText(), Invoke-AkariRegExe(), Invoke-AkariSelfUninstall(), New-AkariShortcut(), Save-AkariFile() (+2 more)

### Community 6 - "Logging and Compat Shims"
Cohesion: 0.15
Nodes (12): Clear-Host(), Get-FilePath(), Get-FolderPath(), Pause(), Read-Host(), show-menu(), Write-Host(), Add-Tweak() (+4 more)

### Community 7 - "Appx, Features, Winget"
Cohesion: 0.14
Nodes (16): Get-AkariAppxInstalled(), Get-AkariAppxPackages(), Get-AkariCapabilitiesInstalled(), Get-AkariFeaturesEnabled(), Remove-AkariAppx(), Test-AkariAppxInstalled(), Test-AkariAppxNever(), Get-AkariWingetPath() (+8 more)

### Community 8 - "Tweak Loader and State"
Cohesion: 0.14
Nodes (18): ConvertTo-AkariTweak(), Find-AkariRegistryOwner(), Get-AkariEntryRow(), Get-AkariPorted(), Get-AkariTweaks(), Import-AkariTweakFile(), New-AkariEntry(), Resolve-AkariEntry() (+10 more)

### Community 9 - "Controls XAML Styles"
Cohesion: 0.10
Nodes (22): ActualWidth, IsDropDownOpen, B, Bar, Box, Field, L, PART_EditableTextBox (+14 more)

### Community 10 - "Registry Engine and Runner"
Cohesion: 0.20
Nodes (12): Get-AkariRegistryState(), Get-AkariRegKey(), Invoke-AkariRegistry(), Resolve-AkariDefault(), Test-AkariKeyRow(), Test-AkariRegMatch(), Invoke-AkariTweak(), Get-AkariState() (+4 more)

### Community 11 - "Self-Update and About"
Cohesion: 0.20
Nodes (17): ConvertTo-AkariNotesText(), Get-AkariLatestRelease(), Get-AkariUpdateStatus(), Install-AkariUpdate(), Invoke-AkariGitHubApi(), Remove-AkariUpdateLeftover(), Save-AkariUpdateFile(), Start-AkariUpdater() (+9 more)

### Community 12 - "System and Hardware Helpers"
Cohesion: 0.15
Nodes (9): Get-AkariChassis(), Get-AkariGpus(), Get-AkariOSBuild(), Grant-AkariOwnership(), Invoke-AkariPowerCfg(), Read-AkariBcd(), Restart-AkariExplorer(), Set-AkariScheduledTask() (+1 more)

### Community 13 - "Real-User Paths and Folders"
Cohesion: 0.13
Nodes (3): Get-AkariUserFolder(), Get-AkariUserSid(), Resolve-AkariRegPath()

### Community 14 - "Registry Reads and GPU Tweaks"
Cohesion: 0.19
Nodes (3): Get-AkariRegValue(), Remove-Reg(), Get-AkariGpuDevices()

### Community 15 - "Plan: Guided UX and Presets"
Cohesion: 0.19
Nodes (12): AkariOS (single PowerShell debloat/optimize app), Data-list Groups (ADR 0002), Guided flow (Apps → Tweaks → Review & Apply), Presets (JSON, Phases, wildcards, Default revert), Quick select (AkariOS, Last used, user presets), Win11Debloat (Raphire; checklist, revertible, CLI), Zoicware (inspiration: configs, all-in-one), UI/Cards.ps1 setting cards (+4 more)

### Community 16 - "Browser Installs and Updaters"
Cohesion: 0.21
Nodes (4): Remove-AkariService(), Remove-AkariUpdaters(), Set-Reg(), Invoke-AkariCsc()

### Community 17 - "Glossary: Tweak Kinds"
Cohesion: 0.20
Nodes (9): Core/Loader.ps1 (Get-AkariTweaks, one owner per registry value), Tweaks/Ported.psd1 (legacy id → one-file ids), Action (one-shot, no revert), Choice (multi-value, Default + Recommended), Entry (<group-id>/<name>), Group (bundles Entries, no nesting), Toggle, Tweak (Toggle, Choice, Action or Group; kebab-case id) (+1 more)

### Community 18 - "M1 Engine Plan"
Cohesion: 0.22
Nodes (8): Tweak State (Optimized / Default / Custom / Unknown), Core/Compat.ps1 shims (Write-Host, Pause, Read-Host), Core extraction from Akari.ps1 into dot-sourced files, Core/Loader.ps1 (Get-AkariTweaks, Import-AkariTweakFile), Core/Registry.ps1 (Resolve-AkariRegPath, Get-AkariRegistryState), Core/State.ps1 (Get-AkariState, remembered state.json), SvcHostSplitThreshold Choice (replaces tuner), Split Akari.ps1 into UI files; remove tuners

### Community 19 - "Runs, Phases, Outcomes"
Cohesion: 0.25
Nodes (9): Akari.ps1 entry point (Resume / OneClick / CLI / GUI branches), Core/Phases.ps1 (Runs in phases across restarts, run.json, -Resume), Core/Presets.ps1 (Read/Resolve/Save presets, Last used), Core/Runner.ps1 (Invoke-AkariTweak / Plan / Run → Outcomes), Outcome (Applied/Reverted/Already/Skipped/Failed), Phase (Normal or Safe Mode boot, reboot between), Preset (built-in or user list of Tweak ids), Run (one engine call with Tweak ids) (+1 more)

### Community 20 - "Plan Docs and Milestones"
Cohesion: 0.31
Nodes (8): AkariOS Project Plan, Migration steps (§11), _ref/ local reference projects, Winhance (PolyForm Shield; ideas and layout only), M1: Engine Implementation Plan, Pester 3.4 test harness (Tests/Run.ps1), M2a: Manual steps Implementation Plan, M3: Optimize chooser, port of 6 Windows, Presets

### Community 21 - "CLI and Run Outcomes"
Cohesion: 0.25
Nodes (8): CLI modes (-List, -Apply, -Revert, -Preset), Run summary Outcomes (Applied/Reverted/Already/Skipped/Failed), CLI -List/-Apply/-Revert with three sample tweaks, Core/Runner.ps1 (Invoke-AkariTweak, Invoke-AkariRun, Start-AkariJob), Sample tweaks: disable-game-dvr, disable-memory-compression, win32-priority-separation, Apply from Review (one Run, restore point first), Core/Restore.ps1 New-AkariRestorePoint, Run plan with Choice values (Invoke-AkariPlan, Shared job results)

### Community 22 - "Legacy Freeze and Optimize"
Cohesion: 0.32
Nodes (7): AkariOS-Ultimate (script menu + GUI), Downloads flow (Install cards alone), Home (Install AkariOS / Optimize / Downloads / Import-Export tiles), Optimize › Legacy (frozen Ultimate pages, ADR 0004), Add-Tweak adapter (Core/Legacy.ps1), Optimize chooser (Legacy / Advanced cards), Tweaks/Ported.psd1 (legacy id → one-file ids)

### Community 23 - "Tweak Format and Defaults"
Cohesion: 0.29
Nodes (6): Requires field (Win10/Win11/Laptop/Desktop), Tweak file format (hashtable .ps1), Tweak kinds (Toggle / Choice / Action / Group), Engine prep (Requires, Explorer restart, key rows, Binary, powercfg wrapper), Explorer restarts once per Run, Batch 3: Power, Performance, Network

### Community 24 - "Credits and Upstream Sources"
Cohesion: 0.25
Nodes (8): CREDITS.md (upstream sources per ported Tweak), Display Driver Uninstaller (Wagnardsoft), FR33THY Ultimate (upstream, via AkariOS-Ultimate), FR33THY WinSux (base of Akari-OS), isleap9/Akari-OS (akarios.ps1, stepone.ps1, steptwo.ps1), NVIDIA Profile Inspector (Orbmu2k), winget (microsoft/winget-cli) app install source, priority-notifications.txt (quiet hours priority-only profile Data blob)

### Community 25 - "Release Workflow"
Cohesion: 0.38
Nodes (7): release.yml (Release workflow), AkariOS-<version>.zip release asset, Build the zip step (tag must equal $AkariVersion), Publish the release step (gh release create, notes from annotated tag), Core/Update.ps1 (GitHub Releases self-update, SHA-256 check), Core/Version.ps1 ($AkariVersion SemVer), Releasing procedure (bump $AkariVersion, annotated tag v<ver>, push)

### Community 26 - "Start Pins and One-click Files"
Cohesion: 0.29
Nodes (7): Presets/AkariOS.json (built-in AkariOS preset), OneClick/ folder (reg.reg, start2.txt, old phase scripts), One-click mode (prep → Safe Mode → tweaks, reboots handled), New Text Document.txt (scratch Start-pins diagnostics script), ConfigureStartPins policy experiment (PolicyManager Start, start2.bin), OneClick/start2.txt (encoded Start menu pins layout), Tweaks/Customize/Start/Files/start2.txt (Start layout copy)

### Community 27 - "M3 Port Batches"
Cohesion: 0.29
Nodes (6): Presets/AkariOS.json, WinSux / Ultimate (FR33THY tweak content), AkariOS = $true marks (checked vs reg.reg), Batch 1: Customize (Taskbar, Start, Explorer, Theme), Batch 2: Optimize registry (Privacy, Gaming, Notifications, Update), UserPreferencesMask written as text bug (reg.reg)

### Community 28 - "Roadmap and Distribution"
Cohesion: 0.29
Nodes (7): Distribution: Build/Bundle.ps1 single-file release, M4: One-click via preset Phases, M5: Apps + Config (Import/Export), M6: Release (bundle, archive old repos), Roadmap M1–M7, Releases and self-update (Core/Update.ps1, SHA-256 digest), winutil (Chris Titus; many files bundled into one)

### Community 30 - "Agent Guide and Session Notes"
Cohesion: 0.50
Nodes (5): AGENTS.md (agent guide), GLOSSARY.md (AkariOS domain vocabulary), next session.txt (session handoff notes and roadmap), PowerShell 5.1 traps (case-insensitive vars, @() flattening, .Count on single object, psd1 BOM), UI visual fixes V1-V6 (loader warnings to log, About link, title bar, dark dialog)

### Community 31 - "Revert to Windows Default"
Cohesion: 0.40
Nodes (4): One-file tweaks (Tweaks/<Section>/<Category>/*.ps1), Default (stock Windows value), Restore point (described AkariOS, before first change), Revert (back to Default)

### Community 32 - "Win11Debloat-style UI"
Cohesion: 0.40
Nodes (4): UI/ layer (Selection, Cards, Apps, Steps, Shell, About, XAML), Raphire Win11Debloat (MIT; app list and UI model), Guided flow (Apps → Tweaks → Review & Apply, Win11Debloat checkbox model), Optimize chooser (Legacy pages / Advanced coming later)

### Community 33 - "Legacy Frozen (ADR 0004)"
Cohesion: 0.83
Nodes (3): Legacy tweaks (Tweaks/*.ps1, Core/Legacy.ps1, Compat.ps1; frozen), Legacy (frozen AkariOS-Ultimate tweaks), Tests/Fixtures/legacy-ids.txt (every Legacy id; none may disappear)

### Community 34 - "One-click Architecture"
Cohesion: 0.50
Nodes (4): Akari-OS (old one-click, WinSux-based), Architecture: Akari.ps1 → Loader → Tweaks; UI + Runner → Phases, One-click mode (prep → Safe Mode → tweaks), Run in phases (Safe Mode, RunOnce resume, saved SID)

### Community 35 - "AkariOS Wallpaper"
Cohesion: 0.67
Nodes (3): Set-AkariDesktopWallpaper(), AkariOS 'A' Triangle Logo, AkariOS Desktop Wallpaper (img.jpg)

### Community 37 - "AkariOS Logo"
Cohesion: 0.67
Nodes (3): AkariOS, Stylized 'A' Monogram Mark, AkariOS Logo (AkariLogo.png)

## Knowledge Gaps
- **57 isolated node(s):** `Rectangle`, `Ellipse`, `ToggleButton`, `IsDropDownOpen`, `ContentPresenter` (+52 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 346 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **222 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Write-Log()` connect `Logging and Compat Shims` to `Entry Point and Phased Runs`, `Restore Points and Legacy Rows`, `App Install Helpers`, `Appx, Features, Winget`, `Registry Engine and Runner`, `System and Hardware Helpers`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **Are the 37 inferred relationships involving `Set-Reg()` (e.g. with `Register-AkariResume()` and `New-AkariRestorePoint()`) actually correct?**
  _`Set-Reg()` has 37 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Rectangle`, `Ellipse`, `ToggleButton` to the rest of the system?**
  _57 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Main Window XAML Shell` be split into smaller, more focused modules?**
  _Cohesion score 0.050816696914700546 - nodes in this community are weakly interconnected._
- **Why does `Test-AkariRequirement()` connect `System and Hardware Helpers` to `Apps Step UI`, `Entry Point and Phased Runs`, `Registry Engine and Runner`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Are the 29 inferred relationships involving `Get-AkariRegValue()` (e.g. with `New-AkariRestorePoint()` and `Invoke-AkariTweak()`) actually correct?**
  _`Get-AkariRegValue()` has 29 INFERRED edges - model-reasoned connections that need verification._
- **Should `Apps Step UI` be split into smaller, more focused modules?**
  _Cohesion score 0.08636363636363636 - nodes in this community are weakly interconnected._