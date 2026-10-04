# Architecture Research

**Domain:** Windows system-setup orchestration (WPF GUI wrapping a 3-stage PowerShell engine with reboots)
**Researched:** 2026-10-04
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     WPF GUI Shell (AkariOS Setup)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ MainWindow│  │  Panels  │  │  Status  │  │  Nav / Search    │   │
│  │  (XAML)   │  │ (XAML)   │  │   Bar    │  │  (XAML)          │   │
│  └─────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬──────────┘   │
│        │              │              │                │              │
├────────┴──────────────┴──────────────┴────────────────┴──────────────┤
│                   $sync (Synchronized Hashtable)                      │
│   configs | assets | window | controls | runspaces | state           │
├─────────────────────────────────────────────────────────────────────┤
│                    Orchestration Layer (functions/)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ State Machine│  │ Stage Runner │  │  Progress / Status       │  │
│  │ (read/write) │  │ (runspace)   │  │  (Dispatcher + file)     │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬──────────────┘  │
│         │                  │                       │                  │
├─────────┴──────────────────┴───────────────────────┴──────────────────┤
│                    WinSux Engine (3 stages)                           │
│  ┌────────────┐  ┌────────────────┐  ┌──────────────────────────┐   │
│  │ winsux.ps1 │  │ stepone.ps1    │  │ steptwo.ps1              │   │
│  │ (Stage 1)  │  │ (Stage 2, SM)  │  │ (Stage 3, normal boot)   │   │
│  │ downloads  │  │ TrustedInst.   │  │ debloat + power + brand  │   │
│  │ + reboot   │  │ + DDU + reboot │  │ + reboot                 │   │
│  └────────────┘  └────────────────┘  └──────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                    Persistence Layer                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
│  │ state.json (disk)│  │ RunOnce registry │  │ bcdedit safeboot │ │
│  │ atomic write     │  │ (boot handoff)   │  │ (boot mode flag) │ │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| MainWindow.xaml | Shell window: title bar, sidebar nav, status bar, panel container | XAML parsed by `XamlReader.Parse`; named controls registered into `$sync` |
| xaml/panels/NN-*.xaml | Per-tab UI fragments (Home, Stage1, Stage2, Stage3, About) | Spliced at `@PANELS@` marker at compile time; sorted by `NN-` prefix |
| scripts/start.ps1 | Admin elevation, WPF assembly load, DWM Mica, `$sync` init | First block in compiled file; self-elevates via `RunAs` |
| scripts/main.ps1 | XAML parse, control registration, nav wiring, button auto-wire, status bar | Last block in compiled file; `Invoke-<BtnName>` convention |
| functions/private/ | Runspace runner, console launcher, elevated process, state I/O | Compiled between start and public functions |
| functions/public/ | `Invoke-*` handlers for each button; stage orchestration logic | Auto-wired by `Btn*` → `Invoke-Btn*` convention |
| config/stages.json | Stage metadata: names, descriptions, warnings, safety gating | Baked as `$sync.configs.stages` at compile time |
| state.json (runtime) | Current stage, completed stages, user selections, timestamps, log path | Written atomically (write-temp-then-move) to `%ProgramData%\AkariOS\state.json` |
| RunOnce registry | Boot handoff: `*!stepone` and `!steptwo` entries | Set by Stage 1; consumed by Windows on next boot |
| bcdedit safeboot | Safe Mode flag for Stage 2 | Set by Stage 1, cleared by Stage 2 |

## Recommended Project Structure

```
AkariOS/
├── Compile.ps1                  # Build pipeline: concatenate → akarios.ps1
├── scripts/
│   ├── start.ps1                # Elevation, WPF load, DWM, $sync init
│   └── main.ps1                 # XAML parse, nav, button wire, status bar
├── functions/
│   ├── private/
│   │   ├── Invoke-RunInBackground.ps1    # Non-blocking runspace runner
│   │   ├── Invoke-ConsoleScript.ps1      # Embedded console script launcher
│   │   ├── Invoke-ElevatedProcess.ps1    # Start-Process -Verb RunAs wrapper
│   │   ├── Invoke-StateRead.ps1          # Read state.json → $sync.state
│   │   ├── Invoke-StateWrite.ps1         # Atomic write state.json
│   │   ├── Invoke-StageRunner.ps1        # Run a stage in a runspace
│   │   └── Invoke-ProgressReporter.ps1   # Parse stage output → status bar
│   └── public/
│       ├── Invoke-BtnInstallAll.ps1      # One-click: run all 3 stages
│       ├── Invoke-BtnStage1.ps1          # Individual stage buttons
│       ├── Invoke-BtnStage2.ps1
│       ├── Invoke-BtnStage3.ps1
│       ├── Invoke-BtnResume.ps1          # Resume after reboot
│       ├── Invoke-BtnCancel.ps1          # Cancel current stage
│       └── Invoke-BtnAbout.ps1           # About / version info
├── config/
│   └── stages.json              # Stage metadata (data-driven UI)
├── xaml/
│   ├── MainWindow.xaml          # Shell with @PANELS@ marker
│   └── panels/
│       ├── 00-Home.xaml         # Dashboard / overview
│       ├── 01-Stage1.xaml       # Stage 1 status + progress
│       ├── 02-Stage2.xaml       # Stage 2 status + progress
│       ├── 03-Stage3.xaml       # Stage 3 status + progress
│       └── 04-About.xaml        # Version, credits, AkariOS branding
├── assets/
│   ├── AkariLogo.png            # Window/taskbar icon
│   ├── AkariLogo.ico
│   └── text/                    # Embedded console scripts (base64 at compile)
│       ├── winsux.ps1           # Stage 1 (embedded, not downloaded)
│       ├── stepone.ps1          # Stage 2 (embedded)
│       └── steptwo.ps1          # Stage 3 (embedded)
├── WinSux-main/WinSux/          # Read-only reference (upstream engine)
├── AkariTool/                   # Read-only reference (UI shell source)
└── .planning/                   # GSD planning artifacts
```

### Structure Rationale

- **scripts/ → functions/ → config/ → assets/ → xaml/ → main:** Mirrors AkariTool's proven compile order. The compiled file is a single self-contained `.ps1` with no external dependencies at runtime.
- **config/stages.json:** Drives the UI data-driven — stage names, descriptions, safety warnings, and gating rules are declared in JSON, not hardcoded in XAML or PowerShell. Changing stage metadata requires no code edits.
- **assets/text/*.ps1:** The three WinSux stage scripts are embedded as base64 at compile time (AkariTool's `Invoke-ConsoleScript` pattern). This keeps the compiled file self-contained, avoids runtime download of the engine itself, and guarantees the engine version matches the GUI version.
- **functions/private vs public:** Private = infrastructure (runspaces, state I/O, progress parsing). Public = button handlers, auto-wired by the `Btn*` → `Invoke-Btn*` convention. Adding a new button requires only a new `Invoke-Btn*` function and a `Btn*` XAML element.

## Architectural Patterns

### Pattern 1: Reboot-Surviving State Machine (JSON + RunOnce + bcdedit)

**What:** A JSON state file on disk (`%ProgramData%\AkariOS\state.json`) tracks which stage the machine is in, which are complete, what the user selected, and when. Windows `RunOnce` registry entries carry the boot handoff. `bcdedit safeboot` controls the boot mode.

**When to use:** Any time the app must survive a reboot and resume automatically. This is the core pattern for AkariOS.

**Trade-offs:**
- Pros: Simple, human-readable, survives all reboot scenarios, no registry bloat, easy to debug.
- Cons: Must be written atomically (write-temp-then-move) to avoid corruption on crash. Must handle the case where the file is missing (fresh run) or stale (previous install completed).

**State schema (state.json):**
```json
{
  "version": 1,
  "installId": "2026-10-04T14:30:00Z",
  "currentStage": 0,
  "completedStages": [],
  "userSelections": {
    "confirmedDestructive": false,
    "restorePointCreated": false,
    "typedAcknowledgment": ""
  },
  "timestamps": {
    "started": null,
    "stage1Started": null,
    "stage1Completed": null,
    "stage2Started": null,
    "stage2Completed": null,
    "stage3Started": null,
    "stage3Completed": null
  },
  "logPath": "C:\\ProgramData\\AkariOS\\logs\\install.log",
  "resumeIntent": "none"
}
```

**State values for `currentStage`:**
- `0` = not started (fresh launch, no install in progress)
- `1` = Stage 1 in progress (downloads + prep, before first reboot)
- `2` = Stage 2 in progress (Safe Mode, TrustedInstaller + DDU)
- `3` = Stage 3 in progress (normal boot, debloat + power + brand)
- `4` = all stages complete

**`resumeIntent` values:**
- `"none"` = no install in progress
- `"stage1"` = Stage 1 was running, resume it
- `"stage2"` = Stage 1 completed, Stage 2 should run next
- `"stage3"` = Stage 2 completed, Stage 3 should run next
- `"done"` = all stages completed

**Atomic write protocol:**
1. Serialize state to JSON string.
2. Write to `state.json.tmp` in the same directory.
3. Flush and close the file handle.
4. Move `state.json.tmp` → `state.json` (atomic on NTFS within same volume).
5. On read: if `state.json` is corrupt or missing, treat as fresh run (`currentStage: 0`).

**Launch decision logic:**
```
On app launch:
  1. Read state.json
  2. If missing or currentStage == 0 → fresh run (show Home / Install button)
  3. If currentStage in {1,2,3} and resumeIntent != "none" → resume
     - Show "Step N of 3 in progress" with Resume / Cancel buttons
  4. If currentStage == 4 → install complete (show summary / About)
  5. If resumeIntent == "stage2" and safeboot is set → we are in Safe Mode
     - Auto-launch Stage 2 console script (stepone.ps1)
  6. If resumeIntent == "stage3" and safeboot is clear → normal boot
     - Auto-launch Stage 3 (steptwo.ps1)
```

### Pattern 2: Safe Mode Handoff (GUI → Console → GUI)

**What:** Stage 1 (winsux.ps1) ends by setting `bcdedit /set {current} safeboot minimal` and rebooting. Stage 2 (stepone.ps1) runs in Safe Mode as a console script (WPF is unreliable in Safe Mode). Stage 2 clears the safeboot flag and reboots. Stage 3 (steptwo.ps1) runs in normal boot.

**When to use:** The transition between Stage 1 and Stage 2, and between Stage 2 and Stage 3.

**Trade-offs:**
- Pros: Matches WinSux's proven approach; no WPF-in-Safe-Mode risk.
- Cons: The GUI cannot directly monitor Stage 2's progress (it's a separate console process). Progress must be inferred from state file updates written by the console script.

**Handoff mechanism:**

*GUI → Stage 2 (Safe Mode):*
1. Stage 1 completes → writes `state.json` with `currentStage: 2`, `resumeIntent: "stage2"`.
2. Stage 1 writes `RunOnce` entry: `*!stepone` → `powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\ProgramData\AkarOS\stepone.ps1`.
3. Stage 1 sets `bcdedit /set {current} safeboot minimal`.
4. Stage 1 calls `shutdown -r -t 00`.
5. On next boot (Safe Mode), Windows runs `RunOnce` → `stepone.ps1` launches as a console window.
6. `stepone.ps1` writes progress to `state.json` (via a lightweight state-update function embedded in the script).
7. `stepone.ps1` completes → writes `currentStage: 3`, `resumeIntent: "stage3"` to `state.json`.
8. `stepone.ps1` clears safeboot: `bcdedit /deletevalue {current} safeboot`.
9. `stepone.ps1` runs DDU with `-Restart` → reboots.

*Stage 2 → Stage 3 (Normal boot):*
1. On next boot (normal mode), the GUI auto-launches (via `RunOnce` set by the GUI before Stage 1, or via Startup folder shortcut).
2. GUI reads `state.json` → sees `resumeIntent: "stage3"`, safeboot is clear.
3. GUI launches Stage 3 (`steptwo.ps1`) in a runspace.
4. Stage 3 completes → writes `currentStage: 4`, `resumeIntent: "done"`.
5. Stage 3 reboots → GUI launches → shows completion summary.

*Failure detection:*
- If `state.json` shows `currentStage: 2` but `stepone.ps1` never ran (no `stage2Started` timestamp after a reasonable time), the GUI shows an error and offers to retry.
- If `stepone.ps1` crashes mid-execution, the `stage2Started` timestamp exists but `stage2Completed` does not. The GUI detects this and offers to resume Stage 2.
- The `RunOnce` entry `*!stepone` has the `*` prefix, which means it runs in Safe Mode. If Safe Mode failed to engage, the entry won't run, and the GUI will detect the stale state on next normal boot.

### Pattern 3: Embedded Engine Scripts (base64 at compile time)

**What:** The three WinSux stage scripts (`winsux.ps1`, `stepone.ps1`, `steptwo.ps1`) are stored as `assets/text/*.ps1` and baked into the compiled `akarios.ps1` as base64 strings, following AkariTool's `Invoke-ConsoleScript` pattern.

**When to use:** Always. The engine scripts are part of the app, not external downloads.

**Trade-offs:**
- Pros: Self-contained compiled file; engine version always matches GUI version; no runtime download of the engine; works offline (after initial payload downloads); proven pattern from AkariTool.
- Cons: Recompile required to update engine scripts; compiled file is larger (~80KB for the three scripts base64-encoded).

**Why not download-at-runtime for the engine?**
- The engine is the app's core logic, not a payload. Downloading it at runtime creates a version-mismatch risk (GUI expects Stage 2 behavior, but upstream changed it).
- The compiled file is already self-contained; embedding the engine is consistent with that design.
- Payloads (7zip, VC++ redists, DDU, Helium, DirectX) are still downloaded at runtime — those are large binaries that change frequently and should not be bundled.

**Why not local files on disk?**
- Requires the app to know its own install path (fragile when launched via `irm | iex`).
- Self-contained `.ps1` is the project's core design principle.

### Pattern 4: Data-Driven Stage Metadata (config/stages.json)

**What:** A JSON config file declares each stage's display name, description, safety warning, and gating requirements. The UI reads this at runtime to populate stage panels.

**When to use:** Always. No stage-specific text should be hardcoded in XAML or PowerShell.

**Trade-offs:**
- Pros: Changing stage descriptions or warnings requires only a JSON edit + recompile; supports future localization; separates content from logic.
- Cons: Slightly more complex than hardcoding; requires a JSON parser (already available in PowerShell).

**stages.json schema:**
```json
{
  "stages": [
    {
      "id": 1,
      "name": "Stage 1 — Download & Prepare",
      "description": "Downloads 7-Zip, VC++ redistributables, DDU, Helium, and DirectX. Installs 7-Zip, removes UWP apps, and prepares the system for Safe Mode.",
      "safetyWarning": "This stage downloads and install software. It will reboot your PC into Safe Mode.",
      "destructive": false,
      "requiresConfirmation": false,
      "estimatedMinutes": 10
    },
    {
      "id": 2,
      "name": "Stage 2 — Safe Mode Hardening",
      "description": "Runs in Safe Mode as TrustedInstaller. Disables Windows Defender, UAC, memory integrity, and VBS. Wipes GPU and audio drivers with DDU.",
      "safetyWarning": "This stage disables security features and wipes drivers. Your PC will be temporarily unprotected. A restore point is strongly recommended.",
      "destructive": true,
      "requiresConfirmation": true,
      "requiresRestorePoint": true,
      "estimatedMinutes": 5
    },
    {
      "id": 3,
      "name": "Stage 3 — Debloat & Optimize",
      "description": "Removes Edge, UWP apps, legacy components. Applies privacy fixes, power plan, Start menu layout, black wallpaper, and installs the Set Timer Resolution service.",
      "safetyWarning": "This stage removes Microsoft Edge and many Windows components. Some apps and features will stop working.",
      "destructive": true,
      "requiresConfirmation": true,
      "requiresRestorePoint": false,
      "estimatedMinutes": 15
    }
  ]
}
```

### Pattern 5: Progress Reporting Across Runspace and Reboot Boundaries

**What:** Long-running stage scripts report progress back to the WPF status bar. Across reboots, the next stage reads the previous stage's completion state from `state.json`.

**When to use:** Any stage that runs longer than a few seconds.

**Trade-offs:**
- Pros: User sees real-time progress; works across runspace boundaries (via `$sync` + Dispatcher); works across reboot boundaries (via `state.json`).
- Cons: Requires the stage scripts to emit progress markers (see below); requires a progress parser in the GUI.

**Within a runspace (same boot):**
1. The stage script writes progress to a log file (`%ProgramData%\AkariOS\logs\stageN.log`) using `Write-Host` or `Add-Content`.
2. The GUI's `Invoke-ProgressReporter` function tails the log file on a `DispatcherTimer` (every 500ms).
3. The parser looks for progress markers (see below) and updates the status bar via `Set-Status`.
4. The stage script also updates `state.json` at key milestones (stage started, stage completed).

**Across reboots (between boots):**
1. Each stage writes a `stageN.completed` marker to `state.json` when it finishes.
2. The next stage (or the GUI on next boot) reads `state.json` to determine what completed.
3. The GUI shows "Step N of 3" based on `currentStage` in `state.json`.
4. If a stage crashed (started but not completed), the GUI shows an error and offers to resume.

**Progress marker protocol (embedded in stage scripts):**
The stage scripts emit structured progress lines that the parser recognizes:
```
[PROGRESS:10] Downloading 7-Zip...
[PROGRESS:35] Installing VC++ redistributables...
[PROGRESS:60] Downloading DDU...
[PROGRESS:85] Preparing Safe Mode...
[DONE] Stage 1 complete.
[ERROR] Stage 1 failed: <error message>
```

The parser reads these lines and maps them to percentage + status text. The `[DONE]` and `[ERROR]` markers update `state.json`.

## Data Flow

### Request Flow

```
User clicks "Install AkariOS"
    ↓
Invoke-BtnInstallAll → reads config/stages.json → shows confirmation dialog
    ↓ (user confirms)
Invoke-StateWrite (currentStage=1, resumeIntent="stage1")
    ↓
Invoke-StageRunner → launches winsux.ps1 in runspace
    ↓
winsux.ps1 downloads payloads, installs 7zip/VC++/Helium/DirectX
    ↓
winsux.ps1 writes RunOnce entries, sets safeboot, reboots
    ↓
[REBOOT — Safe Mode]
    ↓
Windows runs RunOnce → stepone.ps1 (console)
    ↓
stepone.ps1 disables Defender/UAC, runs DDU, clears safeboot, reboots
    ↓
[REBOOT — Normal Mode]
    ↓
GUI auto-launches → reads state.json → resumeIntent="stage3"
    ↓
Invoke-StageRunner → launches steptwo.ps1 in runspace
    ↓
steptwo.ps1 removes Edge/UWP, applies power plan, brands AkariOS, reboots
    ↓
[REBOOT — Normal Mode]
    ↓
GUI auto-launches → reads state.json → currentStage=4 → shows completion
```

### State Management

```
state.json (disk)
    ↓ (read on launch)
$sync.state (in-memory)
    ↓ (subscribe via DispatcherTimer)
Status Bar / Stage Panels (UI)
    ↑ (write on stage events)
Invoke-StateWrite → state.json (atomic)
```

### Key Data Flows

1. **Stage progress (within boot):** Stage script → log file → `Invoke-ProgressReporter` (DispatcherTimer) → `Set-Status` → WPF status bar.
2. **Stage completion (across reboot):** Stage script → `state.json` (atomic write) → next boot → GUI reads `state.json` → determines next stage.
3. **User selections (across reboot):** Confirmation dialog → `$sync.state.userSelections` → `state.json` → next boot → GUI reads and restores UI state.
4. **Safe Mode detection:** `bcdedit /enum {current}` → check for `safeboot` → GUI determines whether to auto-launch Stage 2 or wait.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single user (this project) | Single `state.json`, single log directory, no concurrency needed. The architecture is already minimal. |
| Multiple installs on same machine | `installId` in `state.json` distinguishes concurrent installs. Each install gets its own log subdirectory. |
| Remote monitoring | Not applicable — this is a local system tool. |

### Scaling Priorities

1. **First bottleneck:** `state.json` atomicity under crash. If the file is corrupted mid-write, the app must recover gracefully (fall back to fresh-run state). The write-temp-then-move protocol handles this.
2. **Second bottleneck:** Log file growth during long stages. `steptwo.ps1` runs ~15 minutes and emits many lines. The log should be truncated or rotated if it exceeds a threshold (e.g., 1MB).

## Anti-Patterns

### Anti-Pattern 1: Hardcoding Stage Metadata in XAML

**What people do:** Write "Stage 2 — Safe Mode Hardening" directly in the XAML panel, hardcode the safety warning text in the confirmation dialog, and hardcode the stage list in the navigation.

**Why it's wrong:** Changing any stage description, warning, or name requires editing XAML and PowerShell, then recompiling. It also makes localization impossible and risks inconsistency between the confirmation dialog and the stage panel.

**Do this instead:** Declare all stage metadata in `config/stages.json`. The XAML panels and confirmation dialogs read from `$sync.configs.stages` at runtime.

### Anti-Pattern 2: Writing state.json Directly (Non-Atomic)

**What people do:** Open `state.json` for writing, serialize JSON, write, close — all in one step.

**Why it's wrong:** If the process crashes mid-write (power loss, BSOD, forced shutdown), the file is left truncated or empty. On next launch, the app cannot determine the install state and may skip a stage or re-run a completed one.

**Do this instead:** Write to `state.json.tmp`, flush, then `Move-Item` to `state.json`. On read, if the file is corrupt, treat as fresh run and log a warning.

### Anti-Pattern 3: Running WPF GUI in Safe Mode

**What people do:** Try to keep the WPF GUI running through the Safe Mode transition, or launch a WPF window from `stepone.ps1`.

**Why it's wrong:** WPF rendering relies on DirectX and the full Windows display stack. In Safe Mode, the display driver is a basic VGA driver, and WPF often fails to render or crashes. WinSux's approach (console script in Safe Mode) is proven.

**Do this instead:** Stage 2 is a console script. The GUI detects Safe Mode on next launch and auto-resumes after Stage 2 completes.

### Anti-Pattern 4: Reimplementing WinSux Logic in the GUI

**What people do:** Read `steptwo.ps1`, understand what it does, and rewrite the registry edits, AppX removals, and powercfg commands as native PowerShell functions in the GUI's `functions/public/`.

**Why it's wrong:** Creates a maintenance burden — every upstream WinSux update must be manually ported. The whole point of AkariOS is to wrap WinSux 1:1, not reimplement it.

**Do this instead:** The stage scripts are embedded and run as-is. The GUI's role is orchestration (state machine, progress, confirmation) and branding (AkariOS identity), not tweak logic.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| FR33THY GitHub releases | `IWR` (Invoke-WebRequest) at runtime | Payloads: 7zip, VC++ redists, DDU, Helium, DirectX. URLs are hardcoded in the stage scripts (same as WinSux). |
| Windows Update | Registry + `wuauuserv` service control | Stage 3 pauses updates for 1 year and blocks driver updates. |
| TrustedInstaller | `sc.exe config` binPath repoint | Stage 2's `Run-Trusted` helper. Must restore the original path after each command. |
| DDU (Display Driver Uninstaller) | `Start-Process -Wait` with `-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart` | Stage 2. Configured via `Settings.xml` written by Stage 1. |
| `certutil -decode` | Decodes `start2.txt` → `start2.bin` | Stage 3. Win11 Start menu layout. |
| `csc.exe` | Compiles `settimerresolutionservice.cs` → `SetTimerResolutionService.exe` | Stage 3. .NET Framework 4.x compiler. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| GUI ↔ state.json | File I/O (atomic write) | GUI reads on launch, writes on stage transitions. |
| GUI ↔ stage scripts | Runspace (in-process) or `Start-Process` (cross-process) | Stages 1 and 3 run in runspaces. Stage 2 runs as a separate console process. |
| Stage scripts ↔ state.json | File I/O (append) | Each stage updates its own progress and completion markers. |
| Stage scripts ↔ log file | `Write-Host` / `Add-Content` | Progress markers parsed by `Invoke-ProgressReporter`. |
| GUI ↔ WPF controls | `$sync` hashtable + Dispatcher | `Set-Status` uses `Dispatcher.Invoke` for thread safety. |

## Build Order

### Dependency Graph

```
1. config/stages.json          (no deps)
2. assets/text/winsux.ps1      (no deps — copy from WinSux reference)
3. assets/text/stepone.ps1     (no deps — copy from WinSux reference)
4. assets/text/steptwo.ps1     (no deps — copy from WinSux reference)
5. xaml/panels/*.xaml          (depends on stages.json for data-driven text)
6. functions/private/*.ps1     (no deps — infrastructure)
7. functions/public/*.ps1      (depends on private + stages.json)
8. scripts/start.ps1           (no deps — shell init)
9. scripts/main.ps1            (depends on all panels + functions)
10. xaml/MainWindow.xaml       (depends on panels existing for @PANELS@ marker)
11. Compile.ps1                (depends on all above — produces akarios.ps1)
```

### Build Steps

1. **Copy engine scripts:** Copy `WinSux-main/WinSux/winsux.ps1`, `stepone.ps1`, `steptwo.ps1` into `assets/text/`. These are the embedded engine.
2. **Write `config/stages.json`:** Declare stage metadata (names, descriptions, warnings, gating).
3. **Write XAML panels:** Create `xaml/panels/00-Home.xaml` through `04-About.xaml`. Panels bind to `$sync.configs.stages` for dynamic text.
4. **Write private functions:** `Invoke-RunInBackground`, `Invoke-ConsoleScript`, `Invoke-ElevatedProcess`, `Invoke-StateRead`, `Invoke-StateWrite`, `Invoke-StageRunner`, `Invoke-ProgressReporter`.
5. **Write public functions:** `Invoke-BtnInstallAll`, `Invoke-BtnStage1/2/3`, `Invoke-BtnResume`, `Invoke-BtnCancel`, `Invoke-BtnAbout`.
6. **Write `scripts/start.ps1` and `scripts/main.ps1`:** Adapt from AkariTool, adding state-machine init and resume logic.
7. **Write `Compile.ps1`:** Adapt from AkariTool, adding `config/stages.json` embedding and `assets/text/*.ps1` base64 embedding.
8. **Compile:** Run `Compile.ps1` → produces `akarios.ps1`.
9. **Test:** Launch `akarios.ps1` → verify UI renders, stage buttons work, confirmation dialogs appear, state file is created correctly.

### Dependency Notes

- **stages.json → XAML panels:** Panel text (stage names, descriptions, warnings) should be populated from `$sync.configs.stages` at runtime, not hardcoded in XAML. This requires the panels to have named `TextBlock` controls that `main.ps1` populates on load.
- **Engine scripts → Compile.ps1:** The compile script must read `assets/text/*.ps1`, base64-encode them, and inject them as `$sync.assets.winsux`, `$sync.assets.stepeone`, `$sync.assets.steptwo`.
- **state.json → all functions:** Every function that reads or writes state must go through `Invoke-StateRead` / `Invoke-StateWrite` to ensure atomicity and consistency.
- **MainWindow.xaml → panels:** The `@PANELS@` marker in `MainWindow.xaml` is replaced by the sorted concatenation of `xaml/panels/*.xaml` at compile time. Adding a new panel requires only dropping a new `NN-Name.xaml` file and recompiling.

## Sources

- WinSux engine: `WinSux-main/WinSux/` (winsux.ps1, stepone.ps1, steptwo.ps1, reg.reg, start2.txt, settimerresolutionservice.cs)
- AkariTool shell: `AkariTool/` (Compile.ps1, scripts/start.ps1, scripts/main.ps1, functions/private/, xaml/)
- AkariTool console script pattern: `functions/private/Invoke-ConsoleScript.ps1` (base64 embedding)
- AkariTool runspace pattern: `functions/private/Invoke-RunInBackground.ps1` (background execution)
- AkariTool status bar pattern: `scripts/main.ps1` → `Set-Status` function (Dispatcher-based UI updates from runspaces)

---
*Architecture research for: AkariOS — guided Windows setup app wrapping WinSux*
*Researched: 2026-10-04*
