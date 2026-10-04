# AkariOS Roadmap

**Project:** AkariOS — guided Windows setup app wrapping WinSux
**Created:** 2026-10-04
**Mode:** mvp (Vertical MVP)
**Granularity:** standard (5 phases, 3-5 plans each)

## Overview

AkariOS wraps FR33THY's WinSux — three sequential PowerShell scripts that debloat,
optimize, and rebrand Windows across two reboots and a Safe Mode session — in a
native WPF GUI with per-stage progress, confirmation gating, and automatic resume.

The roadmap is organized into 5 phases, derived from the 18 v1 requirements. The
reboot-surviving state machine is the highest-risk component and comes first.
Distribution and code-signing come last.

## Phase Structure

### Phase 1: Foundation — Shell + State Machine

**Goal:** Deliver a compiled `akarios.ps1` with a working WPF GUI shell, a
reboot-surviving state machine, pre-flight checks, admin elevation, confirmation
gating, logging infrastructure, and progress reporting — the prerequisites for
everything else.

**Mode:** mvp

**Requirements:** PREF-01, PREF-02, PREF-03, SAFE-02, SAFE-03, SAFE-04, PROG-01, PROG-02, PROG-03, DIAG-01

**Success Criteria:**
1. User launches `akarios.ps1` and sees a Windows 11-styled WPF window with Mica backdrop — not a console menu
2. User sees a pre-flight checklist showing pass/fail status for OS version, admin, internet, disk space, pending reboot, and battery/AC power
3. User cannot click "Install AkariOS" while a blocking check is failing; the reason is shown next to the failing check
4. User sees "Step N of 3" with a progress bar and current action text at all times during the install
5. User can cancel during Stage 1 before the first reboot; cancel is disabled once the machine is in a transitional state, and the UI says why

**Plans:**
- [x] 01-PLAN.md
1. Set up project structure and compile pipeline (Compile.ps1, folder layout)
2. Port AkariTool shell (MainWindow.xaml, start.ps1, main.ps1) with AkariOS branding
3. Implement state machine (state.json read/write, atomic updates, RunOnce + bcdedit integration)
4. Implement pre-flight checks and admin elevation
5. Implement confirmation gate, per-stage explanation panels, and cancel logic
6. Implement logging infrastructure and progress reporting

---

### Phase 2: Core Engine — Stage Integration

**Goal:** Integrate the three WinSux stages into the GUI — Stage 1 and 3 as
runspaces, Stage 2 as a Safe Mode console script — with single-click flow,
individual stage run buttons, auto-resume after each reboot, and error surfacing.

**Mode:** mvp

**Requirements:** FLOW-01, FLOW-02, FLOW-03, DIAG-02

**Success Criteria:**
1. User clicks "Install AkariOS" once and the flow runs through all three stages across reboots without further interaction
2. User can run any individual stage on its own from the stage panel, independent of the full flow
3. After each reboot, the app auto-resumes showing "Resuming Step N of 3" with no user action required
4. When a stage fails, user sees an error dialog with failure detail, log excerpt, and retry/abort options

**Plans:**
- [x] 02-01-PLAN.md
- [x] 02-02-PLAN.md
- [x] 02-03-PLAN.md
- [x] 02-04-PLAN.md
1. Embed WinSux engine scripts as base64 assets
2. Implement Stage 1 integration (runspace, progress reporting, reboot handling)
3. Implement Stage 2 integration (Safe Mode console script, TrustedInstaller handling)
4. Implement Stage 3 integration (runspace, progress reporting, final reboot)
5. Implement single-click flow and individual stage run buttons
6. Implement error surfacing with retry/abort

**Status: complete — static verification only.** All nine V-checks and all nine
`AkariOS/tools/Test-*.ps1` harnesses pass; the evidence with actual output is in
`phases/02-core-engine-stage-integration/02-VERIFICATION.md`. **None of it was
observed running.** Four success criteria above are unproven at runtime and are
Phase 4's target, along with ten manual-only items listed in that same document.
Two of those ten will block a tester who does not know about them: Phase 1 defect
D-01 (the Install button stays disabled until the Check tab is opened, which
blocks the single-click flow), and the need to **log on as an administrator at
the Safe Mode prompt** for Stage 2 to fire at all.

---

### Phase 3: Hardening — Destructive Stage Hardening + Branding + Diagnostics

**Goal:** Harden WinSux's destructive behaviors (Edge removal, scheduled task
deletion, BitLocker, Windows Update pause, DISM, payload verification), implement
restore point creation, AkariOS branding, log export, and the "what changed"
summary.

**Mode:** mvp

**Requirements:** SAFE-01, BRND-01, DIAG-03, DIAG-04

**Success Criteria:**
1. User can create a system restore point before Stage 1 and sees explicit confirmation it was created
2. After install completes, user sees a "what changed" summary listing what was removed, disabled, and applied, with links to the restore point and the log
3. User can export the install log (with system info) to a location of their choosing
4. The machine is rebranded as AkariOS — OEM information, logo, wallpaper/lockscreen, and system branding are all visible

**Plans:**
1. Harden Edge removal (target only Edge-specific subdirectories)
2. Harden scheduled task deletion (blocklist-based)
3. Add BitLocker pre-check and skip system drive
4. Make Windows Update pause configurable (default 30 days, not 365)
5. Add DISM error handling and servicing stack verification
6. Add hash verification for payload downloads
7. Implement restore point creation before Stage 1
8. Implement AkariOS branding (OEM info, logo, wallpaper, system branding)
9. Implement "what changed" summary and log export

---

### Phase 4: Testing — VM-Based Validation

**Goal:** Validate the full install flow in VMs with snapshots — per-stage
testing, power-cycle simulation, Safe Mode validation, and multi-Windows-version
compatibility.

**Mode:** mvp

**Requirements:** (validation only — no new requirements)

**Success Criteria:**
1. A human tester can run the full install in a VM and verify it completes across all reboots unattended
2. A human tester can simulate a power-cycle mid-stage and verify the recovery flow works
3. A human tester can verify the install works on Windows 10 22H2, Windows 11 23H2, and Windows 11 24H2

**Plans:**
1. Provision Hyper-V/VMware VMs with Windows 10 22H2, Windows 11 23H2, Windows 11 24H2
2. Create snapshot-based test suite for each stage
3. Test power-cycle recovery scenarios
4. Test Safe Mode validation
5. Test multi-Windows-version compatibility

---

### Phase 5: Distribution — Security + Packaging

**Goal:** Prepare the tool for distribution — code signing, antivirus whitelisting,
user documentation, and distribution packaging.

**Mode:** mvp

**Requirements:** (packaging only — no new requirements)

**Success Criteria:**
1. A user can download and run `akarios.ps1` without antivirus false positives (after whitelisting)
2. A user can verify the integrity of the downloaded file via hash
3. A user can find documentation on security implications and recovery instructions

**Plans:**
1. Obtain EV code-signing certificate
2. Sign `akarios.ps1`
3. Submit for antivirus whitelisting
4. Write user documentation (security implications, recovery instructions)
5. Prepare distribution packaging

---

## Requirement Coverage

| Requirement | Phase | Status |
|-------------|-------|--------|
| PREF-01 | Phase 1: Foundation | Complete |
| PREF-02 | Phase 1: Foundation | Complete |
| PREF-03 | Phase 1: Foundation | Complete |
| SAFE-01 | Phase 3: Hardening | Pending |
| SAFE-02 | Phase 1: Foundation | Complete |
| SAFE-03 | Phase 1: Foundation | Complete |
| SAFE-04 | Phase 1: Foundation | Complete |
| PROG-01 | Phase 1: Foundation | Complete |
| PROG-02 | Phase 1: Foundation | Complete |
| PROG-03 | Phase 1: Foundation | Complete |
| FLOW-01 | Phase 2: Core Engine | Complete |
| FLOW-02 | Phase 2: Core Engine | Complete |
| FLOW-03 | Phase 2: Core Engine | Complete |
| BRND-01 | Phase 3: Hardening | Pending |
| DIAG-01 | Phase 1: Foundation | Complete |
| DIAG-02 | Phase 2: Core Engine | Complete |
| DIAG-03 | Phase 3: Hardening | Pending |
| DIAG-04 | Phase 3: Hardening | Pending |

**Total:** 18 requirements mapped to 5 phases. 100% coverage.

**Caveat on every Phase 1 and Phase 2 "Complete":** *static verification only.*
Those phases were verified with the PowerShell parser, XAML `[xml]` casts,
grep assertions, file hashes and pure-function harnesses with injected seams.
**No AkariOS installer was ever executed on the authoring machine** — the user
compiles and tests personally in a VM. Runtime validation of the full flow is
**Phase 4**, which also carries the manual-only items listed in
`phases/02-core-engine-stage-integration/02-VERIFICATION.md` (ten of them, headed
by the requirement to *log on as an administrator at the Safe Mode prompt*).
Read that table before starting Phase 4: a tester who skips that log-on step
will report a false failure.

## Ordering Rationale

- **Phase 1 before Phase 2:** The state machine and GUI shell are prerequisites for stage integration. Without reliable resume, stages cannot be tested across reboots.
- **Phase 2 before Phase 3:** Stages must be integrated and running before their destructive behaviors can be hardened. Hardening requires a working baseline to test against.
- **Phase 3 before Phase 4:** Hardening must be complete before systematic testing begins — testing unhardened code wastes VM cycles on known failure modes.
- **Phase 4 before Phase 5:** Testing must pass before distribution. Distributing untested destructive software is irresponsible.
- **Phase 5 last:** Distribution depends on a tested, hardened product. Code signing and AV whitelisting are final packaging steps.

---
*Roadmap created: 2026-10-04*
