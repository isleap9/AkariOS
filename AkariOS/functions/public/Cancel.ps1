# -- Cancel logic (SAFE-04) ------------------------------------------------------
# Cancel is only safe while the machine is NOT in a transitional state. Once the
# first reboot is imminent (or done), Windows is mid-flight and killing the
# process would leave a half-configured boot. So:
#
#   Stage 1, before the reboot  -> cancel allowed
#   anything at/after the reboot -> cancel disabled, with the UI-SPEC reason
#
# Get-CanCancel reads the CURRENT stage from state.json. It is a pure decision on
# state; it never touches the registry or bcdedit itself (Resume.ps1 owns those).

$script:AkariOSCancelDisabledReason = "Cancel is disabled because the machine is in a transitional state ({0}). Wait for the current step to complete."

function Get-CancelDisabledReason {
    <#
    .SYNOPSIS
        The UI-SPEC sentence explaining why cancel is unavailable, with the
        current action substituted in (SAFE-04).
    #>
    [CmdletBinding()]
    param([string]$CurrentAction = "the current step")

    return ($script:AkariOSCancelDisabledReason -f $CurrentAction)
}

function Get-CanCancel {
    <#
    .SYNOPSIS
        Returns $true only while Stage 1 is running and the first reboot has NOT
        yet been triggered (SAFE-04).
    .DESCRIPTION
        Cancel is refused in every case other than an active, non-rebooting
        Stage 1. In particular it is refused for stage1-with-reboot-pending,
        stage2, stage3, complete, and any inconsistent state - the UI-SPEC rule
        is "cancel only in Stage 1", and the transitional state inside Stage 1
        is exactly where cancelling is unsafe.
    .PARAMETER State
        Optional state object. Defaults to reading the real state.json.
    .PARAMETER StatePath
        Injectable state path, for testing and for the runspace.
    #>
    [CmdletBinding()]
    param($State,
          [string]$StatePath = $script:AkariOSStateDefaultPath)

    if ($null -eq $State) {
        if (-not (Get-Command Get-AkariOSState -ErrorAction SilentlyContinue)) {
            # No state layer loaded: be conservative and refuse to cancel.
            return $false
        }
        $State = Get-AkariOSState -Path $StatePath
    }

    # Must be actively installing Stage 1.
    if ($State.Status -ne "installing") { return $false }
    if ([int]$State.CurrentStage -ne 1) { return $false }

    # The moment the reboot is queued the machine is transitional.
    if ([bool]$State.RebootPending)    { return $false }

    return $true
}

function Invoke-BtnCancel {
    <#
    .SYNOPSIS
        Cancel button handler. Resets state, reports it, and returns the user to
        the home panel. Refuses, with the UI-SPEC reason, once the machine is
        transitional (SAFE-04).
    #>
    [CmdletBinding()]
    param($State,
          [string]$StatePath = $script:AkariOSStateDefaultPath)

    if (-not (Get-CanCancel -State $State -StatePath $StatePath)) {
        $action = "the current step"
        if ($State -and $State.CurrentAction) { $action = $State.CurrentAction }
        $reason = Get-CancelDisabledReason -CurrentAction $action
        Write-AkariOSLog -Level WARN -Message "Cancel refused: $reason"
        if ($sync.CancelDisabledReason) { $sync.CancelDisabledReason.Text = $reason }
        [System.Windows.MessageBox]::Show($reason, "AkariOS Setup") | Out-Null
        return
    }

    if (Get-Command Reset-AkariOSState -ErrorAction SilentlyContinue) {
        Reset-AkariOSState -Path $StatePath
    }
    Write-AkariOSLog -Level INFO -Message "Install cancelled by the user during Stage 1; state reset."

    Set-Status "Install cancelled. Nothing was changed." "#AAAAAA"
    if ($sync.CancelDisabledReason) {
        $sync.CancelDisabledReason.Text = Get-CancelDisabledReason -CurrentAction "no step is running"
    }
    Show-Panel "PanelHome"
}

function Sync-CancelButton {
    <#
    .SYNOPSIS
        Applies Get-CanCancel to the cancel button's IsEnabled and refreshes the
        disabled reason text (SAFE-04).
    #>
    [CmdletBinding()]
    param($State,
          [string]$StatePath = $script:AkariOSStateDefaultPath)

    if (-not $sync -or -not $sync.BtnCancel) { return }

    $canCancel = Get-CanCancel -State $State -StatePath $StatePath
    $sync.BtnCancel.IsEnabled = [bool]$canCancel

    $action = "no step is running"
    if ($State -and $State.CurrentAction) { $action = $State.CurrentAction }
    if ($sync.CancelDisabledReason) {
        $sync.CancelDisabledReason.Text = Get-CancelDisabledReason -CurrentAction $action
    }
    return $canCancel
}