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
- **Keep the GUI's vocabulary:** risk names `Safe / Caution / Advanced`, state script block named `Detect`, row kinds `Toggle / Action / Group`.
- **Every Toggle must have a revert.** No apply-only toggles. One-shot Actions (installers, checks) are exempt.
- **One tweak per file.** No monolithic scripts.
- **Own tweaks** on top of the FR33THY base, e.g. `Win32PrioritySeparation`, `SvcHostSplitThreshold`.
- **Restore point:** created **before** the run (the old Akari-OS made it at the end).

---

## 4. What the app does

### Sections
0. **Home**: default landing page, live specs (CPU, RAM, GPU, disk, board/BIOS, Windows build), Copy specs. Already built.
1. **Apps**: remove preinstalled apps from a checklist (Win11Debloat-style); install apps via WinGet.
2. **Optimize**: performance, power plan, privacy/telemetry, Windows Update, services, gaming tweaks.
3. **Customize**: taskbar, Start, Explorer, context menu, theme, wallpaper.
4. **Graphics & Hardware**: driver install / debloat / settings import, DDU flow, device power saving, timer resolution service.
5. **Advanced**: risky items (Defender, VBS/memory integrity, UAC, LSA, vulnerable driver blocklist) behind clear risk badges, plus the tuners.
6. **Presets**: built-in presets plus Load / Save my config.

Today's Ultimate pages are Home, Check, Refresh, Setup, Installers, Graphics, Windows, Hardware, Advanced. The sidebar is built from a `$Pages` table (`Akari.ps1`), so renaming pages is cheap; Check / Refresh / Setup / Installers content moves into the sections above during the port.

### Row kinds (already supported by the GUI)
| Kind | Buttons | Example | Revert |
|---|---|---|---|
| **Toggle** | Optimize / Default (+ optional Check) + state dot | memory compression, telemetry | required |
| **Action** | one button with custom label | storage check, install 7-Zip | none (one-shot) |
| **Group** | optional main button + **Options** expander with sub-actions | bloatware (Remove all + per-app), reinstall | per sub-action, if any |

Ultimate also has a `Console` kind (opens a separate PowerShell window). Nothing uses it any more: drop it.

### Each Toggle row shows
- Name, short description, risk badge, reboot-needed flag
- **Current state**, detected live: Optimized / Default / Unknown
- **Optimize** and **Default** buttons

### Modes
- **GUI**: `Akari.ps1` with no arguments.
- **One-click**: `Akari.ps1 -Preset AkariOS`, the old Akari-OS experience (prep → Safe Mode → tweaks, with reboots handled automatically).
- **CLI**: `-Preset <name>`, `-Config <file>`, `-Apply <id,id>`, `-Revert <id,id>`, `-List`.

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
| Win32PrioritySeparation + SvcHost tuners | `UI/Tuners.ps1` |
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
│  ├─ Config.ps1              # save/load user choices (JSON)
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
│  ├─ Graphics/
│  ├─ Hardware/
│  └─ Advanced/
├─ Presets/
│  ├─ AkariOS.json            # full one-click (replaces Akari-OS repo)
│  ├─ Gaming.json
│  └─ Light.json
├─ UI/
│  ├─ MainWindow.xaml         # carried over from AkariOS-Ultimate
│  ├─ Shell.ps1
│  ├─ Rows.ps1
│  ├─ Home.ps1
│  └─ Tuners.ps1
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
# Tweaks/Optimize/Gaming/Win32PrioritySeparation.ps1
@{
    Id          = 'win32-priority-separation'
    Name        = 'Win32 Priority Separation'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Reboot      = $true
    Description = 'Short, variable quanta with a 3:1 foreground boost (0x26).'
    Registry    = @(
        @{
            Path    = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
            Name    = 'Win32PrioritySeparation'
            Type    = 'DWord'
            Value   = 0x26
            Default = 2          # use $null to mean "delete value on revert"
        }
    )
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
```powershell
@{
    Id = 'bloatware'; Kind = 'Group'; Button = 'Remove all'; ...
    Apply   = { ... }                       # optional main button
    Actions = @(
        @{ Name = 'Xbox apps'; Description = '...'; Button = 'Remove'; Confirm = '...'; Block = { ... } }
    )
}
```

### Fields
| Field | Required | Notes |
|---|---|---|
| `Id` | yes | kebab-case, unique, used by presets and CLI |
| `Name`, `Description` | yes | shown in the GUI |
| `Section`, `Category` | yes | drives sidebar and grouping |
| `Risk` | yes | `Safe` / `Caution` / `Advanced` (badge colours `Mu` / `Warn` / `Bad`) |
| `Kind` | no | `Toggle` (default) / `Action` / `Group` |
| `Button` | no | label for Action / Group main button (default `Run`) |
| `Confirm` | no | text of a Yes/No prompt shown before running |
| `Reboot` | no | default `$false` |
| `SafeMode` | no | `$true` if it must run in Safe Mode |
| `Registry` | one of | data-driven registry changes (Toggle only) |
| `Apply` / `Revert` / `Detect` | one of | script blocks for custom logic |
| `Check` | no | extra "Check" button that only reports status |
| `Actions` | Group only | sub-actions: `Name`, `Description`, `Button`, `Block`, optional `Confirm` |
| `Requires` | no | e.g. `Win11`, `NVIDIA`, `Desktop` to hide irrelevant tweaks |

Loader rules:
- A Toggle without a revert path (`Registry` or `Revert`) is rejected.
- A Toggle without `Detect` (and no `Registry`) loads with a warning: the state falls back to "what Akari last applied", which is wrong after a Windows update or a manual change.
- Script blocks must not be interactive: no `Pause`, `Read-Host`, `Clear-Host`. The runner keeps no-op shims only as a safety net.

---

## 8. Presets & configs

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
- **Save my config** writes the same JSON format from the user's current GUI selection.
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

1. **Repo:** ✅ fresh repo `isleap9/AkariOS` created, `.gitignore` with `_ref/`, reference projects cloned. Next: copy the AkariOS-Ultimate GUI and `Tweaks/` in as the starting point (the commit message credits the source repo; Ultimate's history stays in the archived repo).
2. **Core:** move the engine out of `Akari.ps1` per §5.1 — `Loader`, `Registry`, `Trusted`, `Runner`, `State`, `Log`, `Config`. Keep `Add-Tweak` working as a thin adapter during the port, so the GUI stays usable while categories move one at a time.
3. **Port Ultimate:** the source is the 8 GENERATED files in `Tweaks/` (the numbered folders are already gone). Split each `Add-Tweak` call into its own hashtable file, one category at a time: `Windows`, then `Advanced`, `Hardware`, `Graphics`, `Setup`, `Installers`, `Check`, `Refresh`. Per tweak, clean it up as you go:
   - remove `Pause` / `Read-Host` / `Clear-Host` leftovers;
   - add `Detect` (only 1 of ~47 Toggles has one today);
   - add the missing Reverts, or turn the tweak into an Action if it really is one-shot;
   - replace inline copies of `Run-Trusted` with the `Core/Trusted.ps1` one;
   - convert pure registry bodies (`cmd /c reg add …`) into `Registry` data.
   Delete the `Add-Tweak` adapter when the last category is ported.
4. **Port Akari-OS:** split `akarios.ps1`, `stepone.ps1`, `steptwo.ps1` and `reg.reg` into tweak files; build `Presets/AkariOS.json` and `Core/Phases.ps1`.
5. **GUI:** split `Akari.ps1` into `UI/Shell.ps1`, `UI/Rows.ps1`, `UI/Home.ps1`, `UI/Tuners.ps1`. Rows read Toggle state through `Core/State` (`Detect` first), show the reboot flag, and the sidebar follows the new sections. Rewrite `AGENTS.md` (Ultimate's is GSD-generated and stale).
6. **Build + Release:** `Bundle.ps1` + GitHub Action; move binaries from AkariOS-Files into Releases; `Core/Download.ps1`; retire `IWR.ps1` and `AllowScripts.cmd`.
7. **Archive:** `Akari-OS`, `AkariOS-Files`, Akari Tool (C#), AkariOS-Companion, WinUI toolbox. Add a README line pointing to `isleap9/AkariOS`.

---

## 12. Roadmap

| Milestone | Done when |
|---|---|
| **M1: Engine** | Core extracted from `Akari.ps1`; Loader + Registry + Runner work from CLI: `-List`, `-Apply`, `-Revert` on 3 sample tweaks; GUI still runs through the `Add-Tweak` adapter. |
| **M2: Windows category** | Ultimate's `Windows` category fully ported to one-file tweaks, all Toggles revertible with `Detect`. |
| **M3: GUI** | `Akari.ps1` split into `UI/*.ps1`; rows built from Core/Loader by section, Optimize/Default + live state + reboot flag; Home and tuners unchanged. |
| **M4: One-click** | `-Preset AkariOS` reproduces the old Akari-OS 3-phase run, including reboots and Safe Mode. |
| **M5: Apps** | App removal checklist + WinGet installs. |
| **M6: Release** | Bundled single-file release via GitHub Action, old repos archived. |
| **M7: Polish** | Config save/load, `Requires` filtering, own tweaks added. |

---

## 13. Open questions

- Minimum supported OS: Windows 10 22H2 + Windows 11, or Windows 11 only? (Mica already falls back to solid black on Win10.)
- Laptop handling: hide or warn on desktop-only tweaks (power saving, core parking) when a battery is detected?
- Tuners: keep them as special panels on Advanced (as today), or make them Toggles with a value picker so presets can set them? Recommendation: keep the panels and also add plain Toggles with the recommended value, so presets can use them.
