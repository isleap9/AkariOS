# AkariOS

## What This Is

AkariOS is a guided Windows setup app that wraps FR33THY's **WinSux** script collection in a native
Windows 11-styled GUI (WPF, Mica backdrop, dark theme), and rebrands the resulting machine as
"AkariOS". WinSux ships as three sequential PowerShell scripts that must survive two reboots and a
Safe Mode session; AkariOS turns that into a click-through installer with per-stage progress that
resumes itself automatically after each reboot.

It is a power-user tool for a clean, debloated, performance-tuned Windows install — not a
general-purpose tweaker.

## Core Value

The user clicks **Install AkariOS** once, and the machine walks itself through all three WinSux
stages across the reboots with visible progress — no console menus, no typed numbers, no
re-launching anything by hand.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can launch AkariOS Setup and see the WinSux flow as a staged, visual install (not a console menu)
- [ ] User can start the full one-shot install with a single click, and it survives all reboots unattended
- [ ] User can run any individual WinSux stage on its own (power-user path)
- [ ] Installer auto-resumes after each reboot and shows "Step N of 3 in progress"
- [ ] User can see per-stage progress and current status in the UI at all times
- [ ] Installer gates the destructive stages behind an explicit confirmation (restore point + typed acknowledgment)
- [ ] Installer rebrands the machine as AkariOS (OEM info, logo, wallpaper, system branding)
- [ ] Stage 1's Safe Mode pass runs as a console script launched by the GUI, and the GUI resumes afterwards

### Out of Scope

- The 8 FR33THY **Ultimate** tweak tabs from AkariTool — AkariOS is the WinSux install flow only, not a general tweak panel
- Bundling payloads locally — downloads happen at runtime from FR33THY's releases, same as WinSux, to keep the compiled script small
- Running the WPF GUI inside Safe Mode — stage 1 stays a console script; WPF rendering in safe mode is unreliable
- Reimplementing WinSux's tweak logic natively — the underlying registry/service/AppX work is taken 1:1 from WinSux's scripts

## Context

**The two reference sources in this repo:**

- `WinSux-main/WinSux/` — the engine being wrapped. Three scripts plus payload files:
  - `winsux.ps1` (234 lines) — **Stage 1**. Downloads 7zip, VC++ redists (2005–2022, x86+x64), DDU,
    Helium, DirectX; installs 7zip silently and sets its context-menu config; installs Helium with
    policies and strips its services/tasks; removes UWP apps and sets the Terminal delegation keys;
    writes `RunOnce` entries for `stepone.ps1` (safe boot) and `steptwo.ps1` (normal boot); sets
    `bcdedit /set {current} safeboot minimal`; reboots.
  - `stepone.ps1` (153 lines) — **Stage 2**, runs in **Safe Mode as TrustedInstaller**. The
    `Run-Trusted` helper temporarily repoints the TrustedInstaller service's `binPath` to a base64
    `powershell -encodedcommand`, starts it, then restores the original path. Uses it to write
    Defender/security settings that Windows otherwise reverts. Then disables UAC, removes the safe
    boot flag, and runs DDU to wipe GPU/audio drivers with `-Restart`.
  - `steptwo.ps1` (1224 lines) — **Stage 3**, normal boot. Removes Edge (incl. WebView + legacy
    DISM package), UWP apps, Windows capabilities/optional features, legacy apps (brlapi, GameInput,
    OneDrive, RDC, Snipping Tool); Store + Windows settings; privacy/app-permission fixes; per-device
    power, wake, and write-cache settings; black wallpaper + lockscreen; context-menu cleanup; Start
    menu layout (both Win10 XML and Win11 `start2.bin`); the Ultimate power plan (duplicated as
    `99999999-…`) with ~100 powercfg values; the `Set Timer Resolution Service` (compiled at runtime
    from `settimerresolutionservice.cs`); disk cleanup; restore point; reboots.
  - Payload files: `reg.reg` (1494 lines, imported in stage 3), `start2.txt` (96 lines, base64 Win11
    Start layout, decoded via `certutil`), `settimerresolutionservice.cs` (194 lines).

- `AkariTool/` — the **UI shell being reused**, and the build pattern being copied:
  - `Compile.ps1` concatenates sources in a fixed order into one self-contained `akari.ps1`:
    `scripts/start.ps1` → `functions/private/*` → `functions/public/*` → `config/*.json` (as
    `$sync.configs.*`) → base64 assets → `xaml/MainWindow.xaml` with `xaml/panels/*.xaml` spliced in
    at the `<!-- @PANELS@ -->` marker (as the `$inputXML` here-string) → `scripts/main.ps1`.
  - `scripts/start.ps1` — admin elevation (with an `irm <url> | iex` fallback), a
    `SetCurrentProcessExplicitAppUserModelID` call for its own taskbar identity, console-window
    hiding, WPF assembly loading, DWM P/Invoke for Mica + dark title bar, and the synchronized
    `$sync` state hashtable.
  - `scripts/main.ps1` — `XamlReader.Parse`, registers every named control into `$sync`, decodes the
    embedded logo, applies Mica on `Loaded`, wires sidebar nav (`$panels` / `$navMap`), auto-wires
    every `Btn*` control to a matching `Invoke-<name>` function, builds a global search card index,
    implements the hamburger sidebar collapse, and provides `Set-Status` for runspaces to post to the
    status bar.
  - `functions/private/Invoke-RunInBackground.ps1` — the non-blocking runspace runner (keeps the
    window responsive during long operations).
  - `xaml/MainWindow.xaml` + `xaml/panels/NN-Name.xaml` — the shell (styles, titlebar, sidebar nav,
    status bar) and per-tab fragments sorted by `NN-` prefix at build time.

**Why the reboots are the hard part.** WinSux's stages are not a normal sequence — stage 1 ends by
setting the safe-boot flag and rebooting, stage 2 runs in Safe Mode and reboots again, stage 3 runs
in normal boot and reboots a final time. `RunOnce` entries are what carry the flow forward. A GUI
installer has to persist its own state across those boundaries (which stage is next, what the user
selected) and bring itself back up so the user sees "Step 2 of 3" instead of a console window.

## Constraints

- **Tech stack**: WPF via PowerShell (no compiled .NET assembly) — AkariOS must stay a single
  self-contained `.ps1`, following AkariTool's `Compile.ps1` pattern. No external dependencies to
  install.
- **Compatibility**: Windows 10 and 11, Home / Pro / LTSC / IoT / Server — the same matrix WinSux
  supports. Mica is Win11-only; the shell already degrades gracefully to its dark fallback.
- **Administrator**: required. The app self-elevates on launch, as AkariTool and WinSux both do.
- **Dependencies**: Internet access at runtime (payload downloads); `winget` not required for the
  WinSux flow itself; 7-Zip is installed by the flow and then used to extract DDU and DirectX.
- **Payload policy**: download at runtime from FR33THY's release URLs rather than bundling, to keep
  the compiled script small.
- **Provenance**: the tweak logic is WinSux's, taken 1:1. AkariOS is the shell, the flow state
  machine, and the rebranding layer — not a reimplementation.
- **Destructive by nature**: the flow disables Defender, UAC, memory integrity, VBS, and the
  vulnerable-driver blocklist, and wipes GPU/audio drivers. Confirmation gating is a requirement, not
  a nicety.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Guided installer for WinSux's 3-stage flow, not a general tweak panel | The deliverable is an install experience; AkariTool's 8 Ultimate tabs are a different product | — Pending |
| New AkariOS project at repo root; `WinSux-main/` and `AkariTool/` are read-only reference | Keeps the sources of truth intact while the new app is built cleanly on top | — Pending |
| Reuse AkariTool's shell (MainWindow.xaml, Compile.ps1, start/main.ps1) rather than writing fresh XAML | The visual style and the whole build/wiring pipeline already work; only the panels and the flow are new | — Pending |
| Rebrand Windows itself to AkariOS (OEM info, logo, wallpaper, branding) | "Rebrand to AkariOS" was meant literally, not as just an app name | — Pending |
| Auto-resume across reboots via persisted state + `RunOnce` | Matches the one-click promise; manual relaunch defeats the point | — Pending |
| Stage 1's Safe Mode pass stays a console script launched by the GUI | WPF rendering in Safe Mode is unreliable; WinSux's approach already works | — Pending |
| Download payloads at runtime instead of bundling | Keeps the compiled single file small, same as WinSux | — Pending |
| Gate destructive stages behind restore point + typed acknowledgment | The flow removes security features and wipes drivers; silent execution is unacceptable | — Pending |
| Compiled output is `akarios.ps1`, app title "AkariOS Setup" | Distinct identity from the AkariTool it borrows its shell from | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-10-04 after initialization*
