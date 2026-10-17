# AkariOS: agent guide

PowerShell 5.1 + WPF app that debloats and optimizes Windows 10 22H2 / 11 for gaming. `Akari.ps1` is the entry point (GUI, later also CLI and presets).

- Vocabulary: [`GLOSSARY.md`](GLOSSARY.md). Use its terms in code, comments and docs (Tweak, Toggle, Choice, Action, Group, Entry, Apply, Revert, Default, State, Preset, Run, Outcome).
- Plan and target architecture: [`AkariOS-PLAN.md`](AkariOS-PLAN.md). Decisions: [`docs/adr/`](docs/adr/).

## Current layout (transitional)

The port is in progress. Today the repo is the AkariOS-Ultimate baseline:

- `Akari.ps1`: elevation, `Add-Tweak`, runner, state, and the whole GUI host.
- `Tweaks/*.ps1`: 8 GENERATED category files of `Add-Tweak` calls. Large: open only the tweak you're changing (search for its `-Id`), never the whole file.
- `UI/MainWindow.xaml`, `Assets/`.

Target layout (`Core/`, one-file tweaks under `Tweaks/<Section>/<Category>/`, `UI/*.ps1`, `Presets/`, `Build/`) is in plan §6. Update this section whenever the layout changes.

## Rules

1. One tweak per file. If a file passes ~150 lines, split it. Data-list Groups (same-shape Entries) may be one data file (ADR 0002).
2. Every Toggle and Choice has a Revert to the stock Windows Default (ADR 0001). A Tweak is an Action only when no Default exists; the file says why in one line.
3. No tweak logic in `Core/`. Core = helpers, loader, runner only.
4. The GUI never hard-codes tweaks; it builds from the loader output.
5. Open only the tweak file(s) being changed; don't read the whole `Tweaks/` tree or a bundled `Akari.ps1`.
6. HKCU changes must target the real logged-in user hive, not the elevated/SYSTEM one.
7. Tweak script blocks must not be interactive: no `Pause`, `Read-Host`, `Clear-Host`.
8. Credit upstream sources in `CREDITS.md` when porting a tweak.
9. Never copy code from Winhance (PolyForm Shield). Ideas and layout only.
10. Update this file in the same change whenever the layout or a Core API changes.
11. `_ref/` is reference only: read a file there only when the task names it; never scan it whole, never commit or bundle it.
