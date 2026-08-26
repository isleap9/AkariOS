# AkariOS — TODO (current working plan)

_Sync with [ROADMAP.md](ROADMAP.md) (shipped state) and [LOG.md](LOG.md) (session history).
HERMES.md holds the assistant's cross-session memory of this project._

## Direction (decided Aug 2026)

AkariOS is a **focused front-end for the AME Wizard Core engine** (`TrustedUninstaller.CLI`,
MIT, consumed as released 0.8.4 binaries) that ships **only the AkariOS playbook**
(V5 → now **V6.0.0**). One download, one button: apply the playbook to the running system.
The ISO-builder pipeline stays in the codebase but is NOT exposed in the UI.

Hard constraints:
- App stays `asInvoker` at launch; UAC appears only when the engine runs.
- Engine runs happen **only in the user's VM, started by the user** — never on the host.
- Consume their engine unmodified; no forking.

## Proven architecture (Phase 0–2 complete)

```
AkariOS.exe (WinUI3 net10, asInvoker)
   → wizard collects license/options
   → runas → AkariOS.EngineBridge.exe (net472 headless, elevated)
       → spawns TrustedUninstaller.CLI.exe with REDIRECTED pipes
       → mirrors output to %TEMP%\AkariOS-Engine\out.txt
   → UI tails out.txt → progress bar + status + log (console stays visible for debugging)
```

Why the bridge: an unelevated process cannot both `runas` AND capture stdout
(`UseShellExecute=false` disables `Verb=runas`). The bridge is already elevated, so it can do both.

## Phase status

- [x] **Phase 0 — engine spike:** source repo doesn't build (missing Defender .cabs) → consume
      released binaries; escalation + full playbook verified in VM. Upstream bug found: CLI
      crashes on empty options list (`SerializationException`, InterLink.GetParameters) — we
      always pass explicit options so unaffected.
- [x] **Phase 1 — playbook:** V6.0.0 exists (`Desktop\playbooks\AkariOSV6\AkariOSV6.apbx`),
      AME-native, SupportsISO, no NSudo/PowerRun anymore (AV-friendlier than V5).
- [x] **Phase 2 — wizard UI (VM-verified):**
      - Nav pane = 5 step pages, display-only; footer Back/Next/Finish + Discord.
      - License gate (checkbox), System Check (real requirement cards), Configuration
        (FeaturePages popups from playbook.conf), Optimization (live progress), Finished (+restart).
      - Requirements evaluated in-app from playbook.conf; page polls every 2 s while open so
        fixes unlock Next live. Defender logic = port of AME's `GetDefenderToggles`
        (Real-Time Protection / SpyNet reporting+consent / TamperProtection; policy key first).
      - Branding: AkariOS title, new logo, wallpaper banner, red accent (#ff1a1a).

## Next up

- [ ] First release: re-tag `v0.1.0`; verify release zip carries `engine\` + playbook.
- [ ] AV hardening: ship engine packed in encrypted 7z, extract only AFTER System Check passes
      (Defender toggles off). File false-positive submissions for CLI binaries.
- [ ] Phase 3 backlog (absorb from AME Core, MIT): USB flasher, ISO download, ISOWIM bypasses,
      custom OOBE.
- [ ] Playbook self-update via `<Git>` URL check.
- [ ] Decide ISO mode's future: hidden "advanced" entry point vs. delete later (code kept for now).

## Pitfalls (learned the hard way — do not rediscover)

- **DI drift crashes at launch** — register every new service; `ServiceRegistrationTests`
  guards it; still launch the app after startup-path changes.
- **Defender toggles:** MsMpEng keeps RUNNING when protection is off — never use process
  presence as a signal; read the registry values (AME's exact logic).
- **Progress lines are fractional** (`44.4502344…%`) and nested tools emit bare `100%` —
  parse decimals, ignore label-less percents, never regress the bar.
- **One-shot checks annoy users** — poll requirements every 2 s while System Check is visible.
- **Leftover TrustedInstaller nodes** from an unclean run cause named-pipe access-denied next
  run — reboot/kill before re-testing.
- **Read-only attrs off ISO media** block deletes/servicing — clear files AND directories.
- **UI thread:** capture DispatcherQueue at startup; never `GetForCurrentThread()` off-thread.
- **Exe icon embeds at link time** from a stale obj cache — clean rebuild after icon swaps.
- **Never run the playbook/engine on the host. VM only, user-started.**
