# Apps: the Guided Apps step, after Win11Debloat's App Removal page, with two tabs over one table look.
# Remove: FR33THY Ultimate's "bloatware" in four sections, every item checkable: Store apps (every removable package
# on this PC, Win11Debloat's names and recommendation dots), Optional features, Windows features (both read in the
# background) and legacy apps (OneDrive, Remote Desktop...). The AkariOS pick is exactly what FR33THY
# removes: everything but its keep-list. Install: the app installs (Tweaks\Apps\Install), from winget where possible.
# Rows write into the Selection; nothing runs until Review & Apply. Needs UI\Selection.ps1 and Core\Appx.ps1.

$script:AppRows = [ordered]@{}
$script:AppsView = $null
$script:OnlyInstalled = $true
$script:AppTab = 'Remove'
# the last quick select, applied again to the feature rows that arrive after it
$script:AppsPick = $null
# dot per Risk: Safe = recommended to remove, Caution = optional, Advanced = not recommended
$AkariAppDots = @{
    Safe     = @{ Char = [char]0x25CF; Brush = 'Ok'; Label = 'Recommended' }
    Caution  = @{ Char = [char]0x25C6; Brush = 'Warn'; Label = 'Optional' }
    Advanced = @{ Char = [char]0x25B2; Brush = 'Bad'; Label = 'Not recommended' }
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

# the Install tab's cards, in this order (an app with another AppType goes under Other, before the restore card)
$AkariAppTypes = 'Browsers', 'Communication', 'Game launchers', 'Gaming & hardware', 'Media', 'Utilities', 'Runtimes', 'Dev tools'
$AkariRestoreType = 'Restore removed apps'

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

# the table's columns: checkbox | dot | name | description | App ID or source
function New-AkariAppGrid {
    $g = [Windows.Controls.Grid]::new()
    foreach ($w in 32, 22, 240, 0, 260) {
        $c = [Windows.Controls.ColumnDefinition]::new()
        $c.Width = if ($w) { [Windows.GridLength]::new($w) } else { [Windows.GridLength]::new(1, 'Star') }
        [void]$g.ColumnDefinitions.Add($c)
    }
    $g
}

# one table row: @{ Tweak; Installed; Row; Control; Muted }. A removal has a recommendation dot; an install does not.
function New-AkariAppRow($Item) {
    $t = $Item.Tweak
    $e = @{ Tweak = $t; Installed = $Item.Installed; Muted = $false }
    $g = New-AkariAppGrid
    $g.Margin = [Windows.Thickness]::new(0, 3, 0, 3)
    $g.Tag = $t.Id
    $cb = [Windows.Controls.CheckBox]::new()
    $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $cb.Tag = $t.Id
    $cb.VerticalAlignment = 'Center'
    [void]$g.Children.Add($cb)
    if ($t.Category -eq 'Remove') {
        $d = $AkariAppDots[$t.Risk]
        $dot = New-AkariAppCell ([string]$d.Char) 1 $d.Brush 11
        $dot.ToolTip = $d.Label
        [void]$g.Children.Add($dot)
    }
    $name = New-AkariAppCell $t.Name 2
    if ($t.Keep) { $name.ToolTip = 'Kept by the AkariOS pick (FR33THY''s keep-list)' }
    if (-not $Item.Installed) { $name.Opacity = 0.6 }
    [void]$g.Children.Add($name)
    $desc = New-AkariAppCell $(if ($t.Description) { $t.Description } else { 'Not in Akari''s list: found on this PC' }) 3 'Mu'
    $desc.ToolTip = $desc.Text
    [void]$g.Children.Add($desc)
    $src = Get-AkariAppSource $t
    $pkg = New-AkariAppCell $src 4 'Ter' 12
    $pkg.ToolTip = if ($Item.Installed) { $src } else { "$src (not on this PC)" }
    [void]$g.Children.Add($pkg)
    $cb.Add_Click({ param($s, $a) Step-AkariAppCheck ([string]$s.Tag) })
    $e.Row = $g; $e.Control = $cb
    $e
}

# a row was checked or unchecked: checked = Remove or Install (an Advanced item asks first), unchecked = no change
function Step-AkariAppCheck([string]$Id) {
    $e = $script:AppRows[$Id]
    if ($e.Muted) { return }
    $next = if ($e.Control.IsChecked) { 'Optimized' } else { 'None' }
    $q = Get-AkariConfirmText $e.Tweak $next
    if ($q -and [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -ne 'Yes') { Set-AkariAppChecked $e $false; return }
    Set-AkariPending $script:Sel $e.Tweak 'Unknown' $next
    Update-AkariAppsStatus
}

function Set-AkariAppChecked($e, [bool]$On) {
    $e.Muted = $true
    try { $e.Control.IsChecked = $On } finally { $e.Muted = $false }
    Set-AkariPending $script:Sel $e.Tweak 'Unknown' $(if ($On) { 'Optimized' } else { 'None' })
}

# quick select on the Remove tab: checks the removals on this PC that $Pick says yes to and unchecks every other one,
# in all four sections (no confirmation: the user picked a set, and Review lists every item before anything runs).
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

function Update-AkariAppsStatus {
    if (-not $script:AppsStatus) { return }
    $on = @($script:AppRows.Values | Where-Object { $_.Control.IsChecked })
    $rm = @($on | Where-Object { Test-AkariRemoveRow $_ }).Count
    $in = $on.Count - $rm
    $script:AppsStatus.Text = "$rm to remove, $in to install"
    # Downloads shows the count on its Next button ("Review (n)")
    if ($StepNext) { Update-AkariStepFooter }
}

# header search and "Only installed": hide the rows that don't match
function Set-AkariAppsFilter([string]$q) {
    foreach ($e in $script:AppRows.Values) {
        $hit = (-not $q) -or ("$($e.Tweak.Name) $($e.Tweak.Description) $(Get-AkariAppSource $e.Tweak)" -like "*$q*")
        if ($script:OnlyInstalled -and -not $e.Installed) { $hit = $false }
        $e.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
    }
}

function New-AkariAppsButton([string]$Text, [string]$Tip, [scriptblock]$Click) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $b.Content = $Text
    $b.ToolTip = $Tip
    $b.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    if ($Click) { $b.Add_Click($Click) }
    $b
}

# a table card: title, column headers, rows (registered in $script:AppRows). Returns @{ Card; Rows (panel); Title }
function New-AkariAppTable([string]$Title, [string]$Last, $Items) {
    $table = [Windows.Controls.Border]::new()
    $table.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CategoryCard')
    $sp = [Windows.Controls.StackPanel]::new()
    $tt = New-AkariAppCell $Title 0 'Tx' 16
    $tt.FontWeight = 'SemiBold'
    $tt.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    [void]$sp.Children.Add($tt)
    $head = New-AkariAppGrid
    $head.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
    foreach ($h in @(@('Name', 2), @('Description', 3), @($Last, 4))) {
        $c = New-AkariAppCell $h[0] $h[1] 'Mu' 12
        $c.FontWeight = 'SemiBold'
        [void]$head.Children.Add($c)
    }
    [void]$sp.Children.Add($head)
    $rows = [Windows.Controls.StackPanel]::new()
    [void]$sp.Children.Add($rows)
    $table.Child = $sp
    $t = @{ Card = $table; Rows = $rows; Title = $tt; Name = $Title }
    Add-AkariAppRows $t $Items
    $t
}

# adds rows to a table card and puts the count in its title
function Add-AkariAppRows($Table, $Items) {
    foreach ($item in $Items) {
        $e = New-AkariAppRow $item
        $script:AppRows[$item.Tweak.Id] = $e
        [void]$Table.Rows.Children.Add($e.Row)
    }
    $n = @($Table.Rows.Children | Where-Object { $_ -is [Windows.Controls.Grid] }).Count
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

# the background read is done: fill the two feature tables (and apply the last quick select to them)
function Complete-AkariFeatureRead([string[]]$Capabilities, [string[]]$Features, [bool]$Failed = $false) {
    $p = $script:AppsParts
    foreach ($x in @(@($p.CapTable, 'CapabilityRemove', $Capabilities), @($p.FeatTable, 'FeatureDisable', $Features))) {
        $x[0].Rows.Children.Clear()
        $items = @(Get-AkariFoundList $script:Groups $x[1] $x[2])
        if ($Failed) { [void]$x[0].Rows.Children.Add((New-AkariAppCell 'Could not be read. Open the Apps step again to retry.' 0 'Bad' 12)) }
        Add-AkariAppRows $x[0] $items
        if ($script:AppsPick) {
            $ids = @($items | ForEach-Object { $_.Tweak.Id })
            Select-AkariApps $script:AppsPick @($script:AppRows.Values | Where-Object { $_.Tweak.Id -in $ids })
        }
    }
    Set-AkariAppsFilter $(if ($Search) { $Search.Text.Trim() } else { '' })
    Update-AkariAppsStatus
}

# shows one tab: its toolbar and tables, the other's hidden; the active tab button is the accent one
function Show-AkariAppsTab([string]$Tab) {
    $script:AppTab = $Tab
    $p = $script:AppsParts
    foreach ($k in 'Remove', 'Install') {
        $on = ($k -eq $Tab)
        $p["${k}Bar"].Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
        $p["${k}Tables"].Visibility = $p["${k}Bar"].Visibility
        $p["${k}Tab"].SetResourceReference([Windows.FrameworkElement]::StyleProperty, $(if ($on) { 'Accent' } else { 'Btn' }))
    }
    $p.Legend.Visibility = if ($Tab -eq 'Remove') { 'Visible' } else { 'Collapsed' }
    # the feature lists take seconds to read: only once the Remove tab is shown (never for Downloads)
    if ($Tab -eq 'Remove' -and -not $script:AppsFeatureRead) { $script:AppsFeatureRead = $true; Start-AkariFeatureRead }
}

# Downloads (Home tile): the Install cards alone, without the Remove / Install tab buttons
function Set-AkariAppsOnlyInstall([bool]$On) {
    $script:AppsParts.Tabs.Visibility = if ($On) { 'Collapsed' } else { 'Visible' }
    if ($On) { Show-AkariAppsTab 'Install' }
}

# builds the Apps view once: Store apps and legacy apps now (on the UI thread), the features in the background
function Get-AkariAppsView {
    if ($script:AppsView) { return $script:AppsView }
    $installed = @(try { Get-AkariAppxInstalled } catch { })
    $script:AppRows = [ordered]@{}
    $script:AppsPick = $null
    $p = @{}
    $view = [Windows.Controls.StackPanel]::new()

    # tabs
    $tabs = [Windows.Controls.StackPanel]::new()
    $tabs.Orientation = 'Horizontal'
    $tabs.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $p.RemoveTab = New-AkariAppsButton 'Remove' 'Store apps, optional features, Windows features and legacy apps to remove' { Show-AkariAppsTab 'Remove' }
    $p.InstallTab = New-AkariAppsButton 'Install' 'Apps to install, from winget where possible' { Show-AkariAppsTab 'Install' }
    [void]$tabs.Children.Add($p.RemoveTab); [void]$tabs.Children.Add($p.InstallTab)
    [void]$view.Children.Add($tabs)
    $p.Tabs = $tabs

    # Remove toolbar: quick select (W11D recommended, FR33THY all removable), clear, only installed
    $p.RemoveBar = [Windows.Controls.StackPanel]::new()
    $p.RemoveBar.Orientation = 'Horizontal'
    $p.RemoveBar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    [void]$p.RemoveBar.Children.Add((New-AkariAppsButton 'Select recommended' 'Win11Debloat''s pick: what is on this PC and marked Recommended' { Select-AkariApps { param($t) $t.Risk -eq 'Safe' } }))
    [void]$p.RemoveBar.Children.Add((New-AkariAppsButton 'AkariOS' 'The AkariOS debloat (FR33THY''s): every Store app, optional feature, Windows feature and legacy app on this PC except its keep-list' { Select-AkariApps { param($t) -not $t.Keep } }))
    [void]$p.RemoveBar.Children.Add((New-AkariAppsButton 'Clear selection' 'Uncheck everything to remove' { Select-AkariApps { param($t) $false } }))
    $only = [Windows.Controls.CheckBox]::new()
    $only.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $only.Content = 'Only installed'
    $only.IsChecked = $script:OnlyInstalled
    $only.VerticalAlignment = 'Center'
    $only.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $only.Add_Click({ param($s, $a) $script:OnlyInstalled = [bool]$s.IsChecked; Set-AkariAppsFilter $(if ($Search) { $Search.Text.Trim() } else { '' }) })
    [void]$p.RemoveBar.Children.Add($only)
    [void]$view.Children.Add($p.RemoveBar)

    # Install toolbar
    $p.InstallBar = [Windows.Controls.StackPanel]::new()
    $p.InstallBar.Orientation = 'Horizontal'
    $p.InstallBar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    [void]$p.InstallBar.Children.Add((New-AkariAppsButton 'Clear selection' 'Uncheck every app to install' { Clear-AkariInstalls }))
    [void]$view.Children.Add($p.InstallBar)

    # Remove: four sections; the two feature ones say "Reading..." until the background read is done
    $p.RemoveTables = [Windows.Controls.StackPanel]::new()
    $p.StoreTable = New-AkariAppTable 'Store apps' 'App ID' @(Get-AkariAppList $script:Tweaks $script:Groups $installed)
    $p.CapTable = New-AkariAppTable 'Optional features' 'Capability' @()
    $p.FeatTable = New-AkariAppTable 'Windows features' 'Feature' @()
    $p.LegacyTable = New-AkariAppTable 'Legacy apps' 'Id' @(Get-AkariLegacyRemoveList $script:Tweaks)
    foreach ($t in $p.CapTable, $p.FeatTable) {
        [void]$t.Rows.Children.Add((New-AkariAppCell 'Reading what is on this PC...' 0 'Mu' 12))
        $t.Title.Text = "$($t.Name) (reading...)"
    }
    foreach ($t in $p.StoreTable, $p.CapTable, $p.FeatTable, $p.LegacyTable) { [void]$p.RemoveTables.Children.Add($t.Card) }
    [void]$view.Children.Add($p.RemoveTables)

    # Install: a card per kind of app, then the Store apps the debloat removed
    $p.InstallTables = [Windows.Controls.StackPanel]::new()
    $appx = @(try { Get-AkariAppxPackages | ForEach-Object { $_.Name } } catch { })
    foreach ($c in Get-AkariInstallCards $script:Tweaks $appx) {
        $t = New-AkariAppTable $c.Title 'Source' @($c.Items)
        if (-not $c.Items.Count) { [void]$t.Rows.Children.Add((New-AkariAppCell 'Nothing to restore: every app in this list is on this PC.' 0 'Mu' 12)) }
        [void]$p.InstallTables.Children.Add($t.Card)
    }
    [void]$view.Children.Add($p.InstallTables)

    # status and legend
    $foot = [Windows.Controls.DockPanel]::new()
    $p.Legend = [Windows.Controls.StackPanel]::new()
    $p.Legend.Orientation = 'Horizontal'
    [Windows.Controls.DockPanel]::SetDock($p.Legend, 'Right')
    foreach ($k in 'Safe', 'Caution', 'Advanced') {
        $d = $AkariAppDots[$k]
        $dc = New-AkariAppCell ([string]$d.Char) 0 $d.Brush 11
        $dc.Margin = [Windows.Thickness]::new(12, 0, 6, 0)
        [void]$p.Legend.Children.Add($dc)
        [void]$p.Legend.Children.Add((New-AkariAppCell $d.Label 0 'Mu' 12))
    }
    [void]$foot.Children.Add($p.Legend)
    $script:AppsStatus = New-AkariAppCell '' 0 'Mu' 12
    [void]$foot.Children.Add($script:AppsStatus)
    [void]$view.Children.Add($foot)

    $script:AppsParts = $p
    $script:AppsView = $view
    # the features are read when the Remove tab is first shown (Downloads opens on Install and never reads them)
    $script:AppsFeatureRead = $false
    Show-AkariAppsTab $(if ($script:Mode -eq 'Downloads') { 'Install' } else { $script:AppTab })
    Update-AkariAppsStatus
    $view
}
