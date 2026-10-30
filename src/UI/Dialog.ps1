# Akari's dialogs (UI\Dialog.xaml), instead of the white [Windows.MessageBox]: a dark card over the dimmed window
# (ModalOverlay), after Win11Debloat's message box. Buttons say what they do; the last one is the main action (white,
# Enter), the first closes like Esc. Falls back to the native box if the dialog can't open.
# Dot-sourced by Akari.ps1 before the other UI files; called only once the window is up.

# each Icon: a Lucide icon (UI\Icons.xaml), its colour and its blob's
$AkariDialogIcons = @{
    Info = @{ Glyph = 'info'; Brush = 'AccText'; Fill = 'AccSoft' }
    Question = @{ Glyph = 'circle-help'; Brush = 'AccText'; Fill = 'AccSoft' }
    Warning = @{ Glyph = 'triangle-alert'; Brush = 'Warn'; Fill = 'WarnSoft' }
    Error = @{ Glyph = 'circle-x'; Brush = 'Bad'; Fill = 'AccSoft' }
}

# builds the dialog without showing it: its window, Tag.Result = the pressed button's text ($null = closed with Esc)
function New-AkariDialog([string]$Message, [string]$Title = 'AkariOS', [string[]]$Buttons = @('OK'), [string]$Icon = 'Info', [switch]$TextBox) {
    $d = [Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Dialog.xaml" -Raw))
    # the main window's brushes and button styles
    if ($window) { $d.Resources.MergedDictionaries.Add($window.Resources) }
    $d.Tag = @{ Result = $null }
    $d.FindName('DlgTitle').Text = $Title
    $d.FindName('DlgText').Text = $Message
    $ic = $d.FindName('DlgIcon')
    $i = $AkariDialogIcons[$Icon]
    if ($i) {
        $p = $d.FindName('DlgIconPath')
        $p.SetResourceReference([Windows.Shapes.Path]::DataProperty, "Ic.$($i.Glyph)")
        $p.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, $i.Brush)
        $ic.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $i.Fill)
        $ic.Tag = $i.Glyph
    }
    else { $ic.Visibility = 'Collapsed' }
    if ($TextBox) { $d.FindName('DlgInput').Visibility = 'Visible' }
    $bar = $d.FindName('DlgButtons')
    for ($n = 0; $n -lt $Buttons.Count; $n++) {
        $b = [Windows.Controls.Button]::new()
        # the main action crimson (BtnP), the others ghost: the secondary pill with no fill or stroke until hover
        $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $(if ($n -eq $Buttons.Count - 1) { 'BtnP' } else { 'Btn' }))
        if ($n -lt $Buttons.Count - 1) { $b.Background = [Windows.Media.Brushes]::Transparent; $b.BorderBrush = [Windows.Media.Brushes]::Transparent }
        $b.Content = $Buttons[$n]
        $b.Tag = $Buttons[$n]
        $b.MinWidth = 88
        $b.Margin = [Windows.Thickness]::new($(if ($n) { 8 } else { 0 }), 0, 0, 0)
        $b.IsDefault = ($n -eq $Buttons.Count - 1)
        $b.IsCancel = ($n -eq 0)
        $b.Add_Click({
            param($s, $e)
            $w = [Windows.Window]::GetWindow($s)
            $w.Tag.Result = [string]$s.Tag
            $w.Close()
        })
        [void]$bar.Children.Add($b)
    }
    # Esc on a one-button message closes it too (IsCancel above); the title drags the dialog
    $d.FindName('DlgTitle').Add_MouseLeftButtonDown({ param($s, $e) try { [Windows.Window]::GetWindow($s).DragMove() } catch { } })
    $d.Add_ContentRendered({ param($s, $e) $t = $s.FindName('DlgInput'); if ($t.Visibility -eq 'Visible') { [void]$t.Focus() } })
    $d
}

# shows a built dialog over the dimmed window and waits; returns the pressed button's text, or $null
function Invoke-AkariDialog($Dialog) {
    $overlay = if ($window) { $window.FindName('ModalOverlay') } else { $null }
    if ($window -and $window.IsVisible) { $Dialog.Owner = $window } else { $Dialog.WindowStartupLocation = 'CenterScreen' }
    if ($overlay) { $overlay.Visibility = 'Visible' }
    try { [void]$Dialog.ShowDialog() } finally { if ($overlay) { $overlay.Visibility = 'Collapsed' } }
    $Dialog.Tag.Result
}

# a dialog; returns the pressed button's text, or $null (closed). The native box stands in if it can't open.
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
