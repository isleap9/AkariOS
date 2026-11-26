# New features after 1.5.2

Decided 2026-11-26: seven features, each in both apps (`src/` and `app/`, `parity.txt` empty), tested, committed,
then checked on the VM, as the winutil and catch-up batches were. Out: removing Legacy (it stays), translations.

Each batch below says what it reuses, what's new in Core / the UI, the native side and the tests. **Open** lines are
to grill before the batch starts.

Order: X1 is small and has no dependencies. X2 and X5 are lists in the style of the Services page. X3 adds the Run
history that X4 and X6 build on. X7 is the ISO Builder's own work.

## X1 Support file

One button that gathers what a bug report needs.

- Settings › Recovery: a "Save a support file" card next to Logs. It saves `AkariOS-support-<yyyyMMdd-HHmm>.zip`
  where the user picks (`Select-AkariSettingsFile`'s picker, a `.zip` filter).
- Contents: akari.log, activity.json, state.json, settings.json, run.json (when there is one), the last used
  preset, and `system.txt` (version, OS build and UBR, edition, chassis, GPUs and their driver versions, VM or not,
  Safe Mode, admin). The loader's Problems are already in akari.log; the ISO report sits next to the ISO (the user
  attaches it), so neither is added separately.
- Privacy: the user's profile path becomes `%USERPROFILE%`, and the user name and computer name become `<user>` /
  `<pc>` in every text file (`ConvertTo-AkariSupportText`, pure). Nothing is sent anywhere: the user attaches the
  file to an issue.
- Core: `Core/Support.ps1` (`Get-AkariSupportInfo`, `New-AkariSupportFile <path>`); native `Core/Support/SupportFile`.
- Tests: the text scrubbing (pure, both apps on the same cases through an oracle), the zip's file list on a fixture
  folder.
- Built 2026-11-26 (Pester `tests/Support.Tests.ps1`; native `SupportTests` with `Oracle/Export-Support.ps1`, the
  Settings test). VM check: to do.

## X2 Startup apps page

A third list in the style of Services and Scheduled tasks: `Catalogue:Tools/Startup`, in `$AkariCatalogueLists`.
Decided while building: a Category page exists only through its Tweaks, so `oneclick-startup-cleanup` moved from
Tools › Cleanup to a new Tools › Startup Category (its id and the AkariOS preset unchanged) and the list sits under it.

- Read: HKCU and HKLM `Run` / `RunOnce` (both WOW6432Node), both Startup folders, and each entry's on / off state from
  `Explorer\StartupApproved\Run`, `Run32` and `StartupFolder` (the first byte: 02 / 06 = on, 03 / 07 = off; Task
  Manager's own switch). Rows: name, command, publisher (the exe's company name), location, status.
- Change: the switch writes StartupApproved, exactly like Task Manager, so turning an entry back on restores it as it
  was. Delete ("…" menu) asks first and is the only way to remove an entry.
- Filters: All, On, Off, Per user, All users. Search filters the list like the Services page does.
- `oneclick-startup-cleanup` stays as it is (it deletes everything); the page's lead points to it.
- Core: `Core/Startup.ps1` (`Get-AkariStartupItems`, `Set-AkariStartupEnabled`, `Remove-AkariStartupItem`; the
  StartupApproved bytes through the pure `ConvertTo-` / `ConvertFrom-AkariStartupApproved`); UI `UI/StartupPage.ps1`.
  Native: `Machine/StartupItems.cs`, `StartupListViewModel` / `StartupRowViewModel`, `Views/StartupListView`.
- Tests: reads and switches on a test key and `TestDrive:` folders; an oracle compares the pure parts.
- Built 2026-11-26 (Pester `tests/Startup.Tests.ps1`; native `StartupTests` with `Oracle/Export-Startup.ps1`, the
  list's test in `ServicesTasksTests`). RunOnce entries are left out, as Task Manager does. VM check: to do.

## X3 Run history (the base for X4 and X6) and the drift check

### History

- Every Run that changes Tweaks (Guided, One-click, a preset from the CLI, Import, the Catalogue's changes) appends
  each Applied / Reverted Outcome to `expected.json` next to state.json: `{ id: { Mode; Value; When } }`, the latest
  one per id. A Revert keeps the entry (expected = Default).
- Guided, One-click, preset and Import Runs also write a record to `history\<yyyyMMdd-HHmmss>.json`: the items, the
  Outcomes and, from X4 and X6, the earlier values and the numbers. The newest 10 are kept.
- Written by `Invoke-AkariPlan` / the native `Runner`, so the console Runs (One-click, `-Resume`) record too.
- Shared between the apps like presets (`%LOCALAPPDATA%\Akari\`): **Open**. Sharing means either app can fix drift
  after the other one applied settings.

### Drift check

- `Get-AkariDrift <tweaks>`: each id in expected.json whose current State (`Get-AkariState` / `Get-AkariChoiceValue`)
  is different from the expected one. Actions, Group Entries and Tweaks this PC no longer meets are left out; an
  Unknown State is not counted as drift.
- When it runs: at launch, in the background, only when the Windows build or UBR changed since the last check (saved
  in settings.json), and from a "Check my setup" card on Home and in Settings.
- Shown: Home's InfoBar "n settings went back to Windows' values after an update" with Review, which opens a list
  page: each setting, what it is now and what it should be, a tick each, and Re-apply (n), one Run of Kind Apply with
  the restore point rule.
- A daily scheduled check with a Windows notification: **Open** (the task runs as SYSTEM, so a notification needs the
  user's session; the launch check may be enough).
- Tests: the drift list (pure, on fixture Tweaks and made-up States); expected.json written by the Runner for each
  Outcome kind; an oracle between the apps.
- Built 2026-11-26 (Pester `tests/Drift.Tests.ps1`; native `DriftTests` with `Oracle/Export-Drift.ps1`, the app test in
  `HomeSettingsTests`). Decided while building: each app keeps its own expected.json next to its state.json (as
  state.json is per app); no daily task, the launch check (after a build change) and Check my setup only; Review
  opens Guided's Tweaks step with the drifted settings ticked, as Import does, instead of a page of its own. The Run
  history records (`history\*.json`) move to X4, the first batch that reads them. VM check: to do.

## X4 Undo last run

ADR 0001's Revert goes back to Windows' Default. Undo goes back to what this PC had before the Run, including the
user's own values.

- Before a Run's changes (after the restore point), `Save-AkariBefore <items>` reads every registry row the plan will
  write: the value and its kind, or "absent"; for a key row, whether the key exists. Only for Tweaks whose effect is
  their rows (registry Toggles / Choices with no code: the rule `Test-AkariIsoBakeable` and the native `NeedsCode`
  already use). Saved in the Run's history record.
- Undo = a Run of Kind `Undo`: the saved values written back through `Invoke-AkariRegistry` (absent = removed). Tweaks
  with code are listed separately: "Back to Windows' default" (their Revert, ticked by default) or left as they are.
  Actions and app removals are listed as "Can't be undone here" (removed Store apps point to Downloads › Windows apps).
- A deleted key row's subkeys are not saved; the Review says so for those Tweaks: **Open** (export the key with
  `reg export` instead?).
- Where: Recent activity's Run rows get an Undo button (the newest record only, or any of the 10: **Open**); a Review
  page lists everything first; then the run page and the result, as Guided.
- Install AkariOS's "There is no uninstaller" InfoBar changes to say what Undo covers.
- Core: `Core/History.ps1` (`Save-AkariBefore`, `Get-AkariHistory`, `Get-AkariUndoPlan <record> <tweaks>`, pure, and
  `Invoke-AkariUndo`); native `Runs/History.cs`.
- Tests: a Run on a test key, then Undo, then every value is byte for byte what it was (each kind, absent values, key
  rows); the Undo plan's three lists (pure, oracle).
- Built 2026-11-26 (Pester `tests/History.Tests.ps1`; native `HistoryTests`, the Settings test in `HomeSettingsTests`).
  Decided while building: a Tweak with a key row is not undoable exactly (it goes to Windows' default), so a deleted
  key's contents never need saving; Undo lives in Settings › Recovery ("Undo the last run": the newest record, set
  aside as `.undone` once done, so the next Undo goes one Run further back), not on Recent activity's rows; Recorded
  Runs are Guided's and Runs in phases (One-click, CLI presets), not single Optimize changes (a switch flips back);
  the "There is no uninstaller" warnings now say what Undo covers. No oracle: each app reads only its own records.
  VM check: to do.

## X5 Per-game settings

A list on the Optimize › Gaming page (`$AkariCatalogueLists`, under its Tweaks).

- Games found: Steam (`libraryfolders.vdf` → each library's `appmanifest_*.acf`: name, install folder), Epic
  (`%ProgramData%\Epic\EpicGamesLauncher\Data\Manifests\*.item`: DisplayName, InstallLocation, LaunchExecutable),
  GOG (`HKLM\SOFTWARE\WOW6432Node\GOG.com\Games`), Battle.net and Xbox: **Open**. Plus "Add a game…" (an exe picker),
  saved in `games.json`. A library's exe is its launch exe; a folder with several asks the user once.
- Per game, three switches, each a registry value removed on Off (Windows' default is no value):
  - High-performance GPU: `HKCU\Software\Microsoft\DirectX\UserGpuPreferences`, `<exe path>` = `GpuPreference=2;`.
    This is the same key as `gaming-windowed-optimizations`, under a different value name, so the owner check is
    unaffected.
  - Fullscreen optimizations off: `HKCU\...\AppCompatFlags\Layers`, `<exe path>` = `~ DISABLEDXMAXIMIZEDWINDOWEDMODE`
    (other layers already on the value are kept).
  - High CPU priority: `HKLM\...\Image File Execution Options\<exe name>\PerfOptions`, `CpuPriorityClass` = 3. This is
    per exe *name*, so the row says that it applies to every exe with that name.
- The real user's HKCU, as everywhere (rule 6). Each change goes through the Catalogue's queue, the session's restore
  point first.
- These aren't Tweaks (one per exe, found at runtime), so they stay outside presets and Export: **Open** (Export could
  carry `games.json` in its `Extra` block).
- Core: `Core/Games.ps1` (`Get-AkariGames`, `Read-AkariVdf`, pure, `Get-AkariGameSettings`,
  `Set-AkariGameSetting`); native `Machine/Games.cs`, `GamesListViewModel`.
- Tests: the VDF and manifest readers on fixtures (`tests/Fixtures/Games/`), each switch on a test key, the Layers
  value merge (pure, oracle).

## X6 Before and after numbers

- `Get-AkariMetrics` → RAM in use, process count, running services, startup entries (X2's reader), installed Store
  apps, boot time (Diagnostics-Performance event 100's BootTime, when the log has it), the timer resolution
  (`NtQueryTimerResolution`).
- "Before" = taken when a Guided or One-click Run starts, saved in its history record.
- "After" = taken at the first launch after the Run's restart, once the PC has been up 3 minutes (idle numbers right
  after the Run mean nothing): the job waits in the background, then saves into the same record. One-click's console
  Runs take "before" there; the GUI takes "after".
- Home: a "Since AkariOS" card (each number before → after, the difference in the accent colour), and the Run's result
  page once "after" exists. These are approximate numbers: the card's line says they vary from one boot to the next.
- Core: `Core/Metrics.ps1` (WMI and event reads behind wrappers that tests mock; `Get-AkariMetricsDiff`, pure); native
  `Machine/Metrics.cs` (`IMetrics`).
- Tests: the diff and its text (pure, oracle); the wrappers mocked.

## X7 ISO Builder: this PC's drivers in the image

- Build settings: an "Add this PC's drivers" switch (off at first; on in no mode: **Open**), with a note that the
  drivers come from this PC, so the ISO is meant for this PC or one like it.
- New step `Drivers` after Mount: `Export-WindowsDriver -Online -Destination <work>\Drivers` (third-party only), then
  `dism /Image:<mount> /Add-Driver /Driver:<folder> /Recurse`, with one operation per driver (its .inf, class and
  provider) in the report. Optionally boot.wim index 2 too, for storage and network during setup (Intel RST / VMD
  drives): **Open**.
- Wrappers: `Export-AkariOnlineDrivers`, `Add-AkariImageDrivers` (tests mock them); native `IDism.ExportDrivers`,
  `IImage.AddDrivers`.
- Tests: the plan's step order with the setting on and off (pure, `IsoWizardOracleTests`), the recorders' calls in
  `IsoBuildOracleTests`, the report's operations.

## Notes

- Commit the uncommitted work in progress (OneClickPicks, DismException, the Runner and AppKinds changes) before X1.
- Each batch updates AGENTS.md's layout in the same change (rule 10) and adds its CREDITS.md lines where an idea
  comes from somewhere (Task Manager's StartupApproved format is Windows' own; no Winhance code, rule 9).
