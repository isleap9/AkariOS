# HERMES.md — assistant memory for the AkariOS project

_This file is written for the AI assistant (Hermes) working on this repo. It captures
everything important from the development chats so future sessions start fully oriented.
Read this before doing anything. Docs: [TODO.md](TODO.md) (plan), [ROADMAP.md](ROADMAP.md)
(shipped), [LOG.md](LOG.md) (session history)._

## The project in one paragraph

AkariOS is a WinUI 3 app (`net10.0-windows10.0.26100.0`, win-x64, MVVM Toolkit) that is a
focused front-end for the **AME Wizard Core engine** (TrustedUninstaller.CLI, MIT,
consumed as released 0.8.4 binaries). It ships ONLY the user's own playbook
(AkariOS V5, now **V6.0.0**) bundled inside the app. The user picks options in a wizard and
clicks one button to apply. The legacy ISO-builder pipeline (staging/$OEM$/wimlib/oscdimg in
`AkariOS.Core`) still exists in code but is deliberately NOT exposed in the UI.

## Absolute rules (violating these angers the user)

1. **NEVER run the playbook / engine / CLI against the host machine.** Destructive debloat.
   Engine runs happen ONLY in the user's VM, STARTED BY THE USER. The agent may build, run
   unit tests, launch the UI shell, prep files — nothing more. This rule exists because the
   agent once started an engine run on the host (stopped at UAC) and later wired an
   "Apply to this PC" button into a running host instance. User was emphatic.
2. **Never touch the user's brand assets' appearance** (logo colors/transparency etc.)
   without explicit permission. Size/placement changes are fine.
3. UI/shell changes need a design presented first; service-layer work doesn't.
4. Be specific about file/folder paths when giving VM instructions — ambiguity frustrates him
   (his C: drive volume label is literally "AkariOS", which caused confusion once).
5. He wants LOG.md kept current every session ("so we can always reference where we at").

## Key people/context

- User: solo dev `isleap9`, iterative, tests everything himself in a VM and reports back
  with screenshots/logs. Prefers honest effort estimates and being consulted on big decisions.
- Discord: Akari Labs — https://discord.gg/UjjmYM6ytj (button lives in the wizard footer).
- Reference app he likes visually: **Nexus Playbook** (NOT his app) — 5-step wizard with left
  step tracker, requirement cards with Disable buttons, "Select Options" popups. We cloned
  the flow, re-skinned in AkariOS branding (red/black from his wallpaper, not Nexus purple).

## Architecture (all verified by real execution)

```
AkariOS.exe (WinUI3 net10, asInvoker — no UAC at launch)
  │ wizard: License → System Check → Configuration → Optimization → Finished
  │ nav pane = step progress indicator (display-only); footer Back/Next/Finish + Discord
  │
  │ runas (single UAC at engine start)
  ▼
AkariOS.EngineBridge.exe (net472 headless, elevated)
  └─ spawns engine\TrustedUninstaller.CLI.exe "<extracted playbook>" <options...>
     with REDIRECTED pipes, mirrors all output line-by-line to
     %TEMP%\AkariOS-Engine\out.txt  (writes "EXIT <code>" as final line)
  │
AkariOS tails out.txt every 250 ms:
  - progress regex ^\s*(\d+(\.\d+)?)\s*%\s*(.+)$  → bar + status label
  - ignores bare percents (nested robocopy "100%"), never lets the bar regress
```

Why the bridge: unelevated process can't `runas` AND capture stdout simultaneously
(`UseShellExecute=false` kills `Verb=runas`). Bridge is already elevated so it can do both.

Facts proven in Phase 0 (spikes `EngineBridgeProbe`, `LauncherSpike`, then VM runs):
- AME's source repo does NOT build publicly (two Defender .cab resources absent) → consume
  released `CLI-Standalone.zip` 0.8.4 (18 MB extracted) instead.
- net10 CAN load+execute the net472 Shared.dll in-process (useful for unprivileged reads like
  playbook.conf parsing — that's how Configuration/SystemCheck work without elevation).
- Escalation chain works: unelevated launcher → UAC → CLI → TrustedInstaller node → playbook.
- Upstream bug: CLI crashes (`SerializationException` in InterLink.GetParameters) when given
  zero option args. AkariOS always passes explicit option names, so unaffected.

## Playbook

- V6.0.0 source of truth: `Desktop\playbooks\AkariOSV6\AkariOSV6.apbx` (16 MB, 7z password
  `malte`; extracted form next to it). Bundled into builds as
  `src/AkariOS.App/assets/AkariOS-Playbook.apbx` (copied verbatim).
- playbook.conf: Name AkariOS, Title "AkariOS V6", SupportedBuilds 19044–26200,
  Requirements: DefenderToggled, NoAntivirus, Internet, PluggedIn. UseKernelDriver=false,
  Overhaul=true, SupportsISO=true. FeaturePages drive the Configuration popups.
- V6 removed NSudo/PowerRun entirely (AV-friendlier than V5). Remaining AV friction comes
  from the bundled CLI itself, not the playbook.
- Extraction target at runtime: `%LOCALAPPDATA%\AkariOS\playbook\` via bundled 7za.exe
  (`7za.exe`, NOT `7z.exe` — CLI-Standalone ships the standalone build).

## Requirement checks (SystemCheckPage + RequirementsService)

- Evaluated from playbook.conf's `<Requirements>` list; page polls every 2 s while visible
  (user demanded this after one-shot checks forced app restarts).
- **Defender toggles = exact port of AME CLI's GetDefenderToggles** (their CLI.cs:389):
  Real-Time Protection\DisableRealtimeMonitoring == 1; SpyNet SpyNetReporting != 0;
  SubmitSamplesConsent not in {0,2,4}; Features\TamperProtection not in {0,4}.
  Policy keys (`SOFTWARE\Policies\Microsoft\Windows Defender`) first, fallback to
  `SOFTWARE\Microsoft\Windows Defender`. NEVER use MsMpEng process presence — it stays
  running even with protection off (that bug locked Next forever once).
- "Open Windows Security" launches `windowsdefender://protection` UNELEVATED — an earlier
  version used elevated PowerShell and tripped AV.
- UCPD fix: elevated PowerShell `sc stop UCPD; sc config UCPD start= disabled`.
- Gates: license checkbox (step 0), requirementsMet (step 1), ConfiguredAtLeastOnce (step 2),
  RunCompleted exit 0 (step 3). `WizardFlow.StateChanged` event refreshes the footer buttons
  immediately on in-page state changes (sidebar click should never be needed).

## Build & test workflow

- Build: `dotnet build src/AkariOS.App/AkariOS.App.csproj -c Release -p:Platform=x64`
  Output: `src/AkariOS.App/bin/x64/Release/net10.0-windows10.0.26100.0/win-x64/`
  (self-sufficient: exe + engine\ incl. bridge + assets\ incl. playbook).
- csproj copies `third_party/engine-bin/**` → `engine\` (CLI-Standalone 0.8.4, kept locally,
  NOT committed) and bridge publish output → `engine\`. CI fetches the pinned release zip
  before building.
- Tests: `dotnet test src/AkariOS.Tests/...` — 110 passing as of last session.
- ALWAYS launch the app after touching DI/startup/XAML root classes — green build ≠ running app.
- XAML pages deriving from a custom base class need `xmlns:local` + root tag = base class
  (`<local:WizardStepPage ...>`), not `<Page>`.

## Pitfalls learned (full list also in TODO.md)

- Exe icon embeds at link time from stale obj — clean rebuild after icon swap.
- Fractional percentages in engine output; bare nested-tool `100%` lines must be ignored.
- Leftover TrustedInstaller node processes → named-pipe UnauthorizedAccessException next run.
- Read-only attrs propagate from ISO media (files AND dirs) — blocks deletes/servicing.
- Capture DispatcherQueue at startup; background-thread UI mutations crash (COMException).
- DI drift crashes at launch despite green build/tests.
- His C: drive volume LABEL is "AkariOS" — don't confuse with folders.

## Current state (end of last session)

- Phase 2 COMPLETE and VM-verified by user ("okay its working"). All pushed; docs current.
- V6 bundled build delivered for testing (build output folder copied to VM by user).
- Next: first GitHub release (re-tag v0.1.0 — old tag predates CI fixes), AV hardening
  (encrypted-archive engine payload extracted only after System Check passes; file false-
  positive submissions with Microsoft), Phase 3 backlog (USB flasher / ISO download /
  ISOWIM bypasses / custom OOBE absorbed from AME Core MIT code), playbook self-update via
  `<Git>`, decide ISO mode's fate (currently hidden; code kept).

## Where things live (quick reference)

| Thing | Path |
|---|---|
| Wizard shell | `src/AkariOS.App/MainWindow.xaml(.cs)` |
| Step pages | `src/AkariOS.App/Views/{License,SystemCheck,Configuration,Optimization,Finished}Page.*` |
| Flow state/gates | `src/AkariOS.App/Views/WizardState.cs` (class `WizardFlow`) |
| Engine launch + progress parse | `src/AkariOS.App/Services/EngineService.cs` |
| Requirement checks | `src/AkariOS.App/Services/RequirementsService.cs` |
| playbook.conf parser | `src/AkariOS.App/Services/PlaybookManifest.cs` |
| Elevated bridge | `src/AkariOS.EngineBridge/Program.cs` |
| Engine binaries (local) | `third_party/engine-bin/` |
| Branding | `App.xaml` (red accent), `Themes/AkariTheme.xaml`, `Assets/AppIcon.*`, `Assets/Wallpaper.png` |
| Legacy ISO pipeline (hidden) | `src/AkariOS.Core/*`, `Views/BuilderPage.*` |
| AME upstream clone | `C:\Users\isleap\Documents\GitHub\trusted-uninstaller-cli` |
