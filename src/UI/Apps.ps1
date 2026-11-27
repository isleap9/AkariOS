# Apps: the apps pages (plan docs/plans/2026-11-19-winui-3.md, the prototype's Guided Apps step, and Downloads with
# its Windows apps and External apps). Remove: FR33THY Ultimate's "bloatware" in four lists under a SelectorBar, every item checkable: Store
# apps (every removable package on this PC, Win11Debloat's names and risk levels), Optional features, Windows features
# (both read in the background) and legacy apps (OneDrive, Remote Desktop...). The AkariOS pick is exactly what FR33THY
# removes: everything but its keep-list. Install: the app installs (Tweaks\Apps\Install), from winget where possible,
# as cards (Guided: tickable; Downloads: store cards with Install). Needs UI\Selection.ps1, UI\Cards.ps1, Core\Appx.ps1.

$script:AppRows = [ordered]@{}
$script:AppsView = $null
$script:OnlyInstalled = $true
$script:AppsQuery = ''
$script:AppTab = 'Remove'
# the last quick select, applied again to the feature rows that arrive after it
$script:AppsPick = $null
# each Risk's meaning (a Caution / Advanced badge on the row, New-AkariRiskMark): Safe = recommended to remove
$AkariAppDots = @{
    Safe     = @{ Icon = 'circle-check'; Brush = 'Ok'; Label = 'Recommended' }
    Caution  = @{ Icon = 'circle-minus'; Brush = 'Warn'; Label = 'Optional' }
    Advanced = @{ Icon = 'triangle-alert'; Brush = 'Bad'; Label = 'Not recommended' }
}

# Store apps: every AppxRemove Entry from the data file, plus each installed package the file doesn't list (built as
# an Entry of the AppxRemove Group). Sorted by name. Pure, no WPF: $Installed are package names.
function Get-AkariAppList($Tweaks, $Groups, [string[]]$Installed) {
    $g = @($Groups | Where-Object { $_.EntryKind -eq 'AppxRemove' }) | Select-Object -First 1
    if (-not $g) { return }
    $have = @{}
    foreach ($i in $Installed) { $have[$i] = $true }
    $list = @($Tweaks | Where-Object { $_.Group -eq $g.Id })
    $known = @{}
    foreach ($t in $list) { $known[$t.Package] = $true }
    $list += @($Installed | Where-Object { -not $known.ContainsKey($_) } | ForEach-Object { New-AkariEntry $g @{ Name = $_ } })
    $list | Sort-Object Name | ForEach-Object { [pscustomobject]@{ Tweak = $_; Installed = $have.ContainsKey($_.Package) } }
}

# Optional features or Windows features: one Entry per name found on this PC, for the Group of $EntryKind. Pure.
function Get-AkariFoundList($Groups, [string]$EntryKind, [string[]]$Names) {
    $g = @($Groups | Where-Object { $_.EntryKind -eq $EntryKind }) | Select-Object -First 1
    if (-not $g) { return }
    $Names | Where-Object { $_ } | ForEach-Object { New-AkariEntry $g @{ Name = $_ } } | Sort-Object Name |
        ForEach-Object { [pscustomobject]@{ Tweak = $_; Installed = $true } }
}

# legacy apps: the removals with their own file (Tweaks\Apps\Remove, no Group); installed = their Detect says not
# gone yet (quick file and registry checks)
function Get-AkariLegacyRemoveList($Tweaks) {
    $Tweaks | Where-Object { $_.Section -eq 'Apps' -and $_.Category -eq 'Remove' -and -not $_.Group -and (-not $_.Requires -or -not (Test-AkariRequirement $_)) } | Sort-Object Name | ForEach-Object {
        $gone = $false
        if ($_.Detect) { try { $gone = [bool](& $_.Detect) } catch { } }
        [pscustomobject]@{ Tweak = $_; Installed = -not $gone }
    }
}

# the Install tab's cards, in this order (an app with another AppType goes under Other, before the restore card);
# System tools to Home server & streaming and Languages & SDKs came with winutil's apps (W5)
$AkariAppTypes = 'Browsers', 'Communication', 'Game launchers', 'Gaming & hardware', 'Media', 'Utilities', 'System tools', 'Documents',
    'Network & remote', 'Home server & streaming', 'Runtimes', 'Dev tools', 'Languages & SDKs'
$AkariRestoreType = 'Restore removed apps'

# an install's Caution mark (paid, or adds a driver or service; the row's description says which): @{ Icon; Brush;
# Tip }, or $null for a Safe install and for every removal (those have their Risk marks). Pure, no WPF.
function Get-AkariInstallMark($Tweak) {
    if ($Tweak.Category -ne 'Install' -or "$($Tweak.Risk)" -ne 'Caution') { return $null }
    @{ Icon = 'triangle-alert'; Brush = 'Warn'; Tip = 'Check before installing: paid, or adds a driver or service' }
}

# the rows of the Install tab: the app installs, by name. Pure, no WPF.
function Get-AkariInstallList($Tweaks) {
    $Tweaks | Where-Object { $_.Section -eq 'Apps' -and $_.Category -eq 'Install' -and (-not $_.Requires -or -not (Test-AkariRequirement $_)) } | Sort-Object Name |
        ForEach-Object { [pscustomobject]@{ Tweak = $_; Installed = $true } }
}

# the Install tab's cards: @{ Title; Items } per AppType, in $AkariAppTypes order, then Other, then the restore card
# with only the Store apps missing from this PC ($Appx: the package names on it). Pure, no WPF.
function Get-AkariInstallCards($Tweaks, [string[]]$Appx) {
    $have = @{}
    foreach ($a in $Appx) { $have[$a] = $true }
    $all = @(Get-AkariInstallList $Tweaks)
    foreach ($t in $AkariAppTypes) {
        $items = @($all | Where-Object { $_.Tweak.AppType -eq $t })
        if ($items.Count) { [pscustomobject]@{ Title = $t; Items = $items } }
    }
    $other = @($all | Where-Object { $_.Tweak.AppType -notin @($AkariAppTypes) + $AkariRestoreType })
    if ($other.Count) { [pscustomobject]@{ Title = 'Other'; Items = $other } }
    $missing = @($all | Where-Object { $_.Tweak.AppType -eq $AkariRestoreType -and -not ($_.Tweak.Package -and $have.ContainsKey($_.Tweak.Package)) })
    [pscustomobject]@{ Title = $AkariRestoreType; Items = $missing }
}

# the table's last column: the Store id, the package or feature name, a winget id, or where an install comes from
function Get-AkariAppSource($Tweak) {
    if ($Tweak.StoreId) { return "Microsoft Store: $($Tweak.StoreId)" }
    if ($Tweak.Package) { return $Tweak.Package }
    if ($Tweak.Winget -and $Tweak.WingetSource -eq 'msstore') { return "Microsoft Store: $(@($Tweak.Winget) -join ', ')" }
    if ($Tweak.Winget) { return "winget: $(@($Tweak.Winget) -join ', ')" }
    if ($Tweak.Category -eq 'Remove') { return $Tweak.Id }
    'AkariOS download'
}

function Test-AkariRemoveRow($e) { $e.Tweak.Category -eq 'Remove' }

function New-AkariAppCell([string]$Text, [int]$Col, [string]$Brush = 'Tx', [double]$Size = 13) {
    $t = [Windows.Controls.TextBlock]::new()
    $t.Text = $Text
    $t.FontSize = $Size
    $t.TextTrimming = 'CharacterEllipsis'
    $t.VerticalAlignment = 'Center'
    $t.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $Brush)
    [Windows.Controls.Grid]::SetColumn($t, $Col)
    $t
}

# ---- app icons, all without a background: an installed Store app's own logo (read once by Get-AkariAppsView into
# $script:AppLogos), else the bundled Assets\Apps\<package or id>.png (build\AppIcons.ps1), else the box icon on a Sub square.
# A black-or-white logo is drawn in the theme's text colour: bundled ones are saved as <key>.mono.png (a mask), a
# Store logo that is white only (made for a dark Start menu) is found by Test-AkariWhiteLogo.

$script:AppLogos = @{}

# the image file of a row's icon, or $null. Pure, no WPF: $Logos = package name -> logo path; $Dir = Assets\Apps.
function Get-AkariAppIconFile($Tweak, $Logos, [string]$Dir) {
    if ($Tweak.Package -and $Logos -and $Logos[$Tweak.Package]) { return $Logos[$Tweak.Package] }
    # .NET's file check, not Test-Path: this runs for every row (four provider calls a row took ~0.8 ms)
    foreach ($k in $Tweak.Package, $Tweak.Id) {
        if (-not $k) { continue }
        foreach ($f in [IO.Path]::Combine($Dir, "$k.png"), [IO.Path]::Combine($Dir, "$k.mono.png")) {
            if ([IO.File]::Exists($f)) { return $f }
        }
    }
    $null
}

# true when an image's visible pixels are white or near white (no colour): it would vanish on the light theme.
# Every second pixel of each second row is enough.
function Test-AkariWhiteLogo([Windows.Media.Imaging.BitmapSource]$Image) {
    $b = [Windows.Media.Imaging.FormatConvertedBitmap]::new($Image, [Windows.Media.PixelFormats]::Bgra32, $null, 0)
    $w = $b.PixelWidth; $h = $b.PixelHeight
    $px = [byte[]]::new($w * $h * 4)
    $b.CopyPixels($px, $w * 4, 0)
    $n = 0; $white = 0
    for ($y = 0; $y -lt $h; $y += 2) {
        for ($x = 0; $x -lt $w; $x += 2) {
            $i = ($y * $w + $x) * 4
            if ($px[$i + 3] -lt 100) { continue }
            $n++
            $lo = [Math]::Min($px[$i], [Math]::Min($px[$i + 1], $px[$i + 2]))
            $hi = [Math]::Max($px[$i], [Math]::Max($px[$i + 1], $px[$i + 2]))
            if ($lo -ge 200 -and $hi - $lo -le 30) { $white++ }
        }
    }
    $n -gt 0 -and $white / $n -ge 0.9
}

# a row's icon ($Size px): the image (a mask in the text colour when it is black-or-white), or the box placeholder
# (an optional or Windows feature: settings, else box)
function New-AkariAppIcon($Tweak, [double]$Size = 28, $Logos = $script:AppLogos) {
    $file = Get-AkariAppIconFile $Tweak $Logos (Join-Path $Root 'Assets\Apps')
    $icon = $null
    if ($file) {
        try {
            $bi = Get-AkariBitmap $file ([int]($Size * 2))
            $mono = $file -like '*.mono.png'
            if (-not $mono -and $Tweak.Package -and $Logos -and $Logos[$Tweak.Package] -eq $file) { $mono = Test-AkariWhiteLogo $bi }
            if ($mono) {
                # a black-or-white logo in the theme's text colour (the prototype's .mono-ic, inverted in light)
                $icon = [Windows.Shapes.Rectangle]::new()
                $icon.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'Tx')
                $icon.OpacityMask = [Windows.Media.ImageBrush]::new($bi)
            } else {
                $icon = [Windows.Controls.Image]::new()
                $icon.Source = $bi
                [Windows.Media.RenderOptions]::SetBitmapScalingMode($icon, 'HighQuality')
            }
            $icon.Width = $Size; $icon.Height = $Size
        } catch { $icon = $null }
    }
    if (-not $icon) {
        # no logo: the prototype's .ph, a box icon on a Sub square
        $icon = [Windows.Controls.Border]::new()
        $icon.Width = $Size; $icon.Height = $Size
        $icon.CornerRadius = [Windows.CornerRadius]::new($(if ($Size -lt 40) { 6 } else { 8 }))
        $icon.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Sub')
        $kind = if ($Tweak.Group -in 'capability', 'feature') { 'settings' } else { 'box' }
        $g = New-AkariIcon $kind ([Math]::Round($Size / 2)) 'Mu'
        $g.HorizontalAlignment = 'Center'; $g.VerticalAlignment = 'Center'
        $icon.Child = $g
    }
    $icon.HorizontalAlignment = 'Left'
    $icon.VerticalAlignment = 'Center'
    $icon
}

# a removal row (the prototype's .lrow): a check box, the 28 px icon, the name over its Caption description, the Risk
# badge (Caution / Advanced) and the source in Ter; tinted AccSoft while checked. One entry:
# @{ Tweak; Installed; Row; Control; Muted; Mark; Caution }. An install row (Guided's grid) is New-AkariAppCard.
function New-AkariAppRow($Item) {
    $t = $Item.Tweak
    if ($t.Category -ne 'Remove') { return New-AkariAppCard $Item 'Check' }
    $e = @{ Tweak = $t; Installed = $Item.Installed; Muted = $false }
    $b = [Windows.Controls.Border]::new()
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S1')
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Bd')
    $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.CornerRadius = [Windows.CornerRadius]::new(4)
    $b.MinHeight = 60
    $b.Padding = [Windows.Thickness]::new(16, 8, 16, 8)
    $b.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    $b.Tag = $t.Id
    $dp = [Windows.Controls.DockPanel]::new()
    $cb = [Windows.Controls.CheckBox]::new()
    $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $cb.Tag = $t.Id
    $cb.VerticalAlignment = 'Center'
    $cb.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [Windows.Controls.DockPanel]::SetDock($cb, 'Left'); [void]$dp.Children.Add($cb)
    $icon = New-AkariAppIcon $t 28
    $icon.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [Windows.Controls.DockPanel]::SetDock($icon, 'Left'); [void]$dp.Children.Add($icon)
    $end = [Windows.Controls.StackPanel]::new(); $end.Orientation = 'Horizontal'; $end.VerticalAlignment = 'Center'
    $end.Margin = [Windows.Thickness]::new(12, 0, 0, 0)
    $mark = New-AkariRiskMark $t.Risk
    if ($mark) { [void]$end.Children.Add($mark) }
    $src = New-AkariText (Get-AkariAppSource $t) 12 'Ter'
    $src.TextWrapping = 'NoWrap'; $src.TextTrimming = 'CharacterEllipsis'; $src.MaxWidth = 220; $src.VerticalAlignment = 'Center'
    $src.ToolTip = if ($Item.Installed) { $src.Text } else { "$($src.Text) (not on this PC)" }
    [void]$end.Children.Add($src)
    [Windows.Controls.DockPanel]::SetDock($end, 'Right'); [void]$dp.Children.Add($end)
    $txt = [Windows.Controls.StackPanel]::new(); $txt.VerticalAlignment = 'Center'
    $name = New-AkariText $t.Name 14
    if ($t.Keep) { $name.ToolTip = 'Kept by the AkariOS pick (FR33THY''s keep-list)' }
    [void]$txt.Children.Add($name)
    [void]$txt.Children.Add((New-AkariText $(if ($t.Description) { $t.Description } else { 'Not in Akari''s list: found on this PC' }) 12 'Mu'))
    [void]$dp.Children.Add($txt)
    if (-not $Item.Installed) { $txt.Opacity = 0.6; $icon.Opacity = 0.6 }
    $b.Child = $dp
    $cb.Add_Click({ param($s, $a) Step-AkariAppCheck ([string]$s.Tag) })
    $e.Row = $b; $e.Control = $cb
    $e
}

# a removal's Risk as the prototype shows it: a Caution or Advanced badge; Safe (recommended) has none
function New-AkariRiskMark([string]$Risk) {
    if ($Risk -notin 'Caution', 'Advanced') { return $null }
    $m = New-AkariBadge $Risk
    $m.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $m.ToolTip = $AkariAppDots[$Risk].Label
    $m
}

# Downloads' categories (the prototype's SelectorBar), each an AppType list. An app's category: the first whose types
# hold its AppType, else Tools; a removed Store app's is "Microsoft Store" (under All). Pure.
$AkariDownloadCategories = [ordered]@{
    Gaming        = @('Game launchers', 'Gaming & hardware')
    Browsers      = @('Browsers')
    Communication = @('Communication')
    Media         = @('Media')
    Tools         = @('Utilities', 'System tools', 'Documents', 'Network & remote', 'Home server & streaming')
    Development   = @('Runtimes', 'Dev tools', 'Languages & SDKs')
}
# the Store apps the debloat removed: under All only, labelled as the Store's
$AkariDownloadRestore = 'Microsoft Store'
function Get-AkariDownloadCategory($Tweak) {
    if ("$($Tweak.AppType)" -eq $AkariRestoreType) { return $AkariDownloadRestore }
    foreach ($k in $AkariDownloadCategories.Keys) { if ("$($Tweak.AppType)" -in $AkariDownloadCategories[$k]) { return $k } }
    'Tools'
}

# an app card (the prototype's .app): the 40 px icon, the name and its category, then on the right a check box
# ($Mode Check: Guided's Install) or the install action ($Mode Action: Downloads; Set-AkariAppCardState). A Caution
# install has its badge's warning icon next to the name. One entry: @{ Tweak; Installed; Row; Control; Act; Mark; Caution }
function New-AkariAppCard($Item, [string]$Mode = 'Check') {
    $t = $Item.Tweak
    $e = @{ Tweak = $t; Installed = $Item.Installed; Muted = $false; State = '' }
    $b = [Windows.Controls.Border]::new()
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S1')
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Bd')
    $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.CornerRadius = [Windows.CornerRadius]::new(8)
    $b.Padding = [Windows.Thickness]::new(14)
    $b.Margin = [Windows.Thickness]::new(4)
    $b.Tag = $t.Id
    $dp = [Windows.Controls.DockPanel]::new()
    $icon = New-AkariAppIcon $t 40
    $icon.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [Windows.Controls.DockPanel]::SetDock($icon, 'Left'); [void]$dp.Children.Add($icon)
    $act = [Windows.Controls.Grid]::new()
    $act.Width = 92; $act.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($act, 'Right'); [void]$dp.Children.Add($act)
    $txt = [Windows.Controls.StackPanel]::new(); $txt.VerticalAlignment = 'Center'
    # the name wraps (.app .n b); a Caution install's warning icon follows it
    $nm = New-AkariText $t.Name 14
    if ($m = Get-AkariInstallMark $t) {
        $e.Caution = New-AkariIcon 'triangle-alert.Filled' 12 $m.Brush
        $e.Caution.Margin = [Windows.Thickness]::new(6, 0, 0, -1); $e.Caution.ToolTip = $m.Tip
        [void]$nm.Inlines.Add([Windows.Documents.InlineUIContainer]::new($e.Caution))
    }
    [void]$txt.Children.Add($nm)
    $cat = New-AkariText (Get-AkariDownloadCategory $t) 12 'Mu'
    [void]$txt.Children.Add($cat)
    [void]$dp.Children.Add($txt)
    $b.Child = $dp
    $b.ToolTip = "$($t.Description)`n$(Get-AkariAppSource $t)".Trim()
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($b, 600)
    if ($Mode -eq 'Check') {
        $cb = [Windows.Controls.CheckBox]::new()
        $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
        $cb.Tag = $t.Id
        $cb.HorizontalAlignment = 'Right'
        $cb.Add_Click({ param($s, $a) Step-AkariAppCheck ([string]$s.Tag) })
        [void]$act.Children.Add($cb)
        $e.Control = $cb
        # the whole card ticks its box (the prototype's role="checkbox")
        $b.Add_MouseLeftButtonUp({ param($s, $a) if ($a.OriginalSource -is [Windows.Controls.Primitives.ToggleButton]) { return }; $x = $script:AppRows[[string]$s.Tag]; if ($x) { $x.Control.IsChecked = -not $x.Control.IsChecked; Step-AkariAppCheck ([string]$s.Tag) } })
        # "Installed on this PC" (Set-AkariAppsInstalled) shows as the category line
        $e.Mark = $cat
    }
    $e.Row = $b; $e.Act = $act
    $e
}

# a Downloads card's action ($State): '' = the Install button, Waiting / Installing = the ring, Installed = the green
# mark that pops in from 80 % (Motion.Slow), Failed = a red mark with the reason as its tooltip and Install again
function Set-AkariAppCardState($e, [string]$State, [string]$Why = '') {
    $e.State = $State
    $a = $e.Act
    $a.Children.Clear()
    $sp = [Windows.Controls.StackPanel]::new(); $sp.Orientation = 'Horizontal'; $sp.HorizontalAlignment = 'Right'; $sp.VerticalAlignment = 'Center'
    switch ($State) {
        { $_ -in 'Waiting', 'Installing' } {
            [void]$sp.Children.Add((New-AkariRing 16))
            $l = New-AkariText $State 12 'Mu'; $l.Margin = [Windows.Thickness]::new(8, 0, 0, 0); $l.TextWrapping = 'NoWrap'
            [void]$sp.Children.Add($l)
        }
        'Installed' {
            $i = New-AkariIcon 'circle-check.Filled' 16 'Ok'; $i.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
            [void]$sp.Children.Add($i)
            $l = New-AkariText 'Installed' 12 'Ok'; $l.TextWrapping = 'NoWrap'
            [void]$sp.Children.Add($l)
            if ($e.Tweak.Winget -and -not $e.Tweak.RemoveWith) {
                # winutil W4's Uninstall, one app at a time: right-click
                $m = [Windows.Controls.ContextMenu]::new()
                $u = [Windows.Controls.MenuItem]::new(); $u.Header = 'Uninstall'; $u.Tag = $e.Tweak.Id
                $u.Icon = New-AkariIcon 'trash-2' 16 'Inherit'
                $u.Add_Click({ param($s, $x) Start-AkariUninstall @(Find-AkariTweak ([string]$s.Tag)) })
                [void]$m.Items.Add($u)
                $e.Row.ContextMenu = $m
            }
            if ($e.Popped) { Start-AkariMotion $sp Pop 0.8 1 -Speed Slow }
        }
        'Failed' {
            $i = New-AkariIcon 'error-circle.Filled' 16 'Bad'; $i.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
            [void]$sp.Children.Add($i)
            $l = New-AkariText 'Failed' 12 'Bad'; $l.TextWrapping = 'NoWrap'
            [void]$sp.Children.Add($l)
            $sp.ToolTip = $Why
            $sp.Cursor = 'Hand'; $sp.Tag = $e.Tweak.Id
            $sp.Add_MouseLeftButtonUp({ param($s, $x) Add-AkariInstall ([string]$s.Tag) })
        }
        default {
            $btn = [Windows.Controls.Button]::new()
            $btn.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
            $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
            $i = New-AkariIcon 'download' 16 'Inherit'; $i.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
            [void]$c.Children.Add($i); [void]$c.Children.Add((New-AkariText 'Install' 14 'Tx'))
            $btn.Content = $c
            $btn.Tag = $e.Tweak.Id
            $btn.Add_Click({ param($s, $x) Add-AkariInstall ([string]$s.Tag) })
            [void]$sp.Children.Add($btn)
            $e.Row.ContextMenu = $null
        }
    }
    [void]$a.Children.Add($sp)
}

# a grid of cards that fills its width (the native app's CardGridLayout): as many columns of at least $Min px as fit,
# 8 px apart, each row as tall as its tallest card (a row = a Grid of star columns), laid out again when its width or
# the shown cards change (Update-AkariCardGrid). Cards go in with Add-AkariGridCard; a Collapsed card takes no cell.
function New-AkariCardGrid([double]$Min = 220) {
    $g = [Windows.Controls.StackPanel]::new()
    $g.Margin = [Windows.Thickness]::new(-4)
    $g.Tag = @{ Cards = [Collections.Generic.List[object]]::new(); Min = $Min; Cols = 3 }
    $g.Add_SizeChanged({
        param($s, $a)
        $n = Get-AkariGridColumns $a.NewSize.Width $s.Tag.Min
        if ($n -ne $s.Tag.Cols) { $s.Tag.Cols = $n; Update-AkariCardGrid $s }
    })
    $g
}

# how many columns of at least $Min px, $Gap apart, fit in $Width (at least one). Pure.
function Get-AkariGridColumns([double]$Width, [double]$Min, [double]$Gap = 8) {
    if ($Width -le 0 -or [double]::IsNaN($Width) -or [double]::IsInfinity($Width)) { return 1 }
    [Math]::Max(1, [int][Math]::Floor(($Width + $Gap) / ([Math]::Max(1, $Min) + $Gap)))
}

function Add-AkariGridCard($Grid, $Card) { $Grid.Tag.Cards.Add($Card) }

# the shown cards in rows of the grid's column count, in the order they were added
function Update-AkariCardGrid($Grid) {
    if (-not $Grid) { return }
    $n = [Math]::Max(1, [int]$Grid.Tag.Cols)
    foreach ($r in @($Grid.Children)) { $r.Children.Clear() }
    $Grid.Children.Clear()
    $row = $null
    $i = 0
    foreach ($c in $Grid.Tag.Cards) {
        if ($c.Visibility -eq 'Collapsed') { continue }
        if ($i % $n -eq 0) {
            $row = [Windows.Controls.Grid]::new()
            for ($k = 0; $k -lt $n; $k++) { $row.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new()) }
            [void]$Grid.Children.Add($row)
        }
        [Windows.Controls.Grid]::SetColumn($c, $i % $n)
        [void]$row.Children.Add($c)
        $i++
    }
}

# a row was checked or unchecked: checked = Remove or Install (an Advanced item asks first), unchecked = no change
function Step-AkariAppCheck([string]$Id) {
    $e = $script:AppRows[$Id]
    if ($e.Muted) { return }
    $next = if ($e.Control.IsChecked) { 'Optimized' } else { 'None' }
    $q = Get-AkariConfirmText $e.Tweak $next
    if ($q -and -not (Confirm-AkariDialog $q 'Continue')) { Set-AkariAppChecked $e $false; return }
    Set-AkariPending $script:Sel $e.Tweak 'Unknown' $next
    Set-AkariAppRowLook $e
    Update-AkariAppsStatus
}

# a checked removal row is tinted AccSoft (.lrow.sel)
function Set-AkariAppRowLook($e) {
    if (-not (Test-AkariRemoveRow $e)) { return }
    $e.Row.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $(if ($e.Control.IsChecked) { 'AccSoft' } else { 'S1' }))
}

function Set-AkariAppChecked($e, [bool]$On) {
    $e.Muted = $true
    try { $e.Control.IsChecked = $On } finally { $e.Muted = $false }
    Set-AkariPending $script:Sel $e.Tweak 'Unknown' $(if ($On) { 'Optimized' } else { 'None' })
    Set-AkariAppRowLook $e
}

# quick select on the Remove lists: checks the removals on this PC that $Pick says yes to and unchecks every other one,
# in all four lists (no confirmation: the user picked a set, and Review lists every item before anything runs).
# Remembered, so the features read later get the same pick.
function Select-AkariApps([scriptblock]$Pick, $Rows = $null) {
    if ($null -eq $Rows) { $script:AppsPick = $Pick; $Rows = @($script:AppRows.Values | Where-Object { Test-AkariRemoveRow $_ }) }
    foreach ($e in $Rows) { Set-AkariAppChecked $e ($e.Installed -and (& $Pick $e.Tweak)) }
    Update-AkariAppsStatus
}

function Clear-AkariInstalls {
    foreach ($e in @($script:AppRows.Values | Where-Object { -not (Test-AkariRemoveRow $_) })) { Set-AkariAppChecked $e $false }
    Update-AkariAppsStatus
}

# the installs with these ids are on this PC: Guided's cards say so under their name; Downloads' cards show Installed
function Set-AkariAppsInstalled([string[]]$Ids) {
    $script:InstalledIds = @($Ids)
    foreach ($e in @($script:AppRows.Values | Where-Object { $_.Mark })) {
        $on = $e.Tweak.Id -in $Ids
        $e.Mark.Text = if ($on) { 'Installed on this PC' } else { Get-AkariDownloadCategory $e.Tweak }
        $e.Mark.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($on) { 'Ok' } else { 'Mu' }))
    }
    foreach ($e in @($script:DlCards.Values)) {
        if ($e.State -in 'Waiting', 'Installing') { continue }
        Set-AkariAppCardState $e $(if ($e.Tweak.Id -in $Ids) { 'Installed' } else { '' })
    }
}

# the command bar's count and Remove button (the prototype's "n selected", "Remove (n)", disabled at 0)
function Update-AkariAppsStatus {
    if (-not $script:AppsStatus) { return }
    $on = @($script:AppRows.Values | Where-Object { $_.Control.IsChecked })
    $rm = @($on | Where-Object { Test-AkariRemoveRow $_ }).Count
    $script:AppsStatus.Text = "$rm selected"
    if ($StepNext) { Update-AkariStepFooter }
}

# the filter box and "Only installed": hide the rows that don't match. No argument = the box's query ($script:AppsQuery)
function Set-AkariAppsFilter($q = $null) {
    if ($null -ne $q) { $script:AppsQuery = "$q".Trim() }
    $q = $script:AppsQuery
    foreach ($e in $script:AppRows.Values) {
        $hit = (-not $q) -or ("$($e.Tweak.Name) $($e.Tweak.Description) $(Get-AkariAppSource $e.Tweak)" -like "*$q*")
        if ($script:OnlyInstalled -and -not $e.Installed) { $hit = $false }
        $e.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
    }
    if ($script:AppsParts) { Update-AkariCardGrid $script:AppsParts.InstallTables }
}

# a command bar button (.btn, or .btn.sub with -Subtle) with an optional icon
function New-AkariAppsButton([string]$Text, [string]$Tip, [scriptblock]$Click, [string]$Icon = '', [switch]$Subtle) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $(if ($Subtle) { 'Ghost' } else { 'Btn' }))
    if ($Icon) {
        $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
        $i = New-AkariIcon $Icon 16 'Inherit'; $i.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
        [void]$c.Children.Add($i); $t = [Windows.Controls.TextBlock]::new(); $t.Text = $Text; [void]$c.Children.Add($t)
        $b.Content = $c
    } else { $b.Content = $Text }
    $b.ToolTip = $Tip
    $b.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    if ($Click) { $b.Add_Click($Click) }
    $b
}

# one of the Remove lists: its rows (registered in $script:AppRows). Returns @{ Card; Rows (panel); Title; Name }
function New-AkariAppTable([string]$Title, [string]$Last, $Items) {
    $rows = [Windows.Controls.StackPanel]::new()
    $t = @{ Card = $rows; Rows = $rows; Title = [Windows.Controls.TextBlock]::new(); Name = $Title }
    Add-AkariAppRows $t $Items
    $t
}

# adds rows to a list and keeps its count ($Table.Title: "Name (n)", read by the tests)
function Add-AkariAppRows($Table, $Items) {
    foreach ($item in $Items) {
        $e = New-AkariAppRow $item
        $script:AppRows[$item.Tweak.Id] = $e
        [void]$Table.Rows.Children.Add($e.Row)
    }
    $n = @($Table.Rows.Children | Where-Object { $_ -is [Windows.Controls.Border] }).Count
    $Table.Title.Text = "$($Table.Name) ($n)"
}

# ---- the Optional features and Windows features lists take seconds to read: a background runspace reads them once
# (Guided's Apps step and Downloads' Windows apps share it), a timer adds their rows when it is done
$script:FeatureNames = $null; $script:FeatureReading = $false

function Start-AkariFeatureRead {
    if ($script:FeatureNames) { Complete-AkariFeatureRead $script:FeatureNames.Capabilities $script:FeatureNames.Features $script:FeatureNames.Failed; return }
    if ($script:FeatureReading) { return }
    $script:FeatureReading = $true
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $appx = "$Root\Core\Appx.ps1" -replace "'", "''"
    [void]$ps.AddScript(". '$appx'; @{ Capabilities = @(Get-AkariCapabilitiesInstalled); Features = @(Get-AkariFeaturesEnabled) }")
    $job = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke() }
    $timer = [Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Tag = $job
    $timer.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        $r = $null
        try { $r = @($j.Ps.EndInvoke($j.Handle))[0] } catch { }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        if ($r -is [hashtable]) { Complete-AkariFeatureRead $r.Capabilities $r.Features } else { Complete-AkariFeatureRead @() @() $true }
    })
    $timer.Start()
}

# the background read is done: fill the two feature lists of each view not filled yet (and apply its last pick)
function Complete-AkariFeatureRead([string[]]$Capabilities, [string[]]$Features, [bool]$Failed = $false) {
    $script:FeatureReading = $false
    $script:FeatureNames = @{ Capabilities = @($Capabilities); Features = @($Features); Failed = $Failed }
    Add-AkariWindowsFeatures $Capabilities $Features $Failed
    $p = $script:AppsParts
    if (-not $p -or $p.FeaturesFilled) { return }
    $p.FeaturesFilled = $true
    foreach ($x in @(@($p.CapTable, 'CapabilityRemove', $Capabilities), @($p.FeatTable, 'FeatureDisable', $Features))) {
        $x[0].Rows.Children.Clear()
        $items = @(Get-AkariFoundList $script:Groups $x[1] $x[2])
        if ($Failed) { [void]$x[0].Rows.Children.Add((New-AkariText 'Could not be read. Open this page again to retry.' 12 'Bad')) }
        Add-AkariAppRows $x[0] $items
        if ($script:AppsPick) {
            $ids = @($items | ForEach-Object { $_.Tweak.Id })
            Select-AkariApps $script:AppsPick @($script:AppRows.Values | Where-Object { $_.Tweak.Id -in $ids })
        }
    }
    Set-AkariAppsFilter
    Update-AkariAppsStatus
}

# the Remove lists' SelectorBar picked $Name: that list alone, sliding in from the right (24 px, Motion.Slow)
$AkariRemoveLists = 'Store apps', 'Optional features', 'Windows features', 'Legacy apps'
function Show-AkariRemoveList([string]$Name) {
    $p = $script:AppsParts
    if (-not $p) { return }
    $script:RemoveList = $Name
    $map = @{ 'Store apps' = $p.StoreTable; 'Optional features' = $p.CapTable; 'Windows features' = $p.FeatTable; 'Legacy apps' = $p.LegacyTable }
    foreach ($k in $map.Keys) { $map[$k].Card.Visibility = if ($k -eq $Name) { 'Visible' } else { 'Collapsed' } }
    Start-AkariMotion $map[$Name].Card Fade 0 1 -Speed Slow
    Start-AkariMotion $map[$Name].Card Slide 24 0 -Speed Slow
}

# kept for the callers of the old tabs: the removal lists show in Guided
function Show-AkariAppsTab([string]$Tab) { $script:AppTab = $Tab }

# the apps view as Guided shows it ('': Remove, then Install as tickable cards, Quick select); Downloads' Windows apps
# has its own view (Get-AkariWindowsView)
function Set-AkariAppsOnly([string]$Tab) {
    $p = $script:AppsParts
    $guided = -not $Tab
    foreach ($x in $p.InstallHead, $p.InstallTables, $p.RemoveHead, $p.SeeAll) { if ($x) { $x.Visibility = if ($guided) { 'Visible' } else { 'Collapsed' } } }
    if ($p.QuickSelect) { $p.QuickSelect.Visibility = if ($guided) { 'Visible' } else { 'Collapsed' } }
}

# ---- the Store packages: one read in the background (Start-AkariAppxRead), the view built when it is in
# (Complete-AkariAppxRead); "Reading..." until then. $AkariReadInline: read at once on this thread (tests).
if ($null -eq $AkariReadInline) { $AkariReadInline = $false }
# @{ Names (every package: the restore card); Installed (the removable ones); Logos (their logos) } once read, else
# $null; Clear-AkariSteps forgets it (read again after a Run) and bumps Gen, so a read started before is dropped
$script:Appx = $null; $script:AppxJob = $null; $script:AppxGen = 0

# the read itself, as text: run here (inline) or in the job's runspace
$AkariAppxReadCode = @'
$pkgs = @(try { Get-AkariAppxPackages } catch { })
$installed = @(try { Get-AkariAppxInstalled $pkgs } catch { })
$logos = @{}
try { $logos = Get-AkariAppxLogos @($pkgs | Where-Object { $_.Name -in $installed }) } catch { }
@{ Names = @($pkgs | ForEach-Object { $_.Name }); Installed = $installed; Logos = $logos }
'@

function Start-AkariAppxRead {
    if ($script:Appx -or $script:AppxJob) { return }
    if ($AkariReadInline) { $script:Appx = & ([scriptblock]::Create($AkariAppxReadCode)); return }
    $shared = [hashtable]::Synchronized(@{})
    $job = Start-AkariJob ("`$AkariShared.Result = & {`n$AkariAppxReadCode`n}") ([System.Collections.Concurrent.ConcurrentQueue[string]]::new()) "$Root\Core" $shared
    $job.Gen = $script:AppxGen
    $script:AppxJob = $job
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(150)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Write-ErrLog "Apps read: $_" }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        Complete-AkariAppxRead $j
    })
    $tm.Start()
}

# the packages are in: the apps page is built again if it is showing, and a Quick select that waited is picked
function Complete-AkariAppxRead($Job) {
    if ($script:AppxJob -eq $Job) { $script:AppxJob = $null }
    if ($Job.Gen -ne $script:AppxGen) { return }
    $r = $Job.Shared.Result
    $script:Appx = if ($r) { $r } else { @{ Names = @(); Installed = @(); Logos = @{} } }
    if (Get-Command Resume-AkariQuickSelect -ErrorAction SilentlyContinue) { Resume-AkariQuickSelect }
    if (($script:Cat -eq 'Install AkariOS' -and $script:Mode -eq 'Guided' -and $script:Step -eq 0) -or $script:Cat -eq 'Downloads') { Show-Page }
}

# forgets the apps read and the views built on it (a Run changed what is on this PC): both again next time
function Clear-AkariAppsView {
    $script:AppRows = [ordered]@{}
    $script:AppsView = $null
    $script:DlView = $null; $script:DlCards = [ordered]@{}; $script:DlParts = $null
    $script:Win = $null; $script:WinSel = New-AkariSelection
    $script:FeatureNames = $null; $script:FeatureReading = $false
    $script:Appx = $null; $script:AppxJob = $null; $script:AppxGen++
}

# "Reading the apps on this PC..." with a ring, until the read is in
function New-AkariReading([string]$Text) {
    $sp = [Windows.Controls.StackPanel]::new(); $sp.Orientation = 'Horizontal'; $sp.Margin = [Windows.Thickness]::new(2, 4, 0, 0)
    [void]$sp.Children.Add((New-AkariRing 16))
    $t = New-AkariText $Text 14 'Mu'; $t.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    [void]$sp.Children.Add($t)
    $sp
}

# builds the apps view once (Guided's Apps step): the Remove lists under a SelectorBar and a command bar,
# then (Guided) the installs as tickable cards. The features are read in the background.
function Get-AkariAppsView {
    if ($script:AppsView) { return $script:AppsView }
    if (-not $script:Appx) {
        Start-AkariAppxRead
        if (-not $script:Appx) { return New-AkariReading ('Reading the apps on this PC' + [char]0x2026) }
    }
    $installed = @($script:Appx.Installed)
    $script:AppLogos = if ($script:Appx.Logos) { $script:Appx.Logos } else { @{} }
    $script:AppRows = [ordered]@{}
    $script:AppsPick = $null
    $p = @{}
    $view = [Windows.Controls.StackPanel]::new()

    $p.RemoveHead = New-AkariSection 'Remove' -First
    [void]$view.Children.Add($p.RemoveHead)
    $script:RemoveList = 'Store apps'
    $p.Selector = New-AkariSelectorBar $AkariRemoveLists 'Store apps' { param($v) Show-AkariRemoveList $v }
    [void]$view.Children.Add($p.Selector.Bar)
    # the command bar (.cmdbar): Quick select, Select recommended, AkariOS, Clear, Only installed, the filter, the count
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $right = [Windows.Controls.StackPanel]::new(); $right.Orientation = 'Horizontal'
    $script:AppsStatus = New-AkariText '0 selected' 12 'Mu'
    $script:AppsStatus.VerticalAlignment = 'Center'; $script:AppsStatus.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [void]$right.Children.Add($script:AppsStatus)
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$bar.Children.Add($right)
    $left = [Windows.Controls.WrapPanel]::new()
    if (Get-Command New-AkariQuickSelect -ErrorAction SilentlyContinue) { $p.QuickSelect = New-AkariQuickSelect; [void]$left.Children.Add($p.QuickSelect) }
    [void]$left.Children.Add((New-AkariAppsButton 'Select recommended' 'Win11Debloat''s pick: what is on this PC and marked Recommended' { Select-AkariApps { param($t) $t.Risk -eq 'Safe' } } 'check'))
    [void]$left.Children.Add((New-AkariAppsButton 'AkariOS' 'The AkariOS debloat (FR33THY''s): every Store app, optional feature, Windows feature and legacy app on this PC except its keep-list' { Select-AkariApps { param($t) -not $t.Keep } }))
    [void]$left.Children.Add((New-AkariAppsButton 'Clear' 'Uncheck everything to remove' { Select-AkariApps { param($t) $false } } -Subtle))
    $only = [Windows.Controls.CheckBox]::new()
    $only.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $only.Content = 'Only installed'
    $only.IsChecked = $script:OnlyInstalled
    $only.VerticalAlignment = 'Center'
    $only.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $only.Add_Click({ param($s, $a) $script:OnlyInstalled = [bool]$s.IsChecked; Set-AkariAppsFilter })
    [void]$left.Children.Add($only)
    # the filter box (the native app's): Remove's lists and Install's cards, by name, description and source
    $script:AppsQuery = ''
    $fb = New-AkariFilterBox 'Filter apps' 240 { param($q) Set-AkariAppsFilter $q }
    $fb.Box.Margin = [Windows.Thickness]::new(8, 0, 0, 0); $fb.Box.VerticalAlignment = 'Center'
    $p.Filter = $fb.Text
    [void]$left.Children.Add($fb.Box)
    [void]$bar.Children.Add($left)
    $p.RemoveBar = $bar
    [void]$view.Children.Add($bar)

    # the four lists, one shown at a time; the two feature ones say "Reading..." until the background read is done
    $p.RemoveTables = [Windows.Controls.Grid]::new()
    $p.StoreTable = New-AkariAppTable 'Store apps' 'App ID' @(Get-AkariAppList $script:Tweaks $script:Groups $installed)
    $p.CapTable = New-AkariAppTable 'Optional features' 'Capability' @()
    $p.FeatTable = New-AkariAppTable 'Windows features' 'Feature' @()
    $p.LegacyTable = New-AkariAppTable 'Legacy apps' 'Id' @(Get-AkariLegacyRemoveList $script:Tweaks)
    foreach ($t in $p.CapTable, $p.FeatTable) {
        [void]$t.Rows.Children.Add((New-AkariReading ('Reading what is on this PC' + [char]0x2026)))
        $t.Title.Text = "$($t.Name) (reading...)"
    }
    foreach ($t in $p.StoreTable, $p.CapTable, $p.FeatTable, $p.LegacyTable) {
        $t.Card.Visibility = if ($t -eq $p.StoreTable) { 'Visible' } else { 'Collapsed' }
        [void]$p.RemoveTables.Children.Add($t.Card)
    }
    [void]$view.Children.Add($p.RemoveTables)
    $p.SeeAll = [Windows.Controls.Button]::new()
    $p.SeeAll.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Link')
    $p.SeeAll.Content = "Downloads $([char]0x203A) Windows apps lists the same apps and features, and removes them right away"
    $p.SeeAll.Margin = [Windows.Thickness]::new(1, 8, 0, 0)
    $p.SeeAll.HorizontalAlignment = 'Left'
    $p.SeeAll.Add_Click({ $script:DlSection = 'Windows'; Select-AkariPage 'Downloads' })
    [void]$view.Children.Add($p.SeeAll)

    # Guided: the installs as tickable cards, then the Store apps the debloat removed
    $p.InstallHead = New-AkariSection 'Install'
    [void]$view.Children.Add($p.InstallHead)
    $p.InstallTables = New-AkariCardGrid
    $appx = @($script:Appx.Names)
    foreach ($c in Get-AkariInstallCards $script:Tweaks $appx) {
        foreach ($item in $c.Items) {
            $e = New-AkariAppCard $item 'Check'
            $script:AppRows[$item.Tweak.Id] = $e
            Add-AkariGridCard $p.InstallTables $e.Row
        }
    }
    Update-AkariCardGrid $p.InstallTables
    [void]$view.Children.Add($p.InstallTables)

    $script:AppsParts = $p
    $script:AppsView = $view
    $script:AppsTabFresh = $false
    $script:AppsNew = $true
    # the feature lists take seconds: read once the view is built
    Start-AkariFeatureRead
    Set-AkariAppsFilter
    Update-AkariAppsStatus
    $view
}

# ---- Downloads (its own page), in two sections (the native app's, after Winhance's Software & Apps: its idea and
# layout only, rule 9): Windows apps (the four Remove lists as cards, Remove (n) in one Run after the restore point, a
# removed app that can come back has Install; it was the Remove apps page) and External apps (the store cards: Install
# acts right away, queued one at a time with no restore point; several picked at once, Install (n))
$AkariDownloadSections = [ordered]@{ Windows = 'Windows apps'; External = 'External apps' }
$script:DlSection = 'Windows'
$script:DlView = $null; $script:DlCards = [ordered]@{}; $script:DlFilter = 'All'; $script:DlQuery = ''; $script:InstallQueue = [Collections.Generic.List[string]]::new()
# Windows apps: its view and cards (@{ View; Rows (id -> card); Grids, Notes (list -> grid / note); Count; Go; GoText;
# Pick; FeaturesFilled }), its own Selection, the list shown, Only installed (off: removed apps may come back), the search
$script:Win = $null; $script:WinSel = $null; $script:WinList = 'Store apps'; $script:WinOnly = $false; $script:WinQuery = ''

# what puts a removal back: @{ 'pkg:<package>' = the store Group's Entry; 'rm:<removal id>' = the install naming it in
# RemoveWith }. Pure.
function New-AkariRestoreIndex($Tweaks) {
    $ix = @{}
    foreach ($t in $Tweaks) {
        if ($t.Group -eq 'store' -and $t.Package -and -not $ix.ContainsKey("pkg:$($t.Package)")) { $ix["pkg:$($t.Package)"] = $t }
        if ($t.RemoveWith -and -not $ix.ContainsKey("rm:$($t.RemoveWith)")) { $ix["rm:$($t.RemoveWith)"] = $t }
    }
    $ix
}
# a removal's way back: a Store app's Store reinstall (same package), a legacy app's install; none for features. Pure.
function Get-AkariRestoreFor($Removal, $Index) {
    if ($Removal.Group -eq 'appx' -and $Removal.Package) { return $Index["pkg:$($Removal.Package)"] }
    if (-not $Removal.Group) { return $Index["rm:$($Removal.Id)"] }
    $null
}

# a card's busy line: the text over a 4 px bar, sliding while it runs (Installing), empty while it waits
function New-AkariBusyLine([string]$Text, [bool]$Moving) {
    $sp = [Windows.Controls.StackPanel]::new(); $sp.VerticalAlignment = 'Center'
    [void]$sp.Children.Add((New-AkariText $Text 12 'Mu'))
    $track = [Windows.Controls.Border]::new()
    $track.Height = 4; $track.CornerRadius = [Windows.CornerRadius]::new(2); $track.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    $track.ClipToBounds = $true
    $track.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Sub')
    if ($Moving) {
        $r = [Windows.Shapes.Rectangle]::new()
        $r.Width = 80; $r.HorizontalAlignment = 'Left'; $r.RadiusX = 2; $r.RadiusY = 2
        $r.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'Acc')
        $r.RenderTransform = [Windows.Media.TranslateTransform]::new()
        $track.Child = $r
        $track.Add_SizeChanged({ param($s, $a) Start-AkariLoop $s.Child.RenderTransform ([Windows.Media.TranslateTransform]::XProperty) (-80) $a.NewSize.Width 1.2 })
    }
    [void]$sp.Children.Add($track)
    $sp
}

# a store card's frame (picked from mockups): a CardButton (the whole card answers a click) holding the icon, the name
# on up to two lines, a line under it, the description on two lines and the action row. Returns @{ Row; Top; Text;
# Line; Act; Icon }
function New-AkariStoreFrame($Tweak, [string]$Desc) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CardButton')
    $b.Margin = [Windows.Thickness]::new(4); $b.Padding = [Windows.Thickness]::new(16)
    $b.VerticalAlignment = 'Stretch'
    $b.Tag = $Tweak.Id
    $g = [Windows.Controls.Grid]::new(); $g.MinHeight = 132
    foreach ($h in 'Auto', '*', 'Auto') { $rd = [Windows.Controls.RowDefinition]::new(); $rd.Height = [Windows.GridLengthConverter]::new().ConvertFromString($h); $g.RowDefinitions.Add($rd) }
    $top = [Windows.Controls.DockPanel]::new()
    $icon = New-AkariAppIcon $Tweak 48
    $icon.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [Windows.Controls.DockPanel]::SetDock($icon, 'Left'); [void]$top.Children.Add($icon)
    $txt = [Windows.Controls.StackPanel]::new(); $txt.VerticalAlignment = 'Center'
    $nm = New-AkariText $Tweak.Name 14 'Tx' 'SemiBold'
    $nm.MaxHeight = 40; $nm.TextTrimming = 'CharacterEllipsis'
    [void]$txt.Children.Add($nm)
    $line = [Windows.Controls.StackPanel]::new(); $line.Orientation = 'Horizontal'; $line.Margin = [Windows.Thickness]::new(0, 2, 0, 0)
    [void]$txt.Children.Add($line)
    [void]$top.Children.Add($txt)
    $d = New-AkariText $Desc 12 'Mu'
    $d.MaxHeight = 34; $d.TextTrimming = 'CharacterEllipsis'; $d.Margin = [Windows.Thickness]::new(0, 10, 0, 0)
    [Windows.Controls.Grid]::SetRow($d, 1)
    $act = [Windows.Controls.Grid]::new(); $act.MinHeight = 32; $act.Margin = [Windows.Thickness]::new(0, 10, 0, 0)
    [Windows.Controls.Grid]::SetRow($act, 2)
    [void]$g.Children.Add($top); [void]$g.Children.Add($d); [void]$g.Children.Add($act)
    $b.Content = $g
    @{ Row = $b; Top = $top; Text = $txt; Line = $line; Act = $act; Icon = $icon }
}

# a ticked or picked card: an AccSoft tint and a 2 px accent outline
function Set-AkariStoreCardLook($Card, [bool]$On) {
    $Card.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, $(if ($On) { 'AccSoft' } else { 'S1' }))
    $Card.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, $(if ($On) { 'Acc' } else { 'Bd' }))
    $Card.BorderThickness = [Windows.Thickness]::new($(if ($On) { 2 } else { 1 }))
}

# the action row's two ends: $Left at the left, $Right at the right
function Set-AkariCardActions($Act, $Left, $Right) {
    $Act.Children.Clear()
    if ($Left) { $Left.HorizontalAlignment = 'Left'; $Left.VerticalAlignment = 'Center'; [void]$Act.Children.Add($Left) }
    if ($Right) { $Right.HorizontalAlignment = 'Right'; $Right.VerticalAlignment = 'Center'; [void]$Act.Children.Add($Right) }
}
function New-AkariIconText([string]$Icon, [string]$Text, [string]$Brush) {
    $sp = [Windows.Controls.StackPanel]::new(); $sp.Orientation = 'Horizontal'
    $i = New-AkariIcon $Icon 14 $Brush; $i.Margin = [Windows.Thickness]::new(0, 0, 6, 0); $i.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($i)
    $t = New-AkariText $Text 12 $Brush; $t.TextWrapping = 'NoWrap'; $t.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($t)
    $sp
}
function New-AkariSmallButton([string]$Text, [string]$Icon, [string]$Style, [string]$Tag, [scriptblock]$Click) {
    $btn = [Windows.Controls.Button]::new()
    $btn.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style)
    $btn.MinWidth = 0; $btn.Padding = [Windows.Thickness]::new(12, 4, 12, 4)
    if ($Icon) {
        $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
        $i = New-AkariIcon $Icon 14 'Inherit'; $i.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
        [void]$c.Children.Add($i); $tb = [Windows.Controls.TextBlock]::new(); $tb.Text = $Text; [void]$c.Children.Add($tb)
        $btn.Content = $c
    } else { $btn.Content = $Text }
    $btn.Tag = $Tag
    $btn.Add_Click($Click)
    $btn
}

# ---- Windows apps

# a Windows app's card: its rating (Recommended / Optional / Not recommended) and source under the name; installed =
# a "Remove" tick (a click anywhere on the card ticks it) and Installed; removed = Removed and, when AkariOS can put it
# back, Install. One entry: @{ Tweak; Installed; Row; Control; Act; Restore; Restoring; Gone; Muted }
function New-AkariWindowsCard($Item) {
    $t = $Item.Tweak
    $e = @{ Tweak = $t; Installed = [bool]$Item.Installed; Muted = $false; Restoring = $false; Gone = $false; Control = $null }
    $e.Restore = Get-AkariRestoreFor $t $script:RestoreIndex
    $f = New-AkariStoreFrame $t $(if ($t.Description) { $t.Description } else { 'Not in Akari''s list: found on this PC' })
    $dot = $AkariAppDots[[string]$t.Risk]
    if ($dot) {
        $di = New-AkariIcon $dot.Icon 12 $dot.Brush; $di.ToolTip = $dot.Label; $di.Margin = [Windows.Thickness]::new(0, 0, 6, 0); $di.VerticalAlignment = 'Center'
        [void]$f.Line.Children.Add($di)
    }
    $src = New-AkariText (Get-AkariAppSource $t) 12 'Mu'; $src.TextWrapping = 'NoWrap'; $src.TextTrimming = 'CharacterEllipsis'; $src.MaxWidth = 200
    [void]$f.Line.Children.Add($src)
    if (-not $e.Installed) { $f.Icon.Opacity = 0.6 }
    $f.Row.ToolTip = if ($t.Keep) { "$($t.Name): kept by the AkariOS pick (FR33THY's keep-list)" } else { $t.Name }
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($f.Row, 600)
    $f.Row.Add_Click({
        param($s, $a)
        if ($a.OriginalSource -ne $s) { return }
        $x = $script:Win.Rows[[string]$s.Tag]
        if ($x -and $x.Control) { $x.Control.IsChecked = -not $x.Control.IsChecked; Step-AkariWindowsCheck ([string]$s.Tag) }
    })
    $e.Row = $f.Row; $e.Act = $f.Act
    Set-AkariWindowsCardAction $e
    $e
}

function Set-AkariWindowsCardAction($e) {
    $e.Control = $null
    if ($e.Installed) {
        $cb = [Windows.Controls.CheckBox]::new()
        $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
        $cb.Content = 'Remove'; $cb.Tag = $e.Tweak.Id
        $cb.IsChecked = $script:WinSel.Contains($e.Tweak.Id)
        $cb.Add_Click({ param($s, $a) Step-AkariWindowsCheck ([string]$s.Tag) })
        $e.Control = $cb
        Set-AkariCardActions $e.Act $cb (New-AkariIconText 'circle-check.Filled' 'Installed' 'Ok')
    } elseif ($e.Restoring) {
        $l = New-AkariBusyLine ('Installing' + [char]0x2026) $true
        Set-AkariCardActions $e.Act $l $null
        $l.HorizontalAlignment = 'Stretch'
    } else {
        $right = if ($e.Restore) {
            $b = New-AkariSmallButton 'Install' 'download' 'Accent' $e.Tweak.Id { param($s, $a) Start-AkariWindowsRestore ([string]$s.Tag) }
            $b.ToolTip = $e.Restore.Name
            $b
        } else { New-AkariText 'Can''t be put back here' 12 'Ter' }
        Set-AkariCardActions $e.Act (New-AkariText 'Removed' 12 'Ter') $right
    }
    Set-AkariStoreCardLook $e.Row ([bool]($e.Control -and $e.Control.IsChecked))
}

# a card's "Remove" was ticked or unticked: an Advanced one asks first
function Step-AkariWindowsCheck([string]$Id) {
    $e = $script:Win.Rows[$Id]
    if (-not $e -or $e.Muted -or -not $e.Control) { return }
    $next = if ($e.Control.IsChecked) { 'Optimized' } else { 'None' }
    $q = Get-AkariConfirmText $e.Tweak $next
    if ($q -and -not (Confirm-AkariDialog $q 'Continue')) { Set-AkariWindowsChecked $e $false; Update-AkariWindowsStatus; return }
    Set-AkariPending $script:WinSel $e.Tweak 'Unknown' $next
    Set-AkariStoreCardLook $e.Row ([bool]$e.Control.IsChecked)
    Update-AkariWindowsStatus
}

function Set-AkariWindowsChecked($e, [bool]$On) {
    if (-not $e.Control) { return }
    $e.Muted = $true
    try { $e.Control.IsChecked = $On } finally { $e.Muted = $false }
    Set-AkariPending $script:WinSel $e.Tweak 'Unknown' $(if ($On) { 'Optimized' } else { 'None' })
    Set-AkariStoreCardLook $e.Row $On
}

# Select recommended / AkariOS / Clear: the installed apps $Pick says yes to, in all four lists; remembered for the
# features that arrive later
function Select-AkariWindowsApps([scriptblock]$Pick, $Rows = $null) {
    if ($null -eq $Rows) { $script:Win.Pick = $Pick; $Rows = @($script:Win.Rows.Values) }
    foreach ($e in $Rows) { Set-AkariWindowsChecked $e ($e.Installed -and (& $Pick $e.Tweak)) }
    Update-AkariWindowsStatus
}

# "n selected" and the accent Remove (n): off at 0 and while a removal runs
function Update-AkariWindowsStatus {
    if (-not $script:Win -or -not $script:Win.Count) { return }
    $n = $script:WinSel.Count
    $script:Win.Count.Text = "$n selected"
    $script:Win.GoText.Text = 'Remove' + $(if ($n) { " ($n)" } else { '' })
    $script:Win.Go.IsEnabled = ($n -gt 0 -and -not ($script:Job -and $script:Job.Kind -eq 'Remove'))
}

# the search and Only installed: the cards that match, the gone ones left out
function Set-AkariWindowsFilter {
    if (-not $script:Win) { return }
    $q = $script:WinQuery
    foreach ($e in $script:Win.Rows.Values) {
        $hit = (-not $e.Gone) -and ((-not $q) -or ("$($e.Tweak.Name) $($e.Tweak.Description) $(Get-AkariAppSource $e.Tweak)" -like "*$q*"))
        if ($script:WinOnly -and -not $e.Installed) { $hit = $false }
        $e.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
    }
    foreach ($g in $script:Win.Grids.Values) { Update-AkariCardGrid $g }
}

# one list at a time under its SelectorBar
function Show-AkariWindowsList([string]$Name) {
    $script:WinList = $Name
    if (-not $script:Win) { return }
    foreach ($k in @($script:Win.Grids.Keys)) {
        $on = ($k -eq $Name)
        $script:Win.Grids[$k].Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
        $note = $script:Win.Notes[$k]
        $note.Visibility = if ($on -and $note.Text) { 'Visible' } else { 'Collapsed' }
    }
    Start-AkariMotion $script:Win.Grids[$Name] Fade 0 1 -Speed Slow
}

function Add-AkariWindowsCards([string]$List, $Items) {
    $g = $script:Win.Grids[$List]
    foreach ($item in $Items) {
        $e = New-AkariWindowsCard $item
        $script:Win.Rows[$item.Tweak.Id] = $e
        Add-AkariGridCard $g $e.Row
    }
}

# the feature read is in (Complete-AkariFeatureRead): Windows apps' two feature lists, the last pick applied to them
function Add-AkariWindowsFeatures([string[]]$Capabilities, [string[]]$Features, [bool]$Failed) {
    $w = $script:Win
    if (-not $w -or -not $w.View -or $w.FeaturesFilled) { return }
    $w.FeaturesFilled = $true
    foreach ($x in @(@('Optional features', 'CapabilityRemove', $Capabilities), @('Windows features', 'FeatureDisable', $Features))) {
        $items = @(Get-AkariFoundList $script:Groups $x[1] $x[2])
        $w.Notes[$x[0]].Text = if ($Failed) { 'Could not be read. Open this page again to retry.' } else { '' }
        Add-AkariWindowsCards $x[0] $items
        if ($w.Pick) {
            $ids = @($items | ForEach-Object { $_.Tweak.Id })
            Select-AkariWindowsApps $w.Pick @($w.Rows.Values | Where-Object { $_.Tweak.Id -in $ids })
        }
    }
    Set-AkariWindowsFilter
    Show-AkariWindowsList $script:WinList
    Update-AkariWindowsStatus
}

# Windows apps, built once: the lead, the four lists' SelectorBar, the command bar (Select recommended, AkariOS,
# Clear, Only installed, "n selected", the accent Remove (n)), the search, then the list's cards. The features are read
# in the background (one read for Guided and here).
# a toolbar (a DockPanel, $Right docked right) that wraps on a narrow page (ADR 0011: Downloads' toolbars under
# 800 px, the bar being the page less its sides): $Right goes on a row of its own under the rest
function Enable-AkariBarWrap($Bar, $Right, [double]$Under = 728) {
    $Bar.Tag = @{ Right = $Right; Under = $Under }
    $Bar.Add_SizeChanged({ param($s, $e) if ($e.WidthChanged) { Set-AkariBarWrap $s ($e.NewSize.Width -lt $s.Tag.Under) } })
}
function Set-AkariBarWrap($Bar, [bool]$Narrow) {
    if (-not $Bar.Tag) { return }
    $r = $Bar.Tag.Right
    [Windows.Controls.DockPanel]::SetDock($r, $(if ($Narrow) { 'Bottom' } else { 'Right' }))
    $r.HorizontalAlignment = if ($Narrow) { 'Left' } else { 'Stretch' }
    $r.Margin = if ($Narrow) { [Windows.Thickness]::new(0, 8, 0, 0) } else { [Windows.Thickness]::new(0) }
}

function Get-AkariWindowsView {
    if ($script:Win -and $script:Win.View) { return $script:Win.View }
    if (-not $script:Appx) {
        Start-AkariAppxRead
        if (-not $script:Appx) { return New-AkariReading ('Reading the apps on this PC' + [char]0x2026) }
    }
    $script:AppLogos = if ($script:Appx.Logos) { $script:Appx.Logos } else { @{} }
    $script:RestoreIndex = New-AkariRestoreIndex $script:Tweaks
    $script:WinSel = New-AkariSelection
    $w = @{ Rows = [ordered]@{}; Grids = [ordered]@{}; Notes = @{}; Pick = $null; FeaturesFilled = $false }
    $script:Win = $w
    $view = [Windows.Controls.StackPanel]::new()
    $lead = New-AkariText 'Windows'' own apps and features. Tick what to remove, then Remove; a removed app AkariOS can put back has Install.' 14 'Mu'
    $lead.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    [void]$view.Children.Add($lead)
    $sel = New-AkariSelectorBar $AkariRemoveLists $script:WinList { param($v) Show-AkariWindowsList $v }
    [void]$view.Children.Add($sel.Bar)
    $bar = [Windows.Controls.DockPanel]::new(); $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $right = [Windows.Controls.StackPanel]::new(); $right.Orientation = 'Horizontal'; $right.VerticalAlignment = 'Center'
    $w.Count = New-AkariText '0 selected' 12 'Mu'; $w.Count.VerticalAlignment = 'Center'; $w.Count.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [void]$right.Children.Add($w.Count)
    $w.Go = [Windows.Controls.Button]::new()
    $w.Go.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
    $i = New-AkariIcon 'trash-2' 16 'AccT'; $i.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $w.GoText = [Windows.Controls.TextBlock]::new(); $w.GoText.Text = 'Remove'
    [void]$c.Children.Add($i); [void]$c.Children.Add($w.GoText)
    $w.Go.Content = $c; $w.Go.IsEnabled = $false
    $w.Go.Add_Click({ Start-AkariWindowsRemove })
    [void]$right.Children.Add($w.Go)
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$bar.Children.Add($right)
    Enable-AkariBarWrap $bar $right
    $left = [Windows.Controls.WrapPanel]::new()
    [void]$left.Children.Add((New-AkariAppsButton 'Select recommended' 'Win11Debloat''s pick: what is on this PC and marked Recommended' { Select-AkariWindowsApps { param($t) $t.Risk -eq 'Safe' } } 'check'))
    [void]$left.Children.Add((New-AkariAppsButton 'AkariOS' 'The AkariOS debloat (FR33THY''s): every Store app, optional feature, Windows feature and legacy app on this PC except its keep-list' { Select-AkariWindowsApps { param($t) -not $t.Keep } }))
    [void]$left.Children.Add((New-AkariAppsButton 'Clear' 'Uncheck everything to remove' { Select-AkariWindowsApps { param($t) $false } } -Subtle))
    $only = [Windows.Controls.CheckBox]::new()
    $only.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $only.Content = 'Only installed'; $only.IsChecked = $script:WinOnly
    $only.VerticalAlignment = 'Center'; $only.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $only.Add_Click({ param($s, $a) $script:WinOnly = [bool]$s.IsChecked; Set-AkariWindowsFilter })
    [void]$left.Children.Add($only)
    [void]$bar.Children.Add($left)
    [void]$view.Children.Add($bar)
    $script:WinQuery = ''
    $fb = New-AkariFilterBox 'Search Windows apps' 280 { param($q) $script:WinQuery = $q; Set-AkariWindowsFilter }
    $fb.Box.HorizontalAlignment = 'Left'; $fb.Box.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $w.Filter = $fb.Text
    [void]$view.Children.Add($fb.Box)
    foreach ($name in $AkariRemoveLists) {
        $note = New-AkariText '' 14 'Mu'; $note.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
        $w.Notes[$name] = $note
        [void]$view.Children.Add($note)
        $w.Grids[$name] = New-AkariCardGrid 280
        [void]$view.Children.Add($w.Grids[$name])
    }
    Add-AkariWindowsCards 'Store apps' @(Get-AkariAppList $script:Tweaks $script:Groups @($script:Appx.Installed))
    Add-AkariWindowsCards 'Legacy apps' @(Get-AkariLegacyRemoveList $script:Tweaks)
    foreach ($k in 'Optional features', 'Windows features') { $w.Notes[$k].Text = 'Reading what is on this PC' + [char]0x2026 }
    $w.View = $view
    Set-AkariWindowsFilter
    Show-AkariWindowsList $script:WinList
    Update-AkariWindowsStatus
    Start-AkariFeatureRead
    $view
}

# Remove (n): asked with the names, then one Run after the session's restore point; each card goes as the Run gets to it
function Start-AkariWindowsRemove {
    $rows = @(foreach ($id in @($script:WinSel.Keys)) { $e = $script:Win.Rows[$id]; if ($e) { $e } })
    $n = $rows.Count
    if (-not $n) { return }
    if ($script:Busy) { Show-AkariMessage "$($script:BusyLabel) is still running. Remove these when it is done." 'Info' 'Remove apps'; return }
    $names = @($rows | Select-Object -First 6 | ForEach-Object { $_.Tweak.Name }) -join ', '
    if ($n -gt 6) { $names += " and $($n - 6) more" }
    if (-not (Confirm-AkariDialog "$names.`nStore apps can be reinstalled from the Microsoft Store or Downloads." 'Remove' 'Cancel' 'Warning' "Remove $n app$(if ($n -ne 1) { 's' })?")) { return }
    $script:RemovingRows = $rows
    $script:RemovedCount = 0
    Start-AkariApply @(Get-AkariPlanItems $script:WinSel) "Removing $n app$(if ($n -ne 1) { 's' })" -Restore 'Remove apps' -Kind 'Remove'
    Update-AkariWindowsStatus
}

# the job got to item $Done: the cards before it leave their list
function Update-AkariRemoveProgress($Shared) {
    if (-not $script:RemovingRows -or -not $Shared -or -not $Shared.Total) { return }
    $moved = $false
    while ($script:RemovedCount -lt [int]$Shared.Done -and $script:RemovedCount -lt $script:RemovingRows.Count) {
        $e = $script:RemovingRows[$script:RemovedCount]
        $e.Gone = $true
        $e.Row.Visibility = 'Collapsed'
        $script:RemovedCount++
        $moved = $true
    }
    if ($moved -and $script:Win) { foreach ($g in $script:Win.Grids.Values) { Update-AkariCardGrid $g } }
}

# a removed app's Install: Downloads' queue, its card "Installing..." meanwhile
function Start-AkariWindowsRestore([string]$Id) {
    $e = $script:Win.Rows[$Id]
    if (-not $e -or -not $e.Restore) { return }
    $e.Restoring = $true
    Set-AkariWindowsCardAction $e
    Add-AkariInstall $e.Restore.Id
}

# ---- External apps

# a store card (picked from mockups): the 48 px icon, the full name on up to two lines, its type (AppType, else the
# category) with a Caution install's warning, the description on two lines, then its source and the action by State
# (Set-AkariAppCardState). A click anywhere picks it for Install (n), its box too. One entry:
# @{ Tweak; Installed; Row; Act; Check; State; Why; Selected; Muted; Caution }
function New-AkariStoreCard($Item) {
    $t = $Item.Tweak
    $e = @{ Tweak = $t; Installed = $Item.Installed; State = ''; Why = ''; Selected = $false; Muted = $false }
    $f = New-AkariStoreFrame $t "$($t.Description)"
    $type = New-AkariText $(if ($t.AppType) { "$($t.AppType)" } else { Get-AkariDownloadCategory $t }) 12 'Mu'
    $type.TextWrapping = 'NoWrap'
    [void]$f.Line.Children.Add($type)
    if ($m = Get-AkariInstallMark $t) {
        $e.Caution = New-AkariIcon 'triangle-alert.Filled' 12 $m.Brush
        $e.Caution.Margin = [Windows.Thickness]::new(6, 0, 0, 0); $e.Caution.ToolTip = $m.Tip; $e.Caution.VerticalAlignment = 'Center'
        [void]$f.Line.Children.Add($e.Caution)
    }
    $cb = [Windows.Controls.CheckBox]::new()
    $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $cb.Tag = $t.Id; $cb.VerticalAlignment = 'Top'; $cb.Margin = [Windows.Thickness]::new(8, -4, -6, 0)
    $cb.ToolTip = 'Pick it for Install (n)'
    $cb.Add_Click({ param($s, $a) $x = $script:DlCards[[string]$s.Tag]; if ($x -and -not $x.Muted) { Set-AkariStoreSelected $x ([bool]$s.IsChecked) } })
    [Windows.Controls.DockPanel]::SetDock($cb, 'Right')
    $f.Top.Children.Insert(1, $cb)
    $f.Row.ToolTip = "$($t.Description)`n$(Get-AkariAppSource $t)".Trim()
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($f.Row, 600)
    $f.Row.Add_Click({
        param($s, $a)
        if ($a.OriginalSource -ne $s) { return }
        $x = $script:DlCards[[string]$s.Tag]
        if ($x) { Set-AkariStoreSelected $x (-not $x.Selected) }
    })
    $e.Row = $f.Row; $e.Act = $f.Act; $e.Check = $cb
    $e
}

# a card can be picked while it can install (no state yet, or Failed)
function Test-AkariCardSelectable($e) { "$($e.State)" -in '', 'Failed' }

function Set-AkariStoreSelected($e, [bool]$On) {
    if ($On -and -not (Test-AkariCardSelectable $e)) { $On = $false }
    $e.Selected = $On
    $e.Muted = $true
    try { $e.Check.IsChecked = $On } finally { $e.Muted = $false }
    Set-AkariStoreCardLook $e.Row $On
    Update-AkariDownloadsSelection
}

# "n selected", Clear and the accent Install (n)
function Update-AkariDownloadsSelection {
    if (-not $script:DlParts) { return }
    $n = @($script:DlCards.Values | Where-Object { $_.Selected }).Count
    $script:DlParts.Count.Text = "$n selected"
    $script:DlParts.GoText.Text = 'Install' + $(if ($n) { " ($n)" } else { '' })
    $script:DlParts.Go.IsEnabled = $n -gt 0
    $script:DlParts.Clear.IsEnabled = $n -gt 0
}

# Install (n): the picks into the queue in the order shown
function Install-AkariSelected {
    foreach ($e in @($script:DlCards.Values | Where-Object { $_.Selected })) {
        Set-AkariStoreSelected $e $false
        Add-AkariInstall $e.Tweak.Id
    }
}
function Clear-AkariDownloadsSelection { foreach ($e in @($script:DlCards.Values | Where-Object { $_.Selected })) { Set-AkariStoreSelected $e $false } }

# a store card's action row by $State: '' = the source and a small accent Install; Waiting / Installing = a line and a
# bar; Installed = the green mark (popping in from 80 %, Motion.Slow) and a "..." menu with Uninstall (also on a
# right-click) when winget installed it; Failed = the reason as its tooltip and Try again
function Set-AkariAppCardState($e, [string]$State, [string]$Why = '') {
    $e.State = $State; $e.Why = $Why
    $e.Row.ContextMenu = $null
    if ($e.Selected -and -not (Test-AkariCardSelectable $e)) { Set-AkariStoreSelected $e $false }
    if ($e.Check) { $e.Check.Visibility = if (Test-AkariCardSelectable $e) { 'Visible' } else { 'Collapsed' } }
    $id = $e.Tweak.Id
    switch ($State) {
        { $_ -in 'Waiting', 'Installing' } {
            $l = New-AkariBusyLine $(if ($State -eq 'Waiting') { 'Waiting' + [char]0x2026 } else { 'Installing' + [char]0x2026 }) ($State -eq 'Installing')
            Set-AkariCardActions $e.Act $l $null
            $l.HorizontalAlignment = 'Stretch'
        }
        'Installed' {
            $ok = New-AkariIconText 'circle-check.Filled' 'Installed' 'Ok'
            $more = $null
            if ($e.Tweak.Winget -and -not $e.Tweak.RemoveWith) {
                $m = [Windows.Controls.ContextMenu]::new()
                $u = [Windows.Controls.MenuItem]::new(); $u.Header = 'Uninstall'; $u.Tag = $id
                $u.Icon = New-AkariIcon 'trash-2' 16 'Inherit'
                $u.Add_Click({ param($s, $x) Start-AkariUninstall @(Find-AkariTweak ([string]$s.Tag)) })
                [void]$m.Items.Add($u)
                $e.Row.ContextMenu = $m
                $more = New-AkariSmallButton ([string][char]0x2026) '' 'Ghost' $id { param($s, $a) $x = $script:DlCards[[string]$s.Tag]; if ($x -and $x.Row.ContextMenu) { $x.Row.ContextMenu.PlacementTarget = $s; $x.Row.ContextMenu.IsOpen = $true } }
                $more.ToolTip = 'More'
            }
            Set-AkariCardActions $e.Act $ok $more
            if ($e.Popped) { Start-AkariMotion $ok Pop 0.8 1 -Speed Slow }
        }
        'Failed' {
            $bad = New-AkariIconText 'error-circle.Filled' 'Failed' 'Bad'
            $bad.ToolTip = $Why
            Set-AkariCardActions $e.Act $bad (New-AkariSmallButton 'Try again' '' 'Btn' $id { param($s, $a) Add-AkariInstall ([string]$s.Tag) })
        }
        default {
            $src = New-AkariText (Get-AkariAppSource $e.Tweak) 12 'Ter'
            $src.TextWrapping = 'NoWrap'; $src.TextTrimming = 'CharacterEllipsis'; $src.Margin = [Windows.Thickness]::new(0, 0, 96, 0)
            Set-AkariCardActions $e.Act $src (New-AkariSmallButton 'Install' 'download' 'Accent' $id { param($s, $a) Add-AkariInstall ([string]$s.Tag) })
        }
    }
}

# External apps, built once: a SelectorBar of categories and a search box, the selection bar, then the store cards
function Get-AkariDownloadsView {
    if ($script:DlView) { return $script:DlView }
    if (-not $script:Appx) {
        Start-AkariAppxRead
        if (-not $script:Appx) { return New-AkariReading ('Reading the apps on this PC' + [char]0x2026) }
    }
    $script:AppLogos = if ($script:Appx.Logos) { $script:Appx.Logos } else { @{} }
    $view = [Windows.Controls.StackPanel]::new()
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    $right = [Windows.Controls.StackPanel]::new(); $right.Orientation = 'Horizontal'; $right.VerticalAlignment = 'Top'
    $fb = New-AkariFilterBox 'Search apps' 220 { param($q) $script:DlQuery = $q; Set-AkariDownloadsFilter $false }
    [void]$right.Children.Add($fb.Box)
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$bar.Children.Add($right)
    Enable-AkariBarWrap $bar $right
    $cats = @('All') + @($AkariDownloadCategories.Keys)
    $sel = New-AkariSelectorBar $cats $script:DlFilter { param($v) $script:DlFilter = $v; Set-AkariDownloadsFilter $true }
    $sel.Bar.Margin = [Windows.Thickness]::new(0)
    [void]$bar.Children.Add($sel.Bar)
    [void]$view.Children.Add($bar)
    # several at once: click cards to pick them, then Install (n)
    $p = @{}
    $pick = [Windows.Controls.StackPanel]::new(); $pick.Orientation = 'Horizontal'; $pick.HorizontalAlignment = 'Right'
    $pick.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $p.Count = New-AkariText '0 selected' 12 'Mu'; $p.Count.VerticalAlignment = 'Center'; $p.Count.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [void]$pick.Children.Add($p.Count)
    $p.Clear = New-AkariAppsButton 'Clear' 'Drop every pick' { Clear-AkariDownloadsSelection } -Subtle
    [void]$pick.Children.Add($p.Clear)
    $p.Go = [Windows.Controls.Button]::new()
    $p.Go.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
    $i = New-AkariIcon 'download' 16 'AccT'; $i.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.GoText = [Windows.Controls.TextBlock]::new(); $p.GoText.Text = 'Install'
    [void]$c.Children.Add($i); [void]$c.Children.Add($p.GoText)
    $p.Go.Content = $c
    $p.Go.Add_Click({ Install-AkariSelected })
    [void]$pick.Children.Add($p.Go)
    [void]$view.Children.Add($pick)
    $script:DlParts = $p
    $grid = New-AkariCardGrid 280
    $script:DlCards = [ordered]@{}
    # by category, in the SelectorBar's order (Gaming first); the Store reinstalls are Windows apps' now
    $order = @($AkariDownloadCategories.Keys)
    $items = @(Get-AkariInstallCards $script:Tweaks @($script:Appx.Names) | ForEach-Object { $_.Items } | Where-Object { -not $_.Tweak.Group }) |
        Sort-Object { [array]::IndexOf($order, (Get-AkariDownloadCategory $_.Tweak)) }, { $_.Tweak.Name }
    foreach ($item in $items) {
        $e = New-AkariStoreCard $item
        Set-AkariAppCardState $e $(if ($script:InstalledIds -and $item.Tweak.Id -in $script:InstalledIds) { 'Installed' } elseif ($item.Tweak.Id -in $script:InstallQueue) { 'Waiting' } else { '' })
        $script:DlCards[$item.Tweak.Id] = $e
        Add-AkariGridCard $grid $e.Row
    }
    [void]$view.Children.Add($grid)
    $script:DlEmpty = New-AkariEmpty 'search' '' ''
    [void]$view.Children.Add($script:DlEmpty)
    $script:DlGrid = $grid
    $script:DlView = $view
    Set-AkariDownloadsFilter $false
    Update-AkariDownloadsSelection
    $view
}

# the cards of the category and search: switching category fades the grid out and rises it back in (12 px, Motion.Slow)
function Set-AkariDownloadsFilter([bool]$Animate) {
    $n = 0
    foreach ($e in $script:DlCards.Values) {
        $hit = ($script:DlFilter -eq 'All' -or (Get-AkariDownloadCategory $e.Tweak) -eq $script:DlFilter) -and
               (-not $script:DlQuery -or "$($e.Tweak.Name)" -like "*$($script:DlQuery)*")
        $e.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
        if ($hit) { $n++ }
    }
    Update-AkariCardGrid $script:DlGrid
    $script:DlEmpty.Visibility = if ($n) { 'Collapsed' } else { 'Visible' }
    if (-not $n) { $script:DlEmpty.Tag.Text = "No apps match `"$($script:DlQuery)`"" }
    if ($Animate) { Start-AkariMotion $script:DlGrid Fade 0 1 -Speed Slow; Start-AkariMotion $script:DlGrid Rise 12 0 -Speed Slow }
}

function Show-AkariDownloads {
    # the banner; External apps' Update all apps (winutil W4) on its right (ADR 0011, the native DownloadsPage)
    $up = $null
    if ($script:DlSection -ne 'Windows') {
        $up = New-AkariAppsButton 'Update all apps' 'Update every app winget knows a newer version of' { Start-AkariUpdateApps } 'arrow-clockwise'
        $up.Margin = [Windows.Thickness]::new(0)
    }
    Set-AkariHeader @('Downloads') 'Remove Windows'' own apps, or download and install the apps you use.' $up
    $sec = New-AkariSelectorBar @($AkariDownloadSections.Values) $AkariDownloadSections[$script:DlSection] {
        param($v)
        $script:DlSection = @($AkariDownloadSections.Keys | Where-Object { $AkariDownloadSections[$_] -eq $v })[0]
        Show-Page
    }
    $sec.Bar.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $script:DlSections = $sec
    [void]$StepBody.Children.Add($sec.Bar)
    if ($script:DlSection -eq 'Windows') {
        [void]$StepBody.Children.Add((Get-AkariWindowsView))
        Update-AkariWindowsStatus
        return
    }
    $n = @(Get-AkariInstallList $script:Tweaks | Where-Object { -not $_.Tweak.Group }).Count
    # the section's lead (Update all apps is in the banner)
    $dp = [Windows.Controls.DockPanel]::new(); $dp.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $lead = New-AkariText "Apps, game launchers, runtimes and tools, installed from winget where possible. $n in the catalogue." 14 'Mu'
    [void]$dp.Children.Add($lead)
    [void]$StepBody.Children.Add($dp)
    [void]$StepBody.Children.Add((Get-AkariDownloadsView))
    # which apps are on this PC: read once a session, in a job that leaves the page usable
    if ($script:DlView -and -not $script:ShowInstalled) { Start-AkariInstalledRead }
}

# Install on a card: queued, then installed one at a time (a Run of that one item, no restore point); while another
# job runs it waits ("Waiting...") and starts when that one ends
function Add-AkariInstall([string]$Id) {
    if ($Id -in $script:InstallQueue) { return }
    $script:InstallQueue.Add($Id)
    $e = $script:DlCards[$Id]
    if ($e) { Set-AkariAppCardState $e 'Waiting' }
    Start-AkariInstallNext
}

function Start-AkariInstallNext {
    if ($script:Busy -or -not $script:InstallQueue.Count -or $script:Installing) { return }
    $id = $script:InstallQueue[0]
    $t = Find-AkariTweak $id
    $e = $script:DlCards[$id]
    if (-not $t) { $script:InstallQueue.RemoveAt(0); Start-AkariInstallNext; return }
    if ($e) { Set-AkariAppCardState $e 'Installing' }
    $script:Installing = $id
    Start-AkariApply @(@{ Id = $id; Mode = 'Apply' }) "Installing $($t.Name)" -Kind 'Install'
}

# an install ended: its card says how (a toast too), the next one starts; a Windows app put back: the lists are read
# again
function Complete-AkariInstall($Shared) {
    $id = $script:Installing
    $script:Installing = $null
    if ($id -and $script:InstallQueue.Count -and $script:InstallQueue[0] -eq $id) { $script:InstallQueue.RemoveAt(0) }
    $o = @($Shared.Outcomes | Where-Object { $_.Id -eq $id })[0]
    $e = $script:DlCards[$id]
    $t = Find-AkariTweak $id
    $restore = $t -and ($t.Group -eq 'store' -or $t.RemoveWith)
    if ($o -and $o.Outcome -in 'Applied', 'Already') {
        if ($e) { $e.Popped = $true; Set-AkariAppCardState $e 'Installed'; $e.Popped = $false }
        $script:InstalledIds = @($script:InstalledIds) + $id
        Add-AkariActivity "Installed $($t.Name)" 'Downloads' 1 'download'
        Show-AkariToast "$($t.Name) is installed" $(if ($o.Reboot) { 'Restart Windows to finish.' } else { '' })
        if ($restore) {
            Clear-AkariAppsView
            if ($script:Cat -eq 'Downloads') { Show-Page }
        }
    } else {
        $why = if ($o -and $o.Message) { $o.Message } else { 'The install did not run. The details are in akari.log.' }
        if ($e) { Set-AkariAppCardState $e 'Failed' $why }
        if ($script:Win) {
            foreach ($w in @($script:Win.Rows.Values | Where-Object { $_.Restoring -and $_.Restore -and $_.Restore.Id -eq $id })) { $w.Restoring = $false; Set-AkariWindowsCardAction $w }
        }
        Show-AkariToast "$($t.Name) was not installed" $why
    }
}
