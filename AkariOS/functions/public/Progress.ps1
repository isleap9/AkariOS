# -- Progress reporting (PROG-01, PROG-02, PROG-03) -----------------------------
# The progress panel always shows:
#   "Step {N} of 3: {current action}"      (PROG-01)
#   a progress bar reflecting stage position
#   "Resuming Step {N} of 3"                (PROG-02)
#
# These functions are UI-agnostic about THREAD: they may be called from the UI
# thread or from a runspace worker. When $sync is available they marshal through
# the dispatcher so the runspace does not touch WPF objects directly.

$script:AkariOSProgressDefault = "Not started"

function Format-ProgressStep {
    <#
    .SYNOPSIS
        The canonical "Step {N} of 3: {action}" string (PROG-01).
    #>
    [CmdletBinding()]
    param([int]$Stage = 0,
          [string]$Action)

    if (-not $Action) { $Action = $script:AkariOSProgressDefault }
    return "Step {0} of 3: {1}" -f $Stage, $Action
}

function Format-ResumeStep {
    <#
    .SYNOPSIS
        The canonical "Resuming Step {N} of 3" string (PROG-02).
    #>
    [CmdletBinding()]
    param([int]$Stage = 1)
    return "Resuming Step {0} of 3" -f $Stage
}

function Get-StagePercent {
    <#
    .SYNOPSIS
        Maps a stage number and an optional within-stage fraction (0.0-1.0) onto
        the overall 0-100 progress bar value, using the stage boundaries from
        Stage.ps1.
    #>
    [CmdletBinding()]
    param([int]$Stage = 0,
          [double]$Fraction = 0.0,
          [string]$Action)

    if ($Stage -lt 1) { return 0 }
    if ($Fraction -lt 0) { $Fraction = 0 }
    if ($Fraction -gt 1) { $Fraction = 1 }

    $record = Get-AkariOSStage -Number $Stage
    if (-not $record) { return 0 }

    return [int]([Math]::Round($record.PercentStart + ($record.PercentEnd - $record.PercentStart) * $Fraction))
}

function Update-ProgressDisplay {
    <#
    .SYNOPSIS
        Updates "Step N of 3", the progress bar and the action/detail text
        (PROG-01).
    .DESCRIPTION
        Safe to call from a runspace: if a dispatcher is available the UI work is
        marshalled onto it, otherwise it is applied directly.
    .PARAMETER Stage
        Stage number 0-3. 0 means "not started".
    .PARAMETER Action
        Current action text, shown after the colon.
    .PARAMETER Percent
        Explicit bar value 0-100. When omitted it is derived from Stage/Fraction.
    .PARAMETER Fraction
        Within-stage completion 0.0-1.0, used when Percent is omitted.
    .PARAMETER Detail
        Secondary line under the action text.
    .PARAMETER Resume
        When set, show the PROG-02 "Resuming Step N of 3" headline instead.
    #>
    [CmdletBinding()]
    param([int]$Stage = 0,
          [string]$Action,
          [int]$Percent = -1,
          [double]$Fraction = 0.0,
          [string]$Detail = "",
          [switch]$Resume)

    if ($Percent -lt 0) { $Percent = Get-StagePercent -Stage $Stage -Fraction $Fraction -Action $Action }

    if ($Resume -and $Stage -ge 1) {
        $stepText = Format-ResumeStep -Stage $Stage
    } else {
        $stepText = Format-ProgressStep -Stage $Stage -Action $Action
    }

    Write-AkariOSLog -Level INFO -Message ("Progress: {0} ({1}%)" -f $stepText, $Percent)

    # Persist the within-stage position so a resume can pick it up.
    if (Get-Command Set-AkariOSState -ErrorAction SilentlyContinue) {
        try {
            $s = Get-AkariOSState
            $s.Stage = $Stage
            if ($Action) { $s.CurrentAction = $Action }
            $s.StagePercent = $Percent
            Set-AkariOSState -State $s
        } catch {
            Write-AkariOSLog -Level WARN -Message "Could not persist progress: $_"
        }
    }

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
}

function Set-CurrentStage {
    <#
    .SYNOPSIS
        Switches the UI to a stage: shows the progress panel, sets the headline
        for that stage, refreshes the cancel button, and writes the log.
    .PARAMETER Stage
        Stage number 1-3.
    .PARAMETER Action
        Optional current action; defaults to the stage description.
    .PARAMETER Resume
        Show the PROG-02 resume wording.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$Stage,
          [string]$Action,
          [switch]$Resume)

    if (-not $Action) {
        $info = Get-StageExplanation -Number $Stage
        $Action = $info.Description
    }

    Write-AkariOSLog -Level INFO -Message ("Entering stage {0}." -f $Stage)

    if (Get-Command Show-Panel -ErrorAction SilentlyContinue) {
        Show-Panel "PanelProgress"
    }

    Update-ProgressDisplay -Stage $Stage -Action $Action -Resume:$Resume -Fraction 0

    # Stage 1 can still be cancelled; later stages cannot (SAFE-04).
    if (Get-Command Sync-CancelButton -ErrorAction SilentlyContinue) {
        Sync-CancelButton | Out-Null
    }
}

function Set-ProgressIdle {
    <#
    .SYNOPSIS
        Resets the progress panel to its pre-install state: "Step 0 of 3", an
        empty bar, and the waiting message.
    #>
    [CmdletBinding()]
    param()

    Update-ProgressDisplay -Stage 0 -Action $script:AkariOSProgressDefault -Percent 0 -Detail ""
}