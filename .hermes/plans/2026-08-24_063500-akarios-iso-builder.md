# AkariOS Builder — ISO Injection of WinSux.ps1 (WinUI 3)

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** A WinUI 3 app where the user picks a downloaded Windows ISO; the app mounts it, injects `WinSux.ps1` (plus a trigger) into the image, produces a new bootable ISO. The user installs Windows normally; on first boot the fully-working OS runs WinSux.ps1 which applies all debloat/gaming tweaks.

**Architecture:** No offline playbook execution at all. Pipeline = mount ISO → copy its tree to a staging folder → add injection payload (`WinSux.ps1`, bootstrap files) → wire a first-boot hook → repack `install.wim` if injecting inside the image, or leave payload on the ISO media for setup-time pickup → rebuild bootable ISO with oscdimg.

**Tech Stack:** .NET 8, WinUI 3 (AppTemplate MVVM framework), PowerShell invocation via `System.Management.Automation` or `Mount-DiskImage` P/Invoke/PowerShell CLI, ManagedWimLib (already vendored in trusted-uninstaller-cli) or DISM API for WIM edit, ADK `oscdimg.exe` for ISO rebuild.

---

## 1. How the injection actually works (design decision)

Two viable trigger mechanisms; recommended is **both**, with fallback:

### Option A — `C:\Windows\Setup\Scripts\SetupComplete.cmd` inside install.wim  ✅ primary
- Extract/edit `install.wim`: mount the WIM (DISM) or extract just the path addition.
- Add `WinSux.ps1` + `SetupComplete.cmd` containing:
  ```cmd
  @echo off
  powershell -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\WinSux.ps1"
  ```
- SetupComplete.cmd is natively run by Windows Setup as SYSTEM after installation completes, before first logon. Perfect fit: "install windows normally" → tweaks apply automatically.
- Caveat: SetupComplete.cmd does NOT run if a product key/unattend skips OOBE in certain ways — but for standard manual installs it always runs. Also only exists per-image, must be added to every edition index in the WIM (or the one the user selects).

### Option B — `$OEM$` folders on the ISO media (no WIM editing!)  ✅ simplest v1
- Place files under `\sources\$OEM$\$$\Setup\Scripts\` on the ISO tree.
- During installation, Windows copies `$OEM$\$$` into `C:\Windows`, so `SetupComplete.cmd` + `WinSux.ps1` land exactly where they need to be — **without touching install.wim at all**.
- Requires an `autounattend.xml`? No — $OEM$ copying works with normal manual installs too (it's part of standard deployment behavior when sources are present).
- This means the whole pipeline can be pure file-copy on the mounted/staged ISO tree + oscdimg. Fastest to build, least fragile.

**Decision: implement Option B as v1 core pipeline; keep Option A (WIM injection via DISM) as a Phase 2 enhancement/fallback** for cases where $OEM$ handling misbehaves.

### Option C — autounattend.xml with FirstLogonCommands / RunSynchronous
Alternative/complement: ship an `autounattend.xml` on the ISO root that registers a FirstLogonCommand invoking WinSux.ps1 in user context. Useful because some tweaks want a real user session rather than SYSTEM (SetupComplete runs as SYSTEM). Can combine: SetupComplete for system-level, FirstLogonCommand for user-level. Phase 2.

## 2. Proposed solution layout (repo: AkariOS)

```
AkariOS/
├─ AkariOS.sln
├─ assets/
│  ├─ WinSux.ps1                    (user's tweak script — synced/copied from its repo)
│  ├─ SetupComplete.cmd
│  ├─ autounattend.xml              (phase 2)
│  └─ oscdimg.exe                   (bundled or auto-downloaded)
├─ src/
│  ├─ AkariOS.App/                  WinUI 3 from AppTemplate
│  │  ├─ Views/   WelcomePage, IsoPickPage, BuildPage(progress), DonePage
│  │  ├─ ViewModels/ matching VMs
│  │  └─ Services/  (DI wiring)
│  ├─ AkariOS.Core/
│  │  ├─ Iso/IsoMountService.cs      Mount-DiskImage via PowerShell or COM; returns drive letter; eject
│  │  ├─ Iso/IsoStagingService.cs    robocopy ISO tree → temp staging dir
│  │  ├─ Inject/OemInjectService.cs  create sources\$OEM$\$$\Setup\Scripts\, drop payload
│  │  ├─ Iso/IsoBuildService.cs      oscdimg wrapper → output AkariOS_<ver>_x64.iso
│  │  ├─ Download/WindowsIsoLinkService.cs   open MS download page / direct link helper
│  │  └─ Pipeline/InjectionPipeline.cs       orchestration w/ IProgress<ProgressReport>, cancellation
│  └─ tests/AkariOS.Core.Tests/      xUnit
```

Note: no dependency on trusted-uninstaller-cli code for v1. However, keep the `ManagedWimLib` project vendored in the repo (copied from trusted-uninstaller-cli, unreferenced initially) as the designated tool for the Phase 2 WIM-injection fallback — decide its integration when we get there. The rest of TrustedUninstaller (Core actions, CLI) stays out of scope until a future "run on this PC now" mode.

## 3. Step-by-step plan

### Task 0: Scaffold solution (~30 min)
1. Copy AppTemplate App+Framework into `src/`, rename namespaces AppTemplate→AkariOS, create sln, build clean.
2. Commit.

### Task 1: Core contracts (~30 min)
1. Create `AkariOS.Core` project; define `ProgressReport { Stage, Percent, Message }`, `IBuildStep`, `InjectionOptions { SourceIsoPath, OutputIsoPath, PayloadDir }`.
2. Unit-test options validation (missing paths etc.).

### Task 2: ISO mounting (~2 h)
1. `IsoMountService.MountAsync(path)` using `Mount-DiskImage -PassThru | Get-Volume` via a PowerShell run in-process (`System.Management.Automation`) — returns drive letter. `DismountAsync(letter)`.
2. Test manually against a real ISO (integration, not CI).
3. Handle: already-mounted image, no sources dir (not a Windows ISO → friendly error), access denied.

### Task 3: Staging + injection (~1 h)
1. `IsoStagingService`: robocopy `/E` ISO→staging; verify free disk space first (ISO ~5–6 GB, need ~12 GB total).
2. `OemInjectService`: ensure `staging\sources\$OEM$\$$\Setup\Scripts\`; copy `assets\WinSux.ps1` + `assets\SetupComplete.cmd`. Idempotent (overwrite existing files, log if a SetupComplete.cmd already existed — merge by appending our line instead of clobbering).
3. Tests: file layout assertion on a fake staging dir fixture.

### Task 4: ISO rebuild (~2 h)
1. `IsoBuildService`: locate/bundle `oscdimg.exe`; run `oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b<path>\boot\etfsboot.com#pEF,e,b<path>\efi\microsoft\boot\efisys.bin <staging> <out.iso>` (the standard dual-boot UEFI/BIOS bootdata line).
2. Fallback if oscdimg missing: prompt user to install Windows ADK, or offer UDF-only non-bootable fallback (log clearly).
3. Verify output boots in Hyper-V VM (manual test).

### Task 5: Pipeline orchestration (~1 h)
1. `InjectionPipeline`: Mount → Staging → Inject → Dismount → Oscdimg → cleanup temp; emits ProgressReport; supports cancellation between stages; try/finally guarantees dismount.
2. Integration test with a small test ISO if available; otherwise scripted manual checklist.

### Task 6: GUI wiring (~half day)
1. Pages: Welcome (explains flow + button opening Microsoft's official Win11 ISO download page in browser), IsoPick (file picker + validation), Build (progress ring, stage label, log list, cancel), Done ("flash this ISO with Rufus/Ventoy and install normally — tweaks apply automatically after install").
2. Bind VMs to pipeline progress via dispatcher queue.
3. Admin manifest not required for v1 (mounting + file ops don't need elevation); revisit if oscdimg needs it.

### Task 7: Ship WinSux.ps1 alongside
1. Decide source of truth for WinSux.ps1: separate repo copied in at build time (MSBuild target or submodule) — recommend a build task copying from a sibling checkout so edits don't require app releases.
2. Log file: have SetupComplete.cmd tee script output to `%WINDIR%\Setup\Scripts\WinSux.log` for post-install debugging.

### Phase 2 backlog (post-v1)
- Option A WIM injection fallback via ManagedWimLib (vendored in repo, integration TBD) or DISM.
- autounattend.xml generation (edition/locale selection, bypass checks, FirstLogonCommands for user-context tweaks).
- Split WinSux.ps1 into modules with a GUI checkbox picker (requires restructuring the script into functions/sections).
- Optional USB flasher step.

## 4. Files likely to change / create

All new under `C:\Users\isleap\Documents\GitHub\AkariOS\`. Existing repos untouched (template copied, not referenced).

## 5. Tests / validation

- Unit: OemInjectService layout + merge logic; options validation; pipeline stage ordering (fake steps).
- Manual integration: real Windows 11 ISO end-to-end → resulting ISO installs in VM → confirm `C:\Windows\Setup\Scripts\WinSux.log` exists and tweaks applied post-OOBE.

## 6. Risks / tradeoffs

- **$OEM$ reliability**: depends on setup copying behavior; validate on both BIOS and UEFI installs of Win10 & Win11. If flaky, escalate to Option A.
- **oscdimg redistribution**: check ADK license terms before bundling the exe; alternative = instruct user to install ADK, or use a managed ISO writer later.
- **Script runtime context**: SetupComplete.cmd runs as SYSTEM pre-first-logon — any WinSux tweaks needing the actual user profile must be deferred (FirstLogonCommands, phase 2) or handled inside the script (scheduled task / registry RunOnce for logon).
- **Disk space**: ~15 GB free required; check upfront.
- **Long operations**: staging copy + oscdimg take minutes; everything cancellable, never block UI thread.

## 7. Open questions

1. Where does WinSux.ps1 live today (path/repo)? Needed for Task 7 wiring.
2. Target: Windows 11 only, or also 10?
1. WinSux.ps1 lives in-repo at `WinSux/WinSux.ps1` — assets pipeline references it directly.
2. Target both Windows 10 and 11 ISOs (validate $OEM$ flow on both).
3. Resolved: zero user setup. The user only drops/selects an ISO and clicks build; AkariOS handles everything else internally — including oscdimg. The app ships with or auto-downloads oscdimg on first run (settings override for a custom path), so the user never sees the ADK, a terminal, or any manual step.

## Answers locked in

- WinSux.ps1 location: in-repo (`WinSux/WinSux.ps1`).
- OS targets: Windows 10 and Windows 11.
- oscdimg: what it is — Microsoft's tool that turns a folder tree into a bootable .iso file (part of the Windows ADK toolkit). Without it we can't produce a working ISO. Decision: fully invisible to the user — bundled with the app or auto-downloaded at first run. UX contract: drop ISO in → bootable AkariOS ISO out, nothing else asked.
