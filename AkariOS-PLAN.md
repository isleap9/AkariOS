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
- **GUI: reuse the existing AkariOS-Ultimate GUI.** No rebuild from scratch. What already exists (see §5.1): Akari-Dash shell with Mica on Win11, dark title bar, custom caption buttons, collapsible sidebar, search, "Ink" dark monochrome tokens (`Bg S1 S2 Bd Tx Mu Inv InvT Warn Bad`), black-and-white Akari logo, row list with **Optimize / Default** buttons, risk badges, state dot, log drawer, status bar, a **Home page** with live spec cards, and two built-in **tuners** (Win32PrioritySeparation, SvcHostSplitThreshold).
- **Vocabulary lives in [`GLOSSARY.md`](GLOSSARY.md).** Kinds `Toggle / Choice / Action / Group`, risks `Safe / Caution / Advanced`, verbs **Apply / Revert** (the GUI buttons **Optimize / Default** are labels for them), states **Optimized / Default / Custom / Unknown**.
- **Default = stock Windows value**, never "what the user had before" ([ADR 0001](docs/adr/0001-revert-to-windows-default.md)).
- **Every Toggle and Choice must have a revert.** A Tweak is an Action only when no stock-Windows Default exists to go back to (installers, checks, cleanup, DDU); each Action file says why in one line.
- **One tweak per file.** No monolithic scripts. Exception: Groups whose Entries all have the same shape may be one data file ([ADR 0002](docs/adr/0002-data-list-groups.md)).
- **Own tweaks** on top of the FR33THY base, e.g. `Win32PrioritySeparation`, `SvcHostSplitThreshold` (both become Choices; the tuner panels go away).
- **Restore point:** created **before** the first change of a Run (once per GUI session). The old Akari-OS made it at the end. If creation fails, Akari enables System Protection on C: and bypasses the 24h throttle; if it still fails, the GUI asks and the CLI warns and continues (`-RequireRestorePoint` stops instead).
- **Supported OS:** Windows 10 22H2 and Windows 11. Win11-only tweaks use `Requires = 'Win11'`.
- **Laptops:** when a battery is detected, `Requires = 'Desktop'` tweaks stay visible with a warning, are Skipped by Presets, and can be applied by hand after a confirmation.

---

## 4. What the app does

### Sections
0. **Home**: default landing page, live specs (CPU, RAM, GPU, disk, board/BIOS, Windows build), Copy specs. Already built.
1. **Apps**: remove preinstalled apps from a checklist (Win11Debloat-style); install apps via WinGet.
2. **Optimize**: performance, power plan, privacy/telemetry, Windows Update, gaming tweaks, and a **Services** list (services.msc-style: a start-type combobox per service; ~60 curated services with Default + Recommended value + Risk, plus a "Show all services" switch for manual changes).
3. **Customize**: taskbar, Start, Explorer, context menu, theme, wallpaper.
4. **Graphics & Hardware**: driver install / debloat / settings import, DDU flow, device power saving, timer resolution service.
5. **Advanced**: risky items (Defender, VBS/memory integrity, UAC, LSA, vulnerable driver blocklist) behind clear risk badges, plus the Win32PrioritySeparation / SvcHostSplitThreshold Choices.
6. **Presets**: built-in presets plus Load / Save preset.

Today's Ultimate pages are Home, Check, Refresh, Setup, Installers, Graphics, Windows, Hardware, Advanced. The sidebar is built from a `$Pages` table (`Akari.ps1`), so renaming pages is cheap; Check / Refresh / Setup / Installers content moves into the sections above during the port.

### Tweak kinds
| Kind | Buttons | Example | Revert |
|---|---|---|---|
| **Toggle** | Optimize / Default (+ optional Check) + state dot | memory compression, telemetry | required |
| **Choice** | combobox (editable for numbers) + Optimize / Default + state dot | service start type, Win32PrioritySeparation | required (sets Default) |
| **Action** | one button with custom label | storage check, install 7-Zip | none (one-shot) |
| **Group** | optional main button + **Options** expander with Entries | bloatware (Remove all + per-app), services | per Entry, by its kind |

Toggle, Action and Group already exist in the GUI; Choice is new. Entries are addressed `<group-id>/<name>`, can be any kind except Group, and Groups don't nest. Ultimate also has a `Console` kind (opens a separate PowerShell window). Nothing uses it any more: drop it.

### Each Toggle / Choice row shows
- Name, short description, risk badge, reboot-needed flag
- **Current state**, detected live: Optimized / Default / Custom / Unknown
  - Custom = readable but neither the Optimized nor the Default value (e.g. a Choice set to another value, or a hand-edited setting).
  - Unknown = no `Detect`, or `Detect` failed.
- **Optimize** and **Default** buttons (Choice: plus the combobox). Picking a Choice value marked riskier than the row's Risk shows a confirmation first.

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
| Home page (`Get-Specs`, spec cards, Copy specs, spec watchdog) | `UI/Home.ps1` |
| Win32PrioritySeparation + SvcHost tuners | removed: become Choice tweak files; `UI/Rows.ps1` renders the Choice combobox |
| `UI/MainWindow.xaml` (565 lines) | stays; split into page XAML files only if it grows |

Things to keep: one-job-at-a-time runner, log queue drained on the UI thread, `Dispatcher.UnhandledException` → log drawer, `%LOCALAPPDATA%\Akari\akari.log`.

---

## 6. Folder layout

```
AkariOS/
├─ Akari.ps1                  # entry point (GUI / CLI / preset)
├─ Core/
│  ├─ Loader.ps1              # discovers + validates tweak files
│  ├─ Registry.ps1            # Set / Remove / Test registry helpers (incl. real-user HKCU)
│  ├─ Services.ps1            # service start-type helpers
│  ├─ Trusted.ps1             # Run-Trusted (TrustedInstaller), one copy only
│  ├─ Download.ps1            # fetch binaries from the GitHub Release (7-Zip, DDU, VC++…)
│  ├─ Runner.ps1              # apply/revert list of ids, background runspace, reboot tracking
│  ├─ State.ps1               # Detect / remembered state
│  ├─ Phases.ps1              # RunOnce / scheduled-task resume, Safe Mode on/off
│  ├─ Presets.ps1             # load/save Preset JSON (built-in + user)
│  └─ Log.ps1
├─ Tweaks/
│  ├─ Apps/
│  ├─ Optimize/
│  │  ├─ Gaming/
│  │  ├─ Performance/
│  │  ├─ Power/
│  │  ├─ Privacy/
│  │  ├─ Services/
│  │  └─ Update/
│  ├─ Customize/
│  │  ├─ Taskbar/
│  │  ├─ Start/
│  │  ├─ Explorer/
│  │  └─ Theme/
│  ├─ Hardware/              # Section shown as "Graphics & Hardware"
│  │  ├─ Graphics/
│  │  └─ Devices/
│  └─ Advanced/
│     └─ Tuning/              # Win32PrioritySeparation, SvcHostSplitThreshold Choices
├─ Presets/
│  ├─ AkariOS.json            # full one-click (replaces Akari-OS repo)
│  ├─ Gaming.json
│  └─ Light.json
├─ UI/
│  ├─ MainWindow.xaml         # carried over from AkariOS-Ultimate
│  ├─ Shell.ps1
│  ├─ Rows.ps1
│  └─ Home.ps1
├─ Assets/                    # logo, wallpaper, start2 layout
├─ Build/
│  └─ Bundle.ps1              # merges everything into one Akari.ps1 for release (skips _ref/)
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
# Tweaks/Apps/Install7Zip.ps1
@{
    Id       = 'install-7zip'
    Name     = '7-Zip'
    Section  = 'Apps'
    Category = 'Installers'
    Kind     = 'Action'
    Button   = 'Install'
    Risk     = 'Safe'
    Apply    = { Get-AkariBinary '7zip' | Start-Process -Wait -ArgumentList '/S' }
}
```

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
| `SafeMode` | no | `$true` if it must run in Safe Mode |
| `Registry` | one of | data-driven registry changes (Toggle / Choice). `Default` is a value, a per-OS map, or `$null` (delete) |
| `Apply` / `Revert` / `Detect` | one of | script blocks for custom logic |
| `Check` | no | extra "Check" button that only reports status |
| `Choices`, `Recommended`, `Default` | Choice only | valid values (each may carry its own `Risk`), the Optimized value, the stock Windows value |
| `Editable` | no | Choice only: also accept any typed number |
| `Entries` | Group only | Tweaks inside the Group (any kind except Group), id `<group-id>/<Name>` |
| `EntryKind` | no | Group only: engine-provided handler for data-list Entries (e.g. `ServiceStart`) |
| `Requires` | no | e.g. `Win11`, `NVIDIA`, `Desktop` to hide irrelevant tweaks |

Loader rules:
- A Toggle or Choice without a revert path (`Registry` or `Revert`) is rejected.
- An Action file must have a one-line comment saying why it can't be a Toggle.
- A file's folder must match its `Section` / `Category`.
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
- A bare id means Apply (Choices get their `Recommended` value). A Choice can be given an explicit value with an object entry: `{ "services/SysMain": "Manual" }`. Only Choices take a value.
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
- `_ref/winhance-notes/` — screenshots and layout notes only. **No Winhance code** (PolyForm Shield).

---

## 11. Migration

1. **Repo:** ✅ fresh repo `isleap9/AkariOS` created, `.gitignore` with `_ref/`, reference projects cloned. ✅ AkariOS-Ultimate GUI and `Tweaks/` imported as the starting point (commit `d791728` credits the source repo; Ultimate's history stays in the archived repo). ✅ Baseline checked by hand (Oct 2026): `Akari.ps1` launches and the tweaks apply.
2. ✅ (Oct 2026, M1, `docs/plans/2026-10-17-m1-engine.md`; `Presets` still to do, with M4) **Core:** move the engine out of `Akari.ps1` per §5.1 — `Loader`, `Registry`, `Trusted`, `Runner`, `State`, `Log`, `Presets`. Keep `Add-Tweak` working as a thin adapter during the port, so the GUI stays usable while categories move one at a time.
3. **Port Ultimate:** the source is the 8 GENERATED files in `Tweaks/` (the numbered folders are already gone). Split each `Add-Tweak` call into its own hashtable file, one category at a time: `Windows`, then `Advanced`, `Hardware`, `Graphics`, `Setup`, `Installers`, `Check`, `Refresh`. Per tweak, clean it up as you go:
   - remove `Pause` / `Read-Host` / `Clear-Host` leftovers;
   - add `Detect` (only 1 of ~47 Toggles has one today);
   - add the missing Reverts, or turn the tweak into an Action if it really is one-shot;
   - replace inline copies of `Run-Trusted` with the `Core/Trusted.ps1` one;
   - convert pure registry bodies (`cmd /c reg add …`) into `Registry` data.
   Delete the `Add-Tweak` adapter when the last category is ported.
4. **Port Akari-OS:** split `akarios.ps1`, `stepone.ps1`, `steptwo.ps1` and `reg.reg` into tweak files; build `Presets/AkariOS.json` and `Core/Phases.ps1`.
5. **GUI:** split `Akari.ps1` into `UI/Shell.ps1`, `UI/Rows.ps1`, `UI/Home.ps1`. Rows read Toggle / Choice state through `Core/State` (`Detect` first), show the reboot flag, and the sidebar follows the new sections. Rewrite `AGENTS.md` (Ultimate's is GSD-generated and stale).
6. **Build + Release:** `Bundle.ps1` + GitHub Action; move binaries from AkariOS-Files into Releases; `Core/Download.ps1`; retire `IWR.ps1` and `AllowScripts.cmd`.
7. **Archive:** `Akari-OS`, `AkariOS-Files`, Akari Tool (C#), AkariOS-Companion, WinUI toolbox. Add a README line pointing to `isleap9/AkariOS`.

---

## 12. Roadmap

| Milestone | Done when |
|---|---|
| **M1: Engine** | Core extracted from `Akari.ps1`; Loader + Registry + Runner work from CLI: `-List`, `-Apply`, `-Revert` on 3 sample tweaks; GUI still runs through the `Add-Tweak` adapter. |
| **M2: Windows category** | Ultimate's `Windows` category fully ported to one-file tweaks, all Toggles revertible with `Detect`. |
| **M3: GUI** | `Akari.ps1` split into `UI/*.ps1`; rows built from Core/Loader by section, Optimize/Default + Choice combobox + live state (4 states) + reboot flag; tuners replaced by Choices; Home unchanged. |
| **M4: One-click** | `-Preset AkariOS` reproduces the old Akari-OS 3-phase run, including reboots and Safe Mode. |
| **M5: Apps** | App removal checklist + WinGet installs. |
| **M6: Release** | Bundled single-file release via GitHub Action, old repos archived. |
| **M7: Polish** | Preset save/load, Services list, `Requires` filtering, own tweaks added. |

---

## 13. Open questions

- **Apps checklist (M5):** one Entry per removable app (Toggle: installed / removed, Revert reinstalls) or just a "Remove all" Action? Parked until M5.

Resolved (Oct 2026): minimum OS, laptop handling and tuners, see §3.
