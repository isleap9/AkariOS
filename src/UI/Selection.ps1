# Selection: the pending changes chosen in the Manual steps. Nothing is applied until Review & Apply.
# Pure PowerShell (no WPF), so it is tested on its own. Needs Core/Registry.ps1 (Test-AkariRegMatch, Resolve-AkariDefault).

$AkariRiskRank = @{ Safe = 0; Caution = 1; Advanced = 2 }

# keyed by Tweak id; insertion order is the Review order
function New-AkariSelection { [ordered]@{} }

function Get-AkariChoiceLabel($Tweak, $Value) {
    $c = $Tweak.Choices | Where-Object { Test-AkariRegMatch $Value $_.Value } | Select-Object -First 1
    if ($c -and $c.Label) { return $c.Label }
    "$Value"
}

# $Target: 'Optimized', 'Default' or 'None' (no change) for a Toggle or Action; a value for a Choice.
# $Current: a Choice's current registry value.
function Set-AkariPending($Sel, $Tweak, [string]$State, $Target, $Current = $null) {
    $id = $Tweak.Id
    if ($Sel.Contains($id)) { $Sel.Remove($id) }
    if ("$Target" -eq 'None') { return }
    $item = @{ Id = $id; Name = $Tweak.Name }
    switch ($Tweak.Kind) {
        'Choice' {
            if ($null -ne $Current -and (Test-AkariRegMatch $Current $Target)) { return }
            $def = Resolve-AkariDefault $Tweak.Default
            $item.From = if ($State -eq 'Default') { 'Default' } elseif ($null -ne $Current) { Get-AkariChoiceLabel $Tweak $Current } else { 'State unknown' }
            if (Test-AkariRegMatch $Target $def) { $item.Mode = 'Revert'; $item.To = 'Default' }
            else {
                $item.Mode = 'Apply'
                $item.To = Get-AkariChoiceLabel $Tweak $Target
                if (-not (Test-AkariRegMatch $Target $Tweak.Recommended)) { $item.Value = $Target }
            }
        }
        'Action' {
            # the Action's button word: Run, Remove, Install
            $item.Mode = 'Apply'; $item.From = ''; $item.To = $(if ($Tweak.Button) { $Tweak.Button } else { 'Run' })
        }
        default {
            if ($Target -eq $State) { return }
            $item.Mode = if ($Target -eq 'Optimized') { 'Apply' } else { 'Revert' }
            $item.From = if ($State -eq 'Unknown') { 'State unknown' } else { $State }
            $item.To = $Target
        }
    }
    $Sel[$id] = $item
}

# Hidden: a change to a Tweak the Guided steps don't show (Guided = $false), from a preset or an imported file;
# Review lists those under their own heading
function Get-AkariReviewItems($Sel) {
    foreach ($i in $Sel.Values) { [pscustomobject]@{ Id = $i.Id; Name = $i.Name; From = $i.From; To = $i.To; Hidden = [bool]$i.Hidden } }
}

# the Review note about changes that restart the PC (Test-AkariRestarts, Core\Runner.ps1: they run last), or $null.
# Two or more can't all run in one go: only the first does before the restart. Pure, no WPF.
function Get-AkariRestartNote($Sel, $Tweaks) {
    $names = @(foreach ($i in $Sel.Values) {
        $t = $Tweaks | Where-Object { $_.Id -eq $i.Id } | Select-Object -First 1
        if ($t -and (Test-AkariRestarts $t $i.Mode)) { $i.Name }
    })
    if (-not $names.Count) { return $null }
    if ($names.Count -eq 1) { return "$($names[0]) restarts the PC (into Safe Mode for some), so it runs last, after every other change." }
    "These restart the PC: $($names -join ', '). Only $($names[0]) runs now, last; the others are skipped: select them again after the restart."
}

# items for Invoke-AkariPlan
function Get-AkariPlanItems($Sel) {
    foreach ($i in $Sel.Values) {
        $p = @{ Id = $i.Id; Mode = $i.Mode }
        if ($i.ContainsKey('Value')) { $p.Value = $i.Value }
        $p
    }
}

# the question to ask before selecting $Target, or $null when none is needed
function Get-AkariConfirmText($Tweak, $Target) {
    if ($Tweak.Kind -eq 'Choice') {
        if (Test-AkariRegMatch $Target (Resolve-AkariDefault $Tweak.Default)) { return $null }
        $c = $Tweak.Choices | Where-Object { Test-AkariRegMatch $Target $_.Value } | Select-Object -First 1
        if ($c -and $c.Risk -and $AkariRiskRank[$c.Risk] -gt $AkariRiskRank[$Tweak.Risk]) {
            return "$($Tweak.Name): '$(Get-AkariChoiceLabel $Tweak $Target)' is marked $($c.Risk). Select it anyway?"
        }
    } elseif ($Target -ne 'Optimized') { return $null }
    if ($Tweak.Confirm) { return $Tweak.Confirm }
    if ($Tweak.Risk -eq 'Advanced') { return "$($Tweak.Name) is an Advanced tweak and can break things if you don't know what it does. Select it anyway?" }
    $null
}

# a checkbox's target, Win11Debloat's model: checked = Optimized; unchecking a box that started checked
# (its State was Optimized) = Default; a box that started unchecked and is unchecked = no change.
function Get-AkariCheckTarget([bool]$Checked, [string]$Initial) {
    if ($Checked) { return 'Optimized' }
    if ($Initial -eq 'Optimized') { return 'Default' }
    'None'
}
