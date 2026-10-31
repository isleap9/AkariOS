# A second, native app in the same repo, sharing the PowerShell app's data

Decided 2026-10-31 (plan `docs/plans/2026-10-31-native-app.md`). AkariOS gets a second front end and engine:
**the native app**, in `app/`, fully C# (WPF on .NET 10 LTS, CommunityToolkit.Mvvm, MVVM), with no PowerShell
engine. **The PowerShell app** in `src/` stays as it is and keeps shipping; neither replaces the other, and a later
ADR would be needed to retire either one. Both ship from the same release, under the same version.

The two share data instead of drifting:

- **Tweaks**: the native app reads `src/Tweaks/**/*.ps1` itself, through a C# reader of the PowerShell data subset
  (hashtables, arrays, strings, numbers, `$true` / `$false` / `$null`, casts such as `[uint64]`). Every file gives its
  metadata (Id, Name, Section, Category, Risk, Description, Requires, AkariOS, ...). A data-only file (Registry rows,
  Choices) is a complete Tweak for the native engine; a file with script blocks gets its behaviour from a C# class in
  `AkariOS.Tweaks` registered under the same id. A registry fix is made once, in `src/Tweaks`.
- **Data lists** (`Appx.psd1`, `services.psd1`, `tasks.psd1`, the Defender `.psd1` files, `Iso/Data/`, ...) are read
  as they are by the same reader; `OneClick/reg.reg` by a C# `.reg` reader. Nothing is converted.
- **Presets**: `src/Presets/*.json` as they are, the same entry forms, the same Export format; both apps read and
  save `%LOCALAPPDATA%\Akari\presets`, so an export from one imports in the other. Everything else the native app
  keeps to itself (`%LOCALAPPDATA%\AkariOS.Native`, `%ProgramData%\AkariOS.Native`): its log, State, settings and
  `run.json`, so neither app resumes the other's Run in phases.
- **Look**: `src/UI/Theme.Dark.xaml`, `Theme.Light.xaml`, `Icons.xaml`, `Motion.xaml` and `Controls.xaml` loaded as
  they are (a C# port of `Get-AkariXaml`, which also respects Windows' animation-effects setting), plus
  `src/Assets` (fonts, logos, app icons). The window's own styles in `MainWindow.xaml` are copied once into `app/`;
  a test keeps their keys equal.
- **A parity test** lists the Tweak ids each app has that the other lacks (`app/parity.txt`, checked in): the
  PowerShell-only side is the native port's checklist.

Rules carry over: the Glossary's terms, one Tweak per unit (one C# class per script-block Tweak), every Toggle and
Choice reverts to the Windows Default (ADR 0001), HKCU goes to the real logged-in user's hive, native tools
(`bcdedit`, `powercfg`, `winget`, ...) only through one wrapper each, mocked in tests, and nothing runs on the
developer's machine (AGENTS.md rule 12). Everything else is native API: `Microsoft.Win32.Registry`, the service
control manager, the Task Scheduler COM API, `Windows.Management.Deployment.PackageManager`, the DISM API. Legacy
(ADR 0004) is the PowerShell app's only; the native app has no Legacy pages.

Why: a native exe starts fast, ships as one self-contained file, needs no execution policy, and avoids
PowerShell 5.1's limits (stderr handling, slow provider reads, runspaces for every background step). Keeping the
PowerShell app keeps what already passed on the VM and the users who run the one-liner. Sharing the Tweak files and
data lists is what keeps two apps affordable: a second copy of 236 registry Tweaks would drift within weeks.

## Considered Options

- **WinUI 3**: rejected. The app always runs as admin (WinUI's elevated support is limited), it debloats the
  Store / Appx packages the Windows App SDK runtime depends on, and it must ship as one self-contained exe.
- **Replace the PowerShell app**: rejected for now; it is released, tested on the VM and has users.
- **The native app hosts PowerShell for script-block Tweaks**: rejected; it brings back the engine the native app
  is meant to drop, and its limits.
- **Native copies of the Tweaks and data lists (JSON)**: rejected; every fix twice, and the copies drift.
- **Convert the shared lists to JSON for both apps**: rejected; it rewrites working PowerShell loaders and loses
  the files' comments (sources, notes) for no gain the C# reader doesn't give.
- **Porting AkariOS-Companion, or code from Winhance**: rejected (Winhance is PolyForm Shield; Companion is a
  separate code base).

## Consequences

- A data file in `src/` has two readers. Its shape changes only with the C# reader in the same change; the native
  tests load every file under `src/Tweaks` and fail on anything the reader can't take.
- A new script-block Tweak in `src/Tweaks` lands in `app/parity.txt` (PowerShell only) until it gets its C# class.
- The release builds both apps; a failing native build or test stops the release.
- `src/` files the native app reads (Tweaks, data lists, Presets, the shared XAML, Assets) are embedded in the exe
  at build time; the exe reads nothing next to it.
