# Steps: the Install AkariOS page. It opens on a chooser: One-click (the old Akari-OS run, M4) or Guided.
# Guided = Apps -> Tweaks -> Review & Apply (AkariOS-PLAN.md §4). Nothing changes while choosing:
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
    # apps (Section Apps: removals and installs) have their own step
    $list = @($Tweaks | Where-Object { $_.Section -ne 'Apps' -and -not $_.Group -and (($_.Legacy -and $_.Kind -eq 'Toggle' -and -not $Ported.ContainsKey($_.Id)) -or
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

# the steps of each flow: Guided = Apps, Tweaks, Review & Apply; Downloads (Home tile) = the Install cards, Review & Apply.
# Step 3 is the result screen of both.
$AkariFlows = @{ Guided = @(0, 1, 2); Downloads = @(0, 2) }

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
# where Downloads' Back (first step) and Done lead: the Legacy page it was opened from, else Home
$script:FlowExit = 'Home'

# the Shell is opening Downloads from page $From
function Set-AkariFlowExit([string]$From) {
    $script:FlowExit = if ($From -in $AkariLegacyPages -and $From -ne 'Downloads') { $From } else { 'Home' }
}

# the rows of a Legacy page: legacy tweaks only (ADR 0004), those of page $Page, or every match of $Query. Pure.
function Get-AkariLegacyList($Tweaks, [string]$Page, [string]$Query) {
    $legacy = @($Tweaks | Where-Object { $_.Legacy })
    if ($Query) { return @($legacy | Where-Object { "$($_.Name) $($_.Description)" -like "*$Query*" }) }
    @($legacy | Where-Object { $_.Section -eq $Page })
}

function Step-AkariBack {
    # the choosers' Back goes Home, Back on the first Downloads step to where Downloads was opened (no sidebar here)
    if ($script:Cat -eq 'Optimize' -or $script:Mode -eq 'Choose') { Select-AkariPage 'Home'; return }
    $prev = Get-AkariFlowStep $script:Mode $script:Step -1
    if ($null -ne $prev) { $script:Step = $prev }
    elseif ($script:Mode -eq 'Downloads') { Select-AkariPage $script:FlowExit; return }
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

# the Shell opened Install AkariOS or Downloads: switching from one flow to the other starts it afresh
function Enter-AkariFlow([string]$Page) {
    if ($Page -eq 'Downloads' -and $script:Mode -ne 'Downloads') { Clear-AkariSteps; $script:Mode = 'Downloads'; $script:Step = 0 }
    elseif ($Page -eq 'Install AkariOS' -and $script:Mode -eq 'Downloads') { Clear-AkariSteps; $script:Mode = 'Choose'; $script:Step = 0 }
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
    if ($t.Kind -eq 'Choice') { try { $cur = Get-AkariRegValue $t.Registry[0].Path $t.Registry[0].Name } catch { } }
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
    Update-AkariStepFooter
}

# a checkbox was clicked: checked = Apply (after a confirmation when one is needed), unchecked = Revert or no change
function Step-AkariCheck([string]$Id) {
    $e = $script:TweakRows[$Id]
    if ($e.Muted) { return }
    $t = $e.Tweak
    $next = Get-AkariCheckTarget ([bool]$e.Control.IsChecked) $e.Initial
    $q = Get-AkariConfirmText $t $next
    if ($q -and [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -ne 'Yes') {
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
    if ($q -and [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -ne 'Yes') { Set-AkariRowControl $e $e.Shown; return }
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
        if (-not $e) { if (-not $script:AppRows.Contains($i.Id)) { $missing++ }; continue }
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

# saves the current Selection as a user preset (asks for its name)
function Save-AkariQuickSelect {
    if (-not $script:Sel.Count) { [void][Windows.MessageBox]::Show('Pick some changes first, then save them as a preset.', 'Akari'); return }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('A name for this preset:', 'Akari', '')
    if (-not $name -or -not $name.Trim()) { return }
    $path = Save-AkariPreset $name.Trim() @(Get-AkariPlanItems $script:Sel) 'Saved from Install AkariOS'
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

# places the category cards in $Cols columns (masonry); called again when the width crosses the threshold
function Set-AkariTweaksColumns([int]$Cols) {
    if ($Cols -eq $script:GridCols) { return }
    $script:GridCols = $Cols
    $grid = $script:TweaksGrid
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
    $at = @(Get-AkariMasonry @($script:TweakCards | ForEach-Object { $_.Size }) $Cols)
    for ($i = 0; $i -lt $script:TweakCards.Count; $i++) { [void]@($panels)[$at[$i]].Children.Add($script:TweakCards[$i].Card) }
}

# builds the Tweaks view once, after Win11Debloat's System Tweaks: toolbar, then a grid of category cards
function Get-AkariTweaksView {
    if ($script:TweaksView) { return $script:TweaksView }
    $script:TweakCards = @()
    foreach ($g in Get-AkariStepGroups $script:Tweaks $script:Ported) {
        foreach ($c in $g.Categories) {
            # one-file tweaks: a card per Category; legacy tweaks: a card per old page, marked "Not yet ported"
            $legacy = ($c.Name -eq 'Not yet ported')
            $title = if ($legacy) { $g.Section } else { $c.Name }
            $glyph = if ($AkariCategoryGlyphs.ContainsKey($title)) { $AkariCategoryGlyphs[$title] } else { 0xE713 }
            $cc = New-AkariCategoryCard $title $glyph $(if ($legacy) { 'Not yet ported' } else { '' })
            $size = 0
            foreach ($id in $c.Ids) {
                $t = $script:Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                $e = New-AkariRowEntry $t
                $e.Card = $cc.Card
                $script:TweakRows[$id] = $e
                [void]$cc.Panel.Children.Add($e.Row)
                $size += $(if ($t.Kind -eq 'Choice') { 2 } else { 1 })
            }
            $script:TweakCards += @{ Card = $cc.Card; Size = $size }
        }
    }
    $view = [Windows.Controls.StackPanel]::new()
    [void]$view.Children.Add((New-AkariTweaksToolbar))
    $script:TweaksGrid = [Windows.Controls.Grid]::new()
    [void]$view.Children.Add($script:TweaksGrid)
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
}

function Update-AkariStepFooter {
    $n = $script:Sel.Count
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Visible'
    switch ($script:Step) {
        0 {
            if ($script:Mode -eq 'Downloads') { $StepNext.Content = "Review ($n)"; $StepNext.IsEnabled = ($n -gt 0) }
            else { $StepNext.Content = 'Next'; $StepNext.IsEnabled = $true }
        }
        1 { $StepNext.Content = "Review ($n)"; $StepNext.IsEnabled = ($n -gt 0) }
        2 { $StepNext.Content = 'Apply'; $StepNext.IsEnabled = ($n -gt 0) }
        3 { $StepNext.Content = 'Done'; $StepNext.IsEnabled = $true; $StepBack.Visibility = 'Hidden' }
    }
}

# the two ways to install: big cards, like Win11Debloat's start screen
function New-AkariModeCard([string]$Glyph, [string]$Title, [string]$Text, [bool]$Enabled) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'ModeCard')
    $b.IsEnabled = $Enabled
    $sp = [Windows.Controls.StackPanel]::new()
    $ic = New-AkariText $Glyph 28
    $ic.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'Icons')
    $ic.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $tt = New-AkariText $Title 18
    $tt.FontWeight = 'SemiBold'
    $tx = New-AkariText $Text 13 'Mu'
    $tx.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    foreach ($x in $ic, $tt, $tx) { [void]$sp.Children.Add($x) }
    $b.Content = $sp
    $b
}

# One-click: the Akari-OS run (OneClick\akarios.ps1, then stepone.ps1 in Safe Mode, then steptwo.ps1), started in
# Akari's own console: the window closes and Akari.ps1 runs the script there after ShowDialog returns (no new window).
function Confirm-AkariOneClick {
    $q = "AkariOS One-click changes a lot of Windows, including security features.`n`n" +
         "- Run it on a fresh install or a PC you can reinstall. There is no uninstaller.`n" +
         "- Security is reduced on purpose (Defender settings, UAC, memory integrity).`n" +
         "- Your PC restarts several times, once into Safe Mode. Save your work and don't interrupt it.`n" +
         "- Graphics and audio drivers are removed. Install a fresh graphics driver afterwards.`n" +
         "- It is tuned for desktops: power saving is turned off.`n" +
         "- It needs an internet connection.`n`nStart AkariOS One-click now?"
    [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -eq 'Yes'
}

function Start-AkariOneClick {
    $path = "$Root\OneClick\akarios.ps1"
    if (-not (Test-Path $path)) { [void][Windows.MessageBox]::Show("Missing: $path", 'Akari'); return }
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
    $one = New-AkariModeCard ([string][char]0xE945) 'One-click' 'The full AkariOS setup in one go: apps, drivers, Safe Mode and tweaks, with restarts handled for you. For a fresh install.' $true
    $one.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $one.Add_Click({ Start-AkariOneClick })
    $guided = New-AkariModeCard ([string][char]0xE8FD) 'Guided' 'Pick the apps to remove and the Tweaks to apply, review the changes, then apply them in one go.' $true
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
    $legacy = New-AkariModeCard ([string][char]0xE713) 'Legacy' 'The AkariOS-Ultimate pages. Every button acts right away.' $true
    $legacy.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $legacy.Add_Click({ Select-AkariPage $AkariLegacyPages[0] })
    $adv = New-AkariModeCard ([string][char]0xE9E9) 'Advanced' 'Coming later.' $false
    $adv.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    [void]$g.Children.Add($legacy); [void]$g.Children.Add($adv)
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
    $downloads = ($script:Mode -eq 'Downloads')
    foreach ($i in $AkariFlows[$(if ($downloads) { 'Downloads' } else { 'Guided' })]) {
        $d = [Windows.Shapes.Ellipse]::new()
        $d.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'StepDot')
        $d.ToolTip = if ($downloads -and $i -eq 0) { 'Downloads' } else { $AkariStepNames[$i] }
        if ($i -eq [math]::Min($script:Step, 2)) { $d.Tag = 'Current' }
        [void]$StepDots.Children.Add($d)
    }
    $h = if ($downloads -and $script:Step -eq 0) { @('Downloads', 'Pick the apps to install, from winget where possible') }
         elseif ($downloads -and $script:Step -eq 2) { @('Review & Install', 'These apps install in one go') }
         else { $AkariStepHeaders[$script:Step] }
    Set-AkariStepHeader $h[0] $h[1]
    $StepBody.Children.Clear()
    switch ($script:Step) {
        0 {
            [void]$StepBody.Children.Add((Get-AkariAppsView))
            # Downloads: the Install cards alone, no tabs
            Set-AkariAppsOnlyInstall $downloads
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
            foreach ($r in Get-AkariReviewItems $script:Sel) {
                $b = [Windows.Controls.Border]::new()
                $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
                $sp = [Windows.Controls.StackPanel]::new()
                $sp.VerticalAlignment = 'Center'
                $name = New-AkariText $r.Name 14
                [void]$sp.Children.Add($name)
                $change = if ($r.From) { "$($r.From) $([char]0x2192) $($r.To)" } else { $r.To }
                [void]$sp.Children.Add((New-AkariText $change 12 'Mu'))
                $b.Child = $sp
                [void]$StepBody.Children.Add($b)
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
    [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -eq 'Yes'
}

# an AkariOS restore point exists already (from an earlier session): make another one?
function Confirm-AkariAnotherRestore($Point) {
    $when = if ($Point.Date) { " on $($Point.Date.ToString('g'))" } else { '' }
    $q = "AkariOS already made a restore point$when.`n`nCreate another restore point before these changes?"
    [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Question') -eq 'Yes'
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
    # Last used (Quick select): what this Run was asked to do
    try { Save-AkariLastUsed @($Shared.Plan) } catch { Add-Log "Warning: Last used not saved ($($_.Exception.Message))" }
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
        $b = [Windows.Controls.Border]::new()
        $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
        $sp = [Windows.Controls.StackPanel]::new()
        $sp.VerticalAlignment = 'Center'
        [void]$sp.Children.Add((New-AkariText $(if ($t) { $t.Name } else { $o.Id }) 14))
        $line = if ($o.Message) { "$($o.Outcome): $($o.Message)" } else { $o.Outcome }
        [void]$sp.Children.Add((New-AkariText $line 12 $(if ($o.Outcome -eq 'Failed') { 'Bad' } else { 'Mu' })))
        $b.Child = $sp
        [void]$StepBody.Children.Add($b)
    }
}

# Done: forget the Selection and the cached steps, back to Home (Downloads: back to where it was opened)
function Reset-AkariSteps {
    # Downloads goes back to where it was opened (a Legacy page or Home), Install AkariOS Home
    $exit = if ($script:Mode -eq 'Downloads') { $script:FlowExit } else { 'Home' }
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
    $script:TweaksView = $null
    $script:AppRows = [ordered]@{}
    $script:AppsView = $null
    $script:AppTab = 'Remove'
    $script:Outcomes = @()
}
