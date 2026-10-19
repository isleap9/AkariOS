$Root = Split-Path $PSScriptRoot

Describe 'Get-AkariStepGroups' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    . "$Root\UI\Steps.ps1"
    function T($id, $sec, $cat, $kind = 'Toggle', $legacy = $false) {
        ConvertTo-AkariTweak @{ Id = $id; Name = $id; Section = $sec; Category = $cat; Kind = $kind; Risk = 'Safe' } 'x' $legacy
    }
    $list = @(
        T 'w1' 'Windows' '' 'Toggle' $true
        T 'w2' 'Windows' '' 'Action' $true
        T 'a1' 'Advanced' '' 'Toggle' $true
        T 'a2' 'Advanced' 'Tuning' 'Choice'
        T 'h1' 'Hardware' 'Devices'
        T 'o2' 'Optimize' 'Performance'
        T 'o1' 'Optimize' 'Gaming'
        T 'o3' 'Optimize' 'Gaming' 'Action'
        T 'g1' 'Graphics' '' 'Group' $true
    )
    $g = @(Get-AkariStepGroups $list)

    It 'orders Sections: Optimize, Customize, Hardware, Advanced, then the rest' {
        ($g | ForEach-Object { $_.Section }) -join ',' | Should Be 'Optimize,Hardware,Advanced,Windows'
    }

    It 'shows Hardware as Graphics & Hardware' {
        ($g | Where-Object { $_.Section -eq 'Hardware' }).Header | Should Be 'Graphics & Hardware'
    }

    It 'sorts Categories and puts legacy under Not yet ported, last' {
        (($g | Where-Object { $_.Section -eq 'Advanced' }).Categories | ForEach-Object { $_.Name }) -join ',' | Should Be 'Tuning,Not yet ported'
        (($g | Where-Object { $_.Section -eq 'Optimize' }).Categories | ForEach-Object { $_.Name }) -join ',' | Should Be 'Gaming,Performance'
    }

    It 'keeps one-file Toggles, Choices and Actions, and only legacy Toggles' {
        $ids = @($g | ForEach-Object { $_.Categories } | ForEach-Object { $_.Ids }) | Sort-Object
        $ids -join ',' | Should Be 'a1,a2,h1,o1,o2,o3,w1'
    }
}

Describe 'Manual steps (in memory, no window)' {
    $probe = "$TestDrive\steps.ps1"
    Set-Content $probe -Value @'
param($Root, $Key)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariStatePath = "$env:TEMP\akari-steps-test-state.json"
foreach ($f in 'Log', 'Registry', 'Loader', 'State') { . "$Root\Core\$f.ps1" }
$LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:Tweaks = @(
    ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'T'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Kind = 'Choice'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'C'; Type = 'DWord' }; Recommended = 0x26; Default = 2; Editable = $true
        Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }) } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'leg'; Name = 'Leg'; Description = 'D'; Section = 'Windows'; Category = ''; Risk = 'Safe'; Apply = { }; Revert = { } } 'x' $true
)
foreach ($f in 'Selection', 'Cards', 'Steps') { . "$Root\UI\$f.ps1" }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$res.Resources['Icons'] = [Windows.Media.FontFamily]::new('Segoe MDL2 Assets')
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
[void]$res.Children.Add($StepDots); [void]$res.Children.Add($StepBody)
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new()
$Search = [Windows.Controls.TextBox]::new()
Show-AkariSteps
"s0next=$($StepNext.Content)"; "s0back=$($StepBack.Visibility)"
$script:Step = 1; Show-AkariSteps
"s1next=$($StepNext.Content)"; "s1enabled=$($StepNext.IsEnabled)"; "cards=$($script:CardEntries.Count)"
"legThree=$($script:CardEntries['leg'].Control.IsThreeState)"
Step-AkariSwitch 'tog'
"togOn=$($script:CardEntries['tog'].Control.IsChecked)"; "s1after=$($StepNext.Content)"
Set-AkariChoiceTarget 'ch' 0x28
$Search.Text = 'Ch'; Set-AkariTweaksFilter 'Ch'
"togHidden=$($script:CardEntries['tog'].Card.Visibility)"
$script:Step = 2; Show-AkariSteps
"review=$($StepBody.Children.Count)"
"plan=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id + ':' + $_.Mode }) -join ',')"
$script:Step = 1; Show-AkariSteps
"reattached=$($StepBody.Children.Count)"
"untouched=$($null -eq (Get-AkariRegValue $Key 'T'))"
'@
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $out = @{}
    try {
        & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Key $k 2>&1 | ForEach-Object {
            $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'starts on Apps with Next and no Back' {
        $out.s0next | Should Be 'Next'
        $out.s0back | Should Be 'Hidden'
    }
    It 'shows a card per Tweak and disables Review at 0 changes' {
        $out.cards | Should Be '3'
        $out.s1next | Should Be 'Review (0)'
        $out.s1enabled | Should Be 'False'
        $out.legThree | Should Be 'True'
    }
    It 'counts a switch flip' {
        $out.togOn | Should Be 'True'
        $out.s1after | Should Be 'Review (1)'
    }
    It 'filters cards by search' { $out.togHidden | Should Be 'Collapsed' }
    It 'reviews both changes and plans them in order' {
        $out.review | Should Be '2'
        $out.plan | Should Be 'tog:Apply,ch:Apply'
    }
    It 'shows the cached Tweaks view again after Review' { $out.reattached | Should Be '1' }
    It 'changes nothing while choosing' { $out.untouched | Should Be 'True' }
}

Describe 'Get-AkariRunSummary' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    . "$Root\UI\Steps.ps1"
    function O($o, $r = $false) { [pscustomobject]@{ Id = 'x'; Outcome = $o; Reboot = $r; Message = '' } }

    It 'counts an all-Applied Run' {
        $s = Get-AkariRunSummary @((O 'Applied'), (O 'Applied'))
        $s.Text | Should Be '2 applied'
        $s.Reboot | Should Be $false
    }

    It 'counts a Run with one Failed, in Glossary order' {
        (Get-AkariRunSummary @((O 'Failed'), (O 'Reverted'), (O 'Applied'))).Text | Should Be '1 applied, 1 reverted, 1 failed'
    }

    It 'flags a reboot' { (Get-AkariRunSummary @((O 'Applied' $true), (O 'Already'))).Reboot | Should Be $true }
}

Describe 'Apply from Review (fake id, no restore point, no window)' {
    $probe = "$TestDrive\apply.ps1"
    Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariStatePath = "$env:TEMP\akari-apply-test-state.json"
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Root\Core\$f.ps1" }
$LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
$fake = ConvertTo-AkariTweak @{ Id = 'zz-fake-id'; Name = 'Fake'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Apply = { }; Revert = { } } 'x' $false
$script:Tweaks = @($fake)
foreach ($f in 'Selection', 'Cards', 'Steps') { . "$Root\UI\$f.ps1" }
$script:Busy = $false; $script:Queue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
function Set-Busy($b, $l) { $script:Busy = $b }
function Add-Log($m) { }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
[void]$res.Children.Add($StepDots); [void]$res.Children.Add($StepBody)
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new(); $Search = [Windows.Controls.TextBox]::new()

# restore point failed and the user says No: nothing runs, Review stays
function Confirm-AkariNoRestore($m) { $script:asked = $m; $false }
Set-AkariPending $script:Sel $fake 'Default' 'Optimized'
$script:Step = 2
Complete-AkariApply ([hashtable]::Synchronized(@{ Restore = [pscustomobject]@{ Ok = $false; Message = 'protection off' } }))
"asked=$script:asked"; "stayed=$script:Step"; "restoreDone=$script:RestoreDone"

# the real job, restore point skipped, plan = one fake id
$script:RestoreDone = $true
Start-AkariApply
"busy=$script:Busy"; "kind=$($script:Job.Kind)"
"ended=$($script:Job.Handle.AsyncWaitHandle.WaitOne(60000))"
$script:Job.Ps.EndInvoke($script:Job.Handle); $script:Job.Ps.Dispose(); $script:Job.Rs.Dispose()
Complete-AkariApply $script:Job.Shared
"step=$script:Step"; "outcome=$($script:Outcomes[0].Outcome)"; "msg=$($script:Outcomes[0].Message)"
Show-AkariSteps
"resultCards=$($StepBody.Children.Count)"; "next=$($StepNext.Content)"
Reset-AkariSteps
"afterDone=$script:Step"; "selCount=$($script:Sel.Count)"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'asks when the restore point fails, and No changes nothing' {
        $out.asked | Should Be 'protection off'
        $out.stayed | Should Be '2'
        $out.restoreDone | Should Be 'False'
    }
    It 'starts one Apply job' {
        $out.busy | Should Be 'True'
        $out.kind | Should Be 'Apply'
        $out.ended | Should Be 'True'
    }
    It 'shows the Outcomes from the job' {
        $out.step | Should Be '3'
        $out.outcome | Should Be 'Failed'
        $out.msg | Should Be 'Unknown tweak id'
        $out.resultCards | Should Be '2'
        $out.next | Should Be 'Done'
    }
    It 'Done clears the Selection and goes back to Tweaks' {
        $out.afterDone | Should Be '1'
        $out.selCount | Should Be '0'
    }
}
