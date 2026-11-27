# Both apps wear the Aurora banner: a page's light, the Akari bloom and glass

Decided 2026-11-26 (the design canvas "AkariOS app redesign", page D; the native app since 2026-11-26, the PowerShell
app since 2026-11-27, plan `docs/plans/2026-11-26-aurora-powershell.md`). Amends ADR 0008: everything there stands but its "no glows"
rule, which this replaces for the page background, the banner and the cards listed below.

A page shows a soft light behind its top: three radial glows in the page's own colours, drifting slowly, and the Akari
bloom (three ribbons and a corner glow) in the top right corner, fading out downwards. The page's header is a banner on
that light with no card behind it (crumbs, a 40 px title, one line of lead, the page's main actions on the right). The
main cards and panels sit on **glass**: a translucent fill the light shows through, a hairline stroke whose top pixel is
brighter. Featured cards (One-click's) carry the bloom in their corner. Each page has its palette (Home, Install,
Optimize, Remove, Downloads, Usb, Iso, Settings).

ADR 0008 made AkariOS read as Windows 11 Settings; beside it, every page looked the same and nothing said which part of
AkariOS you were in. The light gives each page a colour and the brand a shape (the bloom) without putting crimson on
controls: the controls, type ramp, motion tokens and accent rules of ADR 0008 do not change.

## Considered Options

- **Keep ADR 0008's flat pages**: rejected; the redesign was asked for and the native app already ships it.
- **The light on Home only**: rejected; the palettes are what tells the pages apart.
- **Native app only**: rejected; both apps ship in one release and should look like one product (ADR 0007).

## Consequences

- Decoration only: never hit-tested, hidden from screen readers, gone in high contrast (followed live), still when
  Windows' animation effects are off (ADR 0008's motion switch; the fade-in then takes no time).
- Motion: a 1.2 s fade in once per page load; the glows drift (16 / 19 / 13 s), the ribbons sway (9 s, 24 px left and
  10 px down, inside an overscan so no edge shows) and breathe (opacity 0.85 to 1), each forever and back. Opacity and
  transforms only, as ADR 0008 asks.
- The fade at the bloom's bottom: an opacity mask where the toolkit has one (WPF); the native app (WinUI 3, no element
  opacity mask) fakes it with still horizontal strips on whole pixels, the drawing swaying inside them.
- Glass: WinUI's in-app acrylic in the native app; WPF has none, so the PowerShell app uses a translucent theme brush
  over the light and the window's Mica (no blur). Solid system colours in high contrast.
- Hover: the native app lifts a tile 2 px with a fill overlay and no shadow (WinUI's ThemeShadow is rectangular); WPF's
  `DropShadowEffect` follows the shape, so the PowerShell app may keep ADR 0008's shadow on tiles on hover.
- The palettes' and glass's colours live in the theme files (`Theme.Dark.xaml` / `Theme.Light.xaml` in the PowerShell
  app, `App.xaml`'s ThemeDictionaries and `AuroraBackdrop.Palettes` in the native app); no colour literal elsewhere.
- The PowerShell app's light stays still in software rendering (WPF render tier 0) as well as with motion off; a
  featured card's bloom reads high contrast when its page is built (the light behind the page follows it live).
