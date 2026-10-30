# Catalogue page (Optimize › Advanced, ADR 0005): setting cards whose controls act right away. Pages, search and the
# waiting list come from UI\Catalogue.ps1. States are read in the background when a page opens; changes queue and run
# one at a time in the background job; Safe Mode changes wait in a bar for one restart; Explorer and PC restarts are
# collected in a bar. Dot-sourced by Akari.ps1 after UI\Rows.ps1.

# id -> card: @{ Tweak; Card; Control; StateText; State; Current; Busy ('' / Reading / Waiting / Running); Error; Muted }
$script:CatCards = @{}
# changes waiting for the job: @{ Id; Mode; Value }
$script:CatQueue = [Collections.Generic.List[object]]::new()
# Safe Mode changes waiting for "Restart and apply": id -> Apply / Revert
$script:SafePending = @{}
# ids of applied changes that need Explorer restarted / a PC restart
$script:CatExplorer = [Collections.Generic.HashSet[string]]::new()
$script:CatReboot = [Collections.Generic.HashSet[string]]::new()

# ---- cards

function New-AkariCatalogueCard($t) {
    $e = @{ Tweak = $t; State = 'Unknown'; Current = $null; Busy = ''; Error = ''; Muted = $false }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Tag = $t.Id
    $dp = [Windows.Controls.DockPanel]::new()
    # the control, right
    switch ($t.Kind) {
        'Toggle' {
            $ctl = [Windows.Controls.Primitives.ToggleButton]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CatSwitch')
            $ctl.Add_Click({ param($s, $a) Invoke-AkariCatalogueChange ([string]$s.Tag) $(if ($s.IsChecked -eq $true) { 'Apply' } else { 'Revert' }) $null })
        }
        'Choice' {
            $ctl = [Windows.Controls.ComboBox]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
            $ctl.Width = 220
            $def = Resolve-AkariDefault $t.Default
            foreach ($c in $t.Choices) {
                $it = [Windows.Controls.ComboBoxItem]::new()
                $label = if ($c.Label) { $c.Label } else { "$($c.Value)" }
                if (Test-AkariRegMatch $c.Value $t.Recommended) { $label += ' (Recommended)' }
                elseif (Test-AkariRegMatch $c.Value $def) { $label += ' (Windows default)' }
                $it.Content = $label
                $it.Tag = $c.Value
                [void]$ctl.Items.Add($it)
            }
            $ctl.Add_SelectionChanged({
                param($s, $a)
                $e = $script:CatCards[[string]$s.Tag]
                if ($e.Muted -or -not $s.SelectedItem) { return }
                $v = $s.SelectedItem.Tag
                $t = $e.Tweak
                if (Test-AkariRegMatch $v (Resolve-AkariDefault $t.Default)) { Invoke-AkariCatalogueChange $t.Id 'Revert' $null }
                elseif (Test-AkariRegMatch $v $t.Recommended) { Invoke-AkariCatalogueChange $t.Id 'Apply' $null }
                else { Invoke-AkariCatalogueChange $t.Id 'Apply' $v }
            })
        }
        default {
            $ctl = [Windows.Controls.Button]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
            $ctl.Content = $t.Button
            $ctl.MinWidth = 96
            $ctl.Add_Click({ param($s, $a) Invoke-AkariCatalogueChange ([string]$s.Tag) 'Apply' $null })
        }
    }
    $ctl.Tag = $t.Id
    $ctl.VerticalAlignment = 'Center'
    $ctl.Margin = [Windows.Thickness]::new(16, 0, 0, 0)
    [Windows.Controls.DockPanel]::SetDock($ctl, 'Right')
    [void]$dp.Children.Add($ctl)
    # the restart / Safe Mode marks, left of the control
    $marks = [Windows.Controls.StackPanel]::new()
    $marks.Orientation = 'Horizontal'
    $marks.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($marks, 'Right')
    if ($t.Reboot) { [void]$marks.Children.Add((New-AkariGlyph 'rotate-ccw' 'Mu' 'Restart required')) }
    if ($t.SafeMode) { [void]$marks.Children.Add((New-AkariGlyph 'shield' 'Mu' 'Runs in Safe Mode: Akari restarts into it and back')) }
    [void]$dp.Children.Add($marks)
    # the TweakRow: name, then the id (mono) with the AkariOS and Risk badges, the description, the State line
    $text = [Windows.Controls.StackPanel]::new()
    $text.VerticalAlignment = 'Center'
    $name = [Windows.Controls.TextBlock]::new()
    [void]$name.Inlines.Add([Windows.Documents.Run]::new($t.Name))
    $name.FontSize = 14
    $name.FontWeight = 'SemiBold'
    $name.TextWrapping = 'Wrap'
    [void]$text.Children.Add($name)
    $meta = [Windows.Controls.WrapPanel]::new()
    $meta.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    $id = New-AkariText $t.Id 12 'Ter'
    Set-AkariFont $id 'Mono'
    $id.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
    $id.VerticalAlignment = 'Center'
    [void]$meta.Children.Add($id)
    if ($t.AkariOS) { [void]$meta.Children.Add((New-AkariBadge 'AkariOS')) }
    if ($t.Risk -in 'Caution', 'Advanced') { [void]$meta.Children.Add((New-AkariBadge $t.Risk)) }
    [void]$text.Children.Add($meta)
    if ($t.Description) {
        $d = New-AkariText $t.Description 13 'Mu'
        $d.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
        [void]$text.Children.Add($d)
    }
    $e.StateText = New-AkariText '' 12 'Ter'
    $e.StateText.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$text.Children.Add($e.StateText)
    [void]$dp.Children.Add($text)
    $card.Child = $dp
    $e.Card = $card; $e.Control = $ctl
    $e
}

# the card's State line and control after a change of State, Busy, Error or the waiting list
function Set-AkariCatalogueCard($e) {
    $t = $e.Tweak
    $pending = $script:SafePending.ContainsKey($t.Id)
    if ($e.Error) {
        $e.StateText.Text = "Failed: $($e.Error)"
        $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Bad')
    } else {
        $e.StateText.Text = Get-AkariCatalogueStateText $t $e.State $e.Busy $pending
        $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($pending) { 'Warn' } else { 'Ter' }))
    }
    $e.StateText.Visibility = if ($e.StateText.Text) { 'Visible' } else { 'Collapsed' }
    $e.Control.IsEnabled = -not $e.Busy
    $e.Muted = $true
    try {
        switch ($t.Kind) {
            'Toggle' {
                $e.Control.IsChecked = if ($pending) { $script:SafePending[$t.Id].Mode -eq 'Apply' }
                                       elseif ($e.State -eq 'Optimized') { $true } elseif ($e.State -eq 'Default') { $false } else { $null }
            }
            'Choice' {
                # waiting for Safe Mode: the value it will get, else the current one
                $show = $e.Current
                if ($pending) {
                    $p = $script:SafePending[$t.Id]
                    $show = if ($null -ne $p.Value) { $p.Value } elseif ($p.Mode -eq 'Apply') { $t.Recommended } else { Resolve-AkariDefault $t.Default }
                }
                $it = if ($null -ne $show) { $e.Control.Items | Where-Object { Test-AkariRegMatch $_.Tag $show } | Select-Object -First 1 }
                if ($it) { $e.Control.SelectedItem = $it } else { $e.Control.SelectedIndex = -1 }
            }
        }
    } finally { $e.Muted = $false }
}

function Get-AkariCatalogueCard($t) {
    if (-not $script:CatCards.ContainsKey($t.Id)) { $script:CatCards[$t.Id] = New-AkariCatalogueCard $t }
    $script:CatCards[$t.Id]
}

# ---- the page

function Show-AkariCataloguePage([string]$Query) {
    Set-AkariNav 'Catalogue'
    Sync-AkariNav
    Set-AkariPane $true
    $StepsPanel.Visibility = 'Collapsed'; $StepFooter.Visibility = 'Collapsed'; $HomePanel.Visibility = 'Collapsed'
    $Rows.Children.Clear()
    if ($Query) {
        $Heading.Text = 'Search'
        # [char]0x203A: the file has no BOM, so no non-ASCII text in its strings
        $HeaderSub.Text = "Results for `"$Query`" in Optimize $([char]0x203A) Advanced"
        Set-AkariIcon $HeaderIcon 'search'
    } else {
        $sec, $cat = $script:Cat.Substring($AkariCataloguePrefix.Length).Split('/', 2)
        $header = if ($AkariCatalogueHeaders.ContainsKey($sec)) { $AkariCatalogueHeaders[$sec] } else { $sec }
        $Heading.Text = $cat
        $HeaderSub.Text = "$header. Each change applies right away."
        Set-AkariIcon $HeaderIcon (Get-AkariCategoryIcon $cat)
    }
    $list = @(Get-AkariCatalogueList $script:Tweaks $script:Cat $Query)
    # toolbar: how many, and read the States again
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $refresh = [Windows.Controls.Button]::new()
    $refresh.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $refresh.Content = 'Refresh'
    $refresh.ToolTip = 'Read the current state of these tweaks again'
    $refresh.Add_Click({ Start-AkariCatalogueStates @(Get-AkariCatalogueList $script:Tweaks $script:Cat $Search.Text.Trim()) })
    [Windows.Controls.DockPanel]::SetDock($refresh, 'Right')
    [void]$bar.Children.Add($refresh)
    $count = New-AkariText "$($list.Count) tweak$(if ($list.Count -ne 1) { 's' })" 13 'Mu'
    $count.VerticalAlignment = 'Center'
    [void]$bar.Children.Add($count)
    [void]$Rows.Children.Add($bar)
    $last = ''
    foreach ($t in $list) {
        # search results: a heading per Section › Category
        if ($Query -and "$($t.Section)/$($t.Category)" -ne $last) {
            $last = "$($t.Section)/$($t.Category)"
            $hs = if ($AkariCatalogueHeaders.ContainsKey($t.Section)) { $AkariCatalogueHeaders[$t.Section] } else { $t.Section }
            $h = New-AkariText "$hs $([char]0x203A) $($t.Category)" 14
            $h.FontWeight = 'SemiBold'
            Set-AkariFont $h 'Display'
            $h.Margin = [Windows.Thickness]::new(2, 12, 0, 6)
            [void]$Rows.Children.Add($h)
        }
        $e = Get-AkariCatalogueCard $t
        [void]$Rows.Children.Add($e.Card)
        Set-AkariCatalogueCard $e
    }
    if (-not $list.Count) {
        [void]$Rows.Children.Add((New-AkariText $(if ($Query) { 'No tweak matches.' } else { 'Nothing here yet.' }) 13 'Mu'))
    }
    Start-AkariCatalogueStates $list
    Update-AkariCatalogueBars
}

# ---- States, read in the background

# reads the States of $Tweaks (Toggles and Choices not busy) in a runspace; cards show "Reading…" until theirs arrives
function Start-AkariCatalogueStates($Tweaks) {
    $list = @($Tweaks | Where-Object { $_.Kind -ne 'Action' -and -not (Get-AkariCatalogueCard $_).Busy })
    if (-not $list.Count) { return }
    foreach ($t in $list) { $e = Get-AkariCatalogueCard $t; $e.Busy = 'Reading'; $e.Error = ''; Set-AkariCatalogueCard $e }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{ Items = @($list | ForEach-Object { @{ Id = $_.Id; Source = $_.Source } }); States = [hashtable]::Synchronized(@{}) })
    $code = @"
foreach (`$i in `$AkariShared.Items) {
    try {
        `$t = Import-AkariTweakFile -Path `$i.Source -TweaksRoot $(& $q "$Root\Tweaks")
        `$cur = if (`$t.Kind -eq 'Choice') { Get-AkariChoiceValue `$t } else { `$null }
        `$AkariShared.States[`$i.Id] = @{ State = (Get-AkariState `$t); Current = `$cur }
    } catch { `$AkariShared.States[`$i.Id] = @{ State = 'Unknown'; Current = `$null } }
}
"@
    $job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(200)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        # States arrive one by one: show each as soon as it is read
        $got = @{}
        foreach ($k in @($j.Shared.States.Keys)) { $got[$k] = $j.Shared.States[$k] }
        Set-AkariCatalogueStates $got
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        # whatever could not be read
        $rest = @{}
        foreach ($i in $j.Shared.Items) { if (-not $j.Shared.States.ContainsKey($i.Id)) { $rest[$i.Id] = @{ State = 'Unknown'; Current = $null } } }
        Set-AkariCatalogueStates $rest
    })
    $tm.Start()
}

# States read: id -> @{ State; Current }; only cards still reading take them
function Set-AkariCatalogueStates([hashtable]$States) {
    foreach ($id in @($States.Keys)) {
        $e = $script:CatCards[$id]
        if (-not $e -or $e.Busy -ne 'Reading') { continue }
        $e.State = [string]$States[$id].State
        $e.Current = $States[$id].Current
        $e.Busy = ''
        Set-AkariCatalogueCard $e
    }
}

# ---- changes: right away, one at a time

# a control was used: confirm when needed, then queue the change (or, for a Safe Mode Tweak, wait for Safe Mode)
function Invoke-AkariCatalogueChange([string]$Id, [string]$Mode, $Value) {
    $e = $script:CatCards[$Id]
    if (-not $e -or $e.Busy) { return }
    $t = $e.Tweak
    if ($Mode -eq 'Apply') {
        $target = if ($t.Kind -eq 'Choice') { if ($null -ne $Value) { $Value } else { $t.Recommended } } else { 'Optimized' }
        $q = Get-AkariConfirmText $t $target
        if ($q -and -not (Confirm-AkariDialog $q 'Continue')) { Set-AkariCatalogueCard $e; return }
    }
    $e.Error = ''
    if ($t.SafeMode -and -not (Test-AkariSafeMode)) {
        Set-AkariSafePending $script:SafePending $t $e.State $Mode $Value $e.Current
        Set-AkariCatalogueCard $e
        Update-AkariCatalogueBars
        return
    }
    $e.Busy = 'Waiting'
    Set-AkariCatalogueCard $e
    $script:CatQueue.Add(@{ Id = $Id; Mode = $Mode; Value = $Value })
    Start-AkariCatalogueNext
}

# runs the next queued change when the job is free: the Runner, then the State read back
function Start-AkariCatalogueNext {
    if ($script:Job -or -not $script:CatQueue.Count) { return }
    $it = $script:CatQueue[0]
    $script:CatQueue.RemoveAt(0)
    $e = $script:CatCards[$it.Id]
    $t = $e.Tweak
    $e.Busy = 'Running'
    Set-AkariCatalogueCard $e
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $code = @"
`$t = Import-AkariTweakFile -Path $(& $q $t.Source) -TweaksRoot $(& $q "$Root\Tweaks")
`$AkariShared.Outcome = Invoke-AkariTweak `$t `$AkariShared.Mode `$AkariShared.Value
`$AkariShared.State = Get-AkariState `$t
if (`$t.Kind -eq 'Choice') { `$AkariShared.Current = Get-AkariChoiceValue `$t }
"@
    # the first change of the session gets an AkariOS restore point first (not for Check / Open buttons)
    $code = Add-AkariRestoreFirst $code $(if ($t.Kind -eq 'Action') { $t.Button } else { '' })
    $verb = if ($t.Kind -eq 'Action') { $t.Button.ToLower() } elseif ($it.Mode -eq 'Apply') { 'apply' } else { 'revert' }
    $label = "$($t.Name): $verb"
    Set-Busy $true $label $false
    Add-Log $label
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" ([hashtable]::Synchronized(@{ Id = $it.Id; Mode = $it.Mode; Value = $it.Value }))
    $script:Job.Label = $label
    $script:Job.Kind = 'Catalogue'
}

# the Shell timer: a Catalogue job ended
function Complete-AkariCatalogueJob($Job) {
    $s = $Job.Shared
    switch ($Job.Kind) {
        'Catalogue' {
            $e = $script:CatCards[$s.Id]
            if (-not $e) { return }
            $e.Busy = ''
            if ($s.State) { $e.State = [string]$s.State }
            if ($s.ContainsKey('Current')) { $e.Current = $s.Current }
            $o = $s.Outcome
            if (-not $o) { $e.Error = 'it stopped before its change (see the log)' }
            elseif ($o.Outcome -eq 'Failed') { $e.Error = [string]$o.Message }
            elseif ($o.Outcome -in 'Applied', 'Reverted') {
                if ($e.Tweak.Explorer) { [void]$script:CatExplorer.Add($s.Id) }
                if ($e.Tweak.Reboot) { [void]$script:CatReboot.Add($s.Id) }
            }
            Set-AkariCatalogueCard $e
        }
        'CatalogueExplorer' { $script:CatExplorer.Clear() }
        'CatalogueRun' { Complete-AkariCatalogueSafeRun $s }
    }
    Update-AkariCatalogueBars
}

# ---- the bars: Safe Mode changes, restarts

function New-AkariCatalogueBar([string]$Glyph, [string]$Brush) {
    $b = [Windows.Controls.Border]::new()
    $b.BorderThickness = [Windows.Thickness]::new(0, 1, 0, 0)
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Bd')
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S1')
    $b.Padding = [Windows.Thickness]::new(24, 10, 24, 10)
    $dp = [Windows.Controls.DockPanel]::new()
    $ic = New-AkariGlyph $Glyph $Brush ''
    $ic.Width = 18; $ic.Height = 18
    $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left')
    $btns = [Windows.Controls.StackPanel]::new()
    $btns.Orientation = 'Horizontal'
    [Windows.Controls.DockPanel]::SetDock($btns, 'Right')
    $text = New-AkariText '' 13
    $text.VerticalAlignment = 'Center'
    foreach ($x in $ic, $btns, $text) { [void]$dp.Children.Add($x) }
    $b.Child = $dp
    @{ Bar = $b; Text = $text; Buttons = $btns }
}

function New-AkariBarButton([string]$Text, [scriptblock]$Click, [string]$Style = 'Btn') {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style)
    $b.Content = $Text
    $b.Add_Click($Click)
    $b
}

$script:SafeBar = New-AkariCatalogueBar 'shield' 'Warn'
$script:SafeBar.Apply = New-AkariBarButton 'Restart and apply' { Start-AkariCatalogueSafeRun } 'Accent'
[void]$script:SafeBar.Buttons.Children.Add($script:SafeBar.Apply)
$script:RestartBar = New-AkariCatalogueBar 'rotate-ccw' 'Mu'
$script:RestartBar.Explorer = New-AkariBarButton 'Restart Explorer' { Start-AkariCatalogueExplorer }
$script:RestartBar.Reboot = New-AkariBarButton 'Restart now' { Start-AkariCatalogueRestart }
foreach ($x in $script:RestartBar.Explorer, $script:RestartBar.Reboot) { [void]$script:RestartBar.Buttons.Children.Add($x) }
[void]$CatBars.Children.Add($script:SafeBar.Bar)
[void]$CatBars.Children.Add($script:RestartBar.Bar)

# shows the bars that have something to say (on the Catalogue's pages only)
function Update-AkariCatalogueBars {
    $on = ($script:Cat -like "$AkariCataloguePrefix*")
    $n = $script:SafePending.Count
    $script:SafeBar.Bar.Visibility = if ($on -and $n) { 'Visible' } else { 'Collapsed' }
    $script:SafeBar.Text.Text = "$n change$(if ($n -ne 1) { 's' }) need$(if ($n -eq 1) { 's' }) Safe Mode: Akari restarts into it, applies them and restarts back."
    $lines = @(Get-AkariRestartBarText $script:CatExplorer.Count $script:CatReboot.Count)
    $script:RestartBar.Bar.Visibility = if ($on -and $lines.Count) { 'Visible' } else { 'Collapsed' }
    $script:RestartBar.Text.Text = $lines -join "`n"
    $script:RestartBar.Explorer.Visibility = if ($script:CatExplorer.Count) { 'Visible' } else { 'Collapsed' }
    $script:RestartBar.Reboot.Visibility = if ($script:CatReboot.Count) { 'Visible' } else { 'Collapsed' }
    $script:RestartBar.Reboot.Margin = [Windows.Thickness]::new($(if ($script:CatExplorer.Count) { 8 } else { 0 }), 0, 0, 0)
    $CatBars.Visibility = if ($on -and ($n -or $lines.Count)) { 'Visible' } else { 'Collapsed' }
}

function Start-AkariCatalogueExplorer {
    if ($script:Job) { return }
    Set-Busy $true 'Restarting Explorer' $false
    $script:Job = Start-AkariJob 'Restart-AkariExplorer' $script:Queue "$Root\Core"
    $script:Job.Label = 'Restarting Explorer'
    $script:Job.Kind = 'CatalogueExplorer'
}

function Start-AkariCatalogueRestart {
    if ($script:Job) { return }
    if (-not (Confirm-AkariDialog 'Restart the PC now? Save your work first.' 'Restart now' 'Cancel' 'Warning' 'Restart')) { return }
    Set-Busy $true 'Restarting the PC' $false
    $script:Job = Start-AkariJob 'Restart-AkariPC 0' $script:Queue "$Root\Core"
    $script:Job.Label = 'Restarting the PC'
    $script:Job.Kind = 'CatalogueRestart'
}

# "Restart and apply": one Run of the waiting changes (Invoke-AkariPlan takes the PC into Safe Mode and back,
# Core\Phases.ps1), with the session's restore point first
function Start-AkariCatalogueSafeRun([bool]$SkipRestore = $false) {
    if ($script:Job -or -not $script:SafePending.Count) { return }
    $plan = @($script:SafePending.Keys | ForEach-Object {
        $p = $script:SafePending[$_]
        if ($null -ne $p.Value) { @{ Id = $_; Mode = $p.Mode; Value = $p.Value } } else { @{ Id = $_; Mode = $p.Mode } }
    })
    $skip = $SkipRestore -or -not (Get-AkariRestoreChoice 'Optimize')
    $shared = [hashtable]::Synchronized(@{ Plan = $plan; SkipRestore = $skip })
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $code = @"
`$all = @((Get-AkariTweaks $(& $q "$Root\Tweaks")).Tweaks)
if (-not `$AkariShared.SkipRestore) {
    `$AkariShared.Restore = New-AkariRestorePoint 'AkariOS'
    if (-not `$AkariShared.Restore.Ok) { return }
}
`$AkariShared.Outcomes = @(Invoke-AkariPlan `$AkariShared.Plan `$all)
"@
    $label = "Applying $($plan.Count) change$(if ($plan.Count -ne 1) { 's' }) in Safe Mode"
    Set-Busy $true $label
    Add-Log $label
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'CatalogueRun'
}

function Complete-AkariCatalogueSafeRun($Shared) {
    if ($Shared.Restore -and $Shared.Restore.Ok) { $script:RestoreDone = $true }
    if ($null -eq $Shared.Outcomes) {
        # the restore point failed: ask, then go on without one
        if ($Shared.Restore -and -not $Shared.Restore.Ok -and (Confirm-AkariNoRestore $Shared.Restore.Message)) {
            $script:RestoreDone = $true
            Start-AkariCatalogueSafeRun $true
        }
        return
    }
    # the Run restarts the PC into Safe Mode now (Core\Phases.ps1); nothing waits any more
    $script:SafePending.Clear()
    foreach ($e in $script:CatCards.Values) { Set-AkariCatalogueCard $e }
}

# closing Akari with Safe Mode changes waiting: apply them (one restart) or discard them
$window.Add_Closing({
    param($s, $ev)
    if (-not $script:SafePending.Count -or $script:Job) { return }
    $n = $script:SafePending.Count
    $r = Show-AkariDialog "$n change$(if ($n -ne 1) { 's are' } else { ' is' }) waiting for Safe Mode. Restart and apply $(if ($n -ne 1) { 'them' } else { 'it' }) now, or discard $(if ($n -ne 1) { 'them' } else { 'it' })?" 'AkariOS' @('Discard', 'Restart and apply') 'Question'
    if ($r -eq 'Restart and apply') {
        $ev.Cancel = $true
        # UI\Shell.ps1 stopped its timer on Closing: it must run to finish the job
        $timer.Start()
        Start-AkariCatalogueSafeRun
    }
})
