# AkariOS Roadmap

Living document — update this file as items land. Checked = shipped.

> **Direction change (Aug 2026):** AkariOS is becoming a focused front-end for the
> **AME Wizard Core** engine (MIT, Ameliorated LLC), shipping **only the AkariOS playbook**.
> Two modes from one engine call: **Build ISO** and **Apply now**.
> The detailed, phased plan lives in [TODO.md](TODO.md) — read that first.
> Session-by-session history is in [LOG.md](LOG.md).

## ✅ Done

- [x] WinUI 3 shell (AME Beta–style layout: navbar pane as ISO drop zone, single main page)
- [x] Drag-and-drop ISO intake with per-ISO progress items
- [x] ISO mount + staging pipeline (`AkariOS.Core`)
- [x] `$OEM$` payload injection (`sources\$OEM$\$$\Setup\Scripts\` + `SetupComplete.cmd` hook)
- [x] Bootable ISO rebuild with bundled `oscdimg.exe`
- [x] WinSux.ps1 vendored and injected automatically post-install
- [x] App icon (title bar + executable)
- [x] VM-tested end-to-end install
- [x] Runs **without administrator** (`asInvoker`) — verified end-to-end by `tools/ElevationProbe`;
      this is what restored drag-and-drop (Windows UIPI blocks drops into elevated windows)
- [x] Build cancellation — kills robocopy/oscdimg, deletes partial output
- [x] Build log viewer in-app (collapsible mono pane per ISO item; streams tool output)
- [x] Direct WIM servicing via ManagedWimLib — payload baked into `install.wim`; ESD skipped
- [x] Edition/index selection UI — editions scanned at intake, per-edition checkboxes
- [x] Release builds + GitHub Releases CI (`.github/workflows/release.yml`, tag `v*`)

## 🚧 In Progress

- [ ] **Phase 0: IPC bridge spike** — prove a net10 client can drive the engine's
      `RunPlaybook` in a net472 TrustedInstaller host and receive progress.
      Blocks everything below. See [TODO.md](TODO.md).

## 📋 Backlog

### Engine integration (the new core work)
- [ ] `AkariOS.Engine.exe` — net472 TrustedInstaller host wrapping `AmeliorationUtil.RunPlaybook`
- [ ] `AkariOS.apbx` playbook authored from the WinSux tweaks, shipped pre-extracted
- [ ] Mode switch in UI: **Build ISO** vs **Apply now**
- [ ] Requirement pre-flight in our UI (internet / Defender / UCPD) — the CLI blocks on
      `Console.ReadKey()` for these and would hang with no console attached
- [ ] Playbook options UI (checkbox / radio feature pages)

### Absorb from AME Core (MIT — prefer theirs over reinventing)
- [ ] Hardware-requirement bypass (TPM / CPU / RAM / BitLocker) via `USB/ISOWIM.cs`
- [ ] USB flasher — write finished ISO to a bootable drive (`USB/USB.cs`)
- [ ] In-app Windows ISO download + SHA256 verify (`USB/OSDownload.cs`)
- [ ] Custom OOBE (username, autologon, internet policy) via `OOBE.cs`

### Reconcile
- [ ] Decide whether `AkariOS.Core` (our staging/WIM/oscdimg path) stays as a fallback or is
      retired in favour of the engine's ISO path — **never run both injection mechanisms at once**
      (ours = `$OEM$` + RunOnce, theirs = unattend + OOBE; both would double-run the playbook)

### UX (still ours regardless of engine)
- [ ] Per-ISO tweak selection UI (choose which parts of the playbook to apply)
- [ ] Custom payload support — bring your own scripts alongside the AkariOS playbook

## ❌ Dropped

- ~~Admin self-relaunch (runtime `runas`)~~ — removed. Elevation at launch broke drag-and-drop
  and was never needed for ISO building; elevation is now per-action (engine process only).
