---
phase: 01-foundation-shell-state-machine
plan: 01-PLAN.md
status: complete
completed: 2026-10-04
requirements_covered: [PREF-01, PREF-02, PREF-03, SAFE-02, SAFE-03, SAFE-04, PROG-01, PROG-02, DIAG-01, T-01-STATE]
requirements_partial: [PROG-03]
---

# Phase 01 Summary — Foundation: Shell + State Machine

## What was built

A compilable single-file WPF installer shell (`AkariOS/akarios.ps1`, 124,888 bytes,
parses clean) with the full foundation layer wired: elevation, branded dark UI,
pre-flight gate, typed confirmation, resume detection, atomic state, cancel
guard, ISO8601 logging, and progress reporting.

| Task | Commit | Deliverable |
|---|---|---|
| 1.1 | `07bd2a0` | Directory structure + `.gitkeep` placeholders |
| 1.2 | — | `Compile.ps1` concat pipeline (start → private → public → assets → XAML → main) |
| 2.1 | — | `scripts/start.ps1` — elevation, UAC-decline handling, WPF init, `$sync`, `DwmApi` |
| 2.2 | — | `scripts/main.ps1` — `XamlReader.Parse`, `SelectNodes("//*[@Name]")` control registration, `Set-Status` |
| 2.3 | — | `xaml/MainWindow.xaml` — Mica, `#1C1C1C`, `WindowChrome`, sidebar nav, status bar |
| 2.4 | — | 4 panels: `00-Home`, `01-Check`, `02-Progress`, `03-State` |
| 3.1 | `6773bf2` | `private/State.ps1` — atomic write (temp + backup + replace), schema validation |
| 3.2 | `bd38284` | `public/Resume.ps1` — injectable bcdedit/RunOnce wrappers, D-01/D-03 decision table |
| 4.1 | `0e66842` | `public/Check.ps1` — 6 checks, `Invoke-PreFlightChecks`, `CanInstall`, `Set-InstallButtonEnabled` |
| 5.1 | `28c9161` | `public/Confirm.ps1` — typed `AKARIOS` gate (modal `ShowDialog`) |
| 5.2 | `fc7e2b5` | `public/Stage.ps1` + progress-panel stage roadmap (SAFE-03) |
| 5.3 | `5d2a1be` | `public/Cancel.ps1` — `Get-CanCancel`, transitional-state guard (SAFE-04) |
| 6.1 | `92567cf` | `private/Logging.ps1` — ISO8601 log, 5MB rotation, 3 archives |
| 6.2 | `ae7d549` | `public/Progress.ps1` — `Update-ProgressDisplay`, `Set-CurrentStage`, dispatcher marshal |
| 6.3 | `10e75e9` | `main.ps1` launch integration: log init, resume detect, cancel sync, install gate |

Extra: `76e3010` `.gitignore` (excludes vendored `AkariTool/`, `WinSux-main/`, build output).

## Deviations from plan

1. **Confirm gate is a modal `Window`, not the XAML overlay.** The plan and
   `01-UI-SPEC.md` describe a `ConfirmOverlay` grid inside `MainWindow.xaml`. The
   first implementation drove that overlay from a private
   `DispatcherFrame`/`PushFrame` loop. That loop hangs the app if its "finished"
   flag is never set, and two PowerShell/WPF facts make it fragile:
   `ScriptBlock.GetNewClosure()` captures locals **by value** (so a mutated plain
   `$confirmed` never propagates back), and `Add_Click` returns `$null` (so
   `Remove_Click($null)` throws and leaks a handler per invocation).
   `Show-ConfirmationGate` now builds a modal `Window` and calls `ShowDialog()` —
   same blocking semantics, WPF's own loop, every exit path sets `DialogResult`
   explicitly. Shared state is a hashtable. The now-dead `ConfirmOverlay` grid was
   removed from `MainWindow.xaml`. Behaviour and copy are unchanged.
2. **`Test-AkariOSConfirmation` is case-SENSITIVE** (`Ordinal`), per the
   orchestrator's instruction for this task. The original draft used
   `OrdinalIgnoreCase`. Noted because it is stricter than a user might expect.
3. **All `.ps1` sources carry a UTF-8 BOM.** PowerShell 5.1 decodes BOM-less
   UTF-8 as ANSI and mangles the em dashes and box-drawing characters.
4. **State field names are `CurrentStage` / `Progress`**, not `Stage` /
   `StagePercent`. Caught and fixed in `Cancel.ps1` and `Progress.ps1` during 6.3.
5. **Progress-panel stage copy is hardcoded XAML**, seeded from
   `Get-StageExplanation` at launch. `Stage.ps1` exists so the wording has a
   single non-XAML source for the Phase 2 stage runner to log verbatim.
6. **`Invoke-BtnResume` was added** (not in the plan's function list) because
   `BtnResume` in `03-State.xaml` had no handler — the CTA would have done
   nothing. Resume for stages 2/3 shows the right stage and stops; those are
   already queued as RunOnce console scripts.
7. **Confirmation case-sensitivity** is the one product decision taken without a
   spec ruling, per instruction 2 in the scope-cut message.
8. **No `AkariOS/tools/Test-Confirm.ps1`** — deleted per instruction 4 (no more
   runtime harnesses; `tools/` gained no new files after the scope cut).

## Static verification performed

All checks below were run on this machine and produced the output shown.

| Check | Command | Result |
|---|---|---|
| Parse every source file | `Parser.ParseFile` on all `.ps1` | `PARSE OK` × all |
| Compiled output parses | `Parser.ParseFile` on `akarios.ps1` | `COMPILED PARSE OK` |
| XAML valid + parseable | `tools/Test-Xaml.ps1` | `ALL XAML CHECKS PASSED` — 33 named controls, 4 panels, no duplicate names |
| Compile pipeline runs | `Compile.ps1` | `Done -> akarios.ps1 (124,888 bytes)` |
| Asset base64 embedding | throwaway `assets/text/_probe.ps1` | `embedded asset: _probe.ps1 (27 bytes)`, `sync.assets._probe` present, file deleted after |
| Panel splice | compile output | `spliced 4 panel(s) at @PANELS@` |
| State logic | `tools/Test-State.ps1` (scratch dir) | `ALL STATE TESTS PASSED` (25 assertions) |
| Resume logic | `tools/Test-Resume.ps1` (stubs) | `ALL RESUME TESTS PASSED` (17 assertions) |
| Pre-flight logic | `tools/Test-Check.ps1` (stubs) | `ALL CHECK TESTS PASSED` (40 assertions) |
| Grep acceptance, all plan tasks | see per-task greps | all pass |
| Handlers wired in output | `grep Invoke-Btn* akarios.ps1` | `BtnResume`, `BtnInstall`, `BtnCancel`, `BtnRunChecks` all present |

**Nothing was launched, dot-sourced, or executed against live system state.** No
GUI, no elevation, no `bcdedit`, no registry write, no `%ProgramData%\AkariOS\`,
no WinSux stage, no network fetch.

## Not verified (deferred to VM)

Every item below needs a real Windows run. **None of it was verified here.**

### 1. Build and launch

```powershell
cd C:\Users\isleap\Documents\GitHub\AkariOS\AkariOS
powershell -NoProfile -ExecutionPolicy Bypass -File .\Compile.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\akarios.ps1
```
Expect: a UAC prompt, then a dark `#1C1C1C` window titled **AkariOS Setup** with a
Mica backdrop. Cancel the UAC prompt and confirm the app exits cleanly without an
unhandled exception (this exercises the declined-UAC path added in 2.1).

### 2. Confirmation gate (SAFE-02) — the deferred item from task 5.1

```powershell
# Click "Install AkariOS", then in the dialog:
#   type "akarios"  (lowercase) -> expect the error text, dialog stays open
#   type "AKARIOS " (trailing space) -> expect PASS (input is trimmed)
#   type "AKARIOS please" -> expect the error text
#   type "AKARIOS" -> expect the dialog to close and return confirmed
# Repeat, then press Escape / click Go Back / click the X -> expect no install
```
Not verified: the modal renders, the typed token is read from the TextBox at click
time, the wrong-token error appears, and every exit path returns a boolean
without hanging. The token predicate itself is pure and was reviewed, but was not
executed in this phase.

### 3. Pre-flight gate (PREF-02)

```powershell
# Click "Run checks" on the Checks page.
# Verify all six rows render with pass/warn/fail, and that Install stays
# disabled while a blocking check fails.
# Then disconnect the network and re-run -> Expect "Internet connection" to fail
# and Install to stay disabled.
```

### 4. Resume detection (PROG-02, D-01/D-03/D-05)

```powershell
# Fresh machine: State page should read "Ready to install", no Resume button.
# After a real Stage 1 RunOnce entry exists but no safeboot:
powershell -NoProfile -Command "Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' | Format-List"
powershell -NoProfile -Command "bcdedit /enum '{current}' | Select-String safeboot"
# Relaunch akarios.ps1 -> expect "Resuming Step 1 of 3".
# With safeboot minimal set -> expect "Resuming Step 2 of 3".
```

### 5. State persistence (T-01-STATE)

```powershell
Get-Content C:\ProgramData\AkariOS\state.json
# Corrupt it deliberately, then relaunch:
'{"SchemaVersion":1,"CurrentStage":99,"Status":"nope"}' | Set-Content C:\ProgramData\AkariOS\state.json
# Expect the app to fall back to defaults and NOT claim a bogus resume point.
```

### 6. Logging (DIAG-01)

```powershell
Get-Content C:\ProgramData\AkariOS\install.log -Tail 40
# Every line must start with an ISO8601 timestamp, e.g. 2026-10-04T10:47:22.331+02:00 [INFO ]
```

### 7. Cancel logic (SAFE-04)

```powershell
# With nothing running: Cancel must be disabled.
# During Stage 1 before the reboot: Cancel must be enabled; click it and expect
# "Nothing was changed." and a reset state.json.
# After the reboot is queued: Cancel must be disabled with the transitional-state
# sentence naming the current action.
```

### 8. Progress reporting (PROG-01) and PROG-03 (PARTIAL)

`Update-ProgressDisplay` formats `"Step {N} of 3: {action}"` and maps stage
boundaries (0→20→60→100) onto the bar; this was verified by grep only.
**PROG-03 (indeterminate/animated progress for unknown-duration work) is PARTIAL:**
the XAML defines an `AkariProgress` style and `ProgressBar1`, but no code path
sets `IsIndeterminate = $true`. Phase 2 should set it while a stage action of
unknown duration runs. Verify on the VM:

```powershell
# During any stage action whose duration is unknown, the bar should animate.
# Manual check: watch ProgressBar1 during a real Stage 1 download.
```

### 9. Mica / dark title bar fallback

```powershell
# On Windows 11 22H2+: translucent Mica backdrop, dark title bar.
# Force the fallback by setting the registry value below, then relaunch:
reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f
# Expect a solid #1C1C1C window with no crash.
```

## Requirements traceability

| Requirement | Status | Where |
|---|---|---|
| PREF-01 pre-flight checklist | done | `Check.ps1`, `01-Check.xaml` |
| PREF-02 single blocking gate | done | `Set-InstallButtonEnabled` + `Invoke-BtnInstall` re-check |
| PREF-03 admin elevation | done | `start.ps1` |
| SAFE-02 typed `AKARIOS` | done (behaviour unverified) | `Confirm.ps1` |
| SAFE-03 stage explanations + cost | done | `Stage.ps1`, `00-Home.xaml`, `02-Progress.xaml` |
| SAFE-04 cancel / transitional state | done | `Cancel.ps1` |
| PROG-01 "Step N of 3" | done | `Progress.ps1` |
| PROG-02 resume state | done | `Resume.ps1`, `03-State.xaml` |
| PROG-03 indeterminate progress | **partial** | no `IsIndeterminate` assignment yet |
| DIAG-01 ISO8601 log | done | `Logging.ps1` |
| T-01-STATE corruption handling | done | `State.ps1` (25 scratch assertions) |

## Phase 2 handoff

- WinSux engine scripts are **not yet embedded**. `assets/text/` holds only
  `.gitkeep`; `Compile.ps1` already base64-encodes any `assets/text/*.ps1` into
  `$sync.assets.<name>` (verified with a throwaway probe file).
- `Start-AkariOSInstall` does not exist. `Invoke-BtnInstall` detects this and
  reports "stage runner not wired yet (Phase 2)" rather than pretending to start.
- Stage 2/3 remain console scripts driven by RunOnce, per the WinSux design.