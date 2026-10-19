# Cards: one WinUI-style setting card per Tweak in the Manual steps (Toggle: switch, Choice: combobox, Action: checkbox).
# Cards make no Core calls; UI\Steps.ps1 wires their events to the Selection. Styles come from UI\Controls.xaml.

# a card entry: @{ Tweak; State; Current; Shown; Card; Control; Description; StateLine; Muted }
# $Current: a Choice's current registry value. Shown: the switch target on screen ('Optimized', 'Default' or 'None').
function New-AkariCard($Tweak, [string]$State, $Current = $null) {
    $e = @{ Tweak = $Tweak; State = $State; Current = $Current; Shown = 'None'; Muted = $false }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Tag = $Tweak.Id
    $g = [Windows.Controls.Grid]::new()
    [void]$g.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $c1 = [Windows.Controls.ColumnDefinition]::new(); $c1.Width = [Windows.GridLength]::Auto
    [void]$g.ColumnDefinitions.Add($c1)

    $text = [Windows.Controls.StackPanel]::new()
    $text.VerticalAlignment = 'Center'
    $text.Margin = [Windows.Thickness]::new(0, 0, 24, 0)
    $name = [Windows.Controls.TextBlock]::new()
    $name.Text = $Tweak.Name
    $name.FontSize = 14
    $name.TextWrapping = 'Wrap'
    [void]$text.Children.Add($name)

    # description line: Caution / Advanced lead with a warning glyph and the Risk word; Safe shows nothing extra
    $row = [Windows.Controls.DockPanel]::new()
    if ($Tweak.Risk -in 'Caution', 'Advanced') {
        $riskKey = if ($Tweak.Risk -eq 'Advanced') { 'Bad' } else { 'Warn' }
        $glyph = [Windows.Controls.TextBlock]::new()
        $glyph.Text = [string][char]0xE7BA
        $glyph.FontSize = 12
        $glyph.Margin = [Windows.Thickness]::new(0, 2, 6, 0)
        $glyph.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'Icons')
        $glyph.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $riskKey)
        [Windows.Controls.DockPanel]::SetDock($glyph, 'Left')
        [void]$row.Children.Add($glyph)
    }
    $desc = [Windows.Controls.TextBlock]::new()
    $desc.FontSize = 12
    $desc.TextWrapping = 'Wrap'
    $desc.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Mu')
    if ($Tweak.Risk -in 'Caution', 'Advanced') {
        $r = [Windows.Documents.Run]::new("$($Tweak.Risk). ")
        $r.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, $riskKey)
        $desc.Inlines.Add($r)
    }
    $desc.Inlines.Add([Windows.Documents.Run]::new([string]$Tweak.Description))
    if ($Tweak.Reboot) { $desc.Inlines.Add([Windows.Documents.Run]::new(' Restart required.')) }
    [void]$row.Children.Add($desc)
    [void]$text.Children.Add($row)

    $stateLine = [Windows.Controls.TextBlock]::new()
    $stateLine.FontSize = 12
    $stateLine.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Ter')
    $stateLine.Visibility = 'Collapsed'
    if ($Tweak.Kind -ne 'Action') {
        if ($State -eq 'Custom') { $stateLine.Text = 'Custom value'; $stateLine.Visibility = 'Visible' }
        elseif ($State -eq 'Unknown') { $stateLine.Text = 'State unknown'; $stateLine.Visibility = 'Visible' }
    }
    [void]$text.Children.Add($stateLine)
    [void]$g.Children.Add($text)

    switch ($Tweak.Kind) {
        'Choice' {
            $ctl = [Windows.Controls.ComboBox]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
            $ctl.IsEditable = $Tweak.Editable
            $def = Resolve-AkariDefault $Tweak.Default
            foreach ($c in $Tweak.Choices) {
                $it = [Windows.Controls.ComboBoxItem]::new()
                $label = if ($c.Label) { $c.Label } else { "$($c.Value)" }
                if (Test-AkariRegMatch $c.Value $Tweak.Recommended) { $label += ' (Recommended)' }
                elseif (Test-AkariRegMatch $c.Value $def) { $label += ' (Windows default)' }
                $it.Content = $label
                $it.Tag = $c.Value
                [void]$ctl.Items.Add($it)
            }
        }
        'Action' {
            $ctl = [Windows.Controls.CheckBox]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
            $ctl.Content = 'Run this'
        }
        default {
            $ctl = [Windows.Controls.Primitives.ToggleButton]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Switch')
            # Unknown or Custom: the switch can also mean "no change"
            $ctl.IsThreeState = ($State -notin 'Optimized', 'Default')
        }
    }
    $ctl.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($ctl, 1)
    [void]$g.Children.Add($ctl)
    $card.Child = $g

    $e.Card = $card; $e.Control = $ctl; $e.Description = $desc; $e.StateLine = $stateLine
    $start = if ($Tweak.Kind -eq 'Choice') { $Current } elseif ($State -in 'Optimized', 'Default') { $State } else { 'None' }
    Set-AkariCardControl $e $start
    $e
}

# "0x28", "40" -> number; anything else -> $null
function ConvertFrom-AkariNumber([string]$s) {
    $s = $s.Trim()
    [uint32]$n = 0
    if ($s -match '^0[xX]([0-9a-fA-F]{1,8})$') { return [Convert]::ToUInt32($Matches[1], 16) }
    if ([uint32]::TryParse($s, [ref]$n)) { return $n }
    $null
}

# the value picked or typed in a Choice card, or $null when the typed text is not a number
function Get-AkariComboValue($e) {
    $ctl = $e.Control
    if ($ctl.SelectedItem -and (-not $ctl.IsEditable -or $ctl.Text -eq $ctl.SelectedItem.Content)) { return $ctl.SelectedItem.Tag }
    if ($ctl.IsEditable) { return ConvertFrom-AkariNumber $ctl.Text }
    $null
}

# puts the control on a target without the change handlers reacting (they check $e.Muted)
# $Target: 'Optimized' / 'Default' / 'None' for a Toggle or Action, a value for a Choice
function Set-AkariCardControl($e, $Target) {
    $e.Muted = $true
    try {
        $ctl = $e.Control
        switch ($e.Tweak.Kind) {
            'Choice' {
                $it = $null
                if ($null -ne $Target) { $it = $ctl.Items | Where-Object { Test-AkariRegMatch $_.Tag $Target } | Select-Object -First 1 }
                if ($it) { $ctl.SelectedItem = $it }
                else {
                    $ctl.SelectedIndex = -1
                    if ($ctl.IsEditable -and $null -ne $Target) { $ctl.Text = "$Target" }
                }
            }
            'Action' { $ctl.IsChecked = ($Target -eq 'Optimized') }
            default {
                $e.Shown = [string]$Target
                $ctl.IsChecked = switch ([string]$Target) { 'Optimized' { $true } 'Default' { $false } default { $null } }
            }
        }
    } finally { $e.Muted = $false }
}
