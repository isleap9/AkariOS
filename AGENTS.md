# AkariOS: agent guide

PowerShell 5.1 + WPF app that debloats and optimizes Windows 10 22H2 / 11 for gaming. `Akari.ps1` is the entry point (GUI and CLI, later also presets).

- Vocabulary: [`GLOSSARY.md`](GLOSSARY.md). Use its terms in code, comments and docs (Tweak, Toggle, Choice, Action, Group, Entry, Apply, Revert, Default, State, Preset, Run, Outcome).
- Plan and target architecture: [`AkariOS-PLAN.md`](AkariOS-PLAN.md). Decisions: [`docs/adr/`](docs/adr/).

## Current layout (transitional)

The port is in progress (M1 Engine and M2a Manual steps done; plans in `docs/plans/`).

- `Akari.ps1`: CLI branch (`-List`, `-Apply id,id`, `-Revert id,id`; Apply/Revert need an elevated shell), then elevation (the elevated console stays visible: launch banner, live log), Core and tweak loading, and dot-sourcing `UI/*.ps1`.
- `Core/` (dot-sourced function files, no tweak logic):
  - `Log.ps1`: `Write-Log` (GUI queue, printed to Akari's console window, or straight to the console), `Write-ErrLog` (`%LOCALAPPDATA%\Akari\akari.log`).
  - `Compat.ps1`: no-op / dialog shims for legacy tweak bodies (`Write-Host`, `Pause`, `Read-Host`, file pickers). Loaded only in the GUI job.
  - `Trusted.ps1`: `Run-Trusted`.
  - `Registry.ps1`: `Set-Reg`, `Remove-Reg`, `Get-AkariRegValue`, `Resolve-AkariRegPath` (HKCU → real user's `HKEY_USERS\<sid>`), `Invoke-AkariRegistry`, `Get-AkariRegistryState`.
  - `Loader.ps1`: `Get-AkariTweaks <TweaksRoot>` → `@{ Tweaks; Problems }`, `Import-AkariTweakFile`, `ConvertTo-AkariTweak`. Rules in plan §7.
  - `State.ps1`: `Get-AkariState` → Optimized / Default / Custom / Unknown; `Get/Set-AkariRememberedState` (`state.json`).
  - `Runner.ps1`: `Invoke-AkariTweak <tweak> <Mode> [<Value>]` (Value: a Choice value other than Recommended), `Invoke-AkariPlan <@{Id;Mode;Value}[]>` and `Invoke-AkariRun <ids> <Mode>` → one Outcome per item; `Start-AkariJob <code> <queue> <CoreDir> [<Shared>]` (GUI background runspace with Core loaded; `$AkariShared` hands objects back).
  - `Restore.ps1`: `New-AkariRestorePoint` → `@{ Ok; Message }`, never throws (enables System Protection and lifts the 24 h throttle for one retry).
  - `Legacy.ps1`: `Add-Tweak` adapter + `Import-AkariLegacyTweaks`. Delete when the port is finished.
- `OneClick/`: the old Akari-OS one-click run, imported as-is from `isleap9/Akari-OS` (`akarios.ps1` → `stepone.ps1` in Safe Mode → `steptwo.ps1`, plus `reg.reg`, `start2.txt`, `settimerresolutionservice.cs`, `img.jpg`). Started by Install AkariOS → One-click: the window closes and the run continues in Akari's console (no new window). Only change from upstream: `akarios.ps1` copies these files from its own folder instead of downloading them. Keep it working as-is until the M4 port replaces it.
- `Tweaks/<Section>/<Category>/*.ps1`: one-file tweaks (format in plan §7).
- `Tweaks/*.ps1`: 8 GENERATED legacy category files of `Add-Tweak` calls, loaded through `Core/Legacy.ps1`. Large: open only the tweak you're changing (search for its `-Id`), never the whole file.
- `Tests/`: Pester 3.4. Run `powershell -NoProfile -ExecutionPolicy Bypass -File Tests\Run.ps1`. Fixtures in `Tests/Fixtures/`.
- `UI/` (GUI only, dot-sourced in this order by `Akari.ps1`):
  - `Selection.ps1`: pending changes of the Manual steps (`Set-AkariPending`, `Get-AkariReviewItems`, `Get-AkariPlanItems`, `Get-AkariConfirmText`, `Get-AkariNextToggle`). No WPF.
  - `Cards.ps1`: `New-AkariCard` (switch / combobox / checkbox setting card), `Set-AkariCardControl`, `Get-AkariComboValue`.
  - `Steps.ps1`: the Install AkariOS page: One-click / Guided chooser, then Guided Apps → Tweaks → Review & Apply → result; `New-AkariModeCard` (big tile); `Get-AkariStepGroups` and `Get-AkariRunSummary` are pure.
  - `Shell.ps1`: window, Home tiles (no sidebar on Home), sidebar, search, `Show-Page`, status bar, job timer. `Rows.ps1`: Manual mode (Optimize tile), the legacy rows that act right away. `Home.ps1`: spec cards (hidden for now).
  - `MainWindow.xaml` (shell), `Controls.xaml` (WinUI-style styles: `Switch`, `Combo`, `Check`, `SettingCard`, `Section`, `Accent`, `StepDot`).
- `Assets/`, `CREDITS.md`.

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
