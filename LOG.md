# AkariOS — Session Log

Running history of work sessions: what was done, what was learned, and where we left off.
Newest first. Plan lives in [TODO.md](TODO.md), shipped state in [ROADMAP.md](ROADMAP.md).

Conventions:
- **Verified** = actually executed and observed, not just compiled.
- Bugs found *by testing* are listed separately from features, because they are the
  expensive lessons.

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
