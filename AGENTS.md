# AkariOS: agent guide

PowerShell 5.1 + WPF app that debloats and optimizes Windows 10 22H2 / 11 for gaming. `Akari.ps1` is the entry point (GUI and CLI, later also presets).

- Vocabulary: [`GLOSSARY.md`](GLOSSARY.md). Use its terms in code, comments and docs (Tweak, Toggle, Choice, Action, Group, Entry, Apply, Revert, Default, State, Preset, Run, Outcome).
- Plan and target architecture: [`AkariOS-PLAN.md`](AkariOS-PLAN.md). Decisions: [`docs/adr/`](docs/adr/).

## Current layout (transitional)

The port is in progress (M1 Engine done; plan in `docs/plans/`).

- `Akari.ps1`: CLI branch (`-List`, `-Apply id,id`, `-Revert id,id`; Apply/Revert need an elevated shell), then elevation and the whole GUI host.
- `Core/` (dot-sourced function files, no tweak logic):
  - `Log.ps1`: `Write-Log` (GUI queue or console), `Write-ErrLog` (`%LOCALAPPDATA%\Akari\akari.log`).
  - `Compat.ps1`: no-op / dialog shims for legacy tweak bodies (`Write-Host`, `Pause`, `Read-Host`, file pickers). Loaded only in the GUI job.
  - `Trusted.ps1`: `Run-Trusted`.
  - `Registry.ps1`: `Set-Reg`, `Remove-Reg`, `Get-AkariRegValue`, `Resolve-AkariRegPath` (HKCU → real user's `HKEY_USERS\<sid>`), `Invoke-AkariRegistry`, `Get-AkariRegistryState`.
  - `Loader.ps1`: `Get-AkariTweaks <TweaksRoot>` → `@{ Tweaks; Problems }`, `Import-AkariTweakFile`, `ConvertTo-AkariTweak`. Rules in plan §7.
  - `State.ps1`: `Get-AkariState` → Optimized / Default / Custom / Unknown; `Get/Set-AkariRememberedState` (`state.json`).
  - `Runner.ps1`: `Invoke-AkariTweak`, `Invoke-AkariRun` → one Outcome per id; `Start-AkariJob` (GUI background runspace with Core loaded).
  - `Legacy.ps1`: `Add-Tweak` adapter + `Import-AkariLegacyTweaks`. Delete when the port is finished.
- `Tweaks/<Section>/<Category>/*.ps1`: one-file tweaks (format in plan §7).
- `Tweaks/*.ps1`: 8 GENERATED legacy category files of `Add-Tweak` calls, loaded through `Core/Legacy.ps1`. Large: open only the tweak you're changing (search for its `-Id`), never the whole file.
- `Tests/`: Pester 3.4. Run `powershell -NoProfile -ExecutionPolicy Bypass -File Tests\Run.ps1`. Fixtures in `Tests/Fixtures/`.
- `UI/MainWindow.xaml`, `Assets/`, `CREDITS.md`.

Target layout (`UI/*.ps1`, `Presets/`, `Build/`, `Core/Phases`, `Core/Presets`, …) is in plan §6. Update this section whenever the layout changes.

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
12. Never launch the GUI or run the CLI on the developer's real machine, in tests or by hand. Tests use fixture tweaks, `HKCU:\Software\AkariTest\<guid>` and `TestDrive:`; CLI tests use `-List` or fake ids. The user does all real testing on a VM — never on the developer's machine.
