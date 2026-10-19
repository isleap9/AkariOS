# Cards: the Guided Tweaks grid, after Win11Debloat's System Tweaks page. One category card per Category (icon + title),
# one row per Tweak: Toggle and Action = checkbox, Choice = label + combobox starting on "No change". Small glyphs show
# Risk, restart and an unread State; the tooltip carries the description. Cards make no Core calls; UI\Steps.ps1 wires
# their events to the Selection. Styles come from UI\Controls.xaml.

# Category card icons (Segoe Fluent Icons); a Category not listed here gets the settings gear
$AkariCategoryGlyphs = @{
    Gaming = 0xE7FC; Performance = 0xEC4A; Tuning = 0xE9E9; Privacy = 0xE72E
    Check = 0xE9D9; Refresh = 0xE72C; Setup = 0xE90F; Installers = 0xE896; Graphics = 0xE7F4
    Windows = 0xE771; Hardware = 0xE950; Advanced = 0xE945
}

# masonry: each card goes to the column with the least rows so far (ties: the leftmost). Pure, no WPF.
# $Sizes: rows per card, in order. Returns the column index of each card.
function Get-AkariMasonry([int[]]$Sizes, [int]$Columns) {
    $fill = @(0) * $Columns
    foreach ($s in $Sizes) {
        $c = 0
        for ($i = 1; $i -lt $Columns; $i++) { if ($fill[$i] -lt $fill[$c]) { $c = $i } }
        $fill[$c] += $s + 2
        $c
    }
}

function New-AkariGlyph([int]$Code, [string]$Brush, [string]$Tip) {
    $g = [Windows.Controls.TextBlock]::new()
    $g.Text = [string][char]$Code
    $g.FontSize = 12
    $g.Margin = [Windows.Thickness]::new(6, 0, 0, 0)
    $g.VerticalAlignment = 'Center'
    $g.ToolTip = $Tip
    $g.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'Icons')
    $g.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $Brush)
    $g
}

# the tooltip text of a row: description, Risk, restart, State
function Get-AkariRowTip($Tweak, [string]$State) {
    $lines = @([string]$Tweak.Description)
    if ($Tweak.Risk -in 'Caution', 'Advanced') { $lines += "Risk: $($Tweak.Risk)." }
    if ($Tweak.Reboot) { $lines += 'Restart required.' }
    if ($Tweak.Kind -ne 'Action') {
        $lines += switch ($State) { 'Custom' { 'Now: custom value.' } 'Unknown' { 'Now: state unknown.' } default { "Now: $State." } }
    }
    ($lines | Where-Object { $_ }) -join "`n"
}

# a row entry: @{ Tweak; State; Current; Initial; Row; Control; Glyphs; Muted }
# $Current: a Choice's current registry value. Initial: where the control started ('Optimized' / 'None', or a Choice value).
function New-AkariTweakRow($Tweak, [string]$State, $Current = $null) {
    $e = @{ Tweak = $Tweak; State = $State; Current = $Current; Initial = 'None'; Muted = $false }
    # Risk, restart and an unread State, right of the name
    $glyphs = [Windows.Controls.StackPanel]::new()
    $glyphs.Orientation = 'Horizontal'
    $glyphs.VerticalAlignment = 'Center'
    if ($Tweak.Risk -in 'Caution', 'Advanced') {
        $b = if ($Tweak.Risk -eq 'Advanced') { 'Bad' } else { 'Warn' }
        [void]$glyphs.Children.Add((New-AkariGlyph 0xE7BA $b $Tweak.Risk))
    }
    if ($Tweak.Reboot) { [void]$glyphs.Children.Add((New-AkariGlyph 0xE777 'Mu' 'Restart required')) }
    if ($Tweak.Kind -ne 'Action' -and $State -in 'Custom', 'Unknown') {
        $tip = if ($State -eq 'Custom') { 'Custom value' } else { 'State unknown' }
        [void]$glyphs.Children.Add((New-AkariGlyph 0xE9CE 'Ter' $tip))
    }
    $name = [Windows.Controls.TextBlock]::new()
    $name.Text = $Tweak.Name
    $name.FontSize = 13
    $name.TextWrapping = 'Wrap'
    $name.VerticalAlignment = 'Center'

    $row = [Windows.Controls.DockPanel]::new()
    $row.Margin = [Windows.Thickness]::new(0, 4, 0, 4)
    $row.ToolTip = Get-AkariRowTip $Tweak $State
    $row.Tag = $Tweak.Id
    [Windows.Controls.DockPanel]::SetDock($glyphs, 'Right')
    if ($Tweak.Kind -eq 'Choice') {
        $ctl = [Windows.Controls.ComboBox]::new()
        $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
        $ctl.IsEditable = $Tweak.Editable
        $ctl.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
        $ctl.HorizontalAlignment = 'Stretch'
        # index 0 is always "No change"
        $none = [Windows.Controls.ComboBoxItem]::new()
        $none.Content = 'No change'
        [void]$ctl.Items.Add($none)
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
        # label line (name + glyphs), the combobox under it
        $head = [Windows.Controls.DockPanel]::new()
        [void]$head.Children.Add($glyphs)
        [void]$head.Children.Add($name)
        $sp = [Windows.Controls.StackPanel]::new()
        [void]$sp.Children.Add($head)
        [void]$sp.Children.Add($ctl)
        [void]$row.Children.Add($sp)
    } else {
        $ctl = [Windows.Controls.CheckBox]::new()
        $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
        $ctl.Content = $name
        [void]$row.Children.Add($glyphs)
        [void]$row.Children.Add($ctl)
    }
    $ctl.Tag = $Tweak.Id
    $e.Row = $row; $e.Control = $ctl; $e.Glyphs = $glyphs
    $e
}

# where a row starts. $UseState ("Show current state"): an Optimized Toggle starts checked, a Choice on its current
# value; otherwise every row starts unchecked or on "No change".
function Get-AkariRowStart($e, [bool]$UseState) {
    if (-not $UseState) { return 'None' }
    switch ($e.Tweak.Kind) {
        'Choice' {
            if ($null -ne $e.Current -and ($e.Tweak.Choices | Where-Object { Test-AkariRegMatch $_.Value $e.Current })) { return $e.Current }
            'None'
        }
        'Action' { 'None' }
        default { if ($e.State -eq 'Optimized') { 'Optimized' } else { 'None' } }
    }
}

# a category card: icon, title and an optional note (e.g. "Not yet ported"); rows go into .Panel
function New-AkariCategoryCard([string]$Title, [int]$Glyph, [string]$Note) {
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CategoryCard')
    $panel = [Windows.Controls.StackPanel]::new()
    $head = [Windows.Controls.StackPanel]::new()
    $head.Orientation = 'Horizontal'
    $head.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
    $ic = [Windows.Controls.TextBlock]::new()
    $ic.Text = [string][char]$Glyph
    $ic.FontSize = 18
    $ic.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
    $ic.VerticalAlignment = 'Center'
    $ic.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'Icons')
    $tt = [Windows.Controls.TextBlock]::new()
    $tt.Text = $Title
    $tt.FontSize = 16
    $tt.FontWeight = 'SemiBold'
    $tt.VerticalAlignment = 'Center'
    [void]$head.Children.Add($ic); [void]$head.Children.Add($tt)
    if ($Note) {
        $nt = [Windows.Controls.TextBlock]::new()
        $nt.Text = $Note
        $nt.FontSize = 11
        $nt.Margin = [Windows.Thickness]::new(10, 2, 0, 0)
        $nt.VerticalAlignment = 'Center'
        $nt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Ter')
        [void]$head.Children.Add($nt)
    }
    [void]$panel.Children.Add($head)
    $card.Child = $panel
    @{ Card = $card; Panel = $panel }
}

# "0x28", "40" -> number; anything else -> $null
function ConvertFrom-AkariNumber([string]$s) {
    $s = $s.Trim()
    [uint32]$n = 0
    if ($s -match '^0[xX]([0-9a-fA-F]{1,8})$') { return [Convert]::ToUInt32($Matches[1], 16) }
    if ([uint32]::TryParse($s, [ref]$n)) { return $n }
    $null
}

# the value picked or typed in a Choice row: 'None' for "No change", $null when the typed text is not a number
function Get-AkariComboValue($e) {
    $ctl = $e.Control
    if ($ctl.SelectedItem -and (-not $ctl.IsEditable -or $ctl.Text -eq $ctl.SelectedItem.Content)) {
        if ($ctl.SelectedIndex -eq 0) { return 'None' }
        return $ctl.SelectedItem.Tag
    }
    if ($ctl.IsEditable) {
        if (-not $ctl.Text.Trim()) { return 'None' }
        return ConvertFrom-AkariNumber $ctl.Text
    }
    'None'
}

# puts the control on a target without the change handlers reacting (they check $e.Muted)
# $Target: 'Optimized' / 'None' for a Toggle or Action ('Default' = unchecked too), 'None' or a value for a Choice
function Set-AkariRowControl($e, $Target) {
    $e.Muted = $true
    try {
        $ctl = $e.Control
        if ($e.Tweak.Kind -eq 'Choice') {
            $it = $null
            if ("$Target" -ne 'None') { $it = $ctl.Items | Select-Object -Skip 1 | Where-Object { Test-AkariRegMatch $_.Tag $Target } | Select-Object -First 1 }
            if ($it) { $ctl.SelectedItem = $it }
            elseif ($ctl.IsEditable -and "$Target" -ne 'None') { $ctl.SelectedIndex = -1; $ctl.Text = "$Target" }
            else { $ctl.SelectedIndex = 0 }
        } else {
            $ctl.IsChecked = ($Target -eq 'Optimized')
        }
    } finally { $e.Muted = $false }
}
