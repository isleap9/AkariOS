# Catalogue pages (Optimize's sections, ADR 0005; the prototype's section pages): Settings cards whose controls act right away. Pages, search and the
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
    $e = @{ Tweak = $t; State = 'Unknown'; Current = $null; Busy = ''; Error = ''; Muted = $false; Done = $false }
    # the control (the prototype's control()): a ToggleSwitch for a Toggle, a ComboBox with "Recommended" and "Windows
    # default" beside those options for a Choice, Run / Open for an Action
    switch ($t.Kind) {
        'Toggle' {
            $ctl = [Windows.Controls.Primitives.ToggleButton]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CatSwitch')
            $ctl.Add_Click({ param($s, $a) Invoke-AkariCatalogueChange ([string]$s.Tag) $(if ($s.IsChecked -eq $true) { 'Apply' } else { 'Revert' }) $null })
        }
        'Choice' {
            $ctl = [Windows.Controls.ComboBox]::new()
            $ctl.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
            $ctl.MinWidth = 200
            $def = Resolve-AkariDefault $t.Default
            foreach ($c in $t.Choices) {
                $it = [Windows.Controls.ComboBoxItem]::new()
                $label = if ($c.Label) { $c.Label } else { "$($c.Value)" }
                # the drop-down says Recommended / Windows default on the right of the row (the ComboItem template shows
                # the item's Uid there); the closed box shows the value alone
                if (Test-AkariRegMatch $c.Value $t.Recommended) { $it.Uid = 'Recommended' }
                elseif (Test-AkariRegMatch $c.Value $def) { $it.Uid = 'Windows default' }
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
            $ctl.MinWidth = 80
            $ctl.Add_Click({ param($s, $a) Invoke-AkariCatalogueChange ([string]$s.Tag) 'Apply' $null })
        }
    }
    $ctl.Tag = $t.Id
    $ctl.VerticalAlignment = 'Center'
    # the end of the card: AkariOS and Risk badges, the restart / Safe Mode marks, then the control (or its ring)
    $act = [Windows.Controls.Grid]::new(); $act.VerticalAlignment = 'Center'
    [void]$act.Children.Add($ctl)
    $ring = [Windows.Controls.StackPanel]::new(); $ring.Orientation = 'Horizontal'; $ring.Visibility = 'Collapsed'; $ring.HorizontalAlignment = 'Right'
    [void]$ring.Children.Add((New-AkariRing 16))
    $rt = New-AkariText 'Running' 12 'Mu'; $rt.Margin = [Windows.Thickness]::new(8, 0, 0, 0); $rt.VerticalAlignment = 'Center'
    [void]$ring.Children.Add($rt)
    [void]$act.Children.Add($ring)
    $card = New-AkariSettingsCard (Get-AkariCategoryIcon $t.Category) $t.Name '' @((New-AkariBadges $t), (New-AkariMarks $t), $act)
    $card.Card.Tag = $t.Id
    # the description, with the Tweak's id after it in Cascadia Mono, Ter
    $d = $card.Desc
    $d.Visibility = 'Visible'
    $d.Text = ''
    if ($t.Description) { [void]$d.Inlines.Add([Windows.Documents.Run]::new("$($t.Description) ")) }
    $id = [Windows.Documents.Run]::new($t.Id)
    $id.SetResourceReference([Windows.Documents.TextElement]::FontFamilyProperty, 'FontMono')
    $id.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, 'Ter')
    [void]$d.Inlines.Add($id)
    # the State line: reading, waiting, running, failed, waiting for Safe Mode (empty at rest)
    $e.StateText = New-AkariText '' 12 'Ter'
    $e.StateText.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$card.Text.Children.Add($e.StateText)
    $e.Card = $card.Card; $e.Control = $ctl; $e.Ring = $ring; $e.Name = $card.Title
    $e
}

# a card's name and description with $Query highlighted (the prototype's <mark>: AccText, SemiBold), or plain
function Set-AkariCardHighlight($e, [string]$Query) {
    $tb = $e.Name
    $tb.Inlines.Clear()
    $name = [string]$e.Tweak.Name
    if (-not $Query) { [void]$tb.Inlines.Add([Windows.Documents.Run]::new($name)); return }
    $parts = [regex]::Split($name, '(' + [regex]::Escape($Query) + ')', 'IgnoreCase')
    foreach ($p in $parts) {
        if (-not $p) { continue }
        $r = [Windows.Documents.Run]::new($p)
        if ($p -ieq $Query) { $r.FontWeight = 'SemiBold'; $r.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, 'AccText') }
        [void]$tb.Inlines.Add($r)
    }
}

# the card's State line and control after a change of State, Busy, Error or the waiting list. An Action shows its
# ring while it runs, then Done (the prototype's runAction)
function Set-AkariCatalogueCard($e) {
    $t = $e.Tweak
    $pending = $script:SafePending.ContainsKey($t.Id)
    if ($e.Error) {
        $e.StateText.Text = "Failed: $($e.Error)"
        $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Bad')
    } else {
        $e.StateText.Text = Get-AkariCatalogueStateText $t $e.State $e.Busy $pending
        # at rest the switch or combobox says it all: only Custom / Unknown, and the busy states, keep a line
        if (-not $e.Busy -and -not $pending -and $e.State -in 'Optimized', 'Default') { $e.StateText.Text = '' }
        $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($pending) { 'Warn' } else { 'Ter' }))
    }
    $e.StateText.Visibility = if ($e.StateText.Text) { 'Visible' } else { 'Collapsed' }
    $e.Control.IsEnabled = -not $e.Busy
    $running = ($e.Busy -eq 'Running' -and $t.Kind -eq 'Action')
    $e.Ring.Visibility = if ($running) { 'Visible' } else { 'Collapsed' }
    $e.Control.Visibility = if ($running) { 'Hidden' } else { 'Visible' }
    if ($t.Kind -eq 'Action') {
        if ($e.Done -and -not $e.Busy) {
            $c = [Windows.Controls.StackPanel]::new(); $c.Orientation = 'Horizontal'
            $i = New-AkariIcon 'circle-check.Filled' 16 'Ok'; $i.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
            [void]$c.Children.Add($i); [void]$c.Children.Add((New-AkariText 'Done' 14 'Ok'))
            $e.Control.Content = $c
        } else { $e.Control.Content = $t.Button }
    }
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

# a cached card into $Panel, taken out of the page it was on first (Home's Quick settings, Optimize's Tools)
function Add-AkariCard($Panel, $e) {
    if ($e.Card.Parent) { $e.Card.Parent.Children.Remove($e.Card) }
    [void]$Panel.Children.Add($e.Card)
}

function Get-AkariCatalogueCard($t) {
    if (-not $script:CatCards.ContainsKey($t.Id)) { $script:CatCards[$t.Id] = New-AkariCatalogueCard $t }
    $script:CatCards[$t.Id]
}

# ---- the pages (a drill-down, Windows 11 Settings' pattern, as the native app): a section ('Catalogue:<Section>': its
# categories as rows in groups, UI\Categories.psd1), a category ('Catalogue:<Section>/<Category>': its cards; Services
# and Scheduled tasks their lists too; Optimize > Section > Category), or the search results

# each Category's group and line on its Section's page (shared with the native app's Shell/CategoryInfo)
$script:CategoryInfo = @((Import-PowerShellDataFile "$Root\UI\Categories.psd1").Categories)

# the section and category of a Catalogue page key. Pure.
function Split-AkariCatalogueKey([string]$Key) {
    $rest = $Key.Substring($AkariCataloguePrefix.Length)
    $sec, $cat = $rest.Split('/', 2)
    @{ Section = $sec; Category = $cat }
}

# four Settings-card-sized placeholders that shimmer while a section's States load (.sk)
function New-AkariSkeletons {
    $sp = [Windows.Controls.StackPanel]::new()
    for ($i = 0; $i -lt 4; $i++) {
        $b = [Windows.Controls.Border]::new()
        $b.Height = 68; $b.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
        $b.CornerRadius = [Windows.CornerRadius]::new(4); $b.BorderThickness = [Windows.Thickness]::new(1)
        $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S1')
        $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Bd')
        $b.ClipToBounds = $true
        # the shimmer: a Sub band, faded at both ends by its mask, sliding across once every 1.2 s (a busy loop)
        $r = [Windows.Shapes.Rectangle]::new()
        $r.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'Sub')
        $m = [Windows.Media.LinearGradientBrush]::new()
        $m.StartPoint = [Windows.Point]::new(0, 0); $m.EndPoint = [Windows.Point]::new(1, 0)
        foreach ($s in @(@(0, 0), @(0.5, 255), @(1, 0))) { [void]$m.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb([byte]$s[1], 0, 0, 0), $s[0])) }
        $r.OpacityMask = $m
        $tt = [Windows.Media.TranslateTransform]::new()
        $r.RenderTransform = $tt
        $b.Child = $r
        $b.Add_SizeChanged({
            param($s, $a)
            Start-AkariLoop $s.Child.RenderTransform ([Windows.Media.TranslateTransform]::XProperty) (-$a.NewSize.Width) $a.NewSize.Width 1.2
        })
        [void]$sp.Children.Add($b)
    }
    $sp
}

# the category pages whose States were read once this session: they open with cards, not skeletons
$script:SectionsRead = @{}

function Show-AkariCataloguePage([string]$Query) {
    $StepsPanel.Visibility = 'Collapsed'; $StepFooter.Visibility = 'Collapsed'; $HomePanel.Visibility = 'Collapsed'
    $Rows.Children.Clear()
    $cat = Get-AkariCatalogueOf $script:Tweaks
    if ($Query) { Show-AkariSearchResults $Query; return }
    $k = Split-AkariCatalogueKey $script:Cat
    $sec = $k.Section
    $script:CatShown = $script:Cat
    $hs = if ($AkariCatalogueHeaders.ContainsKey($sec)) { $AkariCatalogueHeaders[$sec] } else { $sec }
    if (-not $k.Category) { Show-AkariSectionPage $cat $sec $hs; return }
    $key = "$AkariCataloguePrefix$sec/$($k.Category)"
    Set-AkariHeader @(@('Optimize', 'Optimize'), @($hs, "$AkariCataloguePrefix$sec"), $k.Category)
    $list = @(Find-AkariCatalogueList $cat $key '')
    $extra = $AkariCatalogueLists[$key]
    if (-not $list.Count -and -not $extra) { [void]$Rows.Children.Add((New-AkariEmpty 'search' 'Nothing here yet' '')); return }
    [void]$Rows.Children.Add((New-AkariLead 'Each change applies right away.'))
    $body = [Windows.Controls.StackPanel]::new()
    foreach ($t in $list) { $e = Get-AkariCatalogueCard $t; Set-AkariCardHighlight $e ''; Add-AkariCard $body $e; Set-AkariCatalogueCard $e }
    # Services, Scheduled tasks: the category's Tweaks, then its list ($AkariCatalogueLists)
    if ($extra) {
        $hold = $Rows
        $Rows = $body
        try { & $extra.Show '' } finally { $Rows = $hold }
    }
    [void]$Rows.Children.Add($body)
    # the States: skeletons until the first ones arrive (the first time this session), then the cards come in
    if (-not $script:SectionsRead[$key] -and @($list | Where-Object { $_.Kind -ne 'Action' }).Count) {
        $script:Skeletons = New-AkariSkeletons
        [void]$Rows.Children.Add($script:Skeletons)
        $body.Visibility = 'Collapsed'
        $script:SectionBody = $body
        $script:SectionLoading = $key
    } else { $script:SectionLoading = '' }
    if ($script:PageMoved -or -not $script:SectionsRead[$key]) { Start-AkariCatalogueStates $list }
    Update-AkariCatalogueBars
}

# a Section's own page: its Categories as Settings rows in their groups (Get-AkariCategoryRows), each opening the
# Category's page
function Show-AkariSectionPage($Catalogue, [string]$Section, [string]$Header) {
    $script:SectionLoading = ''
    Set-AkariHeader @(@('Optimize', 'Optimize'), $Header)
    $list = @(Get-AkariCategoryRows $Catalogue $Section $script:CategoryInfo)
    if (-not $list.Count) { [void]$Rows.Children.Add((New-AkariEmpty 'search' 'Nothing here yet' '')); return }
    [void]$Rows.Children.Add((New-AkariLead 'Pick a category. Each change applies right away.'))
    $groups = [ordered]@{}
    foreach ($r in $list) { if (-not $groups.Contains($r.Group)) { $groups[$r.Group] = [Collections.Generic.List[object]]::new() }; $groups[$r.Group].Add($r) }
    $first = $true
    foreach ($g in $groups.Keys) {
        if ($g) { [void]$Rows.Children.Add((New-AkariSection $g -First:$first)) }
        $first = $false
        foreach ($r in $groups[$g]) { [void]$Rows.Children.Add((New-AkariCategoryRow $r)) }
    }
    Update-AkariCatalogueBars
}

# a Category's row: its icon, name and line, the count in a badge, a chevron; a click opens its page
function New-AkariCategoryRow($Row) {
    $badge = [Windows.Controls.Border]::new()
    $badge.CornerRadius = [Windows.CornerRadius]::new(10); $badge.Padding = [Windows.Thickness]::new(8, 2, 8, 2)
    $badge.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $badge.VerticalAlignment = 'Center'
    $badge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Sub')
    $badge.Child = New-AkariText "$($Row.Count)" 12 'Mu'
    $badge.ToolTip = "$($Row.Count) tweak$(if ($Row.Count -ne 1) { 's' })"
    $chev = New-AkariIcon 'chevron-right' 12 'Mu'
    $c = New-AkariSettingsCard (Get-AkariCategoryIcon $Row.Category) $Row.Category $Row.Line @($badge, $chev) 'CardButton'
    $c.Desc.TextWrapping = 'Wrap'
    $c.Card.Tag = $Row.Key
    $c.Card.Add_Click({ param($x, $e) Select-AkariPage ([string]$x.Tag) })
    $c.Card
}

# the first States of the category are in: the skeletons give way to the cards, which come in (Start-AkariPageEntrance)
function Show-AkariSectionBody {
    if (-not $script:SectionLoading) { return }
    $script:SectionsRead[$script:SectionLoading] = $true
    $script:SectionLoading = ''
    if ($script:Skeletons -and $script:Skeletons.Parent) { $script:Skeletons.Parent.Children.Remove($script:Skeletons) }
    $script:SectionBody.Visibility = 'Visible'
    Start-AkariPageEntrance @($script:SectionBody.Children)
}

# the search results page: every match, grouped by Section › Category, each name with the match highlighted; no match =
# an empty state with examples
function Show-AkariSearchResults([string]$Query) {
    $script:CatShown = ''
    Set-AkariHeader @("Results for `"$Query`"")
    $list = @(Find-AkariCatalogueList (Get-AkariCatalogueOf $script:Tweaks) $AkariCatalogueSearch $Query)
    if (-not $list.Count) {
        [void]$Rows.Children.Add((New-AkariEmpty 'search' "No Tweaks match `"$Query`"" 'Try another word, like "Defender", "DNS" or "Game Bar".'))
        Update-AkariCatalogueBars
        return
    }
    [void]$Rows.Children.Add((New-AkariLead "$($list.Count) Tweak$(if ($list.Count -ne 1) { 's' })"))
    $last = ''
    foreach ($t in $list) {
        if ("$($t.Section)/$($t.Category)" -ne $last) {
            $last = "$($t.Section)/$($t.Category)"
            $hs = if ($AkariCatalogueHeaders.ContainsKey($t.Section)) { $AkariCatalogueHeaders[$t.Section] } else { $t.Section }
            [void]$Rows.Children.Add((New-AkariSection "$hs $([char]0x203A) $($t.Category)" -First:($Rows.Children.Count -eq 1)))
        }
        $e = Get-AkariCatalogueCard $t
        Set-AkariCardHighlight $e $Query
        Add-AkariCard $Rows $e
        Set-AkariCatalogueCard $e
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
    if ($States.Count) { Show-AkariSectionBody }
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
        # the prototype's: "Restart and apply" now, Later (it waits in the Safe Mode bar), or Cancel
        if ($Mode -eq 'Apply' -and -not $script:SafePending.ContainsKey($Id)) {
            $r = Show-AkariDialog ([string]$t.Description) "$($t.Name)?" @('Cancel', 'Later', 'Restart and apply') 'Question'
            if ($r -notin 'Later', 'Restart and apply') { Set-AkariCatalogueCard $e; return }
            Set-AkariSafePending $script:SafePending $t $e.State $Mode $Value $e.Current
            Set-AkariCatalogueCard $e
            Update-AkariCatalogueBars
            if ($r -eq 'Restart and apply') { Start-AkariCatalogueSafeRun }
            else { Show-AkariToast 'Waiting for Safe Mode' "`"$($t.Name)`" applies the next time Akari restarts into Safe Mode." }
            return
        }
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
    # a service or a task (the Services and Scheduled tasks lists): UI\ServicesPage.ps1, UI\TasksPage.ps1
    if ($it.Kind -eq 'Service') { Start-AkariServiceJob $it; return }
    if ($it.Kind -eq 'Task') { Start-AkariTaskJob $it; return }
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
                if ($e.Tweak.Kind -eq 'Action') { $e.Done = $true }
                Add-AkariActivity "$(if ($o.Outcome -eq 'Applied') { 'Applied' } else { 'Reverted' }) `"$($e.Tweak.Name)`"" 'Optimize' 1 (Get-AkariCategoryIcon $e.Tweak.Category)
            }
            Set-AkariCatalogueCard $e
        }
        'CatalogueService' { Complete-AkariServiceJob $s }
        'CatalogueTask' { Complete-AkariTaskJob $s }
        'CatalogueExplorer' { $script:CatExplorer.Clear() }
        'CatalogueRun' { Complete-AkariCatalogueSafeRun $s }
    }
    Update-AkariCatalogueBars
}

# ---- the InfoBars at the top of Optimize's pages: Restart required (Restart now, Restart Explorer), changes waiting
# for Safe Mode (Restart into Safe Mode); each opens and closes by animating its height (ADR 0008)

$script:RestartBar = New-AkariInfoBar 'Warn' 'Restart required' '' @(
    (New-AkariBarButton 'Restart Explorer' { Start-AkariCatalogueExplorer }),
    (New-AkariBarButton 'Restart now' { Start-AkariCatalogueRestart }))
$script:RestartBar.Explorer = $script:RestartBar.Actions.Children[0]
$script:RestartBar.Reboot = $script:RestartBar.Actions.Children[1]
$script:SafeBar = New-AkariInfoBar 'Warn' '' 'Akari restarts into Safe Mode, applies them and restarts back.' @(
    (New-AkariBarButton 'Restart into Safe Mode' { Start-AkariCatalogueSafeRun }))
$script:SafeBar.Apply = $script:SafeBar.Actions.Children[0]
# the Safe Mode bar's icon is power, not the warning sign
Set-AkariIcon $script:SafeBar.Bar.Child.Children[0] 'power'
foreach ($b in $script:RestartBar.Bar, $script:SafeBar.Bar) { $b.Visibility = 'Collapsed'; [void]$CatBars.Children.Add($b) }

# shows the bars that have something to say (on Optimize's pages only)
function Update-AkariCatalogueBars {
    $on = ($script:Cat -like "$AkariCataloguePrefix*" -or $script:Cat -eq 'Optimize')
    $n = $script:SafePending.Count
    $script:SafeBar.Title.Text = "$n change$(if ($n -ne 1) { 's wait' } else { ' waits' }) for Safe Mode"
    if ($on -and $n) { Show-AkariInfoBar $script:SafeBar.Bar } else { Hide-AkariInfoBar $script:SafeBar.Bar }
    $lines = @(Get-AkariRestartBarText $script:CatExplorer.Count $script:CatReboot.Count)
    $script:RestartBar.Text.Text = $lines -join ' '
    if ($on -and $lines.Count) { Show-AkariInfoBar $script:RestartBar.Bar } else { Hide-AkariInfoBar $script:RestartBar.Bar }
    $script:RestartBar.Explorer.Visibility = if ($script:CatExplorer.Count) { 'Visible' } else { 'Collapsed' }
    $script:RestartBar.Reboot.Visibility = if ($script:CatReboot.Count) { 'Visible' } else { 'Collapsed' }
    $CatBars.Visibility = 'Visible'
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
    Update-AkariCatalogueBars
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
