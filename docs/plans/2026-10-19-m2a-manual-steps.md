# M2a: Manual steps Implementation Plan

**Goal:** Split the GUI host out of `Akari.ps1` into `UI/*.ps1`, add WinUI-style controls, and build the Manual flow (Apps stub → Tweaks → Review & Apply): choose without changing anything, then one Run with a restore point first and an Outcome list at the end. Tuners go away (both are Choices now).

**Architecture:** Core grows three things the flow needs: a Run plan (`Id` + `Mode` + optional Choice `Value`), a shared result hashtable for background jobs, and `New-AkariRestorePoint`. The GUI keeps a **Selection** (pending changes, pure PowerShell in `UI/Selection.ps1`, testable without WPF) that cards write into and Review reads from. Cards are built from Loader output (one-file tweaks plus legacy Toggles). Legacy Actions, Groups and Console tweaks stay on the old pages until M2b replaces those pages with Install / Utilities.

**Tech Stack:** Windows PowerShell 5.1, WPF, Pester 3.4.0.

**Spec:** `AkariOS-PLAN.md` §3 (GUI and restore point bullets), §4 (The experience, Tweak kinds, card contents), §12 (M2 row); [ADR 0003](../adr/0003-one-click-or-manual.md); `GLOSSARY.md`.

**M2 split (decided 2026-10-19):** M2a = this plan. M2b = Home (One-click / Manual / Undo everything), Install / Utilities pages (legacy Actions and Groups move there), status bar with Restart required, log drawer removed, old pages and `UI/Rows.ps1` deleted.

## Global Constraints

- Everything in the M1 plan's Global Constraints still holds (PS 5.1 syntax, Glossary terms, Outcome and State values, test hives, how to run tests).
- AGENTS.md rule 12: never launch the GUI or run the CLI with real ids on the developer's machine. Tests may build WPF objects and parse XAML in memory (no window is shown); everything visual is checked by the user on the VM at the **VM check** steps.
- The GUI never hard-codes tweaks (rule 4). No tweak logic in `Core/` or `UI/` (rule 3): the restore point helper and the Run plan are engine, not tweaks.
- Dark only, Ink tokens (`Bg S1 S2 Bd Tx Mu Inv InvT Warn Bad`) for every new colour; no new hard-coded colours outside `UI/Controls.xaml` token definitions.
- Nothing changes on the machine while choosing. The only code that writes is the Run started from Review & Apply (and legacy Actions on the old pages, unchanged until M2b).

**Out of scope for M2a** (M2b or later): Home rebuild, Undo everything, One-click, Install / Utilities, Restart button, removing the log drawer, Apps step content (stub only), Quick select, Last used, Presets, Groups in one-file tweaks, `Requires` filtering, running the State reads off the UI thread.

## Review Focus

1. **Choice set to a value that is neither Recommended nor Default** (e.g. Win32PrioritySeparation `0x28`): Review shows `Default → 0x28 short, fixed`, the Run writes `0x28`, the Outcome is `Applied`, and the card then shows Custom. Test: Task 1 and Task 4.
2. **DWord `0xFFFFFFFF`** (SvcHostSplitThreshold Recommended): `Set-Reg` must write it without an Int32 overflow, and State must read it back as Optimized (the registry returns `-1`). Test: Task 3.
3. **Legacy Toggle with State Unknown**: the switch is three-state (unknown → On = Apply → Off = Revert → unknown = no change), so a legacy Toggle can still be reverted before it is ported. Test: Task 4 (Selection) and VM check in Task 8.
4. **Restore point fails** (System Protection off, 24 h throttle, Home edition quirks): the GUI asks "Continue without a restore point?"; No cancels the whole Run with nothing changed. Test: Task 2 (Mock) and Task 9.
5. **Advanced Tweak or riskier Choice value selected**: confirmation shows at selection time; No leaves the card as it was and the Selection unchanged. Test: Task 4 (`Test-AkariNeedsConfirm`) and VM check in Task 8.
6. **State reads on the UI thread**: opening the Tweaks step calls `Get-AkariState` for every card. Measure on the VM; if it takes more than ~1 s, note it for M2b (background read) rather than fixing it here.

---

### Task 1: Run plan with Choice values, shared job results

**Files:**
- Modify: `Core/Runner.ps1`, `Tests/Runner.Tests.ps1`, `Tests/Fixtures/Tweaks/Optimize/Gaming/GoodChoice.ps1` (only if it lacks a third Choice value)

**Interfaces:**
- Produces:
  - `Invoke-AkariTweak($Tweak, $Mode, $Value = $null)`: for a Choice in `Apply` mode, writes `$Value` when given, else `Recommended`. `Already` for a Choice with `$Value` means the current registry value matches `$Value` (`Test-AkariRegMatch`). `$Value` on a non-Choice is an error Outcome (`Failed`, "Value is only for Choices").
  - `Invoke-AkariPlan([object[]]$Items, $Tweaks)`: `$Items` are hashtables `@{ Id; Mode; Value }` (`Value` optional); one Outcome per item, in order, same unknown-id and never-stop rules as today.
  - `Invoke-AkariRun` stays, now a thin wrapper building items for `Invoke-AkariPlan` (CLI unchanged).
  - `Start-AkariJob([string]$Code, $Queue, [string]$CoreDir, [hashtable]$Shared = $null)`: when given, `$Shared` is a synchronized hashtable set as `$AkariShared` in the runspace, so the job hands back objects (Outcomes, States) instead of log text. The preamble also loads `Legacy.ps1` so a job can import legacy tweaks.

- [ ] **Step 1: Write the failing tests** in `Tests/Runner.Tests.ps1`:
  - `It 'applies a Choice to an explicit Value'`: fixture Choice under `HKCU:\Software\AkariTest\<guid>`, `Invoke-AkariTweak $t Apply 3` → Outcome `Applied`, registry value `3`.
  - `It 'is Already when the Choice holds that Value'`: run it twice → second Outcome `Already`.
  - `It 'fails a Value on a Toggle'` → `Failed`, message contains `only for Choices`.
  - `It 'runs a plan in order with mixed modes'`: two items (Apply, Revert) → two Outcomes in order with the right `Mode`.
  - `It 'hands results back through Shared'`: `$s = [hashtable]::Synchronized(@{})`; `Start-AkariJob '$AkariShared.X = 42' $q $CoreDir $s`; wait for `Handle.IsCompleted` (timeout 20 s); `$s.X | Should Be 42`; dispose.
- [ ] **Step 2: Run tests.** Expected: the five new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: Commit** `Add Run plans with Choice values and shared job results`.

---

### Task 2: Core/Restore.ps1

**Files:**
- Create: `Core/Restore.ps1`, `Tests/Restore.Tests.ps1`
- Modify: `Core/Runner.ps1` (`Start-AkariJob` preamble loads `Restore`)

**Interfaces:**
- Produces `New-AkariRestorePoint([string]$Description = 'Akari')` → `[pscustomobject]@{ Ok = [bool]; Message = [string] }`. Steps (plan §3 restore point bullet): `Checkpoint-Computer -RestorePointType MODIFY_SETTINGS`; on failure, `Enable-ComputerRestore -Drive "$env:SystemDrive\"`, set `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore` `SystemRestorePointCreationFrequency` = 0, retry once, then put that value back to what it was (remove it if it was absent). Never throws. "Once per GUI session" is the caller's job (Task 9).

- [ ] **Step 1: Write the failing tests** (Pester `Mock` only; nothing real is called):
  - `It 'is Ok when the first checkpoint works'`: Mock `Checkpoint-Computer` {}; `Assert-MockCalled Enable-ComputerRestore -Times 0`.
  - `It 'enables protection and retries once'`: first call throws, second works → `Ok` true, `Enable-ComputerRestore` called once.
  - `It 'puts the throttle value back'`: Mock `Get-AkariRegValue`, `Set-Reg`, `Remove-Reg`; when the value was absent before, `Remove-Reg` is called after the retry.
  - `It 'reports failure without throwing'`: both calls throw → `Ok` false, `Message` holds the last error.
- [ ] **Step 2: Run tests.** Expected: FAIL (file not found).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: Commit** `Add Core restore point helper`.

---

### Task 3: SvcHostSplitThreshold Choice

Replaces the second tuner. "Match RAM" from the old tuner isn't a fixed value; any threshold at or above installed RAM gives the same result (no split), so `0xFFFFFFFF` is the Recommended value and the field stays Editable for a typed KB value.

**Files:**
- Create: `Tweaks/Advanced/Tuning/SvcHostSplitThreshold.ps1`, `Tests/Fixtures/Tweaks/Optimize/Gaming/MaxDword.ps1`
- Modify: `Core/Registry.ps1` only if the tests below fail, `Tests/Registry.Tests.ps1`, `CREDITS.md` (Ultimate source)

**Tweak:** `Id = 'svchost-split-threshold'`, `Kind = 'Choice'`, `Risk = 'Safe'`, `Reboot = $true`, `Registry = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control'; Name = 'SvcHostSplitThresholdInKB'; Type = 'DWord' }`, `Choices` = `3670016` ("3.5 GB, Windows default") and `4294967295` ("No split"), `Recommended = 4294967295`, `Default = 3670016`, `Editable = $true`.

- [ ] **Step 1: Write the failing tests** (`MaxDword.ps1` is the same shape under the test hive):
  - `It 'writes DWord 0xFFFFFFFF'`: `Set-Reg <testkey> V 4294967295 DWord` doesn't throw; raw value read back as UInt32 is `4294967295`.
  - `It 'reads 0xFFFFFFFF as Optimized'`: after Apply, `Get-AkariState` → `Optimized`.
  - `It 'loads the real SvcHostSplitThreshold file'`: `Import-AkariTweakFile` on it → no throw, Kind `Choice`.
- [ ] **Step 2: Run tests.** Expected: the new tests FAIL (file missing; possibly overflow).
- [ ] **Step 3: Implement.** If `Set-Reg` overflows, convert values above `[int]::MaxValue` for `DWord` to the signed bit pattern (`[BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$v), 0)`), and make `Test-AkariRegMatch` compare DWords as UInt32.
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: Commit** `Add SvcHostSplitThreshold Choice`.

---

### Task 4: UI/Selection.ps1 (pending changes and Review)

Pure PowerShell, no WPF types, so it is fully testable.

**Files:**
- Create: `UI/Selection.ps1`, `Tests/Selection.Tests.ps1`

**Interfaces:**
- Produces:
  - `New-AkariSelection` → `[ordered]@{}` keyed by Tweak id (insertion order = Review order).
  - `Set-AkariPending($Sel, $Tweak, $State, $Target)`: `$Target` is `'Optimized'`, `'Default'`, `'None'` (no change) or a Choice value. Stores `@{ Id; Mode; Value; From; To }`, or removes the id when the target equals the current State (or the current value for a Choice) or is `'None'`. Toggle: Optimized → Apply, Default → Revert. Choice: Recommended → Apply, Default → Revert, any other value → Apply with `Value`. Action: `'Optimized'` means "run this", Mode Apply.
  - `Get-AkariReviewItems($Sel, $Tweaks)` → rows `@{ Id; Name; From; To }` in Selection order, using Choice labels when a value has one (`Default → 0x28 short, fixed`), Action rows read `Run`.
  - `Get-AkariPlanItems($Sel)` → `@{ Id; Mode; Value }` for `Invoke-AkariPlan`.
  - `Test-AkariNeedsConfirm($Tweak, $Target)` → `$true` when the Tweak is Advanced and the target is Optimized, or the chosen Choice value has a `Risk` above the Tweak's `Risk` (Safe < Caution < Advanced), or the Tweak has `Confirm` text and the target is Optimized.
  - `Get-AkariNextToggle($State, $Legacy)` → next switch target: two-state (`Optimized` ↔ `Default`) when State is known; three-state (`None` → `Optimized` → `Default` → `None`) when State is Unknown.

- [ ] **Step 1: Write the failing tests**, one `It` each: Toggle Default→Optimized gives Apply; flipping back removes it; Choice Recommended gives Apply without Value; Choice other value gives Apply with Value and a labelled To; Choice Default gives Revert; Action gives Run; Review order follows selection order; Advanced needs confirm; Safe Choice with a Caution value needs confirm; Unknown cycles through three targets; a known State cycles through two.
- [ ] **Step 2: Run tests.** Expected: FAIL (file not found).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: Commit** `Add Selection model for Manual steps`.

---

### Task 5: Split Akari.ps1 into UI files, remove the tuners

No behaviour change except the tuners: they are gone, and their Choices show up on the Advanced page as normal one-file rows until Task 8 moves them into the Tweaks step.

**Files:**
- Create: `UI/Shell.ps1` (window load, Mica / caption / StateChanged, sidebar, search, `Show-Page`, `Set-Busy`, `Invoke-Code`, the timer and job polling, Loaded / UnhandledException / Closing), `UI/Home.ps1` (spec functions and `$SpecReadCode`, `Update-Home`, `Copy-Specs`, `Start-SpecRead`, `Set-HomeDim`), `UI/Rows.ps1` (`New-Row`, `Update-Row`, the row click handler; header comment: temporary, deleted in M2b), `Tests/Ui.Tests.ps1`
- Modify: `Akari.ps1` (keeps param, CLI branch, elevation, Add-Type, root detection, Core load, tweak load; then dot-sources `UI\Home.ps1`, `UI\Rows.ps1`, `UI\Shell.ps1` and calls `ShowDialog`), `UI/MainWindow.xaml` (delete `Tuner`, `SvcTuner` and their `Chip` style)

- [ ] **Step 1: Write the failing tests** in `Tests/Ui.Tests.ps1`:
  - `It 'UI scripts have no parse errors'`: for each `UI\*.ps1` and `Akari.ps1`, `[Management.Automation.Language.Parser]::ParseFile(...)` → zero errors.
  - `It 'MainWindow.xaml parses'`: `[Windows.Markup.XamlReader]::Parse` in a child `powershell -STA` (no window shown) → prints `ok`.
  - `It 'has no tuner left'`: `Akari.ps1` and `UI\*.ps1` contain no `Tuner`, `Read-Prio`, `Read-Svc`.
- [ ] **Step 2: Run tests.** Expected: FAIL (`UI\Shell.ps1` missing, tuner names present).
- [ ] **Step 3: Implement** by moving code verbatim; only the tuner code, the `Read-Svc` call in the timer and the `$adv` tuner visibility lines are deleted.
- [ ] **Step 4: Run tests** (whole suite, including `Cli.Tests.ps1`). Expected: all pass.
- [ ] **Step 5: VM check, done by the user only:** GUI opens, Home specs load, every old page lists its rows, a legacy Toggle and an Action run, Advanced shows the two Choice rows and no tuners.
- [ ] **Step 6: Commit** `Split the GUI host into UI files and drop the tuners`.

---

### Task 6: UI/Controls.xaml (WinUI-style controls)

**Files:**
- Create: `UI/Controls.xaml` (a `ResourceDictionary`), extend `Tests/Ui.Tests.ps1`
- Modify: `UI/Shell.ps1` (parse `Controls.xaml` and add it to `$window.Resources.MergedDictionaries` before any card is built)

**Styles (Ink tokens only):**
- `Switch` (`ToggleButton`, `IsThreeState` aware): 40×20 pill track, 12 px thumb; Off = outline `Mu` track, thumb left; On = `Inv` track, `InvT` thumb right; Indeterminate = dashed `Mu` track, thumb centred; hover / pressed / disabled states. Label "On" / "Off" / "Unchanged" to its left like Windows Settings.
- `Combo` (`ComboBox` + `ComboBoxItem`): `S2` field, 4 px corners, chevron glyph `E70D`, popup `S1` with `Bd` border and 4 px corners; editable variant keeps the `Flat` text look.
- `SettingCard` (`Border`): `S1`, `Bd` 1 px, 4 px corners, padding 16,12, min height 68; Grid with icon column, text column (Name 14 px, description 12 px `Mu`), control column.
- `Section` (`Expander`): header with Category name and a chevron, cards stacked inside with 2 px gaps, open by default.
- `Accent` button (Next, Apply), `Btn` kept for Back.
- `StepDot` (`Ellipse` style): 8 px, `Inv` for the current step, `Mu` outline otherwise.

- [ ] **Step 1: Write the failing test:** `It 'Controls.xaml parses and defines every style'`: child `powershell -STA` parses it and checks keys `Switch`, `Combo`, `SettingCard`, `Section`, `Accent`, `StepDot` → prints `ok`.
- [ ] **Step 2: Run tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: Commit** `Add WinUI-style control styles`.

---

### Task 7: UI/Cards.ps1

**Files:**
- Create: `UI/Cards.ps1`, extend `Tests/Ui.Tests.ps1`

**Interfaces:**
- Produces:
  - `New-AkariCard($Tweak, $State)` → a `SettingCard` Border with `Tag = $Tweak.Id`, Name, description line (Caution / Advanced: warning glyph `E7BA` and the Risk word first; Safe: nothing; `Reboot`: trailing "Restart required" in `Mu`), state line ("Custom value" / "State unknown", hidden for Optimized / Default), and the control:
    - Toggle → `Switch`, `IsThreeState` when State is Unknown; `IsChecked` = `$true` Optimized, `$false` Default, `$null` Unknown or Custom.
    - Choice → `Combo` with one item per Choice (`Label`, plus " (Recommended)" / " (Windows default)"), `IsEditable` when `Editable`; selected item = current value, or the typed text for an unlisted one.
    - Action → `CheckBox` "Run this".
  - `Set-AkariCardControl($Card, $Target)`: puts the control back to a target without raising change handling (used when a confirmation is declined).
  - Cards raise no Core calls; Task 8 wires their events to the Selection.
- [ ] **Step 1: Write the failing tests** (child `powershell -STA`, Controls.xaml merged into a bare `ResourceDictionary` application scope, fixture tweaks): Toggle in Default → switch unchecked, two-state; Toggle Unknown → three-state, `IsChecked` null, state line "State unknown"; Choice → item count = Choices count, Recommended item labelled; Advanced → description starts with "Advanced".
- [ ] **Step 2: Run tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: Commit** `Add setting cards for Toggles, Choices and Actions`.

---

### Task 8: UI/Steps.ps1 (Apps → Tweaks → Review)

**Files:**
- Create: `UI/Steps.ps1`
- Modify: `UI/Shell.ps1` (temporary sidebar entry **Manual**, glyph `E8FD`, right under Home; M2b moves the entry point to Home), `UI/MainWindow.xaml` (a `StepsPanel` beside `Rows`: step header with dots, a content host, a footer with Back / Next), `UI/Rows.ps1` (old pages no longer list legacy Toggles, nor one-file tweaks)

**Behaviour:**
- Step 1 **Apps**: "App removal comes in a later version." and Next.
- Step 2 **Tweaks**: one `Section` expander per Section in the order Optimize, Customize, Hardware (header "Graphics & Hardware"), Advanced, then any other Section (legacy page names) alphabetically; inside, cards grouped by Category (empty Category, i.e. legacy, under "Not yet ported"). Sources: all one-file Toggles / Choices / Actions plus legacy Toggles. A card change calls `Get-AkariNextToggle` / reads the combo value, asks `Test-AkariNeedsConfirm` (No → `Set-AkariCardControl` back), then `Set-AkariPending`. Header search filters cards on this step by Name and Description. Next shows "Review (N)" with the change count and is disabled at 0.
- Step 3 **Review & Apply**: a card per `Get-AkariReviewItems` row ("Name" + "From → To"), Back, and **Apply** (Accent). Apply is Task 9.
- Leaving Manual for another page keeps the Selection; coming back returns to the same step.

- [ ] **Step 1: Write the failing test:** `It 'orders Sections and puts legacy under Not yet ported'` against a pure helper `Get-AkariStepGroups($Tweaks)` (in `UI/Steps.ps1`, no WPF) → ordered Section / Category / ids.
- [ ] **Step 2: Run tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: VM check, done by the user only:** Manual opens on Apps; Next → Tweaks shows Optimize / Advanced with the sample tweaks and legacy Toggles under their old page names; switches, the three-state legacy switch and both Choices behave; an Advanced item asks first and No leaves it unchanged; search filters; Review lists exactly the changes made; nothing on the machine changed (check one registry value). Note how long the Tweaks step takes to open (Review Focus 6).
- [ ] **Step 6: Commit** `Add Manual steps with Tweaks and Review`.

---

### Task 9: Apply from Review

**Files:**
- Modify: `UI/Steps.ps1`, `UI/Shell.ps1` (job completion reads `$job.Shared`)

**Behaviour:**
- Apply: `Set-Busy $true 'Applying N changes'`. Job code: load tweaks (`Get-AkariTweaks` + `Import-AkariLegacyTweaks`, inside the job, so no script block crosses runspaces), then, unless this GUI session already has one, `New-AkariRestorePoint` → `$AkariShared.Restore`; if it failed, the job stops before any change and the UI asks "Continue without a restore point?" (Yes starts the job again with the restore point step skipped). Then `Invoke-AkariPlan` → `$AkariShared.Outcomes`.
- On completion: Review switches to a result list, one line per Outcome with its Outcome word (Failed in `Bad` with the message), and "Restart to finish" when any Outcome has `Reboot`. A **Done** button clears the Selection, re-reads States and returns to the Tweaks step. Failed items stay listed so the user sees them.

- [ ] **Step 1: Write the failing test:** pure helper `Get-AkariRunSummary($Outcomes)` → counts per Outcome and `Reboot` flag; `It` cases for an all-Applied Run, a Run with one Failed, a Run with a reboot.
- [ ] **Step 2: Run tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests.** Expected: all pass.
- [ ] **Step 5: VM check, done by the user only:** apply 3 changes (a Toggle, a Choice with a non-Recommended value, a legacy Toggle) → restore point appears in `rstrui`, Outcomes listed, cards show the new States after Done; revert them through the same flow; turn System Protection off and apply again → the continue prompt appears and No changes nothing.
- [ ] **Step 6: Commit** `Apply Review changes as one Run with a restore point`.

---

### Task 10: Docs

**Files:**
- Modify: `AGENTS.md` (Current layout: `UI/*.ps1`, `UI/Controls.xaml`, `Core/Restore.ps1`, new Runner API), `AkariOS-PLAN.md` (§6 `UI/` list, §11 step 5 progress, §12 M2 row "M2a done"), `GLOSSARY.md` (Apply / Revert: drop the Optimize / Default button labels; Section: no longer "one sidebar page"; Run: "or one Review & Apply"; add **Selection**: the pending changes chosen in the Manual steps, nothing applied until Review & Apply)

- [ ] **Step 1:** Update the three files.
- [ ] **Step 2: Run tests.** Expected: all pass.
- [ ] **Step 3: Commit** `Update docs for M2a`.
