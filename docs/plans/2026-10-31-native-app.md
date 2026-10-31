# Native app: plan

**Goal:** A second AkariOS app in `app/`, fully native C# WPF with no PowerShell engine, that reads the PowerShell
app's Tweak files, data lists and presets as they are, looks and moves the same, and ships as one self-contained exe
next to the PowerShell zip. The PowerShell app in `src/` stays as it is and keeps shipping (ADR 0007).

**Architecture:** `app/AkariOS.Native.sln`. `AkariOS.Core` (engine, no WPF, no Tweak logic): the PowerShell data
reader, Loader, Registry engine, State, Runner, Presets, Runs in phases, the native wrappers. `AkariOS.Tweaks`: one C#
class per Tweak whose `src/Tweaks` file has script blocks, registered under that file's id, plus the data-list Group
kinds (AppxRemove, CapabilityRemove, FeatureDisable, StoreInstall). `AkariOS.App` (WPF, MVVM through
CommunityToolkit.Mvvm): views, view models, the motion service, the CLI entry. Tests in `app/tests/`.

**Tech Stack:** .NET 10 (LTS), `net10.0-windows10.0.19041.0` (the PackageManager projection; Windows 10 22H2 and up),
WPF, CommunityToolkit.Mvvm, xUnit v3. Published `win-x64`, self-contained, single file, compressed.

**Spec:** ADR 0007; `docs/GLOSSARY.md`; `docs/PLAN.md` §4, §7 (Tweak file format and loader rules), §8 (Presets);
ADR 0001, 0002, 0005, 0006; the motion plan `docs/plans/2026-10-31-motion-polish.md`; AGENTS.md (the PowerShell
Core APIs are the behaviour to match).

## Decisions (2026-10-31)

- **Name and release.** The exe is `AkariOS-Native.exe` (the PowerShell launcher stays `AkariOS.exe`). Same version
  as the PowerShell app: the projects read `$AkariVersion` from `src/Core/Version.ps1` at build time (an MSBuild
  property function), so there is one version to bump. The `v<version>` release carries `AkariOS-<version>.zip`,
  `Akari.ps1` and `AkariOS-Native.exe` (a fixed name, so `releases/latest/download/AkariOS-Native.exe` always works;
  the PowerShell updater only picks `AkariOS-*.zip`, so the exe doesn't confuse it).
- **Portable.** No installer; run it from anywhere. It updates itself from the About page (N4): the latest release's
  exe, checked against GitHub's SHA-256 digest, swapped by a small helper after the app exits (old exe kept as `.old`
  until the new one starts). A Run in phases first copies the exe to `%ProgramData%\AkariOS.Native\AkariOS-Native.exe`
  and registers that copy for the resume, so a moved or deleted download doesn't break it.
- **Shared Tweaks.** The native Loader reads every `src/Tweaks/<Section>/<Category>/*.ps1` (not the Legacy
  `Tweaks/*.ps1`, not `Ported.psd1`: no Legacy pages, ADR 0004 stays PowerShell-only) through `PsData`, a C# reader of
  the PowerShell data subset: `@{}` (newline or `;` separated), `@()` and comma lists, single- and double-quoted
  strings (no `$` expansion, `` ` `` escapes only), decimal and hex numbers (a hex DWord compares unsigned, as in
  Core), `$true` / `$false` / `$null`, the casts `[uint64]` `[int]` `[long]` `[byte[]]`, comments, and one call:
  `(Import-PowerShellDataFile "$PSScriptRoot\<file>.psd1").<Key>` (the data-list Groups). A script block is read as
  opaque text: the file still gives its metadata, and its behaviour comes from `AkariOS.Tweaks`. Anything else the
  reader rejects is a Problem naming the file and line, like the PowerShell loader's.
- **Shared data lists.** The same reader for `services.psd1`, `tasks.psd1`, `defender-settings.psd1`,
  `defender-off.psd1`, `do-not-disturb.psd1`, `Appx.psd1`, `Capabilities.psd1`, `Features.psd1`, `StoreApps.psd1`,
  `Iso/Data/**`, `UI/Unattend.psd1`, `UI/About.psd1`; a C# `.reg` reader for `OneClick/reg.reg` and the Store's `.reg`
  text. Nothing is converted to JSON; the files keep their comments.
- **Embedded.** The build embeds what the app reads from `src/` (Tweaks with their `Files/`, the data lists,
  `Presets/`, `OneClick/`, the shared XAML, `Assets/`) through linked `EmbeddedResource` items; `IAkariSource` reads
  them from the exe in a release and from the repo's `src/` in tests. Files a Tweak hands to a tool (a Profile
  Inspector profile, `settimerresolutionservice.cs`, `img.jpg`) are written out to
  `%ProgramData%\AkariOS.Native\Files\` first.
- **User data.** Shared: `%LOCALAPPDATA%\Akari\presets` (both read and save it; same JSON). The native app's own:
  `%LOCALAPPDATA%\AkariOS.Native\` (`akari.log`, `state.json`, `lastused.json`, `settings.json`) and
  `%ProgramData%\AkariOS.Native\run.json`. Neither app resumes the other's Run.
- **Shared look.** Loaded as they are from `src/UI`: `Theme.Dark.xaml`, `Theme.Light.xaml`, `Icons.xaml`,
  `Motion.xaml`, `Controls.xaml`, through `AkariXaml.Load` (a port of `Get-AkariXaml`: the Motion entries first, every
  Duration `0:0:0` when Windows' animation effects are off or `AKARI_MOTION=off`). `MainWindow.xaml`'s window styles
  (`Btn`, `BtnP`, `Ghost`, `Flat`, `Tab`, `Chip`, `FocusRing`, `FocusBox`, menus, scroll bars, tooltips) are read
  out of its `Window.Resources` at startup (`AkariXaml.WindowStyles`; decided 2026-10-31 instead of a copy). Fonts and logos from
  `src/Assets`. Same rules as the PowerShell UI: brushes only through `DynamicResource` / `SetResourceReference`,
  animations only on Opacity and transforms, only through `Motion` (`Fade`, `Rise`, `Pop`, `Scale`, `Slide`, `Fill`,
  entrance, stagger, smooth scroll, sliding pills).
- **Parity.** A test lists, by id, what each app has that the other lacks: **PowerShell only** = a `src/Tweaks` file
  with script blocks and no C# class; **Native only** = a C# Tweak with no `src/Tweaks` file. The list is
  `app/parity.txt` (checked in); the test fails when it differs and rewrites it when `AKARI_UPDATE_PARITY=1`. The
  PowerShell-only side is the porting checklist. A C# class whose file is data-only is an error (the data already
  defines it).
- **Unattend Generator.** Christoph Schneegans' generator is C# (MIT): the native app vendors his library source at a
  pinned commit in `app/ThirdParty/UnattendGenerator/` (his license next to it, credited), with his data files, and
  runs the same fixtures as `tests/Unattend.Tests.ps1` (`tests/Fixtures/Unattend/`). The form reads
  `src/UI/Unattend.psd1` like the PowerShell page.

## Global Constraints

- Glossary terms in code, UI text and logs: Apply / Revert, Outcome `Applied` `Reverted` `Already` `Skipped`
  `Failed`, State `Optimized` `Default` `Custom` `Unknown`, Risk `Safe` `Caution` `Advanced`, Kind `Toggle` `Choice`
  `Action` `Group`, Entry ids `<group-id>/<name>`.
- One Tweak per unit: one C# class per script-block Tweak, in `AkariOS.Tweaks/<Section>/<Category>/<Name>.cs`, the
  folder as the `src/Tweaks` file's. Its metadata comes from the `src/Tweaks` file, never repeated in C#.
- Every Toggle and Choice reverts to the Windows Default (ADR 0001). An Action says why in one comment line.
- No Tweak logic in `AkariOS.Core`. The GUI builds from the Loader's output, never from hard-coded Tweaks.
- HKCU rows go to the real logged-in user's `HKEY_USERS\<sid>` (the console session's Explorer owner), saved in the
  Run for later phases.
- Native tools only through one wrapper each, an interface in `AkariOS.Core` that tests fake: `IBcdEdit`,
  `IPowerCfg`, `IShutdown` (restart, firmware restart), `IWinget`, `IW32tm`, `IWevtutil`, `ICleanMgr`, `IPnpUtil`,
  `IOscdimg`, `IExe` (7-Zip, lodctr, DDU). Native APIs behind interfaces too: `IRegistry` (with the test root),
  `ITrustedInstaller`, `IServiceManager`, `ITaskScheduler`, `IPackageManager`, `IDism`, `IRestorePoint`, `IGitHub`,
  `IHttp`.
- Never run the app, the CLI or the engine on the developer's machine (AGENTS.md rule 12). Tests use
  `HKCU\Software\AkariTest\<guid>` (the `IRegistry` test root redirects HKLM and HKCU rows there), temp folders and
  fakes; no test touches a real service, task, package, feature or boot setting.
- No code from Winhance (PolyForm Shield) or AkariOS-Companion. Credit upstream sources in `CREDITS.md`.
- `bin/` and `obj/` git-ignored. Nullable on, warnings as errors.
- Building needs the .NET 10 SDK (installed 2026-10-31, 10.0.403); tests run with
  `dotnet test --solution app\AkariOS.Native.sln`.

## Review Focus

1. **The reader against the real files.** A test loads every file under `src/Tweaks` (and every shared data list):
   zero Problems, the same ids, Sections, Categories and Registry rows the PowerShell loader reports (read live:
   `app/tests/AkariOS.Core.Tests/Oracle/*.ps1` run the PowerShell app's own readers and Loader, so nothing goes stale;
   decided 2026-10-31 instead of a checked-in fixture).
2. **Registry rows compare as Core compares them.** Hex DWords unsigned, ExpandString expanded, Binary from hex
   text, key rows (`'Key'` / `$null`), per-OS Defaults, `(default)` values, `HKLM:\SOFTWARE\Classes\*` taken
   literally. Shared fixtures: the same rows give the same State in both apps.
3. **Elevated as another admin.** HKCU rows land in the logged-in user's hive, in every phase of a Run.
4. **Presets round-trip.** A preset saved by either app loads in the other with the same Items; an Export from one
   imports in the other.
5. **No test reaches the system.** Every wrapper and API interface faked; a test fails if a real implementation is
   constructed under test.

---

## N0: Scaffold (done 2026-10-31: 19 tests; .NET 10's `dotnet test` needs the Microsoft Testing Platform runner, set in `app/global.json`)

**Files:** `app/AkariOS.Native.sln`, `app/Directory.Build.props`, `app/AkariOS.Core/`, `app/AkariOS.Tweaks/`,
`app/AkariOS.App/` (`app.manifest`: `requireAdministrator`, PerMonitorV2, Windows 10 / 11 supportedOS),
`app/tests/AkariOS.Core.Tests/`, `app/tests/AkariOS.Tweaks.Tests/`, `app/tests/AkariOS.App.Tests/`,
`app/parity.txt` (empty), `.gitignore` (`app/**/bin/`, `app/**/obj/`, `.vs/`, `*.user`),
`.github/workflows/native.yml` (build and test on pushes touching `app/` or the `src/` files it reads; Windows runner).

- `Directory.Build.props`: target framework, `Version` from `src/Core/Version.ps1`, nullable, warnings as errors,
  the embedded `src/` items.
- `AkariOS.App` builds an empty window with the shared resources merged, and `--version` prints the version.
- Done when: the solution builds and its (empty) tests pass in Actions; nothing is run on this machine.

## N1: Core engine and CLI (done 2026-10-31, passed on the VM; 239 tests)

The engine of `src/Core` for Toggles, Choices and Actions without the GUI. TDD, one area per batch.

1. **`PsData`** (the reader): the subset above, positions in errors, a test per construct, then the whole-tree test.
   Done 2026-10-31 (`AkariOS.Core/Data/`). Also read: top-level `$name = value` assignments put into later `$name` /
   `"$name\…"` (the ZOICWARE context-menu Tweaks); a `foreach` or any other expression is kept as `PsCode`. Checked
   against PowerShell itself: `Oracle/Export-PsData.ps1` reads all 418 shared files the PowerShell app's way and
   every value agrees. Of the 388 one-file Tweaks, 226 are data only, 162 have code (all of Tools, Hardware and
   OneClick; Apps 35, Customize 38, Optimize 23, Advanced 9).
2. **`RegReader`**: `.reg` text (REGEDIT5 and 4, hex, hex(2) / (7) / (b), `-` deletes, line continuations).
   Done 2026-10-31 (`AkariOS.Core/Data/RegReader.cs`): every hex(n) type (a Store app's own types kept as bytes),
   UTF-16 or UTF-8 files, paths as Tweak rows write them. Checked against the PowerShell app's readers on
   `reg.reg` (tests/RegFile.ps1) and the Store settings (`ConvertFrom-AkariRegExport`).
3. **Loader**: `Tweak` (Id, Name, Description, Section, Category, Kind, Risk, Reboot, Restarts, SafeMode, Explorer,
   Requires, AkariOS, Guided, Button, Confirm, Registry rows, Choices, Recommended, Default, Editable, Winget,
   WingetSource, AppType, EntryKind, ...: the §7 fields), the loader rules (folder = Section / Category, Toggle
   without a revert path rejected, `Requires` known, kebab-case unique ids, one owner per registry value with the
   owner index), Groups and Entries (`New-AkariEntry`, `Keep` / `KeepNames`), `ITweakBehaviour` registered by id from
   `AkariOS.Tweaks`. The parity test and `app/parity.txt`.
   Done 2026-10-31 (`AkariOS.Core/Tweaks/`, `AkariOS.Core/Sources/`): every rule of `Loader.ps1`; the C# is
   `ITweakCode` + `[TweakCode("id")]` (its members come with State and the Runner); the files come through
   `ISourceFiles` (embedded, a folder, memory). Checked against `Get-AkariTweaks` on the real tree: the same Tweaks
   in the same order with the same fields, Groups and Problems. A registry row with code in it (a `foreach`,
   `(& $w11 'Key')`) is the C#'s to give, so the native owner check doesn't see it (the PowerShell one does).
   `parity.txt`: 162 Tweaks and the 4 data-list Groups (their kinds come in N5).
4. **Registry engine**: `IRegistry` over `Microsoft.Win32.Registry` (64-bit view), the real user's hive
   (`UserHive`), rows Apply / Revert / State, key rows, `ITrustedInstaller` (the TrustedInstaller service's token,
   impersonated on one thread) for rows an admin can't write.
   Done 2026-10-31 (`AkariOS.Core/Registry/`): `RegistryEngine` over `IRegistryPaths` (`LiveRegistryPaths` with
   `RealUserSid`, `RedirectedRegistryPaths` for tests), `TrustedInstaller`, and `SystemGuard` (the real ones throw
   when made under test). Checked against `Core\Registry.ps1` on the same rows in one test key: each app reads what
   the other wrote as the same State. Not tested here, only on the VM: the real user's SID and TrustedInstaller.
5. **State**: Optimized / Default / Custom / Unknown, a Choice's value, a behaviour's Detect; remembered State.
   Done 2026-10-31 (`AkariOS.Core/Tweaks/States.cs`): Get-AkariState's order, the C# side of a Tweak (`ITweakCode`:
   `Detect`, `ChoiceValue`, `Rows`), `state.json` in the PowerShell app's format. A Tweak whose C# is missing reads
   Unknown.
6. **System**: OS build, edition, chassis, GPUs (`Requires`), Explorer restart.
   Done 2026-10-31 (`AkariOS.Core/Machine/`): `MachineInfo` (registry reads through the engine, WMI behind
   `IHardware`), `Requirements`, `IExplorer`. The PowerShell app's other System.ps1 wrappers (powercfg, bcdedit,
   w32tm, ...) come with the Tweaks that use them.
7. **Runner**: `Run(items) → Outcome[]` (Requires → Skipped, Already, Failed with the message, PC restarts last,
   Explorer once at the end, progress events), `Log` (`akari.log`), restore point (`IRestorePoint`: WMI
   `SystemRestore`, the 24 h throttle lifted once).
   Done 2026-10-31 (`AkariOS.Core/Runs/`, `Log.cs`): `Runner` (Invoke-AkariTweak and Invoke-AkariPlan), `ITweakCode`'s
   Apply / Revert / After / Prepare, `RestorePoints` over `ISystemRestore`, `AkariLog`. What the native engine can't do
   yet is a Failed Outcome that says so: a Tweak whose C# is missing, winget installs and the list kinds (N5), the
   restart into Safe Mode (`ISafeModeHandoff`, N7).
8. **Presets**: read / save the same JSON (bare id, `{id: value}`, `{id: "Default"}`, `<group>/*`, Phases), resolve,
   Last used, Export (`Get-AkariExportItems`' rules) and Import.
   Done 2026-10-31 (`AkariOS.Core/Presets/`): `PresetStore`. Checked against `Presets.ps1`: the built-in AkariOS
   preset resolves to the same items (Apply, Revert, phases), and each app reads the preset the other saved. Import
   is the GUI's (N3): a preset file read into Guided.
9. **CLI** in `AkariOS-Native.exe` (attached to the parent console): `--list`, `--apply id,id`, `--revert id,id`,
   `--preset <name|file>`, `--revert-preset`, exit 1 on any Failed; tests use `--list` and fake ids only.
   Done 2026-10-31 (`AkariOS.App/Cli.cs`, `AkariOS.Core/Engine.cs`): also a Native column in `--list`; a preset in more
   than one phase is refused until N7. Tests run it in-process on fixture Tweaks and a test key; the exe is never
   started. The self-contained single-file publish builds (about 92 MB).

Done when: the whole `src/Tweaks` tree loads with zero Problems; the data-only Toggles and Choices Apply, Revert and
report State against the test key; presets round-trip with the PowerShell fixtures. VM: `--list`, then `--apply` /
`--revert` of a few registry Tweaks, State checked in the PowerShell app.

## N2: Shell and look

Batches: 1 window styles, fonts, theme (done 2026-10-31); 2 the motion service (done 2026-10-31); 3 the shell (top bar, tabs, page
host, status bar); 4 dialogs; 5 Home and About. The VM check comes at the end.

- The app resources in order: Motion, the theme, Icons, the window styles, Controls (through `AkariXaml`);
  `ThemeService` (System / Dark / Light, `AppsUseLightTheme` followed through `WM_SETTINGCHANGE`, Mica and the dark
  frame on Windows 11 dark, solid elsewhere; `settings.json`).
- `MotionService`: the PowerShell `Motion.ps1` API in C# (`Start`, `Entrance`, `Stagger`, `Show` / `Hide`, `Count`,
  smooth scroll, `MovePill`, segmented and tab pills), the plan pure and tested.
- `MainWindow`: 64 px top bar (logo, tabs over the sliding pill, search, options menu, caption buttons), page header,
  Optimize sub-header, status bar with progress; widths as `Get-AkariTabLayout` / `Get-AkariHomeColumns`.
- Dialogs (`DialogService`: confirm, message, text; the crimson main action last), Home (hero, stats counted in the
  background, mode cards), About (version, links from `About.psd1`, credits, license).
- Done when: the style-key test passes, the pure layout tests pass. VM: the window in dark and light, Windows 10 and
  11, animation effects on and off.

## N3: Registry Toggles and Choices (most of the catalogue)

- Optimize › Advanced (the Catalogue, ADR 0005): Section › Category pages, search, setting cards (switch, Choice
  dropdown or segmented, Action button, badges, State line), States read in the background, changes acting right
  away through one queue, the restore point first, the restart bar.
- Install AkariOS › Guided: Tweaks step (Sections, masonry, Quick select, Clear, Show current state), Review & Apply,
  the result; Last used. One-click waits for N7.
- Import / Export (the Home tile and the options menu).
- Then the script-block Toggles and Choices of Optimize, Customize, Hardware and Advanced as C# classes, a Category
  per batch, each batch shrinking `parity.txt`.
- Done when: every data-only Tweak and the ported batches show and act on both pages. VM: a Guided Run and Catalogue
  changes, checked in the PowerShell app's States (and back).

## N4: Release and updates

- `.github/workflows/release.yml`: after the zip, `dotnet test`, then `dotnet publish app/AkariOS.App -c Release
  -r win-x64 --self-contained -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true
  -p:IncludeNativeLibrariesForSelfExtract=true`, renamed `AkariOS-Native.exe`, attached to the same release. A failing
  native build or test stops the release.
- `UpdateService` (the About page and the launch check, as `Core/Update.ps1`: Available / Latest / Newer / Blocked /
  Error; Blocked during a Run in phases or while changes are applied), the helper that swaps the exe.
- Done when: a tag builds both; the exe's version equals the zip's. VM: an older exe updates itself.

## N5: Apps (remove and install)

- `IPackageManager` (`Windows.Management.Deployment.PackageManager`: installed packages for all users, logos from the
  manifests, remove for all users, deprovision); the never-list.
- `IDism` (`dismapi.dll`, online session: capabilities, features; remove / disable).
- The four Groups' kinds, the legacy app removals (OneDrive, Edge, WebView2, ...) as C# Actions.
- Install: `IWinget` (winget.exe, App Installer re-registered or installed first), the Store re-registration, Store
  restores (`StoreInstall`), the non-winget downloads; `Before` / `After` as C#.
- Pages: Remove tables (Select recommended, AkariOS, Clear, Only installed), Install cards, Downloads flow, app icons
  from `src/Assets/Apps` and the installed logos.
- VM: the Remove and Install flows.

## N6: Services and Scheduled tasks

- `IServiceManager` (SCM: `EnumServicesStatusEx`, `QueryServiceConfig` / `2`, `ChangeServiceConfig` / `2`, start /
  stop; a denied change written as TrustedInstaller under the services key, as `Set-AkariServiceStart`), per-user
  service templates.
- `ITaskScheduler` (the `Schedule.Service` COM API: list, enable / disable, unregister; a denied change as
  TrustedInstaller), indirect resource strings.
- `advanced-services-off` (its Choice values from `services.psd1`), `advanced-remove-scheduled-tasks` (`tasks.psd1`).
- The Services and Scheduled tasks pages (suggestions, Show all, filters, critical-service confirms).
- VM: a few services and tasks changed and reverted.

## N7: Runs in phases, Safe Mode and One-click

- `Run` / `run.json` (the same shape as `Core/Phases.ps1`'s, its own path), `Prepare` in normal mode, SafeMode phases
  split off, `IBcdEdit` (safeboot on / off), RunOnce `*!akari-native-resume` / `!akari-native-resume` in the real
  user's hive pointing at the `%ProgramData%` copy, `--resume` (console window, summary at the end), a Failed change
  in Safe Mode stops the Run and turns Safe Mode off.
- The SafeMode Tweaks (Defender settings and full disable, DDU), the Catalogue's Safe Mode bar, One-click
  (`src/Presets/AkariOS.json`).
- VM: One-click from a fresh Windows 11 and Windows 10 22H2, the three phases end to end.

## N8: Tools and the rest of the parity list

- Section Tools (checks, cleanup, refresh, drivers, setup) and the remaining C# Tweaks, until `parity.txt` lists
  only what is left out on purpose (each with its reason in the file).
- VM: each Tools Action once.

## N9: Unattend Generator

- Schneegans' generator vendored (pinned commit, license, credit), the form from `src/UI/Unattend.psd1`, Open file /
  bookmark query, Reset, Save to a drive or folder (`ISetupDrives`), the fixtures of `tests/Fixtures/Unattend/`.
- VM: a USB install with a generated file.

## N10: ISO Builder

- The plan of `docs/plans/2026-10-31-iso-builder.md` in C#: `IDism` image calls (mount, export, commit, discard,
  remove apps / features / capabilities / packages), offline hives through `RegLoadKey` / `RegUnLoadKey`
  (`IOfflineHives`), `Iso/Data` read through `PsData`, `IOscdimg` and the ADK, UUP Dump and Massgrave through `IHttp`
  (the same fixtures), the leftover mount cleaned on launch.
- VM: the ISO Builder plan's VM batch, with the native exe.

---

## Open after this plan

- Signing the exe (SmartScreen asks the first time, as for `AkariOS.exe`).
