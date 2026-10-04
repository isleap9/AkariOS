# ── AkariOS state persistence ───────────────────────────────────────────────
# state.json holds FINE-GRAINED within-stage progress (PROG-01: "Step N of 3" plus
# the current action text). Cross-reboot stage tracking does NOT live here — that
# is the RunOnce registry entries + the bcdedit safeboot flag (see Resume.ps1).
#
# The file lives at C:\ProgramData\AkariOS\state.json because it must survive
# cleanmgr and C:\Windows\Temp cleanup (STATE.md risk log).
#
# T-01-STATE: state file corruption must not produce a wrong resume point, so
# writes are atomic (temp file + in-place replace) and reads are validated.

# The real on-disk location. Every function takes -Path so tests can point at a
# scratch directory instead of the live machine's ProgramData.
$script:AkariOSStateDefaultPath = "C:\ProgramData\AkariOS\state.json"

function New-AkariOSState {
    <#
    .SYNOPSIS
        Returns a fresh default state object.
    #>
    [CmdletBinding()]
    param(
        [int]$CurrentStage = 0,
        [string]$Status = "pending",
        [int]$Progress = 0,
        [string]$CurrentAction = ""
    )
    [pscustomobject]@{
        SchemaVersion = 1
        CurrentStage  = $CurrentStage
        Status        = $Status
        Progress      = $Progress
        CurrentAction = $CurrentAction
        RebootPending = $false
        UpdatedAt     = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Test-AkariOSState {
    <#
    .SYNOPSIS
        Validates a deserialized state object. T-01-STATE: a corrupt or partial
        state file must be rejected so we can fall back to the default rather
        than resuming from nonsense.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $true)]$State)

    process {
        if ($null -eq $State) { return $false }
        # Required properties must be present.
        foreach ($p in @("SchemaVersion", "CurrentStage", "Status", "Progress", "CurrentAction")) {
            if ($null -eq $State.PSObject.Properties[$p]) { return $false }
        }
        # Types and ranges must be sane. ConvertFrom-Json yields Int64 for whole
        # numbers on PS 5.1, so accept either integer width.
        if (-not ($State.CurrentStage -is [int] -or $State.CurrentStage -is [long])) { return $false }
        if ($State.CurrentStage -lt 0 -or $State.CurrentStage -gt 3)  { return $false }
        if (-not ($State.Progress -is [int] -or $State.Progress -is [long])) { return $false }
        if ($State.Progress -lt 0 -or $State.Progress -gt 100)       { return $false }
        if ([string]$State.Status -notin @("pending", "running", "completed", "error")) { return $false }
        return $true
    }
}

function Get-AkariOSState {
    <#
    .SYNOPSIS
        Reads state.json and returns a validated state object, or the default when
        the file is missing or corrupt.
    #>
    [CmdletBinding()]
    param([string]$Path = $script:AkariOSStateDefaultPath)

    if (-not (Test-Path -LiteralPath $Path)) { return (New-AkariOSState) }

    $raw = $null
    try { $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop }
    catch { return (New-AkariOSState) }

    if ([string]::IsNullOrWhiteSpace($raw)) { return (New-AkariOSState) }

    $obj = $null
    try { $obj = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $obj = $null }

    if (-not (Test-AkariOSState $obj)) {
        # Corrupt or schema-unknown state: log-worthy, and fall back to default.
        return (New-AkariOSState)
    }
    return $obj
}

function Set-AkariOSState {
    <#
    .SYNOPSIS
        Writes state.json atomically (temp file + replace).
    .DESCRIPTION
        Writing to a temp file in the same directory and then replacing the target
        means a crash or power loss mid-write can never leave a half-written
        state.json behind — the reader either sees the old file or the new one.
    .PARAMETER Path
        Defaults to %ProgramData%\AkariOS\state.json. Override for tests.
    .PARAMETER State
        A complete state object to write. Mutually exclusive with the field params.
    #>
    [CmdletBinding(DefaultParameterSetName = "Fields")]
    param(
        [string]$Path = $script:AkariOSStateDefaultPath,
        [Parameter(ParameterSetName = "Object")][psobject]$State,
        [Parameter(ParameterSetName = "Fields")][int]$CurrentStage,
        [Parameter(ParameterSetName = "Fields")][ValidateSet("pending", "running", "completed", "error")][string]$Status,
        [Parameter(ParameterSetName = "Fields")][ValidateRange(0, 100)][int]$Progress,
        [Parameter(ParameterSetName = "Fields")][string]$CurrentAction,
        [Parameter(ParameterSetName = "Fields")][bool]$RebootPending
    )

    if ($PSCmdlet.ParameterSetName -eq "Object") {
        $toWrite = $State
        if (-not (Test-AkariOSState $toWrite)) { throw "Refusing to write invalid state object." }
    } else {
        # Start from what is on disk so a partial update does not wipe other fields.
        $base = Get-AkariOSState -Path $Path
        $toWrite = New-AkariOSState -CurrentStage $base.CurrentStage `
                                 -Status       $base.Status `
                                 -Progress     $base.Progress `
                                 -CurrentAction $base.CurrentAction
        $toWrite.RebootPending = $base.RebootPending
        # Carry the LastError block across the partial update (T-02-26).
        #
        # This branch rebuilds the object field by field, so ANY property the base
        # carries that is not listed above silently vanishes — and Progress.ps1:101
        # issues a partial update on every progress tick, which used to erase a
        # recorded failure the moment the UI refreshed. Guarded on the property
        # existing, so behaviour is unchanged for every state file written before
        # this phase, and deliberately NOT a copy-everything loop: that would start
        # persisting whatever a future caller happens to invent. Clearing the block
        # is Clear-AkariOSStageFailure's job, via the lossless `Object` set.
        if ($base.PSObject.Properties["LastError"]) {
            $toWrite.PSObject.Properties.Add(
                [System.Management.Automation.PSNoteProperty]::new("LastError", $base.LastError))
        }
        if ($PSBoundParameters.ContainsKey("CurrentStage"))  { $toWrite.CurrentStage  = $CurrentStage }
        if ($PSBoundParameters.ContainsKey("Status"))        { $toWrite.Status        = $Status }
        if ($PSBoundParameters.ContainsKey("Progress"))      { $toWrite.Progress      = $Progress }
        if ($PSBoundParameters.ContainsKey("CurrentAction")) { $toWrite.CurrentAction = $CurrentAction }
        if ($PSBoundParameters.ContainsKey("RebootPending")) { $toWrite.RebootPending = $RebootPending }
    }
    $toWrite.UpdatedAt = (Get-Date).ToUniversalTime().ToString("o")

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $json = ($toWrite | ConvertTo-Json -Depth 4)
    # Temp file in the SAME directory so the replace is a same-volume NTFS rename.
    # [System.IO.File]::Replace requires a NON-NULL backup path (passing $null throws
    # "path is not of a legal form"), so we give it a scratch backup and drop it.
    $token  = [guid]::NewGuid().ToString("N")
    $tmp    = Join-Path $dir (".state.$token.tmp")
    $backup = Join-Path $dir (".state.$token.bak")
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))

    try {
        if (Test-Path -LiteralPath $Path) {
            # Atomic same-volume swap: readers see either the old file or the new one.
            [System.IO.File]::Replace($tmp, $Path, $backup)
            Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        } else {
            [System.IO.File]::Move($tmp, $Path)
        }
    } catch {
        # Fall back to a non-atomic overwrite only if Replace is unsupported.
        foreach ($leftover in @($tmp, $backup)) {
            if (Test-Path -LiteralPath $leftover) { Remove-Item -LiteralPath $leftover -Force -ErrorAction SilentlyContinue }
        }
        throw "Failed to write state atomically to '$Path': $($_.Exception.Message)"
    }

    return $toWrite
}

function Initialize-AkariOSState {
    <#
    .SYNOPSIS
        Creates the default state file if it does not already exist. Never
        overwrites an existing state file — that would erase a real resume point.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $script:AkariOSStateDefaultPath,
        [switch]$Force
    )

    $existing = Get-AkariOSState -Path $Path
    if (-not $Force -and (Test-Path -LiteralPath $Path)) {
        # A file is already there: keep it, even if it failed validation above
        # (which just means we returned the default shape).
        return $existing
    }
    return (Set-AkariOSState -Path $Path -State (New-AkariOSState))
}

function Reset-AkariOSState {
    <#
    .SYNOPSIS
        Removes state.json. Used when an install completes or is cancelled, and by
        the "try again" path after an inconsistent state (D-05).
    #>
    [CmdletBinding()]
    param([string]$Path = $script:AkariOSStateDefaultPath)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}