# Phase 2 Patterns: file-by-file analog map

**Phase:** 2 — Core Engine — Stage Integration
**Written:** 2026-10-04
**Mode:** read-only inspection. Nothing in AkariOS was executed. No `bcdedit`, no
registry write, no `shutdown`, no write to `C:\ProgramData\AkariOS`.
**Purpose:** for every path in `02-RESEARCH.md` §6, name the closest existing analog in
this repository and quote the code the executor should copy, verbatim, with line ranges.

**Governing decision:** D-06 "Replicate WinSux exactly"
([02-CONTEXT.md:29-36](02-CONTEXT.md)). Engine files under `WinSux-main/WinSux/*.ps1` are
read-only references. Nothing in this document proposes editing them.

---

## 0. Path prefixes and a naming correction

All paths below are relative to the workspace root
`C:/Users/isleap/Documents/GitHub/AkariOS`. The application itself lives in a nested
`AkariOS/` folder, so a research path like `AkariOS/functions/public/Confirm.ps1`
resolves to `AkariOS/AkariOS/functions/public/Confirm.ps1` on disk. RESEARCH §6 writes
paths without this second prefix throughout; executors must not be surprised by it.

Two corrections to the §6 map that change what gets built:

**(a) `AkariOS/functions/public/Stage.ps1` already exists.** RESEARCH §6 lists it as
**create** with `Get-AkariOSStage` among its contents. It is on disk already, with
`Get-AkariOSStage` already defined. Action is **edit**, not create — and
`Get-AkariOSStage` must not be redefined, because `Progress.ps1:52` already calls it
inside `Get-StagePercent`. A second definition would be a duplicate-function error at
parse time in the compiled single file. See §2 for the existing body.

**(b) `assets/text/` does not exist yet.** `ls` on `AkariOS/AkariOS/assets/text/`
returns nothing; the directory has to be created along with the four engine copies.
`Compile.ps1:56` guards with `-ErrorAction SilentlyContinue` so a missing directory is
silently fine today — which is exactly why Finding 6 (`.reg` not embedded) is a silent
failure rather than a compile error.

---

## 0.5 The map at a glance

| § | Path | Action | Closest analog |
|---|------|--------|----------------|
| 1 | `assets/text/{winsux,stepone,steptwo}.ps1`, `reg.reg` | create (copy) | none needed — byte copies; `AkariTool/Compile.ps1:43-45` shows `.reg` already flows this path |
| 2 | `functions/public/Stage.ps1` | **edit** (exists!) | `Resume.ps1:108-118` injectable seam; `AkariTool/Invoke-Advanced.ps1:4-25` for the orchestration shape |
| 3 | `functions/private/Assets.ps1` | create | `AkariTool/Invoke-ConsoleScript.ps1:42-48` |
| 4 | `Compile.ps1` | edit (one line) | the same block, `AkariOS/Compile.ps1:55-62` vs `AkariTool/Compile.ps1:43-45` |
| 5 | `functions/private/Invoke-RunInBackground.ps1` | edit (prereq) | its own lines 43-59 + the hashtable fix documented at `Confirm.ps1:49-52` |
| 6 | `functions/public/Confirm.ps1` | **no edit** | `Confirm.ps1:233-242` is already the contract |
| 7 | `functions/public/Diagnostics.ps1` | create | `Logging.ps1:105-121` + `State.ps1:93-167` + `Confirm.ps1:42-207` modal |
| 8 | `xaml/panels/02-Progress.xaml` | edit | `02-Progress.xaml:37-61` + `03-State.xaml:32-38` danger card |
| 9 | `scripts/main.ps1` | edit | `main.ps1:101-114` wiring loop + `Check.ps1:407-431` handler |
| 10 | must-not-edit list | — | D-06 + §5/§7 decisions |

---

## 1. `AkariOS/assets/text/{winsux,stepone,steptwo}.ps1` + `reg.reg` — **create (copy)**

**Analog: none needed.** These are byte-for-byte copies of the engine. The *copy
mechanism* precedent is `AkariTool/Compile.ps1:43-45`, which already enumerates
`assets/text/*` with no extension filter at all:

```powershell
# Text assets (assets/text/*) — ~/.reg/.ps1 blobs decoded at runtime into $sync.assets.<filename>
Get-ChildItem "$PSScriptRoot\assets\text" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $script += "`$sync.assets." + $_.BaseName + " = '" + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) + "'" + $nl
}
```

That comment is the direct ancestor of the `.reg` requirement: AkariTool already ships
`.reg` blobs through this same path and needed no filter at all.

**Copy rule (D-06):** the asset copies must remain byte-identical to
`WinSux-main/WinSux/*.ps1`. RESEARCH §9 V8 already specifies the assertion:

```
(Get-FileHash assets\text\winsux.ps1).Hash -eq (Get-FileHash WinSux-main\WinSux\winsux.ps1).Hash
```

**Do not** "fix" the `IWR` alias (Finding 3) or the `HKLM:` typo at `steptwo.ps1:332`.
Both are upstream. Under D-06 they ship as-is.

**Asset keys** follow `$_.BaseName`, so the runtime keys are exactly
`$sync.assets.winsux`, `$sync.assets.stepone`, `$sync.assets.steptwo`,
`$sync.assets.reg`. RESEARCH §9 V2 asserts on exactly these four.

---

## 2. `AkariOS/functions/public/Stage.ps1` — **edit** (already exists)

This is the single largest file in Phase 2, and it is an edit. RESEARCH §6 names five
functions; two already exist and must be preserved byte-identical.

### 2a. Preserve: the stage table and `Get-AkariOSStage`

Existing, `AkariOS/functions/public/Stage.ps1:6-48`:

```powershell
$script:AkariOSStages = @(
    [ordered]@{
        Number       = 1
        Key          = "stage1"
        Title        = "Prepare and reboot"
        Description  = "Stage 1: Downloads required payloads, configures boot settings, and reboots into Safe Mode."
        Cost         = "Cost: downloads several hundred MB and reboots the machine. You can cancel right up to the reboot."
        Reversible   = $true
        # Approximate share of the total progress bar once the stage completes.
        PercentStart = 0
        PercentEnd   = 20
    },
    ...
)

function Get-AkariOSStage {
    [CmdletBinding()]
    param([int]$Number)
    return @($script:AkariOSStages | Where-Object { $_.Number -eq $Number })[0]
}
```

Two reasons not to touch it: `Progress.ps1:52` calls `Get-AkariOSStage -Number $Stage`,
and `main.ps1:131-135` calls `Get-StageExplanation` for the panel headlines. The
`Key` values (`"stage1"`, `"stage2"`, `"stage3"`) also match the `ResumePoint` strings
returned by `Get-ResumePoint` — `Stage.ps1` is the natural place to look up a stage by
resume-point key for the stage runner.

### 2b. Preserve: `Get-StageExplanation` (`Stage.ps1:50-85`)

Unchanged. It is SAFE-03 copy fixed by `01-UI-SPEC.md`.

### 2c. Add: pure string builders — the closest analog is `Resume.ps1`'s injectable seam

`AkariOS/functions/public/Resume.ps1:108-118` is the file's own house style for a pure
function with an injectable seam, and it is the pattern RESEARCH §3.4 says every writer
must extend:

```powershell
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Safeboot,
        $RunOnce,
        $State
    )

    # Defaults call the real wrappers; any supplied parameter short-circuits them.
    if (-not $PSBoundParameters.ContainsKey("Safeboot")) { $Safeboot = Get-BcdSafebootState }
    if (-not $PSBoundParameters.ContainsKey("RunOnce")) { $RunOnce = Get-AkariOSRunOnceEntries }
    if (-not $PSBoundParameters.ContainsKey("State"))   { $State   = Get-AkariOSState }
```

`Get-AkariOSRunOnceCommand` should be fully pure — no seam needed, because it only builds
a string. RESEARCH §9 V6 pins its output:

```powershell
(Get-AkariOSRunOnceCommand -Stage 2) -eq 'powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1'
```

The engine source of that string, verbatim `WinSux-main/WinSux/winsux.ps1:222-225`:

```powershell
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"*!stepone`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\stepone.ps1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"!steptwo`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\steptwo.ps1`" /f >nul 2>&1"
```

Note the escaping: WinSux builds the string with `` `" `` inside a `cmd /c "..."` outer
quote. AkariOS must produce the *resolved* value (V6 uses the literal `C:\Windows\Temp\`
form, i.e. `$env:SystemRoot` already expanded), not the same escaped source form.

**Reuse, do not redefine** — `Resume.ps1:18-26`, verbatim:

```powershell
$script:AkariOSRunOnceKeys = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)

# The two stage entries AkariOS writes, matching WinSux exactly:
#   `*!` -> runs in Safe Mode, `!` -> defers deletion until the command succeeds
$script:AkariOSStage2Entry = "*!stepone"
$script:AkariOSStage3Entry = "!steptwo"
```

Detection matches on the substrings `*stepone*` / `*steptwo*` at `Resume.ps1:83-84`, so
a parallel constant in `Stage.ps1` would silently stop Phase 1 detection from matching.

### 2d. Add: `Invoke-AkariOSStage` and `Start-AkariOSInstall`

The orchestration shape — decode asset, write RunOnce, set safeboot, mark state, launch
— is already proven end to end in AkariTool, in
`AkariTool/functions/public/Invoke-Advanced.ps1:4-25`, verbatim:

```powershell
function Invoke-BtnDefenderDisable {
    $r = [System.Windows.MessageBox]::Show("Disable Windows Defender? This reboots into Safe Mode, runs the disable script, and reboots back. Requires a working setup to undo. Continue?", "Defender: Disable", "YesNo", "Warning")
    if ($r -ne "Yes") { return }
    Invoke-RunInBackground -StatusStart "Disabling Defender (Safe Mode wizard)..." -StatusDone "Defender disable scheduled — restarting." -ScriptBlock {
        function Write-Asset([string]$n, [string]$d) {
            $t = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($sync.assets.$n))
            [IO.File]::WriteAllText($d, $t.TrimStart([char]0xFEFF), (New-Object Text.UTF8Encoding($false)))
        }
        Write-Asset "defenderdisable" "$env:SystemRoot\Temp\defenderdisable.ps1"
        cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"*defenderdisable`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\defenderdisable.ps1`" /f >nul 2>&1"
        ...
        cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"
        Start-Sleep -Seconds 5
        shutdown -r -t 00
    }
}
```

This is the closest thing in the repo to the whole Phase 2 orchestration, and it is
worth studying precisely for what Phase 2 must change about it:

| AkariTool does this | Phase 2 must instead |
|---|---|
| `cmd /c "reg add ... RunOnce ..."` inline in the runspace | build via pure `Get-AkariOSRunOnceCommand` + write via `-RunOnceWriter` seam |
| `cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"` inline | build via `-BcdWriter` seam so RESEARCH §9 V7 can assert it is only ever *passed to* |
| `Write-Asset` closure inside the scriptblock | promoted to `Assets.ps1`'s `Expand-AkariOSEngineAsset` (see §3) |
| runs the engine script in-process | RESEARCH §7 Decision 2: `Start-Process powershell.exe -NoProfile -File <decoded> -PassThru -Wait` — engine self-elevates at `winsux.ps1:1-4`, so in-process would `Exit` our runspace |
| `Invoke-RunInBackground` with no `-OnComplete` | the `-OnComplete` seam from §5, needed for D-10 exit-code handoff |

**Two divergences from AkariTool that are deliberate and must not be copied back:**
AkariTool writes RunOnce under `HKLM` (`Invoke-Advanced.ps1:13`); WinSux writes under
`HKCU` (`winsux.ps1:222`), and D-06 says WinSux wins. AkariTool's entry name is
`*defenderdisable` with no `!`; WinSux's is `*!stepone`, and the `!` is load-bearing
(RESEARCH §4).

The `-EngineInvoker` seam should default to the same launcher shape as
`AkariTool/functions/private/Invoke-ElevatedProcess.ps1:1-13`, verbatim — minus the
`RunAs` verb, since the engine self-elevates:

```powershell
function Start-Elevated {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$ArgumentList,
        [switch]$Wait
    )
    $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    $params = @{ FilePath = $FilePath }
    if ($ArgumentList) { $params.ArgumentList = $ArgumentList }
    if ($Wait)         { $params.Wait = $true }
    if (-not $isElevated) { $params.Verb = "RunAs" }
    Start-Process @params
}
```

Phase 2 needs `-PassThru` to get an `ExitCode`, which this helper does not expose. Copy
its structure, add `PassThru`.

`Start-AkariOSInstall` is the highest-value single function in the phase: it is the name
`Confirm.ps1:233` already looks for, so defining it completes FLOW-01 with no Phase 1
edit. See §6.

---

## 3. `AkariOS/functions/private/Assets.ps1` — **create**

**Closest analog: `AkariTool/functions/private/Invoke-ConsoleScript.ps1:42-48`**, verbatim:

```powershell
    # Decode the embedded script to a temp file, then launch it elevated
    $dest = Join-Path $env:SystemRoot "Temp\akari_$Asset.ps1"
    $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($sync.assets.$Asset))
    [IO.File]::WriteAllText($dest, $text.TrimStart([char]0xFEFF), (New-Object Text.UTF8Encoding($false)))
```

Three details that must survive into `Expand-AkariOSEngineAsset`:

1. **`TrimStart([char]0xFEFF)`** — strips the BOM. `Compile.ps1:59` base64-encodes raw
   file bytes, so a BOM in `reg.reg` would survive into the written file and break
   `regedit /S`.
2. **`New-Object Text.UTF8Encoding($false)`** — no BOM on write. `regedit /S` and
   `powershell -f` both care.
3. **Destination under `$env:SystemRoot\Temp`** — not `$env:TEMP`. The RunOnce values
   name `$env:SystemRoot\Temp\stepone.ps1` exactly (`winsux.ps1:222`); a different
   directory means the entries point at nothing.

The missing-asset guard is also worth copying, `Invoke-ConsoleScript.ps1:34-40`:

```powershell
    if (-not ($sync.assets -and $sync.assets.$Asset)) {
        Set-Status "Embedded script not found: $Asset" "#EF5350"
        [System.Windows.MessageBox]::Show(
            "Embedded script '$Asset' is missing. Recompile akari.ps1 after adding assets\text\$Asset.ps1.",
            "Akari Tool", "OK", "Error") | Out-Null
        return
    }
```

(Change the window title to `"AkariOS Setup"`.)

**Purity requirement.** RESEARCH §6 asks for this to be "a pure function over a
hashtable; trivially unit-testable with an injected asset map", and §9 V9 asserts the
returned path hashes equal to the source. So the asset map must be a parameter with a
default, following `State.ps1:73`'s precedent:

```powershell
    param([string]$Path = $script:AkariOSStateDefaultPath)
```

i.e. `param($Assets, [string]$DestinationRoot = (Join-Path $env:SystemRoot "Temp"), [switch]$Overwrite)`
with `if (-not $PSBoundParameters.ContainsKey("Assets")) { $Assets = $sync.assets }`,
mirroring the `-Safeboot`/`-RunOnce`/`-State` idiom at `Resume.ps1:116-118`.

**File naming.** `Invoke-ConsoleScript` writes `akari_$Asset.ps1` to avoid collisions.
AkariOS must **not** add a prefix — Stage 1's own downloads and the RunOnce values both
require the bare names `stepone.ps1`, `steptwo.ps1`, `winsux.ps1`, `reg.reg`.

---

## 4. `AkariOS/Compile.ps1` — **edit** (one line)

**Analog: the same file, and its own AkariTool ancestor.** Current AkariOS,
`AkariOS/Compile.ps1:55-62`:

```powershell
$script += "`$sync.assets = @{}" + $nl
Get-ChildItem (Join-Path $PSScriptRoot "assets\text") -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq ".ps1" } | Sort-Object Name | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $script += "`$sync.assets." + $_.BaseName + " = '" + [Convert]::ToBase64String($bytes) + "'" + $nl
        Write-Host ("  embedded asset: {0}.ps1 ({1:N0} bytes)" -f $_.BaseName, $bytes.Length) -ForegroundColor DarkGray
    }
```

Three edits, all in this block:

- **Widen the filter.** `.reg` must be accepted or Finding 6 fires. RESEARCH §9 V3 pins
  the shape: `Select-String -Path Compile.ps1 -Pattern 'Extension -eq "\.ps1" -or.*Extension -eq "\.reg"'`
  — so the condition must keep `".ps1" -or` on one line. AkariTool's own version
  (`Compile.ps1:43`) needs no filter at all, which is the cleanest outcome if the
  executor prefers dropping the `Where-Object` wholesale.
- **Fix the console line.** It hardcodes `{0}.ps1` at `Compile.ps1:60`, so `reg.reg` would
  be reported as `reg.ps1`. Use `$_.Name` or `$_.Extension` instead — otherwise the
  compile log misreports what it embedded, which is the kind of thing that wastes a
  Phase 4 VM session.
- **Keep the bare single-quote base64 wrapper.** `Compile.ps1:59` emits the base64 inside
  `'...'`. Base64 output is `A-Za-z0-9+/=` only, so no `'` can appear and the compiled
  file cannot break — but any wrapper change (double quotes, here-strings, escaping)
  breaks that guarantee. RESEARCH §3.8 calls this out; leave it alone.

**Ordering note.** RESEARCH §6's closing paragraph: the asset block sits at
`Compile.ps1:51-62`, after `functions/private/*` (`:45-46`) and `functions/public/*`
(`:48-49`) and before `$inputXML` (`:79`) and `main.ps1` (`:82`). So `Assets.ps1` and
`Stage.ps1` are already in scope when `$sync.assets` is assigned, and no ordering fix is
needed. `start.ps1:88-99` defines `$sync` without an `assets` key — that is fine, since
`Compile.ps1:55` creates it.

---

## 5. `AkariOS/functions/private/Invoke-RunInBackground.ps1` — **edit** (prerequisite)

The whole file is 62 lines. The relevant part, verbatim `:24-61`:

```powershell
    if (Get-Command Set-Status -ErrorAction SilentlyContinue) { Set-Status $StatusStart "#AAAAAA" }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.ThreadOptions  = "ReuseThread"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $sync)

    $ps = [powershell]::Create().AddScript($ScriptBlock)
    $ps.Runspace = $rs

    $handle = $ps.BeginInvoke()

    # Track runspace for cleanup
    $sync.runspaces.Add(@{ ps = $ps; handle = $handle; rs = $rs })

    # Completion watcher on a timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [timespan]::FromMilliseconds(300)
    $done  = $StatusDone
    $error = $null

    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $timer.Stop()
            try   { $error = $ps.EndInvoke($handle) } catch {}
            $rs.Close()
            $rs.Dispose()
            if ($error -and (Get-Command Write-AkariOSLog -ErrorAction SilentlyContinue)) {
                Write-AkariOSLog -Message ("Background job error: " + ($error | Out-String)) -Level "ERROR"
            }
            if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
                if ($error) { Set-Status "Failed - see log" "#FF3333" } else { Set-Status $done "#66BB6A" }
            }
        }
    }.GetNewClosure())

    $timer.Start()
```

### 5a. The closure bug (Finding 1) — lines 43-44, 49, 56

`$done` and `$error` are assigned at `:43-44`, then `.GetNewClosure()` at `:59` snapshots
them **by value**. So `$error = $ps.EndInvoke($handle)` at `:49` writes to the closure's
own copy, and `:56` reads the outer `$null`. **Every background job reports `Done.`**,
including failures. DIAG-02 cannot work until this is fixed.

The established fix is already in the codebase, in `Confirm.ps1:49-52` and `:63-64`:

```powershell
    .DESCRIPTION
        The typed text and the outcome live in a HASHTABLE, not plain locals:
        ScriptBlock.GetNewClosure() captures variables BY VALUE, so a plain
        $confirmed local mutated inside a handler would never be visible here and
        the gate would always report "not confirmed".
    ...
    # Shared state - MUST be a reference type, see .DESCRIPTION.
    $state = @{ Confirmed = $false }
```

Phase 1 already hit this exact trap and documented the fix. Wrap the tick state in a
hashtable — `$outcome = @{ Done = $StatusDone; Error = $null }` — and read
`$outcome.Error` / `$outcome.Done` inside the handler.

### 5b. Add `-OnComplete`

`param()` at `:18-22` gains `[scriptblock]$OnComplete`, invoked after the status update in
both branches. Phase 2 uses it to write the `LastError` block to `state.json` and to open
the error dialog. The same reference-type rule applies — pass results through a hashtable,
never by reassigning a captured local.

### 5c. Add `InitialSessionState` (RESEARCH §7 Decision 1)

`:26` calls `[runspacefactory]::CreateRunspace()` with no argument, so the runspace sees
only the default session state — **none of AkariOS's own functions**. This is invisible
today because the only caller is `Check.ps1:419-431`, whose scriptblock calls
`Invoke-PreFlightChecks` and then marshals a raw `[action]{}`:

```powershell
    Invoke-RunInBackground -StatusStart "Running pre-flight checks..." -StatusDone "Pre-flight checks complete" -ScriptBlock {
        $result = Invoke-PreFlightChecks
        $sync.window.Dispatcher.Invoke([action]{
            Show-CheckResult -Results $result.Results -Summary $result.Summary
            ...
        }, "Normal")
    }
```

...which works only because `Invoke-PreFlightChecks` happens to resolve through the
caller's session state. Phase 2's scriptblock will call `Write-AkariOSLog`,
`Update-ProgressDisplay` and `Set-AkariOSState`, none of which will resolve in a default
ISS. RESEARCH §5 Decision 1 specifies `InitialSessionState]::CreateDefault2()` plus
`AddScript` of the function files.

**Keep `$rs.SessionStateProxy.SetVariable("sync", $sync)` at `:30`.** The dispatcher
pattern in `Progress.ps1:107-124` depends on `$sync` being present in the worker:

```powershell
    $syncRef = $sync
    if ($syncRef -and $syncRef.window) {
        $window = $syncRef.window
        $dispatcher = $window.Dispatcher
        $work = [System.Action]{
            if ($syncRef.ProgressStep)   { $syncRef.ProgressStep.Text = $stepText }
            ...
        }.GetNewClosure()

        if ($dispatcher.CheckAccess()) {
            $work.Invoke()
        } else {
            # Non-blocking marshal: the worker must not deadlock on the UI thread.
            $dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $work) | Out-Null
        }
    }
```

Copy `CheckAccess()`-then-`BeginInvoke` verbatim — RESEARCH §3.3 notes a blocking `Invoke`
from a worker while the UI thread waits on the job deadlocks. `Check.ps1:421` uses the
older blocking `$sync.window.Dispatcher.Invoke([action]{...}, "Normal")` form; prefer the
`Progress.ps1` form for anything Phase 2 adds.

---

## 6. `AkariOS/functions/public/Confirm.ps1` — **no edit needed**

Correct per RESEARCH §6, and worth stating precisely so no executor "improves" it. The
branch, verbatim `AkariOS/functions/public/Confirm.ps1:233-242`:

```powershell
    if (Get-Command Start-AkariOSInstall -ErrorAction SilentlyContinue) {
        Start-AkariOSInstall
    } else {
        # Phase 2 wires the stage runner; until then, say so rather than
        # pretending the install started.
        Set-Status "Confirmed - stage runner not wired yet (Phase 2)." "#FFA726"
        [System.Windows.MessageBox]::Show(
            "Confirmation accepted. The stage runner is wired up in Phase 2.",
            "AkariOS Setup") | Out-Null
    }
```

The contract is already fixed. Defining `Start-AkariOSInstall` anywhere in the compiled
script makes this branch take the first path. The `else` becomes dead code that Phase 2
may leave in place or delete — but deleting it touches a Phase 1 file, and RESEARCH §6
deliberately chose not to.

Two gates sit above it and neither needs changing. `Confirm.ps1:217-225` re-checks
pre-flight before the gate, and `:227-231` handles cancel:

```powershell
    $pre = Invoke-PreFlightChecks
    if (-not $pre.CanInstall) {
        $first = @($pre.BlockingFails)[0]
        Show-CheckResult -Results $pre.Results -Summary $pre.Summary
        [System.Windows.MessageBox]::Show(
            ("The install cannot start yet.`n`n" + $first.Name + ": " + $first.Message),
            "AkariOS Setup") | Out-Null
        return
    }

    if (-not (Show-ConfirmationGate)) {
        Set-Status "Install cancelled at the confirmation gate." "#AAAAAA"
        Show-Panel "PanelHome"
        return
    }
```

`Start-AkariOSInstall` therefore runs only after pre-flight passed **and** the token was
typed. It must not re-open the gate (that would double-prompt), and per RESEARCH
Finding 5 it should call `Set-Status` with the Safe Mode log-on hint before Stage 1's
reboot lands — the cheapest available mitigation, and it needs no engine change.

---

## 7. `AkariOS/functions/public/Diagnostics.ps1` — **create**

No existing analog by name; it is composed from three established seams.

### 7a. Reading the failure — `Logging.ps1:105-121`

`Get-AkariOSLogTail` already exists and is explicitly documented for this use. Verbatim:

```powershell
function Get-AkariOSLogTail {
    <#
    .SYNOPSIS
        Returns the last N log lines, newest last. Used by the home panel's LOG
        card and by error reporting.
    #>
    [CmdletBinding()]
    param([int]$Count = 20,
          [string]$Path = (Get-AkariOSLogPath))

    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    try {
        return @(Get-Content -LiteralPath $Path -Tail $Count -ErrorAction Stop)
    } catch {
        return @()
    }
}
```

Its `.DESCRIPTION` already names "error reporting" as a consumer — Phase 2 is that
consumer. Both `-Count` and `-Path` are injectable, so DIAG-02 is testable against a
scratch log.

### 7b. Reading the state — `State.ps1:66-91`

`Get-AkariOSState -Path` is the read side, and `-Path` defaults to
`$script:AkariOSStateDefaultPath = "C:\ProgramData\AkariOS\state.json"` (`State.ps1:14`).
Under the hard constraint, tests point this at a scratch directory.

### 7c. Writing the `LastError` block — `State.ps1:93-167`

**This is the constraint that matters most for this file.** `New-AkariOSState`
(`State.ps1:28-36`) emits a fixed shape:

```powershell
    [pscustomobject]@{
        SchemaVersion = 1
        CurrentStage  = $CurrentStage
        Status        = $Status
        Progress      = $Progress
        CurrentAction = $CurrentAction
        RebootPending = $false
        UpdatedAt     = (Get-Date).ToUniversalTime().ToString("o")
    }
```

and `Test-AkariOSState` (`State.ps1:52-61`) validates it:

```powershell
        foreach ($p in @("SchemaVersion", "CurrentStage", "Status", "Progress", "CurrentAction")) {
            if ($null -eq $State.PSObject.Properties[$p]) { return $false }
        }
        ...
        if ($State.CurrentStage -lt 0 -or $State.CurrentStage -gt 3)  { return $false }
        ...
        if ([string]$State.Status -notin @("pending", "running", "completed", "error")) { return $false }
```

Consequences for adding `LastError`:

- **`Status` already has an `"error"` value** in the `ValidateSet` at both
  `State.ps1:61` and `State.ps1:111`. Use it. Do not invent a new status constant.
- **Validation requires the five listed properties, not that *only* those exist.** A
  `LastError` property on the object passes `Test-AkariOSState` untouched. But the
  `"Fields"` parameter set at `State.ps1:120-133` **rebuilds the object from scratch**,
  copying field by field:

  ```powershell
        $base = Get-AkariOSState -Path $Path
        $toWrite = New-AkariOSState -CurrentStage $base.CurrentStage `
                                   -Status       $base.Status `
                                   -Progress     $base.Progress `
                                   -CurrentAction $base.CurrentAction
        $toWrite.RebootPending = $base.RebootPending
        if ($PSBoundParameters.ContainsKey("CurrentStage"))  { $toWrite.CurrentStage  = $CurrentStage }
        ...
  ```

  **`$toWrite.LastError` is never copied from `$base`, so any `Set-AkariOSState` call
  using the `Fields` set silently wipes the error block.** This is a live trap:
  `Progress.ps1:101` calls `Set-AkariOSState` with `-CurrentStage/-Progress/-Status/
  -CurrentAction` (the `Fields` set) on *every* progress update. The fix is one line in
  the `Fields` branch mirroring `:127`, e.g. `$toWrite.LastError = $base.LastError`.
  Without it, DIAG-02's error block evaporates the moment the UI refreshes.

  Note `Progress.ps1:101` also passes `-Status "installing"`, which is **not** in the
  `ValidateSet` at `State.ps1:111` — so that call throws and is swallowed by the
  `catch` at `Progress.ps1:102-104`. Pre-existing Phase 1 defect; out of Phase 2 scope,
  but it means progress is currently never persisted to `state.json`.

- **Always write via the `"Object"` set** for a full error record —
  `Set-AkariOSState -State $obj` at `State.ps1:117-119` passes validation as a unit and
  is the only path that does not drop fields.
- **The writer is atomic** (`State.ps1:136-164`): temp file in the same directory, then
  `[System.IO.File]::Replace($tmp, $Path, $backup)`. Nothing about D-10 needs to
  bypass this.

### 7d. Do not add a `ResumePoint` value

`Get-ResumePoint`'s decision table (`Resume.ps1:124-154`) returns only `fresh`,
`stage1`, `stage2`, `stage3`, `inconsistent`, and `main.ps1:151-178` switches on exactly
those. RESEARCH §5 Decision 6 and §7 Decision 3 both chose an independent
`Get-AkariOSStageFailure` over extending that table, so Phase 1's verified D-03/D-05
behaviour stays byte-identical.

### 7e. `Show-StageError` / `Resolve-StageFailure` — modal-dialog analog

There is no error-dialog function yet. The pattern to copy is
`Show-ConfirmationGate` (`Confirm.ps1:42-207`): build a `System.Windows.Window` with
`ShowDialog()`, put the outcome in a **hashtable** (not a local — `Confirm.ps1:63` and
`Confirm.ps1:49-52` explain why), and resolve every exit path so it cannot hang:

```powershell
    # Shared state - MUST be a reference type, see .DESCRIPTION.
    $state = @{ Confirmed = $false }
    ...
    $dlg.ShowDialog() | Out-Null

    $confirmed = [bool]$state.Confirmed
    $dlg.Close()
    return $confirmed
```

Its colour vocabulary is reusable as-is — `Confirm.ps1:68-77` defines the danger palette
that a failure dialog wants:

```powershell
    $accent    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CC2828")
    $accentHi  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E03535")
    $dangerTx  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF3333")
    $dangerBg  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1AFF3333")
    $dangerBr  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#25FF4444")
    $panelBg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#26262A")
```

**Retry/abort semantics.** RESEARCH §5 Decision 11: retry re-runs the whole stage via the
same runner after showing the log excerpt; abort clears the error block and returns to
ready **without touching RunOnce or bcdedit**. The "without touching" half is a real
constraint — under D-06, abort that cleared the safeboot flag or deleted the RunOnce
entries would be editing engine behaviour, which is exactly what D-06 forbids.

---

## 8. `AkariOS/xaml/panels/02-Progress.xaml` — **edit** (RESEARCH §6 says "or equivalent panel")

RESEARCH §5 Decision 9 puts the per-stage buttons on the existing progress panel. This is
the file, and the house conventions are in its own header comment
(`02-Progress.xaml:1-12`):

```xml
<!--
  ==========================================================================
  02-Progress  -  install progress display (PROG-01).

  Shows "Step {N} of 3" at all times, the per-stage progress bar, the current
  action text, and the cancel button whose enabled state is driven by
  Get-CanCancel (SAFE-04).

  This file is a FRAGMENT injected into xaml/MainWindow.xaml at the @PANELS@ marker.
  Symbols must be XML entities, never pasted raw (&#183; = middle dot).
  ==========================================================================
-->
```

Four rules, each with a precedent in this file or its siblings:

**1. Plain `Name=`, never `x:Name`.** `main.ps1:14-19` is the reason:

```powershell
# Store every named control in $sync so functions can reach it by name.
# SelectNodes("//*[@Name]") matches the plain `Name="..."` attribute — panels must
# use `Name`, never the `x:Name` alias, or the control will not be registered here.
([xml]$inputXML).SelectNodes("//*[@Name]") | ForEach-Object {
    $sync[$_.Name] = $sync.window.FindName($_.Name)
}
```

A control with `x:Name` is invisible to both this loop and the button-wiring loop at
`:104`. RESEARCH §9 V5 asserts no `x:Name="BtnStage` exists.

**2. Buttons get a `Style="{StaticResource Btn...}"`.** The two existing variants, from
`00-Home.xaml:89-90` and `02-Progress.xaml:58-59`:

```xml
                <Button Name="BtnInstall" Content="Install AkariOS" Style="{StaticResource BtnAccent}"
                        HorizontalAlignment="Left" IsEnabled="False"/>
```

```xml
                <Button Name="BtnCancel" Content="Cancel Install" Style="{StaticResource Btn}"
                        HorizontalAlignment="Left" IsEnabled="False"/>
```

`BtnAccent` is reserved for the single primary CTA. Three stage buttons are secondary —
use `Btn`.

**3. `IsEnabled="False"` as the declared default.** Both existing buttons ship disabled
and are enabled in code (`main.ps1:188` calls `Set-InstallButtonEnabled -Enabled $false`;
`main.ps1:185` calls `Sync-CancelButton`). Per-stage buttons are a testing/debug
affordance and should not be live on launch.

**4. No `Click=` attribute.** There is no event-handler attribute anywhere in these
panels — wiring is entirely by the name convention below. `STACK.md`'s "What NOT to Use"
table lists `Click="..."` under the XamlReader.Parse failure causes.

**Where to insert.** The stage roadmap card at `02-Progress.xaml:37-47` is the natural
home; the `StackPanel` closes at `:62`, so a new `<Border Style="{StaticResource Card}">`
goes before the danger card at `:49`. `Stage1Headline`..`Stage3Headline` (`:40-45`) are
seeded from `Get-StageExplanation` at `main.ps1:131-135`, so the new buttons sit beside
the copy they act on:

```xml
                <TextBlock Name="Stage1Headline" Style="{StaticResource CardDesc}" Margin="0,8,0,0"
                           TextWrapping="Wrap" Text="Stage 1: Downloads required payloads, configures boot settings, and reboots into Safe Mode."/>
```

**The error-detail text block.** RESEARCH §6 puts the DIAG-02 error UI here too. The
danger-card pattern is `02-Progress.xaml:49-61`, and the closest existing precedent for
an error detail block is `03-State.xaml:32-38`:

```xml
        <!-- Inconsistent-state card, hidden until detection fails (D-05) -->
        <Border Name="StateInconsistent" Style="{StaticResource CardDanger}" Visibility="Collapsed">
            <StackPanel>
                <TextBlock Text="&#9888;  INCONSISTENT STATE" Style="{StaticResource CardGroupHeader}" Foreground="#FF6B6B"/>
                <TextBlock Style="{StaticResource CardDesc}" Margin="0"
                           Text="The installation is in an inconsistent state. Please try again. If the problem persists, check the log at %ProgramData%\AkariOS\install.log."/>
            </StackPanel>
        </Border>
```

`CardDanger` + `Visibility="Collapsed"` + a `Name` on the `Border` is exactly the shape
`Show-StageError` needs, and it mirrors how `main.ps1:172` reveals `StateInconsistent`:

```powershell
            if ($sync.StateInconsistent)  { $sync.StateInconsistent.Visibility = [System.Windows.Visibility]::Visible }
```

Note the error-detail block needs `TextWrapping="Wrap"` and, for a log excerpt, vertical
scrolling — no existing block scrolls, so a `ScrollViewer MaxHeight` or
`TextBlock TextTrimming` is new. Keep the excerpt bounded via `Get-AkariOSLogTail -Count`
rather than letting the panel grow.

**Alternative rejected:** a new `xaml/panels/04-*.xaml`. It would require a `NavXyz`
RadioButton in `MainWindow.xaml` **and** three entries in `$panels`/`$navMap`/`$navNames`
at `main.ps1:64-75`, or `Show-Panel` silently no-ops — see `main.ps1:80`:

```powershell
function Show-Panel {
    param([string]$PanelName)
    if (-not $PanelName -or -not $sync[$PanelName]) { return }
```

RESEARCH §5 Decision 9's reasoning ("reusing the progress panel keeps `Set-CurrentStage`
as the single renderer") applies.

---

## 9. `AkariOS/scripts/main.ps1` — **edit**

### 9a. Button handlers must exist as `Invoke-BtnStage<N>`

The wiring loop, verbatim `main.ps1:101-114`:

```powershell
# ── Wire all buttons to their Invoke-* functions ─────────────────────────────
# Convention: a Button named BtnInstall is handled by Invoke-BtnInstall in
# functions/public/. Keep button Name and function name in sync.
$sync.Keys | Where-Object { $_ -like "Btn*" } | ForEach-Object {
    $btnName = $_
    if ($sync[$btnName] -and $sync[$btnName].GetType().Name -eq "Button") {
        $sync[$btnName].Add_Click({
            $fn = "Invoke-$($btnName)"
            if (Get-Command $fn -ErrorAction SilentlyContinue) {
                & $fn
            }
        }.GetNewClosure())
    }
}
```

`BtnStage1` → `Invoke-BtnStage1`, `BtnStage2` → `Invoke-BtnStage2`,
`BtnStage3` → `Invoke-BtnStage3`. RESEARCH §3.1 is blunt that a missing handler is
**silently dead** because of `-ErrorAction SilentlyContinue` at `:109` — and that this exact
bug shipped once in Phase 1 (the Install CTA). §9 V5 greps for each handler by name.

**Handler placement.** RESEARCH §6 says main.ps1, but Phase 1's convention is that
`Invoke-Btn*` lives in `functions/public/` — `Invoke-BtnInstall` is in `Confirm.ps1:209`,
`Invoke-BtnResume` in `Resume.ps1:168`, `Invoke-BtnRunChecks` in `Check.ps1:407`. Because
`Compile.ps1:48-49` concatenates all of `functions/public/*.ps1` before `main.ps1:82`, the
handlers resolve either way. Putting them in `functions/public/Stage.ps1` or
`Diagnostics.ps1` matches the house convention and keeps `main.ps1` edits to the
launch-time block.

**Handler body shape** — copy `Check.ps1:407-431`, which is the only existing
`Invoke-Btn*` that dispatches to the background runner:

```powershell
function Invoke-BtnRunChecks {
    if (-not (Get-Command Invoke-RunInBackground -ErrorAction SilentlyContinue)) {
        [System.Windows.MessageBox]::Show("Background runner unavailable.", "AkariOS Setup") | Out-Null
        return
    }
    if ($sync.BtnRunChecks) { $sync.BtnRunChecks.IsEnabled = $false }

    Invoke-RunInBackground -StatusStart "Running pre-flight checks..." -StatusDone "Pre-flight checks complete" -ScriptBlock {
        $result = Invoke-PreFlightChecks
        $sync.window.Dispatcher.Invoke([action]{
            Show-CheckResult -Results $result.Results -Summary $result.Summary
            if ($result.CanInstall) {
                Set-InstallButtonEnabled -Enabled $true
            } else {
                $first = @($result.BlockingFails)[0]
                Set-InstallButtonEnabled -Enabled $false -Hint ("Blocked by: " + $first.Name + " — " + $first.Message)
            }
            if ($sync.BtnRunChecks) { $sync.BtnRunChecks.IsEnabled = $true }
        }, "Normal")
    }
}
```

Both halves matter: the `Get-Command` guard (mirroring `:413-416`) and the re-enable on
completion. Per-stage handlers additionally need the pre-flight confirmation gate — they
drive the same destructive engine, so `Show-ConfirmationGate` gates them exactly as
`Confirm.ps1:227` gates the main CTA.

### 9b. The launch-time failure check

Insert as a **new numbered step** alongside the existing five at `main.ps1:116-188`,
inside the `try`/`catch` shape used by step 3 (`:141-182`). That block is the established
home for launch integration, and its comment states the rule Phase 2 inherits:

```powershell
# 3. Resume detection on launch (PROG-02). Get-ResumePoint reads the bcdedit
#    safeboot flag and the RunOnce entries; state.json only corroborates.
#    Failures here must not stop the app - the user can still start fresh.
try {
```

`Get-AkariOSStageFailure` goes after that block (or after step 4), and must be wrapped in
the same protective `try`/`catch` — RESEARCH §9 V1 requires the compiled script to parse,
and a throw during launch would break `ShowDialog()` at `:191`.

**Do not modify the `switch` at `:151-178`.** RESEARCH §5 Decision 6 is explicit: it has
no error branch and Phase 2 does not add one, so D-03/D-05 verified behaviour is
untouched. The `"inconsistent"` branch already shows the house error idiom
(`:169-177`):

```powershell
        "inconsistent" {
            # D-05: no CTA, the user must resolve it manually.
            if ($sync.StateHeadline)      { $sync.StateHeadline.Text = "Inconsistent state detected" }
            if ($sync.StateInconsistent)  { $sync.StateInconsistent.Visibility = [System.Windows.Visibility]::Visible }
            if ($sync.BtnResume)          { $sync.BtnResume.Visibility = [System.Windows.Visibility]::Collapsed }
            Set-Status "Inconsistent installation state - see the State page." "#FF6B6B"
            Write-AkariOSLog -Level ERROR -Message ("Inconsistent state: " + $resume.Reason)
            Show-Panel "PanelState"
        }
```

`Set-Status` + `Write-AkariOSLog -Level ERROR` + `Show-Panel` is the exact three-step
recipe for surfacing a problem. Reuse it verbatim in the new failure block.

### 9c. Asset logging already exists

`main.ps1:119-128` already logs the asset inventory, so a missing `.reg` asset is visible
in `install.log` on the next launch without any Phase 2 code:

```powershell
try {
    $assetNames = @()
    if ($sync.assets) { $assetNames = @($sync.assets.Keys) }
    Initialize-AkariOSLog -Banner @(
        ("State file: " + $script:AkariOSStateDefaultPath),
        ("Assets embedded: " + ($assetNames -join ", "))
    )
} catch {
    # Logging must never block startup.
}
```

Phase 2 should add an assertion here that all four engine assets are present — it is the
cheapest possible guard against Finding 6, and it lands in the log the user can read off
the VM.

---

## 10. Files that must NOT be edited

| Path | Why |
|------|-----|
| `WinSux-main/WinSux/winsux.ps1` | Engine, read-only. D-06. |
| `WinSux-main/WinSux/stepone.ps1` | Engine, read-only. D-06. |
| `WinSux-main/WinSux/steptwo.ps1` | Engine, read-only. D-06. Including the `HKLM:` typo at `:332`. |
| `WinSux-main/WinSux/reg.reg` | Engine, read-only. D-06. |
| `AkariOS/functions/public/Resume.ps1` | §5 Decision 8: reuse `$script:AkariOSStage2Entry` / `AkariOSStage3Entry` verbatim; §7 Decision 3 keeps `Get-ResumePoint` byte-identical. Detection matches substrings at `:83-84` — a parallel constant silently stops it matching. |
| `AkariOS/functions/public/Confirm.ps1` | §6 "no edit needed". The `Get-Command Start-AkariOSInstall` branch at `:233` starts working on its own. |
| `AkariOS/scripts/start.ps1` | `$sync` at `:88-99` needs no new key; `Compile.ps1:55` creates `assets`. |

**New symbols vs. existing symbols** — the collision check, since a duplicate definition
in the compiled single file is a parse-time error:

| Symbol | Status |
|--------|--------|
| `Get-AkariOSStage` | **already defined** — `Stage.ps1:40-48`. Do not redefine; `Progress.ps1:52` calls it. |
| `Get-StageExplanation` | **already defined** — `Stage.ps1:50-85`. Do not redefine; `main.ps1:132` calls it. |
| `$script:AkariOSStages` | **already defined** — `Stage.ps1:6-38`. |
| `Get-AkariOSRunOnceEntries` | **already defined** — `Resume.ps1:56-93`. Do not redefine; `Resume.ps1:117` calls it. |
| `Get-BcdSafebootState` | **already defined** — `Resume.ps1:28-54`. Read-only wrapper; reuse, extend with setters. |
| `Get-AkariOSLogTail` | **already defined** — `Logging.ps1:105-121`. Its docstring already names error reporting as a consumer. |
| `Get-AkariOSState` / `Set-AkariOSState` | **already defined** — `State.ps1:66` / `:93`. Atomic; the error record goes through them. |
| `Set-CurrentStage` / `Update-ProgressDisplay` | **already defined** — `Progress.ps1:127` / `:58`. Stage integration drives these; it does not rebuild them. |
| `Set-InstallButtonEnabled` / `Sync-CancelButton` | **already defined** — `Check.ps1:~395` / `Cancel.ps1`. |
| `Get-AkariOSRunOnceCommand` | **new** — pure string builder. |
| `Set-AkariOSRunOnceEntry` | **new** — wraps `reg add`, injectable `-RunOnceWriter`. |
| `Set-BcdSafebootValue` / `Clear-BcdSafebootValue` | **new** — wrap `bcdedit /set` and `/deletevalue`, injectable `-BcdWriter`. |
| `Invoke-AkariOSEngine` | **new** — child-process launch, injectable `-EngineInvoker`. |
| `Expand-AkariOSEngineAsset` | **new** — decode to disk. |
| `Start-AkariOSInstall` | **new** — the FLOW-01 contract name. |
| `Get-AkariOSStageFailure` / `Show-StageError` / `Resolve-StageFailure` | **new** — DIAG-02. |
| `Invoke-BtnStage1` / `2` / `3` | **new** — FLOW-02, must exist or the buttons are dead. |

**Exact strings that must not drift** (RESEARCH §9 V6 asserts these):

```
powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1
powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\steptwo.ps1
*!stepone
!steptwo
```

from `WinSux-main/WinSux/winsux.ps1:222` and `:225`, already mirrored at
`Resume.ps1:25-26`. Plus `cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"`
(`winsux.ps1:228`) and `bcdedit /deletevalue {current} safeboot` (`stepone.ps1:148`).

---

## 11. Two Phase 1 defects Phase 2 inherits

Found while reading the analogs. Neither is Phase 2 scope to *fix*, but both land
directly on the Phase 2 critical path, so an executor must not be surprised by them.

**1. The `Fields` parameter set silently drops unknown properties** (`State.ps1:120-133`).
A `LastError` block written onto the state object is erased by the next
`Set-AkariOSState -Fields` call, and `Progress.ps1:101` makes such a call on every
progress update. DIAG-02 needs the one-line fix described in §7c. See §5 for the
companion bug.

**2. `Progress.ps1:101` passes `-Status "installing"`**, which is not in the
`ValidateSet` at `State.ps1:111` (`pending`, `running`, `completed`, `error`). The call
throws and is swallowed by the `catch` at `:102-104`, so within-stage progress is **not
currently persisted to `state.json`** despite the file comment at `State.ps1:2-3`
claiming it is. Phase 2's runner should therefore not rely on `state.json` for live
progress — write through the `-State` object set explicitly, and log the true stage
number via `Write-AkariOSLog`.

---

*Phase 2 patterns written 2026-10-04. Read-only inspection: no AkariOS code executed, no
`bcdedit`, no registry write, no `shutdown`, nothing written to `C:\ProgramData\AkariOS`.
Engine files were read as references only and are never proposed for editing.*