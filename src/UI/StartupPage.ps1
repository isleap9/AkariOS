# Startup apps page (Optimize > Tools > Startup; plan docs/plans/2026-11-26-new-features.md, X2): every app that starts
# with Windows from the Run keys and the Startup folders, as Task Manager's Startup apps lists them; each with a switch
# that turns it on or off right away (Explorer's StartupApproved value, Task Manager's own: turned back on, it runs as
# it did) and Remove, which asks first. The Category's Tweak (oneclick-startup-cleanup) sits above it
# (UI\CataloguePage.ps1). The list is read once in the background (Refresh reads it again); changes go through the
# Catalogue's queue with the session's restore point first. Core\Startup.ps1 reads and changes the entries.
# Dot-sourced by Akari.ps1 after UI\TasksPage.ps1; the functions before "the list" are pure.

$AkariStartupFilters = 'All', 'On', 'Off', 'User', 'Machine'

# a filter's label
function Get-AkariStartupFilterLabel([string]$Filter) {
    switch ($Filter) { 'User' { 'This user' } 'Machine' { 'All users' } default { $Filter } }
}

# the entries $Filter ($AkariStartupFilters) and $Query (name, command, publisher or location) leave, by name, then
# location
function Get-AkariStartupView($Items, [string]$Filter, [string]$Query) {
    $q = "$Query".Trim()
    @($Items | Where-Object {
        $i = $_
        $hit = switch ($Filter) {
            'On' { $i.Enabled }
            'Off' { -not $i.Enabled }
            'User' { $i.Scope -eq 'User' }
            'Machine' { $i.Scope -eq 'Machine' }
            default { $true }
        }
        $hit -and (-not $q -or "$($i.Name) $($i.Command) $($i.Publisher) $($i.Location)".IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    } | Sort-Object Name, Location)
}

# the count line: "n startup apps, m on" (of the whole list), "x of n" when filtered
function Get-AkariStartupCountText($All, $View) {
    $n = @($All).Count
    $on = @($All | Where-Object { $_.Enabled }).Count
    $shown = @($View).Count
    $apps = if ($n -eq 1) { 'startup app' } else { 'startup apps' }
    if ($shown -eq $n) { "$n $apps, $on on" } else { "$shown of $n $apps, $on on" }
}

# ---- the list

$script:StartupList = $null     # the entries read (Get-AkariStartupItems), $null until then
$script:StartupReadError = ''
$script:StartupReading = $false
$script:StartupRows = @{}       # key -> @{ Item; Card; Switch; Remove; Status; StateText; Busy; Error }
$script:StartupFilter = 'All'
$script:StartupBar = $null

# the toolbar: the filter, how many, Refresh (built once)
function Get-AkariStartupBar {
    if ($script:StartupBar) { return $script:StartupBar }
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 18, 0, 12)
    $refresh = [Windows.Controls.Button]::new()
    $refresh.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $refresh.Content = 'Refresh'
    $refresh.ToolTip = 'Read the startup apps again'
    $refresh.Add_Click({ if (-not $script:StartupReading) { $script:StartupList = $null; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($refresh, 'Right')
    [void]$bar.Children.Add($refresh)
    $seg = [Windows.Controls.ComboBox]::new(); $seg.MinWidth = 180
    $seg.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $seg.Margin = [Windows.Thickness]::new(0, 0, 16, 0)
    foreach ($f in $AkariStartupFilters) {
        $it = [Windows.Controls.ComboBoxItem]::new()
        $it.Content = Get-AkariStartupFilterLabel $f; $it.Tag = $f
        [void]$seg.Items.Add($it)
    }
    $seg.SelectedIndex = 0
    $seg.Add_SelectionChanged({ param($s, $a) if ($s.SelectedItem) { $script:StartupFilter = [string]$s.SelectedItem.Tag; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($seg, 'Left')
    [void]$bar.Children.Add($seg)
    $count = New-AkariText '' 13 'Mu'
    $count.VerticalAlignment = 'Center'
    [void]$bar.Children.Add($count)
    $script:StartupBar = @{ Bar = $bar; Count = $count }
    $script:StartupBar
}

# adds the startup list to the page (the Catalogue page calls it, $Query = the search)
function Show-AkariStartupList([string]$Query) {
    $b = Get-AkariStartupBar
    if ($b.Bar.Parent) { $b.Bar.Parent.Children.Remove($b.Bar) }; [void]$Rows.Children.Add($b.Bar)
    if ($null -eq $script:StartupList) {
        $b.Count.Text = 'Reading the startup apps' + [char]0x2026
        Start-AkariStartupRead
        return
    }
    if ($script:StartupReadError) {
        $b.Count.Text = ''
        [void]$Rows.Children.Add((New-AkariText "Couldn't read the startup apps: $($script:StartupReadError)" 13 'Bad'))
        return
    }
    $view = @(Get-AkariStartupView $script:StartupList $script:StartupFilter $Query)
    $b.Count.Text = Get-AkariStartupCountText $script:StartupList $view
    foreach ($i in $view) {
        $e = $script:StartupRows[$i.Key]
        if (-not $e) { $e = New-AkariStartupRow $i; $script:StartupRows[$i.Key] = $e }
        elseif (-not $e.Busy) { $e.Item = $i }
        if ($e.Card.Parent) { $e.Card.Parent.Children.Remove($e.Card) }; [void]$Rows.Children.Add($e.Card)
        Set-AkariStartupRow $e
    }
    if (-not $view.Count) { [void]$Rows.Children.Add((New-AkariText $(if (@($script:StartupList).Count) { 'No startup app matches.' } else { 'Nothing starts with Windows from the Run keys or the Startup folders.' }) 13 'Mu')) }
}

# reads every entry in a runspace, then shows the page again when it is still open
function Start-AkariStartupRead {
    if ($script:StartupReading) { return }
    $script:StartupReading = $true
    $shared = [hashtable]::Synchronized(@{})
    $job = Start-AkariJob 'try { $AkariShared.List = @(Get-AkariStartupItems) } catch { $AkariShared.Error = $_.Exception.Message }' $script:Queue "$Root\Core" $shared
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(200)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        Complete-AkariStartupRead $j.Shared
    })
    $tm.Start()
}

function Complete-AkariStartupRead($Shared) {
    $script:StartupReading = $false
    $script:StartupReadError = [string]$Shared.Error
    $script:StartupList = if ($Shared.List) { @($Shared.List) } else { @() }
    if ($AkariCatalogueLists[$script:Cat].Show -eq 'Show-AkariStartupList') { Show-Page }
}

# ---- a row

function New-AkariStartupRow($i) {
    $e = @{ Item = $i; Busy = ''; Error = '' }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Padding = [Windows.Thickness]::new(18, 10, 18, 10)
    $card.MinHeight = 0
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    $dp = [Windows.Controls.DockPanel]::new()
    $sw = [Windows.Controls.Primitives.ToggleButton]::new()
    $sw.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CatSwitch')
    $sw.VerticalAlignment = 'Center'
    $sw.Margin = [Windows.Thickness]::new(12, 0, 0, 0)
    $sw.ToolTip = 'On: it starts with Windows. Off: it stays, but does not start (as Task Manager turns it off).'
    $sw.Tag = $i.Key
    $sw.Add_Click({ param($s, $a) Invoke-AkariStartupChange ([string]$s.Tag) $(if ($s.IsChecked -eq $true) { 'On' } else { 'Off' }) })
    [Windows.Controls.DockPanel]::SetDock($sw, 'Right')
    [void]$dp.Children.Add($sw)
    $rm = [Windows.Controls.Button]::new()
    $rm.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $rm.Content = 'Remove'
    $rm.VerticalAlignment = 'Center'
    $rm.Margin = [Windows.Thickness]::new(16, 0, 0, 0)
    $rm.ToolTip = 'Delete the entry: its registry value or its Startup folder shortcut'
    $rm.Tag = $i.Key
    $rm.Add_Click({ param($s, $a) Invoke-AkariStartupChange ([string]$s.Tag) 'Remove' })
    [Windows.Controls.DockPanel]::SetDock($rm, 'Right')
    [void]$dp.Children.Add($rm)
    # the name, then the publisher, the location and the status, the command (mono), the State line
    $text = [Windows.Controls.StackPanel]::new()
    $text.VerticalAlignment = 'Center'
    $name = New-AkariText $i.Name 14
    $name.FontWeight = 'SemiBold'
    [void]$text.Children.Add($name)
    $meta = [Windows.Controls.WrapPanel]::new()
    $meta.Margin = [Windows.Thickness]::new(0, 3, 0, 0)
    $e.Status = New-AkariText '' 12 'Ter'
    $items = @()
    if ($i.Publisher) { $items += New-AkariText $i.Publisher 12 'Ter' }
    $items += New-AkariText $i.Location 12 'Ter'
    $items += $e.Status
    foreach ($x in $items) { $x.VerticalAlignment = 'Center'; $x.Margin = [Windows.Thickness]::new(0, 0, 12, 0); [void]$meta.Children.Add($x) }
    [void]$text.Children.Add($meta)
    $cmd = New-AkariText $i.Command 12 'Mu'
    Set-AkariFont $cmd 'Mono'
    $cmd.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    $cmd.TextTrimming = 'CharacterEllipsis'
    $cmd.ToolTip = $i.Command
    [void]$text.Children.Add($cmd)
    $e.StateText = New-AkariText '' 12 'Ter'
    $e.StateText.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$text.Children.Add($e.StateText)
    [void]$dp.Children.Add($text)
    $card.Child = $dp
    $e.Card = $card; $e.Switch = $sw; $e.Remove = $rm
    $e
}

function Set-AkariStartupRow($e) {
    $i = $e.Item
    $e.Status.Text = if ($i.Enabled) { 'On' } else { 'Off' }
    $e.Status.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($i.Enabled) { 'Ter' } else { 'Warn' }))
    $e.StateText.Text = if ($e.Error) { "Failed: $($e.Error)" } elseif ($e.Busy -eq 'Waiting') { 'Waiting' + [char]0x2026 } elseif ($e.Busy) { 'Applying' + [char]0x2026 } else { '' }
    $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($e.Error) { 'Bad' } else { 'Ter' }))
    $e.StateText.Visibility = if ($e.StateText.Text) { 'Visible' } else { 'Collapsed' }
    $e.Switch.IsEnabled = -not $e.Busy
    $e.Remove.IsEnabled = -not $e.Busy
    $e.Switch.IsChecked = [bool]$i.Enabled
}

# ---- changes: through the Catalogue's queue (UI\CataloguePage.ps1), one at a time; $Action = On, Off or Remove

function Invoke-AkariStartupChange([string]$Key, [string]$Action) {
    $e = $script:StartupRows[$Key]
    if (-not $e -or $e.Busy) { return }
    if ($Action -eq 'Remove') {
        $q = "Remove `"$($e.Item.Name)`" from the startup apps?`n`n- Its $(if ($e.Item.Kind -eq 'Registry') { 'registry value' } else { 'Startup folder shortcut' }) is deleted: $($e.Item.Command)`n- The app itself stays installed`n- To keep it and only stop it starting, turn it off instead"
        if (-not (Confirm-AkariDialog $q 'Remove' 'Cancel' 'Warning' 'Remove startup app')) { return }
    }
    $e.Error = ''
    $e.Busy = 'Waiting'
    Set-AkariStartupRow $e
    if ($Action -ne 'Remove') { $e.Switch.IsChecked = ($Action -eq 'On') }
    $script:CatQueue.Add(@{ Kind = 'Startup'; Id = $Key; Action = $Action })
    Start-AkariCatalogueNext
}

# Start-AkariCatalogueNext's step for a startup entry: the change, then the entries read again
function Start-AkariStartupJob($It) {
    $e = $script:StartupRows[$It.Id]
    $e.Busy = 'Running'
    Set-AkariStartupRow $e
    if ($It.Action -ne 'Remove') { $e.Switch.IsChecked = ($It.Action -eq 'On') }
    $code = @'
try {
    if ($AkariShared.Action -eq 'Remove') { Remove-AkariStartupItem $AkariShared.Item }
    else { Set-AkariStartupEnabled $AkariShared.Item ($AkariShared.Action -eq 'On') }
} catch { $AkariShared.Error = $_.Exception.Message; Write-Log "Failed: $($_.Exception.Message)" }
try { $AkariShared.List = @(Get-AkariStartupItems) } catch { }
'@
    $code = Add-AkariRestoreFirst $code ''
    $verb = switch ($It.Action) { 'On' { 'turn on' } 'Off' { 'turn off' } default { 'remove' } }
    $label = "$($e.Item.Name): $verb"
    Set-Busy $true $label $false
    Add-Log $label
    $shared = [hashtable]::Synchronized(@{ Id = $It.Id; Action = $It.Action; Item = $e.Item })
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'CatalogueStartup'
}

# the job ended (Complete-AkariCatalogueJob): the list read again, the row as it is now (gone after Remove)
function Complete-AkariStartupJob($Shared) {
    $e = $script:StartupRows[$Shared.Id]
    if ($Shared.List) { $script:StartupList = @($Shared.List) }
    if (-not $e) { return }
    $e.Busy = ''
    $e.Error = [string]$Shared.Error
    $now = @($script:StartupList | Where-Object { $_.Key -eq $Shared.Id }) | Select-Object -First 1
    if ($now) { $e.Item = $now }
    if ($Shared.Action -eq 'Remove' -and -not $e.Error -and -not $now) {
        $script:StartupRows.Remove($Shared.Id)
        Add-AkariActivity "Removed startup app `"$($e.Item.Name)`"" 'Optimize' 1 'rocket'
        if ($AkariCatalogueLists[$script:Cat].Show -eq 'Show-AkariStartupList') { Show-Page }
        return
    }
    Set-AkariStartupRow $e
}
