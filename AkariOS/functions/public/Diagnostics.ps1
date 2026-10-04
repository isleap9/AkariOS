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

function Reveal-StageError {
    <#
    .SYNOPSIS
        Fills the progress panel's error card and reveals it, or hides it again.
    .DESCRIPTION
        Touches WPF controls, so it is marshalled the same way Progress.ps1:107-124
        does: CheckAccess-then-BeginInvoke, never a blocking Invoke from a worker.

        The excerpt is rendered into StageErrorLog.Text — plain text, never Html or
        Rtf — so raw log content from a partially-failed system cannot inject markup
        (T-02-20). The excerpt is always the BOUNDED one Get-AkariOSStageFailure
        already gathered; this function never reads the log file itself.
    .PARAMETER Failure
        The object Get-AkariOSStageFailure returned, or $null to hide the card.
    #>
    [CmdletBinding()]
    param($Failure)

    $syncRef = $sync
    if (-not ($syncRef -and $syncRef.StageErrorDetail)) { return }

    $work = [System.Action]{
        if ($null -eq $Failure) {
            $syncRef.StageErrorDetail.Visibility = [System.Windows.Visibility]::Collapsed
            foreach ($btn in @("BtnStageRetry", "BtnStageAbort")) {
                if ($syncRef[$btn]) { $syncRef[$btn].IsEnabled = $false }
            }
            return
        }
        if ($syncRef.StageErrorTitle) {
            $syncRef.StageErrorTitle.Text = ("STAGE {0} FAILED" -f $Failure.Stage)
        }
        if ($syncRef.StageErrorMessage) {
            $msg = [string]$Failure.Detail
            if ($Failure.ExitCode -ne 0) { $msg = ("{0}`n`nEngine exit code: {1}" -f $msg, $Failure.ExitCode) }
            if ($Failure.RecordedAt)     { $msg = ("{0}`nRecorded at: {1}" -f $msg, $Failure.RecordedAt) }
            $syncRef.StageErrorMessage.Text = $msg
        }
        if ($syncRef.StageErrorLog) {
            $excerpt = @($Failure.LogTail)
            $syncRef.StageErrorLog.Text = if ($excerpt.Count) {
                ($excerpt -join [Environment]::NewLine)
            } else {
                "(no log excerpt available)"
            }
        }
        $syncRef.StageErrorDetail.Visibility = [System.Windows.Visibility]::Visible
        # The two actions become live only together with the card they belong to.
        # A visible Retry that is disabled is the same dead button as a hidden one.
        foreach ($btn in @("BtnStageRetry", "BtnStageAbort")) {
            if ($syncRef[$btn]) { $syncRef[$btn].IsEnabled = $true }
        }
    }.GetNewClosure()

    if ($syncRef.window) {
        $d = $syncRef.window.Dispatcher
        if ($d.CheckAccess()) { $work.Invoke() }
        else { $d.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $work) | Out-Null }
    } else {
        $work.Invoke()
    }
}

function Show-StageError {
    <#
    .SYNOPSIS
        Shows the failed-stage dialog and returns the user's choice: "retry" or "abort".
    .DESCRIPTION
        Built on the Show-ConfirmationGate shape (Confirm.ps1:42-207), for the same
        reason: a real System.Windows.Window with ShowDialog() gives identical
        blocking semantics through WPF's own modal loop, and every exit path resolves
        it explicitly so nothing can hang the app (T-02-21). The outcome lives in a
        HASHTABLE, not plain locals — GetNewClosure captures by VALUE, and a plain
        local mutated in a handler would be invisible here and the dialog would
        always report "abort".

        Escape, the X button and the window-close path all resolve to "abort".

        -DialogInvoker exists so a harness can drive the choice without a modal
        window appearing on the desktop. It is the ONLY way this function shows
        anything, so the default is still the real dialog.
    .PARAMETER Failure
        The object Get-AkariOSStageFailure returned.
    .PARAMETER LogPath
        install.log location, used when the failure carries no excerpt of its own.
    .PARAMETER LogCount
        Bound on the excerpt.
    .PARAMETER DialogInvoker
        Overrides the modal. Receives the failure object and returns "retry"/"abort".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Failure,
        [string]$LogPath = (Get-AkariOSLogPath),
        [int]$LogCount = $script:AkariOSErrorLogCount,
        [scriptblock]$DialogInvoker
    )

    # Always reveal the card first: even if the dialog itself fails, the detail and
    # the excerpt must still be on the progress panel.
    Reveal-StageError -Failure $Failure

    if ($DialogInvoker) { return ([string](& $DialogInvoker $Failure)) }

    if (-not $sync -or -not $sync.window) {
        # No window to own a modal (a test harness, or a very early failure).
        Write-AkariOSLog -Level WARN -Message "Stage error dialog unavailable - defaulting to abort."
        return "abort"
    }

    # Shared outcome - MUST be a reference type, see .DESCRIPTION.
    $choice = @{ Value = "abort" }

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction SilentlyContinue

    $excerpt = @($Failure.LogTail)
    if (-not $excerpt.Count) { $excerpt = @(Get-AkariOSLogTail -Count $LogCount -Path $LogPath) }

    # Danger palette, reused verbatim from Confirm.ps1:68-77.
    $dangerTx = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF3333")
    $dangerBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1AFF3333")
    $dangerBr = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#25FF4444")
    $accent   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CC2828")
    $panelBg  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#26262A")
    $btnBg    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#17FFFFFF")
    $btnBr    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#20FFFFFF")
    $secondary = [System.Windows.Media.Brushes]::LightGray
    $white     = [System.Windows.Media.Brushes]::White

    $dlg = New-Object System.Windows.Window
    $dlg.Title         = "AkariOS - stage failed"
    $dlg.Width         = 620
    $dlg.SizeToContent = "Height"
    $dlg.ResizeMode    = "NoResize"
    $dlg.WindowStartupLocation = "CenterOwner"
    $dlg.Background    = $panelBg
    $dlg.Foreground    = $white
    $dlg.FontFamily    = "Segoe UI Variable Text, Segoe UI"
    $dlg.FontSize      = 13
    $dlg.ShowInTaskbar = $false
    $dlg.Owner         = $sync.window

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = New-Object System.Windows.Thickness(24, 20, 24, 20)

    $heading = New-Object System.Windows.Controls.TextBlock
    $heading.Text = ("Stage {0} did not finish." -f $Failure.Stage)
    $heading.FontFamily = "Segoe UI Variable Display, Segoe UI"
    $heading.FontSize = 24
    $heading.FontWeight = "SemiBold"
    $heading.Foreground = $dangerTx
    $heading.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $heading.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    $stack.Children.Add($heading)

    $warnBorder = New-Object System.Windows.Controls.Border
    $warnBorder.Background = $dangerBg
    $warnBorder.BorderBrush = $dangerBr
    $warnBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $warnBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $warnBorder.Padding = New-Object System.Windows.Thickness(16, 12)
    $warnBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 14)
    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = [string]$Failure.Detail
    $warnText.Foreground = $dangerTx
    $warnText.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $warnBorder.Child = $warnText
    $stack.Children.Add($warnBorder)

    # Retry re-runs the WHOLE stage: the engine is verbatim (D-06) and exposes no
    # partial-state introspection, so there is nothing finer-grained to resume
    # (RESEARCH Decision 11). The user is told plainly before they choose.
    $advice = New-Object System.Windows.Controls.TextBlock
    $advice.Text = "Retry runs the whole stage again from the start. Abort clears this error and changes nothing else on the machine."
    $advice.Foreground = $secondary
    $advice.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $advice.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $stack.Children.Add($advice)

    $logScroll = New-Object System.Windows.Controls.ScrollViewer
    $logScroll.MaxHeight = 160
    $logScroll.VerticalScrollBarVisibility = "Auto"
    $logScroll.HorizontalScrollBarVisibility = "Disabled"
    $logScroll.Margin = New-Object System.Windows.Thickness(0, 0, 0, 14)
    $logText = New-Object System.Windows.Controls.TextBlock
    # Plain text only: raw log content must never be interpreted as markup (T-02-20).
    $logText.Text = if ($excerpt.Count) { ($excerpt -join [Environment]::NewLine) } else { "(no log excerpt available)" }
    $logText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF9E9E")
    $logText.FontFamily = "Consolas, Cascadia Mono, Courier New"
    $logText.FontSize = 11
    $logScroll.Content = $logText
    $stack.Children.Add($logScroll)

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = "Horizontal"
    $btnRow.HorizontalAlignment = "Right"
    $btnRow.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)

    $btnRetry = New-Object System.Windows.Controls.Button
    $btnRetry.Content = "Retry Stage {0}" -f $Failure.Stage
    $btnRetry.MinWidth = 140
    $btnRetry.Padding = New-Object System.Windows.Thickness(20, 9)
    $btnRetry.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
    $btnRetry.Background = $accent
    $btnRetry.Foreground = $white
    $btnRetry.BorderBrush = $dangerBr
    $btnRetry.BorderThickness = New-Object System.Windows.Thickness(1)
    $btnRetry.Cursor = [System.Windows.Input.Cursor]::Hand

    $btnAbort = New-Object System.Windows.Controls.Button
    $btnAbort.Content = "Abort"
    $btnAbort.MinWidth = 120
    $btnAbort.Padding = New-Object System.Windows.Thickness(16, 7)
    $btnAbort.Background = $btnBg
    $btnAbort.Foreground = $white
    $btnAbort.BorderBrush = $btnBr
    $btnAbort.BorderThickness = New-Object System.Windows.Thickness(1)
    $btnAbort.Cursor = [System.Windows.Input.Cursor]::Hand

    $btnRow.Children.Add($btnAbort)
    $btnRow.Children.Add($btnRetry)
    $stack.Children.Add($btnRow)

    $dlg.Content = $stack

    # The outcome is written to the shared hashtable (a reference type, so it
    # survives the closure) and the dialog is resolved explicitly on both paths.
    $btnRetry.Add_Click({
        $choice.Value = "retry"
        $dlg.DialogResult = $true
    }.GetNewClosure())

    $btnAbort.Add_Click({
        $choice.Value = "abort"
        $dlg.DialogResult = $false
    }.GetNewClosure())

    # ShowDialog blocks until DialogResult is set. Escape, the X button and the
    # window-close path all leave $choice at its "abort" default, so none of them
    # can hang the app.
    try   { $dlg.ShowDialog() | Out-Null }
    finally { if ($dlg.IsVisible) { $dlg.Close() } }

    return [string]$choice.Value
}

function Resolve-StageFailure {
    <#
    .SYNOPSIS
        Carries out the user's choice: "retry" re-runs the stage, "abort" clears the record.
    .DESCRIPTION
        "retry" — re-runs the WHOLE stage through Invoke-AkariOSStage, the same
        path the first attempt used. Under D-06 the engine is verbatim and offers
        no partial-state introspection, so a whole-stage re-run is the only honest
        option (RESEARCH Decision 11, T-02-23). Logged before launching.

        "abort" — clears ONLY the LastError block and returns the state to
        'pending'. It touches neither the RunOnce entries nor the boot flag: under
        D-06 an abort that cleared the safeboot flag or deleted a RunOnce entry
        would be editing engine behaviour. That "without touching" half is a hard
        constraint, and a comment-stripped source assertion in the plan's verify
        step fails the build if either appears in this file (T-02-22).
    .PARAMETER Failure
        The object Get-AkariOSStageFailure returned.
    .PARAMETER Choice
        "retry" or "abort".
    .PARAMETER StatePath
        state.json location, for the abort branch.
    .PARAMETER StageInvoker
        Overrides the stage launch, so a harness can assert what retry would do.
        Receives the stage number and the -OnComplete callback.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Failure,
        [Parameter(Mandatory = $true)][ValidateSet("retry", "abort")][string]$Choice,
        [string]$StatePath = $script:AkariOSStateDefaultPath,
        [scriptblock]$StageInvoker = {
            param($n, $cb) Invoke-AkariOSStage -Stage $n -OnComplete $cb
        }
    )

    $stage = [int]$Failure.Stage
    if ($stage -lt 1 -or $stage -gt 3) {
        $stage = [int](Get-AkariOSState -Path $StatePath).CurrentStage
    }
    if ($stage -lt 1 -or $stage -gt 3) {
        Write-AkariOSLog -Level ERROR -Message "Cannot resolve a stage failure: the stage number is unknown."
        return $false
    }

    if ($Choice -eq "abort") {
        Clear-AkariOSStageFailure -StatePath $StatePath | Out-Null
        Reveal-StageError -Failure $null
        Write-AkariOSLog -Level WARN -Message (
            "Stage {0} failure cleared by the user (abort). No RunOnce entry and no boot setting was touched." -f $stage)
        if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
            Set-Status ("Stage {0} error cleared. Nothing else on the machine was changed." -f $stage) "#FFA726"
        }
        return $true
    }

    Write-AkariOSLog -Level WARN -Message (
        "Retrying Stage {0} in full after a recorded failure: {1}" -f $stage, $Failure.Detail)
    if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
        Set-Status ("Retrying Stage {0} - the whole stage runs again from the start." -f $stage) "#FFA726"
    }
    Reveal-StageError -Failure $null
    return [bool](& $StageInvoker $stage $null)
}

function Invoke-BtnStageRetry {
    <#
    .SYNOPSIS
        BtnStageRetry handler: re-run the stage that failed, in full.
    .DESCRIPTION
        Reads the current failure, shows the dialog when no choice was supplied yet,
        then hands the choice to Resolve-StageFailure. The dialog is only shown when
        there IS a recorded failure; with none, this is a no-op rather than a
        re-run of an arbitrary stage.
    #>
    [CmdletBinding()]
    param(
        [string]$StatePath = $script:AkariOSStateDefaultPath,
        [string]$LogPath = (Get-AkariOSLogPath),
        [scriptblock]$DialogInvoker,
        [scriptblock]$StageInvoker
    )

    $failure = Get-AkariOSStageFailure -StatePath $StatePath -LogPath $LogPath
    if (-not $failure) {
        Write-AkariOSLog -Level WARN -Message "Retry pressed with no recorded stage failure - nothing to do."
        return $false
    }

    $choice = Show-StageError -Failure $failure -LogPath $LogPath -DialogInvoker $DialogInvoker
    if ($choice -ne "retry") { $choice = "abort" }

    return (Resolve-StageFailure -Failure $failure -Choice $choice -StatePath $StatePath -StageInvoker $StageInvoker)
}

function Invoke-BtnStageAbort {
    <#
    .SYNOPSIS
        BtnStageAbort handler: clear the recorded failure and nothing else.
    .DESCRIPTION
        Reads the current failure and clears it through Clear-AkariOSStageFailure,
        which writes the state object back through the lossless `Object` set. No
        RunOnce entry and no boot flag is touched (D-06, T-02-22).
    #>
    [CmdletBinding()]
    param([string]$StatePath = $script:AkariOSStateDefaultPath)

    $failure = Get-AkariOSStageFailure -StatePath $StatePath
    if (-not $failure) {
        Write-AkariOSLog -Level WARN -Message "Abort pressed with no recorded stage failure - nothing to do."
        return $false
    }

    return (Resolve-StageFailure -Failure $failure -Choice "abort" -StatePath $StatePath)
}
