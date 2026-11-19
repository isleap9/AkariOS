# Steps: the Install AkariOS page (the prototype's PAGES.install). It opens on a chooser: One-click or Guided.
# Guided = Apps -> Tweaks -> Review & Apply (docs\PLAN.md §4), with a step header and a footer that slides up.
# Nothing changes while choosing: rows write into the Selection, Review lists it, Apply runs it once on the run page,
# then the result (step 3). Also the Legacy page list, Downloads' uninstall and installed read.
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

# the loaded Tweak with id $Id (the first one, ids ignore case), or $null; an index made once, again when
# $script:Tweaks changes size (a scan per row took seconds on the Tweaks step)
$script:TweakIndex = $null; $script:TweakIndexSize = -1; $script:TweakIndexOf = $null
function Find-AkariTweak([string]$Id) {
    if (-not $script:TweakIndex -or $script:TweakIndexSize -ne @($script:Tweaks).Count -or -not [object]::ReferenceEquals($script:TweakIndexOf, $script:Tweaks)) {
        $ix = @{}
        foreach ($t in $script:Tweaks) { if ($null -ne $t.Id -and -not $ix.ContainsKey([string]$t.Id)) { $ix[[string]$t.Id] = $t } }
        $script:TweakIndex = $ix; $script:TweakIndexSize = @($script:Tweaks).Count; $script:TweakIndexOf = $script:Tweaks
    }
    $script:TweakIndex[$Id]
}
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

# the steps of Guided: Apps, Tweaks, Review & Apply; step 3 is the run page, then its result
$AkariFlows = @{ Guided = @(0, 1, 2) }

# the step before (-1) or after (+1) $Step in $Mode's flow, or $null at either end. Pure.
function Get-AkariFlowStep([string]$Mode, [int]$Step, [int]$Dir) {
    $f = @($AkariFlows[$Mode])
    $i = [array]::IndexOf($f, $Step) + $Dir
    if ($i -lt 0 -or $i -ge $f.Count) { return $null }
    $f[$i]
}

# Optimize › Legacy: its pages, in order (Downloads is a page of its own: the Optimize page lists the others)
$AkariLegacyPages = 'Check', 'Refresh', 'Setup', 'Downloads', 'Graphics', 'Windows', 'Hardware', 'Advanced'

# the rows of a Legacy page: legacy tweaks only (ADR 0004), those of page $Page, or every match of $Query. Pure.
function Get-AkariLegacyList($Tweaks, [string]$Page, [string]$Query) {
    $legacy = @($Tweaks | Where-Object { $_.Legacy })
    if ($Query) { return @($legacy | Where-Object { "$($_.Name) $($_.Description)" -like "*$Query*" }) }
    @($legacy | Where-Object { $_.Section -eq $Page })
}

# the footer's Back: Cancel on the first step (the chooser again), else the step before
function Step-AkariBack {
    if ($script:Mode -ne 'Guided') { Select-AkariPage 'Home'; return }
    Push-AkariHistory
    $prev = Get-AkariFlowStep $script:Mode $script:Step -1
    if ($null -ne $prev) { $script:Step = $prev } else { $script:Mode = 'Choose'; $script:Step = 0 }
    Show-Page
}

# the footer's Next: the next step; on Review, Apply asks once, then runs
function Step-AkariForward {
    switch ($script:Step) {
        2 {
            $n = $script:Sel.Count
            if (-not $n) { return }
            if (-not (Confirm-AkariDialog 'Akari makes a restore point first. You can switch any Tweak back later in Optimize.' 'Apply' 'Cancel' 'Question' "Apply $n change$(if ($n -ne 1) { 's' })?")) { return }
            Start-AkariApply
        }
        3 { Reset-AkariSteps }
        default { Push-AkariHistory; $script:Step = Get-AkariFlowStep $script:Mode $script:Step 1; Show-Page }
    }
}

function Initialize-AkariSteps {
    $StepBack.Add_Click({ Step-AkariBack })
    $StepNext.Add_Click({ Step-AkariForward })
}

# ---- the Tweaks step's States: read once in the background (Start-AkariTweakStates, from the Apps step on), the view
# built when they are in (Complete-AkariTweakStates); "Reading..." until then. $AkariReadInline: read them at once on
# this thread instead (tests: no dispatcher runs there).
if ($null -eq $AkariReadInline) { $AkariReadInline = $false }
# id -> @{ State; Current } once read, else $null; the job reading them; a Quick select waiting for them; Clear-AkariSteps
# bumps Gen so a read started before it is dropped
$script:TweakStates = $null; $script:TweakStatesJob = $null; $script:QuickPending = $null; $script:TweakStatesGen = 0; $script:StepGroups = $null

# the Tweaks the grid shows (Get-AkariStepGroups), worked out once per States read
function Get-AkariStepTweaks {
    if (-not $script:StepGroups) { $script:StepGroups = @(Get-AkariStepGroups $script:Tweaks $script:Ported) }
    foreach ($g in $script:StepGroups) { foreach ($c in $g.Categories) { foreach ($id in $c.Ids) { Find-AkariTweak $id } } }
}

function Read-AkariTweakState($t) {
    $cur = $null
    if ($t.Kind -eq 'Choice') { try { $cur = Get-AkariChoiceValue $t } catch { } }
    @{ State = (Get-AkariState $t); Current = $cur }
}

function Start-AkariTweakStates {
    if ($script:TweakStates -or $script:TweakStatesJob) { return }
    # Actions have no State (Get-AkariState: Unknown): nothing to read
    $list = @(Get-AkariStepTweaks | Where-Object { $_ -and $_.Kind -ne 'Action' })
    if ($AkariReadInline -or -not $list.Count) {
        $m = @{}
        foreach ($t in $list) { $m[$t.Id] = Read-AkariTweakState $t }
        $script:TweakStates = $m
        return
    }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{ Items = @($list | ForEach-Object { @{ Id = $_.Id; Source = $_.Source; Legacy = [bool]$_.Legacy } }); States = [hashtable]::Synchronized(@{}) })
    # one-file Tweaks from their file, legacy ones from the legacy files (a script block must not cross runspaces)
    $code = @"
`$legacy = `$null
foreach (`$i in `$AkariShared.Items) {
    try {
        if (`$i.Legacy) {
            if (`$null -eq `$legacy) { `$legacy = @{}; foreach (`$x in @(Import-AkariLegacyTweaks $(& $q "$Root\Tweaks"))) { `$legacy[`$x.Id] = `$x } }
            `$t = `$legacy[`$i.Id]
        } else { `$t = Import-AkariTweakFile -Path `$i.Source -TweaksRoot $(& $q "$Root\Tweaks") }
        `$cur = `$null
        if (`$t.Kind -eq 'Choice') { try { `$cur = Get-AkariChoiceValue `$t } catch { } }
        `$AkariShared.States[`$i.Id] = @{ State = (Get-AkariState `$t); Current = `$cur }
    } catch { `$AkariShared.States[`$i.Id] = @{ State = 'Unknown'; Current = `$null } }
}
"@
    $job = Start-AkariJob $code ([System.Collections.Concurrent.ConcurrentQueue[string]]::new()) "$Root\Core" $shared
    $job.Gen = $script:TweakStatesGen
    $script:TweakStatesJob = $job
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(200)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Write-ErrLog "Tweak states: $_" }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        Complete-AkariTweakStates $j
    })
    $tm.Start()
}

# the States are in: the grid is built if its step is showing, and a Quick select that waited for them is picked
function Complete-AkariTweakStates($Job) {
    if ($script:TweakStatesJob -eq $Job) { $script:TweakStatesJob = $null }
    if ($Job.Gen -ne $script:TweakStatesGen) { return }
    $m = @{}
    foreach ($i in $Job.Shared.Items) { $m[$i.Id] = if ($Job.Shared.States.ContainsKey($i.Id)) { $Job.Shared.States[$i.Id] } else { @{ State = 'Unknown'; Current = $null } } }
    $script:TweakStates = $m
    Resume-AkariQuickSelect
    if ($script:Mode -eq 'Guided' -and $script:Step -eq 1 -and $script:Cat -eq 'Install AkariOS') { Show-AkariSteps }
}

# both reads a Quick select needs (the Tweaks' States, the Store packages): started, and true once both are in
function Test-AkariStepsRead {
    Start-AkariTweakStates
    Start-AkariAppxRead
    [bool]($script:TweakStates -and $script:Appx)
}

# a Quick select that waited for the reads, picked once both are in
function Resume-AkariQuickSelect {
    $p = $script:QuickPending
    if (-not $p -or -not $script:TweakStates -or -not $script:Appx) { return }
    $script:QuickPending = $null
    Set-AkariQuickSelect $p
}

# a Tweak's row; its State from the background read (read here when it has none: an Action, or a test)
function New-AkariRowEntry($t) {
    $r = if ($script:TweakStates -and $script:TweakStates.ContainsKey($t.Id)) { $script:TweakStates[$t.Id] } else { Read-AkariTweakState $t }
    $state = $r.State
    $cur = $r.Current
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
    # the rows need the States and the apps: picked once both background reads are in (Resume-AkariQuickSelect)
    if (-not (Test-AkariStepsRead)) {
        $script:QuickPending = $Preset
        Add-Log "Quick select: $($Preset.Name), picked once the apps and the current state of each tweak are read"
        return
    }
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
            $t = Find-AkariTweak $i.Id
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

# the command bar above the Tweaks: Quick select (Presets), Clear selection, Show current state
function New-AkariTweaksToolbar {
    $bar = [Windows.Controls.WrapPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $quick = New-AkariQuickSelect
    $clear = New-AkariAppsButton 'Clear selection' 'Undo every pick on this page' { Reset-AkariTweakRows } -Subtle
    $show = [Windows.Controls.CheckBox]::new()
    $show.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $show.Content = 'Show current state'
    $show.ToolTip = 'Check the Tweaks already applied on this PC. Unchecking one of them reverts it.'
    $show.IsChecked = $script:UseState
    $show.VerticalAlignment = 'Center'
    $show.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $show.Add_Click({ param($s, $a) $script:UseState = [bool]$s.IsChecked; Reset-AkariTweakRows })
    foreach ($x in $quick, $clear, $show) { [void]$bar.Children.Add($x) }
    $bar
}

# builds the Tweaks view once: an InfoBar, the command bar, then per Section a header and an expander per Category
# (WinUI SettingsExpander; the first two open), whose header says "n of m" picked and follows every change
function Get-AkariTweaksView {
    if ($script:TweaksView) { return $script:TweaksView }
    # the States first: until they are read, a ring and a line saying so (Complete-AkariTweakStates shows the step again)
    if (-not $script:TweakStates) {
        Start-AkariTweakStates
        if (-not $script:TweakStates) { return New-AkariReading ('Reading the current state of each tweak' + [char]0x2026) }
    }
    $script:TweakCards = @()
    $script:TweakSections = @()
    if (-not $script:StepGroups) { $script:StepGroups = @(Get-AkariStepGroups $script:Tweaks $script:Ported) }
    $view = [Windows.Controls.StackPanel]::new()
    $ib = New-AkariInfoBar 'Info' 'Ticked rows are on this PC already' 'Untick one to switch it back, tick one to apply it. Quick select picks the AkariOS setup in one go.'
    [void]$view.Children.Add($ib.Bar)
    [void]$view.Children.Add((New-AkariTweaksToolbar))
    $open = 0
    foreach ($g in $script:StepGroups) {
        $sec = @{ Section = $g.Section; Header = $g.Header }
        $sec.Heading = New-AkariSection $g.Header -First:($g -eq $script:StepGroups[0])
        [void]$view.Children.Add($sec.Heading)
        foreach ($c in $g.Categories) {
            # one-file tweaks: an expander per Category; legacy tweaks: one per old page, "Not yet ported"
            $legacy = ($c.Name -eq 'Not yet ported')
            $title = if ($legacy) { $g.Section } else { $c.Name }
            $ex = New-AkariExpander (Get-AkariCategoryIcon $title) $title "$(@($c.Ids).Count) Tweaks$(if ($legacy) { ', not yet ported' })" ($open -lt 2)
            $open++
            foreach ($id in $c.Ids) {
                $t = Find-AkariTweak $id
                $e = New-AkariRowEntry $t
                $e.Card = $ex.Card
                $script:TweakRows[$id] = $e
                [void]$ex.Body.Children.Add($e.Row)
            }
            $script:TweakCards += @{ Card = $ex.Card; Count = $ex.Count; Ids = @($c.Ids); Section = $g.Section; Body = $ex.Body }
            [void]$view.Children.Add($ex.Card)
        }
        $script:TweakSections += $sec
    }
    $script:TweaksView = $view
    Reset-AkariTweakRows
    $view
}

# each expander's "n of m": the Tweaks of its Category picked in the Selection
function Update-AkariTweakCounts {
    foreach ($c in $script:TweakCards) {
        $n = @($c.Ids | Where-Object { $script:Sel.Contains($_) }).Count
        $c.Count.Text = "$n of $(@($c.Ids).Count)"
    }
}

# the search on the Tweaks step: hide rows that don't match, then expanders left empty, then empty Sections
function Set-AkariTweaksFilter([string]$q) {
    if (-not $script:TweaksView) { return }
    foreach ($e in $script:TweakRows.Values) {
        $hit = (-not $q) -or ("$($e.Tweak.Name) $($e.Tweak.Description)" -like "*$q*")
        $e.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
    }
    foreach ($c in $script:TweakCards) {
        $any = @($c.Body.Children | Where-Object { $_.Visibility -eq 'Visible' }).Count -gt 0
        $c.Card.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    }
    foreach ($sec in $script:TweakSections) {
        $any = @($script:TweakCards | Where-Object { $_.Section -eq $sec.Section -and $_.Card.Visibility -eq 'Visible' }).Count -gt 0
        $sec.Heading.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    }
}

# the footer (.foot): "Step n of 3 . Name", the bar at n / 3, Cancel / Back, and Next ("Apply n changes" on Review)
function Update-AkariStepFooter {
    Update-AkariTweakCounts
    if ($script:Mode -ne 'Guided' -or $script:Step -gt 2) { return }
    $n = $script:Sel.Count
    $StepLabel.Text = "Step $($script:Step + 1) of 3 $([char]0x00B7) $($AkariStepNames[$script:Step])"
    Start-AkariMotion $StepFill Fill $null (($script:Step + 1) / 3) -Speed Slow
    $StepBack.Content = if ($script:Step -eq 0) { 'Cancel' } else { 'Back' }
    if ($script:Step -eq 2) { $StepNext.Content = "Apply $n change$(if ($n -ne 1) { 's' })"; $StepNext.IsEnabled = ($n -gt 0) }
    else { $StepNext.Content = 'Next'; $StepNext.IsEnabled = $true }
}

# One-click: the AkariOS preset's Run (Presets\AkariOS.json: preparation, Safe Mode, then the debloat and tweaks, with
# restarts in between: Core\Phases.ps1), in Akari's own console: the window closes and Akari.ps1 starts the Run there
# after ShowDialog returns (no new window).
function Confirm-AkariOneClick {
    $q = "AkariOS changes a lot of Windows, including security features.`n" +
         "- Run it on a fresh install or a PC you can reinstall. There is no uninstaller.`n" +
         "- Security is reduced on purpose (Defender settings, UAC, memory integrity).`n" +
         "- Your PC restarts several times, once into Safe Mode. Save your work and don't interrupt it.`n" +
         "- Graphics and audio drivers are removed. Install a fresh graphics driver afterwards.`n" +
         "- It is tuned for desktops: power saving is turned off.`n" +
         "- It needs an internet connection."
    Confirm-AkariDialog $q 'Start One-click' 'Cancel' 'Warning' 'Start One-click now?'
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

# the five phases of One-click, as the chooser explains them
$AkariOneClickPhases = @(
    @('Prepare', 'Allows scripts, makes a restore point, gets the graphics driver cleanup ready'),
    @('Drivers', 'Restarts into Safe Mode and removes graphics drivers with Display Driver Uninstaller'),
    @('Safe Mode', 'Applies the security changes that only work in Safe Mode, then restarts back'),
    @('Debloat and tweaks', 'Removes Store apps and features, applies every AkariOS Tweak, installs your apps'),
    @('Finish', 'Rebuilds performance counters, applies the final registry set, restarts one last time'))

# Install AkariOS: two large tiles (One-click recommended, Guided), what One-click does in five phases, and the warning
function Show-AkariChooser {
    Set-AkariHeader @('Install AkariOS')
    [void]$StepBody.Children.Add((New-AkariLead 'Two ways to optimize Windows. Both make a restore point first.'))
    $g = [Windows.Controls.Primitives.UniformGrid]::new()
    $g.Columns = 2
    $g.Margin = [Windows.Thickness]::new(-4)
    [void]$g.Children.Add((New-AkariTile 'zap' 'One-click' 'The full AkariOS setup in one go: removes bloat, cleans and reinstalls graphics drivers, applies every AkariOS Tweak, including the ones that need Safe Mode. Your PC restarts several times.' 'Recommended for a fresh install' { Start-AkariOneClick } -Rec -Big))
    [void]$g.Children.Add((New-AkariTile 'wand' 'Guided' 'Pick the apps to remove and install and the Tweaks to apply, review everything, then apply it in one go. Nothing changes until you press Apply.' 'For a PC you already use' { Start-AkariGuided } -Big))
    [void]$StepBody.Children.Add($g)
    [void]$StepBody.Children.Add((New-AkariSection 'What One-click does'))
    $ex = New-AkariExpander 'list-checks' 'Five phases, about 20 minutes' 'Akari runs them in its own console and restarts the PC between them'
    $ph = [Windows.Controls.StackPanel]::new()
    for ($i = 0; $i -lt $AkariOneClickPhases.Count; $i++) {
        $row = [Windows.Controls.Border]::new()
        $row.Padding = [Windows.Thickness]::new(0, 10, 0, 10)
        if ($i) { $row.BorderThickness = [Windows.Thickness]::new(0, 1, 0, 0); $row.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Div') }
        $dp = [Windows.Controls.DockPanel]::new()
        $n = [Windows.Controls.Border]::new()
        $n.Width = 24; $n.Height = 24; $n.CornerRadius = [Windows.CornerRadius]::new(12); $n.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
        $n.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'AccSoft')
        $nt = New-AkariText "$($i + 1)" 12 'AccText' 'SemiBold'; $nt.HorizontalAlignment = 'Center'; $nt.VerticalAlignment = 'Center'
        $n.Child = $nt
        [Windows.Controls.DockPanel]::SetDock($n, 'Left'); [void]$dp.Children.Add($n)
        $tx = [Windows.Controls.StackPanel]::new(); $tx.VerticalAlignment = 'Center'
        [void]$tx.Children.Add((New-AkariText $AkariOneClickPhases[$i][0] 14))
        [void]$tx.Children.Add((New-AkariText $AkariOneClickPhases[$i][1] 12 'Mu'))
        [void]$dp.Children.Add($tx)
        $row.Child = $dp
        [void]$ph.Children.Add($row)
    }
    [void]$ex.Body.Children.Add((New-AkariExpanderRow $ph $null 16))
    [void]$StepBody.Children.Add($ex.Card)
    $w = New-AkariInfoBar 'Warn' 'There is no uninstaller' 'Use One-click on a fresh install or a PC you can reinstall.'
    $w.Bar.Margin = [Windows.Thickness]::new(0, 16, 0, 0)
    [void]$StepBody.Children.Add($w.Bar)
}

# Guided's step header (.steps): numbered 20 px circles joined by 32 px lines, the current one Acc, done ones ticked
# on AccSoft; the names in Caption (the current one in Tx)
function New-AkariStepsHeader([int]$Step) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Orientation = 'Horizontal'
    $sp.Margin = [Windows.Thickness]::new(0, -8, 0, 20)
    for ($i = 0; $i -lt $AkariStepNames.Count; $i++) {
        $state = if ($i -eq $Step) { 'Current' } elseif ($i -lt $Step) { 'Done' } else { '' }
        if ($i) {
            $l = [Windows.Controls.Border]::new(); $l.Width = 32; $l.Height = 1; $l.Margin = [Windows.Thickness]::new(8, 0, 8, 0); $l.VerticalAlignment = 'Center'
            $l.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Div')
            [void]$sp.Children.Add($l)
        }
        $s = New-AkariStepItem ($i + 1) $AkariStepNames[$i] $state
        [void]$sp.Children.Add($s)
    }
    $sp
}
function New-AkariStepItem([int]$Number, [string]$Name, [string]$State) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Orientation = 'Horizontal'
    $sp.Tag = $State
    $c = [Windows.Controls.Border]::new()
    $c.Width = 20; $c.Height = 20; $c.CornerRadius = [Windows.CornerRadius]::new(10); $c.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $c.VerticalAlignment = 'Center'
    $c.Tag = $State
    switch ($State) {
        'Current' { $c.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Acc') }
        'Done' { $c.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'AccSoft') }
        default { $c.BorderThickness = [Windows.Thickness]::new(1); $c.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Line') }
    }
    if ($State -eq 'Done') {
        $ic = New-AkariIcon 'check' 12 'AccText'
        $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
        $c.Child = $ic
    } else {
        $t = New-AkariText ([string]$Number) 11 $(if ($State -eq 'Current') { 'AccT' } else { 'Tx' }) 'SemiBold'
        $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'; $t.LineHeight = [double]::NaN
        $c.Child = $t
    }
    [void]$sp.Children.Add($c)
    $lb = New-AkariText $Name 12 $(if ($State -eq 'Current') { 'Tx' } else { 'Mu' })
    $lb.VerticalAlignment = 'Center'; $lb.TextWrapping = 'NoWrap'
    [void]$sp.Children.Add($lb)
    $sp
}

# a summary card (.sum .c): the number in Title type, its label in Caption
function New-AkariSumCard([int]$Count, [string]$Label, [string]$Brush = 'Tx') {
    $b = [Windows.Controls.Border]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Panel')
    $b.Margin = [Windows.Thickness]::new(4)
    $sp = [Windows.Controls.StackPanel]::new()
    [void]$sp.Children.Add((New-AkariText "$Count" 28 $Brush))
    [void]$sp.Children.Add((New-AkariText $Label 12 'Mu'))
    $b.Child = $sp
    $b
}
function New-AkariSumRow($Cards) {
    $g = [Windows.Controls.Primitives.UniformGrid]::new()
    $g.Rows = 1
    $g.Margin = [Windows.Thickness]::new(-4, -4, -4, 4)
    foreach ($c in $Cards) { [void]$g.Children.Add($c) }
    $g
}

function Show-AkariSteps {
    # the cached views: detached before the body is cleared, so they can be added again
    if ($script:TweaksView -and $script:TweaksView.Parent) { $script:TweaksView.Parent.Children.Remove($script:TweaksView) }
    if ($script:AppsView -and $script:AppsView.Parent) { $script:AppsView.Parent.Children.Remove($script:AppsView) }
    if ($script:Mode -ne 'Guided') { Show-AkariChooser; return }
    if ($script:Step -eq 3) { if ($script:Running) { Show-AkariRun } else { Show-AkariResult }; return }
    Set-AkariHeader @(@('Install AkariOS', 'Install AkariOS'), 'Guided')
    [void]$StepBody.Children.Add((New-AkariStepsHeader $script:Step))
    Set-AkariFooter $true
    switch ($script:Step) {
        0 {
            [void]$StepBody.Children.Add((Get-AkariAppsView))
            if ($script:AppsView) { Set-AkariAppsOnly ''; Set-AkariAppsFilter '' }
            # the Tweaks step's States are read meanwhile, so Next finds them in
            if (-not $AkariReadInline) { Start-AkariTweakStates }
        }
        1 { [void]$StepBody.Children.Add((Get-AkariTweaksView)); Set-AkariTweaksFilter '' }
        2 { Show-AkariReview }
    }
    Update-AkariStepFooter
}

# Review & Apply: three summary cards, a restart InfoBar when needed, and an expander per kind listing every change
# ("Off -> On", "No change -> Cloudflare"); the changes to Tweaks only Optimize shows (a preset's, an import's) last
function Show-AkariReview {
    $review = @(Get-AkariReviewItems $script:Sel)
    $apps = @($review | Where-Object { $t = Find-AkariTweak $_.Id; (-not $t -and $script:AppRows.Contains($_.Id)) -or ($t -and $t.Section -eq 'Apps') -or $script:AppRows.Contains($_.Id) })
    $rm = @($apps | Where-Object { $e = $script:AppRows[$_.Id]; $e -and (Test-AkariRemoveRow $e) })
    $in = @($apps | Where-Object { $rm -notcontains $_ })
    $tw = @($review | Where-Object { $apps -notcontains $_ })
    [void]$StepBody.Children.Add((New-AkariSumRow @((New-AkariSumCard $rm.Count 'Apps to remove'), (New-AkariSumCard $in.Count 'Apps to install'), (New-AkariSumCard $tw.Count 'Tweaks to apply'))))
    # changes that restart the PC run last (Core\Runner.ps1): say so before Apply
    $note = Get-AkariRestartNote $script:Sel $script:Tweaks
    if ($note) { $ib = New-AkariInfoBar 'Warn' 'Restart needed' $note; $ib.Bar.Margin = [Windows.Thickness]::new(0, 4, 0, 12); [void]$StepBody.Children.Add($ib.Bar) }
    foreach ($k in @(@('trash-2', 'Remove', "$($rm.Count) app$(if ($rm.Count -ne 1) { 's' })", $rm, $false),
                     @('download', 'Install', "$($in.Count) app$(if ($in.Count -ne 1) { 's' }), from winget where possible", $in, $false),
                     @('sliders-horizontal', 'Tweaks', "$($tw.Count) change$(if ($tw.Count -ne 1) { 's' })", $tw, $true))) {
        $ex = New-AkariExpander $k[0] $k[1] $k[2] $k[4]
        if (-not @($k[3]).Count) { [void]$ex.Body.Children.Add((New-AkariExpanderRow (New-AkariText 'Nothing' 14 'Mu') $null 52)) }
        $shownHidden = $false
        foreach ($r in @(@($k[3]) | Where-Object { -not $_.Hidden }) + @(@($k[3]) | Where-Object { $_.Hidden })) {
            if ($r.Hidden -and -not $shownHidden) {
                $shownHidden = $true
                [void]$ex.Body.Children.Add((New-AkariExpanderRow (New-AkariText "Advanced settings (Optimize $([char]0x203A) Advanced)" 14 'Tx' 'SemiBold') $null 52))
            }
            [void]$ex.Body.Children.Add((New-AkariReviewRow $r.Id $r.Name $(if ($k[1] -eq 'Tweaks') { if ($r.From) { "$($r.From) $([char]0x2192) $($r.To)" } else { $r.To } } else { $k[1] }) '' ''))
        }
        [void]$StepBody.Children.Add($ex.Card)
    }
}

# a Review / run / result row inside an expander: the app's icon or the Tweak's Category icon, its name and the change
# (or Outcome) under it, the badges and marks
function New-AkariReviewRow([string]$Id, [string]$Name, [string]$Line, [string]$Icon, [string]$Brush) {
    $t = Find-AkariTweak $Id
    if (-not $t -and $script:AppRows.Contains($Id)) { $t = $script:AppRows[$Id].Tweak }
    $ic = if ($t -and $t.Section -eq 'Apps') { New-AkariAppIcon $t 28 } else { New-AkariIcon $(if ($t) { Get-AkariCategoryIcon $t.Category } else { 'settings' }) 20 'Tx' }
    $ic.Margin = [Windows.Thickness]::new(0, 0, 16, 0)
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left')
    $tx = [Windows.Controls.StackPanel]::new(); $tx.VerticalAlignment = 'Center'
    [void]$tx.Children.Add((New-AkariText $Name 14))
    [void]$tx.Children.Add((New-AkariText $Line 12 $(if ($Brush -eq 'Bad') { 'Bad' } else { 'Mu' })))
    $end = if ($t -and $t.Section -ne 'Apps') { @((New-AkariBadges $t), (New-AkariMarks $t)) } else { $null }
    $row = New-AkariExpanderRow @($ic, $tx) $end 16
    $row.Tag = $Id
    $row
}

# ---- Apply: one Run in the background job, restore point first

# counts per Outcome, in Glossary order, and whether a restart is needed. Pure, no WPF.
# -Uninstall: the Outcomes of an uninstall, whose Reverted reads "uninstalled".
function Get-AkariRunSummary($Outcomes, [switch]$Uninstall) {
    $counts = [ordered]@{}
    foreach ($k in 'Applied', 'Reverted', 'Already', 'Skipped', 'Failed') {
        $n = @($Outcomes | Where-Object { $_.Outcome -eq $k }).Count
        if ($n) { $counts[$k] = $n }
    }
    $text = ($counts.Keys | ForEach-Object { "$($counts[$_]) $(if ($Uninstall -and $_ -eq 'Reverted') { 'uninstalled' } else { $_.ToLower() })" }) -join ', '
    [pscustomobject]@{ Counts = $counts; Text = $text; Reboot = [bool]($Outcomes | Where-Object { $_.Reboot }) }
}

function Confirm-AkariNoRestore([string]$Message) {
    $q = "Akari could not create a restore point:`n$Message"
    Confirm-AkariDialog $q 'Apply anyway' 'Cancel' 'Warning' 'Apply without a restore point?'
}

# an AkariOS restore point exists already (from an earlier session): make another one?
function Confirm-AkariAnotherRestore($Point) {
    $when = if ($Point.Date) { " on $($Point.Date.ToString('g'))" } else { '' }
    Confirm-AkariDialog "AkariOS already made a restore point$when." 'Create one' 'Skip' 'Question' 'Create another restore point?'
}

# whether the changes about to run get a restore point first. Downloads (app installs only) never; Install AkariOS,
# Remove apps and Optimize once per session; when an AkariOS restore point already exists, the user decides. Either
# way it is not asked again this session ($script:RestoreDone).
function Get-AkariRestoreChoice([string]$Flow) {
    if ($Flow -eq 'Downloads' -or $script:RestoreDone) { return $false }
    $point = try { Get-AkariRestorePoint } catch { $null }
    if ($point -and -not (Confirm-AkariAnotherRestore $point)) { $script:RestoreDone = $true; return $false }
    $true
}

# runs a plan in the job: the Selection (Guided: the run page, then the result), or $Plan under $Label (an install, Update
# all apps, Remove apps). -Restore: the flow whose restore point rule applies (none given with a $Plan = no restore point).
# -Kind: Apply (Guided's run page), Install (a Downloads card), Remove (Remove apps' rows).
function Start-AkariApply($Plan = $null, [string]$Label = '', [string]$Restore = '', [string]$Kind = 'Apply') {
    if ($script:Busy -or -not ($Plan -or $script:Sel.Count)) { return }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $items = @(if ($Plan) { $Plan } else { Get-AkariPlanItems $script:Sel })
    $skip = if ($Restore) { -not (Get-AkariRestoreChoice $Restore) } elseif ($Plan) { $true } else { -not (Get-AkariRestoreChoice $script:Mode) }
    $shared = [hashtable]::Synchronized(@{ Plan = $items; SkipRestore = $skip })
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
    $n = $items.Count
    $label = if ($Label) { $Label } else { 'Applying changes' }
    Set-Busy $true $label $($Kind -ne 'Install')
    Add-Log "$label ($n)"
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = $Kind
    if ($Kind -eq 'Apply') {
        # the run page: a row per change, the restore point first
        $script:RunItems = @(New-AkariRunItems $items (-not $skip))
        $script:Running = $true
        $script:Step = 3
        Show-Page
    }
}

# the run page's rows: @{ Id; Name; Kind; State (wait / run / ok / bad / skip / already); Why; Row; Status }
function New-AkariRunItems($Plan, [bool]$Restore) {
    if ($Restore) { @{ Id = ''; Name = 'Create a restore point'; Kind = 'Preparation'; Icon = 'arrow-reset'; State = 'wait' } }
    foreach ($i in $Plan) {
        $t = Find-AkariTweak $i.Id
        if (-not $t -and $script:AppRows.Contains($i.Id)) { $t = $script:AppRows[$i.Id].Tweak }
        $name = if ($t) { $t.Name } else { $i.Id }
        $kind = if (-not $t) { 'Change' }
                elseif ($t.Section -eq 'Apps' -and $t.Category -eq 'Remove') { $name = "Remove $name"; $(if ($t.Group -eq 'appx') { 'Store app' } elseif ($t.Group) { 'Windows feature' } else { 'App' }) }
                elseif ($t.Section -eq 'Apps') { $name = "Install $name"; $(if ($t.Winget) { 'winget' } else { 'AkariOS download' }) }
                else { "Tweak $([char]0x00B7) $($t.Category)" }
        @{ Id = $i.Id; Name = $name; Plain = $(if ($t) { $t.Name } else { $i.Id }); Kind = $kind; Tweak = $t; State = 'wait' }
    }
}

# a run row's status (.runrow .st): Waiting, the ring and Working, Applied (Ok), Failed (Bad), Skipped, Already
function Set-AkariRunState($It, [string]$State) {
    $It.State = $State
    if (-not $It.Status) { return }
    $s = $It.Status
    $s.Children.Clear()
    $lab, $brush, $icon = switch ($State) {
        'run' { 'Working', 'Mu', '' }
        'ok' { 'Applied', 'Ok', 'circle-check.Filled' }
        'bad' { 'Failed', 'Bad', 'error-circle.Filled' }
        'skip' { 'Skipped', 'Ter', '' }
        'already' { 'Already', 'Ter', '' }
        default { 'Waiting', 'Ter', '' }
    }
    if ($State -eq 'run') { $r = New-AkariRing 16; $r.Margin = [Windows.Thickness]::new(0, 0, 6, 0); [void]$s.Children.Add($r) }
    if ($icon) { $i = New-AkariIcon $icon 14 $brush; $i.Margin = [Windows.Thickness]::new(0, 0, 6, 0); [void]$s.Children.Add($i) }
    $t = New-AkariText $lab 12 $brush; $t.TextWrapping = 'NoWrap'; $t.VerticalAlignment = 'Center'
    [void]$s.Children.Add($t)
}

# the run page: the overall bar (the current item and the percent), then a row per change that goes Waiting -> Working ->
# Applied / Failed / Skipped, the page scrolling to the current row
function Show-AkariRun {
    Set-AkariHeader @(@('Install AkariOS', 'Install AkariOS'), 'Applying')
    [void]$StepBody.Children.Add((New-AkariLead 'Keep Akari open. Changes apply one after another; Explorer restarts once at the end.'))
    $bb = [Windows.Controls.StackPanel]::new(); $bb.Margin = [Windows.Thickness]::new(0, 4, 0, 20)
    $lbl = [Windows.Controls.DockPanel]::new(); $lbl.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    $script:RunPct = New-AkariText '0%' 12 'Mu'; [Windows.Controls.DockPanel]::SetDock($script:RunPct, 'Right'); [void]$lbl.Children.Add($script:RunPct)
    $script:RunLabel = New-AkariText ('Starting' + [char]0x2026) 12 'Mu'; [void]$lbl.Children.Add($script:RunLabel)
    [void]$bb.Children.Add($lbl)
    $bar = [Windows.Controls.Grid]::new(); $bar.Height = 3
    $tr = [Windows.Controls.Border]::new(); $tr.Height = 1; $tr.VerticalAlignment = 'Center'; $tr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Track')
    $script:RunFill = [Windows.Shapes.Rectangle]::new(); $script:RunFill.RadiusX = 1.5; $script:RunFill.RadiusY = 1.5
    $script:RunFill.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'Acc')
    $script:RunFill.RenderTransformOrigin = [Windows.Point]::new(0, 0.5)
    $script:RunFill.RenderTransform = [Windows.Media.ScaleTransform]::new(0, 1)
    [void]$bar.Children.Add($tr); [void]$bar.Children.Add($script:RunFill)
    [void]$bb.Children.Add($bar)
    [void]$StepBody.Children.Add($bb)
    $box = [Windows.Controls.Border]::new()
    $box.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CategoryCard')
    $sp = [Windows.Controls.StackPanel]::new()
    $first = $true
    foreach ($it in $script:RunItems) {
        $r = [Windows.Controls.Border]::new()
        $r.MinHeight = 44; $r.Padding = [Windows.Thickness]::new(16, 8, 16, 8)
        if (-not $first) { $r.BorderThickness = [Windows.Thickness]::new(0, 1, 0, 0); $r.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Div') }
        $first = $false
        $dp = [Windows.Controls.DockPanel]::new()
        $ic = if ($it.Tweak -and $it.Tweak.Section -eq 'Apps') { New-AkariAppIcon $it.Tweak 28 } elseif ($it.Icon) { New-AkariIcon $it.Icon 16 'Tx' } else { New-AkariIcon $(if ($it.Tweak) { Get-AkariCategoryIcon $it.Tweak.Category } else { 'settings' }) 16 'Tx' }
        $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $ic.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
        $st = [Windows.Controls.StackPanel]::new(); $st.Orientation = 'Horizontal'; $st.Width = 92; $st.HorizontalAlignment = 'Right'; $st.FlowDirection = 'LeftToRight'
        $wrap = [Windows.Controls.Grid]::new(); $wrap.Width = 92; [void]$wrap.Children.Add($st); $st.HorizontalAlignment = 'Right'; $st.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($wrap, 'Right'); [void]$dp.Children.Add($wrap)
        $tx = [Windows.Controls.StackPanel]::new(); $tx.VerticalAlignment = 'Center'
        [void]$tx.Children.Add((New-AkariText $it.Name 14))
        [void]$tx.Children.Add((New-AkariText $it.Kind 12 'Ter'))
        [void]$dp.Children.Add($tx)
        $r.Child = $dp
        $it.Row = $r; $it.Status = $st
        Set-AkariRunState $it $it.State
        [void]$sp.Children.Add($r)
    }
    $box.Child = $sp
    [void]$StepBody.Children.Add($box)
}

# the job's progress (the Shell timer): the restore point, then each change as Set-AkariProgress names it
function Update-AkariRunPage($Shared) {
    if (-not $script:Running -or -not $script:RunItems) { return }
    $items = @($script:RunItems)
    $rp = @($items | Where-Object { $_.Kind -eq 'Preparation' })[0]
    if ($rp) {
        if ($null -eq $Shared.Restore -and $rp.State -eq 'wait') { Set-AkariRunState $rp 'run' }
        elseif ($Shared.Restore -and $rp.State -eq 'run') { Set-AkariRunState $rp $(if ($Shared.Restore.Ok) { 'ok' } else { 'bad' }) }
    }
    if (-not $Shared.Total) { return }
    $cur = [string]$Shared.Step
    foreach ($it in $items) {
        if ($it.Kind -eq 'Preparation') { continue }
        if ($cur -and $it.Plain -eq $cur -and $it.State -eq 'wait') {
            foreach ($o in $items) { if ($o -ne $it -and $o.State -eq 'run' -and $o.Kind -ne 'Preparation') { Set-AkariRunState $o 'ok' } }
            Set-AkariRunState $it 'run'
            if ($it.Row -and $it.Row.IsVisible) { $it.Row.BringIntoView() }
            $script:RunLabel.Text = "$($it.Name)$([char]0x2026)"
        }
    }
    $pct = [Math]::Min(1, [double]$Shared.Done / [double]$Shared.Total)
    $script:RunPct.Text = "$([int][Math]::Round($pct * 100))%"
    Start-AkariMotion $script:RunFill Fill $null $pct -Speed Slow
}

# called by the Shell timer when an Apply or Remove job has ended
function Complete-AkariApply($Shared, [string]$Kind = 'Apply') {
    if ($Shared.Restore -and $Shared.Restore.Ok) { $script:RestoreDone = $true }
    if ($null -eq $Shared.Outcomes) {
        # stopped before any change: the restore point failed (or the job itself failed)
        $script:Running = $false
        if ($Kind -eq 'Apply') { $script:Step = 2 }
        if ($Shared.Restore -and -not $Shared.Restore.Ok -and (Confirm-AkariNoRestore $Shared.Restore.Message)) {
            $script:RestoreDone = $true
            if ($Kind -eq 'Remove') { Start-AkariApply @($Shared.Plan) $script:BusyLabel -Kind 'Remove' } else { Start-AkariApply }
        }
        return
    }
    $out = @($Shared.Outcomes)
    $ok = @($out | Where-Object { $_.Outcome -in 'Applied', 'Reverted' }).Count
    $sum = Get-AkariRunSummary $out
    # the apps on this PC changed: read and built again next time
    Clear-AkariAppsView
    if ($Kind -eq 'Remove') {
        $script:RemovingRows = $null
        $script:Sel = New-AkariSelection
        Add-AkariActivity "Removed $ok app$(if ($ok -ne 1) { 's' })" 'Remove apps' $ok 'trash-2'
        $bad = @($out | Where-Object { $_.Outcome -eq 'Failed' }).Count
        Show-AkariToast 'Removed' $("$ok app$(if ($ok -ne 1) { 's are' } else { ' is' }) gone." + $(if ($bad) { " $bad failed: see the log." } else { '' }))
        return
    }
    $script:Outcomes = $out
    $script:Running = $false
    $script:ResultUninstall = $false
    foreach ($it in @($script:RunItems)) { $o = @($out | Where-Object { $_.Id -eq $it.Id })[0]; if ($o) { $it.Why = $o.Message } }
    # Last used (Quick select): what a Guided Run was asked to do
    try { Save-AkariLastUsed @($Shared.Plan) } catch { Add-Log "Warning: Last used not saved ($($_.Exception.Message))" }
    Add-AkariActivity 'Guided run' 'Install AkariOS' $ok 'wand'
    Show-AkariToast 'All done' "$ok change$(if ($ok -ne 1) { 's' }) applied.$(if ($sum.Reboot) { ' Restart to finish.' })"
    $script:Step = 3
}

# ---- Downloads' own actions (after Chris Titus Tech's winutil, MIT: Invoke-WPFUnInstall, Invoke-WPFInstallUpgrade,
# Invoke-WPFGetInstalled). They act right away, in a job, with no restore point (as the installs).

# what Uninstall asks about these apps: @{ Text; Count }. Count = the apps winget uninstalls; the others are listed
# apart with where to go (RemoveWith: Remove apps; no winget id: Windows' Installed apps). Pure, no WPF.
function Get-AkariUninstallText($Tweaks) {
    $go = @($Tweaks | Where-Object { $_.Winget -and -not $_.RemoveWith })
    $not = @($Tweaks | Where-Object { $_.RemoveWith -or -not $_.Winget } | ForEach-Object {
        "- $($_.Name): $(if ($_.RemoveWith) { 'use Remove apps' } else { "use Windows' Installed apps" })"
    })
    if (-not $go.Count) { return [pscustomobject]@{ Count = 0; Text = "None of these apps can be uninstalled here:`n" + ($not -join "`n") } }
    $text = "Uninstall these apps?`n`n" + (@($go | ForEach-Object { "- $($_.Name)" }) -join "`n")
    if ($go | Where-Object { $_.AppType -eq 'Runtimes' }) { $text += "`n`nOther apps may need these runtimes." }
    if ($not.Count) { $text += "`n`nNot uninstalled here:`n" + ($not -join "`n") }
    [pscustomobject]@{ Count = $go.Count; Text = $text }
}

# Uninstall (a Downloads card's menu): asked first, then one job (Uninstall-AkariApp per app); a toast says how it went
function Start-AkariUninstall($Tweaks) {
    if ($script:Busy) { return }
    $picked = @($Tweaks | Where-Object { $_ })
    if (-not $picked.Count) { return }
    $ask = Get-AkariUninstallText $picked
    if (-not $ask.Count) { Show-AkariMessage $ask.Text 'Info' 'Uninstall'; return }
    if (-not (Confirm-AkariDialog $ask.Text 'Uninstall' 'Cancel' 'Question' 'Uninstall')) { return }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{ Ids = @($picked | ForEach-Object { $_.Id }) })
    $code = @"
`$all = @((Get-AkariTweaks $(& $q "$Root\Tweaks")).Tweaks)
`$ids = @(`$AkariShared.Ids)
`$out = @()
for (`$n = 0; `$n -lt `$ids.Count; `$n++) {
    `$t = `$all | Where-Object { `$_.Id -eq `$ids[`$n] } | Select-Object -First 1
    if (-not `$t) { continue }
    Set-AkariProgress `$n `$ids.Count `$t.Name
    `$out += Uninstall-AkariApp `$t
}
`$AkariShared.Outcomes = `$out
"@
    $label = "Uninstalling $($picked.Count) app$(if ($picked.Count -ne 1) { 's' })"
    Set-Busy $true $label $false
    Add-Log $label
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'Uninstall'
}

# called by the Shell timer when the uninstall job has ended: the cards go back to Install, a toast says how it went
function Complete-AkariUninstall($Shared) {
    if ($null -eq $Shared.Outcomes) { return }
    $out = @($Shared.Outcomes)
    $gone = @($out | Where-Object { $_.Outcome -in 'Reverted', 'Already' } | ForEach-Object { $_.Id })
    $script:InstalledIds = @($script:InstalledIds | Where-Object { $_ -notin $gone })
    foreach ($id in $gone) { $e = $script:DlCards[$id]; if ($e) { Set-AkariAppCardState $e '' } }
    $sum = Get-AkariRunSummary $out -Uninstall
    Show-AkariToast 'Uninstall' $sum.Text
}

# Update all apps: the Tools Tweak tools-update-apps (one "winget upgrade --all"), asked with its own Confirm
function Start-AkariUpdateApps {
    if ($script:Busy) { return }
    $t = Find-AkariTweak 'tools-update-apps'
    if (-not $t) { return }
    if ($t.Confirm -and -not (Confirm-AkariDialog $t.Confirm 'Update all' 'Cancel' 'Question' $t.Name)) { return }
    Start-AkariApply @(@{ Id = $t.Id; Mode = 'Apply' }) 'Updating all apps' -Kind 'Install'
}

# which installs are on this PC, read in a job that leaves the page usable (one "winget list", the other apps' Detects);
# remembered, so a Downloads page built later shows them again
function Start-AkariInstalledRead {
    if ($script:Busy) { return }
    $script:ShowInstalled = $true
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $code = @"
`$all = @((Get-AkariTweaks $(& $q "$Root\Tweaks")).Tweaks | Where-Object { `$_.Section -eq 'Apps' -and `$_.Category -eq 'Install' })
`$AkariShared.Ids = @(Get-AkariInstalledApps `$all)
"@
    $label = 'Reading the installed apps'
    Set-Busy $true $label $false -Quiet
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" ([hashtable]::Synchronized(@{}))
    $script:Job.Label = $label
    $script:Job.Kind = 'AppsInstalled'
}

# called by the Shell timer when that read has ended
function Complete-AkariInstalledRead($Shared) {
    if ($null -ne $Shared.Ids) { Set-AkariAppsInstalled @($Shared.Ids) }
}

# the result page: a success InfoBar, "Restart to finish" with Restart now, Applied / Failed / Skipped cards, then
# Needs attention (each failure with its reason and Open log) and Skipped (with the reason), Done and Open Optimize
function Show-AkariResult {
    Set-AkariHeader @(@('Install AkariOS', 'Install AkariOS'), 'Done')
    $out = @($script:Outcomes)
    $ok = @($out | Where-Object { $_.Outcome -in 'Applied', 'Reverted' })
    $bad = @($out | Where-Object { $_.Outcome -eq 'Failed' })
    $skip = @($out | Where-Object { $_.Outcome -in 'Skipped', 'Already' })
    $sum = Get-AkariRunSummary $out
    $s = New-AkariInfoBar 'Ok' "$($ok.Count) change$(if ($ok.Count -ne 1) { 's' }) applied" $(if ($bad.Count) { "$($bad.Count) failed. See below." } else { 'Everything went through.' })
    [void]$StepBody.Children.Add($s.Bar)
    if ($sum.Reboot) {
        $rb = [Windows.Controls.Button]::new(); $rb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent'); $rb.Content = 'Restart now'
        $rb.Add_Click({ Start-AkariCatalogueRestart })
        $r = New-AkariInfoBar 'Warn' 'Restart to finish' 'Some changes take effect after a restart.' $rb
        [void]$StepBody.Children.Add($r.Bar)
    }
    [void]$StepBody.Children.Add((New-AkariSumRow @((New-AkariSumCard $ok.Count 'Applied' 'Ok'), (New-AkariSumCard $bad.Count 'Failed' 'Bad'), (New-AkariSumCard $skip.Count 'Skipped'))))
    $name = { param($o) $t = Find-AkariTweak $o.Id; if ($t) { $t.Name } else { $o.Id } }
    if ($bad.Count) {
        [void]$StepBody.Children.Add((New-AkariSection 'Needs attention'))
        $st = [Windows.Controls.StackPanel]::new()
        foreach ($o in $bad) {
            $lg = New-AkariBarButton 'Open log' { Open-AkariLogFolder }
            $c = New-AkariSettingsCard 'error-circle' (& $name $o) $(if ($o.Message) { [string]$o.Message } else { 'It failed. Open the log for details.' }) $lg
            [void]$st.Children.Add($c.Card)
        }
        [void]$StepBody.Children.Add($st)
    }
    if ($skip.Count) {
        [void]$StepBody.Children.Add((New-AkariSection 'Skipped'))
        $st = [Windows.Controls.StackPanel]::new()
        foreach ($o in $skip) {
            $why = if ($o.Message) { [string]$o.Message } elseif ($o.Outcome -eq 'Already') { 'Already done.' } else { 'Skipped.' }
            $c = New-AkariSettingsCard 'info' (& $name $o) $why
            [void]$st.Children.Add($c.Card)
        }
        [void]$StepBody.Children.Add($st)
    }
    $bt = [Windows.Controls.StackPanel]::new(); $bt.Orientation = 'Horizontal'; $bt.Margin = [Windows.Thickness]::new(0, 24, 0, 0)
    $done = [Windows.Controls.Button]::new(); $done.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent'); $done.Content = 'Done'; $done.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $done.Add_Click({ Reset-AkariSteps })
    $opt = New-AkariBarButton 'Open Optimize' { Clear-AkariSteps; $script:Mode = 'Choose'; $script:Step = 0; Select-AkariPage 'Optimize' }
    [void]$bt.Children.Add($done); [void]$bt.Children.Add($opt)
    [void]$StepBody.Children.Add($bt)
}

# Done: forget the Selection and the cached steps, back to Home (Install AkariOS opens on its chooser again)
function Reset-AkariSteps {
    Clear-AkariSteps
    $script:Mode = 'Choose'
    $script:Step = 0
    Select-AkariPage 'Home'
}

# forgets the Selection and the Tweaks view (built again, reading every State afresh). The apps view stays, its rows
# unchecked: what is on this PC is the same until a Run (Complete-AkariApply drops it: Clear-AkariAppsView)
function Clear-AkariSteps {
    $script:Sel = New-AkariSelection
    $script:TweakRows = [ordered]@{}
    $script:TweakCards = @()
    $script:TweakSections = @()
    $script:TweaksView = $null
    # the States are read again; a read still running is dropped when it ends
    $script:StepGroups = $null; $script:TweakStates = $null; $script:TweakStatesJob = $null; $script:QuickPending = $null
    $script:TweakStatesGen++
    foreach ($e in @($script:AppRows.Values)) { $e.Muted = $true; try { $e.Control.IsChecked = $false; Set-AkariAppRowLook $e } finally { $e.Muted = $false } }
    $script:AppsPick = $null
    $script:Outcomes = @()
    $script:ResultUninstall = $false
    $script:RunItems = @(); $script:Running = $false
}
