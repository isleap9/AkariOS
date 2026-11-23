# Apps: the apps pages (plan docs/plans/2026-11-19-winui-3.md, the prototype's Guided Apps step, Downloads and
# Remove apps). Remove: FR33THY Ultimate's "bloatware" in four lists under a SelectorBar, every item checkable: Store
# apps (every removable package on this PC, Win11Debloat's names and risk levels), Optional features, Windows features
# (both read in the background) and legacy apps (OneDrive, Remote Desktop...). The AkariOS pick is exactly what FR33THY
# removes: everything but its keep-list. Install: the app installs (Tweaks\Apps\Install), from winget where possible,
# as cards (Guided: tickable; Downloads: an Install button each). Needs UI\Selection.ps1, UI\Cards.ps1, Core\Appx.ps1.

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
function New-AkariAppIcon($Tweak, [double]$Size = 28) {
    $file = Get-AkariAppIconFile $Tweak $script:AppLogos (Join-Path $Root 'Assets\Apps')
    $icon = $null
    if ($file) {
        try {
            $bi = Get-AkariBitmap $file ([int]($Size * 2))
            $mono = $file -like '*.mono.png'
            if (-not $mono -and $Tweak.Package -and $script:AppLogos[$Tweak.Package] -eq $file) { $mono = Test-AkariWhiteLogo $bi }
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

# a grid of cards that fills its width: min 220 px a column, 8 px apart (the prototype's .grid)
function New-AkariCardGrid {
    $g = [Windows.Controls.Primitives.UniformGrid]::new()
    $g.Columns = 3
    $g.Margin = [Windows.Thickness]::new(-4)
    $g.Add_SizeChanged({ param($s, $a) $n = [Math]::Max(1, [Math]::Floor(($a.NewSize.Width + 8) / 228)); if ($s.Columns -ne $n) { $s.Columns = $n } })
    $g
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
    $p = $script:AppsParts
    if ($p -and $p.RemoveGo) { $p.RemoveGo.IsEnabled = ($rm -gt 0 -and -not $script:Busy); $p.RemoveGoText.Text = 'Remove' + $(if ($rm) { " ($rm)" } else { '' }) }
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

# ---- the Optional features and Windows features lists take seconds to read: a background runspace reads them,
# a timer adds their rows when it is done

function Start-AkariFeatureRead {
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

# the background read is done: fill the two feature lists (and apply the last quick select to them)
function Complete-AkariFeatureRead([string[]]$Capabilities, [string[]]$Features, [bool]$Failed = $false) {
    $p = $script:AppsParts
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

# kept for the callers of the old tabs: the removal lists show in Guided and on Remove apps
function Show-AkariAppsTab([string]$Tab) { $script:AppTab = $Tab }

# the apps view for Guided ('': Remove, then Install as tickable cards, Quick select) or Remove apps ('Remove': the
# lists alone, with the accent Remove (n))
function Set-AkariAppsOnly([string]$Tab) {
    $p = $script:AppsParts
    $guided = -not $Tab
    foreach ($x in $p.InstallHead, $p.InstallTables, $p.RemoveHead, $p.SeeAll) { if ($x) { $x.Visibility = if ($guided) { 'Visible' } else { 'Collapsed' } } }
    if ($p.QuickSelect) { $p.QuickSelect.Visibility = if ($guided) { 'Visible' } else { 'Collapsed' } }
    $p.RemoveGo.Visibility = if ($guided) { 'Collapsed' } else { 'Visible' }
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
    if (($script:Cat -eq 'Install AkariOS' -and $script:Mode -eq 'Guided' -and $script:Step -eq 0) -or $script:Cat -in 'Remove apps', 'Downloads') { Show-Page }
}

# forgets the apps read and the views built on it (a Run changed what is on this PC): both again next time
function Clear-AkariAppsView {
    $script:AppRows = [ordered]@{}
    $script:AppsView = $null
    $script:DlView = $null; $script:DlCards = [ordered]@{}
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

# builds the apps view once (Guided's Apps step, Remove apps): the Remove lists under a SelectorBar and a command bar,
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
    # the command bar (.cmdbar): Quick select (Guided), Select recommended, AkariOS, Clear, Only installed, then the
    # count and the accent Remove (n) (Remove apps)
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $right = [Windows.Controls.StackPanel]::new(); $right.Orientation = 'Horizontal'
    $script:AppsStatus = New-AkariText '0 selected' 12 'Mu'
    $script:AppsStatus.VerticalAlignment = 'Center'; $script:AppsStatus.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [void]$right.Children.Add($script:AppsStatus)
    $p.RemoveGo = [Windows.Controls.Button]::new()
    $p.RemoveGo.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
    $i = New-AkariIcon 'trash-2' 16 'AccT'; $i.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.RemoveGoText = [Windows.Controls.TextBlock]::new(); $p.RemoveGoText.Text = 'Remove'
    [void]$c.Children.Add($i); [void]$c.Children.Add($p.RemoveGoText)
    $p.RemoveGo.Content = $c
    $p.RemoveGo.IsEnabled = $false
    $p.RemoveGo.Add_Click({ Start-AkariRemoveApps })
    [void]$right.Children.Add($p.RemoveGo)
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
    $p.SeeAll.Content = 'Remove apps lists the same apps and features, and removes them right away'
    $p.SeeAll.Margin = [Windows.Thickness]::new(1, 8, 0, 0)
    $p.SeeAll.HorizontalAlignment = 'Left'
    $p.SeeAll.Add_Click({ Select-AkariPage 'Remove apps' })
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
            [void]$p.InstallTables.Children.Add($e.Row)
        }
    }
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

# ---- Remove apps (its own page): the lists alone, Remove (n) asks, then removes them one by one: each row collapses
# and slides out as the job gets to it (Update-AkariRemoveProgress), with the progress toast

function Show-AkariRemoveApps {
    Set-AkariHeader @('Remove apps')
    [void]$StepBody.Children.Add((New-AkariLead 'Store apps, optional features, Windows features and legacy apps. Safe ones are picked by "Select recommended"; Caution and Advanced ones say why.'))
    [void]$StepBody.Children.Add((Get-AkariAppsView))
    if ($script:AppsView) { Set-AkariAppsOnly 'Remove'; Update-AkariAppsStatus }
}

function Start-AkariRemoveApps {
    $rows = @($script:AppRows.Values | Where-Object { (Test-AkariRemoveRow $_) -and $_.Control.IsChecked })
    $n = $rows.Count
    if (-not $n -or $script:Busy) { return }
    $names = @($rows | Select-Object -First 6 | ForEach-Object { $_.Tweak.Name }) -join ', '
    if ($n -gt 6) { $names += " and $($n - 6) more" }
    if (-not (Confirm-AkariDialog "$names.`nStore apps can be reinstalled from the Microsoft Store or Downloads." 'Remove' 'Cancel' 'Warning' "Remove $n app$(if ($n -ne 1) { 's' })?")) { return }
    $script:RemovingRows = $rows
    $script:RemovedCount = 0
    Start-AkariApply @(Get-AkariPlanItems $script:Sel) "Removing $n app$(if ($n -ne 1) { 's' })" -Restore 'Remove apps' -Kind 'Remove'
}

# the job got to item $Done: the rows before it collapse (height, padding and opacity to 0, 24 px to the right)
function Update-AkariRemoveProgress($Shared) {
    if (-not $script:RemovingRows -or -not $Shared -or -not $Shared.Total) { return }
    while ($script:RemovedCount -lt [int]$Shared.Done -and $script:RemovedCount -lt $script:RemovingRows.Count) {
        $r = $script:RemovingRows[$script:RemovedCount].Row
        Start-AkariMotion $r Slide 0 24 -Speed Slow
        Set-AkariSize $r Height 0 Slow -Fade
        $r.Margin = [Windows.Thickness]::new(0)
        $script:RemovedCount++
    }
}

# ---- Downloads (its own page): a SelectorBar of categories and a search box in a command bar, a grid of app cards whose
# Install acts right away (queued one at a time: Add-AkariInstall), no restore point (winutil W4)
$script:DlView = $null; $script:DlCards = [ordered]@{}; $script:DlFilter = 'All'; $script:DlQuery = ''; $script:InstallQueue = [Collections.Generic.List[string]]::new()

function Get-AkariDownloadsView {
    if ($script:DlView) { return $script:DlView }
    if (-not $script:Appx) {
        Start-AkariAppxRead
        if (-not $script:Appx) { return New-AkariReading ('Reading the apps on this PC' + [char]0x2026) }
    }
    $script:AppLogos = if ($script:Appx.Logos) { $script:Appx.Logos } else { @{} }
    $view = [Windows.Controls.StackPanel]::new()
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $right = [Windows.Controls.StackPanel]::new(); $right.Orientation = 'Horizontal'; $right.VerticalAlignment = 'Top'
    $fb = New-AkariFilterBox 'Search apps' 220 { param($q) $script:DlQuery = $q; Set-AkariDownloadsFilter $false }
    [void]$right.Children.Add($fb.Box)
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$bar.Children.Add($right)
    $cats = @('All') + @($AkariDownloadCategories.Keys)
    $sel = New-AkariSelectorBar $cats $script:DlFilter { param($v) $script:DlFilter = $v; Set-AkariDownloadsFilter $true }
    $sel.Bar.Margin = [Windows.Thickness]::new(0)
    [void]$bar.Children.Add($sel.Bar)
    [void]$view.Children.Add($bar)
    $grid = New-AkariCardGrid
    $script:DlCards = [ordered]@{}
    # by category, in the SelectorBar's order (Gaming first), then the Store apps to restore
    $order = @($AkariDownloadCategories.Keys) + $AkariDownloadRestore
    $items = @(Get-AkariInstallCards $script:Tweaks @($script:Appx.Names) | ForEach-Object { $_.Items }) | Sort-Object { [array]::IndexOf($order, (Get-AkariDownloadCategory $_.Tweak)) }, { $_.Tweak.Name }
    foreach ($c in @(@{ Items = $items })) {
        foreach ($item in $c.Items) {
            $e = New-AkariAppCard $item 'Action'
            Set-AkariAppCardState $e $(if ($script:InstalledIds -and $item.Tweak.Id -in $script:InstalledIds) { 'Installed' } elseif ($item.Tweak.Id -in $script:InstallQueue) { 'Waiting' } else { '' })
            $script:DlCards[$item.Tweak.Id] = $e
            [void]$grid.Children.Add($e.Row)
        }
    }
    [void]$view.Children.Add($grid)
    $script:DlEmpty = New-AkariEmpty 'search' '' ''
    [void]$view.Children.Add($script:DlEmpty)
    $script:DlGrid = $grid
    $script:DlView = $view
    Set-AkariDownloadsFilter $false
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
    $script:DlEmpty.Visibility = if ($n) { 'Collapsed' } else { 'Visible' }
    if (-not $n) { $script:DlEmpty.Tag.Text = "No apps match `"$($script:DlQuery)`"" }
    if ($Animate) { Start-AkariMotion $script:DlGrid Fade 0 1 -Speed Slow; Start-AkariMotion $script:DlGrid Rise 12 0 -Speed Slow }
}

function Show-AkariDownloads {
    Set-AkariHeader @('Downloads')
    $n = @(Get-AkariInstallList $script:Tweaks).Count
    # the lead, and Update all apps (winutil W4) on its right
    $dp = [Windows.Controls.DockPanel]::new(); $dp.Margin = [Windows.Thickness]::new(0, -12, 0, 20)
    $up = New-AkariAppsButton 'Update all apps' 'Update every app winget knows a newer version of' { Start-AkariUpdateApps } 'arrow-clockwise' -Subtle
    $up.Margin = [Windows.Thickness]::new(16, -6, 0, 0); $up.VerticalAlignment = 'Top'
    [Windows.Controls.DockPanel]::SetDock($up, 'Right'); [void]$dp.Children.Add($up)
    $lead = New-AkariLead "Apps, game launchers, runtimes and tools, installed from winget where possible. $n in the catalogue."
    $lead.Margin = [Windows.Thickness]::new(0)
    [void]$dp.Children.Add($lead)
    [void]$StepBody.Children.Add($dp)
    [void]$StepBody.Children.Add((Get-AkariDownloadsView))
    # which apps are on this PC: read once a session, in a job that leaves the page usable
    if ($script:DlView -and -not $script:ShowInstalled) { Start-AkariInstalledRead }
}

# Install on a card: queued, then installed one at a time (a Run of that one item, no restore point)
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

# an install ended: its card says how, the next one starts
function Complete-AkariInstall($Shared) {
    $id = $script:Installing
    $script:Installing = $null
    if ($id -and $script:InstallQueue.Count -and $script:InstallQueue[0] -eq $id) { $script:InstallQueue.RemoveAt(0) }
    $o = @($Shared.Outcomes | Where-Object { $_.Id -eq $id })[0]
    $e = $script:DlCards[$id]
    $t = Find-AkariTweak $id
    if ($o -and $o.Outcome -in 'Applied', 'Already') {
        if ($e) { $e.Popped = $true; Set-AkariAppCardState $e 'Installed'; $e.Popped = $false }
        $script:InstalledIds = @($script:InstalledIds) + $id
        Add-AkariActivity "Installed $($t.Name)" 'Downloads' 1 'download'
    } elseif ($e) {
        Set-AkariAppCardState $e 'Failed' $(if ($o) { $o.Message } else { 'The install did not run.' })
        Show-AkariToast "$($t.Name) was not installed" $(if ($o -and $o.Message) { $o.Message } else { 'Open the log for details.' })
    }
}
