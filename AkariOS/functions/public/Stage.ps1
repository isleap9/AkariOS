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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Stage,
        [scriptblock]$AssetInvoker = { param($AssetName) Expand-AkariOSEngineAsset -Name $AssetName -Overwrite },
        [scriptblock]$EngineInvoker,
        [scriptblock]$RunOnceWriter,
        [scriptblock]$BcdWriter,
        [string]$StatePath,
        [string]$LogPath
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
    # -OnComplete is added by the runspace repair in Task 2; until then the job's
    # own logging is the only record of how it ended.
    $supervisorArgs = @{
        StatusStart = ("Stage {0} is running in a separate console window..." -f $Stage)
        StatusDone  = ("Stage {0} finished." -f $Stage)
        ScriptBlock = {
            Invoke-AkariOSEngine -ScriptPath $enginePath -EngineInvoker $EngineInvoker
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