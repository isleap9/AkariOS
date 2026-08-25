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
   `Microsoft.Wim`, `SharpSevenZip`. It cannot be ProjectReference'd from net10.
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

**Goal:** prove a net10 client can drive `RunPlaybook` in a net472 TrustedInstaller host and
receive progress. Everything after this is straightforward UI work; if this fails the whole
architecture changes, so nothing else starts until it's answered.

- [ ] Build `TrustedUninstaller.sln` (Release) — confirm the engine compiles here at all
- [ ] Determine how `Interprocess` crosses the framework boundary. In order of preference:
      1. include the shared `Interprocess/*.cs` in a net10 project (needs
         `System.IO.Pipes.AccessControl` for `PipeSecurity` on modern .NET)
      2. thin net472 host that owns InterLink, plus our own minimal pipe/stdout protocol
      3. reimplement the pipe contract on our side (last resort)
- [ ] Minimal `AkariOS.Engine.exe`: wraps `RunPlaybook`, `requireAdministrator`
- [ ] Console-only net10 client: launch engine, call a trivial playbook, print progress
- [ ] **Verification:** progress values + status strings arrive in the net10 process, engine
      exits cleanly, no orphaned elevated process

**Open question to answer here:** does the TrustedInstaller escalation work when the parent is
an unelevated net10 app, or does the engine need to be launched already-elevated (`runas`)?

## Phase 1 — AkariOS playbook

- [ ] Author `AkariOS.apbx` from the WinSux tweaks using their action types
      (`!registryValue`, `!service`, `!appx`, `!cmd`, `!powershell`, `!scheduledTask`, …)
- [ ] Ship it **pre-extracted** (`Configuration/` + `playbook.conf`) so we skip the 7z /
      password-`malte` decryption path entirely
- [ ] `playbook.conf`: `SupportsISO`, `OOBE` bullet points, optional
      `ISO/DisableBitLocker` + `DisableHardwareRequirements`
- [ ] Use `iso:` / `oobe:` per-action flags to split offline-vs-live work
      (offline is more reliable for service/package removal; scripts are OOBE-only)
- [ ] **Verification:** run in a VM via their CLI first, before any AkariOS wiring

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
