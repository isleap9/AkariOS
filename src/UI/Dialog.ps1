# Akari's dialogs (UI\Dialog.xaml), WinUI's ContentDialog instead of the white [Windows.MessageBox]: a 448 px card over
# a 30 % black smoke that covers the window. Buttons say what they do; the last one given is the main action (the
# accent button, shown first, Enter, focused), the first one given cancels (shown last, Esc, a click on the smoke).
# Lines of the text that start with "- " become a list of consequences. Falls back to the native box if the dialog
# can't open. Dot-sourced by Akari.ps1 before the other UI files; called only once the window is up.

# kept for the callers' -Icon (the native box's image when the dialog can't open); a ContentDialog shows no icon
$AkariDialogIcons = @{
    Info = @{ Glyph = 'info' }; Question = @{ Glyph = 'circle-help' }; Warning = @{ Glyph = 'triangle-alert' }; Error = @{ Glyph = 'error-circle' }
}

# the dialog's text as blocks: paragraphs, and "- " lines as a bulleted list in Mu (the prototype's <ul>). Pure.
# Returns @(@{ Kind = 'Text' | 'Item'; Text })
function Get-AkariDialogBlocks([string]$Message) {
    foreach ($l in ($Message -split "`r?`n")) {
        if ($l -match ('^\s*[-' + [char]0x2022 + ']\s+(.*)$')) { @{ Kind = 'Item'; Text = $Matches[1] } }
        elseif ($l.Trim()) { @{ Kind = 'Text'; Text = $l.Trim() } }
    }
}

# the buttons in the order the footer shows them: the main action (the last given) first, the cancel one (the first
# given) last, the rest between. Pure.
function Get-AkariDialogOrder([string[]]$Buttons) {
    if ($Buttons.Count -le 1) { return , $Buttons }
    $mid = if ($Buttons.Count -gt 2) { $Buttons[1..($Buttons.Count - 2)] } else { @() }
    , (@($Buttons[-1]) + @($mid) + @($Buttons[0]))
}

# builds the dialog without showing it: its window, Tag.Result = the pressed button's text ($null = cancelled);
# -Choices: one radio each under the text (Tag.Choices), -Selected picked at first
function New-AkariDialog([string]$Message, [string]$Title = 'AkariOS', [string[]]$Buttons = @('OK'), [string]$Icon = 'Info', [switch]$TextBox,
    [string[]]$Choices = @(), [int]$Selected = 0) {
    $d = Get-AkariXaml "$Root\UI\Dialog.xaml"
    # the main window's brushes and button styles
    if ($window) { $d.Resources.MergedDictionaries.Add($window.Resources) }
    $d.Tag = @{ Result = $null; Cancel = $Buttons[0]; Closing = $false; Choices = [Collections.Generic.List[object]]::new() }
    $d.FindName('DlgTitle').Text = $Title
    $text = $d.FindName('DlgText')
    foreach ($b in Get-AkariDialogBlocks $Message) {
        $t = [Windows.Controls.TextBlock]::new()
        $t.TextWrapping = 'Wrap'; $t.LineHeight = 20
        if ($b.Kind -eq 'Item') {
            $t.Text = [string][char]0x2022 + '  ' + $b.Text
            $t.Margin = [Windows.Thickness]::new(8, 8, 0, 0)
            $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Mu')
        } else {
            $t.Text = $b.Text
            if ($text.Children.Count) { $t.Margin = [Windows.Thickness]::new(0, 8, 0, 0) }
        }
        [void]$text.Children.Add($t)
    }
    if ($TextBox) { $d.FindName('DlgInput').Visibility = 'Visible' }
    for ($i = 0; $i -lt $Choices.Count; $i++) {
        $r = [Windows.Controls.RadioButton]::new()
        $r.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Radio')
        $r.GroupName = 'DlgChoice'
        $r.Content = $Choices[$i]
        $r.Margin = [Windows.Thickness]::new(0, $(if ($i) { 10 } else { 14 }), 0, 0)
        $r.IsChecked = ($i -eq $Selected)
        $d.Tag.Choices.Add($r)
        [void]$text.Children.Add($r)
    }
    $bar = $d.FindName('DlgButtons')
    $order = Get-AkariDialogOrder $Buttons
    foreach ($name in $order) {
        $b = [Windows.Controls.Button]::new()
        $main = ($name -eq $Buttons[-1])
        $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $(if ($main) { 'BtnP' } else { 'Btn' }))
        $b.MinWidth = 0
        $b.Content = $name
        $b.Tag = $name
        $b.Margin = [Windows.Thickness]::new($(if ($bar.Children.Count) { 4 } else { 0 }), 0, $(if ($bar.Children.Count -lt $order.Count - 1) { 4 } else { 0 }), 0)
        $b.IsDefault = $main
        $b.Add_Click({ param($s, $e) Close-AkariDialog ([Windows.Window]::GetWindow($s)) ([string]$s.Tag) })
        [void]$bar.Children.Add($b)
    }
    # Esc gives the first button (as its own click would; not IsCancel, which would close at once, unanimated)
    $d.Add_PreviewKeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $e.Handled = $true; Close-AkariDialog $s $s.Tag.Cancel } })
    # a click on the smoke cancels; the accent action (or the text box) has focus once shown
    $d.FindName('DlgSmoke').Add_MouseLeftButtonDown({ param($s, $e) $w = [Windows.Window]::GetWindow($s); Close-AkariDialog $w $null })
    $d.Add_ContentRendered({
        param($s, $e)
        $t = $s.FindName('DlgInput')
        if ($t.Visibility -eq 'Visible') { [void]$t.Focus() } else { $f = $s.FindName('DlgButtons').Children[0]; if ($f) { [void]$f.Focus() } }
    })
    $d
}

# closes a dialog with $Result: the card scales to 1.05 and fades out and the smoke fades, over Motion.Base on the exit
# curve (the prototype's dlgOut), then the window closes. Motion off = at once.
function Close-AkariDialog($Dialog, $Result) {
    if (-not $Dialog -or $Dialog.Tag.Closing) { return }
    $Dialog.Tag.Closing = $true
    $Dialog.Tag.Result = $Result
    if (-not $script:AkariMotionOn -or -not $Dialog.IsVisible) { $Dialog.Close(); return }
    $card = $Dialog.FindName('DlgCard')
    Start-AkariMotion $card Scale 1 1.05 -Speed Base -Easing Exit
    Start-AkariMotion $card Fade 1 0 -Speed Base -Easing Exit
    Start-AkariMotion $Dialog.FindName('DlgSmoke') Fade 1 0 -Speed Base
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = $AkariMotion['Motion.Base'].TimeSpan
    $tm.Tag = $Dialog
    $tm.Add_Tick({ param($s, $e) $s.Stop(); try { $s.Tag.Close() } catch { } })
    $tm.Start()
}

# shows a built dialog over the main window and waits; returns the pressed button's text, or $null. The smoke fades
# in over Motion.Base; the card scales from 1.05 and fades in over Motion.Slow (the prototype's dlgIn).
function Invoke-AkariDialog($Dialog) {
    if ($window -and $window.IsVisible) {
        $Dialog.Owner = $window
        if ($window.WindowState -eq 'Maximized') { $Dialog.WindowState = 'Maximized' }
        else { $Dialog.Left = $window.Left; $Dialog.Top = $window.Top; $Dialog.Width = $window.ActualWidth; $Dialog.Height = $window.ActualHeight; $Dialog.WindowStartupLocation = 'Manual' }
    } else { $Dialog.WindowStartupLocation = 'CenterScreen'; $Dialog.SizeToContent = 'WidthAndHeight'; $Dialog.FindName('DlgSmoke').Visibility = 'Collapsed' }

    $Dialog.Add_Loaded({
        param($s, $e)
        Start-AkariMotion ($s.FindName('DlgSmoke')) Fade 0 1 -Speed Base
        Start-AkariMotion ($s.FindName('DlgCard')) Scale 1.05 1 -Speed Slow
        Start-AkariMotion ($s.FindName('DlgCard')) Fade 0 1 -Speed Slow
    })
    [void]$Dialog.ShowDialog()
    $Dialog.Tag.Result
}

# a dialog; returns the pressed button's text, or $null (cancelled). The native box stands in if it can't open.
function Show-AkariDialog([string]$Message, [string]$Title = 'AkariOS', [string[]]$Buttons = @('OK'), [string]$Icon = 'Info') {
    try { return Invoke-AkariDialog (New-AkariDialog $Message $Title $Buttons $Icon) }
    catch {
        Write-ErrLog "Dialog: $($_.Exception.Message)"
        $img = if ($Icon -eq 'Error') { 'Error' } elseif ($Icon -in 'Warning', 'Question') { $Icon } else { 'Information' }
        if ($Buttons.Count -lt 2) { [void][Windows.MessageBox]::Show($Message, $Title, 'OK', $img); return $Buttons[0] }
        if ([Windows.MessageBox]::Show($Message, $Title, 'YesNo', $img) -eq 'Yes') { return $Buttons[-1] }
        return $Buttons[0]
    }
}

# Yes / No in words: $true when the main action ($Yes) was pressed
function Confirm-AkariDialog([string]$Message, [string]$Yes, [string]$No = 'Cancel', [string]$Icon = 'Warning', [string]$Title = 'AkariOS') {
    (Show-AkariDialog $Message $Title @($No, $Yes) $Icon) -eq $Yes
}

# a message with one OK button
function Show-AkariMessage([string]$Message, [string]$Icon = 'Info', [string]$Title = 'AkariOS') {
    [void](Show-AkariDialog $Message $Title @('OK') $Icon)
}

# one answer from a list (One-click's browser): the picked index, or $null (cancelled). If the dialog can't open,
# $Selected (the recommended one).
function Select-AkariChoice([string]$Message, [string[]]$Options, [int]$Selected = 0, [string]$Ok = 'OK', [string]$Title = 'AkariOS') {
    try {
        $d = New-AkariDialog $Message $Title @('Cancel', $Ok) 'None' -Choices $Options -Selected $Selected
        if ((Invoke-AkariDialog $d) -ne $Ok) { return $null }
        for ($i = 0; $i -lt $d.Tag.Choices.Count; $i++) { if ($d.Tag.Choices[$i].IsChecked) { return $i } }
        $null
    } catch { Write-ErrLog "Dialog: $($_.Exception.Message)"; $Selected }
}

# asks for a line of text; the trimmed text, or $null (cancelled or empty)
function Read-AkariText([string]$Prompt, [string]$Ok = 'OK', [string]$Title = 'AkariOS') {
    try {
        $d = New-AkariDialog $Prompt $Title @('Cancel', $Ok) 'None' -TextBox
        $r = Invoke-AkariDialog $d
        $t = $d.FindName('DlgInput').Text
    } catch {
        Write-ErrLog "Dialog: $($_.Exception.Message)"
        Add-Type -AssemblyName Microsoft.VisualBasic
        $r = $Ok; $t = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, '')
    }
    if ($r -ne $Ok -or -not $t -or -not $t.Trim()) { return $null }
    $t.Trim()
}
