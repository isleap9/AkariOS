# AkariOS — Project Plan

> One PowerShell app, one repo, for debloating and optimizing Windows 10/11 for gaming.
> Replaces **Akari-OS** (one-click, WinSux-based) and **AkariOS-Ultimate** (script menu + GUI, Ultimate-based).

---

## 1. Why

- Two repos are really two halves of one product: Akari-OS already downloads AkariOS-Ultimate and points to its graphics scripts.
- Maintaining both means duplicated tweaks, two READMEs, two places to fix the same bug, plus a third repo (AkariOS-Files) for binaries.
- Monolithic files are hard to navigate and burn AI tokens: every small change requires reading the whole file. Today Ultimate keeps 126 tweaks in 8 category files (~710 KB; `Tweaks/Windows.ps1` alone is 272 KB) and the whole GUI host in one 1,200-line `Akari.ps1`.

**Goal:** a single, maintainable app where adding or fixing a tweak means touching one small file.

### Out of scope
- Akari Tool (C#), AkariOS-Companion, WinUI toolbox: abandoned, archive them.
- Rust or any compiled rewrite: not now.

---

## 2. Inspiration — what we take from each

| Project | License | What we take |
|---|---|---|
| **Zoicware** (zoicware/ZOICWARE) | MIT | Everything in one app; user choices saved to a config file; ready-made configs ("set up Windows like me"). |
| **Win11Debloat** (Raphire) | MIT | User decides exactly what to debloat (app checklist); every change revertible; export/import settings; strong CLI; tweaks kept in separate folders, not hard-coded. |
| **Winhance** (memstechtips) | **PolyForm Shield** | Section layout (Apps / Optimize / Customize / Advanced), search, per-setting toggle with current state, WinGet installs. **Ideas and layout only, never code**: the license forbids forks or rebrands as competing products. |
| **WinSux / Ultimate** (FR33THY) | MIT | Current tweak content of both Akari repos. Keep the credit. |
| **winutil** (Chris Titus) | MIT | Develop as many files, ship as one bundled script via a build step. |

MIT code may be reused with attribution. Keep a `CREDITS.md` listing every upstream source.

---

## 3. Decisions so far

- **Name:** AkariOS. Repo `isleap9/AkariOS`, entry script `Akari.ps1`.
- **Tech:** pure PowerShell 5.1 (STA, elevated) + WPF/XAML GUI. No downloaded exes for the UI.
- **GUI: keep the AkariOS-Ultimate shell and theme; Home is Win11Debloat-style** (decided Oct 2026, revised 2026-10-19, [ADR 0003](docs/adr/0003-one-click-or-manual.md)). Kept: Akari-Dash shell with Mica on Win11, dark title bar, custom caption buttons, collapsible sidebar, the page header, the header search, the status bar, and the "Ink" dark monochrome tokens (`Bg S1 S2 Bd Tx Mu Inv InvT Warn Bad`). Replaced: the Optimize / Default row buttons, state dot, risk badges, log drawer (replaced by the visible console), both **tuners** (they become Choices), the old 8 pages, and the current Home. The controls inside pages look like native WinUI 3 (Windows 11 Settings): setting cards, ToggleSwitch, ComboBox, expanders. Dark only.
- **The experience combines Win11Debloat and Zoicware** (§4): on opening, the user chooses **AkariOS one-click** or **Manual**.
- **Vocabulary lives in [`GLOSSARY.md`](GLOSSARY.md).** Kinds `Toggle / Choice / Action / Group`, risks `Safe / Caution / Advanced`, verbs **Apply / Revert**, states **Optimized / Default / Custom / Unknown**.
- **Default = stock Windows value**, never "what the user had before" ([ADR 0001](docs/adr/0001-revert-to-windows-default.md)).
- **Every Toggle and Choice must have a revert.** A Tweak is an Action only when no stock-Windows Default exists to go back to (installers, checks, cleanup, DDU); each Action file says why in one line.
- **One tweak per file.** No monolithic scripts. Exception: Groups whose Entries all have the same shape may be one data file ([ADR 0002](docs/adr/0002-data-list-groups.md)).
- **Own tweaks** on top of the FR33THY base, e.g. `Win32PrioritySeparation`, `SvcHostSplitThreshold` (both become Choices; the tuner panels go away).
- **Restore point:** created **before** the first change of a Run (once per GUI session). The old Akari-OS made it at the end. If creation fails, Akari enables System Protection on C: and bypasses the 24h throttle; if it still fails, the GUI asks and the CLI warns and continues (`-RequireRestorePoint` stops instead).
- **Supported OS:** Windows 10 22H2 and Windows 11. Win11-only tweaks use `Requires = 'Win11'`.
- **Laptops:** when a battery is detected, `Requires = 'Desktop'` tweaks stay visible with a warning, are Skipped by Presets, and can be applied by hand after a confirmation.

---

## 4. What the app does

### The experience (decided Oct 2026, revised 2026-10-19)
Win11Debloat's structure (Raphire): a start screen, then a guided "choose, review, apply once" flow; plus a manual mode for power users.

- **Home** (first screen, full window, **no sidebar**): three tiles.
  - **Install AkariOS**: guided optimization, recommended for a fresh install. Full window, no sidebar (Back returns to Home). Two choices:
    - **One-click**: the old Akari-OS run (prep → Safe Mode → tweaks, reboots handled), after a confirmation. ✅ Oct 2026: Akari runs it natively in its own console: the imported Akari-OS phase bodies in `OneClick/`, chained by Akari (`Core/Phases.ps1`: Safe Mode, RunOnce `Akari.ps1 -OneClick 2|3`, restart). Porting the bodies into tweak files is step 4 below. ✅ M4 (Oct 2026, passed on the VM): One-click runs `Presets/AkariOS.json` (three Phases: preparation, Safe Mode, debloat and tweaks) through `Core/Phases.ps1`; the old bodies and `Akari.ps1 -OneClick` were deleted after the VM check (2026-10-22).
    - **Guided**: steps with Back / Next and step dots: **Apps → Tweaks → Review & Apply**. Nothing changes while choosing; each Toggle shows a checkbox, checked when its State is Optimized, Choices a combobox, Apps a checklist. Review lists only the changes ("Disable Game DVR: Default → Optimized"), then one Run with a restore point first. **Quick select** on Apps and Tweaks: AkariOS, Gaming, Privacy, Light, Last used, the user's own presets. Tweaks step (decided 2026-10-19, ADR 0003): Win11Debloat's category-card grid with checkboxes (Win11Debloat's checked = Apply model), Choices on "No change", glyphs for Risk / restart / State. Apps step: Remove and Install tabs over one table.
  - **Optimize**: **Manual mode**, in-depth, for power users. A chooser with two cards (decided 2026-10-19, ADR 0003): **Legacy** opens the old Ultimate pages with the sidebar, legacy tweaks only (frozen, ADR 0004), every button acting right away; **Advanced** is disabled for now: the new look built on the one-file tweaks, moving away from the FR33THY page structure, designed in a later plan.
  - **Downloads** (Oct 2026): the Guided Apps step's Install cards on their own (apps, game launchers, runtimes, tools, and Store apps the debloat removed), then Review & Apply. Back and Done lead Home.
  - **Import / Export settings**: save choices to a file or load them on another PC (M5).
  - A small **Undo everything** link: selects Revert for every Tweak Akari changed.
- Only Optimize › Legacy has a sidebar (decided 2026-10-20): `← Optimize`, then the legacy pages Check, Refresh, Setup, Downloads, Graphics, Windows, Hardware, Advanced. Home, the choosers and the Guided / Downloads flows are full window with Back.
- **Config** (Zoicware-style): choices are saved automatically as "Last used"; an imported config can run silently.
- **Status bar** shows what is running, "Restart required" (with a Restart button) and failures.
- **Console** (Win11Debloat / Zoicware style, decided 2026-10-19): the elevated PowerShell window stays open next to Akari, shows a launch banner and every log line live (colour by Outcome). No log panel in the window; `akari.log` keeps a copy.

### Tweak kinds
| Kind | Control | Example | Revert |
|---|---|---|---|
| **Toggle** | ToggleSwitch (On = Optimized) | memory compression, telemetry | required |
| **Choice** | ComboBox, "(Recommended)" and "(Windows default)" marked; editable for numbers | service start type, Win32PrioritySeparation | required (sets Default) |
| **Action** | one button with custom label (in the Tweaks step: a checkbox "run this") | storage check, install 7-Zip | none (one-shot) |
| **Group** | expander card with Entries inside | bloatware, services | per Entry, by its kind |
 Entries are addressed `<group-id>/<name>`, can be any kind except Group, and Groups don't nest. Ultimate also has a `Console` kind (opens a separate PowerShell window). Nothing uses it any more: drop it.

### Each Toggle / Choice card shows
- Name, short description, reboot-needed flag. Caution / Advanced show a warning glyph and the Risk word at the start of the description; Safe shows nothing.
- **Current state**, detected live: Optimized / Default / Custom / Unknown
  - Custom = readable but neither the Optimized nor the Default value (e.g. a Choice set to another value, or a hand-edited setting). Shown as "Custom value" on the description line.
  - Unknown = no `Detect`, or `Detect` failed. Shown as "State unknown".
- The switch or combobox. Selecting an Advanced Tweak, or a Choice value riskier than the card's Risk, shows a confirmation first.

### Modes
- **GUI**: `Akari.ps1` with no arguments.
- **One-click**: `Akari.ps1 -Preset AkariOS`, the old Akari-OS experience (prep → Safe Mode → tweaks, with reboots handled automatically).
- **CLI**: `-Preset <name|file>`, `-Apply <id,id>`, `-Revert <id,id>`, `-Revert -Preset <name>` (reverts the Preset's Toggles/Choices in reverse order, skips Actions and reports them), `-List`, `-RequireRestorePoint`.

### Run summary
Every Run ends with one Outcome per Tweak: **Applied** / **Reverted**, **Already** (State already matched), **Skipped** (a Requirement wasn't met, or the service/app doesn't exist on this machine), **Failed**. Plus one **Reboot pending** flag. A Failed Tweak doesn't stop the Run, except in a Safe Mode Phase: there the Run stops and stays in Safe Mode for the user to inspect.

---

## 5. Architecture

```
Akari.ps1  ──►  Core/Loader  ──►  Tweaks/**/*.ps1  (data + optional script blocks)
                    │
                    ├─► UI/      builds pages from the loaded tweak list
                    └─► Core/Runner  applies/reverts lists of tweak ids
                              └─► Core/Phases  reboot / Safe Mode resume for presets
```

- **Tweaks are data.** The engine reads them; the GUI and CLI both use the same engine.
- **The GUI never hard-codes tweaks.** Adding a tweak = adding a file.
- **A preset is a list of tweak ids** (+ optional phase info).

### 5.1 What Ultimate's `Akari.ps1` already does, and where it goes

| Today (`AkariOS-Ultimate/Akari.ps1`) | Moves to |
|---|---|
| Elevate + STA relaunch, root folder detection, startup `trap` | `Akari.ps1` |
| `Add-Tweak` + dot-sourcing `Tweaks/*.ps1` (lines ~51–62) | `Core/Loader.ps1` (reads one-file hashtables, validates) |
| `$Helpers` runspace preamble: `Write-Log`, `Write-Host` shim, `Set-Reg`, `Remove-Reg`, `Run-Trusted`, folder/file pickers | `Core/Registry.ps1`, `Core/Log.ps1`, `Core/Trusted.ps1` |
| `Invoke-Code` (one background runspace at a time) + completion handling in the `DispatcherTimer` | `Core/Runner.ps1` (GUI and CLI share it; CLI runs synchronously) |
| `Get-State` (`Detect`, else remembered `state.json`), `Save-State` | `Core/State.ps1` |
| Window chrome, Mica, caption buttons, sidebar, search, `Show-Page` | `UI/Shell.ps1` |
| `New-Row`, `Update-Row`, row click handler | `UI/Rows.ps1` |
| Home page (`Get-Specs`, spec cards, Copy specs, spec watchdog) | `UI/Home.ps1`, then dropped (M3: Home is the four tiles) |
| Win32PrioritySeparation + SvcHost tuners | removed: become Choice tweak files; `UI/Rows.ps1` renders the Choice combobox |
| `UI/MainWindow.xaml` (565 lines) | stays; split into page XAML files only if it grows |

Things to keep: one-job-at-a-time runner, log queue drained on the UI thread, `Dispatcher.UnhandledException` → console, `%LOCALAPPDATA%\Akari\akari.log`.

---

## 6. Folder layout

```
AkariOS/
├─ Akari.ps1                  # entry point (GUI / CLI / preset)
├─ Core/
│  ├─ Loader.ps1              # discovers + validates tweak files, Ported.psd1, one owner per registry value
│  ├─ Registry.ps1            # Set / Remove / Test registry helpers (incl. real-user HKCU, key rows, literal paths)
│  ├─ Trusted.ps1             # Run-Trusted (TrustedInstaller), one copy only
│  ├─ Runner.ps1              # apply/revert list of ids, background runspace, restart-last, Explorer once
│  ├─ State.ps1               # Detect / remembered state
│  ├─ System.ps1              # OS / chassis reads (Requires), Explorer restart, powercfg, csc, wallpaper refresh
│  ├─ Presets.ps1             # load/save Preset JSON (built-in + user), Last used
│  ├─ Phases.ps1              # RunOnce resume, Safe Mode on/off (One-click)
│  ├─ Appx.ps1, Winget.ps1, AppSetup.ps1, Restore.ps1   # apps, installs, restore point
│  ├─ Legacy.ps1, Compat.ps1  # the Add-Tweak adapter and shims for Legacy (frozen)
│  ├─ Log.ps1                 # log, console banner (Assets\ascii.txt)
│  ├─ Services.ps1            # (later) service start-type helpers
│  └─ Download.ps1            # (later, M6) fetch binaries from the GitHub Release (7-Zip, DDU, VC++…)
├─ Tweaks/
│  ├─ *.ps1                   # Legacy: the 7 generated AkariOS-Ultimate files, frozen (ADR 0004)
│  ├─ Ported.psd1             # legacy id → the one-file ids that fully replace it
│  ├─ Apps/                   # Remove (debloat), Install (Downloads)
│  ├─ Optimize/
│  │  ├─ Gaming/
│  │  ├─ Network/
│  │  ├─ Performance/
│  │  ├─ Power/
│  │  ├─ Privacy/
│  │  ├─ Services/            # (later) the Services data-list Group
│  │  └─ Update/
│  ├─ Customize/
│  │  ├─ Taskbar/
│  │  ├─ Start/
│  │  ├─ Explorer/
│  │  ├─ Theme/
│  │  ├─ Notifications/
│  │  ├─ Input/
│  │  ├─ Accessibility/
│  │  ├─ Sound/
│  │  └─ System/
│  ├─ Hardware/              # (later) Section shown as "Graphics & Hardware"
│  │  ├─ Graphics/
│  │  └─ Devices/
│  └─ Advanced/
│     └─ Tuning/              # Win32PrioritySeparation, SvcHostSplitThreshold Choices
├─ Presets/
│  └─ AkariOS.json            # the AkariOS setup = the AkariOS marks, in Phases; One-click runs it (M4)
├─ OneClick/                  # files One-click's tweaks read: reg.reg, start2.txt, settimerresolutionservice.cs, img.jpg
├─ UI/
│  ├─ MainWindow.xaml         # shell, carried over from AkariOS-Ultimate
│  ├─ Controls.xaml           # WinUI-style switch, combobox, setting card, expander
│  ├─ Shell.ps1               # window, Home tiles, Legacy sidebar, search, status bar, job timer
│  ├─ Rows.ps1                # Optimize › Legacy rows (act right away)
│  ├─ Selection.ps1           # pending changes of the Manual steps (no WPF)
│  ├─ Cards.ps1               # one setting card per Tweak
│  ├─ Apps.ps1                # the Apps step (Remove / Install), Downloads
│  └─ Steps.ps1               # choosers, Apps → Tweaks → Review & Apply, Quick select
├─ Assets/                    # logo (png, ico, ascii.txt for the console)
├─ Build/
│  └─ Bundle.ps1              # (M6) merges everything into one Akari.ps1 for release (skips _ref/)
├─ _ref/                      # local reference projects, gitignored (see §10)
├─ .github/workflows/release.yml
├─ .gitignore                 # includes _ref/
├─ AGENTS.md
├─ CREDITS.md
├─ LICENSE                    # MIT
└─ README.md
```

---

## 7. Tweak file format

Each file is a `.ps1` that returns a hashtable. The loader runs it with `& $file`.

### Registry-only toggle (most tweaks)
The engine derives Apply / Revert / Detect from the `Registry` entries automatically.

```powershell
# Tweaks/Optimize/Gaming/GameDvr.ps1
@{
    Id          = 'disable-game-dvr'
    Name        = 'Disable Game DVR'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Turns off background game recording.'
    Registry    = @(
        @{
            Path    = 'HKCU:\System\GameConfigStore'
            Name    = 'GameDVR_Enabled'
            Type    = 'DWord'
            Value   = 0
            Default = 1          # $null = "Windows doesn't set this value, delete it on revert"
        }                        # per-OS when they differ: Default = @{ Win10 = 1; Win11 = 0 }
    )
}
```

### Choice
`Choices` lists the valid values; `Recommended` is what Optimize and Presets set. An `Editable` Choice also accepts any number typed in.

```powershell
# Tweaks/Advanced/Tuning/Win32PrioritySeparation.ps1
@{
    Id          = 'win32-priority-separation'
    Name        = 'Win32 Priority Separation'
    Section     = 'Advanced'
    Category    = 'Tuning'
    Kind        = 'Choice'
    Risk        = 'Safe'
    Reboot      = $true
    Description = 'Short, variable quanta with a 3:1 foreground boost (0x26).'
    Registry    = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'; Name = 'Win32PrioritySeparation'; Type = 'DWord' }
    Choices     = @(
        @{ Value = 0x26; Label = '0x26 short, variable, 3:1' }
        @{ Value = 0x28; Label = '0x28 short, fixed' }
        @{ Value = 0x18; Label = '0x18 long, fixed, 3:1'; Risk = 'Caution' }
    )
    Editable    = $true
    Recommended = 0x26
    Default     = 2
}
```

### Toggle with custom logic
```powershell
# Tweaks/Optimize/Performance/MemoryCompression.ps1
@{
    Id       = 'disable-memory-compression'
    Name     = 'Disable Memory Compression'
    Section  = 'Optimize'
    Category = 'Performance'
    Risk     = 'Caution'
    Reboot   = $true
    Detect   = { -not (Get-MMAgent).MemoryCompression }
    Apply    = { Disable-MMAgent -MemoryCompression }
    Revert   = { Enable-MMAgent -MemoryCompression }
}
```

### Action
```powershell
# Tweaks/Apps/Install/7Zip.ps1 (Oct 2026: app installs use winget wherever the app is on it)
# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id       = 'install-7-zip'
    Name     = '7-Zip'
    Section  = 'Apps'
    Category = 'Install'
    Kind     = 'Action'
    Button   = 'Install'
    Risk     = 'Safe'
    Winget   = '7zip.7zip'           # the engine installs it (Core/Winget.ps1); Detect = winget lists it as installed
    After    = { Set-Reg 'HKCU:\Software\7-Zip\Options' 'CascadedMenu' 0 }    # optional extras after the install
}
```
An app that isn't on winget keeps an `Apply` (download from AkariOS-Files with `Save-AkariFile`) and a `# Not winget: <why>` line.

### Group
Entries are full Tweaks without `Section`/`Category`; their id is `<group-id>/<Name>`.

```powershell
@{
    Id = 'bloatware'; Kind = 'Group'; Button = 'Remove all'; ...
    Apply   = { ... }                       # optional main button
    Entries = @(
        @{ Name = 'xbox'; Description = '...'; Kind = 'Action'; Button = 'Remove'; Confirm = '...'; Apply = { ... } }
    )
}
```

### Data-list Group ([ADR 0002](docs/adr/0002-data-list-groups.md))
When every Entry has the same shape, the Group reads them from one data file. Services: one row per service, each becoming a Choice Entry `services/<ServiceName>` over `Automatic / AutomaticDelayed / Manual / Disabled`.

```powershell
# Tweaks/Optimize/Services/Services.ps1
@{
    Id = 'services'; Kind = 'Group'; Name = 'Services'; Section = 'Optimize'; Category = 'Services'; Risk = 'Caution'
    EntryKind = 'ServiceStart'                   # engine knows how to Detect/Apply/Revert a service start type
    Entries   = Import-PowerShellDataFile "$PSScriptRoot\Services.psd1"
}
# Services.psd1 rows: @{ Name = 'SysMain'; Display = 'SysMain'; Default = 'Automatic'; Recommended = 'Disabled'; Risk = 'Caution'; Requires = 'SSD' }
```

### Fields
| Field | Required | Notes |
|---|---|---|
| `Id` | yes | kebab-case, unique, used by presets and CLI |
| `Name`, `Description` | yes | shown in the GUI |
| `Section`, `Category` | yes | drives sidebar and grouping |
| `Risk` | yes | `Safe` / `Caution` / `Advanced` (badge colours `Mu` / `Warn` / `Bad`) |
| `Kind` | no | `Toggle` (default) / `Choice` / `Action` / `Group` |
| `Button` | no | label for Action / Group main button (default `Run`) |
| `Confirm` | no | text of a Yes/No prompt shown before running |
| `Reboot` | no | default `$false` |
| `SafeMode` | no | `$true` if it must run in Safe Mode: a Run takes the PC there and back (Core/Phases.ps1, M4) |
| `Restarts` | no | `$true` when its Apply restarts the PC itself (DDU): it runs last, after the next boot is set up |
| `Registry` | one of | data-driven registry changes (Toggle / Choice). `Default` is a value, a per-OS map, or `$null` (delete). `Type = 'Binary'` takes a `[byte[]]`. A **key row** has no `Name`: `Value` / `Default` are `'Key'` (the key exists, created empty) or `$null` (the key is deleted with its contents). One owner per value: no two one-file tweaks set the same value or anything inside the same key row |
| `Apply` / `Revert` / `Detect` | one of | script blocks for custom logic |
| `Check` | no | extra "Check" button that only reports status |
| `Choices`, `Recommended`, `Default` | Choice only | valid values (each may carry its own `Risk`), the Optimized value, the stock Windows value |
| `Editable` | no | Choice only: also accept any typed number |
| `Entries` | Group only | Tweaks inside the Group (any kind except Group), id `<group-id>/<Name>` |
| `EntryKind` | no | Group only: engine-provided handler for data-list Entries (e.g. `ServiceStart`) |
| `Requires` | no | `Win10`, `Win11`, `Laptop`, `Desktop` (later e.g. `NVIDIA`, `SSD`): unmet = hidden in Guided, `Skipped` in a Run |
| `AkariOS` | no | `$true` when the Tweak is part of the AkariOS setup (One-click sets the same thing, e.g. in `OneClick/reg.reg`): Guided shows "(AkariOS)" after its name. A test keeps registry tweaks in line with `reg.reg` both ways |
| `Explorer` | no | `$true` when the change shows only after Explorer restarts: the Run restarts Explorer once at the end if such a Tweak was Applied or Reverted |
| `Winget`, `Before`, `After` | no | Action only: winget package id(s) the engine installs, between the `Before` and `After` blocks; no `Apply` with them. On a registry Toggle, `After` is one more step after its rows, on Apply and on Revert (`$AkariMode`), e.g. a scheduled task |
| `WingetSource` | no | `msstore`: the `Winget` id is a Microsoft Store product id |
| `AppType` | no | Apps > Install only: the card the app shows in (Browsers, Communication, Game launchers, Gaming & hardware, Media, Utilities, Runtimes, Dev tools, Restore removed apps) |

Loader rules:
- A Toggle or Choice without a revert path (`Registry` or `Revert`) is rejected.
- An Action file must have a one-line comment saying why it can't be a Toggle.
- A file's folder must match its `Section` / `Category`.
- An Action's `Detect` (optional) means "already done": the Runner reports Already and skips it.
- A Toggle without `Detect` (and no `Registry`) loads with a warning: the state falls back to "what Akari last applied", which is wrong after a Windows update or a manual change.
- Script blocks must not be interactive: no `Pause`, `Read-Host`, `Clear-Host`. The runner keeps no-op shims only as a safety net.

---

## 8. Presets

```json
{
  "Name": "AkariOS",
  "Description": "Full one-click AkariOS setup for gaming desktops.",
  "Phases": [
    { "Name": "Prep",     "Boot": "Normal",   "Tweaks": ["install-7zip", "install-vcredist", "remove-store-apps"] },
    { "Name": "SafeMode", "Boot": "SafeMode", "Tweaks": ["defender-safemode-settings", "disable-uac", "ddu-remove-drivers"] },
    { "Name": "Tweaks",   "Boot": "Normal",   "Tweaks": ["remove-edge", "remove-onedrive", "ultimate-power-plan", "timer-resolution-service"] }
  ]
}
```

- Simple presets can skip `Phases` and just list `Tweaks`.
- A bare id means Apply (Choices get their `Recommended` value). A Choice can be given an explicit value with an object entry: `{ "services/SysMain": "Manual" }`. `{ "id": "Default" }` means Revert (so a saved Selection with unchecked rows comes back as it was). `"<group>/*"` means every non-keep Entry of that data-list Group on this PC (`appx/*`, `capability/*`, `feature/*`).
- Built (M3): `Core/Presets.ps1`, `Presets/AkariOS.json` (kept equal to the `AkariOS = $true` marks by a test), Quick select on the Apps and Tweaks steps, Last used after each Guided Run, CLI `-Preset` / `-RevertPreset` (a separate switch: `-Revert` already takes ids).
- **Save preset** writes the same JSON format (flat `Tweaks`, no Phases) from the user's current GUI selection, including services changed through "Show all". On a machine without that service the Outcome is Skipped.
- User presets may contain Phases if written by hand.
- `-Revert -Preset <name>` reverts the Toggles and Choices in reverse order and skips Actions.
- `Core/Phases` stores the real user's SID at the start of the run, so HKCU tweaks in later phases (after Safe Mode / RunOnce) still target that user.

---

## 9. Distribution

- Develop with many small files.
- `Build/Bundle.ps1` concatenates Core + Tweaks + UI (XAML embedded as here-strings) into a single `Akari.ps1`. It never includes `_ref/`.
- A GitHub Action builds the bundle on tag and attaches it to the Release, together with the binaries (7-Zip, DDU, VC++, DirectX) that used to live in AkariOS-Files. `Core/Download.ps1` fetches them on demand, because a script run through `iex` has no files next to it.
- Install line stays a one-liner (replaces today's `IWR.ps1`, which downloads `main.zip` into `C:\AkariOS-Ultimate`):
  ```powershell
  iwr 'https://github.com/isleap9/AkariOS/releases/latest/download/Akari.ps1' -useb | iex
  ```
- Never edit the bundled file by hand.
- ✅ Releases and updates (decided 2026-10-20, before M6): `$AkariVersion` in `Core/Version.ps1` (SemVer, `1.0.0` at M6), tag `v<version>`; `.github/workflows/release.yml` zips the runtime folders into `AkariOS-<version>.zip` and publishes it. A folder install updates itself (`Core/Update.ps1`, `UI/About.ps1`): a background check on every GUI launch (never CLI or `-Resume`) and a Check button on the About page; an update found while still on Home asks "Update now / Later", Home shows a bar until Akari closes; never automatic. Install: download, SHA-256 against the `digest` GitHub reports (refused without one), unpack, then a helper outside the folder waits for Akari to exit, swaps the folder (old copy kept as `.old`, put back on failure) and restarts Akari. Blocked in a git checkout, during a Run in phases or while changes are applied. `%LOCALAPPDATA%\Akari` is never touched. Offline / rate limit: silent on launch, one line on the About page. Run through `iex` (M6), Akari is always the latest and offers no update. Passed on the VM 2026-10-20 (v0.1.0 → v0.1.1 updated itself).

---

## 10. Rules (copy into AGENTS.md)

1. One tweak per file. If a file passes ~150 lines, split it.
2. Every Toggle has a revert. No exceptions.
3. No tweak logic in `Core/`. Core = helpers, loader, runner only.
4. The GUI never hard-codes tweaks; it builds from the loader output.
5. AI agents: open only the tweak file(s) being changed; don't read the whole `Tweaks/` tree or the bundled `Akari.ps1`.
6. HKCU changes must target the real logged-in user hive, not the elevated/SYSTEM one.
7. Credit upstream sources in `CREDITS.md` when porting a tweak.
8. Never copy code from Winhance.
9. Update `AGENTS.md` in the same change whenever the layout or a Core API changes. (Ultimate's AGENTS.md went stale: it still describes the deleted numbered folders.)
10. `_ref/` is reference only: read a file there only when the task names it; never scan it whole, never commit or bundle it.

### Local reference projects (`_ref/`, gitignored)
Shallow clones (`git clone --depth 1`) kept next to the code so agents always have the sources at hand:
- `_ref/ZOICWARE` — zoicware/ZOICWARE
- `_ref/Win11Debloat` — Raphire/Win11Debloat
- `_ref/winutil` — ChrisTitusTech/winutil
- `_ref/Ultimate` — FR33THYFR33THY/Ultimate
- `_ref/WinSux` — FR33THYFR33THY/WinSux (base of the old Akari-OS)
- `_ref/Akari-OS` — isleap9/Akari-OS (old one-click, source for the port)
- `_ref/AkariOS-Ultimate old no UI` — the original AkariOS-Ultimate scripts, one per file in `1 Check` … `8 Advanced` (source for the Ultimate port)
- `_ref/winhance-notes/` — screenshots and layout notes only. **No Winhance code** (PolyForm Shield).

---

## 11. Migration

1. **Repo:** ✅ fresh repo `isleap9/AkariOS` created, `.gitignore` with `_ref/`, reference projects cloned. ✅ AkariOS-Ultimate GUI and `Tweaks/` imported as the starting point (commit `d791728` credits the source repo; Ultimate's history stays in the archived repo). ✅ Baseline checked by hand (Oct 2026): `Akari.ps1` launches and the tweaks apply.
2. ✅ (Oct 2026, M1, `docs/plans/2026-10-17-m1-engine.md`; `Presets` still to do, with M4) **Core:** move the engine out of `Akari.ps1` per §5.1 — `Loader`, `Registry`, `Trusted`, `Runner`, `State`, `Log`, `Presets`. Keep `Add-Tweak` working as a thin adapter during the port, so the GUI stays usable while categories move one at a time.
3. **Port Ultimate:** the source is `_ref/AkariOS-Ultimate old no UI/` (the original one-script-per-file folders `1 Check` … `8 Advanced`, 104 scripts), not the 8 GENERATED files in `Tweaks/`. Each old script becomes one tweak file (or several, when it bundles unrelated settings). Its `Add-Tweak` entry in `Tweaks/*.ps1` stays: Legacy is frozen (decided 2026-10-19, ADR 0004) and keeps working on Optimize › Legacy; once everything the entry sets has a one-file owner, `Tweaks/Ported.psd1` lists it and Guided hides its row. Granularity (M3): a setting the user sees is one Toggle; invisible plumbing is one topic Toggle with several `Registry` rows. Order: `6 Windows`, then `8 Advanced`, `7 Hardware`, `5 Graphics`, `3 Setup`, `4 Installers`, `1 Check`, `2 Refresh`. ✅ `4 Installers` ported first (Oct 2026, for the Guided Apps step): `Tweaks/Apps/Install/`, winget for 18 of 28 apps. Per tweak, clean it up as you go:
   - remove `Pause` / `Read-Host` / `Clear-Host` leftovers;
   - add `Detect` (only 1 of ~47 Toggles has one today);
   - add the missing Reverts, or turn the tweak into an Action if it really is one-shot;
   - replace inline copies of `Run-Trusted` with the `Core/Trusted.ps1` one;
   - convert pure registry bodies (`cmd /c reg add …`) into `Registry` data.
   The `Add-Tweak` adapter (`Core/Legacy.ps1`) and `Core/Compat.ps1` stay as long as Legacy does.
   ✅ `6 Windows` (M3, Oct 2026): 126 one-file tweaks in Optimize and Customize, most of Control Panel Settings generated from its own Optimize / Default `.reg` blocks. Left in Legacy for now: Control Panel's focus / priority notification blobs, app actions and Explorer `IsEnabled`; Copilot's app removal; Gamebar's Revert (reinstalls the Xbox apps); Notepad settings (an app settings hive); UAC, Core isolation, Defender (Safe Mode, M4). Next: `8 Advanced`, `7 Hardware`, `5 Graphics`, `3 Setup` (Toggles only).
4. **Port Akari-OS:** (One-click already runs the imported `OneClick/` scripts as-is; this step replaces them) split `akarios.ps1`, `stepone.ps1`, `steptwo.ps1` and `reg.reg` into tweak files; build `Presets/AkariOS.json` and `Core/Phases.ps1`. M3 started it: every one-file Tweak One-click also does is marked `AkariOS = $true` (checked against `reg.reg` and `steptwo.ps1` by a test), and `Presets/AkariOS.json` is those marks; M4 adds the Phases and switches One-click to the preset. ✅ M4 (Oct 2026): `Presets/AkariOS.json` has Phases; `Core/Phases.ps1` runs them (run.json, RunOnce `Akari.ps1 -Resume`, Safe Mode on / off, restarts; SafeMode Tweaks in Guided go through the same Run). Ported for it: Windows Security settings (Safe Mode, TrustedInstaller), Defender tasks / SmartScreen, UAC, Notepad settings, and One-click's own steps in `Tweaks/OneClick/` (DDU prepare / clean, reg.reg import for the values no Tweak owns yet, priority notifications, app actions, startup cleanup, performance counters, final restore point). ✅ (2026-10-22) The `8 Advanced` Defender (full disable: `security-defender-off`, what the other two Defender Tweaks don't own) and Services (`advanced-services-off`, one Toggle over a generated start-type list) scripts, both SafeMode, not in the AkariOS preset.
5. ✅ M2a (Oct 2026, `docs/plans/2026-10-19-m2a-manual-steps.md`: UI split, controls, Manual steps, Apply with restore point; M2b still to do) **GUI:** build the §4 experience inside the kept shell: split `Akari.ps1` into `UI/Shell.ps1`, `UI/Home.ps1`, `UI/Steps.ps1`, `UI/Cards.ps1`, `UI/Toolbox.ps1`; WinUI-style control templates in XAML. Comes **before** the port (step 3), so ported Tweaks land straight in the new UI.
6. **Build + Release:** `Bundle.ps1` + GitHub Action; move binaries from AkariOS-Files into Releases; `Core/Download.ps1`; retire `IWR.ps1` and `AllowScripts.cmd`.
7. **Archive:** `Akari-OS`, `AkariOS-Files`, Akari Tool (C#), AkariOS-Companion, WinUI toolbox. Add a README line pointing to `isleap9/AkariOS`.

---

## 12. Roadmap

| Milestone | Done when |
|---|---|
| **M1: Engine** | Core extracted from `Akari.ps1`; Loader + Registry + Runner work from CLI: `-List`, `-Apply`, `-Revert` on 3 sample tweaks; GUI still runs through the `Add-Tweak` adapter. |
| **M2: Experience** (M2a ✅ Manual steps; M2b: Home, Install / Utilities, status bar, log panel gone) | §4 experience inside the kept shell: Home (One-click / Manual / Undo everything), guided steps (Tweaks → Review & Apply; Apps step stubbed), Install / Utilities pages, WinUI-style cards / switch / combobox, status bar with Restart required; tuners and log panel gone; old tweaks reachable until ported. Built from Core/Loader only. |
| **M3: Windows category** ✅ Oct 2026 (plan `docs/plans/2026-10-19-m3-port-windows.md`) | Optimize chooser (Legacy / Advanced); engine prep (`Requires`, `Explorer`, `Ported.psd1`); `6 Windows` from the old no-UI Ultimate ported to one-file tweaks, all Toggles revertible with `Detect` (Security parts wait for M4); Presets with Quick select, Last used and CLI `-Preset`. |
| **M4: One-click** ✅ Oct 2026 (passed on the VM; the old `OneClick/` scripts and `-OneClick` removed 2026-10-22) | AkariOS one-click (Home button and `-Preset AkariOS`) reproduces the old Akari-OS 3-phase run, including reboots and Safe Mode. |
| **M5: Apps + Config** | Import / Export of settings (the Home tile). Already done earlier: the app removal checklist and winget installs (Guided Apps, Downloads), Quick select, Last used and Save as preset (M3). |
| **M6: Release** | Bundled single-file release via GitHub Action, old repos archived. |
| **M7: Polish** | Rest of the port, Services list, own tweaks, new Home extras, Optimize › Advanced. (`Requires` filtering came with M3.) |

---

## 13. Open questions

- **Apps checklist (M5):** one Entry per removable app (Toggle: installed / removed, Revert reinstalls) or just a "Remove all" Action? Parked until M5.

Resolved (Oct 2026): minimum OS, laptop handling and tuners, see §3.
