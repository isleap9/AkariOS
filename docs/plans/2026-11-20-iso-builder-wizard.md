# ISO Builder as a wizard (native app first)

Status: I1 and I2 done 2026-11-20 (VM-checked); I3 done 2026-11-20; I4 done 2026-11-20 (I3 + I4 VM-checked 2026-11-21); I5 next. Native app (`app/`) first; the PowerShell app (`src/UI/IsoBuilder.ps1`) follows once the
native one is done and checked on the VM.

## Why

The ISO Builder is one long page of zISO's cards. Tiny11 Builder (ntdevlabs, WinUI preview, in `_ref/`) shows a
better shape: a step-by-step wizard, mode cards with a readable removal plan, build settings as switch cards, a
review, and a build page that shows each stage and operation as it runs.

**Licence: Tiny11 Builder has no licence** (its own NOTICE says redistribution rights are not granted). It is
treated like Winhance (rule 9): its flow, layout and ideas only; no code, removal lists, strings or images copied.
Its README and usage guide were read for the ideas; its source is not to be read while writing ours. Our removal
lists come from sources we already credit (FR33THY, Win11Debloat, MIT) and Microsoft's documentation. Our modes
don't carry the Tiny11 name.

**zISO is dropped** (decided 2026-11-20): no zISO cards or options in the native ISO Builder. What the build still
needs from `Iso/Data/Always.psd1` (setup's hardware checks skipped in install.wim and boot.wim) becomes our own
removal group in `Iso/Data/Groups/`, written from Microsoft's and the community's documented values; zISO's ten
options become groups only where a mode needs them, rewritten as our own data. `src/Core/Iso/Data/` (zISO's files
and licence) stays until the PowerShell app is ported to the wizard, then goes with it and CREDITS.md's zISO line.

## The wizard

Six steps, one page each, Back / Next at the lower right (Guided's footer pattern), a stepper on the left of the
page (or the step header Guided uses), the chosen image summarised beside it ("Windows 11 Pro, x64, build 26300.
Your ISO is not changed").

1. **Start**: the mode cards (below) with one line each and a tag (Recommended / Update-safe / For test VMs only).
   Picking one opens step 2.
2. **Windows image**: an ISO I have, UUP Dump, Massgrave (as today), and Microsoft's own download (new, below);
   the work and output folder; Open ISO; the edition (Pro picked when there).
3. **Components**: the mode cards again (switchable), the mode's removal plan as a read-only expander list of its
   removal groups ("n removal groups"; a group = a name, a line, its kind, what it removes). Custom: the removal
   groups as checkboxes, then the image's four lists (Store apps with their icons, Optional features, Windows
   features, OS packages), Select recommended / AkariOS pick / Clear, a search box.
4. **Build settings**: switch cards: final compression (Recovery ESD: smallest, slowest / Maximum WIM / Fast WIM),
   Turbo, Remove leftover image data, Leave .NET 3.5's setup files out, Add .NET 3.5 now, the answer file (None /
   local account / the Unattend Generator's choices), AkariOS in the image.
5. **Review**: cards: Windows image, mode and counts, output and workspace, build settings. "Build ISO" asks once.
6. **Build**: overall progress by stage; each stage an expander of its operations (Waiting, Running, Done, Skipped,
   Failed) with its duration; the current operation; at the end the ISO's path, size and SHA-256, Open folder, and a
   `report.json` next to the ISO (stages, operations, timings, removed items, warnings). Failed: the stage and
   operation that failed, Open log.

## Modes

| Mode | What it does | Keeps |
| --- | --- | --- |
| **AkariOS** (recommended) | The AkariOS setup out of the box: the AkariOS preset's app removals done in the image (FR33THY's pick, Edge without WebView2, OneDrive, the legacy apps that exist offline), the hardware checks skipped, the AkariOS preset's registry Tweaks written into the image, AkariOS-Native.exe copied in, and the rest of the preset run at the first sign-in (below). | Windows Update, Defender settings as the preset sets them, WinRE, the Store |
| **Lite** | An update-safe smaller image: Store apps Win11Debloat rates Safe, Edge (WebView2 kept), OneDrive, Windows AI, the hardware checks skipped, reserved storage and automatic BitLocker encryption off. No AkariOS. | Windows Update, Defender, WinRE, the Store, shared runtimes |
| **Minimal** (for test VMs only) | Lite, then: WinRE removed, Windows Update and Defender off, the component store reset and pruned. Irreversible: no updates, languages or features afterwards. An agreement dialog first. | Only what boots and runs |
| **Custom** | Nothing picked: the removal groups and the image's lists by hand. | What you leave |

Data, in a new folder `src/Core/Iso/Wizard/` (shared with the PowerShell app later; zISO's `Iso/Data/` untouched):
- `Groups/<Id>.psd1`: a removal group (`Name`, `Description`, `Kind` Apps / Features / Capabilities / Settings /
  Files / Setup, `Risk` Safe / Caution / Minimal, `Apps` (patterns, or `'appx:Safe'` / `'appx:AkariOS'` = the appx
  Group's rows by Risk / Keep), `Features`, `Capabilities`, `Packages`, `Registry` (hive-prefixed rows, as today's
  `ConvertTo-AkariIsoRows`), `Remove` (paths in the image), `Boot` (rows for boot.wim)).
- `Modes/<Id>.psd1`: `Name`, `Description`, `Tag`, `Order`, `Groups` (ids), `Settings` (the build settings it
  sets), `AkariOS` (the preset baked in), `Minimal = $true` (the agreement first).
Read by `IsoData.Groups` / `IsoData.Modes`. A test keeps the AkariOS mode's app pick equal to
`Presets/AkariOS.json`'s Groups.

### AkariOS already applied

Two parts, so the result matches One-click whether or not the user answers the first prompt:

1. **In the image** (offline): every Tweak of `Presets/AkariOS.json` that is registry rows only (no blocks, no
   `Requires` the image can't answer) is written into the image's hives: HKLM rows into SOFTWARE / SYSTEM, HKCU rows
   into the Default user's NTUSER.DAT (every new account starts with them). Rows go through the same
   `RegistryEngine` on the loaded hives (`HKLM\AkariIso_*`), so a value means the same thing as on a running PC.
   Per-OS Defaults pick by the image's build.
2. **At the first sign-in**: the rest of the preset (script blocks, Safe Mode phases, downloads) runs as One-click
   does: a RunOnce entry in the Default user's hive starts `C:\AkariOS\AkariOS-Native.exe --preset AkariOS`
   (one UAC prompt: "AkariOS finishes setting up"; the CLI's phased Run restarts and resumes by itself). Tweaks
   already written in part 1 come back Already. A pick to leave part 2 out ("Only what can be done in the image").

Decided: **RunOnce in the Default user's hive**. The other ways each break somewhere:
- an answer file's FirstLogonCommand forces an answer file on every AkariOS ISO and has to be merged into the
  Unattend Generator's file;
- `SetupComplete.cmd` (as SYSTEM, could register an elevated logon task with no prompt) is skipped by Windows when
  setup uses an OEM product key, which is what most laptops' firmware key gives it;
- a scheduled task written offline into `System32\Tasks` + the TaskCache keys is undocumented and fragile.
RunOnce works with or without an answer file, on any key, and its one UAC prompt is a fair "AkariOS finishes
setting up" moment. Declining it leaves part 1 in place; AkariOS stays on the Start menu to run One-click later.

## Build settings

- **Compression**: the last export of the edition: `/Compress:recovery` to `install.esd` (Recovery ESD), `max` or
  `fast` to `install.wim`. Default: Maximum WIM (today's behaviour).
- **Turbo**: features turned off in one `dism /Disable-Feature` with several `/FeatureName` (Microsoft documents
  it), each state read back after; the working image exported `fast` (it already is). Off by default.
- **Remove leftover image data**: an allow-list of folders inside the image (SoftwareDistribution\Download, Temp,
  archived CBS / DISM logs, WER queues, crash dumps), kept whenever the image has pending servicing
  (`pending.xml`). Off by default.
- **Leave .NET 3.5's setup files out**: `sources\sxs` not copied into the ISO. Off by default.

## Microsoft's download

"Latest Windows 11 from Microsoft": the product edition, language and architecture of this PC, through Microsoft's
software-download site (the same flow its page uses), Microsoft's hosts only, the download resumable, the
published SHA-256 checked when there is one. Region or availability blocks are reported, not worked around; the
other sources stay. Network only through one interface (`IHttp`), faked in tests.

## Batches

- **I1 Wizard**: the six steps over today's engine, zISO's cards gone from the native page (Custom only: the image's
  lists; the hardware-check skip still from `Always.psd1` until I4 replaces it). View models: `IsoBuilderViewModel`
  split into a step model and the parts it already has. Tests: step order, Next / Back rules, review text.
- **I2 Build page**: `IsoBuild.Build` reports operations (`IsoOperation { Stage; Name; State; Elapsed }`) beside
  `RunProgress`; stages and operations on the page; `report.json`; ISO size and SHA-256. Oracle unchanged (the port
  gets the same operations later).
- **I3 Build settings**: compression, Turbo, leftover data, .NET 3.5 payload; `IsoChoices` grows; oracle cases for
  each where the port gains them later, native-only tests until then.
- **I4 Modes**: `Modes/*.psd1`, `IsoData.Modes`, the mode cards and removal plan; AkariOS (offline Tweak rows +
  first sign-in) and Lite.
- **I5 Microsoft's download**.
- **I6 Minimal**: WinRE removal, Update and Defender off, `/Cleanup-Image /StartComponentCleanup /ResetBase`, then
  pruning; refuses pending servicing; the agreement dialog. VM-tested before it ships.
- Then the PowerShell app: the same wizard in `src/UI/IsoBuilder.ps1`, the oracle extended.

Each batch: tests green, the exe rebuilt, checked on the VM before the next.
