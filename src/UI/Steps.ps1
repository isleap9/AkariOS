# Steps: the Install AkariOS page. It opens on a chooser: One-click (the old Akari-OS run, M4) or Guided.
# Guided = Apps -> Tweaks -> Review & Apply (docs\PLAN.md §4). Nothing changes while choosing:
# cards write into the Selection, Review lists it, Apply runs it once and shows the Outcomes (step 3, after Review).
# Also the Optimize chooser (Legacy / Advanced) and the Legacy page list, which share the full-window footer.
# Needs UI\Selection.ps1 and UI\Cards.ps1. Initialize-AkariSteps wires the window elements (called by UI\Shell.ps1).

$AkariSectionOrder = 'Optimize', 'Customize', 'Hardware', 'Advanced'
$AkariSectionHeaders = @{ Hardware = 'Graphics & Hardware' }
$AkariStepNames = 'Apps', 'Tweaks', 'Review & Apply'
# page title and subtitle per step (the last one is the result screen)
$AkariStepHeaders = @(
    , @('Apps', 'Pick the apps to remove and the apps to install')
    , @('Tweaks', 'Pick what to change. Hover a row for details.')
    , @('Review & Apply', 'These changes run in one go, after an AkariOS restore point')
    , @('Done', 'What happened to each change')
)
# 'Choose' (One-click or Guided) or 'Guided' (the steps)
$script:Mode = 'Choose'
$script:Step = 0
$script:Sel = New-AkariSelection
# Tweaks grid: one row entry per Tweak id, the category cards (@{ Card; Size }), the columns in use
$script:TweakRows = [ordered]@{}
$script:TweakCards = @()
# the Sections of the grid: @{ Section; Header; Heading; Grid }
$script:TweakSections = @()
$script:GridCols = 0
$script:TweaksView = $null
# "Show current state": rows start on the State read from this PC (Win11Debloat's "Show currently applied tweaks")
$script:UseState = $true
$script:Outcomes = @()
# a restore point is made once per GUI session; the user may also choose to go on without one
$script:RestoreDone = $false

# Sections and Categories shown in the Tweaks step: one-file Toggles, Choices and Actions whose Requires this PC meets
# (Core\System.ps1), plus legacy Toggles not yet ported ($Ported: Tweaks\Ported.psd1; legacy Actions and Groups stay
# on Optimize > Legacy). Pure, no WPF.
function Get-AkariStepGroups($Tweaks, [hashtable]$Ported = @{}) {
    if (-not $Ported) { $Ported = @{} }
    # apps (Section Apps: removals and installs) have their own step; Section OneClick is One-click's own steps; Tools
    # and a Tweak with Guided = $false are the Catalogue's only (Optimize › Advanced, ADR 0005)
    $list = @($Tweaks | Where-Object { $_.Section -notin 'Apps', 'OneClick', 'Tools' -and $_.Guided -ne $false -and -not $_.Group -and (($_.Legacy -and $_.Kind -eq 'Toggle' -and -not $Ported.ContainsKey($_.Id)) -or
        (-not $_.Legacy -and $_.Kind -in 'Toggle', 'Choice', 'Action' -and (-not $_.Requires -or -not (Test-AkariRequirement $_)))) })
    $sections = @($list | ForEach-Object { $_.Section } | Select-Object -Unique)
    $ordered = @($AkariSectionOrder | Where-Object { $_ -in $sections }) + @($sections | Where-Object { $_ -notin $AkariSectionOrder } | Sort-Object)
    foreach ($s in $ordered) {
        $inSec = @($list | Where-Object { $_.Section -eq $s })
        $cats = @($inSec | ForEach-Object { if ($_.Category) { $_.Category } else { 'Not yet ported' } } | Select-Object -Unique)
        $cats = @($cats | Where-Object { $_ -ne 'Not yet ported' } | Sort-Object) + @($cats | Where-Object { $_ -eq 'Not yet ported' })
        $header = if ($AkariSectionHeaders.ContainsKey($s)) { $AkariSectionHeaders[$s] } else { $s }
        [pscustomobject]@{
            Section    = $s
            Header     = $header
            Categories = @(foreach ($c in $cats) {
                $want = if ($c -eq 'Not yet ported') { '' } else { $c }
                [pscustomobject]@{ Name = $c; Ids = @($inSec | Where-Object { "$($_.Category)" -eq $want } | ForEach-Object { $_.Id }) }
            })
        }
    }
}

# the steps of each flow: Guided = Apps, Tweaks, Review & Apply; Downloads (Home tile) = the Install cards, Review & Apply;
# Remove apps (the Catalogue sidebar) = the Remove tables, Review & Apply. Step 3 is the result screen of each.
$AkariFlows = @{ Guided = @(0, 1, 2); Downloads = @(0, 2); 'Remove apps' = @(0, 2) }
# the apps flows: one Apps tab alone (no tab buttons), their own headers, and an exit page ($script:FlowExit)
$AkariAppFlows = @{
    Downloads     = @{ Tab = 'Install'; Head = @('Downloads', 'Pick the apps to install, from winget where possible'); Review = @('Review & Install', 'These apps install in one go') }
    'Remove apps' = @{ Tab = 'Remove'; Head = @('Remove apps', 'Store apps, optional features, Windows features and legacy apps to remove'); Review = @('Review & Remove', 'These apps and features are removed in one go') }
}

# the step before (-1) or after (+1) $Step in $Mode's flow, or $null at either end. Pure.
function Get-AkariFlowStep([string]$Mode, [int]$Step, [int]$Dir) {
    $f = @($AkariFlows[$Mode])
    $i = [array]::IndexOf($f, $Step) + $Dir
    if ($i -lt 0 -or $i -ge $f.Count) { return $null }
    $f[$i]
}

# Optimize › Legacy: the sidebar pages, in order (Downloads takes the old Installers slot). The Shell puts
# '← Optimize' (back to the chooser) above them.
$AkariLegacyPages = 'Check', 'Refresh', 'Setup', 'Downloads', 'Graphics', 'Windows', 'Hardware', 'Advanced'
# where an apps flow's Back (first step) and Done lead: the Legacy or Catalogue page it was opened from, else Home
$script:FlowExit = 'Home'

# the Shell is opening an apps flow from page $From
function Set-AkariFlowExit([string]$From) {
    $script:FlowExit = if (($From -in $AkariLegacyPages -and $From -ne 'Downloads') -or $From -like 'Catalogue:*') { $From } else { 'Home' }
}

# the rows of a Legacy page: legacy tweaks only (ADR 0004), those of page $Page, or every match of $Query. Pure.
function Get-AkariLegacyList($Tweaks, [string]$Page, [string]$Query) {
    $legacy = @($Tweaks | Where-Object { $_.Legacy })
    if ($Query) { return @($legacy | Where-Object { "$($_.Name) $($_.Description)" -like "*$Query*" }) }
    @($legacy | Where-Object { $_.Section -eq $Page })
}

function Step-AkariBack {
    # the choosers' Back goes Home, Back on an apps flow's first step to where it was opened (no sidebar here)
    if ($script:Cat -in 'Optimize', 'About', 'Install USB' -or $script:Mode -eq 'Choose') { Select-AkariPage 'Home'; return }
    $prev = Get-AkariFlowStep $script:Mode $script:Step -1
    if ($null -ne $prev) { $script:Step = $prev }
    elseif ($AkariAppFlows.Contains($script:Mode)) { Select-AkariPage $script:FlowExit; return }
    else { $script:Mode = 'Choose' }
    Show-AkariSteps
}

function Step-AkariForward {
    switch ($script:Step) {
        2 { Start-AkariApply }
        3 { Reset-AkariSteps }
        default { $script:Step = Get-AkariFlowStep $script:Mode $script:Step 1; Show-AkariSteps }
    }
}

function Initialize-AkariSteps {
    $StepBack.Add_Click({ Step-AkariBack })
    $StepNext.Add_Click({ Step-AkariForward })
}

# the Shell opened Install AkariOS or an apps flow: switching from one flow to another starts it afresh
function Enter-AkariFlow([string]$Page) {
    if ($AkariAppFlows.Contains($Page) -and $script:Mode -ne $Page) { Clear-AkariSteps; $script:Mode = $Page; $script:Step = 0 }
    elseif ($Page -eq 'Install AkariOS' -and $AkariAppFlows.Contains($script:Mode)) { Clear-AkariSteps; $script:Mode = 'Choose'; $script:Step = 0 }
}

function New-AkariText([string]$Text, [double]$Size = 13, [string]$Brush = 'Tx') {
    $t = [Windows.Controls.TextBlock]::new()
    $t.Text = $Text
    $t.FontSize = $Size
    $t.TextWrapping = 'Wrap'
    $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $Brush)
    $t
}

# reads every State now (on the UI thread; see the M2a plan, Review Focus 6)
function New-AkariRowEntry($t) {
    $state = Get-AkariState $t
    $cur = $null
    if ($t.Kind -eq 'Choice') { try { $cur = Get-AkariChoiceValue $t } catch { } }
    $e = New-AkariTweakRow $t $state $cur
    switch ($t.Kind) {
        'Choice' {
            $e.Control.Add_SelectionChanged({
                param($s, $a)
                if ($s.SelectedItem) { Set-AkariChoiceTarget ([string]$s.Tag) $(if ($s.SelectedIndex -eq 0) { 'None' } else { $s.SelectedItem.Tag }) }
            })
            $e.Control.Add_LostKeyboardFocus({
                param($s, $a)
                if ($s.IsKeyboardFocusWithin) { return }
                $x = $script:TweakRows[[string]$s.Tag]
                $v = Get-AkariComboValue $x
                if ($null -eq $v) { Set-AkariRowControl $x $x.Shown } else { Set-AkariChoiceTarget ([string]$s.Tag) $v }
            })
        }
        default { $e.Control.Add_Click({ param($s, $a) Step-AkariCheck ([string]$s.Tag) }) }
    }
    $e
}

# puts every row back where it starts (per "Show current state") and drops their changes from the Selection
# (only the Tweak rows': the apps picked in the Apps step stay)
function Reset-AkariTweakRows {
    foreach ($e in $script:TweakRows.Values) {
        $e.Initial = Get-AkariRowStart $e $script:UseState
        $e.Shown = $e.Initial
        Set-AkariRowControl $e $e.Initial
        if ($script:Sel.Contains($e.Tweak.Id)) { $script:Sel.Remove($e.Tweak.Id) }
    }
    # the changes a preset brought for Tweaks with no row here go too
    foreach ($id in @($script:Sel.Keys)) { if ($script:Sel[$id].Hidden) { $script:Sel.Remove($id) } }
    Update-AkariStepFooter
}

# a checkbox was clicked: checked = Apply (after a confirmation when one is needed), unchecked = Revert or no change
function Step-AkariCheck([string]$Id) {
    $e = $script:TweakRows[$Id]
    if ($e.Muted) { return }
    $t = $e.Tweak
    $next = Get-AkariCheckTarget ([bool]$e.Control.IsChecked) $e.Initial
    $q = Get-AkariConfirmText $t $next
    if ($q -and -not (Confirm-AkariDialog $q 'Continue')) {
        Set-AkariRowControl $e $(if ($e.Control.IsChecked) { 'None' } else { 'Optimized' })
        return
    }
    Set-AkariPending $script:Sel $t $e.State $next
    Update-AkariStepFooter
}

# a Choice row picked $Value ('None' = No change)
function Set-AkariChoiceTarget([string]$Id, $Value) {
    $e = $script:TweakRows[$Id]
    if ($e.Muted) { return }
    if ("$Value" -eq 'None') { $same = ("$($e.Shown)" -eq 'None') } else { $same = ("$($e.Shown)" -ne 'None') -and (Test-AkariRegMatch $Value $e.Shown) }
    if ($same) { return }
    $q = if ("$Value" -eq 'None') { $null } else { Get-AkariConfirmText $e.Tweak $Value }
    if ($q -and -not (Confirm-AkariDialog $q 'Continue')) { Set-AkariRowControl $e $e.Shown; return }
    $e.Shown = $Value
    Set-AkariPending $script:Sel $e.Tweak $e.State $Value $e.Current
    Update-AkariStepFooter
}

# ---- Quick select (Core\Presets.ps1): a preset replaces the whole Selection, Apps and Tweaks alike

# the presets the menu lists: built-in (Presets\), Last used, the user's own
function Get-AkariQuickSelectList {
    $all = @(Get-AkariPresets "$Root\Presets")
    @($all | Where-Object { $_.Builtin }) + @(Get-AkariLastUsed | Where-Object { $_ }) + @($all | Where-Object { -not $_.Builtin })
}

# puts the Selection on $Preset: every row back where it starts, then the preset's changes checked. Both views are
# built first (they read every State and app once). Wildcards (appx/*, ...) are remembered for the features read later.
function Set-AkariQuickSelect($Preset) {
    [void](Get-AkariAppsView)
    [void](Get-AkariTweaksView)
    $known = @($script:Tweaks) + @($script:AppRows.Values | ForEach-Object { $_.Tweak })
    $plan = Resolve-AkariPreset $Preset $known
    Reset-AkariTweakRows
    foreach ($e in @($script:AppRows.Values)) { Set-AkariAppChecked $e $false }
    $script:Sel = New-AkariSelection
    $byId = @{}; foreach ($i in $plan.Items) { $byId[$i.Id] = $i }
    $wild = @($Preset.Entries | Where-Object { $_.Id -like '*/[*]' } | ForEach-Object { $_.Id.Substring(0, $_.Id.Length - 2) })
    Select-AkariApps ({ param($t) ($t.Group -and $t.Group -in $wild -and -not $t.Keep) -or $byId.ContainsKey($t.Id) }.GetNewClosure())
    foreach ($e in @($script:AppRows.Values | Where-Object { -not (Test-AkariRemoveRow $_) -and $byId.ContainsKey($_.Tweak.Id) })) { Set-AkariAppChecked $e $true }
    $missing = 0
    foreach ($i in $plan.Items) {
        $e = $script:TweakRows[$i.Id]
        if (-not $e) {
            if ($script:AppRows.Contains($i.Id)) { continue }
            # a Toggle or Choice Guided doesn't show (Optimize › Advanced only): selected all the same, listed apart
            # on Review (never an Action, nor One-click's own steps)
            $t = $script:Tweaks | Where-Object { $_.Id -eq $i.Id } | Select-Object -First 1
            if ($t -and @(Get-AkariExportTweaks @($t)).Count) { Set-AkariHiddenPending $t $i } else { $missing++ }
            continue
        }
        $t = $e.Tweak
        $target = if ($i.Mode -eq 'Revert') { 'Default' } elseif ($t.Kind -eq 'Choice') { if ($i.ContainsKey('Value')) { $i.Value } else { $t.Recommended } } else { 'Optimized' }
        Set-AkariRowControl $e $(if ($target -eq 'Default' -and $t.Kind -ne 'Choice') { 'None' } elseif ($target -eq 'Default') { Resolve-AkariDefault $t.Default } else { $target })
        if ($t.Kind -eq 'Choice') { $e.Shown = $(if ($target -eq 'Default') { Resolve-AkariDefault $t.Default } else { $target }) }
        Set-AkariPending $script:Sel $t $e.State $(if ($target -eq 'Default' -and $t.Kind -eq 'Choice') { Resolve-AkariDefault $t.Default } else { $target }) $e.Current
    }
    Update-AkariAppsStatus
    Update-AkariStepFooter
    $note = if ($missing -or $plan.Unknown.Count) { " ($($missing + $plan.Unknown.Count) not on this PC or not shown here)" } else { '' }
    Add-Log "Quick select: $($Preset.Name), $($script:Sel.Count) changes$note"
}

# a preset's change to a Tweak with no row on the Tweaks step: its State read now, the change marked Hidden
function Set-AkariHiddenPending($Tweak, $Item) {
    $cur = $null
    if ($Tweak.Kind -eq 'Choice') { try { $cur = Get-AkariChoiceValue $Tweak } catch { } }
    $def = Resolve-AkariDefault $Tweak.Default
    $target = if ($Item.Mode -eq 'Revert') { if ($Tweak.Kind -eq 'Choice') { $def } else { 'Default' } }
              elseif ($Tweak.Kind -eq 'Choice') { if ($Item.ContainsKey('Value')) { $Item.Value } else { $Tweak.Recommended } }
              else { 'Optimized' }
    Set-AkariPending $script:Sel $Tweak (Get-AkariState $Tweak) $target $cur
    if ($script:Sel.Contains($Tweak.Id)) { $script:Sel[$Tweak.Id].Hidden = $true }
}

# saves the current Selection as a user preset (asks for its name)
function Save-AkariQuickSelect {
    if (-not $script:Sel.Count) { Show-AkariMessage 'Pick some changes first, then save them as a preset.'; return }
    $name = Read-AkariText 'A name for this preset:' 'Save' 'Save as preset'
    if (-not $name) { return }
    $path = Save-AkariPreset $name @(Get-AkariPlanItems $script:Sel) 'Saved from Install AkariOS'
    Add-Log "Preset saved: $path"
}

# the Quick select button: a menu of presets, built each time it opens (a preset saved just now is listed)
function New-AkariQuickSelect {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $b.Content = 'Quick select ' + [char]0x25BE
    $b.ToolTip = 'Pick a preset: it replaces every pick on the Apps and Tweaks steps'
    $b.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $b.ContextMenu = [Windows.Controls.ContextMenu]::new()
    $b.Add_Click({
        param($s, $a)
        $m = $s.ContextMenu
        $m.Items.Clear()
        foreach ($p in @(Get-AkariQuickSelectList)) {
            $it = [Windows.Controls.MenuItem]::new()
            $it.Header = $(if ($p.Builtin -and $p.Name -eq 'AkariOS') { 'AkariOS (recommended)' } else { $p.Name })
            $it.ToolTip = $p.Description
            $it.Tag = $p
            $it.Add_Click({ param($x, $y) Set-AkariQuickSelect $x.Tag })
            [void]$m.Items.Add($it)
        }
        [void]$m.Items.Add([Windows.Controls.Separator]::new())
        $save = [Windows.Controls.MenuItem]::new()
        $save.Header = 'Save current as preset' + [char]0x2026
        $save.Add_Click({ Save-AkariQuickSelect })
        [void]$m.Items.Add($save)
        $m.PlacementTarget = $s
        $m.Placement = 'Bottom'
        $m.IsOpen = $true
    })
    $b
}

# the toolbar above the grid: Quick select (Presets), Clear selection, Show current state
function New-AkariTweaksToolbar {
    $bar = [Windows.Controls.StackPanel]::new()
    $bar.Orientation = 'Horizontal'
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $quick = New-AkariQuickSelect
    $quick.Margin = [Windows.Thickness]::new(0)
    $clear = [Windows.Controls.Button]::new()
    $clear.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $clear.Content = 'Clear selection'
    $clear.ToolTip = 'Undo every pick on this page'
    $clear.Margin = [Windows.Thickness]::new(8, 0, 16, 0)
    $clear.Add_Click({ Reset-AkariTweakRows })
    $show = [Windows.Controls.CheckBox]::new()
    $show.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $show.Content = 'Show current state'
    $show.ToolTip = 'Check the Tweaks already applied on this PC. Unchecking one of them reverts it.'
    $show.IsChecked = $script:UseState
    $show.VerticalAlignment = 'Center'
    $show.Add_Click({ param($s, $a) $script:UseState = [bool]$s.IsChecked; Reset-AkariTweakRows })
    foreach ($x in $quick, $clear, $show) { [void]$bar.Children.Add($x) }
    $bar
}

# places each Section's category cards in $Cols columns (masonry); called again when the width crosses the threshold
function Set-AkariTweaksColumns([int]$Cols) {
    if ($Cols -eq $script:GridCols) { return }
    $script:GridCols = $Cols
    foreach ($sec in $script:TweakSections) {
        $grid = $sec.Grid
        $cards = @($script:TweakCards | Where-Object { $_.Section -eq $sec.Section })
        foreach ($p in @($grid.Children)) { $p.Children.Clear() }
        $grid.Children.Clear(); $grid.ColumnDefinitions.Clear()
        $panels = for ($i = 0; $i -lt $Cols; $i++) {
            [void]$grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
            $p = [Windows.Controls.StackPanel]::new()
            $p.Margin = [Windows.Thickness]::new($(if ($i) { 6 } else { 0 }), 0, $(if ($i -lt $Cols - 1) { 6 } else { 0 }), 0)
            [Windows.Controls.Grid]::SetColumn($p, $i)
            [void]$grid.Children.Add($p)
            $p
        }
        $at = @(Get-AkariMasonry @($cards | ForEach-Object { $_.Size }) $Cols)
        for ($i = 0; $i -lt $cards.Count; $i++) { [void]@($panels)[$at[$i]].Children.Add($cards[$i].Card) }
    }
}

# builds the Tweaks view once, after Win11Debloat's System Tweaks: toolbar, then per Section a heading and a grid of
# category cards
function Get-AkariTweaksView {
    if ($script:TweaksView) { return $script:TweaksView }
    $script:TweakCards = @()
    $script:TweakSections = @()
    foreach ($g in Get-AkariStepGroups $script:Tweaks $script:Ported) {
        $script:TweakSections += @{ Section = $g.Section; Header = $g.Header }
        foreach ($c in $g.Categories) {
            # one-file tweaks: a card per Category; legacy tweaks: a card per old page, marked "Not yet ported"
            $legacy = ($c.Name -eq 'Not yet ported')
            $title = if ($legacy) { $g.Section } else { $c.Name }
            $cc = New-AkariCategoryCard $title (Get-AkariCategoryIcon $title) $(if ($legacy) { 'Not yet ported' } else { '' })
            $size = 0
            foreach ($id in $c.Ids) {
                $t = $script:Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                $e = New-AkariRowEntry $t
                $e.Card = $cc.Card
                $script:TweakRows[$id] = $e
                # a dashed rule between rows (it hides with its row)
                if ($cc.Panel.Children.Count -gt 1) { [void]$cc.Panel.Children.Add((New-AkariRule $e.Row)) }
                [void]$cc.Panel.Children.Add($e.Row)
                $size += $(if ($t.Kind -eq 'Choice') { 2 } else { 1 })
            }
            $cc.Count.Text = "$(@($c.Ids).Count)"
            $script:TweakCards += @{ Card = $cc.Card; Size = $size; Section = $g.Section }
        }
    }
    $view = [Windows.Controls.StackPanel]::new()
    [void]$view.Children.Add((New-AkariTweaksToolbar))
    foreach ($sec in $script:TweakSections) {
        $sec.Heading = New-AkariText $sec.Header 20
        $sec.Heading.FontWeight = 'SemiBold'
        Set-AkariFont $sec.Heading 'Display'
        $sec.Heading.Margin = [Windows.Thickness]::new(2, $(if ($sec -eq $script:TweakSections[0]) { 0 } else { 12 }), 0, 10)
        $sec.Grid = [Windows.Controls.Grid]::new()
        [void]$view.Children.Add($sec.Heading)
        [void]$view.Children.Add($sec.Grid)
    }
    $script:GridCols = 0
    Set-AkariTweaksColumns 3
    # three columns from 900 px, two below (Win11Debloat folds its third column the same way)
    $view.Add_SizeChanged({ param($s, $a) Set-AkariTweaksColumns $(if ($a.NewSize.Width -ge 900) { 3 } else { 2 }) })
    $script:TweaksView = $view
    Reset-AkariTweakRows
    $view
}

# header search on the Tweaks step: hide rows that don't match, then cards left empty
function Set-AkariTweaksFilter([string]$q) {
    if (-not $script:TweaksView) { return }
    foreach ($e in $script:TweakRows.Values) {
        $hit = (-not $q) -or ("$($e.Tweak.Name) $($e.Tweak.Description)" -like "*$q*")
        $e.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
    }
    foreach ($c in $script:TweakCards) {
        $any = @($c.Card.Child.Children | Select-Object -Skip 1 | Where-Object { $_.Visibility -eq 'Visible' }).Count -gt 0
        $c.Card.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    }
    # a Section with no card left loses its heading too
    foreach ($sec in $script:TweakSections) {
        $any = @($script:TweakCards | Where-Object { $_.Section -eq $sec.Section -and $_.Card.Visibility -eq 'Visible' }).Count -gt 0
        $sec.Heading.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    }
}

function Update-AkariStepFooter {
    $n = $script:Sel.Count
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Visible'
    switch ($script:Step) {
        0 {
            if ($AkariAppFlows.Contains($script:Mode)) { $StepNext.Content = "Review ($n)"; $StepNext.IsEnabled = ($n -gt 0) }
            else { $StepNext.Content = 'Next'; $StepNext.IsEnabled = $true }
        }
        1 { $StepNext.Content = "Review ($n)"; $StepNext.IsEnabled = ($n -gt 0) }
        2 { $StepNext.Content = 'Apply'; $StepNext.IsEnabled = ($n -gt 0) }
        3 { $StepNext.Content = 'Done'; $StepNext.IsEnabled = $true; $StepBack.Visibility = 'Hidden' }
    }
}

# the two ways to install: big cards, like Win11Debloat's start screen
# a poster card (the design system's): icon blob, Unbounded title, muted text. -Hot: the recommended one, crimson
# border and glow (style ModeCardHot)
function New-AkariModeCard([string]$Icon, [string]$Title, [string]$Text, [bool]$Enabled, [switch]$Hot) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $(if ($Hot) { 'ModeCardHot' } else { 'ModeCard' }))
    $b.IsEnabled = $Enabled
    $sp = [Windows.Controls.StackPanel]::new()
    $ic = New-AkariBlob $Icon 48
    $ic.HorizontalAlignment = 'Left'
    $ic.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $tt = New-AkariText $Title 20
    $tt.FontWeight = 'SemiBold'
    Set-AkariFont $tt 'Display'
    $tx = New-AkariText $Text 14 'Mu'
    $tx.Margin = [Windows.Thickness]::new(0, 8, 0, 0)
    foreach ($x in $ic, $tt, $tx) { [void]$sp.Children.Add($x) }
    $b.Content = $sp
    $b
}

# One-click: the AkariOS preset's Run (Presets\AkariOS.json: preparation, Safe Mode, then the debloat and tweaks, with
# restarts in between: Core\Phases.ps1), in Akari's own console: the window closes and Akari.ps1 starts the Run there
# after ShowDialog returns (no new window).
function Confirm-AkariOneClick {
    $q = "AkariOS One-click changes a lot of Windows, including security features.`n`n" +
         "- Run it on a fresh install or a PC you can reinstall. There is no uninstaller.`n" +
         "- Security is reduced on purpose (Defender settings, UAC, memory integrity).`n" +
         "- Your PC restarts several times, once into Safe Mode. Save your work and don't interrupt it.`n" +
         "- Graphics and audio drivers are removed. Install a fresh graphics driver afterwards.`n" +
         "- It is tuned for desktops: power saving is turned off.`n" +
         "- It needs an internet connection.`n`nStart AkariOS One-click now?"
    Confirm-AkariDialog $q 'Start One-click' 'Cancel' 'Warning' 'AkariOS One-click'
}

function Start-AkariOneClick {
    $path = "$Root\Presets\AkariOS.json"
    if (-not (Test-Path $path)) { Show-AkariMessage "Missing: $path" 'Error'; return }
    if ($script:Busy -or -not (Confirm-AkariOneClick)) { return }
    # asked here, in the window; Akari.ps1 makes it in the console before phase 1
    $script:OneClickRestore = Get-AkariRestoreChoice 'OneClick'
    Write-ErrLog "One-click started: $path"
    $script:OneClickPath = $path
    $window.Close()
}

# the page header shows the step, like Win11Debloat's page titles ($Heading / $HeaderSub come from UI\Shell.ps1)
function Set-AkariStepHeader([string]$Title, [string]$Sub) {
    if ($Heading) { $Heading.Text = $Title }
    if ($HeaderSub) { $HeaderSub.Text = $Sub }
}

function Show-AkariChooser {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'Install AkariOS' 'Optimize Windows in one click, or pick each change yourself'
    # footer: only Back (to Home)
    if ($StepFooter) { $StepFooter.Visibility = 'Visible' }
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $g = [Windows.Controls.Primitives.UniformGrid]::new()
    $g.Columns = 2
    $one = New-AkariModeCard -Hot 'zap' 'One-click' 'The full AkariOS setup in one go: apps, drivers, Safe Mode and tweaks, with restarts handled for you. For a fresh install.' $true
    $one.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $one.Add_Click({ Start-AkariOneClick })
    $guided = New-AkariModeCard 'list-checks' 'Guided' 'Pick the apps to remove and the Tweaks to apply, review the changes, then apply them in one go.' $true
    $guided.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $guided.Add_Click({ $script:Mode = 'Guided'; $script:Step = 0; Show-AkariSteps })
    [void]$g.Children.Add($one); [void]$g.Children.Add($guided)
    $StepBody.Children.Clear()
    [void]$StepBody.Children.Add($g)
}

# Optimize (Manual mode): Legacy, the frozen AkariOS-Ultimate pages (ADR 0004), or Advanced (designed later).
# Laid out like the Install AkariOS chooser; Back goes Home (Step-AkariBack).
function Show-AkariOptimizeChooser {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'Optimize' 'Manual, in-depth optimization for Windows'
    if ($StepFooter) { $StepFooter.Visibility = 'Visible' }
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $g = [Windows.Controls.Primitives.UniformGrid]::new()
    $g.Columns = 2
    # Advanced: the Catalogue (ADR 0005), every one-file Tweak by Section › Category, each change acting right away
    $first = @(Get-AkariCataloguePages $script:Tweaks | ForEach-Object { $_.Pages }) | Select-Object -First 1
    $adv = New-AkariModeCard -Hot 'sliders-horizontal' 'Advanced' 'Every tweak AkariOS has, by category. Each change applies right away. More tweaks are on the way.' ([bool]$first)
    $adv.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    if ($first) { $adv.Tag = $first.Key; $adv.Add_Click({ param($s, $e) Select-AkariPage ([string]$s.Tag) }) }
    $legacy = New-AkariModeCard 'history' 'Legacy' 'The old AkariOS-Ultimate pages, being retired as Advanced takes them over. Every button acts right away.' $true
    $legacy.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $legacy.Add_Click({ Select-AkariPage $AkariLegacyPages[0] })
    [void]$g.Children.Add($adv); [void]$g.Children.Add($legacy)
    $StepBody.Children.Clear()
    [void]$StepBody.Children.Add($g)
}

function Show-AkariSteps {
    # the Tweaks view is cached: detach it before the body is cleared, so it can be added again
    if ($script:TweaksView -and $script:TweaksView.Parent) { $script:TweaksView.Parent.Children.Remove($script:TweaksView) }
    if ($script:AppsView -and $script:AppsView.Parent) { $script:AppsView.Parent.Children.Remove($script:AppsView) }
    if ($script:Mode -eq 'Choose') { Show-AkariChooser; return }
    if ($StepFooter) { $StepFooter.Visibility = 'Visible' }
    # step dots, centred in the footer between Back and Next; each names its step
    $StepDots.Children.Clear()
    # an apps flow (Downloads, Remove apps): one Apps tab alone, with its own headers
    $flow = $AkariAppFlows[$script:Mode]
    foreach ($i in $AkariFlows[$(if ($flow) { $script:Mode } else { 'Guided' })]) {
        $d = [Windows.Shapes.Ellipse]::new()
        $d.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'StepDot')
        $d.ToolTip = if ($flow -and $i -eq 0) { $script:Mode } else { $AkariStepNames[$i] }
        if ($i -eq [math]::Min($script:Step, 2)) { $d.Tag = 'Current' }
        [void]$StepDots.Children.Add($d)
    }
    $h = if ($flow -and $script:Step -eq 0) { $flow.Head }
         elseif ($flow -and $script:Step -eq 2) { $flow.Review }
         else { $AkariStepHeaders[$script:Step] }
    Set-AkariStepHeader $h[0] $h[1]
    $StepBody.Children.Clear()
    switch ($script:Step) {
        0 {
            [void]$StepBody.Children.Add((Get-AkariAppsView))
            # an apps flow: its tab alone, no tab buttons; Guided: both tabs
            Set-AkariAppsOnly $(if ($flow) { $flow.Tab } else { '' })
            Set-AkariAppsFilter $Search.Text.Trim()
        }
        1 {
            [void]$StepBody.Children.Add((Get-AkariTweaksView))
            Set-AkariTweaksFilter $Search.Text.Trim()
        }
        2 {
            # changes that restart the PC run last (Core\Runner.ps1): say so before Apply
            $note = Get-AkariRestartNote $script:Sel $script:Tweaks
            if ($note) {
                $n = New-AkariText $note 13 'Warn'
                $n.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
                [void]$StepBody.Children.Add($n)
            }
            # the Guided steps' changes first, then those to Tweaks only Optimize › Advanced shows (a preset's, an import's)
            $review = @(Get-AkariReviewItems $script:Sel)
            $hidden = @($review | Where-Object { $_.Hidden })
            foreach ($r in @($review | Where-Object { -not $_.Hidden }) + $hidden) {
                if ($hidden.Count -and $r -eq $hidden[0]) {
                    $hd = New-AkariText "Advanced settings (Optimize $([char]0x203A) Advanced)" 16
                    $hd.FontWeight = 'SemiBold'
                    Set-AkariFont $hd 'Display'
                    $hd.Margin = [Windows.Thickness]::new(2, 12, 0, 8)
                    [void]$StepBody.Children.Add($hd)
                }
                $change = if ($r.From) { "$($r.From) $([char]0x2192) $($r.To)" } else { $r.To }
                $icon, $brush = if ($r.To -eq 'Default') { 'undo-2', 'Mu' } else { 'arrow-right', 'AccText' }
                [void]$StepBody.Children.Add((New-AkariReviewRow $r.Id $r.Name $change $icon $brush))
            }
        }
        3 { Show-AkariResult }
    }
    Update-AkariStepFooter
}

# ---- Apply: one Run in the background job, restore point first

# counts per Outcome, in Glossary order, and whether a restart is needed. Pure, no WPF.
function Get-AkariRunSummary($Outcomes) {
    $counts = [ordered]@{}
    foreach ($k in 'Applied', 'Reverted', 'Already', 'Skipped', 'Failed') {
        $n = @($Outcomes | Where-Object { $_.Outcome -eq $k }).Count
        if ($n) { $counts[$k] = $n }
    }
    $text = ($counts.Keys | ForEach-Object { "$($counts[$_]) $($_.ToLower())" }) -join ', '
    [pscustomobject]@{ Counts = $counts; Text = $text; Reboot = [bool]($Outcomes | Where-Object { $_.Reboot }) }
}

function Confirm-AkariNoRestore([string]$Message) {
    $q = "Akari could not create a restore point:`n`n$Message`n`nApply the changes without a restore point?"
    Confirm-AkariDialog $q 'Apply anyway' 'Cancel' 'Warning' 'Restore point'
}

# an AkariOS restore point exists already (from an earlier session): make another one?
function Confirm-AkariAnotherRestore($Point) {
    $when = if ($Point.Date) { " on $($Point.Date.ToString('g'))" } else { '' }
    $q = "AkariOS already made a restore point$when.`n`nCreate another restore point before these changes?"
    Confirm-AkariDialog $q 'Create one' 'Skip' 'Question' 'Restore point'
}

# whether the changes about to run get a restore point first. Downloads (app installs only) never; Install AkariOS
# and Optimize once per session; when an AkariOS restore point already exists, the user decides. Either way it is
# not asked again this session ($script:RestoreDone).
function Get-AkariRestoreChoice([string]$Flow) {
    if ($Flow -eq 'Downloads' -or $script:RestoreDone) { return $false }
    $point = try { Get-AkariRestorePoint } catch { $null }
    if ($point -and -not (Confirm-AkariAnotherRestore $point)) { $script:RestoreDone = $true; return $false }
    $true
}

function Start-AkariApply {
    if ($script:Busy -or -not $script:Sel.Count) { return }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{ Plan = @(Get-AkariPlanItems $script:Sel); SkipRestore = -not (Get-AkariRestoreChoice $script:Mode) })
    # the job loads the tweaks itself: a script block must not cross runspaces
    $code = @"
`$root = $(& $q "$Root\Tweaks")
`$loaded = Get-AkariTweaks `$root
`$all = @(`$loaded.Tweaks) + @(Import-AkariLegacyTweaks `$root)
# apps installed on this PC but missing from the data file: build their Entries again here
`$all += @(`$AkariShared.Plan | ForEach-Object { `$i = `$_.Id; if (-not (`$all | Where-Object { `$_.Id -eq `$i })) { Resolve-AkariEntry `$loaded.Groups `$i } } | Where-Object { `$_ })
if (-not `$AkariShared.SkipRestore) {
    `$AkariShared.Restore = New-AkariRestorePoint 'AkariOS'
    if (-not `$AkariShared.Restore.Ok) { return }
}
`$AkariShared.Outcomes = @(Invoke-AkariPlan `$AkariShared.Plan `$all)
"@
    $label = "Applying $($script:Sel.Count) change$(if ($script:Sel.Count -ne 1) { 's' })"
    Set-Busy $true $label
    Add-Log $label
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'Apply'
}

# called by the Shell timer when the Apply job has ended
function Complete-AkariApply($Shared) {
    if ($Shared.Restore -and $Shared.Restore.Ok) { $script:RestoreDone = $true }
    if ($null -eq $Shared.Outcomes) {
        # stopped before any change: the restore point failed (or the job itself failed)
        if ($Shared.Restore -and -not $Shared.Restore.Ok -and (Confirm-AkariNoRestore $Shared.Restore.Message)) {
            $script:RestoreDone = $true
            Start-AkariApply
        }
        return
    }
    $script:Outcomes = @($Shared.Outcomes)
    # Last used (Quick select): what a Guided Run was asked to do (an apps flow's Run would replace it with apps only)
    if ($script:Mode -eq 'Guided') {
        try { Save-AkariLastUsed @($Shared.Plan) } catch { Add-Log "Warning: Last used not saved ($($_.Exception.Message))" }
    }
    $script:Step = 3
}

function Show-AkariResult {
    $sum = Get-AkariRunSummary $script:Outcomes
    $head = New-AkariText $sum.Text 14
    $head.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    [void]$StepBody.Children.Add($head)
    if ($sum.Reboot) {
        $rb = New-AkariText 'Restart Windows to finish.' 14 'Warn'
        $rb.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
        [void]$StepBody.Children.Add($rb)
    }
    foreach ($o in $script:Outcomes) {
        $t = $script:Tweaks | Where-Object { $_.Id -eq $o.Id } | Select-Object -First 1
        $line = if ($o.Message) { "$($o.Outcome): $($o.Message)" } else { $o.Outcome }
        $icon, $brush = switch ($o.Outcome) {
            { $_ -in 'Applied', 'Reverted' } { 'circle-check', 'Ok' }
            'Already' { 'circle-minus', 'Mu' }
            'Skipped' { 'circle-slash', 'Warn' }
            default { 'circle-x', 'Bad' }
        }
        [void]$StepBody.Children.Add((New-AkariReviewRow $o.Id $(if ($t) { $t.Name } else { $o.Id }) $line $icon $brush))
    }
}

# a Review / result row (the design system's ReviewRow): the Tweak's Category blob, its name, then the change
# (From -> To) or the Outcome, and a status icon on the right
function New-AkariReviewRow([string]$Id, [string]$Name, [string]$Line, [string]$Icon, [string]$Brush) {
    $t = $script:Tweaks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    $blob = if (-not $t) { 'settings' } elseif ($t.Section -eq 'Apps') { if ($t.Category -eq 'Install') { 'download' } else { 'trash-2' } } else { Get-AkariCategoryIcon $t.Category }
    $b = [Windows.Controls.Border]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $b.Tag = $Id
    $dp = [Windows.Controls.DockPanel]::new()
    $bl = New-AkariBlob $blob 32
    $bl.Margin = [Windows.Thickness]::new(0, 0, 14, 0)
    [Windows.Controls.DockPanel]::SetDock($bl, 'Left')
    $st = New-AkariIcon $Icon 18 $Brush
    $st.VerticalAlignment = 'Center'
    $st.Margin = [Windows.Thickness]::new(14, 0, 0, 0)
    [Windows.Controls.DockPanel]::SetDock($st, 'Right')
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.VerticalAlignment = 'Center'
    $nm = New-AkariText $Name 14
    $nm.FontWeight = 'SemiBold'
    [void]$sp.Children.Add($nm)
    [void]$sp.Children.Add((New-AkariText $Line 13 $(if ($Brush -eq 'Bad') { 'Bad' } else { 'Mu' })))
    foreach ($x in $bl, $st, $sp) { [void]$dp.Children.Add($x) }
    $b.Child = $dp
    $b
}

# Done: forget the Selection and the cached steps, back to Home (an apps flow: back to where it was opened)
function Reset-AkariSteps {
    # an apps flow goes back to where it was opened (a Legacy or Catalogue page, or Home), Install AkariOS Home
    $exit = if ($AkariAppFlows.Contains($script:Mode)) { $script:FlowExit } else { 'Home' }
    Clear-AkariSteps
    # Install AkariOS opens on its chooser again next time; every State and app is read again then
    $script:Mode = 'Choose'
    $script:Step = 0
    Select-AkariPage $exit
}

# forgets the Selection and the cached views (they are built again, reading every State and app afresh)
function Clear-AkariSteps {
    $script:Sel = New-AkariSelection
    $script:TweakRows = [ordered]@{}
    $script:TweakCards = @()
    $script:TweakSections = @()
    $script:TweaksView = $null
    $script:AppRows = [ordered]@{}
    $script:AppsView = $null
    $script:AppTab = 'Remove'
    $script:Outcomes = @()
}
