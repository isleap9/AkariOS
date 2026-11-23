# The PowerShell app catches up with the native app (1.5.0)

Decided 2026-11-23: the PowerShell app (`src/`) gets everything the native WinUI 3 app (`app/`) has, including what
`2026-11-19-native-winui-3.md`'s Notes and `2026-11-20-iso-builder-wizard.md` marked "native only". Both ship as
1.5.0. Version stays 1.4.2 until the last batch passes the VM.

## Inventory: what the native app does that the PowerShell app doesn't

Compared: `app/AkariOS.App/ViewModels`, `Views`, `Shell` against `src/UI/*.ps1` (the W8b sweep already went the
other way: everything the PowerShell app had is native, Legacy and the Animation effects setting aside).

### Guided (Install AkariOS)
1. **Filter boxes** on the Apps and Tweaks steps (native Notes, W8b). The PowerShell app already has the logic
   (`Set-AkariAppsFilter`, `Set-AkariTweaksFilter`, called only with `''`), not the boxes. The Tweaks filter opens every
   Category expander it matches.
2. **Crumbs name the step**: native "Install AkariOS › Apps / Tweaks / Review & Apply"; the PowerShell app says
   "Install AkariOS › Guided" (`Steps.ps1:626`). `OpenCrumb(0)` returns to the chooser with the picks kept.

### Shell
3. **Titles as a small line of links above a normal heading** on every page (native, W8b); the PowerShell app's
   `Set-AkariHeader` makes the breadcrumb itself the title.
4. **Card grids whose rows are as tall as their tallest card** (`Views/CardGridLayout`); the PowerShell app's
   `New-AkariCardGrid` is a `UniformGrid` (every cell the size of the largest: the same cut / gap problem).
5. **Several jobs at once** (W6): native work is a `BusyWork` per job, the busy toast shows the latest; an install from
   Downloads and a change from Optimize run together; while a Run or a long ISO job holds `Locked`, Optimize's
   changes and Downloads' installs **queue** ("Waiting…") and run when it lifts. The PowerShell app has one job at a
   time (`$script:Busy`, one background runspace): the rest is refused or disabled.
6. **One closing question** naming everything running or waiting (`ClosingGuard`), then the Safe Mode question; the
   PowerShell app has two separate `Add_Closing` handlers (Catalogue, ISO Builder).

### Optimize
7. **Drill-down** (native Notes 2026-11-20): a Section's page lists its Categories as Settings rows in groups (icon,
   name, a line, the count badge, a chevron; `Shell/CategoryInfo`: Optimize Speed / Windows, Customize Desktop /
   Behaviour, Advanced System / Security and features, Tools Keep it running / Check and recover, Graphics & Hardware
   one group, no heading; a Category missing from the table goes under More with its first Tweaks' names); each
   Category has its own page (`Catalogue:<Section>/<Category>`, only its cards; Services / Scheduled tasks their
   lists too); crumbs Optimize › Section › Category; no SelectorBar (`Move-AkariToCategory`,
   `Update-AkariCategoryFromScroll` go). A suggestion opens the Category's page and flashes the card.

### Downloads
8. **Two sections** (Winhance's idea and layout only, rule 9): **Windows apps** = the four Remove lists as store
   cards (`ShownRows`, no gaps), a click on an installed app's card ticks "Remove", Remove (n) = one Run after the
   restore point (Remove apps' flow), a removed app that can come back has **Install** (`RestoreFor`: an appx row's
   `store` Entry of the same package, a legacy removal's install naming it in `RemoveWith`; never features), queued
   with the other installs, the lists read again after; "Only installed" starts off. **External apps** = the store
   cards without the Store reinstalls; a click anywhere picks a card (accent tint and outline), "Install (n)" queues the
   picks in the order shown, Clear; each card keeps its own Install.
9. **Store cards** (280 px at least): 48 px icon, full name on up to two lines, the type (AppType, else the
   category), a two-line description, the source, a small accent Install; Waiting / Installing as a line and a bar;
   Installed with a "…" menu (Uninstall) besides the right-click one; Failed with Try again.
10. **The Remove apps page and its nav item go**; its key opens Downloads › Windows apps. Guided's Apps step is
    unchanged.

### ISO Builder (I1-I6)
11. **I1 wizard**: six steps (Start, Windows image, Components, Build settings, Review, Create ISO), a stepper, Back /
    Next only once a step is complete (`CanNext`, `NextHint`), the image summary; Pro picked; zISO's option cards
    gone; Components reads the image the first time (Custom only).
12. **I2 build page**: stages (Waiting / Running / Done / Failed / Not run, with times), each an expander of its
    operations (an app, a feature, a capability, a package, a removed path, the settings, AkariOS, the answer file,
    .NET 3.5, the cleanup, the SHA-256), the current operation, the result (path, size, SHA-256, report path), Build
    another; `<name>.report.json` next to the ISO, success or failure.
13. **I3 build settings**: compression (Recovery ESD `install.esd` / Maximum WIM / Fast WIM), Turbo (one
    `dism /Disable-Feature` with a `/FeatureName` each, states read back), Remove leftover image data (an allow-list,
    kept while `pending.xml` exists), Leave .NET 3.5's setup files out (`sources\sxs` deleted after NetFx3). Review's
    Build settings card; the report carries them.
14. **I4 modes and removal groups** (`src/Core/Iso/Wizard/`, already shared): AkariOS / Lite / Custom cards, the removal
    plan; a wizard build uses the picked groups instead of `Always.psd1` (Registry / Files / Boot steps only when a
    group has rows or paths; NetFx3 and Cleanup right after Apps); the AkariOS mode's **bake** (registry-only Toggles
    and one-row Choices of the AkariOS preset written into the image's hives at `ImagePath`, as TrustedInstaller when
    refused) and **first sign-in** (RunOnce in the Default user's hive); the image's Store apps with their own icons
    (`AppLogos` from the image's manifests).
15. **I5 Microsoft's download**: the browser downloads from Microsoft's page, AkariOS reads its SHA-256 table, watches
    Downloads for a new `Win11*.iso` every 3 s and uses it only on a match (unreadable list: used, saying so).
16. **I6 Minimal** (Tiny11 Core) and Lite = Tiny11 (ADR 0010): the agreement dialog; the component store pruned
    (`Prune`, `KeepInComponentStore`), refused while pending servicing.
17. **zISO goes**: `src/Core/Iso/Data/` (options, `Always.psd1`, its licence) and CREDITS.md's zISO line.

### Already the same (checked, no batch)
Home (hero, tiles, Quick settings, Recent activity, update InfoBar), Settings (theme, accent, Import / Export, System
Restore, logs, About), Install USB, Services and Scheduled tasks lists, the search (suggestions, flash, highlight, tip,
Ctrl+F / Ctrl+E / Alt+Left), dialogs, toasts, One-click, Runs in phases.

## Batches

Each: Pester (`tests\Run.ps1`) and the native tests (`dotnet test --solution AkariOS.Native.sln` from `app\`) green,
AGENTS.md updated, this line marked done, one commit, then the VM check.

| Batch | What | Status |
| --- | --- | --- |
| P1 | Guided: filter boxes on the Apps and Tweaks steps; crumbs naming the step | done 2026-11-23 |
| P2 | Shell titles as a crumb line over the heading; Optimize's drill-down (Section page of Category rows, Category pages) |done 2026-11-23 |
| P3 | Downloads: two sections, store cards, selection and Install (n), Install for removed apps; card grid rows; Remove apps page and nav item gone; changes and installs queue while a job runs; one closing question |done 2026-11-23 |
| P4 | ISO I1: the wizard over today's engine; no page lock for the ISO's jobs | done 2026-11-23 |
| P5 | ISO I2: operations, the build page, report.json, size and SHA-256 | done 2026-11-23 |
| P6 | ISO I3: build settings | done 2026-11-24 |
| P7 | ISO I4: modes, removal groups, bake, first sign-in, image app icons | |
| P8 | ISO I5: Microsoft's download | |
| P9 | ISO I6: Minimal; zISO removed | |
| P10 | 1.5.0 | |

## Decisions (2026-11-23)

1. **Busy model (item 5)**: one job at a time stays. Optimize's changes and Downloads' installs made while a job runs
   queue ("Waiting…") and start when it ends, instead of being refused; one closing question names everything running
   or waiting, then the Safe Mode one (item 6). In P3.
2. **Category rows (item 7)**: the table moves out of C# into a shared `src/UI/Categories.psd1` (Section, Category,
   Group, line); the native `Shell/CategoryInfo` reads it through PsData (embedded like `UI/*.psd1`), so P2 changes
   native code for that alone. A test fails on a Category missing from it, in both apps.
3. **First sign-in (item 14)**: a PowerShell-built AkariOS image carries the PowerShell app (`C:\AkariOS`, as
   `Copy-AkariToImage` does now). New `Akari.ps1 -FirstSignIn`: the AkariOS preset in One-click's console, no restore
   point. The RunOnce value starts it elevated through `Start-Process -Verb RunAs`. The oracle leaves the copied app and
   the RunOnce command out, as it already leaves AkariOS out.
4. **zISO (item 17)**: removed from both apps in P9: the native port path (`IsoChoices.Options`, `IsoData.Options` /
   `Always`, the embedded `Core/Iso/Data/**`) goes too; the oracle's zISO cases become wizard cases.
5. **Oracle depth**: `IsoBuildOracleTests` also compares each operation's stage, name and state, and report.json
   without timings; the PowerShell build reports the same operations. `IsoDownloadOracleTests` gains Microsoft's
   download (P8).
6. **Titles (item 3)**: the native rule: a normal heading on every page, a small line of links above it only when
   the page has a parent.
