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
| W5 | Downloads (the PowerShell app's card grid: categories, search, Install queued one app at a time with no restore point, Installed / Failed on the card, Uninstall from an installed card's menu, Update all apps, what is installed read once a session) and Remove apps (the four lists one at a time, Remove (n): one Run after the restore point, rows go as it passes them, the lists read again); app icons (bundled `src/Assets/Apps`, an installed Store app's logo, black-or-white ones tinted, else a glyph) on Guided's Apps step too | done 2026-11-20 |
| W6 | Dialogs and toasts everywhere: `AkariDialogs` (ContentDialog: main action accent and first, "- " lines a list) for every confirmation (Advanced, Safe Mode's Restart and apply / Later / Cancel, critical services, One-click); result toasts (Guided run with Restart now, Downloads' install / uninstall / update all, Remove apps, Export with Open folder, Import, Waiting for Safe Mode), stacked at the bottom right; the busy toast with each page's own work and its progress ("n of m"); one closing question naming everything running or waiting (`ClosingGuard`) | done 2026-11-20 |
| W7 | Install USB (the Unattend Generator form on `UnattendForm`): the drive bar (setup USB found, Refresh, Save to a folder…, Save to USB), his check under it, Open file… / Reset to defaults (asks), his sections as Expanders saying "Default" / "Changed from the default", the questions before a disk wipe, a drive without setup, an existing file; `IsoAnswerAsync` for W8 | done 2026-11-20 |
| W8 | ISO Builder (zISO's cards on `IsoBuilderViewModel`: the ISO from a file, UUP Dump or Massgrave (Downloads watched every 3 s), the work folder, Open ISO; the edition; the answer file (none, a local account, Install USB's choices); the options greying what they rule out; the image's four lists; AkariOS (off in a developer build); Build with its steps on the busy toast, done as a toast with Open folder). The long jobs lock the shell; a leftover mount is cleared on launch | done 2026-11-20 |
| W8b | The rest of the PowerShell app's shell (a sweep of every `src/UI` function: only Legacy is left out, on purpose): Optimize's overview (the Sections as cards, a few Tools), titles as breadcrumbs (Optimize › Section, Install AkariOS › step), a suggestion's card scrolled to and flashed, the search's match marked in the results, Ctrl+F / Ctrl+E / Alt+Left, the first run's search tip | done 2026-11-20 |
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
- While a Run of Install AkariOS or Remove apps applies, `ShellState.Locked` is on. Decision (W6): a Catalogue change
  made meanwhile is queued, not refused: its card says "Waiting…" and it runs once the lock lifts (the Catalogue and
  Downloads listen for `Locked` turning off; Downloads' installs wait the same way). A refused restore point keeps the
  lock while it asks, so nothing queued starts in between. The session's restore point is already made by then.
- Busy state goes through `ShellState.Begin` / `End` (a `BusyWork` per job), never one shared flag: an install from
  Downloads and a change from Optimize can run at once, and ending one must not hide the other. End the work before the
  window closes itself (the update), or `ClosingGuard` asks.
- Results are toasts (`ShellState.Toast`); dialogs are for questions (and a few infos that need reading before going
  on). Closing asks once, through `ClosingGuard`; view models have no CanCloseAsync of their own but the Catalogue's
  Safe Mode one.
- `SelectorBar` items and `MenuFlyout` items are filled in code-behind (glue); everything they do is a view model call.
- `src/Assets` (the logos and the app icons) is built into the exe as resources (`Assets/…`) and unpacked on first use
  into `%LOCALAPPDATA%\AkariOS.Native\Assets\<version>` (`Shell/AssetFiles.cs`): a single-file publish has no Assets
  folder next to the exe, so the W1-W4 logos read from `AppContext.BaseDirectory` were missing from the published exe.
- A mono app icon is a `BitmapIcon ShowAsMonochrome` in the text colour (WinUI has no OpacityMask).
- Install USB's form is built in code (`Views/UnattendFormView`), not XAML templates: his items nest branches inside
  branches. The values live in Core's `UnattendForm` (a singleton view model owns it), so the page is made again on
  each visit and drops its handlers on Unloaded; a section's controls are made the first time it opens (29 sections,
  the bloatware list and 15-row tables would otherwise slow the first visit).
- Downloads and Remove apps follow the PowerShell app's current pages (cards that install right away; Remove (n)),
  not the WPF app's table flows with their own Review step.
- ISO Builder (W8): its long jobs (Open ISO, Read the image's apps, Build, the UUP download) set `ShellState.Locked`,
  the W6 rule for a Run: Optimize's changes and Downloads' installs made meanwhile wait and run when the job ends (the
  WPF app refused them). Install AkariOS, Remove apps, One-click and the update are refused while the shell is busy, as
  for any work; Restart now (the Catalogue's bar) is refused while locked. UUP Dump's and Massgrave's lists only ask a
  website: they don't lock and run beside other work. One ISO job at a time.
- The Massgrave watch is an `ITimers` (a DispatcherQueueTimer; tests tick a fake by hand), not a timer in the view.
- An option ruled out is greyed, so a click can't tick two that exclude each other: test option rules with the clicks
  the page allows (ticking a greyed one in a test clears both, as Update-AkariIsoOptions does).
- Not ported on purpose: Legacy (`Tweaks/*.ps1`, Optimize › Legacy, `UI/Rows.ps1`), the "Animation effects" setting
  (WinUI follows Windows'), the compact-nav toggle and the suggestions' arrow keys (NavigationView and AutoSuggestBox do
  them), the Catalogue's skeletons (the cards show "Reading…" until their State is read).
- A card is one view model shared by every page that shows it: the search's highlight is set through
  `CatalogueViewModel.Highlight`, which clears it on the cards of the last results; a page showing cards outside the
  results calls it with none.
- Optimize's Section pages used to scroll to a Category from a SelectorBar at the top, which scrolled away with the
  page: picking the next Category meant scrolling back up. Decision (2026-11-20, native app only; tried on Customize
  first, then every Section): a drill-down (Windows 11 Settings' pattern). A Section's page lists its Categories as
  Settings rows in groups (Optimize: Speed, Windows; Customize: Desktop, Behaviour; Advanced: System, Security and
  features; Tools: Keep it running, Check and recover; Graphics & Hardware: one group, no heading), each row its icon,
  name, a line saying what is inside, the count in a badge and a chevron (`Shell/CategoryInfo`); each Category has its
  own page (Optimize › Section › Category). Every page's title is a small line of links above a normal heading,
  Install AkariOS' Guided too. Picked from mockups; rejected: the bar pinned, tabs, plain rows with a title-size
  breadcrumb, tiles, a switcher in the title, chips, Categories in the left nav, a list beside the cards, expanders.
