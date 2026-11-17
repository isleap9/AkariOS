# AkariOS looks like Windows 11 and takes the user's accent colour

Decided 2026-11-17 (plan `docs/plans/2026-11-17-windows-11-style.md`). Supersedes ADR 0006's identity (crimson accent
and lamp glows, Unbounded / Manrope / JetBrains Mono, Lucide line icons, pill controls, top tabs, hero); keeps its
theme mechanism (two brush dictionaries swapped at runtime, every brush a `DynamicResource`, no colour literal outside
`Theme.Dark.xaml` / `Theme.Light.xaml`). Both apps change: `src/UI` and the native app, which loads the same XAML.

AkariOS takes the Windows 11 Settings look: WinUI 3's colours, type ramp (Segoe UI Variable), control metrics and
layout (a left NavigationView, settings cards, InfoBars), Fluent System Icons, and **the user's Windows accent colour**
instead of crimson. The brand stays in the logo (the crimson chevron), and nothing else in the UI is crimson.

The own identity made AkariOS recognisable, but next to the Windows settings it changes it read as a themed web page,
and the crimson-on-everything made routine choices look alarming. A tool that changes Windows settings reads as
trustworthy when it looks like the Settings app it sits next to; the user's own accent is what Windows apps use. The
fonts and icons are Windows' own or Microsoft's (MIT), so nothing ships under the OFL any more.

## Considered Options

- **Keep the identity, soften it** (fewer glows, a calmer crimson): rejected; the fonts, pills and top tabs still read
  as a web page beside Windows Settings.
- **WinUI 3 / Windows App SDK for the native app**: rejected for now; the PowerShell app can only use WPF, and both apps
  share one set of XAML. The look is rebuilt in WPF from WinUI's metrics.
- **A fixed blue accent**: rejected; Windows apps follow the user's accent, and the palette is one registry read.

## Consequences

- Accent at runtime: both apps read the real user's `Explorer\Accent\AccentPalette` (rule 6: the signed-in user's
  hive, not the elevated account's; the native app reads it through its registry engine for the same reason, instead
  of `UISettings`) and put `Acc AccH AccP AccT AccText AccSoft Info` into the current theme dictionary
  (`Set-AkariAccent` / `Get-AkariAccentColors`, `Look/Accent.cs` + `ThemeService`), again on `WM_SETTINGCHANGE`
  "ImmersiveColorSet" and `WM_DWMCOLORIZATIONCOLORCHANGED`. An unreadable palette keeps the theme file's default blue.
- No glows: the `Glow` and `AccC` keys and every accent `DropShadowEffect` go; shadows stay only on tooltips, flyouts,
  dialogs and tiles on hover.
- Segoe UI Variable is missing on Windows 10: the font families fall back to Segoe UI, which is close enough.
- The change lands in batches (tokens, type, icons, controls, shell, pages, native parity); between batches the app
  mixes the old layout with the new colours.
