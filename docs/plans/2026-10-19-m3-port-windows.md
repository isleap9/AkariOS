# M3: Optimize chooser, port of 6 Windows, Presets

**Goal:** Turn Optimize into a chooser (frozen **Legacy** pages, **Advanced** later), add the engine pieces the port needs, port `6 Windows` from the old no-UI Ultimate into one-file tweaks (every Toggle revertible to the Windows Default, with `Detect`), then add Presets with Quick select and Last used, built on the new ids.

**Architecture:** Two tweak sets live side by side from now on. **Legacy** = the 7 generated `Tweaks/*.ps1` files through `Core/Legacy.ps1`, frozen: never edited by the port, never deleted, shown only on Optimize › Legacy (and in Guided until ported). **One-file tweaks** = `Tweaks/<Section>/<Category>/*.ps1`, used by Guided, Presets, the CLI and later Optimize › Advanced. `Tweaks/Ported.psd1` maps a legacy id to the one-file ids that fully replace it; Guided hides a legacy row once its id is there.

**Tech Stack:** Windows PowerShell 5.1, WPF, Pester 3.4.0.

**Spec:** `AkariOS-PLAN.md` §4, §7, §8, §11 step 3, §12 (M3, M5 rows); ADR 0001, 0002, 0003; `GLOSSARY.md`.

## Decisions (2026-10-19)

1. **Optimize = chooser** with two cards, like Install AkariOS: **Legacy** (the AkariOS-Ultimate pages as they are, buttons act right away) and **Advanced** (disabled, "Coming later"; designed in a later plan).
2. **Legacy is frozen** (new ADR 0004). Porting never edits or deletes a legacy entry; the `Add-Tweak` adapter and `Core/Compat.ps1` stay. This replaces §11 step 3's "delete the `Add-Tweak` entry once ported". Cost: the same setting has two implementations; the Legacy one is the safety net.
3. **Granularity: mixed.** What the user sees (each taskbar item, Start, Explorer, theme) = one Toggle each. Invisible plumbing (the 25 app permissions, ease of access, typing, sound scheme, ads) = one topic Toggle each, several `Registry` rows. About 100 files from `6 Windows`.
4. **Order:** chooser → engine prep → port in batches → Presets.
5. **Home spec cards: dropped** (code removed from `UI/Home.ps1`).
6. `1 Check`, `2 Refresh` and the "open this Settings page" Actions of `3 Setup` stay Legacy-only for now: nothing in Guided or a Preset needs them. Revisit with Advanced.

## Global Constraints

- Everything in the M1 and M2a plans' Global Constraints still holds.
- AGENTS.md rule 12: never launch the GUI or run the CLI with real ids on the developer's machine (the shell is elevated). Tests use fixtures, `HKCU:\Software\AkariTest\<guid>`, `TestDrive:`. Native or system-changing commands only through a PowerShell function the tests mock (`Restart-AkariExplorer`, `Invoke-AkariPowerCfg`, …), with `Assert-MockCalled`. One Context per Mock override (Pester 3 scope).
- Port source: `_ref/AkariOS-Ultimate old no UI/<folder>/<script>` (read only the script being ported). Never the generated `Tweaks/*.ps1`. Credit in `CREDITS.md`.
- **Default = stock Windows** (ADR 0001), taken from the script's Default branch and checked against a clean install; where Win10 and Win11 differ, use the per-OS map or `Requires`.
- **One owner per registry value:** a `(Path, Name)` appears in at most one one-file tweak (legacy excluded). Enforced by a test.
- Tweak blocks: cmdlet errors fail the tweak; add `-ErrorAction SilentlyContinue` where a failure is fine. Never `$ErrorActionPreference = 'Stop'` around native calls.
- Edit with Edit/Write (no heredoc/sed for backslash content). Keep CRLF where files have it.
- Every task ends with the test suite green (`powershell -NoProfile -ExecutionPolicy Bypass -File Tests\Run.ps1`) and a **VM check** list for the user.

## Review Focus

1. **Legacy untouched:** `git diff` of a port batch shows no change in `Tweaks/*.ps1` (top level), `Core/Legacy.ps1`, `Core/Compat.ps1`. A test loads the 7 real legacy files with zero Problems.
2. **Optimize › Legacy shows legacy only:** today the Optimize page also lists one-file tweaks of the Optimize Section (`UI/Shell.ps1` line 23); Legacy must not.
3. **Guided double rows:** a ported legacy id disappears from Guided only when `Ported.psd1` lists it, and a legacy id is listed only when every value it sets has a one-file owner.
4. **Win10 vs Win11:** Win11-only keys (`TaskbarAl`, `HideRecommendedSection`, FeatureManagement overrides) carry `Requires = 'Win11'`, Win10-only ones (`EnableAutoTray`) `Requires = 'Win10'`; unmet = hidden in Guided, `Skipped` in a Run.
5. **Explorer restarts once per Run**, at the end, only if a tweak with `Explorer = $true` was Applied or Reverted.
6. **HKCU → real user hive** for every new tweak (`Resolve-AkariRegPath`), including tweaks with `Apply` blocks.

---

### Task 1: Docs for the decisions

**Files:** `docs/adr/0004-legacy-frozen.md` (new), `docs/adr/0003-one-click-or-manual.md`, `AkariOS-PLAN.md` (§4 Optimize, §6 `Tweaks/Ported.psd1`, §7 fields `Requires` / `Explorer`, §11 step 3, §12), `GLOSSARY.md` (**Legacy**: the frozen AkariOS-Ultimate tweaks on Optimize › Legacy), `AGENTS.md` (`Core/Legacy.ps1` no longer "delete when the port is finished").

### Task 2: Optimize chooser, spec cards dropped

**Files:** `UI/Steps.ps1` (or `UI/Shell.ps1`, wherever the Install AkariOS chooser lives), `UI/Shell.ps1`, `UI/Home.ps1`, `Akari.ps1` (if it dot-sources Home for specs), tests.

```
 Optimize                                               ← Back
 ┌──────────────────────────────┐  ┌──────────────────────────────┐
 │  Legacy                      │  │  Advanced                    │
 │  The AkariOS-Ultimate pages: │  │  Coming later.               │
 │  Check, Refresh, Setup,      │  │                              │
 │  Graphics, Windows, Hardware,│  │                              │
 │  Advanced. Buttons act right │  │                              │
 │  away.                       │  │          (disabled)          │
 └──────────────────────────────┘  └──────────────────────────────┘
```
Layout decided 2026-10-20:
- **Chooser** = the Install AkariOS one: full window, no sidebar, two `New-AkariModeCard`s side by side, header "Optimize", footer Back → Home. **Legacy** card: "The AkariOS-Ultimate pages. Every button acts right away." **Advanced** card: greyed, "Coming later." (like the Import / Export tile).
- **Legacy view**: the sidebar holds only `← Optimize` (back to the chooser) and the legacy pages: Check, Refresh, Setup, Downloads, Graphics, Windows, Hardware, Advanced. Home, Install AkariOS and the `Manual` heading leave the sidebar (Home tiles reach them). Pages show **legacy tweaks only**: the sidebar `Optimize` page (one-file Optimize tweaks) goes, and the Advanced page loses the one-file Tuning Choices. Search covers legacy tweaks only.
- **Downloads** takes the old Installers slot: it opens the existing Downloads flow (full window). Opened from Legacy, its Back on the first step and Done lead back to Legacy; opened from Home, to Home. The legacy `Tweaks/Installers.ps1` (deleted in e94039d) stays deleted.
- Restore point rule unchanged (Optimize, first change of the session).
- Remove the spec read code and hidden cards from `UI/Home.ps1` (drop the file if nothing else is left), and the spec parts of `UI/Shell.ps1` (timer watchdog, `CopySpecs`, `Start-SpecRead`).

**VM check:** Optimize tile shows the two cards, Advanced greyed; Back → Home. Legacy opens Check with the sidebar `← Optimize`, Check … Advanced, Downloads in the fourth slot; no Home / Install AkariOS / Optimize items, no one-file tweaks on any page (Advanced has no Tuning Choices). `← Optimize` → chooser. Downloads from Legacy → Install cards; Back and Done return to Legacy. Downloads from Home → Back / Done return to Home. Search inside Legacy finds only legacy rows. A Legacy Optimize button still asks about / makes the restore point once.

### Task 3: Engine prep

**Files:** `Core/Loader.ps1`, `Core/Runner.ps1`, `Core/Registry.ps1`, `Core/Power.ps1` (new: `Invoke-AkariPowerCfg`), `Core/Explorer.ps1` or `Core/Phases.ps1` (`Restart-AkariExplorer`), `UI/Steps.ps1` (Guided filter), tests and fixtures.

- **`Requires`** (`Win10`, `Win11`, `Laptop`, `Desktop`): `Test-AkariRequirement <tweak>`; the Runner returns `Skipped` with the reason; Guided hides unmet tweaks. OS / chassis reads behind one function each (tests mock them).
- **`Explorer = $true`:** the Run calls `Restart-AkariExplorer` once at the end if such a tweak was Applied or Reverted.
- **Registry rows:** a row with `Name` omitted and `Value = $null` deletes the whole key on Apply (Default `'Key'` recreates it empty, or keep the key rows' Defaults explicit: decide in the task, test both); `Binary` values (`[byte[]]`) write and Detect correctly.
- **`Invoke-AkariPowerCfg <args>`**: the only powercfg call; returns stdout; tests mock it.
- **`Tweaks/Ported.psd1`**: `@{ '<legacy-id>' = @('<new-id>', …) }`. Loader reads it, reports a Problem for unknown ids on either side; Guided drops legacy rows listed there.
- **Ownership test:** no `(Path, Name)` in two one-file tweaks.
- **Legacy smoke test:** the 7 real `Tweaks/*.ps1` load with zero Problems.

**VM check:** none visible yet beyond Guided still listing everything (no tweak uses the new fields).

### Task 4: Batch 1, Customize (Taskbar, Start, Explorer, Theme)

Source scripts: `6 Windows/1 Start Menu Taskbar`, `2 Start Menu Layout`, `3 Start Menu Shortcuts`, `4 Context Menu`, `5 Theme Black`, `6 Signout Lockscreen Wallpaper Black`, `7 User Account Pictures Black`, `8 Widgets`, `9 Copilot` (taskbar part), and the matching `22 Control Panel Settings` values (Personalization, Explorer options, Other).

Planned files (names indicative, final list in the batch):

| Category | Toggles | Actions |
|---|---|---|
| `Customize/Taskbar` | align left (Win11), hide search, hide task view, hide chat, hide Copilot button, hide widgets, hide Meet Now (Win10), disable news and interests, hide security tray icon, show all tray icons (Win10), end task in menu, far-corner show desktop | unpin taskbar apps |
| `Customize/Start` | hide Recommended (Win11), new Start menu (Win11, Caution), All apps as list, hide most used, hide recently added, hide recent items, hide Accessibility folders, more pins | AkariOS Start pins (Win10 layout xml / Win11 `start2.bin`), Start menu shortcuts |
| `Customize/Explorer` | classic context menu, trim context menu (one topic Toggle: customize folder, pin to Quick access, favorites, compatibility, terminal, Defender scan, give access, library, share, previous versions, send to), open to This PC, show extensions, show hidden files, hide frequent folders, hide 3D Objects, hide Gallery, folder tips and title bar (topic) | |
| `Customize/Theme` | dark theme, no transparency, solid black background, black sign-in / lock screen, black account pictures, no sign-in blur | |

Each Toggle: `Registry` data (Detect is free) or `Apply`/`Revert`/`Detect` blocks; `Explorer = $true` where the change needs it. Actions say in one line why they can't be Toggles. `Ported.psd1` gets `start-taskbar`, `start-layout`, `start-shortcuts`, `context-menu`, `theme-black`, `signout-wallpaper`, `account-pictures`, `widgets` (and `copilot` only once its AI policy part lands in Task 5).

**VM check (Win11 and Win10):** Guided Tweaks shows the four new Customize cards and no longer shows the replaced legacy rows; with Show current state on, a clean VM shows them unchecked; check all → Review → Apply: taskbar, Start, Explorer, context menu and theme change, Explorer restarts once; reopen Guided: all show checked (Optimized); uncheck all → Apply: back to stock look; Win10 hides the Win11-only rows. Optimize › Legacy still has all the old rows and they still work.

### Task 5: Batch 2, Optimize registry (Privacy, Gaming, Notifications, Update) and the rest of Control Panel

Source scripts: `22 Control Panel Settings` (remaining values), `9 Copilot`, `10 Gamemode`, `11 Pointer Precision`, `19 Gamebar` (registry and presence writer only; the apps are in Apps › Remove), `21 Notepad Settings`, `23 Sound`, `24 Loudness EQ`.

| Category | Toggles (topic Toggles in italics) |
|---|---|
| `Optimize/Privacy` | *app permissions* (Deny, Default Allow), *telemetry and feedback*, activity history, *ads and suggestions*, Copilot and AI, web search in Start, *search highlights and cloud search*, find my device, location, *inking and typing data* |
| `Optimize/Gaming` | Game Mode, disable Game Bar, (Game DVR exists), HAGS, windowed optimizations / VRR, Xbox controller guide button |
| `Optimize/Update` | delivery optimization, driver updates through Windows Update (Caution), Store auto-update, Maps auto-update |
| `Customize/Notifications` | notifications off, *focus / do not disturb*, suggested actions, tips |
| `Customize/Input` | *typing*, language bar and hotkey, touch keyboard, enhance pointer precision |
| `Customize/Accessibility` | *ease of access shortcuts and narrator* |
| `Customize/Sound` | *no sound scheme*, startup sound, communications do nothing |
| `Customize/System` | snap, Alt+Tab windows only, long paths, BSOD details, finish-setup nags, Notepad settings, Terminal not default, black console |

Actions where the old script is one-shot (Loudness EQ). `Ported.psd1` gets `control-panel` (only when every one of its values has an owner across Tasks 4 to 6; until then it stays visible), `copilot`, `gamebar`, `gamemode`, `pointer-precision`, `notepad`, `sound`, `loudness-eq`.

**VM check:** as Task 4 for the new cards; Settings › Privacy shows permissions off after Apply and on after Revert; Game Bar closed and its presence writer disabled; no legacy `control-panel` row lost in Optimize › Legacy.

### Task 6: Batch 3, Power, Performance, Network

Source scripts: `25 Device Manager Power Savings & Wake`, `26 Network Adapter Power Savings & Wake`, `27 Network IPv4 Only`, `28 Write Cache Buffer Flushing`, `29 Power Plan`, `30 Timer Resolution`, `35 Cleanup`, plus remaining Control Panel values (storage sense, maintenance, defrag task, background apps).

| Category | Tweaks |
|---|---|
| `Optimize/Power` | ultimate power plan (import, activate, its powercfg sub-values; Revert `-restoredefaultschemes`, Detect = active scheme; Caution: other plans are removed), disable hibernate (Reboot), disable fast boot, disable power throttling, laptop battery actions (`Requires = 'Laptop'`), device power savings and wake, network adapter power savings and wake |
| `Optimize/Performance` | timer resolution service (`OneClick/settimerresolutionservice.cs` source, compiled in the Apply block; Revert removes the service), write cache buffer flushing, storage sense off, automatic maintenance off, defrag schedule off, background apps off; clean temp files (Action) |
| `Optimize/Network` | IPv4 only |

Services through cmdlets (`Get/Set/New-Service`), powercfg through `Invoke-AkariPowerCfg`, device and adapter changes through cmdlets or one wrapper each. `Ported.psd1`: `power-plan`, `timer-resolution`, `write-cache`, `devmgr-power`, `netadapter-power`, `ipv4-only`, `cleanup`, and `control-panel` if complete.

**VM check:** power plan shows as Ultimate Performance after Apply and Balanced after Revert; `powercfg /a` shows hibernate off; timer resolution service running after Apply, gone after Revert; network adapter shows only IPv4 bound.

### Task 7: Presets, Quick select, Last used

**Files:** `Core/Presets.ps1` (new), `Presets/AkariOS.json` (new), `UI/Steps.ps1`, `UI/Apps.ps1`, `UI/Selection.ps1`, `Akari.ps1` (CLI `-Preset`), tests.

- Format per plan §8. A bare id = Apply (Choices: Recommended); `{ "id": "value" }` for a Choice value; **Group wildcard** `"appx/*"`, `"capability/*"`, `"feature/*"` = every non-Keep Entry present on this PC (the FR33THY pick becomes data; the Apps step's AkariOS button reads the preset).
- `Get-AkariPresets` (built-in `Presets/` + user `%LOCALAPPDATA%\Akari\presets\`), `Resolve-AkariPreset` → plan items (`@{Id;Mode;Value}`), unknown ids reported, not fatal. `Save-AkariPreset`.
- **Quick select** (toolbar dropdown on Apps and Tweaks): AkariOS, Last used, user presets, "Save current as preset…". Picking one **replaces** the Selection (Clear selection, then the preset's items).
- **Last used** saved after each Guided Run.
- CLI: `-Preset <name|file>` (Apply), `-Revert -Preset` (reverse order, Actions skipped and reported).
- `AkariOS.json` = the ported equivalents of what One-click does that exist so far; no `Phases` yet (M4 adds them and switches One-click from `OneClick/*.ps1` to the preset).

```
 [Quick select ▾] [Clear selection] [☐ Show current state]      [search…]
  ├ AkariOS (recommended)
  ├ Last used
  ├ ─────────
  ├ My gaming PC
  └ Save current as preset…
```

**VM check:** Quick select › AkariOS ticks the expected rows on both steps; Clear restores; Save as preset → reopen Akari → it is listed and reproduces the Selection; after a Run, Last used reproduces it.

### Task 8: Docs and status

`AGENTS.md` layout (new Core files, `Ported.psd1`, `Presets/`, new Categories), `AkariOS-PLAN.md` §11 / §12 status, `CREDITS.md`.

---

## After this plan

- **Batch 4, Advanced › Security** (`31 UAC`, `32 Core Isolation`, `33 Defender Optimize`, and `8 Advanced` Defender, Firewall, Spectre, DEP, download warning): SmartScreen and other normal-boot parts can come first; the Safe Mode parts wait for M4 (Phases from a Run).
- Next plan: `8 Advanced`, `7 Hardware`, `5 Graphics`, `3 Setup` (Toggles only), Services Group (ADR 0002), Optimize › Advanced design.
- M4: One-click from `Presets/AkariOS.json` with Phases.

## Still open (recommendations, confirm before the task that needs them)

- `OneClick/akarios.ps1` downloads the old AkariOS-Ultimate to the Desktop: **drop it**; after M6, replace with a Desktop shortcut running the `iwr` one-liner.
- AkariOS-Files (7 non-winget installs, One-click installers, Edge/WebView reinstall): **move with M6** (Releases + `Core/Download.ps1`), not in this plan.
