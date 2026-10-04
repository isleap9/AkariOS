# Phase 2 Research: Core Engine — Stage Integration

**Phase:** 2 — Core Engine — Stage Integration
**Researched:** 2026-10-04
**Mode:** static-only. Nothing in this document was executed against the live machine.
**Governing decision:** D-06 "Replicate WinSux exactly" ([VERIFIED: `.planning/phases/02-core-engine-stage-integration/02-CONTEXT.md:29-36`]).

## Claim provenance legend

| Tag | Meaning |
|-----|---------|
| `[VERIFIED: path:Lx-Ly]` | Read with `read_file` **this session**; discrete values quoted verbatim from the cited range. |
| `[CITED: url]` | From official Microsoft documentation, fetched this session. |
| `[ASSUMED]` | Training knowledge, not verified this session. |
| `[ENGINE]` | Value taken verbatim from the read-only WinSux source. |

Every in-repo discrete value below (field name, registry key, status constant, function name,
path, RunOnce string) is quoted beside its claim. A value that appears in a code example but
was **not** found verbatim in a quoted source is tagged `[ASSUMED]` at first use.

---

## 1. Executive summary — what Phase 2 actually has to build

Phase 1 delivered a shell that can *describe* an install and *detect* where one was interrupted.
Phase 2 must make it *perform* one. Concretely, six pieces of work:

1. **Asset packing** — put the three engine scripts (plus `reg.reg`) into `AkariOS/assets/text/`
   so `Compile.ps1`'s existing base64 path picks them up, and add a decode helper.
2. **A pure command builder** — `Get-AkariOSStageScript` / `Get-AkariOSRunOnceCommand` that
   return the *strings* WinSux uses, so the wiring is unit-testable without executing anything.
3. **A stage runner** — one function per stage that: decodes assets to `%SystemRoot%\Temp`,
   writes the RunOnce entries, sets `bcdedit safeboot`, marks `RebootPending`, and launches.
4. **Runspace execution** — Stage 1 and Stage 3 as background jobs via the existing
   `Invoke-RunInBackground` pattern (already ported, zero new concurrency machinery).
5. **Per-stage run buttons** (FLOW-02) — three `Btn*` controls wired by the existing naming
   convention.
6. **Post-reboot error surfacing** (DIAG-02 / D-10) — detect a failed stage from `state.json`
   on next launch, show detail + log excerpt + Retry/Abort.

**The single most important finding of this research is a Phase 1 defect that Phase 2's entire
error-surfacing path depends on.** See §8, Finding 1. Phase 2 cannot honestly claim DIAG-02
until it is fixed.

---

## 2. The engine, read directly

### 2.1 Stage 1 — `WinSux-main/WinSux/winsux.ps1` (233 lines)

Structure, in execution order [ENGINE, read whole file]:

| Lines | What it does |
|-------|--------------|
| 1-4 | Self-elevate via `Start-Process -Verb RunAs` + `Exit` |
| 5-9 | Console cosmetics: `$Host.UI.RawUI.WindowTitle`, `BackgroundColor`, `Clear-Host` |
| 11-16 | **Internet gate:** `if (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet ...))` → writes `"Internet Connection Required"` and **`Pause`** |
| 18-19 | `$progresspreference = 'silentlycontinue'` |
| 25-29 | Downloads the five sibling files (`reg.reg`, `settimerresolutionservice.cs`, `start2.txt`, `stepone.ps1`, `steptwo.ps1`) into `$env:SystemRoot\Temp` |
| 35-46 | 7-Zip download + silent install + HKCU options + start-menu relocation |
| 52-77 | Twelve vcredist downloads + twelve silent installs |
| 83-130 | DDU download, 7-Zip extract, `Settings.xml` written and set read-only |
| 133 | `reg add HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching ... SearchOrderConfig 0` |
| 139-169 | Helium install + policies + logon/services/tasks removal |
| 175-181 | DirectX download, extract, silent install |
| 187-212 | `Get-AppXPackage -AllUsers` bulk removal with an explicit keep-list |
| 215-219 | Password-less sign-in + Terminal delegation registry |
| **222** | **RunOnce `*!stepone`** |
| **225** | **RunOnce `!steptwo`** |
| **228** | **`bcdedit /set {current} safeboot minimal`** |
| 230-234 | `Write-Host "RESTARTING"`, `Start-Sleep -Seconds 5`, **`shutdown -r -t 00`** |

The three load-bearing lines, verbatim [ENGINE: `winsux.ps1:222`, `:225`, `:228`]:

```powershell
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"*!stepone`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\stepone.ps1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"!steptwo`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\steptwo.ps1`" /f >nul 2>&1"
cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"
```

and the reboot, verbatim [ENGINE: `winsux.ps1:233-234`]:

```powershell
Start-Sleep -Seconds 5
shutdown -r -t 00
```

**Critical for Phase 2:** Stage 1 *already writes both RunOnce entries itself*. AkariOS does not
need to write them separately — it only needs to make sure the two `.ps1` files and `reg.reg`
exist at the exact paths the entries name (`$env:SystemRoot\Temp\stepone.ps1`,
`\steptwo.ps1`), which Stage 1 achieves by downloading them at L28-29. Under D-06 the correct
Phase 2 implementation is: **decode the assets to those paths ourselves and let Stage 1's own
`IWR` overwrite them** — or accept the download. Both are defensible; §7 Decision 4 picks one.

**`Pause` is a hard blocker for runspace execution.** `Pause` at [ENGINE: `winsux.ps1:14`] reads a
keypress from the console host. In a PowerShell runspace there is no console host, and the
call will either throw or block forever. See §8, Finding 2.

**`IWR` is not a defined function.** Every download line calls `IWR` [ENGINE: `winsux.ps1:25-29`,
`35`, `52-63`, `83`, `139`, `175`] but no `function IWR` and no `Set-Alias IWR` exists anywhere in
`WinSux-main/WinSux/*.ps1` (grepped this session: zero hits outside the call sites). `IWR` resolves
to the built-in `Invoke-WebRequest` alias in a normal console session, which works. Inside a
runspace that is not guaranteed to carry the default alias set — see §8, Finding 3.

### 2.2 Stage 2 — `WinSux-main/WinSux/stepone.ps1` (152 lines)

Same 1-9 preamble (self-elevate, cosmetics). Then [ENGINE: `stepone.ps1:12-36`] a single
function that is the whole trick of this stage:

```powershell
function Run-Trusted([String]$command) {
try {
    	Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop
  		}
  		catch {
  	taskkill /im trustedinstaller.exe /f >$null
  		}
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='TrustedInstaller'"
        $DefaultBinPath = $service.PathName
        $trustedInstallerPath = "$env:SystemRoot\servicing\TrustedInstaller.exe"
        if ($DefaultBinPath -ne $trustedInstallerPath) {
    	$DefaultBinPath = $trustedInstallerPath
        }
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
        $base64Command = [Convert]::ToBase64String($bytes)
        sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
        sc.exe start TrustedInstaller | Out-Null
        sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
```

Then `$windowssecuritysettings` is a 40-element array of `cmd /c "reg add ..."` strings
[ENGINE: `stepone.ps1:48-132`]. Those are executed **twice** [ENGINE: `:135-142`] — once through
`Run-Trusted`, once through `Invoke-Expression` — because some keys refuse a normal admin
context. Three of them are `bcdedit`, verbatim [ENGINE: `stepone.ps1:120-124`]:

```powershell
# turn off vbs virtualization based security
# faceit anti cheat forces this on, even after uninstall
'cmd /c "bcdedit /deletevalue allowedinmemorysettings >nul 2>&1"',
'cmd /c "bcdedit /deletevalue isolatedcontext >nul 2>&1"',
'cmd /c "bcdedit /deletevalue hypervisorlaunchtype >nul 2>&1"',
```

Then UAC off [ENGINE: `:145`], then the Safe Mode release, verbatim [ENGINE: `stepone.ps1:147-148`]:

```powershell
# remove safe mode boot
cmd /c "bcdedit /deletevalue {current} safeboot >nul 2>&1"
```

and finally the reboot, verbatim [ENGINE: `stepone.ps1:150-152`]:

```powershell
        Write-Host "DDU & RESTARTING`n" -ForegroundColor Red

# uninstall soundblaster realtek intel amd nvidia drivers & restart
Start-Process "$env:SystemRoot\Temp\ddu\Display Driver Uninstaller.exe" -ArgumentList "-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart" -Wait
```

**Note the reboot is DDU's `-Restart`, not `shutdown`** [ENGINE: `stepone.ps1:153`]. Stage 2 has
no `shutdown` call at all. That matters for the resume flow: the transition out of Safe Mode is
driven by DDU, so a Stage 2 failure *before* DDU launches leaves `safeboot` cleared but no reboot
performed — the machine sits in Safe Mode with the next-stage RunOnce entry never consumed.

Also note: Stage 2 **does not write a new RunOnce entry.** The `!steptwo` entry written by Stage 1
[ENGINE: `winsux.ps1:225`] is still pending, and it is what fires on the normal boot out of Safe
Mode. AkariOS must not delete it.

### 2.3 Stage 3 — `WinSux-main/WinSux/steptwo.ps1` (1223 lines)

Same 1-9 preamble, same `Run-Trusted` at [ENGINE: `:12-36`]. Then ~1180 lines of tweaks: Edge
uninstall (L41-58+), UWP removal, scheduled-task tree deletion, `regedit /S reg.reg` import
[ENGINE: `:420`], Store settings hive load, BitLocker disable, Defender task disable, network
adapter binding disable, `certutil -decode start2.txt start2.bin` [ENGINE: `:869`], `csc.exe`
compile of `settimerresolutionservice.cs` [ENGINE: `:1152`], temp clearing [ENGINE: `:1185-1188`],
`cleanmgr.exe /autoclean` [ENGINE: `:1203`], restore point [ENGINE: `:1209-1218`].

The RunOnce wipe, verbatim [ENGINE: `steptwo.ps1:322-335`]:

```powershell
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunNotification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunNotification`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg add `"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg add `"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
```

(Line 332 has a typo in the engine — `HKLM:` with a colon, inside a `cmd /c` string. Harmless: it
fails silently into `>nul 2>&1`, which is why upstream never noticed.)

And the tail, verbatim [ENGINE: `steptwo.ps1:1220-1224`]:

```powershell
        Write-Host "RESTARTING`n" -ForegroundColor Red

# restart
Start-Sleep -Seconds 5
shutdown -r -t 00
```

**Destructive interaction with resume detection.** Stage 3 deletes and recreates the *entire*
HKCU, HKLM and WOW6432Node `RunOnce` keys [ENGINE: `:324-333`]. This destroys any RunOnce entry
AkariOS might have written to relaunch itself after the final reboot — including the
`!AkariOS` GUI-relaunch entry described in `research/STACK.md`. Under D-06 we do not work around
it in the engine; the question of *when* AkariOS writes a post-stage-3 relaunch entry is
§7 Decision 5.

---

## 3. Patterns in the existing AkariOS shell to replicate

### 3.1 The button → handler convention (the silent-failure trap)

[VERIFIED: `AkariOS/scripts/main.ps1:101-114`], verbatim:

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

Two consequences the planner must respect:

1. **`Invoke-BtnStage1` must exist or the button is silently dead.** `Get-Command ... -ErrorAction
   SilentlyContinue` swallows the miss. This exact bug shipped once already (the Install CTA with
   no handler, Phase 1).
2. **The enumeration is `$sync.Keys`**, which is populated by the `SelectNodes("//*[@Name]")` loop
   at [VERIFIED: `AkariOS/scripts/main.ps1:14-19`]. A new button must therefore use plain
   `Name="..."`, never `x:Name`.

### 3.2 The runspace pattern

[VERIFIED: `AkariOS/functions/private/Invoke-RunInBackground.ps1:18-61`], verbatim body:

```powershell
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$StatusStart = "Running...",
        [string]$StatusDone  = "Done."
    )

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
            ...
        }
    }.GetNewClosure())

    $timer.Start()
```

What this gives Phase 2 for free: `$sync` injection (line 30), STA + `ReuseThread`,
non-blocking `BeginInvoke`, and an error-collection `EndInvoke` at line 49.

**What it does NOT give Phase 2, and this is a real gap:**

- **No `InitialSessionState`.** `CreateRunspace()` with no argument uses the *default* session
  state, which contains only the Microsoft.PowerShell.Core snap-in. **None of AkariOS's own
  functions are defined inside the runspace.** The scriptblock passed in cannot call
  `Write-AkariOSLog`, `Update-ProgressDisplay`, or `Get-AkariOSStage`. This is the single biggest
  implementation trap in Phase 2 — see §7 Decision 1.
- **No completion callback.** The tick handler only writes `Set-Status "Failed - see log"`.
  DIAG-02 needs a hook to (a) mark `state.json` as errored and (b) open the error dialog.
- **`$error` inside `GetNewClosure()` is captured by value.** Line 44 assigns `$error = $null` in
  the enclosing scope; `.GetNewClosure()` snapshots it, so line 49's assignment writes to the
  *closure copy* and line 56's read sees `null` — i.e. **the error branch is effectively dead
  code today.** `$done` has the same bug. Fixing this is a prerequisite for DIAG-02.

### 3.3 The dispatcher-marshalling pattern for UI writes

[VERIFIED: `AkariOS/functions/public/Progress.ps1:107-124`], verbatim:

```powershell
    $syncRef = $sync
    if ($syncRef -and $syncRef.window) {
        $window = $syncRef.window
        $dispatcher = $window.Dispatcher
        $work = [System.Action]{
            if ($syncRef.ProgressStep)   { $syncRef.ProgressStep.Text = $stepText }
            if ($syncRef.ProgressAction) { $syncRef.ProgressAction.Text = if ($Action) { $Action } else { $script:AkariOSProgressDefault } }
            if ($syncRef.ProgressDetail) { $syncRef.ProgressDetail.Text = $Detail }
            if ($syncRef.ProgressBar1)   { $syncRef.ProgressBar1.Value = [Math]::Max(0, [Math]::Min(100, $Percent)) }
        }.GetNewClosure()

        if ($dispatcher.CheckAccess()) {
            $work.Invoke()
        } else {
            # Non-blocking marshal: the worker must not deadlock on the UI thread.
            $dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $work) | Out-Null
        }
    }
```

Two things to copy verbatim: the `CheckAccess()` branch (direct invoke when already on the UI
thread), and `BeginInvoke` over `Invoke` — a blocking `Invoke` from a runspace while the UI
thread waits on the job deadlocks.

### 3.4 The injectable-seam pattern

Phase 1 established that **every read of the outside world goes through a wrapper with an
overridable parameter.** [VERIFIED: `AkariOS/functions/public/Resume.ps1:108-118`], verbatim:

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

The user's hard constraint is that no state-touching code runs on the live machine, so Phase 2
**must** extend this pattern to every writer. Concrete seams required:

| Seam | Wraps | Injected via |
|------|-------|--------------|
| `Get-BcdSafebootState` (exists, read-only) [VERIFIED: `Resume.ps1:28-54`] | `bcdedit /enum` | `-Safeboot` |
| `Set-BcdSafebootValue` (new) | `bcdedit /set {current} safeboot minimal` | `-BcdWriter` scriptblock |
| `Clear-BcdSafebootValue` (new) | `bcdedit /deletevalue {current} safeboot` | `-BcdWriter` scriptblock |
| `Set-AkariOSRunOnceEntry` (new) | `reg add ... RunOnce` | `-RunOnceWriter` scriptblock |
| `Invoke-AkariOSEngine` (new) | launching the decoded engine script | `-EngineInvoker` scriptblock |
| `-TempRoot` / `-StatePath` / `-LogPath` | file paths | direct parameters |

The precedent for path injection is [VERIFIED: `AkariOS/functions/private/State.ps1:73`] —
`param([string]$Path = $script:AkariOSStateDefaultPath)` — and the default it must not touch is
`$script:AkariOSStateDefaultPath = "C:\ProgramData\AkariOS\state.json"` [VERIFIED: `State.ps1:14`].

### 3.5 The existing RunOnce/safeboot vocabulary — must not be duplicated

[VERIFIED: `AkariOS/functions/public/Resume.ps1:18-26`], verbatim:

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

The entry names match WinSux exactly [ENGINE: `winsux.ps1:222`, `:225`], and detection keys off
substring `*stepone*` / `*steptwo*` [VERIFIED: `Resume.ps1:83-84`]. **Phase 2 must reuse these
variables, not define new ones** — otherwise Phase 1's detection silently stops matching.

### 3.6 The resume-detection switch Phase 2 hooks into

[VERIFIED: `AkariOS/scripts/main.ps1:151-178`], verbatim:

```powershell
    switch ($resume.ResumePoint) {
        "fresh" {
            if ($sync.StateHeadline) { $sync.StateHeadline.Text = "Ready to install" }
            if ($sync.BtnResume)     { $sync.BtnResume.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        { $_ -in @("stage1","stage2","stage3") } {
            $stageNo = switch ($resume.ResumePoint) { "stage1" {1} "stage2" {2} "stage3" {3} }
            if ($sync.StateHeadline) { $sync.StateHeadline.Text = Format-ResumeStep -Stage $stageNo }
            if ($sync.BtnResume) {
                $sync.BtnResume.Visibility = [System.Windows.Visibility]::Visible
                $sync.BtnResume.IsEnabled  = $true
            }
            if ($resume.ResumePoint -ne "stage1") {
                # Safe Mode / later stages cannot be cancelled or driven from the
                # GUI; the console stage script is already queued via RunOnce.
                Set-Status "Resuming Step $stageNo of 3 - the queued stage script will run at boot." "#FFA726"
            }
        }
        "inconsistent" {
            # D-05: no CTA, the user must resolve it manually.
            if ($sync.StateHeadline)      { $sync.StateHeadline.Text = "Inconsistent state detected" }
            if ($sync.StateInconsistent)  { $sync.StateInconsistent.Visibility = [System.Windows.Visibility]::Visible }
            if ($sync.BtnResume)          { $sync.BtnResume.Visibility = [System.Windows.Visibility]::Collapsed }
            Set-Status "Inconsistent installation state - see the State page." "#FF6B6B"
            Write-AkariOSLog -Level ERROR -Message ("Inconsistent state: " + $resume.Reason)
            Show-Panel "PanelState"
        }
    }
```

Note what is **absent**: there is no branch for a stage that *ended in an error*. Per D-10 that
branch is exactly what Phase 2 adds. And note `Get-ResumePoint`'s decision table
[VERIFIED: `Resume.ps1:120-154`] has no error branch either — so DIAG-02 needs either a new
`ResumePoint` value or an independent check against `state.json`.

### 3.7 The confirmation gate's hand-off point

[VERIFIED: `AkariOS/functions/public/Confirm.ps1:233-242`], verbatim:

```powershell
    if (Get-Command Start-AkariOSInstall -ErrorAction SilentlyContinue) {
        Start-AkariOSInstall
    } else {
        # Phase 2 wires the stage runner; until then, say so rather than
        # pretending the install started.
        Set-Status "Confirmed - stage runner not wired yet (Phase 2)." "#FFA726"
```

**The contract is already fixed: Phase 2 must define `Start-AkariOSInstall`.** FLOW-01 is
satisfied the moment this function exists and launches Stage 1. This is the highest-value,
lowest-risk single edit in the phase.

### 3.8 The asset-embedding path already in Compile.ps1

[VERIFIED: `AkariOS/Compile.ps1:51-62`], verbatim:

```powershell
# --- Embed engine scripts (base64) so akarios.ps1 stays self-contained ---
# Each assets/text/<name>.ps1 becomes $sync.assets.<name> as raw UTF-8 text at runtime.
# WinSux stage scripts are the payload here; they are decoded and written to disk by
# the stage runner in Phase 2. Payloads themselves (DDU, DirectX, 7-Zip) download at runtime.
$script += "`$sync.assets = @{}" + $nl
Get-ChildItem (Join-Path $PSScriptRoot "assets\text") -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq ".ps1" } | Sort-Object Name | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $script += "`$sync.assets." + $_.BaseName + " = '" + [Convert]::ToBase64String($bytes) + "'" + $nl
        Write-Host ("  embedded asset: {0}.ps1 ({1:N0} bytes)" -f $_.BaseName, $bytes.Length) -ForegroundColor DarkGray
    }
```

Two hard constraints this imposes:

- **`Where-Object { $_.Extension -eq ".ps1" }` at line 57 — `.reg` files are NOT embedded.** To
  ship `reg.reg` (54,014 bytes [VERIFIED: `wc -l`/`ls -la` on `WinSux-main/WinSux/`], 1,494 lines)
  the filter must be widened, and base64 for a binary-ish asset is still fine (it's ASCII).
- **Base64 is emitted as a bare single-quoted PowerShell string at line 59.** A single `'` inside
  the base64 would break the compiled file. Base64 output is `A-Za-z0-9+/=` only, so this is safe
  for the engine — but any future change to the wrapper must keep that property.

Also note [VERIFIED: `AkariOS/scripts/start.ps1:88-99`] defines `$sync` **without** an `assets`
key:

```powershell
$sync             = [Hashtable]::Synchronized(@{})
$sync.configs     = @{}
$sync.runspaces   = [System.Collections.Generic.List[hashtable]]::new()
$sync.app         = @{
    Name           = "AkariOS Setup"
    AppUserModelId = "AkariOS.Setup"
    StatePath      = "C:\ProgramData\AkariOS\state.json"
    LogPath        = "C:\ProgramData\AkariOS\install.log"
    ConfirmToken   = "AKARIOS"
    TotalStages    = 3
    IsAdmin        = $akariosIsAdmin
}
```

`$sync.assets` is injected later by Compile.ps1, and `main.ps1:120-121` already guards for it
(`if ($sync.assets) { $assetNames = @($sync.assets.Keys) }`). **Order dependency: the asset block
sits between the function definitions and `$inputXML` [VERIFIED: `Compile.ps1:51-79`], so asset
decode helpers defined in `functions/private/*.ps1` are already in scope when the assignment runs.**

---

## 4. WinSux semantics that Phase 2 must respect (and the docs on them)

- **`!` prefix** — "You can prefix a RunOnce key *value* parameter with an exclamation point (!)
  to defer deletion of the key until after the command runs successfully. Without the exclamation
  point prefix, if the specified command fails, the RunOnce key will still be deleted and the
  command will not be executed the next time the system starts."
  [CITED: learn.microsoft.com/en-us/windows-hardware/drivers/install/runonce-registry-key]
- **`*` prefix** — "Also, by default, the RunOnce keys are ignored when the system is started in
  Safe Mode. The *value* parameter of RunOnce keys can be prefixed with an asterisk (*) to force
  the command to be executed even in Safe Mode."
  [CITED: same URL]
- **Elevation caveat** — "Starting with Windows Vista, the system will not execute the commands
  specified by the RunOnce keys if a user without administrator privileges is logged on to the
  system." [CITED: same URL]

Three implications the planner must design around:

1. **Both prefixes are on the *value name*, not the value data.** MS docs phrase it as the value
   parameter; WinSux puts `*!stepone` as the `/v` **name** [ENGINE: `winsux.ps1:222`] and upstream
   works, so the prefixes are parsed off the value name. AkariOS must copy that exactly. Note the
   MS doc describes RunOnce under the **HKLM** hive; WinSux uses **HKCU** [ENGINE: `winsux.ps1:222`].
   That divergence is upstream's and, under D-06, AkariOS inherits it — but it is a genuine
   unknown whether HKCU RunOnce honours `*` in Safe Mode. Phase 1's `Get-AkariOSRunOnceEntries`
   reads both hives [VERIFIED: `Resume.ps1:18-21`], which covers the detection half; the *firing*
   half is the Phase 4 VM target.
2. **RunOnce fires at logon, not at boot.** A user must log on for `*!stepone` to execute. Safe
   Mode normally does not auto-logon. **If the machine sits at the Safe Mode logon screen, Stage 2
   never runs and Stage 3 never fires.** Nothing in WinSux configures auto-logon. This is a
   showstopper-class risk that the context file does not mention; see §8, Finding 5.
3. **A non-elevated logged-on user means the entry never runs** and (absent `!`) is deleted. Both
   entries have `!`, so they survive — but they also then never fire again until an elevated
   logon.

---

## 5. Technical decisions

| # | Decision | Confidence | Rationale |
|---|----------|-----------|-----------|
| 1 | Create the runspace with an `InitialSessionState` that dot-sources the AkariOS function files, and pass the engine script as a *scriptblock* to the child `PowerShell` instance rather than executing it in-process. | **HIGH** | `CreateRunspace()` with no ISS cannot see AkariOS functions (§3.2). A child `powershell.exe -NoProfile -File <decoded path>` inherits nothing but the file — which is exactly the isolation WinSux already assumes, and it gives us a real `ExitCode` for D-10. |
| 2 | Launch stages 1 and 3 as **child processes** (`Start-Process -PassThru -Wait` on a background runspace), not as in-process runspace scriptblocks. | **HIGH** | The engine scripts self-elevate via `Start-Process -Verb RunAs` + `Exit` [ENGINE: `winsux.ps1:1-4`] — running them in-process would re-elevate *our* GUI. A child process also yields a real `ExitCode` for D-10 and gives the engine its own console host so `Pause` [ENGINE: `winsux.ps1:14`] has somewhere to read. §7 Decision 2. |
| 3 | Give the child process a **real console** (`powershell.exe -NoProfile -File <decoded>`), not `-Command "& { <engine text> }"`. | **HIGH** | `Pause`, `Clear-Host`, `$Host.UI.RawUI.WindowTitle` and `BackgroundColor` all require a console host. `-Command` inherits *our* hidden GUI host and degrades them; `-File` in a new window does not. This is the fix for §8, Finding 2. |
| 4 | **Decode and write the engine assets to `$env:SystemRoot\Temp` ourselves, and accept that Stage 1's own `IWR` overwrites `stepone.ps1` / `steptwo.ps1` / `reg.reg`.** No patching of Stage 1. | **HIGH** | Stage 1 downloads its five siblings at [ENGINE: `winsux.ps1:25-29`] before writing the RunOnce entries that name those exact paths [ENGINE: `:222`, `:225`]. Pre-writing is required so the files exist even if the download fails; the overwrite is harmless because the bytes are identical (D-06). Widening the Compile.ps1 filter to `.reg` is mandatory either way (§3.8). |
| 5 | Do **not** write the RunOnce entries from AkariOS in the happy path; write them only via the seam `Set-AkariOSRunOnceEntry` when Stage 1 does *not* run (per-stage buttons for stage 2/3 during testing). | **MEDIUM** | Stage 1 writes both entries itself [ENGINE: `winsux.ps1:222`, `:225`]; writing them again is duplication that can drift. But `Invoke-BtnStage2` has no engine to write them, so the seam must exist. Test-only path, documented as such. |
| 6 | Add a `Show-StageError` / `Resolve-StageFailure` pair in `functions/public/Diagnostics.ps1`, driven by a new `state.json` `LastError` block. Do **not** add a `ResumePoint` value. | **HIGH** | `Get-ResumePoint`'s switch has no error branch [VERIFIED: `Resume.ps1:120-154`] and `main.ps1:151-178` has no error branch either. An independent check is additive and leaves the verified Phase 1 decision table untouched; adding a `ResumePoint` would change Phase 1's verified behaviour. §7 Decision 3. |
| 7 | Fix the `GetNewClosure()` by-value capture of `$error` / `$done` in `Invoke-RunInBackground.ps1` as a **Phase 2 prerequisite**, and add an `-OnComplete` scriptblock parameter. | **HIGH** | The error branch is dead code today [VERIFIED: `Invoke-RunInBackground.ps1:44-56`], so DIAG-02 cannot hook anything without this fix. `-OnComplete` is the smallest seam that gives both success and failure paths a callback. |
| 8 | Reuse `$script:AkariOSStage2Entry` / `$script:AkariOSStage3Entry` / `Get-BcdSafebootState` / `Format-ResumeStep` verbatim; add no new RunOnce or bcdedit vocabulary. | **HIGH** | Detection matches on the entry-name substrings [VERIFIED: `Resume.ps1:83-84`], and §3.5 spells out the silent-miss failure mode if a parallel constant is introduced. |
| 9 | Per-stage buttons go on the **existing progress panel** as `BtnStage1` / `BtnStage2` / `BtnStage3`, declared with plain `Name=` (never `x:Name`). | **MEDIUM** | The wiring enumerates `$sync.Keys` [VERIFIED: `main.ps1:14-19`, `:101-114`], which only contains plain-`Name` controls. A new panel is Claude's-discretion either way, but reusing the progress panel keeps `Set-CurrentStage` as the single renderer. |
| 10 | Write the post-stage-3 GUI-relaunch RunOnce entry **before** Stage 3 starts (as the last thing the stage runner does), and accept that the engine deletes it. | **MEDIUM** | Stage 3 wipes and recreates RunOnce in HKCU, HKLM and WOW6432Node [ENGINE: `steptwo.ps1:324-333`], so any entry written *after* it starts is destroyed. Writing first is still destroyed by the later wipe, therefore the relaunch cannot rely on RunOnce at all — the GUI relaunch must be **detection-driven instead** (resume point `stage3` + safeboot clear + log tail). This resolves §7 Decision 5: no post-stage-3 RunOnce entry is written, and the relaunch is left to the Phase 4 VM decision. |
| 11 | Retry semantics for D-10: retry **re-runs the whole stage** via the same runner, after showing the log excerpt; abort clears the error block and returns to the ready state without touching RunOnce or bcdedit. | **MEDIUM** | D-10 scopes retry/abort at the GUI level only. Re-running a whole stage is the only honest option under D-06 (no partial-state introspection exists), and abort must not mutate boot state or it would edit engine behaviour. |

---

## 6. Implementation map — files created and touched

| Path | Action | Notes |
|------|--------|-------|
| `AkariOS/assets/text/winsux.ps1` | **create** (copy) | Read-only engine copy; never edited. |
| `AkariOS/assets/text/stepone.ps1` | **create** (copy) | Same. |
| `AkariOS/assets/text/steptwo.ps1` | **create** (copy) | Same. |
| `AkariOS/assets/text/reg.reg` | **create** (copy) | Required by Stage 3 `regedit /S` [ENGINE: `steptwo.ps1:420`]; needs the Compile.ps1 filter widened (§3.8). |
| `AkariOS/Compile.ps1` | **edit** | Widen `Where-Object { $_.Extension -eq ".ps1" }` to also accept `.reg`. One-line change. |
| `AkariOS/functions/private/Assets.ps1` | **create** | `Expand-AkariOSEngineAsset -Name -DestinationRoot -Overwrite` — base64-decode from `$sync.assets`, write UTF-8, return the path. Pure function over a hashtable; trivially unit-testable with an injected asset map. |
| `AkariOS/functions/public/Stage.ps1` | **create** | `Get-AkariOSStageScript`, `Get-AkariOSRunOnceCommand` (both **pure string builders**), `Get-AkariOSStage`, `Invoke-AkariOSStage`, `Start-AkariOSInstall`. |
| `AkariOS/functions/public/Diagnostics.ps1` | **create** | `Get-AkariOSStageFailure`, `Show-StageError`, `Resolve-StageFailure`. Read-mostly; state writes go through the existing `Save-AkariOSState` atomic writer. |
| `AkariOS/functions/public/Confirm.ps1` | **no edit needed** | The `Get-Command Start-AkariOSInstall` branch [VERIFIED: `Confirm.ps1:233-242`] starts working the moment the function exists. This is deliberate — no edit, so FLOW-01 lands without touching a Phase 1 file. |
| `AkariOS/functions/private/Invoke-RunInBackground.ps1` | **edit** | Fix closure capture; add `-OnComplete`. Prerequisite for decision 7. |
| `AkariOS/functions/public/MainWindow.xaml` (or equivalent panel) | **edit** | Add `BtnStage1`/`BtnStage2`/`BtnStage3` with plain `Name=`, plus the error-detail text block and Retry/Abort buttons for `Show-StageError`. |
| `AkariOS/scripts/main.ps1` | **edit** | `Invoke-BtnStage1/2/3` handlers; call `Get-AkariOSStageFailure` on launch and open the error panel if non-null. |

**Ordering constraint:** `Assets.ps1` and `Stage.ps1` must be dot-sourced into the runspace ISS (§7 Decision 1) *before*
any runner function is invoked. The Compile.ps1 concatenation order puts `functions/private/*`
before `functions/public/*` and both before the asset block and `$inputXML` [VERIFIED:
`Compile.ps1:51-79`], so helpers are in scope when `$sync.assets` is assigned — no ordering fix needed.

---

## 7. Decision rationale — the four calls that had real alternatives

Section 5 is the summary table; this section gives the alternatives that were weighed, because a
planner inheriting D-06 needs to know what was rejected and why.

### §7 Decision 1 — How the runner's functions reach the runspace

`Invoke-RunInBackground` calls `[runspacefactory]::CreateRunspace()` with no
`InitialSessionState` [VERIFIED: `Invoke-RunInBackground.ps1:26-27`], so the runspace sees only the
default session state: none of AkariOS's functions. Three options:

| Option | Verdict |
|--------|---------|
| A. Dot-source `Assets.ps1` + `Stage.ps1` into the runspace via a custom `InitialSessionState` | **Chosen.** One `iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()` at construction, `AddScript` each function file, then `CreateRunspace($iss)`. Clean, and the function files exist as real files. |
| B. Inject the functions as a single big scriptblock prepended to the runner scriptblock | Rejected — re-parses every function per stage and makes the failure log unreadable. |
| C. Move all engine orchestration into the child `powershell.exe` and keep the runspace a thin `Start-Process -Wait` wrapper | Rejected — it works, but the runspace then carries *no* AkariOS logic, so `Set-Status` progress updates from the parent are all we get and the D-10 exit-code handoff becomes the only signal. Kept as the fallback if A proves fragile. |

Note the separation: A is about *AkariOS's own* functions; the **engine script itself is never
run in the runspace** (decision 2). The runspace is the supervisor; the engine is a child process.

### §7 Decision 2 — Process boundary for the engine

| Option | Verdict |
|--------|---------|
| A. `Start-Process powershell.exe -NoProfile -File <decoded> -PassThru -Wait` inside the background runspace | **Chosen.** Self-elevation, `Pause`, `Clear-Host`, `$Host.UI.RawUI` and a meaningful `ExitCode` all work (§8, Finding 2). |
| B. `[powershell]::Create().AddScript(<engine text>)` inside the AkariOS runspace | **Rejected.** Self-elevate + `Exit` at [ENGINE: `winsux.ps1:1-4`] would terminate *our* runspace; `Pause` has no console; no `ExitCode`. |
| C. Compile-and-run in-process on the UI thread | **Rejected outright.** Freezes the GUI through ~1200 lines of Stage 3. |

### §7 Decision 3 — Where the DIAG-02 error check lives

| Option | Verdict |
|--------|---------|
| A. New independent `Get-AkariOSStageFailure` reading `state.json` + log tail | **Chosen.** Additive; Phase 1's verified `Get-ResumePoint` table [VERIFIED: `Resume.ps1:120-154`] and `main.ps1:151-178` stay byte-identical. |
| B. Add a `ResumePoint = "error"` value | **Rejected for this phase** — it changes a Phase 1 verified behaviour and would need re-verification of D-03/D-05. Deferred; may be the right home once Phase 4 has real failure data. |

### §7 Decision 4 — Asset decode vs. letting Stage 1 download (see table row 4)

Decode-and-write-then-allow-overwrite, chosen. The alternative (strip the download from Stage 1)
is forbidden by D-06. The alternative (don't pre-write) leaves the RunOnce entries pointing at
files that may not exist if the download failed — worse than a redundant overwrite.

### §7 Decision 5 — Post-stage-3 GUI relaunch (see table row 10)

**No post-stage-3 RunOnce entry is written.** It is unconditionally destroyed by Stage 3's wipe
[ENGINE: `steptwo.ps1:324-333`]. This is a correction to the `!AkariOS` relaunch entry assumed in
`research/STACK.md`: that entry cannot work through Stage 3, and Phase 2 must not write a broken
mechanism. The alternative — writing it and letting it die — is strictly worse (an AkariOS
RunOnce key that sometimes vanishes is confusing to debug in a VM). **This is a documented
deviation from the Phase 1 research assumption** and should be logged as such in STATE.md.

---

## 8. Findings — defects and risks, highest severity first

### Finding 1 — `Invoke-RunInBackground`'s completion/error branch is dead code [Phase 1 defect]

[VERIFIED: `Invoke-RunInBackground.ps1:44-56`]: `$error` and `$done` are assigned in the enclosing
scope, then captured **by value** by `.GetNewClosure()`, then reassigned inside the tick handler.
The closure writes to its own snapshot; the status branch reads the outer `$null`. Consequence:
**any background job failure is reported as `Done.`** DIAG-02's entire path — mark `state.json`
errored, show the log excerpt, offer Retry/Abort — is downstream of this. Decision 7 fixes it as a
prerequisite. Until fixed, Phase 2 must not claim FLOW-03.

### Finding 2 — `Pause` in Stage 1 blocks or throws without a console host

[ENGINE: `winsux.ps1:14`]: the no-internet branch calls `Pause`. In a runspace with no console host
this either throws `HostException` or blocks the runspace thread forever — the second case is
worse, because the UI would sit at "Running…" with no error. Mitigated by decision 2/3 (engine runs
in its own console window) and by the pre-flight internet check Phase 1 already gates the Install
button on. Residual risk: a mid-run network drop still hits `Pause`, and the console window then
waits for a keypress the user may not know about. Not fixable under D-06; record it for the Phase 4
VM procedure ("if the flow stalls, look for a maximized console window").

### Finding 3 — `IWR` is used ~20 times and defined nowhere

[ENGINE: `winsux.ps1:25-29`, `35`, `52-63`, `83`, `139`, `175`] call `IWR`; a grep of
`WinSux-main/WinSux/*.ps1` this session found no `function IWR` and no `Set-Alias IWR`. It relies
on the built-in `Invoke-WebRequest` alias. In a child `powershell.exe -File` the alias exists, so
decision 2 makes this a non-issue **for the engine**. It *would* be an issue if the engine were ever
run in a custom-ISS runspace (option A of decision 1 is about our functions only — never do both).
Note also `IWR` is deprecated in PS7 but we target 5.1, where it is correct.

### Finding 4 — Stage 3 destroys all RunOnce keys, invalidating the `!AkariOS` relaunch plan

[ENGINE: `steptwo.ps1:324-333`]. See §7 Decision 5. Severity: **medium** — it degrades a
convenience, not the flow, provided the flow is detection-driven. Deviation must be recorded.

### Finding 5 — Stage 2 requires an **elevated interactive logon in Safe Mode**, and nothing configures it [showstopper-class]

`HKCU` RunOnce fires at logon, not at boot (§4). Safe Mode does not auto-logon by default, and
WinSux configures no auto-logon. Combined with the documented elevation caveat [CITED: same URL] —
RunOnce commands are skipped entirely for a non-elevated logged-on user — the flow can sit at the
Safe Mode logon screen forever with `safeboot` still set. **The context file does not mention
this at all.** Consequences for planning:

- Phase 2 must **document the procedure prominently in the UI**: after the Stage 1 reboot, log on
  as an administrator in Safe Mode and let `*!stepone` fire. A `Set-Status` hint before the reboot
  is the cheapest possible mitigation and needs no engine change.
- AkariOS must **not** add auto-logon: that is a new security-relevant change to the machine state
  and is outside Phase 2's boundary (Phase 3 owns hardening/branding; D-11 explicitly rules out
  belt-and-braces Safe Mode mechanisms).
- Phase 4's VM procedure must have an explicit "log on at the Safe Mode prompt" step, or it will
  report a false failure.

### Finding 6 — `reg.reg` is not embedded by the current Compile.ps1 filter

§3.8: the filter is `$_.Extension -eq ".ps1"`, so Stage 3's `regedit /S reg.reg`
[ENGINE: `steptwo.ps1:420`] has no file to import. **One-line fix, but it is a silent failure** — the
`regedit` call is inside a string executed via `Invoke-Expression`, so it fails without stopping
the script. Phase 2's verification must include a grep asserting `reg.reg` appears in the compiled
`akarios.ps1` asset block.

---

## Validation Architecture

> Canonical heading for Nyquist. Section 9 below is the same content — static verification only.

**Strategy:** every Phase 2 requirement is verified *statically*, in-process, with no
engine execution. The user compiles and tests on a VM personally; AkariOS never runs its
own installer on this machine. Validation is therefore layered:

- **Layer 1 — syntax:** PowerShell parser on the compiled `akarios.ps1`; `[xml]` cast on
  panel XAML. Catches malformed concatenation and XAML regressions.
- **Layer 2 — contract:** grep/select-string assertions that each new symbol exists, is
  wired to a handler, and that engine assets are byte-identical to upstream.
- **Layer 3 — purity:** unit assertions over pure functions (asset decode, RunOnce command
  string builders) with injected seams — no bcdedit, no registry, no reboot.
- **Layer 4 — VM (Phase 4):** anything requiring a real reboot, Safe Mode, or TrustedInstaller.
  Out of scope here by construction.

Per-requirement mapping: FLOW-01 → V1/V5/V6; FLOW-02 → V5; FLOW-03 → V2/V8 (detection is
Phase 1's, already verified — Phase 2 adds the engine side); DIAG-02 → V1/V7 + the
`Invoke-RunInBackground` closure fix (Decision 7), without which the error path is dead code.

---

## 9. Static verification plan (nothing here executes the engine)

Every check below is safe to run on the live machine: parser and XML checks, greps, and file
existence only. **No check may invoke `bcdedit`, write a registry key, call `shutdown`, download, or
touch `C:\ProgramData\AkariOS`.**

| # | Assertion | Method |
|---|-----------|--------|
| V1 | Compiled shell parses | `[System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$errs); $errs.Count -eq 0` |
| V2 | All three engine assets + `reg.reg` are embedded | `Select-String -Path akarios.ps1 -Pattern '\$sync\.assets\.(winsux|stepone|steptwo|reg)\b'` — all four must hit |
| V3 | `.reg` filter was widened | `Select-String -Path Compile.ps1 -Pattern 'Extension -eq "\.ps1" -or.*Extension -eq "\.reg"'` |
| V4 | Panel XAML is well-formed XML | `[xml](Get-Content panels\MainWindow.xaml -Raw)` |
| V5 | Every new button has a handler | for each `BtnStage1..3`, `Select-String -Path scripts\main.ps1 -Pattern 'function Invoke-BtnStage1'` etc., **and** the button uses plain `Name=` (assert no `x:Name="BtnStage`) |
| V6 | RunOnce command strings match the engine byte-for-byte | unit-assert `(Get-AkariOSRunOnceCommand -Stage 2) -eq 'powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1'` — string comparison only, no `reg add` |
| V7 | `bcdedit` / `shutdown` are only ever *passed to* a seam | `Select-String -Path functions\**\*.ps1 -Pattern 'bcdedit' -Context 1` and confirm each hit is inside a `-BcdWriter` default, never called directly by a runner |
| V8 | Engine copies are unmodified | `(Get-FileHash assets\text\winsux.ps1).Hash -eq (Get-FileHash WinSux-main\WinSux\winsux.ps1).Hash` (same for the other three) |
| V9 | Decode helper is pure | run `Expand-AkariOSEngineAsset` with an injected asset map and `-DestinationRoot $env:TEMP`; assert the returned path exists and the file hash matches the source |

**Not verifiable here, deferred to Phase 4 VM validation:** `*!stepone` firing in Safe Mode
(Finding 5), DDU's `-Restart` transition out of Safe Mode, Stage 3's restore point creation, and
whether a `Pause` ever surfaces in practice (Finding 2).

---

*Research complete. Sections 1-9 written 2026-10-04. Static-only: no engine script was executed.*