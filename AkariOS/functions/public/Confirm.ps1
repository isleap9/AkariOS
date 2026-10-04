# -- Confirmation gate (SAFE-02) ---------------------------------------------
# The install is destructive and irreversible in places, so the user must type
# AKARIOS before Stage 1 begins.
#
# DESIGN NOTE (Phase 1):
# This gate builds a small modal WPF Window and calls ShowDialog(). An earlier
# revision drove the MainWindow.xaml overlay from inside a private
# DispatcherFrame/PushFrame loop; that was fragile, because a "finished" flag that
# was never set left the loop spinning forever and hung the app. ShowDialog() has
# identical blocking semantics but uses WPF's own modal loop, and every exit path
# here resolves the dialog explicitly, so there is no unbounded wait.
#
# The exact wording is fixed by 01-UI-SPEC.md and must not be paraphrased.

$script:AkariOSConfirmToken   = "AKARIOS"
$script:AkariOSConfirmHeading = "Confirm Installation"
$script:AkariOSConfirmBody    = "You are about to make significant changes to your Windows installation. Please review what will happen:"
$script:AkariOSConfirmWarning = "Type AKARIOS to confirm: This will disable Windows Defender, UAC, memory integrity, VBS, and the vulnerable-driver blocklist. It will remove Edge, UWP apps, and GPU/audio drivers. These changes are not easily reversible. A system restore point is recommended."
$script:AkariOSConfirmPrompt  = "Type AKARIOS to confirm you understand:"
$script:AkariOSConfirmError   = "Confirmation text does not match. Please type AKARIOS exactly."

function Test-AkariOSConfirmation {
    <#
    .SYNOPSIS
        Pure predicate: does this input match the required token? (SAFE-02)
    .DESCRIPTION
        Case-SENSITIVE exact match on the whole trimmed string, so "AKARIOS" passes
        while "akarios", "AKARIOS!", "AKARIOS please", "AKARI0S" and the empty
        string all fail. Kept separate from the UI so the rule is verifiable
        without a window.
    #>
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string]$InputText,
          [string]$Token = $script:AkariOSConfirmToken)

    if ($null -eq $InputText) { return $false }
    $trimmed = $InputText.Trim()
    if ($trimmed.Length -eq 0) { return $false }
    return [string]::Equals($trimmed, $Token, [System.StringComparison]::Ordinal)
}

function Show-ConfirmationGate {
    <#
    .SYNOPSIS
        Shows the confirmation gate. Returns $true ONLY if the user typed the
        exact token and pressed "I Understand"; $false for cancel, Escape, or a
        window close (SAFE-02).
    .DESCRIPTION
        The typed text and the outcome live in a HASHTABLE, not plain locals:
        ScriptBlock.GetNewClosure() captures variables BY VALUE, so a plain
        $confirmed local mutated inside a handler would never be visible here and
        the gate would always report "not confirmed".
    .PARAMETER Token
        Override the required token. Defaults to AKARIOS.
    #>
    [CmdletBinding()]
    param([string]$Token = $script:AkariOSConfirmToken)

    if (-not $sync -or -not $sync.window) {
        throw "Confirmation gate UI is unavailable."
    }

    # Shared state - MUST be a reference type, see .DESCRIPTION.
    $state = @{ Confirmed = $false }

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction SilentlyContinue

    $accent    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CC2828")
    $accentHi  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E03535")
    $dangerTx  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF3333")
    $dangerBg  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1AFF3333")
    $dangerBr  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#25FF4444")
    $panelBg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#26262A")
    $btnBg     = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#17FFFFFF")
    $btnBr     = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#20FFFFFF")
    $secondary = [System.Windows.Media.Brushes]::LightGray
    $white     = [System.Windows.Media.Brushes]::White

    $dlg = New-Object System.Windows.Window
    $dlg.Title         = $script:AkariOSConfirmHeading
    $dlg.Width         = 560
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
    $heading.Text = $script:AkariOSConfirmHeading
    $heading.FontFamily = "Segoe UI Variable Display, Segoe UI"
    $heading.FontSize = 28
    $heading.FontWeight = "SemiBold"
    $heading.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $heading.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    $stack.Children.Add($heading)

    $body = New-Object System.Windows.Controls.TextBlock
    $body.Text = $script:AkariOSConfirmBody
    $body.Foreground = $secondary
    $body.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $body.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    $stack.Children.Add($body)

    # Danger card holding the UI-SPEC warning text.
    $warnBorder = New-Object System.Windows.Controls.Border
    $warnBorder.Background = $dangerBg
    $warnBorder.BorderBrush = $dangerBr
    $warnBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $warnBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $warnBorder.Padding = New-Object System.Windows.Thickness(16, 12)
    $warnBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 14)
    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = $script:AkariOSConfirmWarning -replace "AKARIOS", $Token
    $warnText.Foreground = $dangerTx
    $warnText.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $warnBorder.Child = $warnText
    $stack.Children.Add($warnBorder)

    $prompt = New-Object System.Windows.Controls.TextBlock
    $prompt.Text = $script:AkariOSConfirmPrompt -replace "AKARIOS", $Token
    $prompt.Foreground = $secondary
    $prompt.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
    $stack.Children.Add($prompt)

    $box = New-Object System.Windows.Controls.TextBox
    $box.Height = 34
    $box.Padding = New-Object System.Windows.Thickness(10, 7)
    $box.Background = $btnBg
    $box.Foreground = $white
    $box.CaretBrush = $white
    $box.BorderBrush = $btnBr
    $box.BorderThickness = New-Object System.Windows.Thickness(1)
    $stack.Children.Add($box)

    $err = New-Object System.Windows.Controls.TextBlock
    $err.Text = $script:AkariOSConfirmError -replace "AKARIOS", $Token
    $err.Foreground = $dangerTx
    $err.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $err.Visibility = [System.Windows.Visibility]::Collapsed
    $err.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0)
    $stack.Children.Add($err)

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = "Horizontal"
    $btnRow.HorizontalAlignment = "Right"
    $btnRow.Margin = New-Object System.Windows.Thickness(0, 18, 0, 0)

    $btnGo = New-Object System.Windows.Controls.Button
    $btnGo.Content = "I Understand"
    $btnGo.MinWidth = 160
    $btnGo.Padding = New-Object System.Windows.Thickness(24, 10)
    $btnGo.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
    $btnGo.Background = $accent
    $btnGo.Foreground = $white
    $btnGo.BorderBrush = $accentHi
    $btnGo.BorderThickness = New-Object System.Windows.Thickness(1)
    $btnGo.Cursor = [System.Windows.Input.Cursor]::Hand

    $btnBack = New-Object System.Windows.Controls.Button
    $btnBack.Content = "Go Back"
    $btnBack.MinWidth = 120
    $btnBack.Padding = New-Object System.Windows.Thickness(16, 7)
    $btnBack.Background = $btnBg
    $btnBack.Foreground = $white
    $btnBack.BorderBrush = $btnBr
    $btnBack.BorderThickness = New-Object System.Windows.Thickness(1)
    $btnBack.Cursor = [System.Windows.Input.Cursor]::Hand

    $btnRow.Children.Add($btnBack)
    $btnRow.Children.Add($btnGo)
    $stack.Children.Add($btnRow)

    $dlg.Content = $stack

    # The token is read from the TextBox at click time; the outcome is written to
    # the shared hashtable (a reference type, so it survives the closure).
    $btnGo.Add_Click({
        if (Test-AkariOSConfirmation -InputText $box.Text -Token $Token) {
            $state.Confirmed = $true
            $dlg.DialogResult = $true
        } else {
            # Wrong token: keep the dialog open and show the UI-SPEC error.
            $err.Visibility = [System.Windows.Visibility]::Visible
            $box.SelectAll()
            $box.Focus()
        }
    }.GetNewClosure())

    $btnBack.Add_Click({ $dlg.DialogResult = $false }.GetNewClosure())

    $dlg.Add_ContentRendered({ $box.Focus() }.GetNewClosure())

    # ShowDialog blocks until DialogResult is set. Escape, the X button and the
    # window-close path all resolve it to $false, so this cannot hang.
    $dlg.ShowDialog() | Out-Null

    $confirmed = [bool]$state.Confirmed
    $dlg.Close()
    return $confirmed
}

function Invoke-BtnInstall {
    <#
    .SYNOPSIS
        BtnInstall handler: run the confirmation gate, then hand off to the
        stage runner. This is the ONLY entry point into the install (SAFE-02).
    #>
    # Defense in depth: never start if a blocking pre-flight check is failing,
    # even if something enabled the button.
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

    if (Get-Command Start-AkariOSInstall -ErrorAction SilentlyContinue) {
        Start-AkariOSInstall
    } else {
        # Reachable only if Stage.ps1 failed to load into the runspace. The Phase 2
        # text that used to live here ("stage runner not wired yet (Phase 2)") is
        # removed: the runner IS wired, so reaching this branch means a load failure,
        # and blaming the phase would send the reader looking in the wrong place.
        Set-Status "Confirmed - the stage runner failed to load; this is a defect." "#FF6B6B"
        Write-AkariOSLog -Level ERROR -Message "Start-AkariOSInstall is not available - Stage.ps1 did not load. The install cannot start."
        [System.Windows.MessageBox]::Show(
            "Confirmation accepted, but the stage runner is not available.`n`n" +
            "Stage.ps1 failed to load, so the install cannot start. See install.log.",
            "AkariOS Setup") | Out-Null
    }
}