# Scheduled tasks page (Optimize > Advanced > Scheduled tasks): the tasks FR33THY and ZOICWARE turn off
# (Tweaks\Advanced\Scheduled tasks\Files\tasks.psd1, with who and why), or with "Show all" every task on this PC, as in
# Task Scheduler; each with a switch that turns it on or off right away. The Category's Tweaks (advanced-remove-scheduled-tasks) sit
# above it (UI\CataloguePage.ps1). The list is read once in the background (Refresh reads it again); changes go through
# the Catalogue's queue, one at a time in the job, with the session's restore point first. Core\System.ps1 reads and
# changes the tasks. Dot-sourced by Akari.ps1 after UI\ServicesPage.ps1; the functions before "the list" are pure.

$AkariTaskFilters = 'All', 'Enabled', 'Disabled', 'Microsoft', 'Other'
$AkariTaskSuggestPath = 'Tweaks\Advanced\Scheduled tasks\Files\tasks.psd1'

# a task's key in the rows and the queue: its folder and name
function Get-AkariTaskKey($Task) { "$($Task.Path)$($Task.Name)" }

# the tasks.psd1 rows: @(@{ Path; Name (a wildcard); Source; Note })
function Get-AkariTaskSuggestions([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @((Import-PowerShellDataFile $Path).Tasks)
}

# the first tasks.psd1 row that names the task, or $null (FR33THY and ZOICWARE leave it)
function Get-AkariTaskSuggestion($Task, $Suggest) {
    foreach ($r in @($Suggest)) { if ($Task.Path -eq $r.Path -and $Task.Name -like $r.Name) { return $r } }
    $null
}

# the tasks $Filter ($AkariTaskFilters: Microsoft = Windows' own folder, Other = the rest, apps' updaters) and $Query
# (name, folder or description) leave, by folder then name; with $Suggest (tasks.psd1 rows), only the tasks they name
# ($null = every task)
function Get-AkariTaskView($Tasks, [string]$Filter, [string]$Query, $Suggest = $null) {
    $q = "$Query".Trim()
    @($Tasks | Where-Object {
        $t = $_
        if ($null -ne $Suggest -and -not (Get-AkariTaskSuggestion $t $Suggest)) { return $false }
        $hit = switch ($Filter) {
            'Enabled' { $t.Enabled }
            'Disabled' { -not $t.Enabled }
            'Microsoft' { $t.Path -like '\Microsoft\*' }
            'Other' { $t.Path -notlike '\Microsoft\*' }
            default { $true }
        }
        $hit -and (-not $q -or "$($t.Name) $($t.Path) $($t.Description)".IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    } | Sort-Object Path, Name)
}

# ---- the list

$script:TaskList = $null     # the tasks read (Get-AkariTasks), $null until then
$script:TaskReadError = ''
$script:TaskReading = $false
$script:TaskRows = @{}       # key -> @{ Task; Card; Switch; Status; StateText; Busy; Error; Muted }
$script:TaskFilter = 'All'
$script:TaskSuggest = $null
$script:TaskAll = $false      # "Show all": every task, not only FR33THY's and ZOICWARE's
$script:TaskBar = $null

# the toolbar: the filters, how many, Refresh (built once)
function Get-AkariTaskBar {
    if ($script:TaskBar) { return $script:TaskBar }
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 18, 0, 12)
    $refresh = [Windows.Controls.Button]::new()
    $refresh.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $refresh.Content = 'Refresh'
    $refresh.ToolTip = 'Read the scheduled tasks again'
    $refresh.Add_Click({ if (-not $script:TaskReading) { $script:TaskList = $null; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($refresh, 'Right')
    [void]$bar.Children.Add($refresh)
    $all = New-AkariBarSwitch 'Show all' 'Off: only the tasks FR33THY and ZOICWARE turn off, the ones known to be safe to turn off. On: every task on this PC, to go further.'
    $all.Switch.Add_Click({ param($s, $a) $script:TaskAll = ($s.IsChecked -eq $true); Show-Page })
    [Windows.Controls.DockPanel]::SetDock($all.Panel, 'Right')
    [void]$bar.Children.Add($all.Panel)
    $seg = [Windows.Controls.ListBox]::new()
    $seg.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Segmented')
    $seg.Margin = [Windows.Thickness]::new(0, 0, 16, 0)
    foreach ($f in $AkariTaskFilters) {
        $it = [Windows.Controls.ListBoxItem]::new()
        $it.Content = $(if ($f -eq 'Microsoft') { 'Windows' } elseif ($f -eq 'Other') { 'Apps' } else { $f }); $it.Tag = $f
        if ($f -eq 'Microsoft') { $it.ToolTip = 'Windows'' own tasks (the \Microsoft\ folder)' }
        if ($f -eq 'Other') { $it.ToolTip = 'Tasks apps added: updaters, helpers' }
        [void]$seg.Items.Add($it)
    }
    $seg.SelectedIndex = 0
    $seg.Add_SelectionChanged({ param($s, $a) if ($s.SelectedItem) { $script:TaskFilter = [string]$s.SelectedItem.Tag; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($seg, 'Left')
    [void]$bar.Children.Add($seg)
    $count = New-AkariText '' 13 'Mu'
    $count.VerticalAlignment = 'Center'
    [void]$bar.Children.Add($count)
    $script:TaskBar = @{ Bar = $bar; Count = $count }
    $script:TaskBar
}

# adds the task list to the page (the Catalogue page calls it, $Query = the search)
function Show-AkariTaskList([string]$Query) {
    $b = Get-AkariTaskBar
    [void]$Rows.Children.Add($b.Bar)
    if ($null -eq $script:TaskList) {
        $b.Count.Text = 'Reading the scheduled tasks' + [char]0x2026
        Start-AkariTaskRead
        return
    }
    if ($script:TaskReadError) {
        $b.Count.Text = ''
        [void]$Rows.Children.Add((New-AkariText "Couldn't read the scheduled tasks: $($script:TaskReadError)" 13 'Bad'))
        return
    }
    if ($null -eq $script:TaskSuggest) { $script:TaskSuggest = Get-AkariTaskSuggestions (Join-Path $Root $AkariTaskSuggestPath) }
    $view = @(Get-AkariTaskView $script:TaskList $script:TaskFilter $Query $(if ($script:TaskAll) { $null } else { , $script:TaskSuggest }))
    $all = @($script:TaskList).Count
    $b.Count.Text = if ($script:TaskAll) { if ($view.Count -eq $all) { "$all tasks" } else { "$($view.Count) of $all tasks" } }
                    else { "$($view.Count) tasks FR33THY and ZOICWARE turn off" }
    foreach ($t in $view) {
        $k = Get-AkariTaskKey $t
        $e = $script:TaskRows[$k]
        if (-not $e) { $e = New-AkariTaskRow $t; $script:TaskRows[$k] = $e }
        elseif (-not $e.Busy) { $e.Task = $t }
        [void]$Rows.Children.Add($e.Card)
        Set-AkariTaskRow $e
    }
    if (-not $view.Count) { [void]$Rows.Children.Add((New-AkariText 'No task matches.' 13 'Mu')) }
}

# reads every task in a runspace, then shows the page again when it is still open
function Start-AkariTaskRead {
    if ($script:TaskReading) { return }
    $script:TaskReading = $true
    $shared = [hashtable]::Synchronized(@{})
    $job = Start-AkariJob 'try { $AkariShared.List = @(Get-AkariTasks) } catch { $AkariShared.Error = $_.Exception.Message }' $script:Queue "$Root\Core" $shared
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
        Complete-AkariTaskRead $j.Shared
    })
    $tm.Start()
}

function Complete-AkariTaskRead($Shared) {
    $script:TaskReading = $false
    $script:TaskReadError = [string]$Shared.Error
    $script:TaskList = if ($Shared.List) { @($Shared.List) } else { @() }
    if ($AkariCatalogueLists[$script:Cat].Show -eq 'Show-AkariTaskList') { Show-Page }
}

# ---- a row

function New-AkariTaskRow($t) {
    $e = @{ Task = $t; Busy = ''; Error = ''; Muted = $false }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Padding = [Windows.Thickness]::new(18, 10, 18, 10)
    $card.MinHeight = 0
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    $dp = [Windows.Controls.DockPanel]::new()
    $sw = [Windows.Controls.Primitives.ToggleButton]::new()
    $sw.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CatSwitch')
    $sw.VerticalAlignment = 'Center'
    $sw.Margin = [Windows.Thickness]::new(16, 0, 0, 0)
    $sw.ToolTip = 'On: the task runs when its triggers fire. Off: it never runs.'
    $sw.Tag = Get-AkariTaskKey $t
    $sw.Add_Click({ param($s, $a) Invoke-AkariTaskChange ([string]$s.Tag) ($s.IsChecked -eq $true) })
    [Windows.Controls.DockPanel]::SetDock($sw, 'Right')
    [void]$dp.Children.Add($sw)
    # the name, then the folder (mono), the status and the author, the description, the State line
    $text = [Windows.Controls.StackPanel]::new()
    $text.VerticalAlignment = 'Center'
    $name = New-AkariText $t.Name 14
    $name.FontWeight = 'SemiBold'
    [void]$text.Children.Add($name)
    $meta = [Windows.Controls.WrapPanel]::new()
    $meta.Margin = [Windows.Thickness]::new(0, 3, 0, 0)
    $path = New-AkariText $t.Path 12 'Ter'
    Set-AkariFont $path 'Mono'
    $path.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $e.Status = New-AkariText '' 12 'Ter'
    $e.Status.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $items = @($path, $e.Status)
    if ($t.Author) { $items += New-AkariText $t.Author 12 'Ter' }
    foreach ($x in $items) { $x.VerticalAlignment = 'Center'; [void]$meta.Children.Add($x) }
    [void]$text.Children.Add($meta)
    if ($t.Description) {
        $d = New-AkariText $t.Description 12 'Mu'
        $d.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
        $d.MaxHeight = 34
        $d.TextTrimming = 'CharacterEllipsis'
        $d.ToolTip = $t.Description
        [void]$text.Children.Add($d)
    }
    # who turns it off and why (empty for the others: Show all)
    $r = if ($script:TaskSuggest) { Get-AkariTaskSuggestion $t $script:TaskSuggest }
    if ($r) {
        $sg = New-AkariText "Turned off by $($r.Source) ($($r.Note))" 12 'Ter'
        $sg.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
        [void]$text.Children.Add($sg)
    }
    $e.StateText = New-AkariText '' 12 'Ter'
    $e.StateText.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$text.Children.Add($e.StateText)
    [void]$dp.Children.Add($text)
    $card.Child = $dp
    $e.Card = $card; $e.Switch = $sw
    $e
}

function Set-AkariTaskRow($e) {
    $t = $e.Task
    $e.Status.Text = if ($t.State) { $t.State } else { 'Unknown' }
    $e.Status.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($t.State -eq 'Running') { 'Ok' } elseif (-not $t.Enabled) { 'Warn' } else { 'Ter' }))
    $e.StateText.Text = if ($e.Error) { "Failed: $($e.Error)" } elseif ($e.Busy -eq 'Waiting') { 'Waiting' + [char]0x2026 } elseif ($e.Busy) { 'Applying' + [char]0x2026 } else { '' }
    $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($e.Error) { 'Bad' } else { 'Ter' }))
    $e.StateText.Visibility = if ($e.StateText.Text) { 'Visible' } else { 'Collapsed' }
    $e.Switch.IsEnabled = -not $e.Busy
    $e.Switch.IsChecked = [bool]$t.Enabled
}

# ---- changes: through the Catalogue's queue (UI\CataloguePage.ps1), one at a time

function Invoke-AkariTaskChange([string]$Key, [bool]$Enabled) {
    $e = $script:TaskRows[$Key]
    if (-not $e -or $e.Busy) { return }
    $e.Error = ''
    $e.Busy = 'Waiting'
    Set-AkariTaskRow $e
    # the switch shows the change asked for until the job reads the task back
    $e.Switch.IsChecked = $Enabled
    $script:CatQueue.Add(@{ Kind = 'Task'; Id = $Key; Enabled = $Enabled })
    Start-AkariCatalogueNext
}

# Start-AkariCatalogueNext's step for a task: the change, then the task read back
function Start-AkariTaskJob($It) {
    $e = $script:TaskRows[$It.Id]
    $e.Busy = 'Running'
    Set-AkariTaskRow $e
    $e.Switch.IsChecked = $It.Enabled
    $code = @'
try { Set-AkariTaskEnabled $AkariShared.Path $AkariShared.Name $AkariShared.Enabled }
catch { $AkariShared.Error = $_.Exception.Message; Write-Log "Failed: $($_.Exception.Message)" }
try { $AkariShared.Task = @(Get-AkariTasks $AkariShared.Path $AkariShared.Name) | Select-Object -First 1 } catch { }
'@
    $code = Add-AkariRestoreFirst $code ''
    $label = "$($e.Task.Name): turn $(if ($It.Enabled) { 'on' } else { 'off' })"
    Set-Busy $true $label $false
    Add-Log $label
    $shared = [hashtable]::Synchronized(@{ Id = $It.Id; Path = $e.Task.Path; Name = $e.Task.Name; Enabled = [bool]$It.Enabled })
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'CatalogueTask'
}

# the job ended (Complete-AkariCatalogueJob): the row shows the task as it is now
function Complete-AkariTaskJob($Shared) {
    $e = $script:TaskRows[$Shared.Id]
    if (-not $e) { return }
    $e.Busy = ''
    $e.Error = [string]$Shared.Error
    if ($Shared.Task) {
        $e.Task = $Shared.Task
        if ($script:TaskList) { $script:TaskList = @($script:TaskList | ForEach-Object { if ((Get-AkariTaskKey $_) -eq $Shared.Id) { $Shared.Task } else { $_ } }) }
    }
    Set-AkariTaskRow $e
}
