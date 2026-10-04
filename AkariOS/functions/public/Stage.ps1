# -- Stage explanations (SAFE-03) ----------------------------------------------
# The three stage descriptions are fixed by 01-UI-SPEC.md and must not be
# paraphrased. They live here as data so the progress panel can show the same
# wording the home panel uses, and so the stage runner can log them verbatim.

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
    [ordered]@{
        Number       = 2
        Key          = "stage2"
        Title        = "Safe Mode (console only)"
        Description  = "Stage 2: Runs in Safe Mode as TrustedInstaller. Disables Defender, modifies system protections, and reboots."
        Cost         = "Cost: permanently reduces your security posture. Run from a console window because the GUI does not render in Safe Mode. Cancel is no longer available."
        Reversible   = $false
        PercentStart = 20
        PercentEnd   = 60
    },
    [ordered]@{
        Number       = 3
        Key          = "stage3"
        Title        = "Tweaks and branding"
        Description  = "Stage 3: Removes bloatware, applies performance tweaks, sets AkariOS branding, and reboots to complete."
        Cost         = "Cost: removes applications and drivers that are not trivially reinstalled. A system restore point is the only reliable way back."
        Reversible   = $false
        PercentStart = 60
        PercentEnd   = 100
    }
)

function Get-AkariOSStage {
    <#
    .SYNOPSIS
        Returns the stage record for a stage number (1-3), or $null.
    #>
    [CmdletBinding()]
    param([int]$Number)
    return @($script:AkariOSStages | Where-Object { $_.Number -eq $Number })[0]
}

function Get-StageExplanation {
    <#
    .SYNOPSIS
        Returns the UI-SPEC explanation block for a stage: title, description,
        cost and reversibility (SAFE-03).
    .PARAMETER Number
        Stage number 1, 2 or 3.
    #>
    [CmdletBinding()]
    param([int]$Number)

    $stage = Get-AkariOSStage -Number $Number
    if (-not $stage) {
        return [pscustomobject]@{
            Number      = 0
            Title       = "Unknown stage"
            Description = ""
            Cost        = ""
            Reversible  = $false
        }
    }

    return [pscustomobject]@{
        Number      = $stage.Number
        Title       = $stage.Title
        Description = $stage.Description
        Cost        = $stage.Cost
        # SAFE-03: reversibility is stated, not implied.
        Reversible  = [bool]$stage.Reversible
        ReversibleText = if ($stage.Reversible) {
            "Reversible: you can cancel right up to the reboot into Safe Mode."
        } else {
            "Not easily reversible. Create a system restore point before continuing."
        }
    }
}

# ══ Stage launch (FLOW-01 / FLOW-03) ═════════════════════════════════════════
#
# Everything below the stage-explanation block drives ONE path: decode the engine
# to disk, write the cross-reboot handoff, and hand the launch to a child
# powershell.exe.
#
# TWO HARD RULES, both from the phase threat model:
#
#   D-07  The engine owns the reboot. There is no `shutdown`, `Restart-Computer`
#         or `bcdedit` invocation anywhere in AkariOS code outside a wrapper's
#         parameter default. Test-Stage.ps1 asserts this on the stripped source.
#
#   V7    Every call that touches the outside world sits behind an overridable
#         scriptblock parameter whose default is the real call. A VM or a test
#         passes a replacement and nothing executes.

# Which embedded asset each stage runs. Stage 3 additionally needs reg.reg,
# which steptwo.ps1 imports from %SystemRoot%\Temp. Engine is the asset that is
# launched; the rest are written to disk alongside it. Asset keys are BaseNames
# (no extension) because that is how Compile.ps1 names $sync.assets.<key>.
$script:AkariOSStageAssets = @{
    1 = [ordered]@{ Engine = "winsux";  Also = @() }
    2 = [ordered]@{ Engine = "stepone"; Also = @() }
    3 = [ordered]@{ Engine = "steptwo"; Also = @("reg") }
}

function Get-AkariOSRunOnceCommand {
    <#
    .SYNOPSIS
        Returns the exact RunOnce VALUE DATA WinSux stores for a stage (FLOW-03).
    .DESCRIPTION
        Pure string builder — no registry, no filesystem, no engine. Stage 2 and
        Stage 3 resolve to the strings at winsux.ps1:222 and winsux.ps1:225
        respectively, byte for byte. Phase 1's resume detection matches on the
        `*!stepone` / `!steptwo` ENTRY names (Resume.ps1), which live in
        $script:AkariOSStage2Entry / $script:AkariOSStage3Entry and are reused by
        Set-AkariOSRunOnceEntry, never redefined here.

        Stage 1 returns $null: WinSux writes no RunOnce entry for itself, and a
        stage-1 entry would point at a script that is already running.
    .PARAMETER Stage
        Stage number 1-3.
    .PARAMETER TempRoot
        Directory the target script lives in. Defaults to %SystemRoot%\Temp, which
        makes the produced string identical to the engine's. Overridable only so a
        test can pin it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Stage,
        [string]$TempRoot = (Join-Path $env:SystemRoot "Temp")
    )

    $scriptName = switch ($Stage) {
        2 { "stepone.ps1" }
        3 { "steptwo.ps1" }
        default { $null }
    }

    if (-not $scriptName) { return $null }

    # Verbatim from winsux.ps1:222 / :225 — `-nop -ep bypass -WindowStyle Maximized -f`.
    return "powershell.exe -nop -ep bypass -WindowStyle Maximized -f $(Join-Path $TempRoot $scriptName)"
}

function Set-AkariOSRunOnceEntry {
    <#
    .SYNOPSIS
        Writes one cross-reboot RunOnce entry for a stage, through an overridable seam.
    .DESCRIPTION
        The entry NAME comes from the Phase 1 constants in Resume.ps1 and the value
        DATA from Get-AkariOSRunOnceCommand — Phase 1's resume detection greps for
        those entry names, so they are reused rather than restated here.

        The registry write itself exists only inside the -RunOnceWriter default. A
        test or VM run injects its own writer and reg.exe is never reached.
    .PARAMETER Stage
        Stage number 2 or 3.
    .PARAMETER RunOnceWriter
        Overrides the registry write. Receives the full command string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Stage,
        [string]$TempRoot = (Join-Path $env:SystemRoot "Temp"),
        [scriptblock]$RunOnceWriter = { param($RunOnceWriterCommand) Invoke-Expression $RunOnceWriterCommand }
    )

    $entry = switch ($Stage) {
        2 { $script:AkariOSStage2Entry }
        3 { $script:AkariOSStage3Entry }
        default { $null }
    }
    if (-not $entry) {
        Write-AkariOSLog -Level WARN -Message ("No RunOnce entry exists for stage {0} - WinSux writes none." -f $Stage)
        return $false
    }

    $value = Get-AkariOSRunOnceCommand -Stage $Stage -TempRoot $TempRoot
    if (-not $value) { return $false }

    # The reg.exe invocation lives here as a STRING; it is only ever executed by
    # $RunOnceWriter, whose default is the seam defined in the param() block above.
    $RunOnceWriterCommand = ('cmd /c reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "{0}" /t REG_SZ /d "{1}" /f >nul 2>&1' -f $entry, $value)

    & $RunOnceWriter $RunOnceWriterCommand

    Write-AkariOSLog -Level INFO -Message ("Queued RunOnce {0} -> {1}" -f $entry, $value)
    return $true
}

function Set-BcdSafebootValue {
    <#
    .SYNOPSIS
        Sets `bcdedit /set {current} safeboot minimal`, through an overridable seam.
    .DESCRIPTION
        The ONLY place AkariOS can turn Safe Mode on, and it is reachable only
        through -BcdWriter. Undo path: Clear-BcdSafebootValue, also behind a seam.
    .PARAMETER BcdWriter
        Overrides the bcdedit invocation. Receives the full command string.
    #>
    [CmdletBinding()]
    param(
        [scriptblock]$BcdWriter = { param($BcdWriterCommand) Invoke-Expression $BcdWriterCommand }
    )

    $BcdWriterCommand = 'cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"'

    & $BcdWriter $BcdWriterCommand
    Write-AkariOSLog -Level INFO -Message "Requested Safe Mode (minimal)."
    return $true
}

function Clear-BcdSafebootValue {
    <#
    .SYNOPSIS
        Clears the safeboot flag through an overridable seam, so the next boot is normal.
    .DESCRIPTION
        Called at the START of Stage 2. If it is skipped, the machine boots into
        Safe Mode again after Stage 2 and the install loops.
    .PARAMETER BcdWriter
        Overrides the bcdedit invocation. Receives the full command string.
    #>
    [CmdletBinding()]
    param(
        [scriptblock]$BcdWriter = { param($BcdWriterCommand) Invoke-Expression $BcdWriterCommand }
    )

    $BcdWriterCommand = 'cmd /c "bcdedit /deletevalue {current} safeboot >nul 2>&1"'

    & $BcdWriter $BcdWriterCommand
    Write-AkariOSLog -Level INFO -Message "Cleared the Safe Mode flag."
    return $true
}

function Invoke-AkariOSEngine {
    <#
    .SYNOPSIS
        Launches a decoded engine script as a CHILD powershell.exe and returns its exit code.
    .DESCRIPTION
        The child-process boundary is the ratified architecture decision (T-02-04):
        the engine self-elevates with `Start-Process -Verb RunAs` + `Exit` in its
        first four lines, so running it in-process would terminate our own runspace.
        It also calls Pause, Clear-Host and $Host.UI.RawUI, which need a console
        host of their own — `-File` in a separate window gives it one.

        Deliberately NO `-Verb RunAs` here: the engine elevates itself, and an
        elevated launcher would show a second UAC prompt.
    .PARAMETER ScriptPath
        Path to the decoded engine script on disk.
    .PARAMETER EngineInvoker
        Overrides the process launch. Receives $ScriptPath and returns a process-like
        object exposing .ExitCode (or a bare exit code).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [scriptblock]$EngineInvoker = {
            param($EngineScriptPath)
            Start-Process -FilePath "powershell.exe" `
                          -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $EngineScriptPath" `
                          -PassThru -Wait -WindowStyle Normal
        }
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-AkariOSLog -Level ERROR -Message ("Engine script is missing: {0}" -f $ScriptPath)
        return 9009
    }

    $result = & $EngineInvoker $ScriptPath

    # The default invoker returns a Process; an injected one may return a bare
    # exit code. Normalise both to an int so the caller has one contract.
    $code = $null
    if ($null -ne $result) {
        if ($result.PSObject.Properties.Name -contains "ExitCode") { $code = [int]$result.ExitCode }
        elseif ($result -is [int]) { $code = [int]$result }
    }

    if ($null -eq $code) { $code = -1 }

    Write-AkariOSLog -Level INFO -Message ("Engine child process for {0} exited with code {1}." -f (Split-Path -Leaf $ScriptPath), $code)
    return $code
}

function Invoke-AkariOSStage {
    <#
    .SYNOPSIS
        Runs one stage end to end: decode, record, hand off, launch the engine child.
    .DESCRIPTION
        The single confirmation path (FLOW-01): Invoke-BtnInstall -> Start-AkariOSInstall
        -> here -> decoded engine -> child powershell.exe.

        It does NOT show the confirmation gate — Invoke-BtnInstall already ran it,
        and running it twice would double-prompt. It does NOT reboot anything: the
        engine owns that (D-07).

        No RunOnce entry is written for Stage 3. steptwo.ps1 wipes the RunOnce keys
        itself (steptwo.ps1:324-333), so an entry written after it starts is dead.
    .PARAMETER Stage
        Stage number 1-3.
    .PARAMETER AssetInvoker
        Overrides Expand-AkariOSEngineAsset. Receives the asset name, returns the path.
    .PARAMETER EngineInvoker
        Overrides the child-process launch.
    .PARAMETER RunOnceWriter
        Overrides the RunOnce registry write.
    .PARAMETER BcdWriter
        Overrides the bcdedit invocation.
    .PARAMETER StatePath
        state.json location. Defaults to the live path; override for tests.
    .PARAMETER LogPath
        install.log location. Defaults to the live path; override for tests.
    .PARAMETER OnComplete
        Optional completion callback, receives the outcome hashtable from the
        background runner. Added in Plan 02 task 1 so the per-stage button handlers
        can re-enable themselves when the stage actually ends; additive, and the
        default behaviour when omitted is unchanged.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Stage,
        [scriptblock]$AssetInvoker = { param($AssetName) Expand-AkariOSEngineAsset -Name $AssetName -Overwrite },
        [scriptblock]$EngineInvoker,
        [scriptblock]$RunOnceWriter,
        [scriptblock]$BcdWriter,
        [string]$StatePath,
        [string]$LogPath,
        [scriptblock]$OnComplete
    )

    $map = $script:AkariOSStageAssets[$Stage]
    if (-not $map) {
        Write-AkariOSLog -Level ERROR -Message ("No engine asset is mapped for stage {0}." -f $Stage)
        return $false
    }

    # --- 1. Decode the engine (and its companions) to %SystemRoot%\Temp -------
    # The engine asset goes first and its failure aborts the stage; a companion
    # asset (reg.reg) that fails to decode is logged and does not abort, because
    # the stage script itself is still runnable.
    $enginePath = & $AssetInvoker $map.Engine
    if (-not $enginePath) {
        Write-AkariOSLog -Level ERROR -Message ("Stage {0} aborted: asset '{1}' did not decode." -f $Stage, $map.Engine)
        return $false
    }
    Write-AkariOSLog -Level INFO -Message ("Decoded engine asset '{0}' to {1}" -f $map.Engine, $enginePath)

    foreach ($name in @($map.Also)) {
        $p = & $AssetInvoker $name
        if ($p) {
            Write-AkariOSLog -Level INFO -Message ("Decoded companion asset '{0}' to {1}" -f $name, $p)
        } else {
            Write-AkariOSLog -Level WARN -Message ("Companion asset '{0}' did not decode." -f $name)
        }
    }

    # --- 2. Record where we are -----------------------------------------------
    if (Get-Command Set-CurrentStage -ErrorAction SilentlyContinue) {
        Set-CurrentStage -Stage $Stage
    }
    Write-AkariOSLog -Level INFO -Message ("Stage {0} starting. Engine: {1}" -f $Stage, $enginePath)

    # --- 3. Cross-reboot handoff (seams only) ---------------------------------
    if ($Stage -eq 1) {
        # WinSux writes BOTH entries before it reboots (winsux.ps1:222, :225).
        Set-AkariOSRunOnceEntry -Stage 2 -RunOnceWriter $RunOnceWriter
        Set-AkariOSRunOnceEntry -Stage 3 -RunOnceWriter $RunOnceWriter
        Set-BcdSafebootValue -BcdWriter $BcdWriter
    }
    elseif ($Stage -eq 2) {
        # Clear safeboot FIRST or the machine boots into Safe Mode again (loop).
        Clear-BcdSafebootValue -BcdWriter $BcdWriter
    }

    if ($StatePath) { Set-AkariOSState -Path $StatePath -CurrentStage $Stage -Status "running" }

    # --- 4. Safe Mode log-on hint (status bar only, no engine change) ---------
    if ($Stage -eq 1) {
        Set-Status "Stage 1 is running in its own console window. The machine will restart into Safe Mode - at the Safe Mode logon screen, sign in as an ADMINISTRATOR so the queued Stage 2 script can run." "#FFA726"
    }

    # --- 5. Launch the engine as a child process, supervised -----------------
    # Invoke-RunInBackground keeps the WPF UI responsive while the child runs.
    # -OnComplete receives the outcome hashtable, which is the ONLY way to learn
    # how the job ended: a local captured by the job's closure would be read by
    # value and always look like success.
    $supervisorArgs = @{
        StatusStart = ("Stage {0} is running in a separate console window..." -f $Stage)
        StatusDone  = ("Stage {0} finished." -f $Stage)
        ScriptBlock = {
            Invoke-AkariOSEngine -ScriptPath $enginePath -EngineInvoker $EngineInvoker
        }.GetNewClosure()
        OnComplete  = {
            param($Outcome)
            if ($Outcome.Error) {
                Write-AkariOSLog -Level ERROR -Message ("Stage {0} FAILED: {1}" -f $Stage, ($Outcome.Error | Out-String))
                if ($StatePath) { Set-AkariOSState -Path $StatePath -CurrentStage $Stage -Status "error" }
            } else {
                Write-AkariOSLog -Level INFO -Message ("Stage {0} engine process completed." -f $Stage)
            }
            if ($OnComplete) { & $OnComplete $Outcome }
        }.GetNewClosure()
    }

    if (Get-Command Invoke-RunInBackground -ErrorAction SilentlyContinue) {
        Invoke-RunInBackground @supervisorArgs
    } else {
        Write-AkariOSLog -Level ERROR -Message "Background runner unavailable - stage cannot be launched."
        return $false
    }

    return $true
}

function Start-AkariOSInstall {
    <#
    .SYNOPSIS
        The published entry point into the install (FLOW-01).
    .DESCRIPTION
        Confirm.ps1:233 resolves this name with Get-Command and calls it, so its
        existence is what completes FLOW-01 — no Phase 1 file needed editing.

        It takes no required parameters on purpose: the confirmation gate already
        ran in Invoke-BtnInstall, and pre-flight is re-checked there.
    #>
    [CmdletBinding()]
    param()

    Write-AkariOSLog -Level INFO -Message "Install confirmed by the user. Starting Stage 1."
    return (Invoke-AkariOSStage -Stage 1)
}

# ══ Per-stage run buttons (FLOW-02) ══════════════════════════════════════════
#
# Three buttons on the progress panel each run exactly one stage, independently
# of the full three-stage flow.
#
# SAFETY (SAFE-02): these handlers drive the SAME destructive engine as the main
# Install CTA, so they repeat BOTH gates Invoke-BtnInstall runs —
# Invoke-PreFlightChecks and the typed-token Show-ConfirmationGate. Neither is
# optional and neither may be skipped because the button already looks enabled.
#
# A missing Invoke-BtnStage<N> is a SILENTLY DEAD button: main.ps1:109 wires
# buttons with `-ErrorAction SilentlyContinue`, so a name typo costs nothing at
# launch and the user just finds a button that does nothing. Test-Panels.ps1
# asserts one definition of each, for exactly this reason.

function Show-StageHandoffHint {
    <#
    .SYNOPSIS
        Reveals the Stage 2 Safe Mode handoff copy on the progress panel.
    .DESCRIPTION
        Touches a WPF control, so it must be marshalled onto the UI thread. Uses
        the Progress.ps1:107-124 CheckAccess-then-BeginInvoke shape: a blocking
        Invoke from a worker while the UI thread waits on the job deadlocks.

        The static copy lives in 02-Progress.xaml; -PendingNote is the one dynamic
        part, appended as a separate line so the literal text is never rewritten.
    .PARAMETER Visible
        Show (default) or collapse the hint.
    .PARAMETER PendingNote
        Optional extra sentence appended to the hint text, e.g. that the next
        RunOnce entry is still queued.
    .PARAMETER RunOnceInvoker
        Overrides Get-AkariOSRunOnceEntries, the only way this function reads
        machine state. Defaults to the real read-only lookup; nothing writes.
    .PARAMETER ProbePending
        When set, a still-queued !steptwo entry appends the recovery sentence.
    #>
    [CmdletBinding()]
    param(
        [switch]$Visible,
        [string]$PendingNote = "",
        [scriptblock]$RunOnceInvoker = { Get-AkariOSRunOnceEntries },
        [switch]$ProbePending
    )

    $syncRef = $sync
    if (-not ($syncRef -and $syncRef.StageHandoffHint)) { return }

    $note = $PendingNote
    if ($ProbePending -and -not $note) {
        try {
            $entries = & $RunOnceInvoker
            if ($entries -and ($entries | Where-Object { [string]$_ -like "*$($script:AkariOSStage3Entry)*" })) {
                $note = "STAGE 3 IS STILL QUEUED: !steptwo has not run yet, so it will start the next time this account signs in."
            }
        } catch {
            # A failed probe must not stop the hint from appearing.
        }
    }

    $work = [System.Action]{
        $hint = $syncRef.StageHandoffHint
        # Idempotent: revealing the hint repeatedly must not grow the text. The
        # XAML literal is captured once as the base, and the note is re-applied
        # to that base every time.
        if (-not $syncRef["StageHandoffBase"]) { $syncRef["StageHandoffBase"] = $hint.Text }
        $hint.Text = if ($note) { $syncRef["StageHandoffBase"] + "  " + $note } else { $syncRef["StageHandoffBase"] }
        $hint.Visibility = if ($Visible) {
            [System.Windows.Visibility]::Visible
        } else {
            [System.Windows.Visibility]::Collapsed
        }
    }.GetNewClosure()

    if ($syncRef.window) {
        $dispatcher = $syncRef.window.Dispatcher
        if ($dispatcher.CheckAccess()) { $work.Invoke() }
        else { $dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $work) | Out-Null }
    } else {
        # No window (a test harness): set it directly.
        $work.Invoke()
    }
}

function Invoke-AkariOSSingleStage {
    <#
    .SYNOPSIS
        Shared body of Invoke-BtnStage1/2/3: gate, then run one stage alone.
    .DESCRIPTION
        Exists so the three button handlers cannot drift apart. Every outside-world
        step (pre-flight, the gate, the stage launch, RunOnce, panel switching)
        is an injectable parameter whose default is the real call, so a test can
        drive the whole handler and assert on what it did without touching
        machine state.

        Stage 2 and Stage 3 FIRST write their own RunOnce entry. This is NOT the
        happy path: in the full flow WinSux queues BOTH entries during Stage 1
        (winsux.ps1:222 / :225) and by the time Stage 2 or 3 runs they are already
        in the registry. When a user runs Stage 2 or Stage 3 on its own nothing
        has queued the next hand-off, so without this write the flow simply stops
        there. The write still goes through the Set-AkariOSRunOnceEntry seam and
        still happens only after both gates have passed.
    .PARAMETER Stage
        Stage number 1-3.
    .PARAMETER ButtonName
        Name of the button in $sync, disabled for the run and re-enabled when the
        stage's background job completes.
    .PARAMETER WriteOwnRunOnce
        Queue this stage's RunOnce entry before running. True for stages 2 and 3.
    .PARAMETER PreflightInvoker
        Overrides Invoke-PreFlightChecks.
    .PARAMETER GateInvoker
        Overrides Show-ConfirmationGate.
    .PARAMETER StageInvoker
        Overrides Invoke-AkariOSStage.
    .PARAMETER PanelSwitcher
        Overrides Show-Panel.
    .PARAMETER RunOnceWriter
        Overrides the RunOnce registry write.
    .PARAMETER MessageBoxInvoker
        Overrides the blocking-failure dialog. Injectable so a harness can exercise
        the blocked path without a modal window appearing on the desktop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet(1, 2, 3)][int]$Stage,
        [string]$ButtonName = "",
        [bool]$WriteOwnRunOnce = $false,
        [scriptblock]$PreflightInvoker = { Invoke-PreFlightChecks },
        [scriptblock]$GateInvoker      = { Show-ConfirmationGate },
        [scriptblock]$StageInvoker     = { param($n, $cb) Invoke-AkariOSStage -Stage $n -OnComplete $cb },
        [scriptblock]$PanelSwitcher    = { param($p) Show-Panel $p },
        [scriptblock]$RunOnceWriter,
        [scriptblock]$MessageBoxInvoker = {
            param($Text, $Title)
            [System.Windows.MessageBox]::Show($Text, $Title) | Out-Null
        }
    )

    # 1. Same Get-Command guard as Invoke-BtnRunChecks (Check.ps1:413-416): without
    #    the background runner nothing can be supervised, so say so instead of
    #    pretending the stage started.
    if (-not (Get-Command Invoke-RunInBackground -ErrorAction SilentlyContinue)) {
        & $MessageBoxInvoker "Background runner unavailable." "AkariOS Setup"
        return
    }

    # 2. Defense in depth: the per-stage path drives the same destructive engine
    #    as the main CTA, so it repeats the pre-flight check even when the button
    #    was enabled by main.ps1 step 6 (Confirm.ps1:217-225).
    $pre = & $PreflightInvoker
    if (-not $pre.CanInstall) {
        $first = @($pre.BlockingFails)[0]
        if (Get-Command Show-CheckResult -ErrorAction SilentlyContinue) {
            Show-CheckResult -Results $pre.Results -Summary $pre.Summary
        }
        & $MessageBoxInvoker ("Stage {0} cannot start yet.`n`n" + $first.Name + ": " + $first.Message) "AkariOS Setup"
        return
    }

    # 3. The typed-token gate, identical to the main CTA (Confirm.ps1:227-231).
    if (-not (& $GateInvoker)) {
        Set-Status ("Stage {0} cancelled at the confirmation gate." -f $Stage) "#AAAAAA"
        & $PanelSwitcher "PanelHome"
        return
    }

    # 4. Per-stage-runs-alone path: queue this stage's own cross-reboot hand-off.
    #    Both gates have passed; nothing below here is reachable without them.
    if ($WriteOwnRunOnce) {
        Set-AkariOSRunOnceEntry -Stage $Stage -RunOnceWriter $RunOnceWriter
    }

    # 5. Stage 2 must be launched from a console, not from WPF (D-12), so the
    #    handoff copy is on screen before the engine takes over the machine.
    #
    #    WHY D-12 IS NOT "IMPROVABLE": WPF in Safe Mode depends on the
    #    undocumented Render Tier 0 path (BasicDisplay.sys + WARP). It may work on
    #    some builds and fail on others, and STACK.md classifies it as unreliable.
    #    So AkariOS attempts nothing in Safe Mode: Step 1's RunOnce entry launches
    #    stepone.ps1 as a raw maximized console, and this hint is how the user is
    #    told to expect that. Do not "improve" this into a Safe Mode WPF attempt —
    #    RESEARCH Finding 5 and the D-12 rationale are the reason it is text.
    #
    #    The copy also has to answer the three things the user cannot infer
    #    (02-Progress.xaml, the comment above StageHandoffHint): that the console
    #    window is the engine and not a hang, that they MUST log on at the Safe
    #    Mode prompt because RunOnce fires at logon and nothing auto-logs-on, and
    #    that DDU's -Restart — not a shutdown call — is what leaves Safe Mode.
    #
    #    The still-pending half is dynamic and is the only part computed here: if
    #    the next RunOnce entry is still queued we say so, because a machine that
    #    came back into normal boot with !steptwo pending is a recoverable state
    #    the resume banner handles, and silently doing nothing would be the
    #    confusing outcome.
    if ($Stage -eq 2) {
        if ($WriteOwnRunOnce) {
            Set-Status ("Stage 2 will run in a console window after the reboot. Safe Mode needs an ADMINISTRATOR logon at its prompt - see the Stage 2 handoff note.") "#FFA726"
        } else {
            Set-Status ("Stage 2 runs as a console window, never as the AkariOS window - see the Stage 2 handoff note.") "#FFA726"
        }
        Show-StageHandoffHint -Visible -ProbePending
    }

    # 6. Disable our own button for the duration, and re-enable it from the
    #    stage's completion callback so a second click cannot race the first.
    if ($ButtonName -and $sync -and $sync[$ButtonName]) {
        $sync[$ButtonName].IsEnabled = $false
    }

    $onDone = {
        param($Outcome)
        if ($ButtonName -and $sync -and $sync[$ButtonName]) {
            $syncRef2 = $sync
            $reenable = [System.Action]{
                if ($syncRef2[$ButtonName]) { $syncRef2[$ButtonName].IsEnabled = $true }
            }.GetNewClosure()
            if ($syncRef2.window) {
                $d = $syncRef2.window.Dispatcher
                if ($d.CheckAccess()) { $reenable.Invoke() }
                else { $d.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $reenable) | Out-Null }
            } else {
                $reenable.Invoke()
            }
        }
    }.GetNewClosure()

    Write-AkariOSLog -Level INFO -Message ("User requested Stage {0} on its own." -f $Stage)
    return (& $StageInvoker $Stage $onDone)
}

function Invoke-BtnStage1 {
    <#
    .SYNOPSIS
        BtnStage1 handler: run Stage 1 alone, behind the full install gates.
    #>
    [CmdletBinding()]
    param()
    return (Invoke-AkariOSSingleStage -Stage 1 -ButtonName "BtnStage1")
}

function Invoke-BtnStage2 {
    <#
    .SYNOPSIS
        BtnStage2 handler: run Stage 2 alone, behind the full install gates.
    .DESCRIPTION
        Stage 2 runs as a raw maximized console, never WPF (D-12), and the machine
        only leaves Safe Mode because DDU restarts it (stepone.ps1:153) - there is
        no shutdown call in that script at all. It also writes its own RunOnce
        entry first, because nothing else will have queued one.
    #>
    [CmdletBinding()]
    param()
    return (Invoke-AkariOSSingleStage -Stage 2 -ButtonName "BtnStage2" -WriteOwnRunOnce $true)
}

function Invoke-BtnStage3 {
    <#
    .SYNOPSIS
        BtnStage3 handler: run Stage 3 alone, behind the full install gates.
    .DESCRIPTION
        Writes its own RunOnce entry first (RESEARCH §5 Decision 5: in the happy
        path Stage 1 already queued both entries, so this only fires when the user
        runs Stage 3 by itself). No entry is written FOR anything after Stage 3 -
        steptwo.ps1 wipes the RunOnce keys itself (steptwo.ps1:324-333).
    #>
    [CmdletBinding()]
    param()
    return (Invoke-AkariOSSingleStage -Stage 3 -ButtonName "BtnStage3" -WriteOwnRunOnce $true)
}