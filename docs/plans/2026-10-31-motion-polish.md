# Motion and polish: the PowerShell GUI

Decided 2026-10-31. The GUI looks finished but moves like a prototype: every hover, press, switch, tab, page, dialog
and progress change snaps instantly. The only animations today are the busy spinner and the status bar loop
(`MainWindow.xaml`). This pass gives the PowerShell version the motion a native app has, as far as WPF allows from
PowerShell, and fixes the stalls that make it feel slow. Engine, Tweaks, CLI and the Run are not touched: `src/UI`
only (plus tests).

After this plan is done, the native C# WPF app starts (`app/`, its own ADR and plan). It reuses this plan's motion
tokens and durations, so both apps move alike.

## What the code has today

- Styles: `MainWindow.xaml` (`Btn`, `BtnP`, `Ghost`, `Cap`, `CapX`, `Tab`, `Chip`, `Flat`, ContextMenu, MenuItem,
  ScrollBar, ToolTip) and `Controls.xaml` (`Switch`, `CatSwitch`, `Check`, `Radio`, `ComboItem`, `Combo`, `SegItem`,
  `Segmented`, `SettingCard`, `CategoryCard`, `Accent`, `ModeCard`, `ModeCardHot`, `StepNum`). Every state change is a
  plain `Trigger` + `Setter`: brushes swap, sizes and `HorizontalAlignment` jump (the switch thumb jumps from Left to
  Right).
- Brushes come only through `DynamicResource` (theme swap at runtime, a test checks). Those brushes are frozen and
  shared: a `ColorAnimation` on them throws or recolours every control at once.
- XAML is read as text (`Get-Content -Raw`) and parsed by `XamlReader::Parse` in `Shell.ps1` (MainWindow, Controls,
  Icons, Theme), `Dialog.ps1`, `Rows.ps1`. So Akari can change the text before parsing (used below for reduced motion).
- Pages: `Show-Page` (`Shell.ps1`) flips `Visibility` of `HomePanel` / `StepsPanel` / the Catalogue page and rebuilds
  `Rows.Children` in PowerShell. Nothing fades; heavy pages (Catalogue, Services "Show all", Unattend, ISO Builder)
  block the UI thread while they build.
- Popups: the combo dropdown already uses `PopupAnimation="Fade"`; context menus, the options menu and tooltips don't.
- Effects: `DropShadowEffect` glows on `BtnP`, `Accent`, `ModeCardHot`, the menu and the dialog. They are expensive
  to redraw, so they must never be animated or sit under an animating element without a cache.

## Decisions

1. **Motion tokens.** One set of durations and easings, `UI/Motion.xaml`:
   `Motion.Fast` 120 ms (hover, press), `Motion.Base` 200 ms (switches, checks, tabs, popups),
   `Motion.Slow` 280 ms (pages, dialogs), `Motion.Stagger` 30 ms (cards one after another), easing
   `Motion.Ease` = `CubicEase EaseOut`, `Motion.Spring` = `BackEase EaseOut Amplitude 0.3` (switch thumb only).
   Storyboards inside templates are frozen, so they take these through `StaticResource`, never `DynamicResource`.
   `Shell.ps1` adds the contents of `Motion.xaml` to each dictionary that uses it before parsing (`Get-AkariXaml
   <file>`), so the values exist in only one file. A test fails any `Duration="…"` literal in a Storyboard.
2. **Animate Opacity and transforms only, never brushes.** A hover is a layer (`Border` / `Rectangle` filled with
   `CtlH`, `AccH`…) whose Opacity fades 0 → 1; a press is a `ScaleTransform` 1 → 0.97; the switch thumb moves through a
   `TranslateTransform.X`, not `HorizontalAlignment`. That keeps every brush a `DynamicResource` (theme swap still
   works) and keeps animation on the render thread. A test fails a `ColorAnimation` / `ColorAnimationUsingKeyFrames`
   in any UI XAML.
3. **Triggers keep the state, `EnterActions` / `ExitActions` animate to it.** The Setter remains the source of truth
   (Detect, keyboard, theme swap all still land right); the storyboard only smooths the way there. Every
   `EnterActions` has a matching `ExitActions` back.
4. **Reduced motion.** When Windows has animations off (`[Windows.SystemParameters]::ClientAreaAnimation` is false, the
   "Animation effects" setting), `Get-AkariXaml` writes every Motion duration as `0:0:0` before parsing. Code-started
   animations (`Start-AkariMotion`, below) check the same flag. A test checks both.
5. **Code-started motion goes through one helper.** `Start-AkariMotion <element> Fade|Rise|Pop|Scale [-From] [-To]
   [-Delay]` in a new `UI/Motion.ps1` (pure parts first, tests dot-source it), built on `BeginAnimation` with the token
   durations read from the window's resources. No other file calls `BeginAnimation` directly.
6. **Build first, then animate.** A page fades in only after its content is built: `Show-Page` builds, then queues the
   animation on the Dispatcher at `Loaded` priority, so the first frame shows the animation start, not a frozen
   half-built page. Heavy rebuilds are avoided, not just hidden (step 6).
7. **Effects stay static.** No animation targets a `DropShadowEffect` or an element that has one; a glowing button
   fades its glow layer (a sibling with the effect and `BitmapCache`), never the effect itself.

## Steps

Each step ends with tests green (`tests\Run.ps1`) and a VM check by the user (rule 12: never on the dev machine).

### 1. Motion foundation
- `UI/Motion.xaml` (the tokens), `Get-AkariXaml <file>` in `Shell.ps1` (token merge + reduced motion), used by every
  `XamlReader::Parse` call in `Shell.ps1`, `Dialog.ps1`, `Rows.ps1`.
- `UI/Motion.ps1`: `Start-AkariMotion`, `Test-AkariMotionOn`.
- Tests (`tests/Ui.Tests.ps1`): no Duration literals in Storyboards, no ColorAnimation, every `EnterActions` has an
  `ExitActions`, every parsed file still parses with motion on and off, durations are `0:0:0` with motion off.
- AGENTS.md: the new files and helpers.

### 2. Controls (`Controls.xaml`)
- `Switch` / `CatSwitch`: thumb slides (`TranslateTransform.X`, `Motion.Spring`), grows on hover and stretches while
  pressed through `ScaleTransform`; the track's `Acc` fill is a layer that fades in; Unchanged slides the thumb to the
  middle.
- `Check`: the mark scales 0.6 → 1 and fades in; the fill layer fades. `Radio`: the dot scales from 0.
- `Combo`: hover layer fades, the chevron rotates 180° while open; `ComboItem` highlight fades.
- `Segmented` / `SegItem`: the old segment fades out as the new one fades in. (Done this way, not a sliding pill: the
  segments wrap onto a second line in a narrow card, where one indicator would have to jump rows.)
- `Accent`, `ModeCard`, `ModeCardHot`: hover lift (`TranslateTransform.Y`: −1 px the button, −3 px the card) and press
  scale; `Accent`'s glow is its own cached layer under the fades. `ModeCardHot` keeps its glow on the button (one
  card, a short hover only).
- `SettingCard`, `CategoryCard`: left as they are (plain Border styles with no template, and not clickable: a hover
  would suggest they are).
- `StepNum`: Current / Done pop in (the colours change at once).
- Done (2026-10-31). Each animated value belongs to one trigger (the switch thumb: size, hover, press, middle, on
  transforms), so overlapping triggers never fight; a trigger true at load plays then (a switch already on slides in).
  Test: every control built off screen, its states flipped, ends on the right values with motion on and off.

### 3. Shell (`MainWindow.xaml`)
- `Btn`, `BtnP`, `Ghost`, `Cap`, `CapX`, `Chip`, `MenuItem`: hover layer fade, press scale (not on caption buttons:
  Windows' own don't).
- `Tab`: the old tab's crimson tint fades out as the new one's fades in; hover and press fade. (A pill that slides
  between tabs needs code that follows the tabs' widths as the window resizes: step 7, if time allows.)
- `Flat`: the focus stroke and `AccSoft` halo fade in.
- `ContextMenu` (Quick select, the options menu): fades in and drops 6 px into place; `ToolTip` fades in.
- `ScrollBar`: thumb thin by default, widens and brightens while the mouse is over the bar (Windows 11 style).
- Status bar: progress glides (`Set-AkariStatusProgress`: the fill is full width, `Start-AkariMotion Fill` scales it
  from the left) instead of jumping.
- Done (2026-10-31): `Btn`, `BtnP` (glow on its own cached layer), `Ghost`, `Cap`, `CapX`, `Tab`, `Chip`, `Flat`,
  `MenuItem`, `ContextMenu`, `ScrollBar`, `ToolTip`, the progress fill. Test as step 2's.

### 4. Pages and dialogs
- Page change: the page surface fades and rises 10 px (`Motion.Slow`) after `Show-Page` builds it; the header text
  cross-fades. Search results fade in the same way.
- Catalogue / Legacy / Review rows: the first 12 cards fade and rise one after another (`Motion.Stagger`); the rest
  appear at once (no long waits on big pages).
- Guided steps: Next / Back slide the step left / right.
- Home: the mode cards stagger in on first show; the stats count up when they arrive (`Complete-AkariHomeStats`).
- Dialogs (`Dialog.xaml`): the card fades and scales 0.96 → 1, the `ModalOverlay` dim fades in and out. The card
  itself closes at once (animating it out would hold the window open after Enter / Esc).
- The update bar, Catalogue restart / Safe Mode bars: slide into place when they appear instead of popping in.
- Done (2026-10-31): `Start-AkariEntrance` (hidden now, played at Loaded priority, shown at once if it fails),
  `Start-AkariStagger`, `Show-` / `Hide-AkariElement`, `Start-AkariCount` in `Motion.ps1`; `Show-Page` decides a
  page is new (`$script:PageMoved`: another page, or the search starting / ending; typing only refreshes);
  `Show-AkariSteps` slides by the step's direction. The Shell navigation test runs with motion off; the helpers have
  their own test with motion on and off.

### 5. Smooth scrolling
- The page `ScrollViewer`s scroll by an eased offset instead of jumping per wheel notch: `Enable-AkariSmoothScroll
  <scrollViewer>` handles `PreviewMouseWheel`, animates toward a target offset on `CompositionTarget.Rendering`, and
  stops listening once it arrives (no per-frame cost when idle). Touchpads (small deltas) scroll as they do now.
  Behind a check on the VM: dropped if it feels worse than the default.
- Done (2026-10-31): `Enable-AkariSmoothScroll` on `PageScroll` (Windows' wheel lines x 16 px per notch, eased to the
  target, settled in about a third of a second; an inner scrollable part keeps the wheel), `Reset-AkariScroll` puts a
  new page at the top (before, a page opened where the last one had been scrolled).

### 6. Stalls (what motion can't hide)
- Measure first: a debug run (`$env:AKARI_UI_TIMING = 1`) logs to akari.log every page build (`Show-Page`, through
  `Start-` / `Stop-AkariUiTimer`), the launch time, and every UI-thread stall over 200 ms with the page it happened on
  (`Start-AkariStallWatch`). Fix the slowest ones, in order. (Done 2026-10-31: the measuring. The fixes below wait for
  the numbers from a VM run.)
- Expected: Catalogue page build (cards cached already: check the first build), Services / Scheduled tasks "Show all"
  (hundreds of rows built in PowerShell: build in chunks at `Background` priority so the first screen shows at once and
  the rest fills in while the page stays responsive), the Unattend page's ~2 s first build (show a skeleton, build in
  chunks), the ISO Builder's first build.
- Skeleton rows (pulsing placeholders, `Motion.Slow` loop) wherever a list is read in the background: Services,
  tasks, the Apps feature lists, Catalogue States.

### 7. Finish
- Pass on every page in both themes, light and dark, with motion on and off; fix anything that flickers, jumps or
  leaves a control half-animated after a theme swap.
- Optional: a tab pill that slides between tabs (step 3).
- CREDITS.md if any technique is taken from another project. Release notes.

## Not in this plan

- The native C# WPF app (`app/`): next, with its own ADR (a second front end and engine in C#, same repo, PowerShell
  version kept) and plan. It takes `Motion.xaml`'s tokens as they end up here.
- New features or layout changes: this pass changes how things move, not what is on the page.
