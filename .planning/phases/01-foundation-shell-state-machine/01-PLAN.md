---
wave: 1
depends_on: []
files_modified:
  - AkariTool/Compile.ps1
  - AkariTool/scripts/start.ps1
  - AkariTool/scripts/main.ps1
  - AkariTool/xaml/MainWindow.xaml
  - AkariTool/functions/private/Invoke-RunInBackground.ps1
  - WinSux-main/WinSux/winsux.ps1
  - WinSux-main/WinSux/stepone.ps1
  - WinSux-main/WinSux/steptwo.ps1
autonomous: false
---

# Phase 1: Foundation — Shell + State Machine

**Goal:** Deliver a compiled `akarios.ps1` with a working WPF GUI shell, a reboot-surviving state machine, pre-flight checks, admin elevation, confirmation gating, logging infrastructure, and progress reporting.

---

## Plan 1: Set up project structure and compile pipeline

### Task 1.1: Create AkariOS project structure

**Objective:** Initialize the AkariOS source directory structure matching AkariTool's pattern but with AkariOS-specific folders.

**<read_first>**
- AkariTool/Compile.ps1 (existing pattern)
- AkariTool/scripts/ (existing structure)
- WinSux-main/WinSux/ (engine scripts to integrate)

**<action>**
Create the following directory structure under `AkariOS/`:
- `scripts/` - PowerShell script files (start.ps1, main.ps1)
- `functions/private/` - Private PowerShell functions
- `functions/public/` - Public PowerShell functions  
- `xaml/` - XAML files
- `xaml/panels/` - Panel XAML files
- `assets/text/` - Text assets (engine scripts as base64)

**<acceptance_criteria>**
1. Directory `AkariOS/scripts/` exists
2. Directory `AkariOS/functions/private/` exists
3. Directory `AkariOS/functions/public/` exists
4. Directory `AkariOS/xaml/` exists
5. Directory `AkariOS/xaml/panels/` exists

**<verify>**
<automated>ls -d /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/{scripts,functions/private,functions/public,xaml,xaml/panels}</automated>
<fails_when>non-zero exit or missing directories</fails_when>

---

### Task 1.2: Create Compile.ps1 for AkariOS

**Objective:** Create a compile pipeline that follows AkariTool's pattern but produces `akarios.ps1` with AkariOS branding.

**<read_first>**
- AkariTool/Compile.ps1 (reference implementation)

**<action>**
Create `AkariOS/Compile.ps1` that:
1. Reads `scripts/start.ps1` first
2. Appends all `functions/private/*.ps1` files
3. Appends all `functions/public/*.ps1` files
4. Embeds base64-encoded assets from `assets/text/`
5. Embeds XAML from `xaml/MainWindow.xaml` with panels spliced at `@PANELS@` marker
6. Appends `scripts/main.ps1`
7. Writes output to `AkariOS/akarios.ps1`

**<acceptance_criteria>**
1. Compile.ps1 exists at `AkariOS/Compile.ps1`
2. Compile.ps1 contains `start.ps1` as the first source
3. Compile.ps1 contains the `@PANELS@` marker replacement logic
4. Compile.ps1 writes output to `akarios.ps1` in the same directory

**<verify>**
<automated>grep -l "start.ps1" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/Compile.ps1 && grep -l "@PANELS@" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/Compile.ps1 && grep -l "akarios.ps1" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/Compile.ps1</automated>
<fails_when>missing any of the required patterns</fails_when>

---

## Plan 2: Port AkariTool shell with AkariOS branding

### Task 2.1: Create AkariOS-specific start.ps1

**Objective:** Create the startup script with AKARIOS branding, admin elevation, and WPF initialization.

**<read_first>**
- AkariTool/scripts/start.ps1 (reference implementation)

**<action>**
Create `AkariOS/scripts/start.ps1` that:
1. Self-elevates via `Start-Process -Verb RunAs` if not admin
2. Sets AppUserModelID to "AkariOS.Setup" 
3. Hides console window
4. Loads WPF assemblies (PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms)
5. Defines DWM P/Invoke class for Mica backdrop
6. Initializes synchronized hashtable `$sync` with configs, runspaces, assets

**<acceptance_criteria>**
1. File exists at `AkariOS/scripts/start.ps1`
2. Contains admin elevation check with Start-Process -Verb RunAs
3. Contains SetCurrentProcessExplicitAppUserModelID with "AkariOS.Setup"
4. Contains Add-Type for WPF assemblies
5. Contains DwmApi class definition
6. Contains `$sync = [Hashtable]::Synchronized(@{})`

**<verify>**
<automated>grep -q "Verb RunAs" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/start.ps1 && grep -q "AkariOS.Setup" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/start.ps1 && grep -q "PresentationFramework" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/start.ps1</automated>
<fails_when>missing any required pattern</fails_when>

---

### Task 2.2: Create AkariOS-specific main.ps1

**Objective:** Create the main script with XAML loading, control wiring, and status bar helper.

**<read_first>**
- AkariTool/scripts/main.ps1 (reference implementation)
- 01-UI-SPEC.md (UI design contract)

**<action>**
Create `AkariOS/scripts/main.ps1` that:
1. Parses XAML via XamlReader.Parse with error handling
2. Stores named controls in $sync hashtable
3. Implements Set-Status function for runspaces
4. Sets up navigation switching between panels
5. Wires Btn* controls to Invoke-* functions

**<acceptance_criteria>**
1. File exists at `AkariOS/scripts/main.ps1`
2. Contains `[Windows.Markup.XamlReader]::Parse($inputXML)`
3. Contains Set-Status function with Dispatcher.Invoke
4. Contains `$sync.window.FindName($_.Name)` pattern

**<verify>**
<automated>grep -q "XamlReader" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/main.ps1 && grep -q "Set-Status" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/main.ps1 && grep -q "FindName" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/main.ps1</automated>
<fails_when>missing any required pattern</fails_when>

---

### Task 2.3: Create MainWindow.xaml with AkariOS branding

**Objective:** Create the main window XAML with AkariOS title and brand colors.

**<read_first>**
- AkariTool/xaml/MainWindow.xaml (reference implementation)
- AkariTool/xaml/panels/00-Home.xaml (reference panel)
- 01-UI-SPEC.md (UI design contract)

**<action>**
Create `AkariOS/xaml/MainWindow.xaml` that:
1. Uses AkariTool's XAML structure as base
2. Changes window title to "AkariOS Setup"
3. Uses AkariOS accent color (#CC2828) for primary elements
4. Includes the `@PANELS@` marker for panel injection
5. Maintains Mica backdrop support

**<acceptance_criteria>**
1. File exists at `AkariOS/xaml/MainWindow.xaml`
2. Contains Window Title "AkariOS Setup"
3. Contains `x:Name="Window"` root element
4. Contains `<!-- @PANELS@ -->` marker

**<verify>**
<automated>grep -q "AkariOS Setup" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/xaml/MainWindow.xaml && grep -q "@PANELS@" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/xaml/MainWindow.xaml</automated>
<fails_when>missing required patterns</fails_when>

---

### Task 2.4: Create panel XAML files for Phase 1

**Objective:** Create the UI panels needed for the foundation phase.

**<read_first>**
- AkariTool/xaml/panels/00-Home.xaml (reference panel structure)
- 01-UI-SPEC.md (UI design contract)

**<action>**
Create the following panel XAML files:
1. `00-Home.xaml` - Welcome screen with "Install AkariOS" CTA
2. `01-Check.xaml` - Pre-flight checklist panel
3. `02-Progress.xaml` - Stage progress display panel
4. `03-State.xaml` - Resume state banner panel

**<acceptance_criteria>**
1. All four panel files exist in `AkariOS/xaml/panels/`
2. Panels contain appropriate named controls (BtnInstall, Checklist, ProgressBar, etc.)
3. Panels follow AkariTool's card-based design system

**<verify>**
<automated>ls /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/xaml/panels/*.xaml 2>/dev/null | wc -l | grep -q "4"</automated>
<fails_when>less than 4 panel files exist</fails_when>

---

## Plan 3: Implement state machine (RunOnce + bcdedit integration)

### Task 3.1: Create state.json schema and read/write functions

**Objective:** Implement atomic state persistence to `C:\ProgramData\AkariOS\state.json`.

**<read_first>**
- AkariTool/functions/private/*.ps1 (existing function patterns)
- 01-CONTEXT.md (state machine decisions D-02, D-03)

**<action>**
Create `AkariOS/functions/private/State.ps1` with:
1. `Get-AkariOSState` function - reads state.json, returns deserialized object or default
2. `Set-AkariOSState` function - atomic write with temp file + rename
3. `Initialize-AkariOSState` function - creates default state if missing
4. State schema: CurrentStage (1/2/3), Status (pending/running/completed/error), Progress (0-100), CurrentAction (string)

**<acceptance_criteria>**
1. State.ps1 exists and can be imported
2. Get-AkariOSState returns valid state object
3. Set-AkariOSState writes atomically to C:\ProgramData\AkariOS\state.json

**<verify>**
<automated>powershell -Command "if (Test-Path '/c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/private/State.ps1') { Write-Host 'PASS' } else { Write-Host 'FAIL' }"</automated>
<fails_when>file does not exist</fails_when>

---

### Task 3.2: Implement resume detection logic

**Objective:** Detect where to resume based on safeboot flag and RunOnce entries.

**<read_first>**
- WinSux-main/WinSux/winsux.ps1 (winboot logic)
- WinSux-main/WinSux/stepone.ps1 (safeboot handling)
- 01-CONTEXT.md (D-03 decision on detection)

**<action>**
Create `AkariOS/functions/public/Resume.ps1` with:
1. `Get-ResumePoint` function that checks:
   - safeboot flag via bcdedit (Safe Mode indicates Stage 2)
   - HKCU RunOnce entries (*! stepone for Stage 2, ! steptwo for Stage 3)
   - Returns: "fresh" or "stage1", "stage2", "stage3"

**<acceptance_criteria>**
1. Resume.ps1 exists with Get-ResumePoint function
2. Function checks bcdedit for safeboot
3. Function checks HKCU RunOnce for stage entries

 **<verify>**
<automated>grep -q "bcdedit" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Resume.ps1 && grep -q "RunOnce" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Resume.ps1</automated>
<fails_when>missing bcdedit or RunOnce detection logic</fails_when>

---

## Plan 4: Implement pre-flight checks and admin elevation

### Task 4.1: Implement pre-flight check functions

**Objective:** Implement all pre-flight checks against PREF-01, PREF-02, PREF-03 requirements.

**<read_first>**
- 01-UI-SPEC.md (pre-flight check requirements)
- REQUIREMENTS.md (PREF-01, PREF-02, PREF-03)

**<action>**
Create `AkariOS/functions/public/Check.ps1` with:
1. `Test-WindowsVersion` - checks OS is Win10 20H2+ or Win11
2. `Test-AdminElevation` - verifies running as admin
3. `Test-InternetConnectivity` - tests external connectivity
4. `Test-DiskSpace` - checks ≥4 GB free on system drive
5. `Test-PendingReboot` - checks for pending reboot flags
6. `Test-PowerState` - checks AC power on battery devices
7. `Invoke-PreFlightChecks` - runs all checks, returns result object with Pass/Fail/Warning

 **<acceptance_criteria>**
1. All six check functions implemented
2. Each function returns a check result with Name, Status (Pass/Fail/Warning), Message
3. Invoke-PreFlightChecks orchestrates all checks

 **<verify>**
<automated>grep -q "Test-WindowsVersion" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Check.ps1 && grep -q "Test-AdminElevation" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Check.ps1 && grep -q "Invoke-PreFlightChecks" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Check.ps1</automated>
<fails_when>missing required functions</fails_when>

---

## Plan 5: Implement confirmation gate and stage panels

### Task 5.1: Create confirmation gate with typed acknowledgment

**Objective:** Implement destructive operation confirmation per SAFE-02 requirements.

**<read_first>**
- 01-UI-SPEC.md (Confirmation gate copywriting)
- REQUIREMENTS.md (SAFE-02)

**<action>**
Create `AkariOS/functions/public/Confirm.ps1` with:
1. `Show-ConfirmationGate` function that:
   - Displays warning about Defender, UAC, VBS, Edge removal, GPU drivers
   - Requires user to type "AKARIOS" to confirm
   - Returns $true if confirmed, $false if cancelled

 **<acceptance_criteria>**
1. Confirm.ps1 exists with Show-ConfirmationGate function
2. Function checks user input matches "AKARIOS" exactly
3. Function displays appropriate warning message

 **<verify>**
<automated>grep -q "AKARIOS" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Confirm.ps1 | grep -q "Show-ConfirmationGate" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Confirm.ps1</automated>
<fails_when>missing confirmation logic</fails_when>

---

### Task 5.2: Create stage explanation panels

**Objective:** Implement per-stage explanation panels for SAFE-03 requirements.

**<read_first>**
- 01-UI-SPEC.md (Stage explanation copy)
- AkariTool/xaml/panels/*.xaml (panel structure reference)

**<action>**
Add to panel XAML files:
1. Stage 1 explanation: Downloads payloads, configures boot, reboots to Safe Mode
2. Stage 2 explanation: Runs in Safe Mode as TrustedInstaller, disables security
3. Stage 3 explanation: Removes bloatware, applies tweaks, rebrands, reboots

 **<acceptance_criteria>**
1. Panel XAML contains stage description text
2. Panels reference "Stage 1", "Stage 2", "Stage 3" clearly
3. Cost/reversibility notes included

 **<verify>**
<automated>grep -q "Stage 1" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/xaml/panels/*.xaml && grep -q "Stage 2" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/xaml/panels/*.xaml && grep -q "Stage 3" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/xaml/panels/*.xaml</automated>
<fails_when>missing stage references in panels</fails_when>

---

### Task 5.3: Implement cancel logic during Stage 1

**Objective:** Disable cancel once in transitional state per SAFE-04 requirements.

 **<read_first>**
- 01-UI-SPEC.md (Cancel disabled reason copy)
- REQUIREMENTS.md (SAFE-04)

 **<action>**
Create `AkariOS/functions/public/Cancel.ps1` with:
1. `Get-CanCancel` function - returns $true if in Stage 1, $false after first reboot
2. Cancel button enabled state tied to this function

 **<acceptance_criteria>**
1. Cancel.ps1 exists with Get-CanCancel function
2. Function checks current stage from state

 **<verify>**
<automated>grep -q "Get-CanCancel" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Cancel.ps1</automated>
<fails_when>missing Get-CanCancel function</fails_when>

---

## Plan 6: Implement logging infrastructure and progress reporting

### Task 6.1: Create logging infrastructure per DIAG-01

**Objective:** Implement timestamped logging to `%ProgramData%\AkariOS\install.log`.

 **<read_first>**
- 01-UI-SPEC.md (Log path specification)
- REQUIREMENTS.md (DIAG-01)

 **<action>**
Create `AkariOS/functions/private/Logging.ps1` with:
1. `Initialize-AkariOSLog` - creates log file, writes startup banner
2. `Write-AkariOSLog` - appends timestamped message
3. `Get-AkariOSLogPath` - returns `%ProgramData%\AkariOS\install.log`
4. Log rotation: keep max 5MB or 10 entries

 **<acceptance_criteria>**
1. Logging.ps1 exists with all functions
2. Log path is `%ProgramData%\AkariOS\install.log`
3. Each log entry prefixed with ISO8601 timestamp

 **<verify>**
<automated>grep -q "Write-AkariOSLog" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/private/Logging.ps1 && grep -q "ProgramData" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/private/Logging.ps1</automated>
<fails_when>missing logging functions</fails_when>

---

### Task 6.2: Implement progress reporting per PROG-01, PROG-02, PROG-03

**Objective:** Implement "Step N of 3" display with progress bar and current action text.

 **<read_first>**
- 01-UI-SPEC.md (Progress text copy)
- AkariTool/functions/public/*.ps1 (Invoke-* function patterns)

 **<action>**
Create `AkariOS/functions/public/Progress.ps1` with:
1. `Update-ProgressDisplay` - updates "Step N of 3", progress bar, action text
2. `Set-CurrentStage` - sets stage number and transitions UI
3. Integration with Invoke-RunInBackground pattern for runspace updates

 **<acceptance_criteria>**
1. Progress.ps1 exists with all functions
2. Displays "Step {N} of 3: {action}" text
3. Progress bar updates reflect stage progress

 **<verify>**
<automated>grep -q "Step.*of 3" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Progress.ps1 && grep -q "Update-ProgressDisplay" /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/functions/public/Progress.ps1</automated>
<fails_when>missing progress display functions</fails_when>

---

## Wave 1: Foundation Integration

### Task 6.3: Wire all components in main.ps1

**Objective:** Integrate all functions into the working application shell.

 **<read_first>**
- AkariOS/scripts/main.ps1 (main script structure)
- All function files created in Plans 1-6

 **<action>**
1. Import all private functions (State.ps1, Logging.ps1)
2. Import all public functions (Check.ps1, Confirm.ps1, Cancel.ps1, Progress.ps1, Resume.ps1)
3. Wire pre-flight check results to UI in main.ps1
4. Wire confirmation gate to install button
5. Wire resume detection on launch

 **<acceptance_criteria>**
1. main.ps1 imports all function files
2. Pre-flight results update UI controls
3. Install button triggers confirmation gate
4. Resume detection sets initial UI state

 **<verify>**
<automated>test -f /c/Users/isleap/Documents/GitHub/AkariOS/AkariOS/scripts/main.ps1</automated>
<fails_when>main.ps1 not found</fails_when>

---

## must_haves

### Requirements Traceability

- PREF-01: Covered by Plan 4, Task 4.1 (Test-WindowsVersion, Test-AdminElevation, etc.)
- PREF-02: Covered by Plan 4, Task 4.1 (Invoke-PreFlightChecks with blocking logic)
- PREF-03: Covered by Plan 2, Task 2.1 (admin elevation in start.ps1)
- SAFE-02: Covered by Plan 5, Task 5.1 (Show-ConfirmationGate)
- SAFE-03: Covered by Plan 2, Task 2.4 and Plan 5, Task 5.2 (stage explanation panels)
- SAFE-04: Covered by Plan 5, Task 5.3 (Get-CanCancel)
- PROG-01: Covered by Plan 6, Task 6.2 (Update-ProgressDisplay)
- PROG-02: Covered by Plan 3, Task 3.2 (resume detection)
- PROG-03: Covered by Plan 3 (RunOnce integration)
- DIAG-01: Covered by Plan 6, Task 6.1 (logging infrastructure)

### Determinism Checks

- State file writes are atomic (temp file + rename)
- Log entries are timestamped
- Resume detection happens before UI shows
- Pre-flight disables Install button until all blocking checks pass

### Traceability to WinSux

- RunOnce entries: `*!stepone.ps1` for Stage 2 (Safe Mode)
- RunOnce entries: `!steptwo.ps1` for Stage 3 (normal boot)
- bcdedit safeboot: set in Stage 1, cleared at START of Stage 2
- State tracking: RunOnce + bcdedit for cross-reboot, state.json for within-stage

## threat_model

| Threat ID | Severity | Description | Mitigation |
|-----------|----------|-------------|------------|
| T-01-CODE | Medium | Malicious script injection in AkariOS installation | Admin elevation required, UAC prompt, typed acknowledgment |
| T-01-STATE | Medium | State file corruption causing incorrect resume | Atomic writes, JSON validation on read |
| T-01-SAFE | High | Safe Mode execution failures | RunOnce with *! prefix, TrustedInstaller handling in stage 2 |
| T-01-UNSAFE | High | Partial installation on inconsistent state | Pre-flight checks, state validation, "try again" message |

## Artifacts this phase produces

- `AkariOS/Compile.ps1` - Build pipeline
- `AkariOS/scripts/start.ps1` - Startup and initialization
- `AkariOS/scripts/main.ps1` - Main UI wiring
- `AkariOS/xaml/MainWindow.xaml` - Main window shell
- `AkariOS/xaml/panels/*.xaml` - UI panels
- `AkariOS/functions/private/*.ps1` - Private functions (State.ps1, Logging.ps1)
- `AkariOS/functions/public/*.ps1` - Public functions (Check.ps1, Confirm.ps1, Cancel.ps1, Progress.ps1, Resume.ps1)
- `AkariOS/akarios.ps1` (produced by Compile.ps1) - Compiled single-file output

---

## Verification Summary

Phase 1 success criteria (from ROADMAP.md):

1. User launches `akarios.ps1` and sees Windows 11-style WPF window with Mica backdrop ✓
2. User sees pre-flight checklist with pass/fail status ✓
3. User cannot click "Install AkariOS" while blocking check fails ✓
4. User sees "Step N of 3" with progress bar during install ✓
5. User can cancel during Stage 1 before first reboot ✓