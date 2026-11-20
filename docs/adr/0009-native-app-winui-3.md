# The native app is a WinUI 3 app on the WinUI 3 MVVM framework

Decided 2026-11-19 (plan `docs/plans/2026-11-19-native-winui-3.md`). Supersedes ADR 0007's "WPF" and its **Look**
point; the rest of ADR 0007 stands (one repo, shared data, the parity test, the same rules and vocabulary).

ADR 0008 gave the PowerShell app WinUI 3's look, rebuilt in WPF from WinUI's values, because PowerShell can only host
WPF. The native app has no such limit, so it stops imitating WinUI and **is** WinUI 3: Windows App SDK, unpackaged
and self-contained, on .NET 10. Its window, NavigationView, Mica, settings cards, InfoBars, ContentDialogs, controls
and motion are WinUI's own; Akari crimson is its accent (WinUI's `SystemAccentColor*` ramp from ADR 0008's values).

The app is built on the WinUI 3 MVVM framework (the author's `WinUI-3-MVVM-Framework`, copied into
`app/AkariOS.Framework`, renamed, with its tests): `Microsoft.Extensions.Hosting` and DI, `FrameNavigationService`,
settings, theme, dialog, file picker and InfoBar services, converters, behaviors, collections. Pages are XAML Views
over CommunityToolkit.Mvvm view models; the view models hold the logic and are tested without WinUI objects (a
WinUI object can't be made in a test host). The engine (`AkariOS.Core`, `AkariOS.Tweaks`) is unchanged. The CLI
(`Cli.cs`, `RunConsole.cs`, `--resume`, One-click's console) moves over as it was: `Program.Main` runs it before any
XAML is loaded.

## Considered Options

- **Keep WPF, bring its views to ADR 0008's look** (the WinUI 3 plan's batch 7): rejected; it rebuilds by hand what
  WinUI has, and keeps the shared-XAML loader, the motion port and the custom controls to maintain.
- **WinUI 3 packaged (MSIX)**: rejected; the app runs elevated (`requireAdministrator`), updates itself in place and
  ships as one exe next to the PowerShell app's zip.
- **Another UI stack (Avalonia, MAUI)**: rejected; neither is Windows 11's own look.

## Consequences

- The native app no longer reads `src/UI/*.xaml` (`Theme.*`, `Icons`, `Motion`, `Controls`, `MainWindow`): the
  PowerShell app's XAML is its own again, and changing it can't break the native build. The two apps share the
  accent's values and the page layout (the prototype), not files.
- `AkariOS-Native.exe` stays one self-contained file (`PublishSingleFile`, `EnableMsixTooling` for the embedded
  `resources.pri`, `WindowsPackageType` None), so the updater (the running exe renamed `.old`) is unchanged. About
  115 MB.
- The WPF app's pages are rebuilt batch by batch (W2-W8); until then a page shows which batch brings it. The WPF code
  stays in git (commit `3ee49b6`) as the reference for each page's behaviour; its App tests go, the CLI's stay.
- Tests: the framework's own (`tests/AkariOS.Framework.Tests`, on xUnit v3) and the view models' in
  `AkariOS.App.Tests`; the WPF STA page harness (`AppHarness`, `LookTests.OnSta`) is gone.
- Projects that use the Windows App SDK build for x64 only (`win-x64`), as the release does.
