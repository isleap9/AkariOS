$Root = Join-Path (Split-Path $PSScriptRoot) 'src'

Describe 'Get-AkariStepGroups' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    $AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
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
        T 'oc1' 'OneClick' 'Finish' 'Action'
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

    It 'hides a legacy Toggle listed in Ported.psd1' {
        $ids = @(Get-AkariStepGroups $list @{ 'w1' = @('o1') } | ForEach-Object { $_.Categories } | ForEach-Object { $_.Ids }) | Sort-Object
        $ids -join ',' | Should Be 'a1,a2,h1,o1,o2,o3'
    }

    Context 'Requires on Windows 10' {
        function Test-AkariRequirement($t) { if ($t.Requires -contains 'Win11') { 'needs Win11' } }
        $req = @($list) + @(ConvertTo-AkariTweak @{ Id = 'w11'; Name = 'w11'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Requires = 'Win11' } 'x' $false)
        It 'hides a Tweak whose Requires this PC does not meet' {
            $ids = @(Get-AkariStepGroups $req | ForEach-Object { $_.Categories } | ForEach-Object { $_.Ids })
            $ids -contains 'w11' | Should Be $false
            $ids -contains 'o1' | Should Be $true
        }
    }
}

Describe 'Manual steps (in memory, no window)' {
    $probe = "$TestDrive\steps.ps1"
    Set-Content $probe -Value @'
param($Root, $Key)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariStatePath = "$env:TEMP\akari-steps-test-state.json"
$AkariLogFile = "$env:TEMP\akari-steps-test\akari.log"
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'Presets') { . "$Root\Core\$f.ps1" }
$LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
New-Item $Key -Force | Out-Null; New-ItemProperty $Key -Name 'O' -Value 0 -PropertyType DWord | Out-Null
$script:Tweaks = @(
    ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'T'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    # already Optimized on this "PC" (the test key): starts checked
    ConvertTo-AkariTweak @{ Id = 'opt'; Name = 'Opt'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'O'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Kind = 'Choice'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'C'; Type = 'DWord' }; Recommended = 0x26; Default = 2; Editable = $true
        Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }) } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'leg'; Name = 'Leg'; Description = 'D'; Section = 'Windows'; Category = ''; Risk = 'Safe'; Apply = { }; Revert = { } } 'x' $true
)
$AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
$env:AKARI_MOTION = 'off'; . "$Root\UI\Motion.ps1"
foreach ($f in 'Selection', 'Catalogue', 'Cards', 'Apps', 'Steps', 'Pages') { . "$Root\UI\$f.ps1" }
. "$Root\..\tests\ShellStub.ps1"
# no real AppX read in tests: no app installed, no data-list Group
function Get-AkariAppxInstalled { @() }; function Get-AkariAppxPackages { @() }; function Start-AkariFeatureRead { }; $script:Groups = @()
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Theme.Dark.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Controls.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Icons.xaml"))
[void]$res.Children.Add($StepBody)
function Click($b) { $b.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)) }
$script:Cat = 'Install AkariOS'; Show-Page
$tiles = $StepBody.Children[1]
"chooser=$($tiles.Children.Count)|$($Heading.Text)|$($StepFooter.Visibility)|$($tiles.Children[0].BorderBrush -eq $res.FindResource('Acc'))"
"chooserParts=$(($StepBody.Children | ForEach-Object { $_.GetType().Name }) -join ',')|$($StepBody.Children[4].Tag)"
# One-click: declined, then accepted (Start-Process and the window are stubs: nothing is launched)
$realRoot = $Root; $Root = 'X:\Akari'
function Test-Path($p) { $true }
function Write-ErrLog($m) { }
function Start-Process { $script:newWindow = $true }
function Get-AkariRestoreChoice { $false }
$window = [pscustomobject]@{}; $window | Add-Member ScriptMethod Close { $script:closed = $true }
function Confirm-AkariOneClick { $script:Chassis = $args[0]; $false }
function Get-AkariChassis { 'Laptop' }
Click $tiles.Children[0]
"declinedLaunch=$([bool]$script:OneClickPath)|$script:Chassis"
function Confirm-AkariOneClick { $true }
# the browser question: Helium (recommended) first, then by name, No browser last; cancelled = nothing launched
$hold = $script:Tweaks
$script:Tweaks = @($hold) + @(
    ConvertTo-AkariTweak @{ Id = 'install-vivaldi'; Name = 'Vivaldi'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; AppType = 'Browsers'; Apply = { } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'install-helium'; Name = 'Helium'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; AppType = 'Browsers'; Apply = { } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'install-brave'; Name = 'Brave'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; AppType = 'Browsers'; Apply = { } } 'x' $false)
function Select-AkariChoice { $script:Asked = $args[1] -join ','; $null }
Click $tiles.Children[0]
"browserCancel=$script:Asked|$([bool]$script:OneClickPath)"
function Select-AkariChoice { 2 }
Click $tiles.Children[0]
$script:Tweaks = $hold
"launched=$script:OneClickPath"; "closed=$script:closed"; "newWindow=$([bool]$script:newWindow)"; "picks=$script:OneClickBrowser|$script:OneClickChassis"
Remove-Item Function:\Test-Path; $Root = $realRoot
Initialize-AkariSteps
Click $tiles.Children[1]
"mode=$script:Mode|$script:Step|$($StepFooter.Visibility)|$($StepNext.Content)|$($StepBack.Content)|$($StepLabel.Text -replace '[^ -~]', '.')|$(@($Crumbs.Children | ForEach-Object { $_.Text }) -join '>')>$($Heading.Text)"
Click $StepNext
"s1=$script:Step|$($StepNext.Content)|$($StepNext.IsEnabled)|$($script:TweakRows.Count)|$($script:TweakCards.Count)|$($StepLabel.Text -replace '[^ -~]', '.')|$($StepBack.Content)"
$hdr = $StepBody.Children[0]
"stepper=$(@($hdr.Children | Where-Object { $_ -is [Windows.Controls.StackPanel] } | ForEach-Object { $c = $_.Children[0]; "$($_.Tag):$(if ($c.Child -is [Windows.Controls.TextBlock]) { $c.Child.Text } else { 'check' }):$($_.Children[1].Text)" }) -join '|')"
"legStart=$($script:TweakRows['leg'].Control.IsChecked)"; "optStart=$($script:TweakRows['opt'].Control.IsChecked)"
"counts=$(($script:TweakCards | ForEach-Object { $_.Count.Text }) -join ',')"
$script:TweakRows['tog'].Control.IsChecked = $true; Step-AkariCheck 'tog'
$script:TweakRows['opt'].Control.IsChecked = $false; Step-AkariCheck 'opt'
"s1after=$($script:Sel.Count)|$(($script:TweakCards | ForEach-Object { $_.Count.Text }) -join ',')"
Set-AkariChoiceTarget 'ch' 0x28
# Show current state off: every row unchecked, the Selection emptied
$script:UseState = $false; Reset-AkariTweakRows
"plainOpt=$($script:TweakRows['opt'].Control.IsChecked)"; "plainSel=$($script:Sel.Count)"
$script:UseState = $true; Reset-AkariTweakRows
"backOpt=$($script:TweakRows['opt'].Control.IsChecked)"
$script:TweakRows['tog'].Control.IsChecked = $true; Step-AkariCheck 'tog'
$script:TweakRows['opt'].Control.IsChecked = $false; Step-AkariCheck 'opt'
Set-AkariChoiceTarget 'ch' 0x28
# the filter box above the Tweaks: typing hides what doesn't match and opens the Categories that do
$chCard = $script:TweakCards | Where-Object { $_.Ids -contains 'ch' }
$chHead = $chCard.Head; $chHead.IsChecked = $false; $chBefore = [bool]$chHead.IsChecked
$tweakBox = @($script:TweaksView.Children[1].Children | Where-Object { $_ -is [Windows.Controls.Grid] })[0].Children[0]
$tweakBox.Text = 'Ch'
"togHidden=$($script:TweakRows['tog'].Row.Visibility)"; "togCardHidden=$($script:TweakRows['tog'].Card.Visibility)"
"chOpened=$chBefore|$($chHead.IsChecked)|$script:TweaksQuery"
$tweakBox.Text = ''
Click $StepNext
"review=$script:Step|$(($StepBody.Children | ForEach-Object { $_.GetType().Name }) -join ',')|$($StepNext.Content)|$($StepLabel.Text -replace '[^ -~]', '.')"
"sums=$(($StepBody.Children[1].Children | ForEach-Object { $_.Child.Children[0].Text }) -join ',')"
"plan=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id + ':' + $_.Mode }) -join ',')"
Click $StepBack
"reattached=$script:Step|$($StepBody.Children.Count)"
# Back in the title bar walks the steps (the history), Cancel on Apps goes back to the chooser
Click $StepBack; Click $StepBack
"cancel=$script:Mode|$($StepFooter.Visibility)|$($script:History.Count -gt 0)"
"untouched=$($null -eq (Get-AkariRegValue $Key 'T'))"; "optUntouched=$(Get-AkariRegValue $Key 'O')"
'@
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $out = @{}
    try {
        & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Key $k 2>&1 | ForEach-Object {
            $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'opens on the chooser: One-click (recommended) and Guided tiles, the five phases, the warning; no footer' {
        $out.chooser | Should Be '2|Install AkariOS|Collapsed|True'
        $out.chooserParts | Should Be 'TextBlock,UniformGrid,TextBlock,Border,Border|Warn'
    }
    It 'One-click asks first, saying when the PC is a laptop; No launches nothing' { $out.declinedLaunch | Should Be 'False|Laptop' }
    It 'One-click asks for the browser next: Helium (recommended) first, then by name, No browser last; Cancel launches nothing' {
        $out.browserCancel | Should Be 'Helium (recommended),Brave,Vivaldi,No browser|False'
    }
    It 'One-click hands the picked browser and the chassis to the console' { $out.picks | Should Be 'install-vivaldi|Laptop' }
    It 'One-click runs in Akari''s own console, no new window' { $out.newWindow | Should Be 'False' }
    It 'One-click Yes hands the AkariOS preset to the console and closes the window' {
        $out.launched | Should Match 'Presets\\AkariOS\.json'
        $out.closed | Should Be 'True'
    }
    It 'Guided starts on Apps: the footer slides up with Step 1 of 3, Cancel and Next, a breadcrumb' {
        $out.mode | Should Be 'Guided|0|Visible|Next|Cancel|Step 1 of 3 . Apps|Install AkariOS>Apps'
    }
    It 'Tweaks: a row per Tweak in an expander per Category, the step header numbers the steps, Apps done' {
        $out.s1 | Should Be '1|Next|True|4|3|Step 2 of 3 . Tweaks|Back'
        $out.stepper | Should Be 'Done:check:Apps|Current:2:Tweaks|:3:Review & Apply'
    }
    It 'starts an Optimized Tweak checked and an unread one unchecked; each expander says how many are picked' {
        $out.optStart | Should Be 'True'
        $out.legStart | Should Be 'False'
        $out.counts | Should Be '0 of 2,0 of 1,0 of 1'
        $out.s1after | Should Be '2|2 of 2,0 of 1,0 of 1'
    }
    It 'Show current state off starts every row unchecked and empties the Selection' {
        $out.plainOpt | Should Be 'False'
        $out.plainSel | Should Be '0'
        $out.backOpt | Should Be 'True'
    }
    It 'filters rows from its filter box, hides emptied expanders and opens the matching ones' {
        $out.togHidden | Should Be 'Collapsed'
        $out.togCardHidden | Should Be 'Collapsed'
        $out.chOpened | Should Be 'False|True|Ch'
    }
    It 'Review: three summary cards and the changes, Apply n changes; planned in order: Apply, Revert, Choice' {
        $out.review | Should Be '2|StackPanel,UniformGrid,Border,Border,Border|Apply 3 changes|Step 3 of 3 . Review & Apply'
        $out.sums | Should Be '0,0,3'
        $out.plan | Should Be 'tog:Apply,opt:Revert,ch:Apply'
    }
    It 'shows the cached Tweaks view again after Review' { $out.reattached | Should Be '1|2' }
    It 'Cancel on Apps goes back to the chooser' { $out.cancel | Should Be 'Choose|Collapsed|True' }
    It 'changes nothing while choosing' {
        $out.untouched | Should Be 'True'
        $out.optUntouched | Should Be '0'
    }
}

Describe 'Get-AkariRunSummary' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    $AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
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

    It 'says uninstalled for an uninstall' {
        (Get-AkariRunSummary @((O 'Reverted'), (O 'Reverted'), (O 'Skipped')) -Uninstall).Text | Should Be '2 uninstalled, 1 skipped'
    }
}

# winutil W4: what "Uninstall selected" asks. Fake apps.
Describe 'Get-AkariUninstallText' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    $AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
    . "$Root\UI\Steps.ps1"
    function App([string]$Name, $More) { ConvertTo-AkariTweak (@{ Id = $Name; Name = $Name; Section = 'Apps'; Category = 'Install'; Kind = 'Action' } + $More) 'x' $false }
    $steam = App 'Steam' @{ Winget = 'A.Steam'; AppType = 'Game launchers' }
    $vc = App 'Visual C++' @{ Winget = 'A.VC1', 'A.VC2'; AppType = 'Runtimes' }
    $edge = App 'Edge' @{ Winget = 'A.Edge'; RemoveWith = 'remove-edge' }
    $cru = App 'CRU' @{ Apply = { } }

    It 'lists the apps winget uninstalls' {
        $q = Get-AkariUninstallText @($steam)
        $q.Count | Should Be 1
        $q.Text | Should Be "Uninstall these apps?`n`n- Steam"
    }

    It 'warns about runtimes and lists apart what is not uninstalled here, with where to go' {
        $q = Get-AkariUninstallText @($steam, $edge, $vc, $cru)
        $q.Count | Should Be 2
        $q.Text | Should Be ("Uninstall these apps?`n`n- Steam`n- Visual C++`n`nOther apps may need these runtimes.`n`n" +
            "Not uninstalled here:`n- Edge: use Remove apps`n- CRU: use Windows' Installed apps")
    }

    It 'says so when nothing picked can be uninstalled here' {
        $q = Get-AkariUninstallText @($edge)
        $q.Count | Should Be 0
        $q.Text | Should Be "None of these apps can be uninstalled here:`n- Edge: use Remove apps"
    }
}

Describe 'Apply from Review (fake id, no restore point, no window)' {
    $probe = "$TestDrive\apply.ps1"
    Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariStatePath = "$env:TEMP\akari-apply-test-state.json"
$AkariLogFile = "$env:TEMP\akari-apply-test\akari.log"
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Root\Core\$f.ps1" }
$LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
$fake = ConvertTo-AkariTweak @{ Id = 'zz-fake-id'; Name = 'Fake'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Apply = { }; Revert = { } } 'x' $false
$script:Tweaks = @($fake)
$AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
$env:AKARI_MOTION = 'off'; . "$Root\UI\Motion.ps1"
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps', 'Pages') { . "$Root\UI\$f.ps1" }
. "$Root\..\tests\ShellStub.ps1"
# no real AppX read in tests: no app installed, no data-list Group
function Get-AkariAppxInstalled { @() }; function Get-AkariAppxPackages { @() }; function Start-AkariFeatureRead { }; $script:Groups = @()
$script:Busy = $false; $script:Queue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
function Set-Busy($b, $l) { $script:Busy = $b }
function Add-Log($m) { }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Theme.Dark.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Controls.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Icons.xaml"))
[void]$res.Children.Add($StepBody)
$script:Cat = 'Install AkariOS'

# restore point failed and the user says No: nothing runs, Review stays
function Confirm-AkariNoRestore($m) { $script:asked = $m; $false }
Set-AkariPending $script:Sel $fake 'Default' 'Optimized'
$script:Mode = 'Guided'; $script:Step = 2
Complete-AkariApply ([hashtable]::Synchronized(@{ Restore = [pscustomobject]@{ Ok = $false; Message = 'protection off' } }))
"asked=$script:asked"; "stayed=$script:Step"; "restoreDone=$script:RestoreDone"

# the real job, restore point skipped, plan = one fake id: the run page shows its row
$script:RestoreDone = $true
Start-AkariApply
"busy=$script:Busy"; "kind=$($script:Job.Kind)"
"run=$script:Step|$script:Running|$($Heading.Text)|$(@($script:RunItems).Count)|$($script:RunItems[0].Name)|$($script:RunItems[0].Status.Children[-1].Text)"
Update-AkariRunPage @{ Total = 1; Done = 0; Step = 'Fake' }
"working=$($script:RunItems[0].State)|$($script:RunLabel.Text -replace '[^ -~]', '.')"
"ended=$($script:Job.Handle.AsyncWaitHandle.WaitOne(60000))"
$script:Job.Ps.EndInvoke($script:Job.Handle); $script:Job.Ps.Dispose(); $script:Job.Rs.Dispose()
Complete-AkariApply $script:Job.Shared
"step=$script:Step"; "outcome=$($script:Outcomes[0].Outcome)"; "msg=$($script:Outcomes[0].Message)"; "toast=$($script:Toasts[-1][0])"
Show-Page
"result=$($Heading.Text)|$($StepBody.Children[0].Tag)|$($StepBody.Children.Count)|$($StepBody.Children[$StepBody.Children.Count - 1].Children[0].Content)"
Reset-AkariSteps
"afterDone=$script:went,$script:Mode,$script:Step"; "selCount=$($script:Sel.Count)"; "appsCache=$($null -eq $script:AppsView)"
# Last used: only a Guided Run saves it (Remove apps leaves it alone)
function Save-AkariLastUsed($plan) { $script:saved += , $script:Mode }
$script:saved = @()
$script:Mode = 'Guided'
Complete-AkariApply ([hashtable]::Synchronized(@{ Plan = @(@{ Id = 'zz-fake-id'; Mode = 'Apply' }); Outcomes = @([pscustomobject]@{ Id = 'zz-fake-id'; Outcome = 'Applied' }) })) 'Remove'
Complete-AkariApply ([hashtable]::Synchronized(@{ Plan = @(@{ Id = 'zz-fake-id'; Mode = 'Apply' }); Outcomes = @([pscustomobject]@{ Id = 'zz-fake-id'; Outcome = 'Applied' }) }))
"lastUsed=$($script:saved -join ',')"
"activity=$(($script:Activity | ForEach-Object { $_[0] }) -join ',')"
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
    It 'starts one Apply job and shows the run page, a row per change, Waiting then Working' {
        $out.busy | Should Be 'True'
        $out.kind | Should Be 'Apply'
        $out.run | Should Be '3|True|Applying|1|Fake|Waiting'
        $out.working | Should Be 'run|Fake.'
        $out.ended | Should Be 'True'
    }
    It 'shows the result: the InfoBar, the cards, what needs attention, Done' {
        $out.step | Should Be '3'
        $out.outcome | Should Be 'Failed'
        $out.msg | Should Be 'Unknown tweak id'
        $out.toast | Should Be 'All done'
        $out.result | Should Be 'Done|Ok|5|Done'
    }
    It 'Done clears the Selection and goes back Home, with Install AkariOS back on its chooser' {
        $out.afterDone | Should Be 'Home,Choose,0'
        $out.selCount | Should Be '0'
        $out.appsCache | Should Be 'True'
    }
    It 'saves Last used for a Guided Run only, and records each Run in Recent activity' {
        $out.lastUsed | Should Be 'Guided'
        $out.activity | Should Be 'Guided run,Removed 1 app,Guided run'
    }
}

Describe 'Get-AkariFlowStep' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    $AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
    . "$Root\UI\Steps.ps1"
    It 'walks Guided through Apps, Tweaks, Review' {
        Get-AkariFlowStep 'Guided' 0 1 | Should Be 1
        Get-AkariFlowStep 'Guided' 1 1 | Should Be 2
        Get-AkariFlowStep 'Guided' 2 1 | Should BeNullOrEmpty
        Get-AkariFlowStep 'Guided' 0 -1 | Should BeNullOrEmpty
    }
    It 'has no apps flows: Downloads and Remove apps are pages of their own' { @($AkariFlows.Keys) -join ',' | Should Be 'Guided' }
}

Describe 'Optimize Legacy pages' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    $AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
    . "$Root\UI\Steps.ps1"
    function L($id, $page, $name) { ConvertTo-AkariTweak @{ Id = $id; Name = $name; Description = 'D'; Section = $page; Category = ''; Risk = 'Safe'; Apply = { }; Revert = { } } 'x' $true }
    $list = @(
        L 'dark' 'Windows' 'Dark theme'; L 'bios' 'Check' 'BIOS check'; L 'leg-adv' 'Advanced' 'Old advanced'
        ConvertTo-AkariTweak @{ Id = 'tuning'; Name = 'Theme tuning'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Risk = 'Safe'
            Registry = @(@{ Path = 'HKCU:\Software\AkariTest'; Name = 'X'; Type = 'DWord'; Value = 1; Default = 0 }) } 'x' $false
    )
    It 'lists Downloads in the old Installers slot, after Setup' {
        $AkariLegacyPages -join ',' | Should Be 'Check,Refresh,Setup,Downloads,Graphics,Windows,Hardware,Advanced'
    }
    It 'shows only the legacy tweaks of a page (no one-file tweaks)' {
        (Get-AkariLegacyList $list 'Advanced' '' | ForEach-Object { $_.Id }) -join ',' | Should Be 'leg-adv'
    }
    It 'searches legacy tweaks only' {
        (Get-AkariLegacyList $list 'Check' 'theme' | ForEach-Object { $_.Id }) -join ',' | Should Be 'dark'
    }
}

Describe 'Get-AkariInstallCards' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Apps.ps1"
    function I($id, $type, $pkg = $null) { ConvertTo-AkariTweak @{ Id = $id; Name = $id; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; AppType = $type; Package = $pkg } 'x' $false }
    $cards = @(Get-AkariInstallCards @(
        I 'b2' 'Browsers'; I 'b1' 'Browsers'; I 'r1' 'Runtimes'; I 'x1' 'Something new'
        I 'photos' 'Restore removed apps' 'Microsoft.Windows.Photos'; I 'calc' 'Restore removed apps' 'Microsoft.WindowsCalculator'
    ) @('Microsoft.WindowsCalculator'))

    It 'makes a card per kind, in the set order, Other, then the restore card' {
        ($cards | ForEach-Object { $_.Title }) -join ',' | Should Be 'Browsers,Runtimes,Other,Restore removed apps'
    }
    It 'sorts each card by name' { ($cards[0].Items | ForEach-Object { $_.Tweak.Id }) -join ',' | Should Be 'b1,b2' }
    It 'offers to restore only the Store apps missing from the PC' { ($cards[3].Items | ForEach-Object { $_.Tweak.Id }) -join ',' | Should Be 'photos' }
    # winutil W5: AkariOS's eight, System tools / Documents / Network / Home server after Utilities, Languages after Dev tools
    It 'orders the cards as AkariOS''s kinds, then winutil''s new ones' {
        $AkariAppTypes -join ',' | Should Be ('Browsers,Communication,Game launchers,Gaming & hardware,Media,Utilities,System tools,Documents,' +
            'Network & remote,Home server & streaming,Runtimes,Dev tools,Languages & SDKs')
    }
}

Describe 'Get-AkariInstallMark' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Apps.ps1"
    function T($cat, $risk) { ConvertTo-AkariTweak @{ Id = "x-$cat-$risk"; Name = 'x'; Section = 'Apps'; Category = $cat; Kind = 'Action'; Risk = $risk } 'x' $false }

    It 'marks a Caution install: check before installing' {
        $m = Get-AkariInstallMark (T 'Install' 'Caution')
        "$($m.Icon),$($m.Brush),$($m.Tip)" | Should Be 'triangle-alert,Warn,Check before installing: paid, or adds a driver or service'
    }
    It 'leaves a Safe install and every removal unmarked' {
        Get-AkariInstallMark (T 'Install' 'Safe') | Should Be $null
        Get-AkariInstallMark (T 'Remove' 'Caution') | Should Be $null
    }
}

Describe 'App icons' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Apps.ps1"
    $dir = Join-Path $TestDrive 'Apps'
    New-Item $dir -ItemType Directory -Force | Out-Null
    foreach ($n in 'Akari.Test.Pkg', 'install-test', 'install-black.mono') { Set-Content "$dir\$n.png" -Value 'png' }

    It 'takes an installed Store app''s own logo first' {
        Get-AkariAppIconFile @{ Id = 'appx/Akari.Test.Pkg'; Package = 'Akari.Test.Pkg' } @{ 'Akari.Test.Pkg' = 'C:\logo.png' } $dir | Should Be 'C:\logo.png'
    }
    It 'else the bundled icon of its package, then of its id' {
        Get-AkariAppIconFile @{ Id = 'store/Akari.Test.Pkg'; Package = 'Akari.Test.Pkg' } @{} $dir | Should Be "$dir\Akari.Test.Pkg.png"
        Get-AkariAppIconFile @{ Id = 'install-test' } $null $dir | Should Be "$dir\install-test.png"
    }
    It 'finds a black-or-white logo''s mask' { Get-AkariAppIconFile @{ Id = 'install-black' } @{} $dir | Should Be "$dir\install-black.mono.png" }
    It 'else none (the row shows the box placeholder)' { Get-AkariAppIconFile @{ Id = 'install-other'; Package = 'Akari.Other' } @{} $dir | Should Be $null }

    # build\AppIcons.ps1 makes them: run it after adding an app. More Clock Tool, the braille driver and six of
    # winutil's apps (lazygit, fnm, JPEGView, K-Lite, Policy Plus, PuTTY) have no usable logo: they keep the box placeholder.
    It 'has a bundled icon for every app to install, legacy app and Store app to restore' {
        $none = 'install-more-clock-tool', 'remove-brlapi', 'install-lazygit', 'install-fnm', 'install-jpegview', 'install-k-lite-codecs', 'install-policy-plus', 'install-putty'
        $ids = @(Get-ChildItem "$Root\Tweaks\Apps\Install\*.ps1", "$Root\Tweaks\Apps\Remove\*.ps1" | ForEach-Object {
            $text = Get-Content $_.FullName -Raw
            if ($text -notmatch 'EntryKind' -and $text -match "Id\s*=\s*'([^']+)'") { $Matches[1] }
        })
        $ids += @((Import-PowerShellDataFile "$Root\Tweaks\Apps\Install\StoreApps.psd1").Rows | ForEach-Object { $_.Name })
        $ids.Count | Should BeGreaterThan 80
        @($ids | Where-Object { $_ -notin $none -and -not (Test-Path "$Root\Assets\Apps\$_.png") -and -not (Test-Path "$Root\Assets\Apps\$_.mono.png") }) -join ', ' | Should Be ''
    }
}

Describe 'Test-AkariWhiteLogo' {
    Add-Type -AssemblyName PresentationCore
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Apps.ps1"
    # a 4 x 4 image: a clear border around a 2 x 2 middle of one colour
    function Img([byte]$R, [byte]$G, [byte]$B) {
        $px = [byte[]]::new(64)
        foreach ($i in 5, 6, 9, 10) { $px[$i * 4] = $B; $px[$i * 4 + 1] = $G; $px[$i * 4 + 2] = $R; $px[$i * 4 + 3] = 255 }
        [Windows.Media.Imaging.BitmapSource]::Create(4, 4, 96, 96, [Windows.Media.PixelFormats]::Bgra32, $null, $px, 16)
    }
    It 'is true for a white glyph (drawn in the text colour)' { Test-AkariWhiteLogo (Img 250 250 250) | Should Be $true }
    It 'is false for a coloured or dark logo' {
        Test-AkariWhiteLogo (Img 0 120 215) | Should Be $false
        Test-AkariWhiteLogo (Img 40 40 40) | Should Be $false
    }
}

Describe 'Risk marks' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Apps.ps1"
    It 'are badges for Caution and Advanced, none for Safe (recommended), each with its meaning' {
        foreach ($k in 'Safe', 'Caution', 'Advanced') { $AkariAppDots[$k].Label | Should Not BeNullOrEmpty }
    }
}

Describe 'Get-AkariAppList' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Apps.ps1"
    $g = ConvertTo-AkariTweak @{ Id = 'appx'; Kind = 'Group'; Name = 'G'; Section = 'Apps'; Category = 'Remove'; Risk = 'Caution'; EntryKind = 'AppxRemove' } 'x' $false
    $tweaks = @(
        New-AkariEntry $g @{ Name = 'Akari.Test.Zed'; Display = 'Zed'; Risk = 'Safe' }
        New-AkariEntry $g @{ Name = 'Akari.Test.Alpha'; Display = 'Alpha'; Risk = 'Advanced'; Keep = $true }
        ConvertTo-AkariTweak @{ Id = 'other'; Name = 'Other' } 'x' $false
    )
    $list = @(Get-AkariAppList $tweaks @($g) @('Akari.Test.Zed', 'Akari.Test.Extra'))

    It 'lists the data file apps plus installed apps it does not know, by name' {
        ($list | ForEach-Object { $_.Tweak.Name }) -join ',' | Should Be 'Akari.Test.Extra,Alpha,Zed'
    }
    It 'marks what is installed' {
        ($list | ForEach-Object { "$($_.Installed)" }) -join ',' | Should Be 'True,False,True'
    }
    It 'builds an unknown installed app as an optional Entry of the Group' {
        $list[0].Tweak.Id | Should Be 'appx/Akari.Test.Extra'
        $list[0].Tweak.Risk | Should Be 'Caution'
    }
}

Describe 'Apps pages (in memory, no window, fake packages)' {
    $probe = "$TestDrive\apps.ps1"
    Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariLogFile = "$env:TEMP\akari-apps-test\akari.log"
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Root\Core\$f.ps1" }
$LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
$g = ConvertTo-AkariTweak @{ Id = 'appx'; Kind = 'Group'; Name = 'G'; Section = 'Apps'; Category = 'Remove'; Risk = 'Caution'; EntryKind = 'AppxRemove' } 'x' $false
$cap = ConvertTo-AkariTweak @{ Id = 'capability'; Kind = 'Group'; Name = 'Optional features'; Section = 'Apps'; Category = 'Remove'; Risk = 'Caution'
    EntryKind = 'CapabilityRemove'; KeepNames = '*WMIC*'; Entries = @(@{ Name = 'App.StepsRecorder'; Display = 'Steps Recorder'; Risk = 'Safe' }) } 'x' $false
$feat = ConvertTo-AkariTweak @{ Id = 'feature'; Kind = 'Group'; Name = 'Windows features'; Section = 'Apps'; Category = 'Remove'; Risk = 'Caution'
    EntryKind = 'FeatureDisable'; Entries = @(@{ Name = 'Unused' }) } 'x' $false
$script:Groups = @($g, $cap, $feat)
$script:Tweaks = @(
    New-AkariEntry $g @{ Name = 'Akari.Test.Safe'; Display = 'Safe app'; Description = 'D'; Risk = 'Safe' }
    New-AkariEntry $g @{ Name = 'Akari.Test.Opt'; Display = 'Optional app'; Description = 'D'; Risk = 'Caution' }
    New-AkariEntry $g @{ Name = 'Akari.Test.Kept'; Display = 'Kept app'; Description = 'D'; Risk = 'Advanced'; Keep = $true }
    New-AkariEntry $g @{ Name = 'Akari.Test.Gone'; Display = 'Gone app'; Description = 'D'; Risk = 'Safe' }
    ConvertTo-AkariTweak @{ Id = 'inst'; Name = 'Inst app'; Description = 'D'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Button = 'Install'; Risk = 'Safe'; AppType = 'Game launchers'; Winget = 'Akari.Test.Inst'; Apply = { } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'instc'; Name = 'Paid app'; Description = 'D'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Button = 'Install'; Risk = 'Caution'; AppType = 'Utilities'; Winget = 'Akari.Test.Paid'; Apply = { } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'tools-update-apps'; Name = 'Update all apps'; Description = 'D'; Section = 'Tools'; Category = 'Setup'; Kind = 'Action'; Risk = 'Safe'; Confirm = 'Update every app?'; Apply = { } } 'x' $false
)
$AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
$env:AKARI_MOTION = 'off'; . "$Root\UI\Motion.ps1"
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps', 'Pages') { . "$Root\UI\$f.ps1" }
. "$Root\..\tests\ShellStub.ps1"
# the fake PC has three of the listed apps and one the list doesn't know
function Get-AkariAppxPackages { @() }
function Get-AkariAppxInstalled { @('Akari.Test.Safe', 'Akari.Test.Opt', 'Akari.Test.Kept', 'Akari.Test.Extra') }
# no real feature read: the probe hands fake names to Complete-AkariFeatureRead itself, later
function Start-AkariFeatureRead { }
$script:Busy = $false; $script:Queue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
function Set-Busy($b, $l) { $script:Busy = $b }
function Add-Log($m) { }
function Start-AkariJob($code, $q, $dir, $shared) { @{ Shared = $shared; Code = $code } }
function Confirm-AkariDialog { $script:asked = $args[0]; $script:askedTitle = $args[4]; $script:answer }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Theme.Dark.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Controls.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Icons.xaml"))
[void]$res.Children.Add($StepBody)
$script:Cat = 'Install AkariOS'; $script:Mode = 'Guided'; $script:Step = 0; Show-Page
$p = $script:AppsParts
"rows=$($script:AppRows.Count)"
"visible=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)"
"guidedParts=$($p.RemoveHead.Visibility),$($p.InstallHead.Visibility),$($p.QuickSelect.Visibility),$(($p.Selector.Items.Children | ForEach-Object { $_.Tag }) -join '/')"
Select-AkariApps { param($t) $t.Risk -eq 'Safe' }
"recommended=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')|$($script:AppRows['appx/Akari.Test.Safe'].Row.Background -eq $res.FindResource('AccSoft'))"
Select-AkariApps { param($t) -not $t.Keep }
"removable=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id } | Sort-Object) -join ',')|$($script:AppsStatus.Text)"
Select-AkariApps { param($t) $false }
"cleared=$($script:Sel.Count)"
$e = $script:AppRows['appx/Akari.Test.Opt']; $e.Control.IsChecked = $true; Step-AkariAppCheck 'appx/Akari.Test.Opt'
"review=$((Get-AkariReviewItems $script:Sel | ForEach-Object { $_.Name + ':' + $_.To }) -join ',')"
"badges=$($e.Row.Child.Children[2].Children[0].Tag)|$($null -eq $script:AppRows['appx/Akari.Test.Safe'].Row.Child.Children[2].Children[0].Tag)"
$script:OnlyInstalled = $false; Set-AkariAppsFilter ''
"allVisible=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)"
$p.Filter.Text = 'Optional'
"searched=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)|$script:AppsQuery"
$script:OnlyInstalled = $true; Set-AkariAppsFilter
"onlyKeepsQuery=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)|$script:AppsQuery"
$script:OnlyInstalled = $false; $p.Filter.Text = ''
# the Remove lists: one at a time under the SelectorBar
Show-AkariRemoveList 'Optional features'
"lists=$($p.StoreTable.Card.Visibility),$($p.CapTable.Card.Visibility)"
Show-AkariRemoveList 'Store apps'
# the installs: tickable cards, a Caution one with its warning, reviewed as Install
"source=$(Get-AkariAppSource $script:AppRows['inst'].Tweak)"
"caution=$($script:AppRows['instc'].Caution.ToolTip),$($null -eq $script:AppRows['inst'].Caution)|$(Get-AkariDownloadCategory $script:AppRows['inst'].Tweak),$(Get-AkariDownloadCategory $script:AppRows['instc'].Tweak)"
$e = $script:AppRows['inst']; $e.Control.IsChecked = $true; Step-AkariAppCheck 'inst'
"installReview=$((Get-AkariReviewItems $script:Sel | Where-Object { $_.Id -eq 'inst' } | ForEach-Object { $_.Name + ':' + $_.To }))"
Clear-AkariInstalls
"afterClear=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')"
# app picks survive the Tweaks step: building it, and its Clear selection, only touch the Tweak rows
Select-AkariApps { param($t) $t.Risk -eq 'Safe' }
$script:Step = 1; Show-Page
"keptAfterTweaks=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')"
Reset-AkariTweakRows
"keptAfterClear=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')"
# the features arrive after the AkariOS pick: they get the same pick, the keep-list stays unchecked
"readingTitle=$($p.CapTable.Title.Text)"
Select-AkariApps { param($t) -not $t.Keep }
Complete-AkariFeatureRead @('App.StepsRecorder~~~~0.0.1.0', 'WMIC~~~~') @('WorkFolders-Client')
"titles=$($p.CapTable.Title.Text),$($p.FeatTable.Title.Text)"
"capName=$($script:AppRows['capability/App.StepsRecorder~~~~0.0.1.0'].Tweak.Name)"
"wmic=$($script:AppRows['capability/WMIC~~~~'].Tweak.Keep),$($script:AppRows['capability/WMIC~~~~'].Tweak.Risk)"
"lateSel=$((Get-AkariPlanItems $script:Sel | Where-Object { $_.Id -notlike 'appx/*' } | ForEach-Object { $_.Id } | Sort-Object) -join ',')"
Clear-AkariSteps
# Downloads > Windows apps (the Remove apps page before): the four lists as cards, its own Selection, Remove (n) asks,
# then removes in one job; a removed app that can come back has Install
function Click($b) { $b.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)) }
$script:Cat = 'Remove apps'; Show-Page
$w = $script:Win
"winPage=$script:Cat|$script:DlSection|$($Heading.Text)|$(@($w.Rows.Keys) -join ',')|$($w.Go.IsEnabled)|$($w.Grids['Store apps'].Visibility),$($w.Grids['Legacy apps'].Visibility)"
"winGone=$($w.Rows['appx/Akari.Test.Gone'].Row.Visibility)|$($w.Rows['appx/Akari.Test.Gone'].Act.Children[0].Text)|$($w.Rows['appx/Akari.Test.Gone'].Act.Children[1].Text)"
$e = $w.Rows['appx/Akari.Test.Opt']; Click $e.Row
"winPicked=$($w.Go.IsEnabled),$($w.GoText.Text),$($w.Count.Text)|$($e.Row.BorderThickness.Left)|$($script:WinSel.Contains('appx/Akari.Test.Opt'))|$($script:Sel.Contains('appx/Akari.Test.Opt'))"
$w.Filter.Text = 'Safe'
"winSearch=$(@($w.Rows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)|$($w.Grids['Store apps'].Children.Count)"
$w.Filter.Text = ''
Complete-AkariFeatureRead @('App.StepsRecorder~~~~0.0.1.0') @('WorkFolders-Client')
"winFeatures=$($w.Grids['Optional features'].Tag.Cards.Count),$($w.Grids['Windows features'].Tag.Cards.Count)|$($w.Notes['Optional features'].Text)"
function Get-AkariRestoreChoice { $false }
$script:answer = $false; Start-AkariWindowsRemove
"rmCancel=$($null -eq $script:Job)|$script:askedTitle|$($script:asked -replace "`n", '/')"
$script:answer = $true; Start-AkariWindowsRemove
"rmJob=$($script:Job.Kind),$($script:Job.Shared.Plan[0].Id),$($script:Job.Label)"
# the job got to the first item: its card leaves the list
Update-AkariRemoveProgress @{ Total = 1; Done = 1 }
"rmGone=$script:RemovedCount|$($e.Row.Visibility)|$($e.Gone)"
$script:Busy = $false; $script:Job = $null
Complete-AkariApply ([hashtable]::Synchronized(@{ Plan = @(@{ Id = 'appx/Akari.Test.Opt'; Mode = 'Apply' }); Outcomes = @([pscustomobject]@{ Id = 'appx/Akari.Test.Opt'; Outcome = 'Applied' }) })) 'Remove'
"rmDone=$($script:Toasts[-1][0])|$($script:WinSel.Count)|$($null -eq $script:Win)"
# a removed app's Install: queued as an install, the card "Installing..."; a failure puts the card back
Show-Page
$w = $script:Win
$g = $w.Rows['appx/Akari.Test.Gone']; $g.Restore = Find-AkariTweak 'inst'; Set-AkariWindowsCardAction $g
"restoreBtn=$($g.Act.Children[1].GetType().Name)|$($g.Act.Children[1].Tag)"
Start-AkariWindowsRestore 'appx/Akari.Test.Gone'
"restoring=$($g.Restoring)|$(@($script:InstallQueue) -join ',')|$($script:Job.Kind)|$($script:Job.Shared.Plan[0].Id)"
$script:Busy = $false; $script:Job = $null
Complete-AkariInstall ([hashtable]::Synchronized(@{ Outcomes = @([pscustomobject]@{ Id = 'inst'; Outcome = 'Failed'; Message = 'no network' }) }))
"restoreFailed=$($g.Restoring)|$($g.Act.Children[1].GetType().Name)|$($script:Toasts[-1][0])|$($script:Toasts[-1][1])"
# Downloads > External apps: the store cards by category, Install queued one at a time, the installed ones marked
$script:DlSection = 'External'; Show-Page
"dlPage=$($Heading.Text)|$(@($script:DlCards.Keys) -join ',')|$($script:Job.Kind)"
"dlStart=$($script:DlCards['inst'].Act.Children[1].GetType().Name)|$($script:DlCards['inst'].Act.Children[0].Text)"
$script:Busy = $false; $script:Job = $null
Complete-AkariInstalledRead ([hashtable]::Synchronized(@{ Ids = @('inst') }))
"dlMarked=$($script:DlCards['inst'].State)|$($script:DlCards['instc'].State)|$($script:DlCards['inst'].Check.Visibility)|$($null -ne $script:DlCards['inst'].Row.ContextMenu)"
$script:DlFilter = 'Gaming'; Set-AkariDownloadsFilter $false
"dlGaming=$($script:DlCards['inst'].Row.Visibility),$($script:DlCards['instc'].Row.Visibility)|$($script:DlGrid.Children.Count)|$($script:DlGrid.Children[0].Children.Count)"
$script:DlFilter = 'All'; $script:DlQuery = 'zz'; Set-AkariDownloadsFilter $false
"dlNone=$($script:DlEmpty.Visibility)|$($script:DlEmpty.Tag.Text)"
$script:DlQuery = ''; Set-AkariDownloadsFilter $false
# several at once: a click on a card picks it (an installed one can't be), then Install (n)
Click $script:DlCards['instc'].Row; Click $script:DlCards['inst'].Row
"dlPicked=$($script:DlParts.GoText.Text)|$($script:DlParts.Count.Text)|$($script:DlCards['instc'].Selected),$($script:DlCards['inst'].Selected)|$($script:DlCards['instc'].Row.BorderThickness.Left)"
Install-AkariSelected
"dlInstalling=$($script:DlCards['instc'].State)|$($script:Job.Kind)|$($script:Job.Shared.Plan[0].Id)|$($script:Job.Shared.SkipRestore)|$($script:DlParts.GoText.Text)|$($script:DlCards['instc'].Check.Visibility)"
$script:Busy = $false; $script:Job = $null
Complete-AkariInstall ([hashtable]::Synchronized(@{ Outcomes = @([pscustomobject]@{ Id = 'instc'; Outcome = 'Applied' }) }))
"dlInstalled=$($script:DlCards['instc'].State)|$($script:Activity[-1][0])|$($script:InstallQueue.Count)|$($script:Toasts[-1][0])"
# the way back for a removal (pure): a Store app's Store reinstall by package, a legacy app's install by RemoveWith
$ix = New-AkariRestoreIndex @([pscustomobject]@{ Id = 'store/X'; Group = 'store'; Package = 'Pkg.X' }, [pscustomobject]@{ Id = 'install-od'; RemoveWith = 'apps-remove-onedrive' })
"restoreIx=$((Get-AkariRestoreFor ([pscustomobject]@{ Id = 'appx/pkg.x'; Group = 'appx'; Package = 'pkg.x' }) $ix).Id)|$((Get-AkariRestoreFor ([pscustomobject]@{ Id = 'apps-remove-onedrive' }) $ix).Id)|$($null -eq (Get-AkariRestoreFor ([pscustomobject]@{ Id = 'feature/X'; Group = 'feature' }) $ix))"
"gridCols=$(Get-AkariGridColumns 0 280),$(Get-AkariGridColumns 600 280),$(Get-AkariGridColumns 900 280),$(Get-AkariGridColumns 1000 220)"
# Uninstall (an installed card's menu): asked with the names, one job, the card back to Install
$script:answer = $true; Start-AkariUninstall @($script:DlCards['inst'].Tweak)
"unJob=$($script:Job.Kind),$($script:Job.Shared.Ids -join ','),$($script:asked -replace "`n", '|')"
$script:Busy = $false; $script:Job = $null
Complete-AkariUninstall ([hashtable]::Synchronized(@{ Outcomes = @([pscustomobject]@{ Id = 'inst'; Outcome = 'Reverted'; Reboot = $false; Message = '' }) }))
"unDone=$($script:DlCards['inst'].State)|$($script:Toasts[-1][1])"
# Update all apps: the Tools Tweak, asked with its own Confirm, one job without a restore point
$script:answer = $false; Start-AkariUpdateApps
"upCancel=$($null -eq $script:Job),$script:asked"
$script:answer = $true; Start-AkariUpdateApps
"up=$($script:Job.Shared.Plan[0].Id),$($script:Job.Shared.Plan[0].Mode),$($script:Job.Shared.SkipRestore)"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'Guided''s Apps step: the Remove lists under a SelectorBar with Quick select, then the installs; Only installed hides the missing app' {
        $out.rows | Should Be '7'
        $out.visible | Should Be '6'
        $out.guidedParts | Should Be 'Visible,Visible,Visible,Store apps/Optional features/Windows features/Legacy apps'
    }
    It 'Select recommended checks the installed Safe apps (Win11Debloat), their rows tinted' { $out.recommended | Should Be 'appx/Akari.Test.Safe|True' }
    It 'AkariOS checks every installed app but the keep-list (FR33THY)' { $out.removable | Should Be 'appx/Akari.Test.Extra,appx/Akari.Test.Opt,appx/Akari.Test.Safe|3 selected' }
    It 'Clear empties the Selection' { $out.cleared | Should Be '0' }
    It 'a checked app is reviewed as Remove; a Caution app has its badge, a Safe one none' {
        $out.review | Should Be 'Optional app:Remove'
        $out.badges | Should Be 'Caution|True'
    }
    It 'filters by Only installed and from its filter box, Only installed keeping the typed filter' {
        $out.allVisible | Should Be '7'
        $out.searched | Should Be '1|Optional'
        $out.onlyKeepsQuery | Should Be '1|Optional'
    }
    It 'shows one Remove list at a time' { $out.lists | Should Be 'Collapsed,Visible' }
    It 'installs: tickable cards, the winget id as source, a Caution one marked, reviewed as Install' {
        $out.source | Should Be 'winget: Akari.Test.Inst'
        $out.caution | Should Be 'Check before installing: paid, or adds a driver or service,True|Gaming,Tools'
        $out.installReview | Should Be 'Inst app:Install'
        $out.afterClear | Should Be 'appx/Akari.Test.Opt'
    }
    It 'keeps the app picks when the Tweaks step is built and when its selection is cleared' {
        $out.keptAfterTweaks | Should Be 'appx/Akari.Test.Safe'
        $out.keptAfterClear | Should Be 'appx/Akari.Test.Safe'
    }
    It 'reads the features in the background, then lists them with their names and the keep-list marked' {
        $out.readingTitle | Should Be 'Optional features (reading...)'
        $out.titles | Should Be 'Optional features (2),Windows features (1)'
        $out.capName | Should Be 'Steps Recorder'
        $out.wmic | Should Be 'True,Advanced'
    }
    It 'gives the features that arrive late the last quick select (FR33THY: all but the keep-list)' {
        $out.lateSel | Should Be 'capability/App.StepsRecorder~~~~0.0.1.0,feature/WorkFolders-Client'
    }
    It 'Remove apps opens Downloads > Windows apps: the lists as cards, Remove (n) off at 0' {
        $out.winPage | Should Be 'Downloads|Windows|Downloads|appx/Akari.Test.Extra,appx/Akari.Test.Gone,appx/Akari.Test.Kept,appx/Akari.Test.Opt,appx/Akari.Test.Safe|False|Visible,Collapsed'
        $out.winGone | Should Be "Visible|Removed|Can't be put back here"
    }
    It 'a click on a card ticks its Remove, in Windows apps'' own Selection, outlined in the accent' {
        $out.winPicked | Should Be 'True,Remove (1),1 selected|2|True|False'
    }
    It 'searches Windows apps and lays the shown cards out again' { $out.winSearch | Should Be '1|1' }
    It 'gets the features from the one read, as cards' { $out.winFeatures | Should Be '1,1|' }
    It 'Remove asks with the names; Cancel starts nothing, Remove one job; each card leaves as the job gets to it' {
        $out.rmCancel | Should Be 'True|Remove 1 app?|Optional app./Store apps can be reinstalled from the Microsoft Store or Downloads.'
        $out.rmJob | Should Be 'Remove,appx/Akari.Test.Opt,Removing 1 app'
        $out.rmGone | Should Be '1|Collapsed|True'
        $out.rmDone | Should Be 'Removed|0|True'
    }
    It 'a removed app that can come back has Install: queued with the installs, the card back when it fails' {
        $out.restoreBtn | Should Be 'Button|appx/Akari.Test.Gone'
        $out.restoring | Should Be 'True|inst|Install|inst'
        $out.restoreFailed | Should Be 'False|Button|Inst app was not installed|no network'
    }
    It 'External apps: a store card per install (no Store reinstalls), Install at first, then Installed with its menu' {
        $out.dlPage | Should Be 'Downloads|inst,instc|AppsInstalled'
        $out.dlStart | Should Be 'Button|winget: Akari.Test.Inst'
        $out.dlMarked | Should Be 'Installed||Collapsed|True'
    }
    It 'External apps filters by category and search, one grid row for the shown cards, with an empty state' {
        $out.dlGaming | Should Be 'Visible,Collapsed|1|1'
        $out.dlNone | Should Be 'Visible|No apps match "zz"'
    }
    It 'finds the way back for a removal: the Store reinstall by package, a legacy app''s install, none for a feature' { $out.restoreIx | Should Be 'store/X|install-od|True' }
    It 'fits as many columns of the minimum width as the grid''s width allows' { $out.gridCols | Should Be '1,2,3,4' }
    It 'picks cards with a click (not an installed one); Install (n) queues them, no restore point' {
        $out.dlPicked | Should Be 'Install (1)|1 selected|True,False|2'
        $out.dlInstalling | Should Be 'Installing|Install|instc|True|Install|Collapsed'
        $out.dlInstalled | Should Be 'Installed|Installed Paid app|0|Paid app is installed'
    }
    It 'Uninstall asks with the name, runs one job, and the card goes back to Install' {
        $out.unJob | Should Be 'Uninstall,inst,Uninstall these apps?||- Inst app'
        $out.unDone | Should Be '|1 uninstalled'
    }
    It 'Update all apps asks with the Tweak''s Confirm, then runs it with no restore point' {
        $out.upCancel | Should Be 'True,Update every app?'
        $out.up | Should Be 'tools-update-apps,Apply,True'
    }
}

