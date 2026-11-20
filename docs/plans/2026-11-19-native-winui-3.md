# The native app on WinUI 3

ADR 0009. Replaces the WinUI 3 plan's batch 7 (`2026-11-19-winui-3.md`: "native parity"): instead of bringing the
WPF views to ADR 0008's look, the native app's UI is rebuilt on WinUI 3 and the WinUI 3 MVVM framework.

## Decisions

1. **Projects.** `app/AkariOS.Framework` = the framework library (`WinUI-3-MVVM-Framework/src/AppTemplate.Framework`,
   namespace `AkariOS.Framework`, no AkariOS code in it; a fix that isn't AkariOS-specific goes back to the template
   too). `app/AkariOS.App` = the WinUI 3 exe (`AkariOS-Native`): `Program.cs`, `App.xaml`, `MainWindow`, `Shell/`,
   `ViewModels/`, `Views/`, `Cli.cs`, `RunConsole.cs`. Engine projects untouched.
2. **Entry point.** `DISABLE_XAML_GENERATED_MAIN`; `Program.Main`: `--resume` and One-click's console
   (`InConsole`), the CLI (`AttachConsole(-1)`), else `Application.Start(new App())`; after the window closes,
   `App.OneClick` runs in a console. The same code as the WPF app's, only the window part changed.
3. **Hosting.** `App.BuildHost`: `AddMvvmFramework()`, `FileSettingsStorage("AkariOS.Native")` (=
   `%LOCALAPPDATA%\AkariOS.Native\settings.json`), `IAkariLog` = akari.log (no framework file logger), `Engine.Live`
   as a singleton, pages through `FrameNavigationService` + DI, `IShellNavigator` = `WindowNavigator` (never the window itself through DI: see AGENTS.md), `IShellOpen`.
   Single instance (`AppInstance` key `AkariOS.Native`).
4. **Shell.** `NavTable` (pure) = Shell.ps1's `$AkariNav`: Home, Install AkariOS, Optimize (its Catalogue sections as
   children), Downloads, Remove apps, Install USB, ISO Builder; Settings in the footer. `MainWindow.Open <key>` maps a
   key to its View; a page still to come = `PlaceholderPage` naming its batch (`NavTable.ComingWith`). 48 px title
   bar (back, logo, version), Mica, NavigationView `Auto` (compact under 1000 px), the search box (W2).
5. **Look.** WinUI's controls and theme resources only (`ThemeResource …FillColor…Brush`, text styles). Crimson
   through `SystemAccentColor` / `Light1-3` / `Dark1-3` in `App.xaml`. No colour literal in Views (the title bar's
   caption button colours are the one exception: an `AppWindow` API). Glyphs: Segoe Fluent Icons (MDL2 on Windows
   10). Settings › Accent colour (Windows accent) in W3.
6. **Logic in view models.** A View binds; its view model does the work through Core and the services, testable in
   `AkariOS.App.Tests` with fakes (the old `AppHarness` pattern, minus WPF). Port each page's behaviour from the WPF
   code at `3ee49b6` (`app/AkariOS.App/Pages/*`) and the PowerShell app's `src/UI/*.ps1`; the prototype is the
   reference for layout.
7. **Single file.** `EnableMsixTooling` true on the App (resources.pri embedded), `WindowsAppSDKSingleFileVerifyConfiguration`
   false on the Framework. Publish command unchanged (AGENTS.md).

## Batches

| Batch | What | Status |
| --- | --- | --- |
| W1 | Scaffold: framework copied, WinUI 3 App, Program (CLI, consoles), shell + nav, Home hero, Settings (theme, logs), placeholders, tests (CLI, shell, view models, framework), single-file publish checked, ADR 0009, AGENTS.md | done 2026-11-19 |
| W2 | Optimize: Catalogue section pages (SelectorBar of categories, settings cards with ToggleSwitch / ComboBox / Run), the change queue, restart and Safe Mode InfoBars, search (AutoSuggestBox, suggestions, results page), Services and Scheduled tasks lists, closing asks | done 2026-11-20 |
| W3 | Home (tiles, Quick settings, Recent activity, the facts, the update InfoBar and launch prompt) and Settings (theme, accent, Export, System Restore, logs, About: update check and install, What's new, links, credits). No animations setting: WinUI follows Windows' own | done 2026-11-20 |
| W4 | Install AkariOS: chooser, Guided (Apps, Tweaks, Review & Apply), run page, result, restore point rule, One-click hand-off; Settings › Import (a preset into Guided's Tweaks step). The Apps step is Guided's only: its Remove and Install tables, row picks, Select recommended / AkariOS / Clear, Only installed, the features read, Quick select's apps; no icons | done 2026-11-20 |
| W5 | Downloads and Remove apps: their own pages on W4's `AppsStepViewModel` (one tab each, Review & Install / Review & Remove), app icons (`src/Assets/Apps`, Store logos), Show installed, Update all apps, Uninstall selected, the install queue, the removal Run | |
| W6 | Dialogs and toasts everywhere: ContentDialog confirmations (Advanced, Safe Mode, critical services), busy toast with progress, close-while-running questions | |
| W7 | Install USB (the Unattend Generator form on `UnattendForm`) | |
| W8 | ISO Builder | |
| W9 | Release: `release.yml` publishes `AkariOS-Native.exe` again, ProductVersion check; VM check on Windows 10 22H2 and 11 24H2 (elevated, 100 % and 150 %) | |

## Notes

- A WinUI object can't be made in `dotnet test`: test view models and pure tables, never Views.
- The test project references the App exe; no `InternalsVisibleTo` (it clashes with the Windows App SDK's injected
  auto-initializers). Test public types.
- `CliTests` names the class `AkariOS.App.Cli` where `Cli` alone would be the test's own method.
- Theme "System" follows the elevated process's own app mode; the real user's (rule 6) when they differ comes with W3's
  accent work.
- File dialogs: `Shell/AppParts.cs`'s `IFilePicker` on `Microsoft.Windows.Storage.Pickers` (paths). The framework's
  `IFilePickerService` uses `Windows.Storage.Pickers`, which fail in an elevated process: never use it here (and
  worth fixing in the template).
- The accent is code, not XAML (`Accent.Crimson` → `Application.Resources`, before the window); a change applies the
  theme again (`MainWindow.RefreshTheme`) so WinUI's brushes read it.
- Every page's content column goes through `Views/PageLayout.Fit <scroller> <column>`: its width is set from the
  ScrollViewer's on every size change (at most 1064 px, centred). With MaxWidth and centring alone, Settings kept its
  old width and position after the pane collapsed (removing its Expander didn't fix it). Check a new page on the VM
  with the pane opening and closing.
- Install AkariOS has no header search (the WPF app filtered the step from the window's search box): the Apps and
  Tweaks steps have their own filter boxes; the window's box stays the Catalogue's search.
- While a Guided Run applies, `ShellState.Locked` is on: a Catalogue card refuses its change with a message (W6 may
  queue it instead). Closing asks (`InstallViewModel.CanCloseAsync`) before the Catalogue's own question.
- `SelectorBar` items and `MenuFlyout` items are filled in code-behind (glue); everything they do is a view model call.
