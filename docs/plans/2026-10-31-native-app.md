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
  exe, checked against GitHub's SHA-256 digest, swapped in place (the running exe renamed to `.old`, removed when the
  new one starts; N4). A Run in phases first copies the exe to `%ProgramData%\AkariOS.Native\AkariOS-Native.exe`
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
host, status bar; done 2026-10-31); 4 dialogs (done 2026-10-31: the shared Dialog.xaml as it is); 5 Home, About and the options
menu (done 2026-10-31: the shared About.psd1 through PsData; what isn't native yet says when it comes). The VM check comes
at the end.

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

Batches (decided 2026-11-03): a the Catalogue's pure part and Optimize's sub-header (done 2026-11-03: Core
`Catalogue`, checked against Catalogue.ps1 on two made-up PCs; inside one page the search keeps the page's order,
since 5.1's Sort-Object isn't stable); b the Catalogue page (done 2026-11-03: `CatalogueView`, setting cards kept
per Tweak, States read in the background one by one, Refresh; a Tweak with no C# yet has its control off and says
so; a Choice is a dropdown, as in the PowerShell Catalogue (the segmented control is the Guided rows'); the search
looks through the Catalogue from any page that doesn't filter its own list); c changes acting right away (done
2026-11-03: one queue, the session's restore point first, `Selection.ConfirmText` checked against Selection.ps1 on
every real Tweak, the Safe Mode and restart bars, Restart Explorer / Restart now (`IShutdown`), closing with a change
running or Safe Mode changes waiting asks; Safe Mode's "Restart and apply" waits for N7); d Install AkariOS › Guided's Tweaks step
(done 2026-11-03: `InstallPage`, `TweaksStep`, `TweakRow`; the chooser (One-click = N7), the stepper footer, an Apps
step saying it comes with N5; the Sections, pending changes and row tooltips checked against Steps.ps1 /
Selection.ps1 / Cards.ps1 on every real Tweak; every State read once in the background before the grid is built,
where the PowerShell app reads them on the UI thread); e Review & Apply, the result, Last used (done 2026-11-03:
`ReviewStep`, `InstallPage.Apply`: one Run in the background with progress, the restore point first and "Apply
anyway" when Windows refuses it, Last used, the Catalogue's States read again after; closing during a Run asks);
f Import / Export (done 2026-11-03: `ImportExport`, `IFilePicker`; an export from one test PC imports on another into
Guided's Tweaks step; WPF test threads now shut their dispatcher down, which one left behind hung the test process's
exit); g the script-block Toggles and Choices as C# classes, small Categories together: g1 Optimize
Gaming / Network / Privacy / Update (done 2026-11-03: 9 classes, parity 162 -> 153; `TweakServices` for the hosts
file, network bindings, Settings pages, a service stop, TrustedInstaller, ProgramData and the clock; data read out of
the files through `FileData`, code-built rows and the hosts list checked against PowerShell's), g2 Optimize/Performance
(done 2026-11-03: 8 classes, parity 153 -> 145; `IServiceManager` (replaces g1's service stop), `ITaskScheduler`,
`IExe`, `IMemoryAgent`, `IBitLocker`, the system folders and `UserFolders`), g3 Optimize/Power (done 2026-11-03: 6
classes, parity 145 -> 139, every Optimize Tweak native; `IPowerCfg`; the powercfg calls and registry writes checked
against the PowerShell blocks run with recorders, Oracle/Invoke-TweakBlocks.ps1), g4 Customize Taskbar /
Start / Explorer / Theme (done 2026-11-03: 13 classes, parity 139 -> 126; `IProcesses`, `IShortcuts`, `IDesktop`,
Explorer on the services, REG_NONE values, System.Drawing for the black images; the rows oracle now covers every class
that builds rows), g5 Customize System / Notifications / Sound / Input (done 2026-11-03: 9 classes, parity 126 -> 117;
`IBcdEdit` (N7's Safe Mode uses it too), `IW32tm`; the blocks oracle now also runs Detect and After blocks, records
bcdedit, w32tm, reg import and registry-state rows, and points the PowerShell blocks' registry reads at the C# test's
key; the priority list's .reg fragment is written through the registry engine, not reg.exe; a `System` folder's
classes use the namespace `SystemTweaks`), g6 Customize/Apps (done 2026-11-03: 6 classes, parity 117 -> 111;
`IAppSettings` (a Store app's settings.dat through reg.exe load / import / export / unload; `AppSettings.Parse` =
ConvertFrom-AkariRegExport, `AppSettings.State` = Get-AkariAppSettingState), `AppHive` reads each file's family, Detect
rows, inline .reg text, stopped programs and messages out of its blocks; Terminal's settings.json edited as text; the
blocks oracle records Read- / Import-AkariAppSettings and stands in for Stop-Process, Start-Process, Start-Sleep and
Remove-Item, with a temp user folder; the PowerShell app-actions block puts a space before its 2nd and 3rd .reg value
lines (`+` before `-join`), the C# text has none: the VM check confirms all three values land), g7 Customize/Context
menu (done 2026-11-03: 10 classes, parity 111 -> 101; `RowScript` reads rows a file builds with code (helper script
blocks with params and switches, foreach, if, assignments) through PsData instead of copying them, checked by the rows
oracle; the two desktop entries' rows read out of their blocks and written as TrustedInstaller; Print's verbs from
Files/PrintVerbs.ps1's function, keys tested on the registry; the blocks oracle records Invoke-AkariRegistry /
-Trusted and reads Get-AkariRegKey on the test key), g8 Hardware/Graphics (done 2026-11-03: 10 classes, parity
101 -> 91; `IDownloads` (Save-AkariFile from AkariOS-Files), the remembered state and the Program Files folders on
`TweakServices`, `IShortcuts` takes the working folder; NVIDIA Profile Inspector through `IExe` with the .nip written to
the Files folder; per-GPU Detects drop an adapter whose key is missing, as Get-AkariRegValue outputs nothing there (only
the MSI keys can be missing on a real PC: no key = Unknown); the blocks oracle answers Get-AkariGpus /
Get-AkariGpuDevices with the C# test's PC, records downloads, shortcuts, Unblock-File, the remembered state and key
create / delete on the test key, and points the blocks' $env: Program Files / ProgramData at temp folders), g9 Hardware/Input and Advanced Security / System (not Safe Mode ones; done
2026-11-03: 6 classes, parity 91 -> 85; `IMemoryAgent` covers every MMAgent feature and the operation recorder's file
count; `ILauncher` opens windowsdefender: pages; StartSearchShell reads its folder names, moves and programs to stop
out of the file, takes the folders over with takeown / icacls through `IExe` and moves them under the Windows folder;
the blocks oracle records the MMAgent cmdlets, Set-AkariScheduledTask, services and Grant-AkariOwnership, and does the
moves in its own copy of the folders (-SystemRoot); the tests' oracle helpers are shared, BlockLines.cs). Services-off and
Scheduled tasks wait for N6, the Defender Safe Mode Toggles for N7.

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

## N4: Release and updates (built 2026-11-12, 552 tests; VM check pending)

- `.github/workflows/release.yml`: the version checked against the tag, then `dotnet test -c Release`, then
  `dotnet publish app/AkariOS.App -c Release -r win-x64 --self-contained -p:PublishSingleFile=true
  -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true` (`AkariOS-Native.exe`, its
  `ProductVersion` must equal `$AkariVersion`), then the zip and `Akari.ps1`; all three attached to the same release.
  The native steps come first: a failing build or test stops the release before anything is published.
  `native.yml` also runs on `src/Core/Update.ps1` (the updater's Oracle).
- `UpdateService` (the About page, Home's update bar and the launch check, as `Core/Update.ps1` and `UI/About.ps1`:
  Available / Latest / Newer / Blocked / Error; Blocked for a developer build (not a single-file publish), a saved
  `run.json`, or changes being applied or waiting for Safe Mode).
- The swap (decided 2026-11-12, instead of a helper process): Windows lets a running exe be renamed, not
  overwritten. The release's `AkariOS-Native.exe` is downloaded next to the running exe as `<exe>.new`, checked
  against GitHub's SHA-256 digest and the release's version (its `ProductVersion`), then the running exe becomes
  `<exe>.old`, the new one takes its name (whatever the user called it) and is started, and the app closes; if it
  won't start, everything is put back. On launch `<exe>.old` and a stray `.new` are deleted (retried while the old
  one is still closing).
- Done when: a tag builds both; the exe's version equals the zip's. VM: an older exe updates itself.

## N5: Apps (remove and install)

Batches (decided 2026-11-12), each committed on its own with a VM step: **N5a** engine (done 2026-11-12, 596
tests): `IPackageManager` (WinRT `PackageManager`; the provisioned copy through its `FindProvisionedPackages` /
`DeprovisionPackageForAllUsersAsync` rather than DISM: DISM's provisioned-app struct isn't documented; NonRemovable,
which WinRT lacks, = System-signed plus App Installer and Windows Security), `IDism` (dismapi.dll: capabilities and
features), `IWinget` + `Winget` (App Installer and the Store as Winget.ps1), `AppKinds` (the four Group kinds and the
`Winget` field in the Runner); **N5b** the legacy removals as C# (done 2026-11-12, 605 tests, parity 85 → 76); **N5c** the installs with code (done 2026-11-12, 631 tests, parity 76 → 50); **N5d** the pages (done 2026-11-12, 655 tests)
(Guided Apps step, Downloads and Remove apps flows, app icons as WPF resources, Home's Removable apps). Oracles: the
pure list functions of `UI/Apps.ps1`, and the blocks of N5b / N5c with recorders for the Appx, winget and AppSetup
helpers.

- `IPackageManager` (`Windows.Management.Deployment.PackageManager`: installed packages for all users, logos from the
  manifests, remove for all users, deprovision); the never-list.
- `IDism` (`dismapi.dll`, online session: capabilities, features; remove / disable).
- The four Groups' kinds, the legacy app removals (OneDrive, Edge, WebView2, ...) as C# Actions.
- Install: `IWinget` (winget.exe, App Installer re-registered or installed first), the Store re-registration, Store
  restores (`StoreInstall`), the non-winget downloads; `Before` / `After` as C#.
- N5c decisions (2026-11-12): AppSetup.ps1's install helpers in `Core/Apps/AppSetup` (no app logic);
  `Find-AkariProgram` / `Open-AkariWingetTool` wait for N8 (Tools), their only user. An installer runs through
  `IExe.Run(capture: false)`, waited for alone: 5.1's `Start-Process -Wait` may also wait for the programs it
  starts (deliberate difference: the NVIDIA App installer starts the app). Spotify's installer goes through
  explorer.exe as in the PowerShell app (no token work for one app). Portable winget packages are looked for in the
  process's own LocalAppData, where winget, run elevated by Akari, unpacks them. Values a block writes (Discord's
  settings, Spotify's prefs, policies) are written in C# and checked by the Oracle; the `Files/` configs are read from
  src/. Firefox's uBlock comes through `TweakServices.Http`. The Microsoft Store restore = `Winget.EnsureStore`
  (compared with Install-AkariMicrosoftStore in N5a), tested on fakes.
- N5d decisions (2026-11-12): one `InstallPage` hosts Guided, Downloads and Remove apps as Steps.ps1 does (a flow
  switch starts afresh; Back / Done of an apps flow go where it was opened). Apps.ps1's pure functions are
  `Core/Tweaks/AppLists` (Oracle); the WPF side is `Pages/AppsStep`. The packages, logos and legacy Detects are read
  in one background read, the features in another when the Remove tab first shows (never for Downloads). The app
  icons are WPF resources read as streams (pack:// needs WPF's Application, which tests don't have). Quick select
  and Import pick the apps too, after the Tweaks (whose Quick select clears the Selection). Rows are plain grids as
  in the PowerShell app; their build time is checked on the VM (AKARI_UI_TIMING) before anything virtualizes them.
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
- Built 2026-11-12 (684 tests, parity 50 → 48). Decided: the services are read through WMI `Win32_Service` as the
  PowerShell app reads them (its description and DelayedAutoStart in one query), not the SCM calls above; a startup
  type is written to the service's registry key as `Set-AkariServiceStart` does (admin, else TrustedInstaller; a
  per-user instance's template too), not with `ChangeServiceConfig`. A task Windows keeps from an admin goes through
  `schtasks` started as TrustedInstaller (`ITrustedInstaller.Start`, `CreateProcessWithTokenW`): the thread
  impersonation the registry uses reaches neither a new process nor the out-of-process Task Scheduler.
  `advanced-services-off` runs in Safe Mode only (the restart into it is N7's). Service, task and Tweak changes
  share the Catalogue's one queue.

## N7: Runs in phases, Safe Mode and One-click

- `Run` / `run.json` (the same shape as `Core/Phases.ps1`'s, its own path), `Prepare` in normal mode, SafeMode phases
  split off, `IBcdEdit` (safeboot on / off), RunOnce `*!akari-native-resume` / `!akari-native-resume` in the real
  user's hive pointing at the `%ProgramData%` copy, `--resume` (console window, summary at the end), a Failed change
  in Safe Mode stops the Run and turns Safe Mode off.
- The SafeMode Tweaks (Defender settings and full disable, DDU), the Catalogue's Safe Mode bar, One-click
  (`src/Presets/AkariOS.json`).
- VM: One-click from a fresh Windows 11 and Windows 10 22H2, the three phases end to end.
- Built 2026-11-12 (710 tests, parity 48 → 37). Decided (grilled): `Core/Runs/Phases.cs` is Start-AkariPhases and
  Split-AkariSafeModePhases line for line, checked scenario by scenario against the real ones with recorders
  (`Oracle/Export-Phases.ps1`); run.json is read and written only by the native app (same shape, its own path). The
  exe a resume starts is a copy in `%ProgramData%\AkariOS.Native`, refreshed each time a Run sets up the next boot (a
  developer build is started where it is), deleted on a later launch once no Run is saved. RunOnce runs
  `powershell.exe … Start-Process '<copy>' --resume -Verb RunAs`: Windows blocks a startup entry that needs elevation
  itself. `--resume` and One-click run in a console window of their own (AllocConsole, maximized; the banner from
  `Assets/ascii.txt` scaled as Get-AkariBannerArt does; the summary and Enter at the end), never WPF. One-click asks
  first (Confirm-AkariOneClick's text), makes the session's restore point in the window (refused = "Run anyway" /
  Cancel), then closes the window and hands the AkariOS preset to that console. The Catalogue's "Restart and apply"
  asks once more (Restart now / Cancel), then runs through the queue (restore point first) into the Runner's Safe Mode
  handoff. reg.reg is written through the registry engine (RegReader), not reg.exe. N7 also took the two Tools
  Actions the AkariOS preset runs (`oneclick-startup-cleanup`, `oneclick-restore-point`) and the Tools DDU pair, which
  share DDU's steps.

## N8: Tools and the rest of the parity list

- Section Tools (checks, cleanup, refresh, drivers, setup) and the remaining C# Tweaks, until `parity.txt` lists
  only what is left out on purpose (each with its reason in the file).
- VM: each Tools Action once.
- Built 2026-11-12 (753 tests, parity 37 → 0: nothing left out). Decided (grilled): every Tools block as one C#
  class, checked against its block (`Invoke-TweakBlocks.ps1`, now with `-Logs` so the console lines match too). Web
  pages open through `ILauncher`, which takes `https:` (never `http:`); Windows' own windows and the tools Akari
  starts go through `IExe` from their System32 path, not waited for (`appwiz.cpl` = `control.exe appwiz.cpl`). The
  board, BIOS and drives are `IHardware` reads (WMI; the drives through `DriveInfo`, not `Get-Volume`). The clipboard
  is user32's (Core has no WPF and a change runs off the UI thread). Vendor pages and downloads go through `IHttp`
  (`Text`, headers: AMD's site serves browsers only); AMD's setup link is the block's regex over the page's hrefs.
  wevtutil, cleanmgr (with its frozen watch) and pnputil each through their own interface; the driver store is read
  through DISM's API (`IDism.Drivers`, as Get-WindowsDriver -Online). Remove-AkariPaths is `SystemPaths.Remove` (real
  deletes; tests on temp folders, the Oracle's real function on its own copy). Windows.old goes as TrustedInstaller
  through cmd's `rd` (as N7's Defender move), then taken over and deleted. The firmware restart is
  `IShutdown.Firmware`. Deliberate differences: AMD's config files keep their own encoding (5.1's Set-Content writes
  ANSI, the same bytes for these ASCII files); `[uri]::EscapeDataString` is matched as 5.1 has it (RFC 2396: `!*'()`
  not escaped); the bare `rundll32.exe` / `msiexec.exe` run from System32.

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
