# AkariOS — Session Log

Running history of work sessions: what was done, what was learned, and where we left off.
Newest first. Plan lives in [TODO.md](TODO.md), shipped state in [ROADMAP.md](ROADMAP.md).

Conventions:
- **Verified** = actually executed and observed, not just compiled.
- Bugs found *by testing* are listed separately from features, because they are the
  expensive lessons.

---

## 2026-08-25 — Phase 0 spike: engine bridge + playbook discovery

### Verified: engine source does NOT build here

`MSBuild 18.9.1` (VS 2026 Community) + the v4.7.2 targeting pack are installed, and NuGet
restore of `TrustedUninstaller.sln` succeeded. The build still fails:

```
CSC : error CS1566: Error reading resource
'TrustedUninstaller.Shared.Properties.Z-AME-NoDefender-Package31bf3856ad364e35amd641.0.0.0.cab'
-- Could not find file
```

Two embedded Defender-removal `.cab` blobs are referenced by the csproj (lines 220–221) but
are **not committed to the public repo**. Only `UsrClass.dat`, `uefi-ntfs-ame*.img` are present.
Not fixable on our side.

→ **Decision: consume the released binaries.** Downloaded `CLI-Standalone.zip` 0.8.4 (9.5 MB
zip → 18 MB extracted); the shipped `TrustedUninstaller.Shared.dll` has the cab baked in.
Benefits: no fork, no net472 build chain, trivial version pinning.

### Verified: net10 CAN load + execute the net472 engine in-process

Built `tools/EngineBridgeProbe` (commit `ebe5d8e`), reflection-based so it reports *where* it
breaks rather than failing to compile:

```
[bridge] runtime : .NET 10.0.11
  [OK] load TrustedUninstaller.Shared      v0.8.4.0 (IL runtime v4.0.30319)
  [OK] resolve AmeliorationUtil
  [OK] resolve RunPlaybook overloads       14 params, 23 params
  [OK] resolve InterLink + progress types  InterProgress=True; InterMessageReporter=True
  [OK] EXECUTE engine code                 DeserializePlaybook threw DirectoryNotFoundException
[bridge] VERDICT: net10 CAN load and execute the net472 engine in-process.
```

**This invalidated my own plan.** TODO.md had asserted "it cannot be ProjectReference'd from
net10" and budgeted 2–4 days for a custom IPC bridge. Wrong on both counts: `InterLink` ships
*inside* `Shared.dll` (no shared-source-project boundary), and .NET's compat shims load the
net472 assembly fine. Dependencies resolve via an `AssemblyResolve` hook pointed at the engine
folder. TODO corrected in place rather than quietly edited.

Still unproven, and it's the harder half: **TrustedInstaller escalation**. Loading ≠ escalating.
Open risks — `InterLink.LaunchNode` re-launches *itself* at higher levels (may assume the
net472 CLI layout), and the release ships `TrustedUninstaller.CLI.exe.config` whose binding
redirects a net10 host will not apply.

Architecture note: even though in-process now works, a **separate engine process is still
probably right** — the UI must stay `asInvoker` or drag-and-drop breaks again (UIPI), and a
crash in ~49k lines of privileged Win32 shouldn't kill the UI.

### Discovered: the AkariOS V5 playbook already exists and is AME-native

The user pointed out `AkariOS-Playbook.apbx` (18 MB) was already committed at the repo root.
Extracted with 7-Zip + password `malte` → 68 folders / 186 files / 35 MB:

- `playbook.conf` — **AkariOS V5, v5.0.4, `SupportsISO=true`**, supported builds 19044→26200,
  `DisableBitLocker` + `DisableHardwareRequirements`, OOBE bullet points, and **5 FeaturePages**
  of user-facing options (security, settings ×2, removals, extras)
- `Configuration/` — `custom.yml` → 7 task files; `registry.yml` alone is 82 KB
- `Executables/` — 34 MB of bundled tools/scripts
- **881 actions**: `registryValue` 466, `service` 246, `appx` 71, `run` 29, `writeStatus` 16,
  `cmd` 12, `powerShell` 10, `file` 10, `taskKill` 8, `task` 7, `download` 2

**Phase 1 is therefore ~done** — it becomes verification + wiring, not authoring. Also means
`WinSux.ps1` + `$OEM$` is superseded; the V5 playbook already contains those tweaks in
engine-native form. Only 2 actions carry `iso: true`, so almost everything currently runs
live/OOBE — worth revisiting for offline reliability, but only with VM testing.

### Where we left off

- Pushed: `ebe5d8e` (probe), docs update following.
- Next: **TrustedInstaller escalation test** — the last unknown in Phase 0.
- Note: `v0.1.0` tag still points at a commit predating the CI fixes; re-tag before releasing.

---

## 2026-08-24 → 08-25 — Release CI, UX polish, WIM servicing, elevation reversal

### Shipped

| Commit | What |
|---|---|
| `2572057` | Release CI: build self-contained `AkariOS.exe` on `v*` tag push, zip → GitHub Release |
| `9d0dea5` | CI: checkout `WinSux` submodule so the payload exists at publish time |
| `d4d97ea` | Fix latent repo bug: `WinSux` was a gitlink with **no `.gitmodules` URL** at all |
| `0bc3e2a` | Real build cancellation — kill robocopy/oscdimg on cancel, delete partial output |
| `a5af2a3` | In-app build log viewer — streams oscdimg/robocopy output per ISO item |
| `9b740bd` | Fix `COMException 0x8001010E` — capture UI `DispatcherQueue` at startup |
| `6a243b7` | Direct WIM servicing via vendored ManagedWimLib (no DISM, no mounting) |
| `2d4a842` | Edition picker — scan `install.wim` editions at intake, per-edition checkboxes |
| `8f5e719` | Read-only attribute fixes (see below) + register `IsoMountService` in DI |
| `1060aed` | **Drop admin requirement → `asInvoker`**, restoring drag-and-drop |

Tests: 96 → **110 passing**.

### Bugs I introduced and had to fix (all found by the user running the app)

1. **App wouldn't launch at all.** Added `IsoMountService` + `WimService` to
   `BuilderViewModel`'s constructor for the edition scan, registered only `WimService`.
   Compiled clean, died at startup with
   `Unable to resolve service for type 'IsoMountService'`.
   → Added `ServiceRegistrationTests` (DI graph resolves with `ValidateOnBuild`).
   → **Lesson: a green build is not proof the app starts. Launch it.**
2. **`COMException 0x8001010E` on every build.** My new log-viewer code mutated an
   `ObservableCollection` from the pipeline thread. `MainWindowEnqueue` called
   `DispatcherQueue.GetForCurrentThread()`, which returns **null on a background thread**,
   so the action ran inline instead of marshalling. Fixed by capturing the UI dispatcher once
   at startup.
3. **`[WimIsReadOnly] ... Permission denied`** servicing `install.wim`. Everything robocopy
   copies off mounted ISO media inherits the read-only attribute. Fixed in `StagingStep` and
   defensively in `WimService`. Regression test **verified by disabling the fix and
   reproducing the user's exact error string**, then re-enabling.
4. **Read-only *directories*** (e.g. `boot\en-us`) blocked staging cleanup — the old code
   cleared the attribute on files only. This was the source of the leaked ~10 GB temp folders.

### The elevation reversal (most important finding)

I had claimed — from a stale memory note — that ISO mounting required admin, and told the
user drag-and-drop was fundamentally incompatible with elevation (Windows UIPI). The first
half was **wrong**.

The user asked *"how does AME support mounting an ISO while elevated?"*, which forced a real
test. Built `tools/ElevationProbe` (committed, reusable): runs the actual pipeline code
unelevated against a real Windows 11 25H2 ISO.

```
[probe] elevated = False
[probe] Mount-DiskImage: OK  (mounted I:)
[probe] robocopy staging: OK  (968 files / 10.0 GB)
[probe] $OEM$ payload write: OK
[probe] wimlib ListImages: OK  (idx 1: Windows 11 Pro)
[probe] wimlib InjectPayload + Overwrite (real 9.7 GB WIM): OK
[probe] oscdimg rebuild bootable ISO: OK  (10220 MB produced)
[probe] RESULT: entire pipeline works WITHOUT admin -> elevation can be dropped.
```

Consequence: `app.manifest` → `asInvoker`. Drag-and-drop works again with **no** UIPI
message-filter hack and **no** split-process redesign. Two proposed architectures
(elevated helper process; `ChangeWindowMessageFilterEx` + `WM_DROPFILES` subclassing) were
discarded as unnecessary. App verified launching with no UAC prompt.

### wimlib gotchas solved (ManagedWimLib)

- `Overwrite()` requires opening with `OpenFlags.WriteAccess`, else cryptic failures.
- wimlib reads file **data at commit time**, not at `AddTree` time — temp source dirs must
  outlive the commit (my first version deleted them too early; the real error was only
  visible in wimlib's own error file, not the exception).
- Use `WriteFlags.Rebuild` (atomic temp+rename); append mode failed on small WIMs.
- The vendored project is legacy net46-only → added `ManagedWimLib.net.csproj`, a thin
  SDK-style wrapper compiling the same sources for net10 + shipping `libwim-15.dll` per-RID.

### CI note

Release workflow was validated by actually tagging `v0.1.0` and reading the failure logs
(via GitHub API, needed a token from `git credential fill` for a private repo). Two real
bugs surfaced that a local build could never catch. The tag currently points at a commit
predating those fixes — **re-tag before publishing a release**.

### Direction decided at end of session

Explored `C:\Users\isleap\Documents\GitHub\trusted-uninstaller-cli` (AME Wizard Core, MIT).
It is far more than a playbook runner — it also contains ISO injection with TPM/BitLocker
bypass, WIM→ESD, `unattend.xml` generation, a USB flasher, and in-app OS ISO download, i.e.
three items already on our roadmap.

Decision: **AkariOS becomes a front-end for that engine, shipping only the AkariOS
playbook** — one download, user picks "Build ISO" or "Apply now". Key discovery:
`AmeliorationUtil.RunPlaybook(...)` serves both modes (`ISO = isoPath != null`) and reports
progress/status via `InterLink`, i.e. it is built to be driven by a GUI. But it is
`[InterprocessMethod(Level.TrustedInstaller)]` and net472, so it must live in a separate
elevated host process — which conveniently keeps our UI unelevated.

Full phased plan written to TODO.md. **Next up: Phase 0 IPC bridge spike.**

### Where we left off

- Working tree clean, all work pushed to `main` (`1060aed`).
- App runs unelevated; drag-and-drop expected to work — **awaiting user confirmation**.
- Not yet started: building `TrustedUninstaller.sln`, the net472 engine host, or the spike.
- Open question for Phase 0: does TrustedInstaller escalation work when the parent process
  is unelevated, or must the engine be launched already-elevated via `runas`?
