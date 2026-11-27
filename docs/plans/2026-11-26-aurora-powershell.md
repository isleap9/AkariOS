# The Aurora banner in the PowerShell app

ADR 0011. The native app has it (2026-11-26: `app/AkariOS.App/Controls/AuroraBackdrop.cs`, `RibbonArt.cs`,
`BloomMark.cs`, `PageBanner.xaml`, `Contrast.cs`, `Motion.cs`, `App.xaml`'s glass, `Views/Cards.xaml`'s `Tile`); this
plan brings the same look to `src/UI` (WPF, PowerShell 5.1). Visual only: no page's logic, command, name a test or
another file uses, or behaviour changes. The design: the canvas "AkariOS app redesign", page D
(`project/D-*.dc.html`); where the design shows a feature AkariOS lacks (Home's Tweak packs and This PC, Settings'
Safety switches, Install USB's drive list and presets, the ISO Builder's Bake in), take the layout only.

## Rules that still hold (AGENTS.md, ADR 0008)

- Brushes and colours only in `Theme.Dark.xaml` / `Theme.Light.xaml` (same keys in both), named through
  `DynamicResource` / `SetResourceReference`; no hex in other XAML or code (a test checks).
- Every animation through `UI/Motion.ps1` (`Start-AkariMotion`, `Start-AkariLoop`...), Opacity and transforms only,
  durations from `Motion.xaml` or 0 with motion off (`Test-AkariMotionOn`); a Storyboard that repeats Forever may use
  its own times (the aurora's 16 / 19 / 13 / 9 s). Every trigger with `EnterActions` has `ExitActions`.
- XAML parsed only through `Get-AkariXaml`; UI files without a BOM keep non-ASCII out of their code.
- Rule 12: never launch the GUI here. Pester tests only (`tests\Run.ps1`); the user checks on the VM.
- Update AGENTS.md's `UI/` entries in the same change.

## Traps in the existing tests (`tests/Ui.Tests.ps1`, Describe 'Themes')

- The theme key list reads only `SolidColorBrush` and `Color` elements of each theme file, and 'define every brush the
  UI uses' matches names `[A-Za-z0-9]+`: so name keys without dots (`AuroraHomeA`, not `Aurora.Home.A`), and make the
  glass stroke's gradient out of theme `Color`s (`GlassEdgeTop`, `GlassEdge`) used by a `LinearGradientBrush` defined
  in `Controls.xaml` (or extend the test to read gradient brushes too, in the same change).
- No key named `Glow` or `AccC` (the tests forbid them; `GlowOpacity` is a `sys:Double`, not a brush: keep it out of
  the theme files' brush list, or call it `PaneGlowOpacity` and extend the key reader).
- 'take the plan's values' pins `Bg`, `Surf`, `Acc`...: the aurora adds keys and changes none of those.

## The values (the native app's, to copy)

**Palettes** (three glows A, B, C, then the ribbons' colour and its light end), as theme Colors
`Aurora<Palette><A|B|C|Ribbon|RibbonLight>` (e.g. `AuroraHomeA`) in both theme files (the same in dark and light; the opacities differ):

| Palette | A | B | C | Ribbon | RibbonLight |
| --- | --- | --- | --- | --- | --- |
| Home | E3263F | A21CAF | FF7A3C | E3263F | FF9AA6 |
| Install | FF4D2E | E3263F | FF9A3C | FF4D2E | FFB199 |
| Optimize | E3263F | 7C3AED | FF7A3C | E3263F | FF9AA6 |
| Remove | 0F9D8A | 2B6FFF | 14B8A0 | 0F9D8A | 7CE0CF |
| Downloads | 2B6FFF | 0EA5E9 | 7C3AED | 2B6FFF | 9CC4FF |
| Usb | 5B6B82 | 2B6FFF | 94A3B8 | 5B6B82 | C4CDD8 |
| Iso | A21CAF | E3263F | 7C3AED | A21CAF | E59CF0 |
| Settings | E3263F | 64748B | A21CAF | E3263F | FF9AA6 |

Pages: Home = Home; Install AkariOS = Install; Optimize and every Catalogue page = Optimize; Downloads = Downloads on
External apps, Remove on Windows apps; Install USB = Usb; ISO Builder = Iso; Settings = Settings; Search = Optimize.

**The backdrop**: 460 px tall (640 on Home), top of the page, behind the scroller, scrolls away with nothing (it stays
at the top of the content layer; the page scrolls over it). Glows layer opacity 0.55 dark / 0.32 light; ribbons'
box 0.8 dark / 0.55 light. Three glows, each an ellipse with a radial gradient colour → transparent:

| Glow | anchored | x (share of page width) | width (share) | top px | height = backdrop − | opacity | drift x (share of own width) | drift y px | scale from → to | seconds |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | left | −0.08 | 0.62 | −160 | 180 | 1.0 | 0.08 | 30 | 1.0 → 1.15 | 16 |
| B | right | −0.06 | 0.56 | −120 | 220 | 1.0 | −0.10 | 40 | 1.1 → 0.95 | 19 |
| C | left | 0.34 | 0.42 | 60 | 320 | 0.7 | 0.12 | −30 | none | 13 |

Each drift is a sine ease in-out, AutoReverse, forever. The ribbons' box: anchored top right, 64 % of the page wide,
230 px tall (340 on Home); the drawing (below) covers it from the top right (SVG `xMaxYMin slice`) with 24 px of
overscan past the right edge and 10 px above the top; it sways X 0 → −24, Y 0 → 10 over 9 s, and its host's opacity
0.85 → 1 over 9 s, all forever and back. The bottom fade: an `OpacityMask` (a vertical LinearGradientBrush, opaque to
40 % of the box's height, transparent at its bottom) on the box, which does not move (WPF has one: no strips). Fade in:
the whole backdrop's opacity 0 → 1 over 1.2 s, cubic ease out, once per page shown. Recompute sizes on the page's
width change (the drift's distance too). Hidden (Collapsed) in high contrast (`SystemParameters.HighContrast`, followed
on `SystemParameters.StaticPropertyChanged`); still with motion off.

**The drawing** (560 x 280, `RibbonArt.Drawing`): a 560 x 280 rectangle filled with a radial gradient centred at
(0.78, 0.2), radius 0.6, Ribbon at alpha 140 → alpha 0; then three closed paths (start, cubic out, line to corner,
cubic back), each filled with a linear gradient:

1. M150,280 C250,200 330,80 560,30 L560,110 C390,130 300,210 260,280 Z; gradient (0,1)→(1,0): Ribbon a0 @0, Ribbon a230
   @0.55, RibbonLight a255 @1; opacity 1.
2. M280,280 C350,215 430,160 560,140 L560,196 C470,205 410,240 380,280 Z; gradient (0,1)→(1,0.2): RibbonLight a0 @0,
   RibbonLight a217 @0.7, white a230 @1; opacity 0.75.
3. M200,0 C310,50 440,60 560,0 L560,34 C440,92 300,80 200,0 Z; gradient (0,0)→(1,1): Ribbon a0 @0, Ribbon a179 @1;
   opacity 0.6.

A WPF `DrawingBrush` / `DrawingImage` with `Stretch="UniformToFill"`, `AlignmentX="Right"`, `AlignmentY="Top"` does the
cover and anchoring in one. The gradients' colours come from the palette: build the drawing in XAML with
`DynamicResource` colours per palette, or in code with `SetResourceReference` on each GradientStop's Color.

**The bloom** (a featured card's corner: Install AkariOS' One-click tile and Home's One-click tile): the same drawing in
a 360 x 180 box in the card's top right corner (smaller when the card is), opacity 0.7, faded out from 20 % of its
height, still; clipped to the card's inner corner (8 − 1 px); takes no room; the card's padding 0, the content over it.

**The banner** (replaces the page header's look; `Set-AkariHeader` keeps its parts and names): min height 150 px,
padding 4,8,0,8, the text at its bottom with 8 px between lines: the crumbs (the `Crumb` links, a ` › ` between), the
title at 40 px (`FontDisplay`, SemiBold, WinUI's TitleLarge: 40 / 52 line height), one line of lead in the secondary
text brush, at most 640 px wide; the page's main actions on the right at the bottom, under the text below 640 px.

**Glass**, theme brushes `Glass` and `GlassStroke` (+ `GlowOpacity`): dark `Glass` = #2A2425 at about 65 % (the
acrylic's tint 0.5 + luminosity 0.62 over #2D2728 fallback: try #A62A2425 and judge on the VM), `GlassStroke` a vertical
gradient (absolute, 0 → 2 px) #26FFFFFF, #26FFFFFF, #14FFFFFF; light `Glass` = #8CFFFFFF (tint 0.55 / luminosity 0.75),
`GlassStroke` #FFFFFFFF, #FFFFFFFF, #CCFFFFFF; `GlowOpacity` 0.33 dark / 0.25 light (the nav pane header's accent glow).
High contrast: the system's window and text colours. Styles: `GlassCard` (Border: Glass, GlassStroke, 1 px, 8 px
corners, 16 padding), `GlassTile` (the tile on the glass; hover: lift 2 px (`Motion.Fast`) under a subtle fill overlay,
plus ADR 0008's tile hover shadow), `GlassRow` (68 px min, padding 16,12, a row that opens a page).

**What goes on glass** (as the native app): Home's hero and tiles, Install's chooser tiles, Review's group panels
(Remove and Install on the left beside the Tweaks in a 1.3 times wider column, one column under 800 px, rows split by
hairlines), the run page's list, Optimize's Section cards, a Section's Category rows (`GlassRow`), the toolbars of the
Catalogue's lists, Settings' sections (one glass panel each, rows split by hairlines, 64 px rows at least, a hover fill),
Install USB's numbered sections (1 Drive: the USB and Refresh; 2 Setup choices: the expanders) with Save to a folder… /
Save to USB in a glass footer beside the USB's name, the ISO Builder's step cards and its 280 px side panel (the steps
as a list, the image; under 1000 px the stepper row instead), the step footers, toasts and the busy toast. Stay as they
are (cards): the Catalogue's Tweak cards, service / task / startup / game rows, app cards and tables, Guided's
Category expanders. Downloads' SelectorBars and toolbars sit on the light, Update all apps in its banner. Entrances:
the page's children rise 16 px staggered (`Start-AkariPageEntrance` already does 28 px: use the design's 16).

**Narrow**: Install's tiles and count cards stack under 600 px; Downloads' toolbars wrap under 800 px; Install USB's
drive bar under 700 px.

## Batches

1. Theme keys (palettes, glass, glow) in both theme files; `Glass*` styles in `Controls.xaml`; `UI/Aurora.ps1` (new,
   dot-sourced after `Motion.ps1`): `New-AkariAurora`, `Set-AkariAuroraPalette <name>`, `Update-AkariAuroraSize`,
   `New-AkariBloom`, pure helpers first (`Get-AkariAuroraGlows <width> <tall>` → each glow's size and margin,
   `Get-AkariAuroraRibbonBox <width> <tall>`, `Get-AkariPagePalette <page> <query>`), its motion through `Motion.ps1`
   (add `Start-AkariDrift` if needed). The backdrop goes once into `MainWindow.xaml`'s content layer behind
   `PageScroll`; `Show-AkariPageNow` sets the palette and fades it in. High contrast and motion off. Tests:
   `tests/Aurora.Tests.ps1` (the pure helpers, every palette key in both themes, no hex outside the themes, the rules
   tests still green).
2. The banner: `PageHeader` restyled, `Set-AkariHeader` gains an optional lead and actions (every page's lead from the
   native `PageBanner`s' text; check the native Views for each page's Lead).
3. Pages, one at a time, each its own check on the VM: Home, Install AkariOS (chooser, Guided, Review, run, result),
   Optimize and the Catalogue pages, Downloads, Install USB, ISO Builder, Settings, Search.
4. AGENTS.md, CREDITS (nothing new), ADR 0011's last line if anything changed.

## Status (2026-11-27)

Batches 1-4 done, Pester green; waiting for the VM check. Where the port differs from the native app or this plan:

- No `GlowOpacity`: the PowerShell app has no pane header glow (and the Themes test forbids `Glow` keys). `GlassStroke`
  is a `LinearGradientBrush` in the theme files; the Themes test reads gradient brushes too.
- The light stays still in render tier 0 too; each drift runs at 30 fps.
- Home follows the native app, not this plan: the hero straight on the light (112 px logo, overline, 40 px headline),
  the facts as three glass cards under it, tiles with no bloom or Acc stroke (One-click's footer in AccText), then Since
  AkariOS. Install's chooser keeps the Acc stroke beside its bloom. A tile's bloom reads high contrast when its page is
  built.
- Settings: Appearance, Settings files and Recovery are glass panels (`GlassListRow`, `GlassListButton`); About stays an
  expander (its update status, links and credits). Since AkariOS, Quick settings and Recent activity stay cards.
- Install USB's saves are in a page footer the shell owns (`PageFooter`, `Set-AkariPageFooter`).
- Home's and the chooser's tiles go by the content layer's width (600 px); the other narrow rules by the element's own
  width (the page less its 36 px sides): 528 / 628 / 728 / 928 px for the design's 600 / 700 / 800 / 1000.
