# -- Stage failure diagnostics (DIAG-02) ----------------------------------------
# Because the engine is verbatim (D-06) AkariOS cannot intercept a live failure
# from inside a running stage (D-09). What it CAN do is DETECT a failure after
# the fact: a stage that ended badly leaves a LastError block on the lightweight
# state file, and the next launch shows it with a bounded log excerpt plus a
# Retry and an Abort action (D-10).
#
# Every path parameter is injectable so the harness never touches the live
# machine: tests point -StatePath and -LogPath at a scratch directory. Nothing
# in this file writes a registry key, invokes bcdedit, or reboots anything —
# Abort clears the error record and nothing else, because editing the engine's
# boot or RunOnce state would be editing engine behaviour (D-06, T-02-22).

$script:AkariOSErrorLogCount = 20

function Get-AkariOSStageFailure {
    <#
    .SYNOPSIS
        Returns the recorded failure for the last stage, or $null when there is none.
    .DESCRIPTION
        An INDEPENDENT check against the state file, deliberately not a new
        Get-ResumePoint value (RESEARCH §7 Decision 3): Phase 1's verified D-03/D-05
        resume decision table and main.ps1's resume switch stay byte-identical.

        A failure is present when the state carries a LastError block OR when
        Status is "error" — the existing ValidateSet member from State.ps1:111,
        not a new status constant (T-02-24). The log excerpt is BOUNDED by
        Get-AkariOSLogTail -Count; the whole log is never read, and the excerpt is
        plain text for the dialog to render (T-02-20).
    .PARAMETER StatePath
        state.json location. Defaults to the house constant; override for tests.
    .PARAMETER LogPath
        install.log location. Defaults to Get-AkariOSLogPath; override for tests.
    .PARAMETER LogCount
        Maximum number of trailing log lines to attach to the failure.
    #>
    [CmdletBinding()]
    param(
        [string]$StatePath = $script:AkariOSStateDefaultPath,
        [string]$LogPath   = (Get-AkariOSLogPath),
        [int]$LogCount     = $script:AkariOSErrorLogCount
    )

    $state = Get-AkariOSState -Path $StatePath

    $block = $state.PSObject.Properties["LastError"]
    $hasBlock = ($null -ne $block) -and ($null -ne $block.Value)
    $isError = ([string]$state.Status -eq "error")

    if (-not ($hasBlock -or $isError)) { return $null }

    $stage      = [int]$state.CurrentStage
    $detail     = ""
    $exitCode   = 0
    $recordedAt = ""

    if ($hasBlock) {
        $le = $block.Value
        if ($null -ne $le.PSObject.Properties["Stage"])      { $stage      = [int]$le.Stage }
        if ($null -ne $le.PSObject.Properties["Detail"])     { $detail     = [string]$le.Detail }
        if ($null -ne $le.PSObject.Properties["ExitCode"])   { $exitCode   = [int]$le.ExitCode }
        if ($null -ne $le.PSObject.Properties["RecordedAt"]) { $recordedAt = [string]$le.RecordedAt }
    }

    if (-not $detail) {
        # Status said error but no detail was recorded — still report it rather
        # than silently looking healthy.
        $detail = ("Stage {0} reported status 'error' with no recorded detail." -f $stage)
    }

    $tail = @(Get-AkariOSLogTail -Count $LogCount -Path $LogPath)

    return [pscustomobject]@{
        Stage      = $stage
        Detail     = $detail
        ExitCode   = $exitCode
        RecordedAt = $recordedAt
        LogTail    = $tail
        LogText    = ($tail -join [Environment]::NewLine)
    }
}

function Set-AkariOSStageFailure {
    <#
    .SYNOPSIS
        Records a stage failure into the state file's LastError block.
    .DESCRIPTION
        Idempotent: the block is REPLACED, never nested, so calling this twice
        leaves exactly one block (T-02-19's sibling property).

        The write goes through the `Object` parameter set of Set-AkariOSState,
        which is the only lossless write path — it writes the object it is handed
        verbatim, while the `Fields` set rebuilds the object field by field.
    .PARAMETER Stage
        Stage number 1-3.
    .PARAMETER Detail
        The failure message shown to the user and stored in state.json.
    .PARAMETER ExitCode
        The engine child process's exit code, when there was one.
    .PARAMETER StatePath
        state.json location. Defaults to the house constant; override for tests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Stage,
        [Parameter(Mandatory = $true)][string]$Detail,
        [int]$ExitCode = 0,
        [string]$StatePath = $script:AkariOSStateDefaultPath
    )

    $obj = Get-AkariOSState -Path $StatePath

    $block = [pscustomobject]@{
        Stage      = $Stage
        Detail     = $Detail
        ExitCode   = $ExitCode
        RecordedAt = (Get-Date).ToUniversalTime().ToString("o")
    }

    # -Force replaces an existing block in place; no nesting, no duplicates.
    $obj | Add-Member -NotePropertyName "LastError" -NotePropertyValue $block -Force
    $obj.Status = "error"
    if ($obj.CurrentStage -lt 1) { $obj.CurrentStage = $Stage }

    return (Set-AkariOSState -Path $StatePath -State $obj)
}

function Clear-AkariOSStageFailure {
    <#
    .SYNOPSIS
        Removes the LastError block and returns the state to 'pending' for a stage.
    .DESCRIPTION
        The EXACT clearing mechanism, and it is not the obvious one: the `Fields`
        parameter set RE-CARRIES LastError from the on-disk base object, so
        `Set-AkariOSState -Fields @{ ... }` can never clear the block — it copies
        it straight back. Reading the object, removing the property and writing it
        back through the `Object` set is the only way to actually lose it.

        This touches nothing else: no RunOnce entry, no boot flag, no engine file.
        Aborting a failed stage is a GUI-level decision and MUST NOT edit engine
        behaviour (D-06, D-10, T-02-22).
    .PARAMETER StatePath
        state.json location. Defaults to the house constant; override for tests.
    #>
    [CmdletBinding()]
    param([string]$StatePath = $script:AkariOSStateDefaultPath)

    $obj = Get-AkariOSState -Path $StatePath
    $obj.Status = "pending"
    $obj.PSObject.Properties.Remove("LastError")

    return (Set-AkariOSState -Path $StatePath -State $obj)
}
