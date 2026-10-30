# AkariOS

AkariOS debloats and optimizes Windows 10 22H2 and Windows 11 for gaming. It removes the apps you don't want, turns off
telemetry and background noise, and tunes Windows, the graphics driver and your input devices. You see every change
before it happens, and almost every change can be put back to the Windows default.

## Run it

Open PowerShell and paste:

```powershell
iwr 'https://github.com/isleap9/AkariOS/releases/latest/download/Akari.ps1' -useb | iex
```

This downloads the latest release, checks it against its SHA-256, unpacks it to `%LOCALAPPDATA%\Akari\app` and starts
AkariOS. It asks for administrator rights.

Or download `AkariOS-<version>.zip` from [Releases](https://github.com/isleap9/AkariOS/releases), unpack it and run
`Akari.ps1` (right-click > Run with PowerShell; `AllowScripts.cmd` turns on running scripts if Windows blocks it).
A folder install updates itself from the About page.

**Needs:** Windows 10 22H2 or Windows 11, Windows PowerShell 5.1 (built in), an administrator account. Run it on a
PC you can reinstall, ideally a fresh install, the first time.

## What's inside

- **Install AkariOS**
  - **One-click**: the full AkariOS setup in one go (apps, drivers, Safe Mode, tweaks), restarts handled for you. For a
    fresh install.
  - **Guided**: pick the apps to remove and the tweaks to apply, review every change, then apply them in one go.
- **Optimize › Advanced**: every tweak by category (Optimize, Customize, Graphics & Hardware, Advanced, Tools), each
  change applied right away. Also Remove apps and Downloads.
- **Downloads**: browsers, launchers, runtimes, tools and chat apps, mostly through winget, and Store apps the debloat
  removed.
- **Install USB**: an `autounattend.xml` for a Windows install USB (accounts, language, edition, disk, bloatware), after
  Christoph Schneegans' generator.
- **Import / Export settings**: save this PC's settings to a file and load them on another PC, reviewed in Guided
  before anything changes.

## Safety

- A Windows restore point is made before the first change of a session.
- Every tweak that changes a setting has a Revert to the stock Windows default. Actions (installs, cleanups, checks)
  can't be undone and say so before they run.
- One-click and some Advanced tweaks lower security on purpose (Defender settings, UAC, memory integrity). They say so
  and ask first.

## Command line

From an elevated PowerShell in the AkariOS folder:

```powershell
.\Akari.ps1 -List                         # every tweak id
.\Akari.ps1 -Apply id1,id2                # apply tweaks
.\Akari.ps1 -Revert id1,id2               # put them back to the Windows default
.\Akari.ps1 -Preset AkariOS               # a preset by name, or a .json file (an exported settings file works too)
.\Akari.ps1 -RevertPreset my-settings.json
```

## Credits and license

AkariOS builds on FR33THY's Ultimate and WinSux, ZOICWARE, Win11Debloat, Christoph Schneegans' unattend generator and
others: see [CREDITS.md](CREDITS.md) for each tweak's source. MIT license: [LICENSE](LICENSE).

## Development

- `src/` is what AkariOS runs from (`Akari.ps1`, `Core/`, `UI/`, `Tweaks/`, `Presets/`, `OneClick/`, `Assets/`); the
  release zip ships it as one `AkariOS\` folder.
- `tests/`: Pester 3.4, `powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run.ps1` (tests never change this
  PC: they use test registry keys, TestDrive and mocks).
- `build/Bootstrap.ps1`: the one-liner's script; `.github/workflows/release.yml` publishes a release on a `v*` tag.
- `docs/`: the plan, the glossary, decisions (ADRs) and milestone plans. [AGENTS.md](AGENTS.md) is the guide for
  contributors and coding agents.
