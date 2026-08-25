# AkariOS — TODO

_Working plan. Sync with [ROADMAP.md](ROADMAP.md) as items land._

## Direction (decided Aug 2026)

AkariOS becomes a **focused front-end for the AME Wizard Core engine**
(`C:\Users\isleap\Documents\GitHub\trusted-uninstaller-cli`, MIT / Ameliorated LLC),
shipping **only the AkariOS playbook** — no playbook browser, no third-party playbooks,
no "download AME Wizard then download our playbook" dance. One app, one download.

Two user-facing modes, one engine call:

| Mode | What it does | Engine |
|---|---|---|
| **Build ISO** | inject AkariOS playbook into a Windows ISO | `RunPlaybook(..., isoPath: <iso>)` |
| **Apply now** | debloat the running system | `RunPlaybook(..., isoPath: null)` |

`AmeliorationUtil.RunPlaybook(...)` is the single entry point for both
(`ISO = isoPath != null`, AmeliorationUtil.cs:532) and it already reports progress +
status text via `InterLink.InterProgress` / `InterMessageReporter` — i.e. designed to be
driven by a GUI.

## Hard constraints (verified, not assumed)

1. **`RunPlaybook` is `[InterprocessMethod(Level.TrustedInstaller)]`** (AmeliorationUtil.cs:520).
   It MUST run in a TrustedInstaller-level process. Not optional — that privilege is how the
   engine removes protected components. So the engine cannot live in our WinUI process.
2. **Engine is .NET Framework 4.7.2** and pulls WPF (`PresentationFramework`, `WindowsBase`),
   WinForms, COM (`WUApiLib`, `IWshRuntimeLibrary`), `YamlDotNet`, `DiscUtils.Udf`,
   `Microsoft.Wim`, `SharpSevenZip`.
   ~~It cannot be ProjectReference'd from net10.~~ **Corrected (Phase 0):** a net10 process
   *can* load and execute `TrustedUninstaller.Shared.dll` directly — verified. What is still
   true: it can't be built from source here (missing Defender `.cab` blobs), so we reference
   the **released binaries** and resolve their dependencies with an `AssemblyResolve` hook.
3. **AkariOS.App must stay `asInvoker`.** Windows UIPI blocks drag-and-drop from Explorer into
   an elevated window — that is what silently broke the ISO drop zone. Verified by
   `tools/ElevationProbe`: the whole current pipeline (mount, robocopy, `$OEM$`, wimlib
   servicing of a real 9.7 GB install.wim, oscdimg rebuild → 10220 MB ISO) works with
   **no admin at all**. Elevation must therefore be per-action, never at launch.

## Target architecture

```
AkariOS.exe            WinUI 3, net10, asInvoker      ← UI, no UAC at launch, DnD works
    │
    │  InterLink named pipe (their IPC, already built)
    ▼
AkariOS.Engine.exe     net472, requireAdministrator → elevates to TrustedInstaller
    └── AmeliorationUtil.RunPlaybook(...)             ← their engine, consumed unmodified
```

- UAC appears only when the user presses Run/Build — not on launch.
- We **consume** the engine, we do not fork it. No patches to their source; keep their repo
  as an upstream we can pull from (`v0.8.4` at time of writing).
- `Interprocess/` is a **shared source project** (`.shproj` + `.projitems`, compiles into each
  consumer) rather than a DLL — so the same `.cs` files may be includable in a net10 project.
  That is the crux of Phase 0.

---

## Phase 0 — IPC bridge spike ⭐ IN PROGRESS

**Goal:** prove a net10 client can drive `RunPlaybook` and receive progress. Everything after
this is straightforward UI work; if this fails the whole architecture changes, so nothing else
starts until it's answered.

### Answered ✅

- [x] **Engine source does NOT build here.** `TrustedUninstaller.Shared` references two
      embedded Defender resources that are **absent from the public repo**:
      `CSC : error CS1566: Error reading resource '...Z-AME-NoDefender-Package...amd64...cab'`.
      Not fixable on our side.
      → **Decision: consume the released binaries** (`CLI-Standalone.zip` 0.8.4, 18 MB
      extracted), not a source build. No fork, no net472 build toolchain, easy version pinning.
      (MSBuild 18.9.1 + the v4.7.2 targeting pack ARE installed; restore succeeded — the
      failure is purely the missing binary blobs.)
- [x] **net10 CAN load and execute the net472 engine in-process** — verified by
      `tools/EngineBridgeProbe` (commit `ebe5d8e`):
      - `TrustedUninstaller.Shared` v0.8.4 (IL v4.0.30319) loads under .NET 10.0.11
      - `AmeliorationUtil` resolves; both `RunPlaybook` overloads present (14 + 23 params)
      - `Interprocess.InterLink` + `InterProgress` + `InterMessageReporter` all resolve
      - engine code actually **runs** (`DeserializePlaybook` threw a normal
        `DirectoryNotFoundException`)
      → This **invalidates the original assumption** that a net472 host + custom IPC bridge was
      mandatory. `InterLink` ships *inside* `Shared.dll`, so there is no shared-source-project
      boundary to solve. Dependencies resolve from the engine folder via an `AssemblyResolve` hook.

### Still open — the harder half

Loading the assembly is NOT the same as escalating and running a playbook.

- [ ] **Escalation test (VM, user-run):** does the CLI reach `Level.TrustedInstaller` when
      launched via `runas` from an unelevated net10 process? Procedure in LOG.md.
      Tool ready: `tools/LauncherSpike`. **Never run against the host machine.**
- [ ] **Binding redirects:** the release ships `TrustedUninstaller.CLI.exe.config`; a net10 host
      does not apply app.config binding redirects. Watch for assembly-version conflicts
      (`System.Text.Json`, `System.Memory`, `Newtonsoft.Json`).
- [ ] **Verification:** run a trivial 2–3 action playbook end-to-end, progress + status arriving
      in the net10 process, engine exits cleanly, no orphaned elevated process.

### Architecture decision (revisit after the escalation test)

In-process now looks technically possible, but **a separate engine process is still probably
right**, for reasons independent of framework compatibility:

1. The UI must stay `asInvoker` so drag-and-drop keeps working (UIPI). If the engine ran
   in-process at TrustedInstaller level, the whole UI would be elevated → DnD breaks again.
2. A crash inside ~49k lines of privileged Win32 code should not take the UI down.
3. UAC then appears only when the user presses Run/Build.

So: prefer `AkariOS.Engine.exe` (its own process, elevates itself), with the UI talking to it.
In-process loading remains a useful fallback for cheap, unprivileged calls
(playbook parsing, option enumeration, requirement checks) where no elevation is needed.

- [ ] Decide: engine process launched via `runas` on demand vs. `InterLink`-managed nodes
- [ ] `AkariOS.Engine.exe` — net472 or net10 host wrapping `RunPlaybook`

## Phase 1 — AkariOS playbook ✅ ALREADY EXISTS

**`AkariOS-Playbook.apbx` (18 MB, repo root) is the AkariOS V5 playbook and it is already a
complete, AME-compatible playbook.** This phase is therefore mostly *verification + wiring*,
not authoring. Upstream: <https://github.com/isleap9/AkariOS-Playbook>

Verified contents (extract with 7-Zip, password `malte` → 68 folders / 186 files / 35 MB):

```
playbook.conf     AkariOS V5 · v5.0.4 · SupportsISO=true
                  SupportedBuilds: 19044 19045 22621 22631 26100 26200
                  Requirements: DefenderToggled, NoAntivirus, Internet, PluggedIn
                  ISO: DisableBitLocker=true, DisableHardwareRequirements=true
                  OOBE bullet points present
                  5 FeaturePages (security, settings 1/2 + 2/2, removals, extras)
Configuration/    custom.yml → 7 task files
                  registry.yml (82 KB), services.yml (22 KB), appx.yml, components.yml,
                  commands.yml, ScheduledTasks.yml, FinalTasks.yml
Executables/      34 MB of bundled scripts/tools (AkariOS.pow, DevManView, Edge/Copilot
                  removal, Defender scripts, service batches, PostInstall, …)
playbook.png
```

Action mix (881 actions total): `registryValue` 466, `service` 246, `appx` 71, `run` 29,
`writeStatus` 16, `cmd` 12, `powerShell` 10, `file` 10, `taskKill` 8, `task` 7, `download` 2.
Only 2 actions currently carry `iso: true` (commands.yml:70,75).

### Remaining work

- [ ] Decide how the playbook ships: keep the `.apbx` and decrypt at runtime (engine already
      does this, password `malte`), or ship **pre-extracted** to skip decryption entirely.
      Pre-extracted is simpler but exposes the tweaks as loose files.
- [ ] Wire "one download, self-updating": `<Git>` already points at the playbook repo, so we can
      check for playbook updates independently of app updates.
- [ ] Map the 5 `FeaturePages` → our options UI (checkbox pages with defaults, `IsRequired`).
- [ ] **Review `iso:` / `oobe:` coverage.** With only 2 `iso: true` actions, nearly everything
      runs live/OOBE today. Offline injection is more reliable for service/package removal, so
      revisit once ISO mode works — but do NOT bulk-flip flags without VM testing.
- [ ] `Requirements` incl. `Internet` + `NoAntivirus` + `PluggedIn` must be pre-flighted in OUR
      UI (see Phase 2) — the CLI blocks on `Console.ReadKey()` for these.
- [ ] **Verification:** run this exact playbook via their CLI in a VM before any AkariOS wiring.

### Consequence for the project

The old `WinSux/WinSux.ps1` + `$OEM$` mechanism is superseded by this playbook. Do not port
WinSux tweaks into a new playbook — V5 already contains them in engine-native form.

## Phase 2 — UI rework

- [ ] Mode switch: **Build ISO** / **Apply now**
- [ ] Feature/options pages driven by the playbook's option list (checkbox/radio pages)
- [ ] Requirement pre-flight in OUR UI (internet, Defender, UCPD) — the CLI calls
      `Console.ReadKey()` on those paths (CLI.cs:112,123) and would **hang with no console**
- [ ] Bind engine progress/status to the existing per-item progress + build log viewer
- [ ] Keep drag-and-drop intake and the edition picker

## Phase 3 — Absorb what they already solve

Their repo has MIT-licensed pieces that are on our roadmap; prefer theirs over writing ours:

- [ ] `USB/ISOWIM.cs` — TPM / CPU / RAM / BitLocker bypass, WIM→ESD, `unattend.xml` generation
- [ ] `USB/USB.cs` — USB flasher (device enumeration, eject) → kills the "USB flasher" backlog item
- [ ] `USB/OSDownload.cs` — in-app Windows ISO download + SHA256 verify
- [ ] `USB/ISO.cs` — DiscUtils-based ISO read/extract (no Mount-DiskImage needed)

## Phase 4 — Reconcile our pipeline

Once their ISO path is proven, most of `AkariOS.Core` is superseded:

- [ ] Decide: keep `AkariOS.Core` (WimServiceStep / OscdimgService / staging) as a fallback,
      or delete it in favour of their ISO path
- [ ] **Do not mix injection mechanisms.** Ours uses `$OEM$` + RunOnce; theirs uses
      unattend + custom OOBE. Both at once risks double-running the playbook.
- [ ] Keep `tools/ElevationProbe` either way — it is how we verify privilege claims

---

## Pitfalls (learned the hard way — do not rediscover)

- **DI drift crashes the app at launch.** Adding a ctor param to a ViewModel without
  registering the service compiles fine and dies at runtime. `ServiceRegistrationTests`
  guards the Core graph; a green build is NOT proof the app starts.
- **Always launch the app after changing startup/DI/manifest.** Tests passing ≠ app running.
- **Read-only attribute:** everything robocopied off mounted ISO media is read-only —
  files *and* directories (e.g. `boot\en-us`). Read-only dirs block recursive delete;
  read-only `install.wim` makes wimlib fail `[WimIsReadOnly] Permission denied`.
- **wimlib:** `Overwrite()` needs `OpenFlags.WriteAccess`; file DATA is read at commit time
  (temp sources must outlive the commit); use `WriteFlags.Rebuild`.
- **UI thread:** capture the `DispatcherQueue` at startup. `GetForCurrentThread()` returns
  null on background threads, so callbacks ran inline and mutating an `ObservableCollection`
  threw `COMException 0x8001010E`.
- **`Mount-DiskImage` returns a bare letter** (`H`), not `H:`; wimlib needs `H:\`.
- **oscdimg** won't overwrite an existing output file.
- Elevation is NOT required to build ISOs. Don't reintroduce `requireAdministrator`.

## Done recently

- [x] Drop admin requirement → `asInvoker`; drag-and-drop restored (`1060aed`)
- [x] `tools/ElevationProbe` — proves the pipeline needs no admin, against a real 25H2 ISO
- [x] Read-only fixes: staged files + directories, and `install.wim` before servicing (`8f5e719`)
- [x] Register `IsoMountService` in DI + `ServiceRegistrationTests` guard
- [x] Edition picker — scan `install.wim` editions at intake, per-edition checkboxes (`2d4a842`)
- [x] Direct WIM servicing via vendored ManagedWimLib (`6a243b7`)
- [x] In-app build log viewer, streaming oscdimg/robocopy output (`a5af2a3`)
- [x] Real build cancellation — kills robocopy/oscdimg, deletes partial output (`0bc3e2a`)
- [x] Release CI on tag push + GitHub Release (`.github/workflows/release.yml`)
- [x] Fixed latent repo bug: `WinSux` submodule had no `.gitmodules` URL
