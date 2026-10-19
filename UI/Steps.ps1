# Steps: the Manual flow, Apps -> Tweaks -> Review & Apply (AkariOS-PLAN.md §4). Nothing changes while choosing:
# cards write into the Selection, Review lists it, Apply runs it once and shows the Outcomes (step 3, after Review).
# Needs UI\Selection.ps1 and UI\Cards.ps1. Initialize-AkariSteps wires the window elements (called by UI\Shell.ps1).

$AkariSectionOrder = 'Optimize', 'Customize', 'Hardware', 'Advanced'
$AkariSectionHeaders = @{ Hardware = 'Graphics & Hardware' }
$AkariStepNames = 'Apps', 'Tweaks', 'Review & Apply'
$script:Step = 0
$script:Sel = New-AkariSelection
$script:CardEntries = [ordered]@{}
$script:TweaksView = $null
$script:Outcomes = @()
# a restore point is made once per GUI session; the user may also choose to go on without one
$script:RestoreDone = $false

# Sections and Categories shown in the Tweaks step: one-file Toggles, Choices and Actions, plus legacy Toggles
# (legacy Actions and Groups stay on the old pages until M2b). Pure, no WPF.
function Get-AkariStepGroups($Tweaks) {
    $list = @($Tweaks | Where-Object { ($_.Legacy -and $_.Kind -eq 'Toggle') -or (-not $_.Legacy -and $_.Kind -in 'Toggle', 'Choice', 'Action') })
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

function Initialize-AkariSteps {
    $StepBack.Add_Click({ if ($script:Step -gt 0) { $script:Step--; Show-AkariSteps } })
    $StepNext.Add_Click({
        switch ($script:Step) {
            2 { Start-AkariApply }
            3 { Reset-AkariSteps }
            default { $script:Step++; Show-AkariSteps }
        }
    })
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
function New-AkariCardEntry($t) {
    $state = Get-AkariState $t
    $cur = $null
    if ($t.Kind -eq 'Choice') { try { $cur = Get-AkariRegValue $t.Registry[0].Path $t.Registry[0].Name } catch { } }
    $e = New-AkariCard $t $state $cur
    if ($t.Kind -eq 'Choice') { $e.Shown = $cur }
    $e.Control.Tag = $t.Id
    switch ($t.Kind) {
        'Choice' {
            $e.Control.Add_SelectionChanged({ param($s, $a) if ($s.SelectedItem) { Set-AkariChoiceTarget ([string]$s.Tag) $s.SelectedItem.Tag } })
            $e.Control.Add_LostKeyboardFocus({
                param($s, $a)
                if ($s.IsKeyboardFocusWithin) { return }
                $x = $script:CardEntries[[string]$s.Tag]
                $v = Get-AkariComboValue $x
                if ($null -eq $v) { Set-AkariCardControl $x $x.Shown } else { Set-AkariChoiceTarget ([string]$s.Tag) $v }
            })
        }
        default { $e.Control.Add_Click({ param($s, $a) Step-AkariSwitch ([string]$s.Tag) }) }
    }
    $e
}

# a switch or checkbox was clicked: move it to its next target, after a confirmation when one is needed
function Step-AkariSwitch([string]$Id) {
    $e = $script:CardEntries[$Id]
    if ($e.Muted) { return }
    $t = $e.Tweak
    if ($t.Kind -eq 'Action') {
        $next = if ($e.Control.IsChecked) { 'Optimized' } else { 'None' }
        $prev = if ($next -eq 'Optimized') { 'None' } else { 'Optimized' }
    } else {
        $prev = $e.Shown
        $next = Get-AkariNextToggle $e.State $prev
    }
    $q = Get-AkariConfirmText $t $next
    if ($q -and [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -ne 'Yes') { $next = $prev }
    Set-AkariCardControl $e $next
    Set-AkariPending $script:Sel $t $e.State $next
    Update-AkariStepFooter
}

function Set-AkariChoiceTarget([string]$Id, $Value) {
    $e = $script:CardEntries[$Id]
    if ($e.Muted -or (Test-AkariRegMatch $Value $e.Shown)) { return }
    $q = Get-AkariConfirmText $e.Tweak $Value
    if ($q -and [Windows.MessageBox]::Show($q, 'Akari', 'YesNo', 'Warning') -ne 'Yes') { Set-AkariCardControl $e $e.Shown; return }
    $e.Shown = $Value
    Set-AkariPending $script:Sel $e.Tweak $e.State $Value $e.Current
    Update-AkariStepFooter
}

# builds the Tweaks view once: a heading per Section, an expander per Category, a card per Tweak
function Get-AkariTweaksView {
    if ($script:TweaksView) { return $script:TweaksView }
    $view = [Windows.Controls.StackPanel]::new()
    foreach ($g in Get-AkariStepGroups $script:Tweaks) {
        $h = New-AkariText $g.Header 20
        $h.FontWeight = 'SemiBold'
        $h.Margin = [Windows.Thickness]::new(0, 8, 0, 12)
        [void]$view.Children.Add($h)
        foreach ($c in $g.Categories) {
            $x = [Windows.Controls.Expander]::new()
            $x.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Section')
            $x.Header = $c.Name
            $x.Tag = $h
            $p = [Windows.Controls.StackPanel]::new()
            foreach ($id in $c.Ids) {
                $t = $script:Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                $e = New-AkariCardEntry $t
                $script:CardEntries[$id] = $e
                [void]$p.Children.Add($e.Card)
            }
            $x.Content = $p
            [void]$view.Children.Add($x)
        }
    }
    $script:TweaksView = $view
    $view
}

# header search on the Tweaks step: hide cards that don't match, then empty Categories and Sections
function Set-AkariTweaksFilter([string]$q) {
    if (-not $script:TweaksView) { return }
    foreach ($e in $script:CardEntries.Values) {
        $hit = (-not $q) -or ("$($e.Tweak.Name) $($e.Tweak.Description)" -like "*$q*")
        $e.Card.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
    }
    $heads = @{}
    foreach ($x in @($script:TweaksView.Children | Where-Object { $_ -is [Windows.Controls.Expander] })) {
        $any = @($x.Content.Children | Where-Object { $_.Visibility -eq 'Visible' }).Count -gt 0
        $x.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
        if ($any) { $heads[$x.Tag.GetHashCode()] = $true }
    }
    foreach ($h in @($script:TweaksView.Children | Where-Object { $_ -is [Windows.Controls.TextBlock] })) {
        $h.Visibility = if ($heads.ContainsKey($h.GetHashCode())) { 'Visible' } else { 'Collapsed' }
    }
}

function Update-AkariStepFooter {
    $n = $script:Sel.Count
    $StepBack.Visibility = if ($script:Step -gt 0) { 'Visible' } else { 'Hidden' }
    switch ($script:Step) {
        0 { $StepNext.Content = 'Next'; $StepNext.IsEnabled = $true }
        1 { $StepNext.Content = "Review ($n)"; $StepNext.IsEnabled = ($n -gt 0) }
        2 { $StepNext.Content = 'Apply'; $StepNext.IsEnabled = ($n -gt 0) }
        3 { $StepNext.Content = 'Done'; $StepNext.IsEnabled = $true; $StepBack.Visibility = 'Hidden' }
    }
}

function Show-AkariSteps {
    $StepDots.Children.Clear()
    for ($i = 0; $i -lt 3; $i++) {
        $d = [Windows.Shapes.Ellipse]::new()
        $d.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'StepDot')
        if ($i -eq [math]::Min($script:Step, 2)) { $d.Tag = 'Current' }
        [void]$StepDots.Children.Add($d)
    }
    $label = if ($script:Step -eq 3) { 'Done' } else { "Step $($script:Step + 1) of 3: $($AkariStepNames[$script:Step])" }
    $title = New-AkariText $label 13 'Mu'
    $title.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $title.VerticalAlignment = 'Center'
    [void]$StepDots.Children.Add($title)
    # the Tweaks view is cached: detach it before clearing, so it can be added again
    if ($script:TweaksView -and $script:TweaksView.Parent) { $script:TweaksView.Parent.Children.Remove($script:TweaksView) }
    $StepBody.Children.Clear()
    switch ($script:Step) {
        0 { [void]$StepBody.Children.Add((New-AkariText 'App removal comes in a later version. Select Next to choose Tweaks.' 14 'Mu')) }
        1 {
            [void]$StepBody.Children.Add((Get-AkariTweaksView))
            Set-AkariTweaksFilter $Search.Text.Trim()
        }
        2 {
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

function Start-AkariApply {
    if ($script:Busy -or -not $script:Sel.Count) { return }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{ Plan = @(Get-AkariPlanItems $script:Sel); SkipRestore = $script:RestoreDone })
    # the job loads the tweaks itself: a script block must not cross runspaces
    $code = @"
`$root = $(& $q "$Root\Tweaks")
`$all = @((Get-AkariTweaks `$root).Tweaks) + @(Import-AkariLegacyTweaks `$root)
if (-not `$AkariShared.SkipRestore) {
    `$AkariShared.Restore = New-AkariRestorePoint 'Akari'
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

# Done: forget the Selection, read every State again, back to the Tweaks step
function Reset-AkariSteps {
    $script:Sel = New-AkariSelection
    $script:CardEntries = [ordered]@{}
    $script:TweaksView = $null
    $script:Outcomes = @()
    $script:Step = 1
    Show-AkariSteps
}
