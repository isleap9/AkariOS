# Pages: Home and the Optimize landing page (plan docs/plans/2026-11-19-winui-3.md decision 6, the prototype
# docs/design/akarios-prototype.html's PAGES.home and PAGES.optimize), the page helpers they and the others share (the
# lead line, the empty state) and Recent activity. Dot-sourced by Akari.ps1 after UI\Steps.ps1, before UI\Shell.ps1;
# functions only (they run once the window is up).

# the line under a page's title (.lead): Mu, at most 760 px, 20 px above the content
function New-AkariLead([string]$Text) {
    $t = New-AkariText $Text 14 'Mu'
    $t.MaxWidth = 760; $t.HorizontalAlignment = 'Left'
    $t.Margin = [Windows.Thickness]::new(0, -12, 0, 20)
    $t
}

# an empty state (.empty): a 40 px Ter icon, a line in Tx (SemiBold) and one in Mu, centred. Tag = the first line
function New-AkariEmpty([string]$Icon, [string]$Title, [string]$Text) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Margin = [Windows.Thickness]::new(0, 48, 0, 48)
    $sp.HorizontalAlignment = 'Center'
    $i = New-AkariIcon $Icon 40 'Ter'; $i.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    [void]$sp.Children.Add($i)
    $t = New-AkariText $Title 14 'Tx' 'SemiBold'; $t.TextAlignment = 'Center'
    [void]$sp.Children.Add($t)
    $d = New-AkariText $Text 14 'Mu'; $d.TextAlignment = 'Center'
    if (-not $Text) { $d.Visibility = 'Collapsed' }
    [void]$sp.Children.Add($d)
    $sp.Tag = $t
    $sp
}

# ---- Recent activity: the last runs (One-click, Guided, Optimize, Downloads, Remove apps), each with its count of
# changes, kept in activity.json next to akari.log (at most 20)
if (-not $AkariActivityPath) { $AkariActivityPath = Join-Path (Split-Path $AkariLogFile) 'activity.json' }
function Get-AkariActivity {
    try { @((Get-Content $AkariActivityPath -Raw -ErrorAction Stop | ConvertFrom-Json) | Where-Object { $_ }) } catch { @() }
}
function Add-AkariActivity([string]$Title, [string]$Where, [int]$Count, [string]$Icon = 'sliders-horizontal') {
    $list = @([pscustomobject]@{ Title = $Title; Where = $Where; Count = $Count; Icon = $Icon; When = (Get-Date).ToString('o') }) + @(Get-AkariActivity | Select-Object -First 19)
    try { New-Item (Split-Path $AkariActivityPath) -ItemType Directory -Force | Out-Null; ConvertTo-Json @($list) -Depth 3 | Set-Content $AkariActivityPath -Encoding UTF8 }
    catch { Write-ErrLog "Could not save the activity: $_" }
}

# when an activity happened, in words: "Just now", "12 minutes ago", "Today 14:05", "Yesterday", or the date. Pure.
function Get-AkariWhenText([datetime]$When, [datetime]$Now = (Get-Date)) {
    $d = $Now - $When
    if ($d.TotalMinutes -lt 1) { return 'Just now' }
    if ($d.TotalMinutes -lt 60) { $m = [int][Math]::Floor($d.TotalMinutes); return "$m minute$(if ($m -ne 1) { 's' }) ago" }
    if ($When.Date -eq $Now.Date) { return 'Today ' + $When.ToString('HH:mm') }
    if ($When.Date -eq $Now.Date.AddDays(-1)) { return 'Yesterday' }
    $When.ToString('d MMM yyyy', [Globalization.CultureInfo]::InvariantCulture)
}

# ---- Home: the update InfoBar, the hero card (logo, headline, One-click and Choose changes, the facts), Get started
# tiles, Quick settings (four AkariOS Tweaks as Settings cards) and Recent activity
$AkariQuickSettings = 'disable-game-dvr', 'gaming-game-mode', 'performance-background-apps-off', 'privacy-ads'
$script:HomeStat = @{}

# a fact (the native Home's): a glass card with the 36 px icon square, the number (SemiBold) over its label (Caption, Mu);
# $script:HomeStat[$Key] = the number
function New-AkariHomeFact([string]$Icon, [string]$Key, [string]$Label) {
    $c = [Windows.Controls.Border]::new()
    $c.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'GlassCard')
    $c.Padding = [Windows.Thickness]::new(14); $c.Margin = [Windows.Thickness]::new(4)
    $dp = [Windows.Controls.DockPanel]::new()
    $ic = New-AkariBlob $Icon 36; $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
    $tx = [Windows.Controls.StackPanel]::new(); $tx.VerticalAlignment = 'Center'
    $n = New-AkariText ([string][char]0x2014) 14 'Tx' 'SemiBold'; $n.TextWrapping = 'NoWrap'
    $l = New-AkariText $Label 12 'Mu'; $l.TextWrapping = 'NoWrap'
    [void]$tx.Children.Add($n); [void]$tx.Children.Add($l)
    [void]$dp.Children.Add($tx)
    $c.Child = $dp
    $script:HomeStat[$Key] = $n
    $c
}
# the facts (Start-AkariHomeStats): Tweaks, apps you can remove, changes applied; one under the other under 600 px
function New-AkariHomeFacts {
    $g = [Windows.Controls.Primitives.UniformGrid]::new()
    $g.Columns = 3; $g.Margin = [Windows.Thickness]::new(-4, 0, -4, 0)
    [void]$g.Children.Add((New-AkariHomeFact 'sliders-horizontal' 'Tweaks' 'Tweaks'))
    [void]$g.Children.Add((New-AkariHomeFact 'trash-2' 'Apps' 'Apps you can remove'))
    [void]$g.Children.Add((New-AkariHomeFact 'check' 'Applied' 'Changes applied'))
    $script:HeroFacts = $g
    $g
}

# the hero (the native Home's banner, ADR 0011): straight on the light, no card: the 112 px logo, the version overline,
# "Windows, tuned for games" at 40 px, the lead, Start One-click (accent) and Choose changes
function New-AkariHero {
    $g = [Windows.Controls.Grid]::new()
    $g.MinHeight = 220; $g.Margin = [Windows.Thickness]::new(4, 8, 0, 16)
    foreach ($w in 'Auto', 'Star') { $cd = [Windows.Controls.ColumnDefinition]::new(); $cd.Width = if ($w -eq 'Auto') { [Windows.GridLength]::Auto } else { [Windows.GridLength]::new(1, 'Star') }; [void]$g.ColumnDefinitions.Add($cd) }
    $logo = New-AkariLogoImage 112
    $logo.Margin = [Windows.Thickness]::new(0, 0, 28, 0); $logo.VerticalAlignment = 'Center'
    [void]$g.Children.Add($logo)
    $tx = [Windows.Controls.StackPanel]::new(); $tx.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($tx, 1)
    $ov = New-AkariText "AkariOS $AkariVersion" 14 'Mu'; $ov.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
    [void]$tx.Children.Add($ov)
    $h = New-AkariText 'Windows, tuned for games' 28
    Set-AkariFont $h Display
    $h.FontSize = 40; $h.LineHeight = 52; $h.FontWeight = 'SemiBold'; $h.TextWrapping = 'Wrap'
    $h.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
    [void]$tx.Children.Add($h)
    $ld = New-AkariText 'Debloat and optimize Windows 10 and 11 in one go, or pick each change yourself. Every Toggle and Choice goes back to Windows'' default.' 14 'Mu'
    $ld.TextWrapping = 'Wrap'; $ld.MaxWidth = 560; $ld.HorizontalAlignment = 'Left'
    [void]$tx.Children.Add($ld)
    $bt = [Windows.Controls.WrapPanel]::new(); $bt.Margin = [Windows.Thickness]::new(0, 20, 0, 0)
    $one = [Windows.Controls.Button]::new()
    $one.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $oc = [Windows.Controls.StackPanel]::new(); $oc.Orientation = 'Horizontal'
    $oi = New-AkariIcon 'zap' 16 'AccT'; $oi.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    [void]$oc.Children.Add($oi); $ot = [Windows.Controls.TextBlock]::new(); $ot.Text = 'Start One-click'; [void]$oc.Children.Add($ot)
    $one.Content = $oc
    $one.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $one.ToolTip = 'The full AkariOS setup in one go, with restarts handled for you'
    $one.Add_Click({ Start-AkariOneClick })
    $choose = [Windows.Controls.Button]::new()
    $choose.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $choose.Content = 'Choose changes'
    $choose.ToolTip = 'Pick the apps and Tweaks yourself, review them, then apply them in one go'
    $choose.Add_Click({ Start-AkariGuided })
    [void]$bt.Children.Add($one); [void]$bt.Children.Add($choose)
    [void]$tx.Children.Add($bt)
    [void]$g.Children.Add($tx)
    $script:HeroOneClick = $one; $script:HeroChoose = $choose
    $g
}

# a tile (.tile: Get started, the Install AkariOS chooser) on the glass (GlassTile, ADR 0011): the 40 px icon square
# (48 with -Big), the title, its text, a footer line (Ter; AccText with -Rec or -Accent); -Rec = the recommended one,
# an Acc stroke too; -Bloom = a featured tile: the Akari bloom in its top right corner in that palette (New-AkariBloom),
# the content over it. A small tile (Home's, as the native app's) has its footer right under its text.
function New-AkariTile([string]$Icon, [string]$Title, [string]$Text, [string]$Foot, [scriptblock]$Click, [switch]$Rec, [switch]$Big, [string]$Bloom = '', [switch]$Accent) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'GlassTile')
    if ($Rec) { $b.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'Acc') }
    if ($Big) { $b.MinHeight = 200; $b.Padding = [Windows.Thickness]::new(20) }
    $dp = [Windows.Controls.DockPanel]::new()
    $f = [Windows.Controls.StackPanel]::new(); $f.Orientation = 'Horizontal'; $f.Margin = [Windows.Thickness]::new(0, $(if ($Big) { 10 } else { 6 }), 0, 0)
    $ft = New-AkariText $Foot 12 $(if ($Rec -or $Accent) { 'AccText' } else { 'Ter' })
    [void]$f.Children.Add($ft)
    if ($Big) { [Windows.Controls.DockPanel]::SetDock($f, 'Bottom'); [void]$dp.Children.Add($f) }
    $sp = [Windows.Controls.StackPanel]::new()
    $ic = New-AkariBlob $Icon $(if ($Big) { 48 } else { 40 })
    $ic.HorizontalAlignment = 'Left'; $ic.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
    [void]$sp.Children.Add($ic)
    $tt = if ($Big) { New-AkariText $Title 20 } else { New-AkariText $Title 14 'Tx' 'SemiBold' }
    $tt.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
    [void]$sp.Children.Add($tt)
    $dt = New-AkariText $Text 14 'Mu'; $dt.TextWrapping = 'Wrap'
    [void]$sp.Children.Add($dt)
    if (-not $Big) { [void]$sp.Children.Add($f) }
    [void]$dp.Children.Add($sp)
    $b.Content = $dp
    if ($Bloom) {
        # the bloom takes no room: the tile's padding moves onto its content, the bloom clipped to the tile's inside
        # GlassTile's own padding (16) is not on the button until its style applies; -Big set 20
        $p = if ($Big) { 20 } else { 16 }
        $pad = [Windows.Thickness]::new($p)
        $b.Padding = [Windows.Thickness]::new(1)
        $bg = [Windows.Controls.Grid]::new(); $bg.ClipToBounds = $true
        [void]$bg.Children.Add((New-AkariBloom $Bloom 360 180 7))
        $dp.Margin = $pad; $b.Content = $null; [void]$bg.Children.Add($dp)
        $b.Content = $bg
    }
    $b.Margin = [Windows.Thickness]::new(4)
    $b.Add_Click($Click)
    $b
}

# Choose changes / the Guided tile: Install AkariOS on Guided's first step
function Start-AkariGuided {
    if ($script:Cat -ne 'Install AkariOS') { Push-AkariHistory }
    $script:Cat = 'Install AkariOS'; $script:Query = ''
    if ($script:Mode -ne 'Guided' -or $script:Step -ge 3) { Clear-AkariSteps }
    $script:Mode = 'Guided'; $script:Step = 0
    Show-Page
}

$script:HomeView = $null
function Show-AkariHome {
    $HomePanel.Children.Clear()
    $p = @{}
    # the update InfoBar (About.ps1's check), dismissible
    $s = $script:UpdateStatus
    if ($s -and $s.Kind -in 'Available', 'Blocked' -and -not $script:UpdateDismissed) {
        $up = @()
        if ($s.Kind -eq 'Available') { $up += New-AkariBarButton 'Update' { Start-AkariUpdateInstall } }
        $up += New-AkariBarButton "What's new" { Select-AkariPage 'Settings' }
        $ib = New-AkariInfoBar 'Info' "AkariOS $($s.Release.Version) is available" $(if ($s.Kind -eq 'Blocked') { $s.Message } else { '' }) $up -Close
        $ib.Close.Add_Click({ $script:UpdateDismissed = $true })
        [void]$HomePanel.Children.Add($ib.Bar)
    }
    # the drift check's InfoBar (About.ps1): AkariOS settings Windows changed back, dismissible
    if ($script:Drift -and @($script:Drift).Count -and -not $script:DriftDismissed) {
        $n = @($script:Drift).Count
        $db = New-AkariInfoBar 'Warn' "$n AkariOS setting$(if ($n -ne 1) { 's' }) went back to Windows' values" 'Windows changed them back, most likely with an update. Review them and apply them again.' @(
            (New-AkariBarButton 'Review' { Open-AkariDriftReview })) -Close
        $db.Close.Add_Click({ $script:DriftDismissed = $true })
        [void]$HomePanel.Children.Add($db.Bar)
    }
    [void]$HomePanel.Children.Add((New-AkariHero))
    [void]$HomePanel.Children.Add((New-AkariHomeFacts))
    $since = @()
    # X6: the numbers before the last Run and after its restart (Core\Metrics.ps1)
    $mr = Get-AkariMetricsShown $script:MetricsRecords
    if ($mr) {
        $since += New-AkariSection 'Since AkariOS' 
        $st = [Windows.Controls.StackPanel]::new()
        foreach ($row in @(Get-AkariMetricsDiff $mr.Metrics['Before'] $mr.Metrics['After'])) {
            $c = New-AkariSettingsCard 'gauge' $row.Name '' (New-AkariText $row.Text 14 'Tx' 'SemiBold') 'Plain'
            [void]$st.Children.Add($c.Card)
        }
        $note = New-AkariText "Before `"$($mr.Name)`" and after its restart. These numbers change from one boot to the next: read them as a rough guide." 12 'Mu'
        $note.TextWrapping = 'Wrap'; $note.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
        [void]$st.Children.Add($note)
        $since += $st
    }
    [void]$HomePanel.Children.Add((New-AkariSection 'Get started'))
    $tiles = [Windows.Controls.Primitives.UniformGrid]::new()
    $tiles.Columns = 3
    $tiles.Margin = [Windows.Thickness]::new(-4)
    [void]$tiles.Children.Add((New-AkariTile 'zap' 'One-click' 'The full AkariOS setup: apps, drivers, Safe Mode and tweaks, with restarts handled for you.' 'Recommended for a fresh install' { Start-AkariOneClick } -Accent))
    [void]$tiles.Children.Add((New-AkariTile 'wand' 'Guided' 'Pick the apps to remove and the Tweaks to apply, review, then apply in one go.' 'For a PC you already use' { Start-AkariGuided }))
    [void]$tiles.Children.Add((New-AkariTile 'sliders-horizontal' 'Optimize' 'Every Tweak by category. Each change applies the moment you flip it.' 'For power users' { Select-AkariPage 'Optimize' }))
    $script:HomeTiles = $tiles
    [void]$HomePanel.Children.Add($tiles)
    foreach ($x in $since) { [void]$HomePanel.Children.Add($x) }
    # Quick settings: four AkariOS Tweaks as the Catalogue's own cards (they act right away)
    $quick = @($AkariQuickSettings | ForEach-Object { Find-AkariTweak $_ } | Where-Object { $_ -and @(Get-AkariCatalogueTweaks @($_)).Count })
    if ($quick.Count) {
        [void]$HomePanel.Children.Add((New-AkariSection 'Quick settings'))
        $st = [Windows.Controls.StackPanel]::new()
        foreach ($t in $quick) { $e = Get-AkariCatalogueCard $t; Set-AkariCardHighlight $e ''; if ($e.Card.Parent) { $e.Card.Parent.Children.Remove($e.Card) }; [void]$st.Children.Add($e.Card); Set-AkariCatalogueCard $e }
        [void]$HomePanel.Children.Add($st)
        if ($script:PageMoved) { Start-AkariCatalogueStates @($quick | Where-Object { -not (Get-AkariCatalogueCard $_).Busy }) }
    }
    # Recent activity
    [void]$HomePanel.Children.Add((New-AkariSection 'Recent activity'))
    $act = @(Get-AkariActivity | Select-Object -First 5)
    $st = [Windows.Controls.StackPanel]::new()
    if ($act.Count) {
        foreach ($a in $act) {
            $when = try { Get-AkariWhenText ([datetime]$a.When) } catch { '' }
            $ok = [Windows.Controls.StackPanel]::new(); $ok.Orientation = 'Horizontal'
            $oi = New-AkariIcon 'circle-check.Filled' 16 'Ok'; $oi.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
            [void]$ok.Children.Add($oi)
            $n = [int]$a.Count
            [void]$ok.Children.Add((New-AkariText "$n change$(if ($n -ne 1) { 's' })" 12 'Ok'))
            $c = New-AkariSettingsCard ([string]$a.Icon) ([string]$a.Title) "$when $([char]0x00B7) $($a.Where)" $ok
            [void]$st.Children.Add($c.Card)
        }
    } else {
        $c = New-AkariSettingsCard 'history' 'Nothing applied yet' 'Runs from One-click, Guided and Optimize show up here.'
        [void]$st.Children.Add($c.Card)
    }
    [void]$HomePanel.Children.Add($st)
    Start-AkariHomeStats
    Update-AkariHomeWidth $Layer.ActualWidth
}

# a narrow content layer ($Width): the tiles one under the other, then the facts gone (they are on Optimize too)
function Update-AkariHomeWidth([double]$Width) {
    if ($Width -le 0) { return }
    if ($script:HomeTiles) { $script:HomeTiles.Columns = if ($Width -lt 600) { 1 } else { 3 } }
    # Install AkariOS' chooser tiles: one under the other under 600 px too (ADR 0011's narrow rule)
    if ($script:ChooserTiles) { $script:ChooserTiles.Columns = if ($Width -lt 600) { 1 } else { 2 } }
    if ($script:HeroFacts) { $script:HeroFacts.Columns = if ($Width -lt 600) { 1 } else { 3 } }
}

# $Stats: @{ Tweaks; Apps; Applied }, each a count or $null (a dash: not read)
function Set-AkariHomeStats($Stats) {
    foreach ($k in @($Stats.Keys)) {
        if (-not $script:HomeStat[$k]) { continue }
        if ($null -eq $Stats[$k]) { $script:HomeStat[$k].Text = [string][char]0x2014 } else { Start-AkariCount $script:HomeStat[$k] ([int]$Stats[$k]) }
    }
}

# the stats, read once and again after a change: Tweaks = the Catalogue's; apps you can remove = the Store apps on the
# PC outside the keep-list; changes applied = what Export would save (Get-AkariExportItems), read in a quiet runspace
$script:StatsJob = $null; $script:StatsFresh = $false; $script:StatsLast = @{}
function Start-AkariHomeStats {
    $cat = @((Get-AkariCatalogueOf $script:Tweaks).Tweaks)
    Set-AkariHomeStats @{ Tweaks = $cat.Count; Apps = $script:StatsLast.Apps; Applied = $script:StatsLast.Applied }
    if ($script:StatsJob -or $script:StatsFresh) { return }
    $script:StatsFresh = $true
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    # the files the job needs, not the whole loader again (a script block must not cross runspaces)
    $shared = [hashtable]::Synchronized(@{
        Groups  = @($script:Groups | ForEach-Object { $_.Source } | Select-Object -Unique)
        Sources = @($cat | Where-Object { $_.Kind -in 'Toggle', 'Choice' -and $_.Section -ne 'Tools' } | ForEach-Object { $_.Source })
    })
    # its log stays quiet, and it runs below normal priority: a minute of reads that must not slow the window
    $code = @"
[Threading.Thread]::CurrentThread.Priority = 'BelowNormal'
`$root = $(& $q "$Root\Tweaks")
`$groups = @(foreach (`$s in `$AkariShared.Groups) { try { Import-AkariTweakFile -Path `$s -TweaksRoot `$root } catch { } })
try { `$AkariShared.Apps = @(Get-AkariAppxInstalled | Where-Object { `$e = Resolve-AkariEntry `$groups "appx/`$_"; `$e -and -not `$e.Keep }).Count } catch { }
`$tweaks = @(foreach (`$s in `$AkariShared.Sources) { try { Import-AkariTweakFile -Path `$s -TweaksRoot `$root } catch { } })
try { `$AkariShared.Applied = @(Get-AkariExportItems `$tweaks).Count } catch { }
"@
    $job = Start-AkariJob $code ([System.Collections.Concurrent.ConcurrentQueue[string]]::new()) "$Root\Core" $shared
    $script:StatsJob = $job
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(300)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        Complete-AkariHomeStats $j.Shared
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Write-ErrLog "Home stats: $_" }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        $script:StatsJob = $null
        Complete-AkariHomeStats $j.Shared
    })
    $tm.Start()
}
function Complete-AkariHomeStats($Shared) {
    foreach ($k in 'Apps', 'Applied') { if ($null -ne $Shared.$k -and $script:StatsLast.$k -ne $Shared.$k) { $script:StatsLast[$k] = $Shared.$k; Set-AkariHomeStats @{ $k = $Shared.$k } } }
}

# ---- Optimize: its five sections as cards (their categories and Tweak counts), then a few Tools, then the Legacy pages
$AkariOptimizeTools = @('oneclick-restore-point', 'cleanup-temp-files', 'tools-driver-nvidia', 'tools-driver-amd', 'tools-driver-intel')
function Show-AkariOptimize {
    Set-AkariHeader @('Optimize') 'Every Tweak, by section. Each change applies the moment you flip it, and you can switch it back the same way.'
    $cat = Get-AkariCatalogueOf $script:Tweaks
    $grid = [Windows.Controls.Primitives.UniformGrid]::new()
    $grid.Columns = 2
    $grid.Margin = [Windows.Thickness]::new(-2)
    foreach ($s in $cat.Pages) {
        $cats = @($s.Pages | ForEach-Object { $_.Category })
        $n = @($cat.Tweaks | Where-Object { $_.Section -eq $s.Section }).Count
        $count = New-AkariText "$n" 12 'Ter'; $count.VerticalAlignment = 'Center'; $count.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
        $chev = New-AkariIcon 'chevron-right' 12 'Mu'
        $icon = if ($AkariSectionIcons.Contains($s.Section)) { $AkariSectionIcons[$s.Section] } else { 'settings' }
        $c = New-AkariSettingsCard $icon $s.Header ((@($cats | Select-Object -First 4) -join ', ') + $(if ($cats.Count -gt 4) { [char]0x2026 } else { '' })) @($count, $chev) 'GlassRow'
        $c.Card.Tag = "$AkariCataloguePrefix$($s.Section)"
        $c.Card.Margin = [Windows.Thickness]::new(2)
        $c.Card.Add_Click({ param($x, $e) Select-AkariPage ([string]$x.Tag) })
        [void]$grid.Children.Add($c.Card)
    }
    [void]$StepBody.Children.Add($grid)
    # Tools: a restore point, the temp files, this PC's graphics driver (the Catalogue's own cards)
    $tools = @($AkariOptimizeTools | ForEach-Object { Find-AkariTweak $_ } | Where-Object { $_ -and @(Get-AkariCatalogueTweaks @($_)).Count } | Select-Object -First 3)
    if ($tools.Count) {
        [void]$StepBody.Children.Add((New-AkariSection 'Tools'))
        $st = [Windows.Controls.StackPanel]::new()
        foreach ($t in $tools) { $e = Get-AkariCatalogueCard $t; Set-AkariCardHighlight $e ''; if ($e.Card.Parent) { $e.Card.Parent.Children.Remove($e.Card) }; [void]$st.Children.Add($e.Card); Set-AkariCatalogueCard $e }
        [void]$StepBody.Children.Add($st)
    }
    # Legacy: the old AkariOS-Ultimate pages (ADR 0004), being retired as the sections take them over
    $legacy = @($AkariLegacyPages | Where-Object { $_ -ne 'Downloads' -and @(Get-AkariLegacyList $script:Tweaks $_ '').Count })
    if ($legacy.Count) {
        [void]$StepBody.Children.Add((New-AkariSection 'Legacy'))
        $ex = New-AkariExpander 'history' 'Legacy scripts' 'The old AkariOS-Ultimate pages, being retired as the sections above take them over'
        foreach ($p in $legacy) {
            $b = [Windows.Controls.Button]::new()
            $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Link')
            $b.Content = $p; $b.Tag = $p; $b.HorizontalAlignment = 'Left'
            $b.Add_Click({ param($x, $e) Select-AkariPage ([string]$x.Tag) })
            $n = New-AkariText "$(@(Get-AkariLegacyList $script:Tweaks $p '').Count) scripts" 12 'Ter'
            [void]$ex.Body.Children.Add((New-AkariExpanderRow $b $n))
        }
        [void]$StepBody.Children.Add($ex.Card)
    }
}
