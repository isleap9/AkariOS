# AkariOS has its own visual identity instead of the Windows Settings look

Decided 2026-10-30 (plan `docs/plans/2026-10-30-redesign.md`). The GUI drops the WinUI / Windows 11 Settings look it
copied (Segoe UI, Segoe Fluent glyphs, a white accent, square-ish cards) for AkariOS's own, from the AkariOS design
system: warm black and warm paper themes, one crimson accent with a "lamp" glow on the main action, Unbounded for
titles, Manrope for text, JetBrains Mono for ids, Lucide line icons, pill controls, rounded cards with icon blobs.
Dark and light themes are two brush dictionaries swapped at runtime (`Set-AkariTheme`), following Windows by default.

A debloat tool that looks like Windows Settings reads as part of Windows, and users can't tell where Windows ends
and AkariOS begins; an identity of its own makes it recognisable (a launcher, a release page and the app all look the
same) and lets the one crimson accent mean "this changes your PC". The fonts and icons ship with the app (SIL OFL,
ISC), so it looks the same on every PC, without a font install.

Only `src/UI` and `src/Assets` change: the engine, Tweaks, CLI and Runs don't, and every brush, font and icon goes
through a resource key, so the next change of look is again a styles-only change.

## Considered Options

- **Keep the WinUI look, recolour it crimson**: rejected; Segoe and Fluent glyphs keep it reading as Windows, and
  the white-accent controls didn't carry a colour well.
- **Dark only**: rejected; a light theme is expected and costs one dictionary, since every colour is a key.
- **Fonts from the system, icons from Segoe Fluent**: rejected; Windows 10 lacks Segoe Fluent Icons and the
  Variable fonts, so the app looked different on 10 and 11.

## Consequences

- No hex colours in styles or code: a test checks every brush the UI names exists in both themes.
- Icons are geometries generated from Lucide (`build/Icons.ps1` → `UI/Icons.xaml`); a new icon means adding its name
  there and regenerating.
- Mica stays on Windows 11 in dark (behind a 90% tint); the light theme and Windows 10 are solid.
- Phase 2 (a top bar instead of the sidebar) is a separate decision in the plan.
