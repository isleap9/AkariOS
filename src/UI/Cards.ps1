# Cards: the Guided Tweaks grid, after Win11Debloat's System Tweaks page. One category card per Category (icon + title),
# one row per Tweak: Toggle and Action = checkbox, Choice = label + combobox starting on "No change". Small glyphs show
# Risk, restart and an unread State; the tooltip carries the description. Cards make no Core calls; UI\Steps.ps1 wires
# their events to the Selection. Styles come from UI\Controls.xaml.

# Category icons (Ic.<name> keys, UI\Icons.xaml); a Category not listed here gets 'settings'
$AkariCategoryGlyphs = @{
    Gaming = 'gamepad-2'; Performance = 'gauge'; Tuning = 'sliders-vertical'; Privacy = 'lock'
    Check = 'activity'; Refresh = 'refresh-cw'; Setup = 'wrench'; Graphics = 'monitor'
    Windows = 'app-window'; Hardware = 'cpu'; Advanced = 'flask-conical'
    Taskbar = 'panel-bottom'; Start = 'layout-grid'; Explorer = 'folder'; Theme = 'palette'
    Update = 'cloud-download'; Power = 'power'; Network = 'wifi'; Notifications = 'bell'; Input = 'mouse'; Accessibility = 'accessibility'; Sound = 'volume-2'; System = 'settings-2'
    Security = 'shield-check'; Display = 'monitor'; Apps = 'app-window'; Cleanup = 'eraser'; Drivers = 'hard-drive'
    'Context menu' = 'menu'; Services = 'activity'; 'Scheduled tasks' = 'history'
    Fixes = 'wrench'; Panels = 'app-window'; Features = 'blocks'
}

# a Category's icon name
function Get-AkariCategoryIcon([string]$Category) { if ($AkariCategoryGlyphs.ContainsKey($Category)) { $AkariCategoryGlyphs[$Category] } else { 'settings' } }

# a Fluent icon (UI\Icons.xaml, Ic.<name>, built by build\Icons.ps1; '<name>.Filled' for a filled one): its 20x20
# path, filled in $Brush, scaled to $Size by a Viewbox. $Brush 'Inherit': the text colour of the button or menu item
# it sits in (a selected nav button, a disabled menu row)
function New-AkariIcon([string]$Name, [double]$Size = 16, [string]$Brush = 'Tx') {
    $p = [Windows.Shapes.Path]::new()
    $p.SetResourceReference([Windows.Shapes.Path]::DataProperty, "Ic.$Name")
    if ($Brush -eq 'Inherit') {
        $bd = [Windows.Data.Binding]::new('Foreground')
        $bd.RelativeSource = [Windows.Data.RelativeSource]::new([Windows.Data.RelativeSourceMode]::FindAncestor, [Windows.Controls.Control], 1)
        [void][Windows.Data.BindingOperations]::SetBinding($p, [Windows.Shapes.Shape]::FillProperty, $bd)
    } else { $p.SetResourceReference([Windows.Shapes.Shape]::FillProperty, $Brush) }
    $c = [Windows.Controls.Canvas]::new(); $c.Width = 20; $c.Height = 20
    [void]$c.Children.Add($p)
    $v = [Windows.Controls.Viewbox]::new(); $v.Width = $Size; $v.Height = $Size
    $v.Child = $c
    $v.Tag = $Name
    $v
}

# points an icon at another icon: one from New-AkariIcon, or a Path in XAML (the page header's, CapMaxGlyph)
function Set-AkariIcon($Icon, [string]$Name) {
    $p = if ($Icon -is [Windows.Shapes.Path]) { $Icon } else { $Icon.Child.Children[0] }
    $p.SetResourceReference([Windows.Shapes.Path]::DataProperty, "Ic.$Name")
    $Icon.Tag = $Name
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

# an image file as a frozen bitmap ($Width: decoded at that pixel width, 0 = its own), read once per session (the apps
# lists are built again on every flow switch). Decoded from the file's bytes: WPF's UriSource path took ~5 ms a file,
# the bytes ~0.4 ms, and leave no file open. Throws when the file can't be read or decoded.
$script:AkariBitmaps = @{}
function Get-AkariBitmap([string]$Path, [int]$Width = 0) {
    $key = "$Width|$Path"
    if (-not $script:AkariBitmaps.ContainsKey($key)) {
        $bi = [Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit()
        $bi.StreamSource = [IO.MemoryStream]::new([IO.File]::ReadAllBytes($Path))
        if ($Width) { $bi.DecodePixelWidth = $Width }
        $bi.CacheOption = 'OnLoad'
        $bi.EndInit()
        $bi.Freeze()
        $script:AkariBitmaps[$key] = $bi
    }
    $script:AkariBitmaps[$key]
}

# a small mark next to a name (Risk, restart, Safe Mode, an unread State): a 14 px icon with a tooltip
function New-AkariGlyph([string]$Icon, [string]$Brush, [string]$Tip) {
    $g = New-AkariIcon $Icon 14 $Brush
    $g.Margin = [Windows.Thickness]::new(6, 0, 0, 0)
    $g.VerticalAlignment = 'Center'
    if ($Tip) { $g.ToolTip = $Tip }
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
        [void]$glyphs.Children.Add((New-AkariGlyph 'triangle-alert' $b $Tweak.Risk))
    }
    if ($Tweak.Reboot) { [void]$glyphs.Children.Add((New-AkariGlyph 'rotate-ccw' 'Mu' 'Restart required')) }
    if ($Tweak.Kind -ne 'Action' -and $State -in 'Custom', 'Unknown') {
        $tip = if ($State -eq 'Custom') { 'Custom value' } else { 'State unknown' }
        [void]$glyphs.Children.Add((New-AkariGlyph 'circle-help' 'Ter' $tip))
    }
    $name = [Windows.Controls.TextBlock]::new()
    [void]$name.Inlines.Add([Windows.Documents.Run]::new($Tweak.Name))
    # part of the AkariOS setup (what One-click applies): "(AkariOS)" after the name, muted
    if ($Tweak.AkariOS) {
        $tag = [Windows.Documents.Run]::new(' (AkariOS)')
        $tag.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, 'Mu')
        [void]$name.Inlines.Add($tag)
    }
    $name.FontSize = 13
    $name.TextWrapping = 'Wrap'
    $name.VerticalAlignment = 'Center'

    $row = [Windows.Controls.DockPanel]::new()
    $row.Margin = [Windows.Thickness]::new(0, 4, 0, 4)
    $row.ToolTip = Get-AkariRowTip $Tweak $State
    $row.Tag = $Tweak.Id
    [Windows.Controls.DockPanel]::SetDock($glyphs, 'Right')
    if ($Tweak.Kind -eq 'Choice') {
        # up to 4 values (and not typed in): a segmented picker, a ListBox with the same SelectedIndex / SelectedItem /
        # SelectionChanged, so the row code doesn't tell them apart; else a combobox. Each holds its own item type:
        # a ComboBoxItem in a ListBox ignores clicks.
        if (-not $Tweak.Editable -and @($Tweak.Choices).Count -le 4) {
            $ctl = [Windows.Controls.ListBox]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Segmented')
            $ctl.HorizontalAlignment = 'Left'
            $itemType = [Windows.Controls.ListBoxItem]
        } else {
            $ctl = [Windows.Controls.ComboBox]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
            $ctl.IsEditable = $Tweak.Editable
            $ctl.HorizontalAlignment = 'Stretch'
            $itemType = [Windows.Controls.ComboBoxItem]
        }
        $ctl.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
        # index 0 is always "No change"
        $none = $itemType::new()
        $none.Content = 'No change'
        [void]$ctl.Items.Add($none)
        $def = Resolve-AkariDefault $Tweak.Default
        foreach ($c in $Tweak.Choices) {
            $it = $itemType::new()
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
# a TextBlock (or control) in one of the window's fonts (UI\Controls.xaml): Display (titles), Text, Small (captions)
# or Mono (ids, code)
function Set-AkariFont($Block, [string]$Font) { $Block.SetResourceReference([Windows.Documents.TextElement]::FontFamilyProperty, "Font$Font") }

# the accent brushes for a theme from Windows' AccentPalette (ADR 0008; pure): 32 bytes, 8 colours as R, G, B, A:
# Light3, Light2, Light1, Base, Dark1, Dark2, Dark3, unused. Dark: Acc = Light2, AccText = Info = Light3, AccT black;
# Light: Acc = Dark1, AccText = Info = Dark2, AccT white; AccH / AccP / AccSoft = Acc at 90 / 80 / 10%. Key ->
# '#AARRGGBB'; $null when the palette is missing or short (the theme's default blue stays).
function Get-AkariAccentColors($Palette, [string]$Theme) {
    if ($null -eq $Palette -or @($Palette).Count -lt 28) { return $null }
    $p = [byte[]]@($Palette)
    $hex = { param([int]$i, [int]$a) '#{0:X2}{1:X2}{2:X2}{3:X2}' -f $a, $p[$i * 4], $p[$i * 4 + 1], $p[$i * 4 + 2] }
    $acc, $text, $on = if ($Theme -eq 'Light') { 4, 5, '#FFFFFFFF' } else { 1, 0, '#FF000000' }
    [ordered]@{
        Acc = & $hex $acc 0xFF; AccH = & $hex $acc 0xE6; AccP = & $hex $acc 0xCC; AccSoft = & $hex $acc 0x1A
        AccT = $on; AccText = & $hex $text 0xFF; Info = & $hex $text 0xFF
    }
}

function New-AkariCategoryCard([string]$Title, [string]$Icon, [string]$Note) {
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CategoryCard')
    $panel = [Windows.Controls.StackPanel]::new()
    # head: the icon blob, the title, a note ("Not yet ported"), and the count pill on the right (Count.Text: Steps.ps1)
    $head = [Windows.Controls.DockPanel]::new()
    $head.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
    $count = [Windows.Controls.TextBlock]::new()
    $count.FontSize = 12
    $count.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Mu')
    Set-AkariFont $count 'Mono'
    $pill = [Windows.Controls.Border]::new()
    $pill.CornerRadius = [Windows.CornerRadius]::new(10)
    $pill.Padding = [Windows.Thickness]::new(8, 1, 8, 2)
    $pill.BorderThickness = [Windows.Thickness]::new(1)
    $pill.VerticalAlignment = 'Center'
    $pill.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Ctl')
    $pill.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CtlBd')
    $pill.Child = $count
    [Windows.Controls.DockPanel]::SetDock($pill, 'Right')
    $ic = New-AkariBlob $Icon 36
    $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $tt = [Windows.Controls.TextBlock]::new()
    $tt.Text = $Title
    $tt.FontSize = 20
    $tt.FontWeight = 'SemiBold'
    Set-AkariFont $tt 'Display'
    $tt.VerticalAlignment = 'Center'
    $tt.TextTrimming = 'CharacterEllipsis'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left')
    [void]$head.Children.Add($pill); [void]$head.Children.Add($ic)
    if ($Note) {
        $nt = [Windows.Controls.TextBlock]::new()
        $nt.Text = $Note
        $nt.FontSize = 12
        $nt.Margin = [Windows.Thickness]::new(10, 2, 8, 0)
        $nt.VerticalAlignment = 'Center'
        $nt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Ter')
        [Windows.Controls.DockPanel]::SetDock($nt, 'Right')
        [void]$head.Children.Add($nt)
    }
    [void]$head.Children.Add($tt)
    [void]$panel.Children.Add($head)
    $card.Child = $panel
    @{ Card = $card; Panel = $panel; Count = $count }
}

# an icon on a rounded crimson-tint square (the design system's "blob"): category cards, mode cards, Review rows,
# dialogs. $Brush / $Fill: the icon colour and the square's (a warning: Warn on WarnSoft)
function New-AkariBlob([string]$Icon, [double]$Size = 36, [string]$Brush = 'AccText', [string]$Fill = 'AccSoft') {
    $b = [Windows.Controls.Border]::new()
    $b.Width = $Size; $b.Height = $Size
    $b.CornerRadius = [Windows.CornerRadius]::new([Math]::Round($Size * 0.3))
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $Fill)
    $b.VerticalAlignment = 'Center'
    $i = New-AkariIcon $Icon ([Math]::Round($Size * 0.55)) $Brush
    $i.HorizontalAlignment = 'Center'; $i.VerticalAlignment = 'Center'
    $b.Child = $i
    $b.Tag = $Icon
    $b
}

# the dashed rule between two rows of a card; shown only while $Row is (the search filter hides rows)
function New-AkariRule($Row) {
    $l = [Windows.Shapes.Line]::new()
    $l.X1 = 0; $l.X2 = 1; $l.Stretch = 'Fill'; $l.Height = 1
    $l.StrokeThickness = 1
    $l.StrokeDashArray = [Windows.Media.DoubleCollection]::new([double[]](4, 3))
    $l.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, 'Bd')
    $l.Margin = [Windows.Thickness]::new(0, 2, 0, 2)
    $bd = [Windows.Data.Binding]::new('Visibility'); $bd.Source = $Row
    [void][Windows.Data.BindingOperations]::SetBinding($l, [Windows.UIElement]::VisibilityProperty, $bd)
    $l
}

# a pill badge: AkariOS (crimson tint), Caution (amber outline), Advanced (solid amber)
function New-AkariBadge([string]$Kind) {
    $b = [Windows.Controls.Border]::new()
    $b.CornerRadius = [Windows.CornerRadius]::new(10)
    $b.Padding = [Windows.Thickness]::new(8, 1, 8, 2)
    $b.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
    $b.VerticalAlignment = 'Center'
    $fg, $bg, $bd = switch ($Kind) {
        'AkariOS' { 'AccText', 'AccSoft', $null }
        'Caution' { 'Warn', 'WarnSoft', 'Warn' }
        default { 'WarnT', 'Warn', $null }
    }
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bg)
    if ($bd) { $b.BorderThickness = [Windows.Thickness]::new(1); $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, $bd) }
    $t = [Windows.Controls.TextBlock]::new()
    $t.Text = $Kind; $t.FontSize = 12; $t.FontWeight = 'SemiBold'
    $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $fg)
    $b.Child = $t
    $b.Tag = $Kind
    $b
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
