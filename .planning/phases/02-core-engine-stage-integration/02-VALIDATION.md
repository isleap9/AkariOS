---
phase: "02"
slug: "core-engine-stage-integration"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-04"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **Hard constraint for this project:** the user never runs the AkariOS installer on this
> machine — they compile and test personally in a VM. Every verification command below is
> therefore **static**: PowerShell parser, XAML `[xml]` cast, `Select-String` / grep
> assertions, `Get-FileHash`, and pure-function unit asserts with injected seams.
>
> **Forbidden in any `<automated>` command:** `bcdedit`, any registry write, `shutdown` /
> `Restart-Computer`, any download, and any touch of `C:\ProgramData\AkariOS`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PowerShell 5.1 parser + `Select-String` assertions (no external test framework) |
| **Config file** | none — no test runner to install |
| **Quick run command** | `powershell -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('C:\Users\isleap\Documents\GitHub\AkariOS\AkariOS\akarios.ps1',[ref]$null,[ref]$e); if($e.Count -eq 0){'PARSE OK'}else{$e}"` |
| **Full suite command** | see Per-Task Verification Map — V1 through V9 from `02-RESEARCH.md` §9 |
| **Estimated runtime** | ~5 seconds (parser + greps only, no engine execution) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command (parser check on the compiled shell)
- **After every plan wave:** Run V1–V9 in full
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

Task IDs are assigned by the planner; REQ and V-number mappings below are fixed by
`02-RESEARCH.md` §9 and are authoritative regardless of task numbering.

| Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command (abbreviated — full form in RESEARCH §9) | V# | Status |
|-------------|------------|-----------------|-----------|------------------------------------------------------------------------|-----|--------|
| FLOW-01 | T-02-01 | Single-click flow starts Stage 1 without re-prompting the engine; RunOnce command string matches WinSux byte-for-byte | contract + unit | parser check on compiled `akarios.ps1`; assert `(Get-AkariOSRunOnceCommand -Stage 2) -eq 'powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1'` | V1, V6 | ⬜ pending |
| FLOW-02 | T-02-02 | Per-stage buttons dispatch to real handlers; no dead buttons (Phase 1 regression class) | contract | for each `BtnStage1..3`: `Select-String -Path scripts\main.ps1 -Pattern 'function Invoke-BtnStage1'` **and** assert no `x:Name="BtnStage` in the panel | V5 | ⬜ pending |
| FLOW-03 | T-02-03 | Engine assets embedded and byte-identical to upstream; `reg.reg` filter widened so Stage 3's `regedit /S` source exists | contract + hash | `Select-String -Path akarios.ps1 -Pattern '\$sync\.assets\.(winsux\|stepone\|steptwo\|reg)\b'` (all four must hit); `Get-FileHash` equality vs `WinSux-main\WinSux\` | V2, V3, V8 | ⬜ pending |
| DIAG-02 | T-02-04 | Error path is reachable (closure fix) and `bcdedit` / `shutdown` only ever reach the engine through an injectable seam, never called directly by a runner | purity + contract | parser check; `Select-String -Path functions\**\*.ps1 -Pattern 'bcdedit' -Context 1` and confirm each hit sits inside a `-BcdWriter` default | V1, V7 | ⬜ pending |
| — (helper) | — | `Expand-AkariOSEngineAsset` is pure: injected asset map, `-DestinationRoot $env:TEMP`, returned path exists and hash matches source | unit | run with injected map into `$env:TEMP`; assert path exists + hash match | V9 | ⬜ pending |
| — (helper) | — | Panel XAML is well-formed after the new controls are added | syntax | `[xml](Get-Content panels\MainWindow.xaml -Raw)` | V4 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AkariOS/assets/text/{winsux,stepone,steptwo}.ps1` + `reg.reg` — copies of the read-only
      engine, created before any asset-decoding task runs
- [ ] `AkariOS/functions/private/Assets.ps1` — `Expand-AkariOSEngineAsset` exists and is pure
      (V9 depends on it existing)
- [ ] `Invoke-RunInBackground.ps1` closure fix + `-OnComplete` parameter — **prerequisite**;
      without it the DIAG-02 error branch is dead code (RESEARCH §5 Decision 7)

*No test framework to install — this project has none and needs none.*

---

## Manual-Only Verifications

Deferred to Phase 4 VM validation by construction. None of these can be checked statically,
and none may be attempted on this machine.

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `*!stepone` RunOnce actually fires in Safe Mode | FLOW-01, FLOW-03 | Requires a real Safe Mode boot + logon. **Also gated on Finding 5:** RunOnce fires at *logon*, and Safe Mode does not auto-logon — so Stage 2 may never run unattended. This is the project's highest listed risk. | Boot the VM into Safe Mode, confirm the logon prompt appears, log on, verify Stage 2 runs. If it does not, Finding 5 is confirmed and a Phase 3/4 decision on auto-logon is required. |
| DDU's `-Restart` transition out of Safe Mode | FLOW-03 | Requires GPU driver removal and a real reboot | Snapshot the VM, run Stage 2, confirm the machine exits Safe Mode cleanly |
| Stage 3 restore point creation | FLOW-03 | Requires an actual system restore point to exist | Run Stage 3, then check `Get-ComputerRestorePoint` |
| `Pause` in the engine ever surfacing | — | Depends on runtime console state | Observe the child console window during Stage 1 |
| Full unattended three-stage flow across two reboots | FLOW-01 | The phase's headline success criterion — only observable end-to-end on a VM | Click Install once, walk away, confirm all three stages complete |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] No `<automated>` command invokes `bcdedit`, writes the registry, calls `shutdown`, downloads, or touches `C:\ProgramData\AkariOS`
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending