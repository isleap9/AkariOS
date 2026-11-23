# Cards: the WinUI building blocks every page uses (plan docs/plans/2026-11-19-winui-3.md, the prototype
# docs/design/akarios-prototype.html): Fluent icons, badges and marks, Settings cards, expanders, InfoBars, the
# SelectorBar, section headers, the progress ring; and the Guided Tweaks rows (a check box per Toggle, a combobox
# starting on "No change" per Choice). Cards make no Core calls; UI\Steps.ps1 wires their events to the Selection.
# Styles come from UI\Controls.xaml and UI\MainWindow.xaml.

# Category icons (the prototype's CAT_ICON, as UI\Icons.xaml keys); a Category not listed here gets 'settings'
$AkariCategoryGlyphs = @{
    Gaming = 'gamepad-2'; Performance = 'gauge'; Power = 'power'; Privacy = 'eye-off'; Network = 'globe'; Update = 'refresh-cw'
    Security = 'shield'; Display = 'monitor'; Tuning = 'cpu'; Graphics = 'monitor'; Input = 'keyboard'; Accessibility = 'accessibility'
    Apps = 'apps'; 'Context menu' = 'list-bullet'; Explorer = 'folder'; Notifications = 'bell'; Sound = 'volume-2'; Start = 'layout-grid'
    System = 'app-window'; Taskbar = 'panel-bottom'; Theme = 'paint-brush'; Features = 'apps'; 'Scheduled tasks' = 'calendar'
    Services = 'settings'; Check = 'circle-check'; Cleanup = 'broom'; Drivers = 'download'; Fixes = 'wrench'; Panels = 'app-window'
    Refresh = 'arrow-reset'; Setup = 'rocket'
    # Legacy pages
    Windows = 'app-window'; Hardware = 'cpu'; Advanced = 'flask-conical'
}
# Optimize's sections (the prototype's SEC_ICON); each has a .Filled icon for the selected nav item
$AkariSectionIcons = [ordered]@{ Optimize = 'gauge'; Customize = 'paint-brush'; Hardware = 'cpu'; Advanced = 'shield'; Tools = 'toolbox' }

# a Category's icon name
function Get-AkariCategoryIcon([string]$Category) { if ($AkariCategoryGlyphs.ContainsKey($Category)) { $AkariCategoryGlyphs[$Category] } else { 'settings' } }

# a Fluent System Icon (UI\Icons.xaml, Ic.<name>, built by build\Icons.ps1): its filled 20 x 20 path in $Brush, scaled
# to $Size by a Viewbox. $Brush 'Inherit': the text colour of the control it sits in (a nav item, a disabled menu row)
function New-AkariIcon([string]$Name, [double]$Size = 16, [string]$Brush = 'Tx') {
    $p = [Windows.Shapes.Path]::new()
    $p.Width = 20; $p.Height = 20
    $p.SetResourceReference([Windows.Shapes.Path]::DataProperty, "Ic.$Name")
    if ($Brush -eq 'Inherit') {
        $bd = [Windows.Data.Binding]::new('Foreground')
        $bd.RelativeSource = [Windows.Data.RelativeSource]::new([Windows.Data.RelativeSourceMode]::FindAncestor, [Windows.Controls.Control], 1)
        [void][Windows.Data.BindingOperations]::SetBinding($p, [Windows.Shapes.Shape]::FillProperty, $bd)
    } else { $p.SetResourceReference([Windows.Shapes.Shape]::FillProperty, $Brush) }
    $v = [Windows.Controls.Viewbox]::new(); $v.Width = $Size; $v.Height = $Size
    $v.Child = $p
    $v.Tag = $Name
    $v
}

# points an icon at another Fluent icon: one from New-AkariIcon, or a Path in XAML
function Set-AkariIcon($Icon, [string]$Name) {
    $p = if ($Icon -is [Windows.Shapes.Path]) { $Icon } else { $Icon.Child }
    $p.SetResourceReference([Windows.Shapes.Path]::DataProperty, "Ic.$Name")
    $Icon.Tag = $Name
}

# a TextBlock (or control) in one of the window's fonts: Display, Text, Small (Caption) or Mono
function Set-AkariFont($Block, [string]$Font) { $Block.SetResourceReference([Windows.Documents.TextElement]::FontFamilyProperty, "Font$Font") }

# a text block: $Size 14 = Body, 12 = Caption (FontSmall), 20 / 28 = Subtitle / Title (Display, SemiBold)
function New-AkariText([string]$Text, [double]$Size = 14, [string]$Brush = 'Tx', [string]$Weight = '') {
    $t = [Windows.Controls.TextBlock]::new()
    $t.Text = $Text
    $t.FontSize = $Size
    $t.TextWrapping = 'Wrap'
    $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $Brush)
    if ($Size -ge 20) { Set-AkariFont $t 'Display'; $t.FontWeight = 'SemiBold'; $t.LineHeight = $(if ($Size -ge 28) { 36 } else { 28 }) }
    elseif ($Size -le 12) { Set-AkariFont $t 'Small'; $t.LineHeight = 16 }
    else { $t.LineHeight = 20 }
    if ($Weight) { $t.FontWeight = $Weight }
    $t
}

# a section header between groups of cards (.sect): Body Strong, 30 px above, 8 below ($First: no space above)
function New-AkariSection([string]$Text, [switch]$First) {
    $t = New-AkariText $Text 14 'Tx' 'SemiBold'
    $t.Margin = [Windows.Thickness]::new(1, $(if ($First) { 0 } else { 30 }), 0, 8)
    $t
}

# the accent brushes' colours (Set-AkariAccent, UI\Shell.ps1) for $Theme from an AccentPalette, as @{ Key = @(A, R, G, B) }, or $null (unreadable).
# Dark: Acc = Light2, AccText = Info = Light3, AccT = black; light: Acc = Dark1, AccText = Info = Dark2, AccT = white.
# AccH / AccP = Acc at 90 / 80 %, AccSoft = Acc at 12 % (dark) / 8 % (light). Pure.
function Get-AkariAccentColors($Palette, [string]$Theme) {
    if (-not $Palette -or @($Palette).Count -lt 28) { return $null }
    $p = [byte[]]@($Palette)
    $c = { param($i, $a) , @([int]$a, [int]$p[$i * 4], [int]$p[$i * 4 + 1], [int]$p[$i * 4 + 2]) }
    if ($Theme -eq 'Light') { $acc = 4; $text = 5; $on = 255; $soft = 0x14 } else { $acc = 1; $text = 0; $on = 0; $soft = 0x1F }
    @{
        Acc = (& $c $acc 255); AccH = (& $c $acc 0xE6); AccP = (& $c $acc 0xCC); AccSoft = (& $c $acc $soft)
        AccText = (& $c $text 255); Info = (& $c $text 255); AccT = @(255, $on, $on, $on)
    }
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

# a small mark (restart, Safe Mode, an unread State): a 16 px icon in Mu with a tooltip (.card .end's marks)
function New-AkariGlyph([string]$Icon, [string]$Brush, [string]$Tip) {
    $g = New-AkariIcon $Icon 16 $Brush
    $g.VerticalAlignment = 'Center'
    $g.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    if ($Tip) { $g.ToolTip = $Tip; [Windows.Controls.ToolTipService]::SetInitialShowDelay($g, 600) }
    $g
}

# a Tweak's marks, the prototype's marks(): restart (arrow-clockwise), Safe Mode (power), each with its tooltip
function New-AkariMarks($Tweak) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Orientation = 'Horizontal'; $sp.VerticalAlignment = 'Center'
    if ($Tweak.Reboot) { [void]$sp.Children.Add((New-AkariGlyph 'arrow-clockwise' 'Mu' 'Restart required')) }
    if ($Tweak.SafeMode) { [void]$sp.Children.Add((New-AkariGlyph 'power' 'Mu' 'Runs in Safe Mode: Akari restarts into it and back')) }
    $sp
}

# a badge (.badge, 20 px, 4 px corners, Caption): AkariOS (Sub with a CtlBd stroke, Mu text), Caution (WarnSoft, a
# filled Warn warning icon, Tx text), Advanced (solid Warn, WarnT text)
function New-AkariBadge([string]$Kind) {
    $b = [Windows.Controls.Border]::new()
    $b.CornerRadius = [Windows.CornerRadius]::new(4)
    $b.Height = 20
    $b.Padding = [Windows.Thickness]::new(8, 0, 8, 0)
    $b.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $b.VerticalAlignment = 'Center'
    $fg, $bg = switch ($Kind) {
        'AkariOS' { 'Mu', 'Sub' }
        'Caution' { 'Tx', 'WarnSoft' }
        default { 'WarnT', 'Warn' }
    }
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bg)
    if ($Kind -eq 'AkariOS') { $b.BorderThickness = [Windows.Thickness]::new(1); $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CtlBd') }
    $sp = [Windows.Controls.StackPanel]::new(); $sp.Orientation = 'Horizontal'; $sp.VerticalAlignment = 'Center'
    if ($Kind -eq 'Caution') { $i = New-AkariIcon 'triangle-alert.Filled' 12 'Warn'; $i.Margin = [Windows.Thickness]::new(0, 0, 4, 0); [void]$sp.Children.Add($i) }
    $t = New-AkariText $Kind 12 $fg
    $t.TextWrapping = 'NoWrap'
    [void]$sp.Children.Add($t)
    $b.Child = $sp
    $b.Tag = $Kind
    $b
}

# a Tweak's badges, the prototype's akBadge() + badge(): AkariOS, then its Risk (Caution / Advanced)
function New-AkariBadges($Tweak) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Orientation = 'Horizontal'; $sp.VerticalAlignment = 'Center'
    if ($Tweak.AkariOS) { [void]$sp.Children.Add((New-AkariBadge 'AkariOS')) }
    if ($Tweak.Risk -in 'Caution', 'Advanced') { [void]$sp.Children.Add((New-AkariBadge $Tweak.Risk)) }
    $sp
}

# a Settings card (.card): a 20 px icon, the title and its Caption description, then $End (controls, marks) on the
# right. $Style: SettingCard (a Border), CardButton (clickable) or CardRow (a row inside an expander, no icon column).
# Returns @{ Card; Title; Desc; End; Icon; Text }
function New-AkariSettingsCard([string]$Icon, [string]$Title, [string]$Desc = '', $End = $null, [string]$Style = 'SettingCard') {
    $dp = [Windows.Controls.DockPanel]::new()
    $dp.LastChildFill = $true
    $ic = $null
    if ($Icon) {
        $ic = New-AkariIcon $Icon 20 'Tx'
        $ic.Margin = [Windows.Thickness]::new(0, 0, 16, 0)
        $ic.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($ic, 'Left')
        [void]$dp.Children.Add($ic)
    }
    $endPanel = [Windows.Controls.StackPanel]::new()
    $endPanel.Orientation = 'Horizontal'; $endPanel.VerticalAlignment = 'Center'
    $endPanel.Margin = [Windows.Thickness]::new(16, 0, 0, 0)
    foreach ($x in @($End)) { if ($x) { [void]$endPanel.Children.Add($x) } }
    [Windows.Controls.DockPanel]::SetDock($endPanel, 'Right')
    [void]$dp.Children.Add($endPanel)
    $txt = [Windows.Controls.StackPanel]::new(); $txt.VerticalAlignment = 'Center'
    $tt = New-AkariText $Title 14
    [void]$txt.Children.Add($tt)
    $dd = New-AkariText $Desc 12 'Mu'
    $dd.Margin = [Windows.Thickness]::new(0, 2, 0, 0)
    if (-not $Desc) { $dd.Visibility = 'Collapsed' }
    [void]$txt.Children.Add($dd)
    [void]$dp.Children.Add($txt)
    $card = if ($Style -eq 'CardButton') { [Windows.Controls.Button]::new() } else { [Windows.Controls.Border]::new() }
    if ($Style -ne 'Plain') { $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style) }
    if ($Style -eq 'CardButton') { $card.Content = $dp } else { $card.Child = $dp }
    @{ Card = $card; Title = $tt; Desc = $dd; End = $endPanel; Icon = $ic; Text = $txt }
}

# an expander (WinUI SettingsExpander, the prototype's .exp): a head card (icon, title, description, $End, a chevron
# that turns) and a body of rows (CardRow) that opens and closes by animating its height (ADR 0008).
# Returns @{ Card; Head; Body; Panel (= Body); Count (a Caption on the right, e.g. "3 of 5"); Title; Desc }
function New-AkariExpander([string]$Icon, [string]$Title, [string]$Desc = '', [bool]$Open = $false, $End = $null) {
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CategoryCard')
    $sp = [Windows.Controls.StackPanel]::new()
    $count = New-AkariText '' 12 'Mu'
    $count.TextWrapping = 'NoWrap'; $count.VerticalAlignment = 'Center'; $count.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $ends = @($End) + $count
    $h = New-AkariSettingsCard $Icon $Title $Desc $ends 'Plain'
    $head = [Windows.Controls.Primitives.ToggleButton]::new()
    $head.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'ExpHead')
    $inner = $h.Card.Child; $h.Card.Child = $null
    $head.Content = $inner
    $head.IsChecked = $Open
    $body = [Windows.Controls.StackPanel]::new()
    $body.ClipToBounds = $true
    if (-not $Open) { $body.Height = 0 }
    $head.Tag = $body
    $head.Add_Click({ param($s, $e) Set-AkariSize $s.Tag Height $(if ($s.IsChecked) { 'Auto' } else { 0 }) Base })
    [void]$sp.Children.Add($head); [void]$sp.Children.Add($body)
    $card.Child = $sp
    @{ Card = $card; Head = $head; Body = $body; Panel = $body; Count = $count; Title = $h.Title; Desc = $h.Desc }
}

# a row inside an expander (.exp .row): $Content on the left (a check box, text), $End on the right
function New-AkariExpanderRow($Content, $End = $null, [double]$Left = 52) {
    $b = [Windows.Controls.Border]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CardRow')
    $b.Padding = [Windows.Thickness]::new($Left, 8, 16, 8)
    $dp = [Windows.Controls.DockPanel]::new()
    if ($End) {
        $endPanel = [Windows.Controls.StackPanel]::new(); $endPanel.Orientation = 'Horizontal'; $endPanel.VerticalAlignment = 'Center'
        $endPanel.Margin = [Windows.Thickness]::new(16, 0, 0, 0)
        foreach ($x in @($End)) { if ($x) { [void]$endPanel.Children.Add($x) } }
        [Windows.Controls.DockPanel]::SetDock($endPanel, 'Right'); [void]$dp.Children.Add($endPanel)
    }
    foreach ($x in @($Content)) { if ($x) { [void]$dp.Children.Add($x) } }
    $b.Child = $dp
    $b
}

# an InfoBar (WinUI, the prototype's .info): $Kind Info (InfoSoft, an Info icon), Warn, Ok or Bad; a filled severity
# icon, the bold title and its text on one line, then $Actions (buttons) and an optional close button (-Close). It
# opens and closes by animating its height and opacity (ADR 0008): Show-AkariInfoBar. Returns @{ Bar; Title; Text; Actions; Close }
function New-AkariInfoBar([string]$Kind, [string]$Title, [string]$Text = '', $Actions = $null, [switch]$Close) {
    $icon, $brush, $fill = switch ($Kind) {
        'Warn' { 'triangle-alert', 'Warn', 'WarnSoft' }
        'Ok'   { 'circle-check', 'Ok', 'OkSoft' }
        'Bad'  { 'error-circle', 'Bad', 'BadSoft' }
        default { 'info', 'Info', 'InfoSoft' }
    }
    $b = [Windows.Controls.Border]::new()
    $b.CornerRadius = [Windows.CornerRadius]::new(4)
    $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Bd')
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $fill)
    $b.Padding = [Windows.Thickness]::new(16, 12, 16, 12)
    $b.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $b.ClipToBounds = $true
    $dp = [Windows.Controls.DockPanel]::new()
    $ic = New-AkariIcon "$icon.Filled" 16 $brush
    $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $ic.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
    $acts = [Windows.Controls.StackPanel]::new(); $acts.Orientation = 'Horizontal'; $acts.VerticalAlignment = 'Center'
    foreach ($a in @($Actions)) { if ($a) { $a.Margin = [Windows.Thickness]::new(12, 0, 0, 0); [void]$acts.Children.Add($a) } }
    $x = $null
    if ($Close) {
        $x = [Windows.Controls.Button]::new()
        $x.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Ghost')
        $x.Width = 32; $x.Height = 32; $x.Padding = [Windows.Thickness]::new(0); $x.Margin = [Windows.Thickness]::new(8, -4, -8, -4)
        $x.ToolTip = 'Close'
        $x.Content = New-AkariIcon 'x' 16 'Mu'
        $x.Tag = $b
        $x.Add_Click({ param($s, $e) Hide-AkariInfoBar $s.Tag })
        [void]$acts.Children.Add($x)
    }
    [Windows.Controls.DockPanel]::SetDock($acts, 'Right'); [void]$dp.Children.Add($acts)
    $t = [Windows.Controls.TextBlock]::new()
    $t.TextWrapping = 'Wrap'; $t.VerticalAlignment = 'Center'
    $r1 = [Windows.Documents.Run]::new($Title); $r1.FontWeight = 'SemiBold'
    $r2 = [Windows.Documents.Run]::new($Text); $r2.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, 'Mu')
    [void]$t.Inlines.Add($r1); [void]$t.Inlines.Add([Windows.Documents.Run]::new('  ')); [void]$t.Inlines.Add($r2)
    [void]$dp.Children.Add($t)
    $b.Child = $dp
    $b.Tag = $Kind
    @{ Bar = $b; Title = $r1; Text = $r2; Actions = $acts; Close = $x }
}

# an InfoBar in or out: its height and opacity animate over Motion.Slow (ADR 0008), then it is collapsed
function Show-AkariInfoBar($Bar) {
    if ($Bar.Visibility -eq 'Visible' -and $Bar.Opacity -ge 1) { return }
    $Bar.Visibility = 'Visible'
    if ($Bar.IsLoaded) { $Bar.Height = 0; $Bar.Opacity = 0; Set-AkariSize $Bar Height 'Auto' Slow -Fade } else { $Bar.Opacity = 1 }
}
function Hide-AkariInfoBar($Bar) {
    if ($Bar.Visibility -ne 'Visible') { return }
    if (-not $Bar.IsLoaded -or -not $script:AkariMotionOn) { $Bar.Visibility = 'Collapsed'; return }
    Set-AkariSize $Bar Height 0 Slow -Fade
    $Bar.Margin = [Windows.Thickness]::new(0)
}

# a SelectorBar (WinUI, .selbar): $Items as Selector radio buttons, $Current picked, over a 16 x 3 Acc underline that
# slides to the picked one (Move-AkariUnderline); $OnPick { param($Value) } runs on a pick.
# Returns @{ Bar; Items; Line }
function New-AkariSelectorBar([string[]]$Items, [string]$Current, [scriptblock]$OnPick) {
    $g = [Windows.Controls.Grid]::new()
    $g.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $g.HorizontalAlignment = 'Left'
    $row = [Windows.Controls.WrapPanel]::new()
    $cv = [Windows.Controls.Canvas]::new(); $cv.IsHitTestVisible = $false
    $line = [Windows.Controls.Border]::new()
    $line.Width = 16; $line.Height = 3; $line.CornerRadius = [Windows.CornerRadius]::new(1.5)
    $line.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Acc')
    $line.Visibility = 'Hidden'
    [Windows.Controls.Canvas]::SetTop($line, 35)
    [void]$cv.Children.Add($line)
    $group = 'sel' + [guid]::NewGuid().ToString('N')
    foreach ($i in $Items) {
        $rb = [Windows.Controls.RadioButton]::new()
        $rb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Selector')
        $rb.Content = $i; $rb.Tag = $i; $rb.GroupName = $group
        $rb.IsChecked = ($i -eq $Current)
        [void]$row.Children.Add($rb)
    }
    [void]$g.Children.Add($row); [void]$g.Children.Add($cv)
    $state = @{ Line = $line; Row = $row; OnPick = $OnPick; Quiet = $false }
    $row.Tag = $state
    $row.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler]{
        param($s, $e)
        $st = $s.Tag
        [void](Move-AkariUnderline $st.Line $e.OriginalSource $true)
        if (-not $st.Quiet -and $st.OnPick) { & $st.OnPick ([string]$e.OriginalSource.Tag) }
    })
    $row.Add_Loaded({ param($s, $e) $c = @($s.Children | Where-Object { $_.IsChecked })[0]; [void](Move-AkariUnderline $s.Tag.Line $c $false) })
    $row.Add_SizeChanged({ param($s, $e) $c = @($s.Children | Where-Object { $_.IsChecked })[0]; [void](Move-AkariUnderline $s.Tag.Line $c $false) })
    @{ Bar = $g; Items = $row; Line = $line; State = $state }
}

# picks $Value on a SelectorBar without running its OnPick (scrolling moves the selection)
function Set-AkariSelectorValue($Bar, [string]$Value) {
    $Bar.State.Quiet = $true
    try { foreach ($rb in $Bar.Items.Children) { if ([string]$rb.Tag -eq $Value -and -not $rb.IsChecked) { $rb.IsChecked = $true } } } finally { $Bar.State.Quiet = $false }
}

# a filter box (Downloads' search, Guided's Apps and Tweaks steps): a Flat TextBox with its hint and a search icon.
# $Changed gets the trimmed text on every key. Returns @{ Box (the Grid to add); Text (the TextBox) }
function New-AkariFilterBox([string]$Hint, [double]$Width, [scriptblock]$Changed) {
    $sb = [Windows.Controls.Grid]::new(); $sb.Width = $Width
    $q = [Windows.Controls.TextBox]::new()
    $q.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Flat')
    $q.Padding = [Windows.Thickness]::new(10, 5, 32, 6)
    $h = New-AkariText $Hint 14 'Ter'
    $h.IsHitTestVisible = $false; $h.Margin = [Windows.Thickness]::new(12, 0, 0, 1); $h.VerticalAlignment = 'Center'
    $ic = New-AkariIcon 'search' 14 'Mu'; $ic.HorizontalAlignment = 'Right'; $ic.Margin = [Windows.Thickness]::new(0, 0, 10, 0); $ic.IsHitTestVisible = $false
    [void]$sb.Children.Add($q); [void]$sb.Children.Add($h); [void]$sb.Children.Add($ic)
    $q.Tag = @{ Hint = $h; Changed = $Changed }
    $q.Add_TextChanged({ param($s, $a) $s.Tag.Hint.Visibility = if ($s.Text) { 'Collapsed' } else { 'Visible' }; & $s.Tag.Changed $s.Text.Trim() })
    @{ Box = $sb; Text = $q }
}

# a button with its text and click (an InfoBar's action, Open log, Done)
function New-AkariBarButton([string]$Text, [scriptblock]$Click, [string]$Style = 'Btn') {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style)
    $b.Content = $Text
    $b.Add_Click($Click)
    $b
}

# a progress ring (.ring, 16 px): a 30 % Acc arc spinning once every 1.2 s, forever (a busy loop: no Motion token)
function New-AkariRing([double]$Size = 16) {
    $p = [Windows.Shapes.Path]::new()
    $p.Width = $Size; $p.Height = $Size
    $p.Data = [Windows.Media.Geometry]::Parse('M8,1.5 A6.5,6.5 0 0 1 14.5,8')
    $p.Stretch = 'None'
    $p.StrokeThickness = 2; $p.StrokeStartLineCap = 'Round'; $p.StrokeEndLineCap = 'Round'
    $p.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, 'Acc')
    $p.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
    $rt = [Windows.Media.RotateTransform]::new()
    $p.RenderTransform = $rt
    $p.VerticalAlignment = 'Center'
    Start-AkariLoop $rt ([Windows.Media.RotateTransform]::AngleProperty) 0 360 1.2
    $p
}

# an icon on an 8 px AccSoft square (.tile .ico): the tiles, the phases. $Brush / $Fill: the icon colour and the square's
function New-AkariBlob([string]$Icon, [double]$Size = 40, [string]$Brush = 'AccText', [string]$Fill = 'AccSoft') {
    $b = [Windows.Controls.Border]::new()
    $b.Width = $Size; $b.Height = $Size
    $b.CornerRadius = [Windows.CornerRadius]::new(8)
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $Fill)
    $b.VerticalAlignment = 'Center'
    $i = New-AkariIcon $Icon ([Math]::Round($Size / 2)) $Brush
    $i.HorizontalAlignment = 'Center'; $i.VerticalAlignment = 'Center'
    $b.Child = $i
    $b.Tag = $Icon
    $b
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

# a Guided Tweaks row (.exp .row): a check box (a Choice: a combobox starting on "No change"), the name and its
# description, the badges, the marks (restart, Safe Mode, an unread State).
# Returns @{ Tweak; State; Current; Initial; Row; Control; Glyphs; Muted }. $Current: a Choice's current value.
function New-AkariTweakRow($Tweak, [string]$State, $Current = $null) {
    $e = @{ Tweak = $Tweak; State = $State; Current = $Current; Initial = 'None'; Muted = $false }
    $glyphs = New-AkariMarks $Tweak
    if ($Tweak.Kind -ne 'Action' -and $State -in 'Custom', 'Unknown') {
        $tip = if ($State -eq 'Custom') { 'Custom value' } else { 'State unknown' }
        [void]$glyphs.Children.Add((New-AkariGlyph 'circle-help' 'Ter' $tip))
    }
    $name = [Windows.Controls.TextBlock]::new()
    [void]$name.Inlines.Add([Windows.Documents.Run]::new($Tweak.Name))
    $name.TextWrapping = 'Wrap'
    $txt = [Windows.Controls.StackPanel]::new(); $txt.VerticalAlignment = 'Center'
    [void]$txt.Children.Add($name)
    if ($Tweak.Description) { $d = New-AkariText ([string]$Tweak.Description) 12 'Mu'; [void]$txt.Children.Add($d) }
    $end = @((New-AkariBadges $Tweak), $glyphs)
    if ($Tweak.Kind -eq 'Choice') {
        $ctl = [Windows.Controls.ComboBox]::new()
        $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
        $ctl.IsEditable = $Tweak.Editable
        $ctl.MinWidth = 200
        # index 0 is always "No change"
        $none = [Windows.Controls.ComboBoxItem]::new()
        $none.Content = 'No change'
        [void]$ctl.Items.Add($none)
        $def = Resolve-AkariDefault $Tweak.Default
        foreach ($c in $Tweak.Choices) {
            $it = [Windows.Controls.ComboBoxItem]::new()
            $label = if ($c.Label) { $c.Label } else { "$($c.Value)" }
            # Recommended / Windows default on the right of the drop-down row (the ComboItem template's note: the item's Uid)
            if (Test-AkariRegMatch $c.Value $Tweak.Recommended) { $it.Uid = 'Recommended' }
            elseif (Test-AkariRegMatch $c.Value $def) { $it.Uid = 'Windows default' }
            $it.Content = $label
            $it.Tag = $c.Value
            [void]$ctl.Items.Add($it)
        }
        $end += $ctl
        $left = $txt
        $pad = 52
    } else {
        $ctl = [Windows.Controls.CheckBox]::new()
        $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
        $ctl.Content = $txt
        $ctl.HorizontalAlignment = 'Stretch'
        $left = $ctl
        $pad = 52
    }
    $row = New-AkariExpanderRow $left $end $pad
    $row.ToolTip = Get-AkariRowTip $Tweak $State
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($row, 600)
    $row.Tag = $Tweak.Id
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
