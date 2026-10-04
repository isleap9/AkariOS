# ── AkariOS post-install relaunch ────────────────────────────────────────────
#
# WHY THIS FILE EXISTS
#
# After Stage 3 (steptwo.ps1) the machine reboots and the AkariOS window is
# expected to come back by itself, so the user sees the completion screen
# instead of silence. The obvious mechanism is WRONG here, and the reason is a
# fact about the read-only engine:
#
#   steptwo.ps1:324-333 deletes and re-creates the RunOnce key under HKCU, HKLM
#   and WOW6432Node. Any RunOnce value AkariOS wrote BEFORE Stage 3 started is
#   therefore unconditionally destroyed before it can ever fire. A Startup
#   folder shortcut would survive, but it re-runs elevation and the pre-flight
#   checklist at every logon until something removes it.
#
# So the hand-off is a SCHEDULED TASK, which that wipe does not touch, and
# every outside-world call in this file sits behind an overridable scriptblock
# whose default is the real call (V7). No test in this repository creates a
# real task, writes a registry key or starts a process: Test-Relaunch.ps1
# injects a stub for every one of them.
#
# TWO RATIFIED CONSTRAINTS THAT ARE EASY TO REGRESS BY INTUITION:
#
#   D-14  The task targets the INTERACTIVE user with /IT and /RL HIGHEST, never
#         /RU SYSTEM. A task running as SYSTEM executes in session 0, which has
#         no visible desktop: the WPF window would be created on a screen the
#         user cannot see, reproducing the exact symptom this mechanism exists
#         to fix. If the interactive account name cannot be resolved we fall
#         back to SYSTEM and log a WARN so the degradation is diagnosable - we
#         do not abort.
#
#   D-15  The task points at a STAGED COPY under %ProgramData%\AkariOS\, not at
#         the running script's own path. The user may have launched akarios.ps1
#         from Downloads and deleted it since.
#
# Recovery, if a task is ever left behind:
#     schtasks /delete /TN "AkariOS-PostInstall" /F

# The single task name, used by the builder, the creator and the self-cleanup.
# One constant so the three can never drift apart.
$script:AkariOSRelaunchTaskName = "AkariOS-PostInstall"

# The staged copy's file name, same reasoning.
$script:AkariOSRelaunchScriptName = "akarios.ps1"

# The path of the script that is running RIGHT NOW. Captured at load time, not
# read as $PSCommandPath inside a function: $PSCommandPath is an automatic
# variable scoped to the file being executed, and in the compiled single-file
# build every function in this file came from akarios.ps1 itself - which is
# exactly the file the relaunch task must be able to point at.
$script:AkariOSRelaunchRunningScript = $PSCommandPath

function Get-AkariOSRelaunchDirectory {
    <#
    .SYNOPSIS
        Returns the directory the relaunch script is staged into.
    .DESCRIPTION
        Derived from the house state constant in State.ps1, never hardcoded, so
        the relaunch target and state.json can never end up in different
        places. $env:ProgramData is the fallback for a build where State.ps1
        was not loaded (the Get-Command guard in Stage.ps1 allows that shape).
    #>
    [CmdletBinding()]
    param()

    if ($script:AkariOSStateDefaultPath) {
        return (Split-Path -Path $script:AkariOSStateDefaultPath -Parent)
    }
    if ($env:ProgramData) {
        return (Join-Path $env:ProgramData "AkariOS")
    }
    return $null
}

function Get-AkariOSRelaunchScriptPath {
    <#
    .SYNOPSIS
        Returns the full path the staged relaunch copy will live at.
    #>
    [CmdletBinding()]
    param()

    $dir = Get-AkariOSRelaunchDirectory
    if (-not $dir) { return $null }
    return (Join-Path $dir $script:AkariOSRelaunchScriptName)
}

function Get-AkariOSInteractiveUser {
    <#
    .SYNOPSIS
        Returns the current account name in DOMAIN\user form, or $null.
    .DESCRIPTION
        Pure read of the current identity. No registry, no task, no process.
        Returns $null rather than throwing so the caller can take the documented
        /RU SYSTEM fallback (D-14) instead of failing the whole stage.
    #>
    [CmdletBinding()]
    param()

    try {
        $name = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ([string]::IsNullOrWhiteSpace([string]$name)) { return $null }
        return [string]$name
    } catch {
        return $null
    }
}

function Get-AkariOSRelaunchTaskCommand {
    <#
    .SYNOPSIS
        Builds the schtasks.exe ARGUMENT LIST that creates the relaunch task.
    .DESCRIPTION
        PURE STRING BUILDER. It writes no registry key, creates no task and
        starts no process, so Test-Relaunch.ps1 can pin both inputs and assert
        the produced string with nothing stubbed.

        The /TR payload is quoted so the -File argument survives being handed
        to cmd, and the whole command reaches schtasks.exe as ONE -ArgumentList
        string (Invoke-AkariOSTaskCommandDefault's job).

        When -InteractiveUser is null or empty the documented D-14 degradation
        applies: /RU SYSTEM WITHOUT /IT. That is the only case in which /IT is
        omitted, and the caller (Set-AkariOSRelaunchTask) logs it at WARN.
    .PARAMETER ScriptPath
        Path of the staged script the task runs. Pin this in tests.
    .PARAMETER InteractiveUser
        Account the task runs as. Defaults to the resolved interactive user.
    #>
    [CmdletBinding()]
    param(
        [string]$ScriptPath = (Get-AkariOSRelaunchScriptPath),
        [string]$InteractiveUser = (Get-AkariOSInteractiveUser)
    )

    if ([string]::IsNullOrWhiteSpace([string]$ScriptPath)) { return $null }

    $user = if ([string]::IsNullOrWhiteSpace([string]$InteractiveUser)) { "SYSTEM" } else { $InteractiveUser }
    $interactive = (-not [string]::IsNullOrWhiteSpace([string]$InteractiveUser))

    # -WindowStyle Hidden: the relaunched session is the interactive user's own
    # desktop, and the console would otherwise flash on top of the WPF window.
    # The /TR payload's INNER quotes are backslash-escaped because this whole
    # thing is handed to schtasks.exe as ONE -ArgumentList string and is parsed
    # by the standard C runtime rules, where \" inside a quoted value yields a
    # literal quote. Without them the -File path would be split at its first
    # space. /TN and /RU take plain quotes: they have no nested value.
    $tr = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\"' -f $ScriptPath

    # The /IT and /RL tokens are appended as one fragment rather than
    # interpolated separately, so the produced argument list has exactly one
    # /IT and exactly one /RL and neither can appear twice.
    $interactivePart = if ($interactive) { "/IT " } else { "" }
    return ('/TN "{0}" /TR "{1}" /SC ONLOGON /RU "{2}" {3}/RL HIGHEST /F' -f
            $script:AkariOSRelaunchTaskName, $tr, $user, $interactivePart)
}

function Invoke-AkariOSTaskCommandDefault {
    <#
    .SYNOPSIS
        The REAL create path: runs schtasks.exe with the argument list.
    .DESCRIPTION
        Reachable only as the -TaskWriter default. Mirrors Invoke-AkariOSEngine
        (-PassThru -Wait) so the caller learns the real exit code instead of
        assuming success. Returns an object exposing .ExitCode.
    #>
    [CmdletBinding()]
    param([string]$TaskWriterCommand)

    if (-not $TaskWriterCommand) { return [pscustomobject]@{ ExitCode = 1; Output = "" } }
    $TaskWriterProcess = Start-Process -FilePath "schtasks.exe" -ArgumentList $TaskWriterCommand -PassThru -Wait -NoNewWindow
    return [pscustomobject]@{ ExitCode = $TaskWriterProcess.ExitCode; Output = "" }
}

function Invoke-AkariOSTaskDeleteDefault {
    <#
    .SYNOPSIS
        The REAL self-cleanup path: deletes the relaunch task.
    .DESCRIPTION
        Called directly rather than through the & $TaskWriter indirection, so it
        can return BOTH the exit code and the text: schtasks reports a missing
        task as exit code 1 with "cannot find the file", which is the same exit
        code as a genuine failure. Without the text, "already deleted" and
        "deletion failed" would be indistinguishable and the idempotent
        self-cleanup (D-17) could not log one at INFO and the other at WARN.
    #>
    [CmdletBinding()]
    param([string]$TaskWriterCommand)

    $TaskWriterArgs = @()
    if ($TaskWriterCommand) { $TaskWriterArgs = @($TaskWriterCommand -split '\s+') }
    $TaskWriterOutput = & "schtasks.exe" @TaskWriterArgs 2>&1 | Out-String
    $TaskWriterCode = $LASTEXITCODE
    if ($null -eq $TaskWriterCode) { $TaskWriterCode = 1 }
    return [pscustomobject]@{ ExitCode = [int]$TaskWriterCode; Output = [string]$TaskWriterOutput }
}

function Get-AkariOSTaskDeleteCommand {
    <#
    .SYNOPSIS
        Builds the schtasks.exe argument list that DELETES the relaunch task.
    .DESCRIPTION
        Pure string builder, the delete counterpart of
        Get-AkariOSRelaunchTaskCommand, so /TN appears in exactly one place.
    #>
    [CmdletBinding()]
    param()

    return ('/delete /TN "{0}" /F' -f $script:AkariOSRelaunchTaskName)
}

function Test-AkariOSTaskAbsent {
    <#
    .SYNOPSIS
        True when an outcome's text means "the task was not there", not
        "the deletion failed".
    .DESCRIPTION
        The load-bearing predicate behind the idempotent self-cleanup. A missing
        task is the EXPECTED state on the second launch and on any machine where
        the user deleted it by hand, so it is INFO, never WARN. schtasks writes
        it to either stream depending on build and locale, so the wording is
        matched loosely and the exit code is not trusted as the signal.
    #>
    [CmdletBinding()]
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace([string]$Text)) { return $false }
    return ([string]$Text -match '(?i)(cannot find the file|not found|no tasks? (are )?scheduled)')
}

function Resolve-AkariOSTaskOutcome {
    <#
    .SYNOPSIS
        Normalises whatever a -TaskWriter returned into .ExitCode and .Output.
    .DESCRIPTION
        A stub may return a bare int, a Process-like object with .ExitCode, an
        object with .ExitCode/.Output, or nothing at all. "Nothing at all" is
        treated as FAILURE, not success: that is precisely the null-invoker
        false-success shape that shipped in Phase 2, and an outcome that cannot
        be read must never be read as a clean run.
    #>
    [CmdletBinding()]
    param($Result)

    if ($null -eq $Result) {
        return [pscustomobject]@{ ExitCode = 1; Output = ""; Readable = $false }
    }
    $code = $null
    $text = ""
    if ($Result.PSObject.Properties.Name -contains "ExitCode") { $code = [int]$Result.ExitCode }
    elseif ($Result -is [int]) { $code = [int]$Result }
    if ($Result.PSObject.Properties.Name -contains "Output") { $text = [string]$Result.Output }
    if ($null -eq $code) {
        return [pscustomobject]@{ ExitCode = 1; Output = $text; Readable = $false }
    }
    return [pscustomobject]@{ ExitCode = [int]$code; Output = $text; Readable = $true }
}

function Set-AkariOSRelaunchTask {
    <#
    .SYNOPSIS
        Creates the logon-time relaunch task, through an overridable seam.
    .DESCRIPTION
        Called from the Stage 3 branch of Invoke-AkariOSStage, AFTER
        Copy-AkariOSRelaunchScript has staged the file and BEFORE the engine
        child is launched. A task pointing at a script that is not on disk is
        worse than no task, so a failed staging is fatal to this call and a
        failed creation is only a WARN: Stage 3 must survive it.

        Returns $true/$false. NEVER throws.

        Null-invoker fallback: Invoke-AkariOSStage declares -TaskWriter without a
        default, so a caller that omits it binds $null, and "& $null $cmd"
        launches nothing while returning nothing - indistinguishable from a
        clean create. The exact bug that shipped in Phase 2 as T-02-32. The
        fallback below is why this function can be called with -TaskWriter $null
        and still reach the real launcher.
    .PARAMETER ScriptPath
        Path of the staged script. Pinned by the harness to a scratch file.
    .PARAMETER InteractiveUser
        Account the task runs as. Resolved when omitted.
    .PARAMETER TaskWriter
        Overrides the schtasks invocation. Receives the argument-list string and
        returns an exit code, or an object exposing .ExitCode (and .Output).
    #>
    [CmdletBinding()]
    param(
        [string]$ScriptPath = (Get-AkariOSRelaunchScriptPath),
        [string]$InteractiveUser,
        [scriptblock]$TaskWriter
    )

    if (-not $TaskWriter) {
        $TaskWriter = { param($TaskWriterCommand) Invoke-AkariOSTaskCommandDefault -TaskWriterCommand $TaskWriterCommand }
    }

    if ([string]::IsNullOrWhiteSpace([string]$ScriptPath)) {
        Write-AkariOSLog -Level ERROR -Message "Relaunch task not created: no staged script path is known."
        return $false
    }
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-AkariOSLog -Level ERROR -Message ("Relaunch task not created: the staged script is missing ({0}). A task pointing at a file that is not there is worse than no task." -f $ScriptPath)
        return $false
    }

    # An EXPLICIT -InteractiveUser (including an explicit $null) is honoured as
    # given; the machine is only interrogated when the caller omitted the
    # parameter. $PSBoundParameters distinguishes the two, and getting it wrong
    # would silently re-resolve an explicitly degraded call - which is why the
    # D-14 WARN below has to be reachable from a caller that asked for $null.
    if ($PSBoundParameters.ContainsKey('InteractiveUser')) {
        $resolvedUser = $InteractiveUser
    } else {
        $resolvedUser = Get-AkariOSInteractiveUser
    }

    if (-not $resolvedUser) {
        # D-14 degradation, logged so it is never silent: /RU SYSTEM without /IT
        # means the window may land on session 0's phantom desktop.
        Write-AkariOSLog -Level WARN -Message "Interactive account could not be resolved - the relaunch task falls back to /RU SYSTEM without /IT, so the relaunched window may not be visible."
    }

    $command = Get-AkariOSRelaunchTaskCommand -ScriptPath $ScriptPath -InteractiveUser $resolvedUser
    if (-not $command) {
        Write-AkariOSLog -Level ERROR -Message "Relaunch task not created: the schtasks argument list could not be built."
        return $false
    }

    try {
        $raw = & $TaskWriter $command
    } catch {
        Write-AkariOSLog -Level WARN -Message ("Relaunch task could not be created ({0}). Stage 3 continues; the completion screen will have to be opened by hand." -f ($_.Exception.Message))
        return $false
    }

    $outcome = Resolve-AkariOSTaskOutcome -Result $raw
    if (-not $outcome.Readable -or $outcome.ExitCode -ne 0) {
        Write-AkariOSLog -Level WARN -Message ("Relaunch task creation failed (schtasks exit code {0}). Stage 3 continues; the completion screen will have to be opened by hand." -f $outcome.ExitCode)
        return $false
    }

    Write-AkariOSLog -Level INFO -Message ("Queued relaunch task '{0}' for {1} -> {2}" -f $script:AkariOSRelaunchTaskName, $resolvedUser, $ScriptPath)
    return $true
}

function Remove-AkariOSRelaunchTask {
    <#
    .SYNOPSIS
        Deletes the relaunch task. Idempotent, and NEVER throws (D-17).
    .DESCRIPTION
        Called by the launch step AFTER the completion summary has been shown,
        so a failure while building the summary leaves both the screen and a
        working re-run path.

        IDEMPOTENT BY CONTRACT, and that is the load-bearing property:
          task exists        -> $true,  INFO
          task already absent -> $false, INFO (never WARN)
          writer throws      -> $false, WARN, exception NOT propagated

        A missing task is the EXPECTED state on the second launch and on any
        machine where the user removed it by hand, so treating it as an error
        would put a permanent WARN in the log of every healthy second launch.
        Equally, a self-cleanup that can crash the app is worse than one that
        leaves a task behind, so a writer that throws is swallowed.

        Null-invoker fallback as in Set-AkariOSRelaunchTask (T-02-32).
    .PARAMETER TaskWriter
        Overrides the schtasks invocation. Returns an exit code, or an object
        exposing .ExitCode (and .Output, which is how "already absent" is
        distinguished from "deletion failed").
    #>
    [CmdletBinding()]
    param(
        [scriptblock]$TaskWriter
    )

    

    if (-not $TaskWriter) {
        $TaskWriter = { param($TaskWriterCommand) Invoke-AkariOSTaskDeleteDefault -TaskWriterCommand $TaskWriterCommand }
    }

    $command = Get-AkariOSTaskDeleteCommand

    try {
        $raw = & $TaskWriter $command
    } catch {
        Write-AkariOSLog -Level WARN -Message ('Relaunch task ''{0}'' could not be deleted ({1}). Remove it by hand: schtasks /delete /TN "{0}" /F' -f $script:AkariOSRelaunchTaskName, $_.Exception.Message)
        return $false
    }

    $outcome = Resolve-AkariOSTaskOutcome -Result $raw
    if ($outcome.Readable -and $outcome.ExitCode -eq 0) {
        Write-AkariOSLog -Level INFO -Message ("Deleted relaunch task '{0}'." -f $script:AkariOSRelaunchTaskName)
        return $true
    }

    if (Test-AkariOSTaskAbsent -Text $outcome.Output) {
        Write-AkariOSLog -Level INFO -Message ("Relaunch task '{0}' was already absent - nothing to delete." -f $script:AkariOSRelaunchTaskName)
        return $false
    }

    Write-AkariOSLog -Level WARN -Message ('Relaunch task ''{0}'' was not deleted (schtasks exit code {1}). Remove it by hand: schtasks /delete /TN "{0}" /F' -f $script:AkariOSRelaunchTaskName, $outcome.ExitCode)
    return $false
}

function Copy-AkariOSRelaunchScript {
    <#
    .SYNOPSIS
        Stages a copy of the running script where the relaunch task can find it
        (D-15), through an overridable seam.
    .DESCRIPTION
        The task's command line must point at something that will still be there
        at the next logon. The user may have run akarios.ps1 from Downloads, from
        a temp path, or from a file they have since deleted, so pointing the task
        at the running script's own path is not safe.

        Returns the destination path, or $null with an ERROR log when the source
        cannot be resolved or the copy fails - a relaunch task pointing at a
        nonexistent file is worse than no task, so this failure must be visible.
    .PARAMETER SourcePath
        File to copy. Defaults to the running script's own path.
    .PARAMETER Destination
        Where to write it. Defaults to %ProgramData%\AkariOS\akarios.ps1,
        derived from the house state constant.
    .PARAMETER FileCopier
        Overrides the copy. Receives $Source and $Destination.
    #>
    [CmdletBinding()]
    param(
        [string]$SourcePath = $script:AkariOSRelaunchRunningScript,
        [string]$Destination = (Get-AkariOSRelaunchScriptPath),
        [scriptblock]$FileCopier
    )

    if (-not $FileCopier) {
        $FileCopier = {
            param($Source, $Destination)
            [System.IO.File]::Copy($Source, $Destination, $true)
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$SourcePath)) {
        Write-AkariOSLog -Level ERROR -Message "Relaunch script was not staged: the running script's own path could not be resolved, so there is nothing to copy."
        return $null
    }
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        Write-AkariOSLog -Level ERROR -Message ("Relaunch script was not staged: the source does not exist ({0})." -f $SourcePath)
        return $null
    }
    if ([string]::IsNullOrWhiteSpace([string]$Destination)) {
        Write-AkariOSLog -Level ERROR -Message "Relaunch script was not staged: no destination directory could be resolved."
        return $null
    }

    try {
        $dir = Split-Path -Path $Destination -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        }
        & $FileCopier $SourcePath $Destination
    } catch {
        Write-AkariOSLog -Level ERROR -Message ("Relaunch script was not staged ({0})." -f $_.Exception.Message)
        return $null
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        Write-AkariOSLog -Level ERROR -Message ("Relaunch script was not staged: the copier reported success but nothing exists at {0}." -f $Destination)
        return $null
    }

    Write-AkariOSLog -Level INFO -Message ("Staged relaunch script to {0}" -f $Destination)
    return $Destination
}