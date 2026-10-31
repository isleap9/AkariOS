# Services page (Optimize > Advanced > Services): the services FR33THY and ZOICWARE change (services.psd1, with what
# each one sets), or with "Show all" every service on this PC, as in Windows' Services console; each with its startup
# type (Automatic, Automatic (delayed start), Manual, Disabled) and Start / Stop, acting right away. The
# Category's Tweaks (advanced-services-off) sit above it (UI\CataloguePage.ps1). The list is read once in the
# background (Refresh reads it again); changes go through the Catalogue's queue, one at a time in the job, with the
# session's restore point first. Core\System.ps1 reads and changes the services. Dot-sourced by Akari.ps1 after
# UI\CataloguePage.ps1; the functions before "the list" are pure (tests dot-source this file).

$AkariStartTypes = [ordered]@{ Automatic = 'Automatic'; AutomaticDelayed = 'Automatic (delayed start)'; Manual = 'Manual'; Disabled = 'Disabled' }
$AkariServiceFilters = 'All', 'Running', 'Automatic', 'Manual', 'Disabled', 'Changed'
# services Windows needs to start, sign in, show the desktop or play sound: disabling or stopping one asks first
$AkariCriticalServices = 'RpcSs', 'RpcEptMapper', 'DcomLaunch', 'LSM', 'Power', 'PlugPlay', 'BrokerInfrastructure', 'SamSs',
    'ProfSvc', 'Schedule', 'CoreMessagingRegistrar', 'SystemEventsBroker', 'gpsvc', 'StateRepository', 'Winmgmt', 'UserManager',
    'EventLog', 'AudioEndpointBuilder', 'Audiosrv', 'TextInputManagementService', 'Dhcp', 'Dnscache', 'nsi', 'AppXSvc', 'CryptSvc'
# the Windows default start types (2 automatic, 3 manual, 4 disabled) advanced-services-off knows
$AkariServiceDefaultsPath = 'Tweaks\Advanced\Services\Files\services.psd1'

# name -> the Windows default Start value, from services.psd1 (@{ Services = @(@{ Name; Default }) })
function Get-AkariServiceDefaults([string]$Path) {
    $d = @{}
    if (Test-Path -LiteralPath $Path) { foreach ($s in (Import-PowerShellDataFile $Path).Services) { $d[$s.Name] = [int]$s.Default } }
    $d
}

# a service's Windows default Start value (a per-user instance: its template's), or $null when it isn't known
function Get-AkariServiceDefault($Service, [hashtable]$Defaults) {
    if ($Defaults.ContainsKey($Service.Name)) { return $Defaults[$Service.Name] }
    $tpl = Get-AkariServiceTemplate $Service.Name
    if ($tpl -and $Defaults.ContainsKey($tpl)) { return $Defaults[$tpl] }
    $null
}

# name -> what FR33THY's and ZOICWARE's picks set it to ("Off (FR33THY): Disabled", "Light (ZOICWARE): Disabled",
# "Manual (ZOICWARE): Manual"), from services.psd1: the services the page lists unless "Show all" is on
function Get-AkariServiceSuggestions([string]$Path) {
    $out = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $out }
    $d = Import-PowerShellDataFile $Path
    $add = { param($n, $text) if (-not $out.ContainsKey($n)) { $out[$n] = @() }; $out[$n] += $text }
    foreach ($s in $d.Services) { if ($null -ne $s.Off) { & $add $s.Name "Off (FR33THY): $(Get-AkariStartLabel $s.Off)" } }
    foreach ($n in $d.Light) { & $add $n 'Light (ZOICWARE): Disabled' }
    foreach ($n in $d.Manual) { & $add $n 'Manual (ZOICWARE): Manual' }
    $out
}

# a service's suggestions (a per-user instance: its template's), @() when FR33THY and ZOICWARE leave it
function Get-AkariServiceSuggestion($Service, [hashtable]$Suggest) {
    if ($Suggest.ContainsKey($Service.Name)) { return @($Suggest[$Service.Name]) }
    $tpl = Get-AkariServiceTemplate $Service.Name
    if ($tpl -and $Suggest.ContainsKey($tpl)) { return @($Suggest[$tpl]) }
    @()
}

# $true when the service's startup type is not its known Windows default (delayed counts as automatic)
function Test-AkariServiceChanged($Service, [hashtable]$Defaults) {
    $def = Get-AkariServiceDefault $Service $Defaults
    if ($null -eq $def -or $Service.Start -notin $AkariStartTypes.Keys) { return $false }
    (ConvertFrom-AkariStartType $Service.Start).Start -ne $def
}

# the services $Filter ($AkariServiceFilters) and $Query (name, display name or description) leave, by display name;
# with $Suggest (Get-AkariServiceSuggestions), only the ones FR33THY or ZOICWARE change ($null = every service)
function Get-AkariServiceView($Services, [string]$Filter, [string]$Query, [hashtable]$Defaults, [hashtable]$Suggest = $null) {
    $q = "$Query".Trim()
    @($Services | Where-Object {
        $s = $_
        if ($null -ne $Suggest -and -not @(Get-AkariServiceSuggestion $s $Suggest).Count) { return $false }
        $hit = switch ($Filter) {
            'Running' { $s.Status -eq 'Running' }
            'Automatic' { $s.Start -in 'Automatic', 'AutomaticDelayed' }
            'Manual' { $s.Start -eq 'Manual' }
            'Disabled' { $s.Start -eq 'Disabled' }
            'Changed' { Test-AkariServiceChanged $s $Defaults }
            default { $true }
        }
        $hit -and (-not $q -or "$($s.DisplayName) $($s.Name) $($s.Description)".IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    } | Sort-Object DisplayName)
}

# the service's button now: Stop (running and it accepts a stop), Start (stopped and not disabled), or '' (none)
function Get-AkariServiceAction($Service) {
    if ($Service.Status -eq 'Running') { if ($Service.CanStop) { return 'Stop' } else { return '' } }
    if ($Service.Status -eq 'Stopped' -and $Service.Start -ne 'Disabled') { return 'Start' }
    ''
}

# the question before a change ($Op StartType with a startup type, or Control with Start / Stop), or '' (none)
function Get-AkariServiceConfirm($Service, [string]$Op, [string]$Value) {
    if ($Service.Name -notin $AkariCriticalServices -and (Get-AkariServiceTemplate $Service.Name) -notin $AkariCriticalServices) { return '' }
    if ($Op -eq 'StartType' -and $Value -eq 'Disabled') {
        return "$($Service.DisplayName) is a service Windows needs. Disabled, Windows may not start, sign you in or work properly until you set it back (in Safe Mode if it no longer starts). Disable it anyway?"
    }
    if ($Op -eq 'Control' -and $Value -eq 'Stop') {
        return "$($Service.DisplayName) is a service Windows needs. Stopping it can freeze or close parts of Windows until it starts again or you restart. Stop it anyway?"
    }
    ''
}

# a Start value as its startup type's name
function Get-AkariStartLabel([int]$Start) { switch ($Start) { 2 { 'Automatic' } 3 { 'Manual' } 4 { 'Disabled' } default { "$Start" } } }

# ---- the list

$script:SvcList = $null      # the services read (Get-AkariServices), $null until then
$script:SvcReadError = ''
$script:SvcReading = $false
$script:SvcRows = @{}        # name -> @{ Svc; Card; Combo; Button; Status; Default; StateText; Busy; Error; Muted }
$script:SvcFilter = 'All'
$script:SvcDefaults = $null
$script:SvcSuggest = $null
$script:SvcAll = $false       # "Show all": every service, not only FR33THY's and ZOICWARE's
$script:SvcBar = $null

# a switch with its label, for a toolbar: @{ Panel; Switch }
function New-AkariBarSwitch([string]$Label, [string]$Tip) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Orientation = 'Horizontal'
    $sp.VerticalAlignment = 'Center'
    $sp.Margin = [Windows.Thickness]::new(16, 0, 12, 0)
    $sp.ToolTip = $Tip
    $lb = New-AkariText $Label 13 'Mu'
    $lb.VerticalAlignment = 'Center'
    $lb.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
    $sw = [Windows.Controls.Primitives.ToggleButton]::new()
    $sw.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CatSwitch')
    $sw.VerticalAlignment = 'Center'
    $sw.IsChecked = $false
    [void]$sp.Children.Add($lb); [void]$sp.Children.Add($sw)
    @{ Panel = $sp; Switch = $sw }
}

# the toolbar: the filters, how many, Refresh (built once)
function Get-AkariServiceBar {
    if ($script:SvcBar) { return $script:SvcBar }
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 18, 0, 12)
    $refresh = [Windows.Controls.Button]::new()
    $refresh.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $refresh.Content = 'Refresh'
    $refresh.ToolTip = 'Read the services again'
    $refresh.Add_Click({ if (-not $script:SvcReading) { $script:SvcList = $null; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($refresh, 'Right')
    [void]$bar.Children.Add($refresh)
    $all = New-AkariBarSwitch 'Show all' 'Off: only the services FR33THY and ZOICWARE change, the ones known to be safe to turn off. On: every service on this PC, to go further.'
    $all.Switch.Add_Click({ param($s, $a) $script:SvcAll = ($s.IsChecked -eq $true); Show-Page })
    [Windows.Controls.DockPanel]::SetDock($all.Panel, 'Right')
    [void]$bar.Children.Add($all.Panel)
    $seg = [Windows.Controls.ListBox]::new()
    $seg.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Segmented')
    $seg.Margin = [Windows.Thickness]::new(0, 0, 16, 0)
    foreach ($f in $AkariServiceFilters) {
        $it = [Windows.Controls.ListBoxItem]::new()
        $it.Content = $(if ($f -eq 'Changed') { 'Not default' } else { $f }); $it.Tag = $f
        if ($f -eq 'Changed') { $it.ToolTip = 'Startup types that differ from the Windows default (for the services Akari knows the default of)' }
        [void]$seg.Items.Add($it)
    }
    $seg.SelectedIndex = 0
    $seg.Add_SelectionChanged({ param($s, $a) if ($s.SelectedItem) { $script:SvcFilter = [string]$s.SelectedItem.Tag; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($seg, 'Left')
    [void]$bar.Children.Add($seg)
    $count = New-AkariText '' 13 'Mu'
    $count.VerticalAlignment = 'Center'
    [void]$bar.Children.Add($count)
    $script:SvcBar = @{ Bar = $bar; Count = $count }
    $script:SvcBar
}

# adds the services list to the page (the Catalogue page calls it, $Query = the search)
function Show-AkariServiceList([string]$Query) {
    $b = Get-AkariServiceBar
    [void]$Rows.Children.Add($b.Bar)
    if ($null -eq $script:SvcList) {
        $b.Count.Text = 'Reading the services' + [char]0x2026
        Start-AkariServiceRead
        return
    }
    if ($script:SvcReadError) {
        $b.Count.Text = ''
        $m = New-AkariText "Couldn't read the services: $($script:SvcReadError)" 13 'Bad'
        [void]$Rows.Children.Add($m)
        return
    }
    if ($null -eq $script:SvcDefaults) { $script:SvcDefaults = Get-AkariServiceDefaults (Join-Path $Root $AkariServiceDefaultsPath) }
    if ($null -eq $script:SvcSuggest) { $script:SvcSuggest = Get-AkariServiceSuggestions (Join-Path $Root $AkariServiceDefaultsPath) }
    $view = @(Get-AkariServiceView $script:SvcList $script:SvcFilter $Query $script:SvcDefaults $(if ($script:SvcAll) { $null } else { $script:SvcSuggest }))
    $all = @($script:SvcList).Count
    $b.Count.Text = if ($script:SvcAll) { if ($view.Count -eq $all) { "$all services" } else { "$($view.Count) of $all services" } }
                    else { "$($view.Count) services FR33THY and ZOICWARE change" }
    foreach ($s in $view) {
        $e = $script:SvcRows[$s.Name]
        if (-not $e) { $e = New-AkariServiceRow $s; $script:SvcRows[$s.Name] = $e }
        elseif (-not $e.Busy) { $e.Svc = $s }
        [void]$Rows.Children.Add($e.Card)
        Set-AkariServiceRow $e
    }
    if (-not $view.Count) { [void]$Rows.Children.Add((New-AkariText 'No service matches.' 13 'Mu')) }
}

# reads every service in a runspace, then shows the page again when it is still open
function Start-AkariServiceRead {
    if ($script:SvcReading) { return }
    $script:SvcReading = $true
    $shared = [hashtable]::Synchronized(@{})
    $job = Start-AkariJob 'try { $AkariShared.List = @(Get-AkariServices) } catch { $AkariShared.Error = $_.Exception.Message }' $script:Queue "$Root\Core" $shared
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
        Complete-AkariServiceRead $j.Shared
    })
    $tm.Start()
}

function Complete-AkariServiceRead($Shared) {
    $script:SvcReading = $false
    $script:SvcReadError = [string]$Shared.Error
    $script:SvcList = if ($Shared.List) { @($Shared.List) } else { @() }
    if ($AkariCatalogueLists[$script:Cat].Show -eq 'Show-AkariServiceList') { Show-Page }
}

# ---- a row

function New-AkariServiceRow($s) {
    $e = @{ Svc = $s; Busy = ''; Error = ''; Muted = $false }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Padding = [Windows.Thickness]::new(18, 10, 18, 10)
    $card.MinHeight = 0
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    $dp = [Windows.Controls.DockPanel]::new()
    # the startup type, right; Start / Stop left of it
    $combo = [Windows.Controls.ComboBox]::new()
    $combo.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $combo.Width = 230
    $combo.VerticalAlignment = 'Center'
    $combo.Margin = [Windows.Thickness]::new(12, 0, 0, 0)
    $combo.ToolTip = 'Startup type'
    $combo.Tag = $s.Name
    foreach ($k in $AkariStartTypes.Keys) {
        $it = [Windows.Controls.ComboBoxItem]::new()
        $it.Content = $AkariStartTypes[$k]; $it.Tag = $k
        [void]$combo.Items.Add($it)
    }
    $combo.Add_SelectionChanged({
        param($c, $a)
        $e = $script:SvcRows[[string]$c.Tag]
        if (-not $e -or $e.Muted -or -not $c.SelectedItem) { return }
        $v = [string]$c.SelectedItem.Tag
        if ($v -ne $e.Svc.Start) { Invoke-AkariServiceChange $e.Svc.Name 'StartType' $v }
    })
    [Windows.Controls.DockPanel]::SetDock($combo, 'Right')
    [void]$dp.Children.Add($combo)
    $btn = [Windows.Controls.Button]::new()
    $btn.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $btn.MinWidth = 76
    $btn.VerticalAlignment = 'Center'
    $btn.Margin = [Windows.Thickness]::new(16, 0, 0, 0)
    $btn.Tag = $s.Name
    $btn.Add_Click({ param($b, $a) Invoke-AkariServiceChange ([string]$b.Tag) 'Control' ([string]$b.Content) })
    [Windows.Controls.DockPanel]::SetDock($btn, 'Right')
    [void]$dp.Children.Add($btn)
    # the display name, then the name (mono), the status and the Windows default, the description, the State line
    $text = [Windows.Controls.StackPanel]::new()
    $text.VerticalAlignment = 'Center'
    $name = New-AkariText $s.DisplayName 14
    $name.FontWeight = 'SemiBold'
    [void]$text.Children.Add($name)
    $meta = [Windows.Controls.WrapPanel]::new()
    $meta.Margin = [Windows.Thickness]::new(0, 3, 0, 0)
    $id = New-AkariText $s.Name 12 'Ter'
    Set-AkariFont $id 'Mono'
    $id.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $e.Status = New-AkariText '' 12 'Ter'
    $e.Status.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $e.Default = New-AkariText '' 12 'Ter'
    foreach ($x in $id, $e.Status, $e.Default) { $x.VerticalAlignment = 'Center'; [void]$meta.Children.Add($x) }
    [void]$text.Children.Add($meta)
    if ($s.Description) {
        $d = New-AkariText $s.Description 12 'Mu'
        $d.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
        $d.MaxHeight = 34
        $d.TextTrimming = 'CharacterEllipsis'
        $d.ToolTip = $s.Description
        [void]$text.Children.Add($d)
    }
    # what FR33THY's and ZOICWARE's picks set it to (empty for the others: Show all)
    $e.Suggest = New-AkariText '' 12 'Ter'
    $e.Suggest.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$text.Children.Add($e.Suggest)
    $e.StateText = New-AkariText '' 12 'Ter'
    $e.StateText.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$text.Children.Add($e.StateText)
    [void]$dp.Children.Add($text)
    $card.Child = $dp
    $e.Card = $card; $e.Combo = $combo; $e.Button = $btn
    $e
}

# the row after a change of the service, Busy or Error
function Set-AkariServiceRow($e) {
    $s = $e.Svc
    $e.Status.Text = if ($s.Status) { $s.Status } else { 'Unknown' }
    $e.Status.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($s.Status -eq 'Running') { 'Ok' } else { 'Ter' }))
    $def = if ($script:SvcDefaults) { Get-AkariServiceDefault $s $script:SvcDefaults }
    $e.Default.Text = if ($null -ne $def) { "Windows default: $(Get-AkariStartLabel $def)" } else { '' }
    $e.Default.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if (Test-AkariServiceChanged $s $script:SvcDefaults) { 'Warn' } else { 'Ter' }))
    $sug = if ($script:SvcSuggest) { @(Get-AkariServiceSuggestion $s $script:SvcSuggest) } else { @() }
    $e.Suggest.Text = if ($sug.Count) { 'Suggested: ' + ($sug -join ', ') } else { '' }
    $e.Suggest.Visibility = if ($sug.Count) { 'Visible' } else { 'Collapsed' }
    $e.StateText.Text = if ($e.Error) { "Failed: $($e.Error)" } elseif ($e.Busy -eq 'Waiting') { 'Waiting' + [char]0x2026 } elseif ($e.Busy) { 'Applying' + [char]0x2026 } else { '' }
    $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($e.Error) { 'Bad' } else { 'Ter' }))
    $e.StateText.Visibility = if ($e.StateText.Text) { 'Visible' } else { 'Collapsed' }
    $act = Get-AkariServiceAction $s
    $e.Button.Content = $act
    $e.Button.Visibility = if ($act) { 'Visible' } else { 'Hidden' }
    # Boot / System start: a driver-like service Windows' console doesn't change either
    $e.Combo.IsEnabled = -not $e.Busy -and $s.Start -in $AkariStartTypes.Keys
    $e.Button.IsEnabled = -not $e.Busy
    $e.Muted = $true
    try {
        $it = $e.Combo.Items | Where-Object { [string]$_.Tag -eq $s.Start } | Select-Object -First 1
        if ($it) { $e.Combo.SelectedItem = $it } else { $e.Combo.SelectedIndex = -1 }
    } finally { $e.Muted = $false }
}

# ---- changes: through the Catalogue's queue (UI\CataloguePage.ps1), one at a time

# $Op StartType ($Value = a startup type) or Control ($Value = Start / Stop)
function Invoke-AkariServiceChange([string]$Name, [string]$Op, [string]$Value) {
    $e = $script:SvcRows[$Name]
    if (-not $e -or $e.Busy -or -not $Value) { return }
    $q = Get-AkariServiceConfirm $e.Svc $Op $Value
    if ($q -and -not (Confirm-AkariDialog $q 'Continue' 'Cancel' 'Warning')) { Set-AkariServiceRow $e; return }
    $e.Error = ''
    $e.Busy = 'Waiting'
    Set-AkariServiceRow $e
    $script:CatQueue.Add(@{ Kind = 'Service'; Id = $Name; Op = $Op; Value = $Value })
    Start-AkariCatalogueNext
}

# Start-AkariCatalogueNext's step for a service: the change, then the service read back
function Start-AkariServiceJob($It) {
    $e = $script:SvcRows[$It.Id]
    $e.Busy = 'Running'
    Set-AkariServiceRow $e
    $code = @'
try {
    if ($AkariShared.Op -eq 'StartType') { Set-AkariServiceStart $AkariShared.Id $AkariShared.Value }
    else { Invoke-AkariServiceControl $AkariShared.Id $AkariShared.Value }
} catch { $AkariShared.Error = $_.Exception.Message; Write-Log "Failed: $($_.Exception.Message)" }
try { $AkariShared.Service = @(Get-AkariServices $AkariShared.Id) | Select-Object -First 1 } catch { }
'@
    $code = Add-AkariRestoreFirst $code ''
    $label = if ($It.Op -eq 'StartType') { "$($e.Svc.DisplayName): startup type $($AkariStartTypes[$It.Value])" } else { "$($e.Svc.DisplayName): $($It.Value.ToLower())" }
    Set-Busy $true $label $false
    Add-Log $label
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" ([hashtable]::Synchronized(@{ Id = $It.Id; Op = $It.Op; Value = $It.Value }))
    $script:Job.Label = $label
    $script:Job.Kind = 'CatalogueService'
}

# the job ended (Complete-AkariCatalogueJob): the row shows the service as it is now
function Complete-AkariServiceJob($Shared) {
    $e = $script:SvcRows[$Shared.Id]
    if (-not $e) { return }
    $e.Busy = ''
    $e.Error = [string]$Shared.Error
    if ($Shared.Service) {
        $e.Svc = $Shared.Service
        if ($script:SvcList) { $script:SvcList = @($script:SvcList | ForEach-Object { if ($_.Name -eq $Shared.Id) { $Shared.Service } else { $_ } }) }
    }
    Set-AkariServiceRow $e
}
