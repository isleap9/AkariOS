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
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Root\Core\$f.ps1" }
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
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps') { . "$Root\UI\$f.ps1" }
# no real AppX read in tests: no app installed, no data-list Group
function Get-AkariAppxInstalled { @() }; function Start-AkariFeatureRead { }; $script:Groups = @()
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$res.Resources['Icons'] = [Windows.Media.FontFamily]::new('Segoe MDL2 Assets')
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
[void]$res.Children.Add($StepDots); [void]$res.Children.Add($StepBody)
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new()
$Search = [Windows.Controls.TextBox]::new()
$StepFooter = [Windows.Controls.Border]::new()
$Heading = [Windows.Controls.TextBlock]::new(); $HeaderSub = [Windows.Controls.TextBlock]::new()
Show-AkariSteps
"chooser=$($StepBody.Children[0].Children.Count)"; "oneClick=$($StepBody.Children[0].Children[0].IsEnabled)"; "chooserFooter=$($StepFooter.Visibility)"; "chooserNext=$($StepNext.Visibility)"
# One-click: declined, then accepted (Start-Process and the window are stubs: nothing is launched)
$Root = 'X:\Akari'
function Test-Path($p) { $true }
function Write-ErrLog($m) { }
function Start-Process { $script:newWindow = $true }
$window = [pscustomobject]@{}; $window | Add-Member ScriptMethod Close { $script:closed = $true }
function Confirm-AkariOneClick { $false }
$StepBody.Children[0].Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
"declinedLaunch=$([bool]$script:OneClickPath)"
function Confirm-AkariOneClick { $true }
$StepBody.Children[0].Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
"launched=$script:OneClickPath"; "closed=$script:closed"; "newWindow=$([bool]$script:newWindow)"
Remove-Item Function:\Test-Path
function Select-AkariPage($n) { $script:went = $n }
Initialize-AkariSteps
$StepBack.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
"backTo=$script:went"
# Optimize: the Legacy / Advanced chooser; Legacy opens Check, Back goes Home
$script:Cat = 'Optimize'; Show-AkariOptimizeChooser
"optCards=$($StepBody.Children[0].Children.Count)"; "optEnabled=$($StepBody.Children[0].Children[0].IsEnabled),$($StepBody.Children[0].Children[1].IsEnabled)"
"optHeading=$($Heading.Text)"; "optFooter=$($StepBack.Visibility),$($StepNext.Visibility)"
$StepBody.Children[0].Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
"legacyTo=$script:went"
$StepBack.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
"optBack=$script:went"
$script:Cat = 'Install AkariOS'; Show-AkariSteps
$StepBody.Children[0].Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
"mode=$script:Mode"; "s0next=$($StepNext.Content)"; "s0back=$($StepBack.Visibility)"; "guidedFooter=$($StepFooter.Visibility)"
$script:Step = 1; Show-AkariSteps
"s1next=$($StepNext.Content)"; "s1enabled=$($StepNext.IsEnabled)"; "rows=$($script:TweakRows.Count)"; "cards=$($script:TweakCards.Count)"
"heading=$($Heading.Text)"; "dots=$($StepDots.Children.Count)"
"legStart=$($script:TweakRows['leg'].Control.IsChecked)"; "optStart=$($script:TweakRows['opt'].Control.IsChecked)"
$script:TweakRows['tog'].Control.IsChecked = $true; Step-AkariCheck 'tog'
$script:TweakRows['opt'].Control.IsChecked = $false; Step-AkariCheck 'opt'
"s1after=$($StepNext.Content)"
Set-AkariChoiceTarget 'ch' 0x28
# Show current state off: every row unchecked, the Selection emptied
$script:UseState = $false; Reset-AkariTweakRows
"plainOpt=$($script:TweakRows['opt'].Control.IsChecked)"; "plainSel=$($script:Sel.Count)"
$script:UseState = $true; Reset-AkariTweakRows
"backOpt=$($script:TweakRows['opt'].Control.IsChecked)"
$script:TweakRows['tog'].Control.IsChecked = $true; Step-AkariCheck 'tog'
$script:TweakRows['opt'].Control.IsChecked = $false; Step-AkariCheck 'opt'
Set-AkariChoiceTarget 'ch' 0x28
$Search.Text = 'Ch'; Set-AkariTweaksFilter 'Ch'
"togHidden=$($script:TweakRows['tog'].Row.Visibility)"; "togCardHidden=$($script:TweakRows['tog'].Card.Visibility)"
Set-AkariTweaksFilter ''
$script:Step = 2; Show-AkariSteps
"review=$($StepBody.Children.Count)"
"plan=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id + ':' + $_.Mode }) -join ',')"
$script:Step = 1; Show-AkariSteps
"reattached=$($StepBody.Children.Count)"
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
    It 'opens on the One-click / Guided chooser with only Back' {
        $out.chooser | Should Be '2'
        $out.oneClick | Should Be 'True'
        $out.chooserFooter | Should Be 'Visible'
        $out.chooserNext | Should Be 'Collapsed'
    }
    It 'One-click asks first; No launches nothing' { $out.declinedLaunch | Should Be 'False' }
    It 'One-click runs in Akari''s own console, no new window' { $out.newWindow | Should Be 'False' }
    It 'One-click Yes hands OneClick\akarios.ps1 to the console and closes the window' {
        $out.launched | Should Match 'OneClick\\akarios\.ps1'
        $out.closed | Should Be 'True'
    }
    It 'Back on the chooser goes Home' { $out.backTo | Should Be 'Home' }
    It 'Optimize opens on Legacy and a greyed Advanced, with only Back' {
        $out.optCards | Should Be '2'
        $out.optEnabled | Should Be 'True,False'
        $out.optHeading | Should Be 'Optimize'
        $out.optFooter | Should Be 'Visible,Collapsed'
    }
    It 'Legacy opens the first Legacy page, Back on the Optimize chooser goes Home' {
        $out.legacyTo | Should Be 'Check'
        $out.optBack | Should Be 'Home'
    }
    It 'Guided starts on Apps, with Back to the chooser' {
        $out.mode | Should Be 'Guided'
        $out.s0next | Should Be 'Next'
        $out.s0back | Should Be 'Visible'
        $out.guidedFooter | Should Be 'Visible'
    }
    It 'shows a row per Tweak in a card per Category, and disables Review at 0 changes' {
        $out.rows | Should Be '4'
        $out.cards | Should Be '3'
        $out.s1next | Should Be 'Review (0)'
        $out.s1enabled | Should Be 'False'
    }
    It 'names the step in the page header, dots in the footer' {
        $out.heading | Should Be 'Tweaks'
        $out.dots | Should Be '3'
    }
    It 'starts an Optimized Tweak checked and an unread one unchecked' {
        $out.optStart | Should Be 'True'
        $out.legStart | Should Be 'False'
    }
    It 'counts checking one box and unchecking an Optimized one' { $out.s1after | Should Be 'Review (2)' }
    It 'Show current state off starts every row unchecked and empties the Selection' {
        $out.plainOpt | Should Be 'False'
        $out.plainSel | Should Be '0'
        $out.backOpt | Should Be 'True'
    }
    It 'filters rows by search and hides emptied cards' {
        $out.togHidden | Should Be 'Collapsed'
        $out.togCardHidden | Should Be 'Collapsed'
    }
    It 'reviews the changes and plans them in order: Apply, Revert, Choice' {
        $out.review | Should Be '3'
        $out.plan | Should Be 'tog:Apply,opt:Revert,ch:Apply'
    }
    It 'shows the cached Tweaks view again after Review' { $out.reattached | Should Be '1' }
    It 'changes nothing while choosing' {
        $out.untouched | Should Be 'True'
        $out.optUntouched | Should Be '0'
    }
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
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps') { . "$Root\UI\$f.ps1" }
# no real AppX read in tests: no app installed, no data-list Group
function Get-AkariAppxInstalled { @() }; function Start-AkariFeatureRead { }; $script:Groups = @()
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
$script:Mode = 'Guided'; $script:Step = 2
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
function Select-AkariPage($n) { $script:went = $n }
Reset-AkariSteps
"afterDone=$script:went,$script:Mode,$script:Step"; "selCount=$($script:Sel.Count)"; "appsCache=$($null -eq $script:AppsView)"
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
    It 'Done clears the Selection and goes back Home, with Install AkariOS back on its chooser' {
        $out.afterDone | Should Be 'Home,Choose,0'
        $out.selCount | Should Be '0'
        $out.appsCache | Should Be 'True'
    }
}

Describe 'Get-AkariFlowStep' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    . "$Root\UI\Steps.ps1"
    It 'walks Guided through Apps, Tweaks, Review' {
        Get-AkariFlowStep 'Guided' 0 1 | Should Be 1
        Get-AkariFlowStep 'Guided' 1 1 | Should Be 2
        Get-AkariFlowStep 'Guided' 0 -1 | Should BeNullOrEmpty
    }
    It 'walks Downloads from the apps straight to Review' {
        Get-AkariFlowStep 'Downloads' 0 1 | Should Be 2
        Get-AkariFlowStep 'Downloads' 2 -1 | Should Be 0
        Get-AkariFlowStep 'Downloads' 0 -1 | Should BeNullOrEmpty
    }
}

Describe 'Optimize Legacy pages' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
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
    It 'Downloads exits to the Legacy page it was opened from, else Home' {
        Set-AkariFlowExit 'Graphics'; $script:FlowExit | Should Be 'Graphics'
        Set-AkariFlowExit 'Home'; $script:FlowExit | Should Be 'Home'
        Set-AkariFlowExit 'Optimize'; $script:FlowExit | Should Be 'Home'
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

Describe 'Apps step (in memory, no window, fake packages)' {
    $probe = "$TestDrive\apps.ps1"
    Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
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
    ConvertTo-AkariTweak @{ Id = 'inst'; Name = 'Inst app'; Description = 'D'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Button = 'Install'; Risk = 'Safe'; Winget = 'Akari.Test.Inst'; Apply = { } } 'x' $false
)
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps') { . "$Root\UI\$f.ps1" }
# the fake PC has three of the listed apps and one the list doesn't know
function Get-AkariAppxInstalled { @('Akari.Test.Safe', 'Akari.Test.Opt', 'Akari.Test.Kept', 'Akari.Test.Extra') }
# no real feature read: the probe hands fake names to Complete-AkariFeatureRead itself, later
function Start-AkariFeatureRead { }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
[void]$res.Children.Add($StepBody)
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new(); $Search = [Windows.Controls.TextBox]::new()
$StepFooter = [Windows.Controls.Border]::new()
$script:Mode = 'Guided'; $script:Step = 0; Show-AkariSteps
"rows=$($script:AppRows.Count)"
"visible=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)"
Select-AkariApps { param($t) $t.Risk -eq 'Safe' }
"recommended=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')"
Select-AkariApps { param($t) -not $t.Keep }
"removable=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id } | Sort-Object) -join ',')"
"status=$($script:AppsStatus.Text)"
Select-AkariApps { param($t) $false }
"cleared=$($script:Sel.Count)"
# a Caution app needs no confirmation (an Advanced one shows a MessageBox: checked on the VM, not here)
$e =$script:AppRows['appx/Akari.Test.Opt']; $e.Control.IsChecked = $true; Step-AkariAppCheck 'appx/Akari.Test.Opt'
"review=$((Get-AkariReviewItems $script:Sel | ForEach-Object { $_.Name + ':' + $_.To }) -join ',')"
$script:OnlyInstalled = $false; Set-AkariAppsFilter ''
"allVisible=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)"
Set-AkariAppsFilter 'Optional'
"searched=$(@($script:AppRows.Values | Where-Object { $_.Row.Visibility -eq 'Visible' }).Count)"
# Install tab: its own table, an install is reviewed as Install
Show-AkariAppsTab 'Install'
"installTab=$($script:AppsParts.RemoveTables.Visibility),$($script:AppsParts.InstallTables.Visibility),$($script:AppsParts.Legend.Visibility)"
"source=$(Get-AkariAppSource $script:AppRows['inst'].Tweak)"
$e = $script:AppRows['inst']; $e.Control.IsChecked = $true; Step-AkariAppCheck 'inst'
"installReview=$((Get-AkariReviewItems $script:Sel | Where-Object { $_.Id -eq 'inst' } | ForEach-Object { $_.Name + ':' + $_.To }))"
"bothStatus=$($script:AppsStatus.Text)"
Clear-AkariInstalls
"afterClear=$($script:AppsStatus.Text)"
# app picks survive the Tweaks step: building it, and its Clear selection, only touch the Tweak rows
Select-AkariApps { param($t) $t.Risk -eq 'Safe' }
$script:Step = 1; Show-AkariSteps
"keptAfterTweaks=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')"
Reset-AkariTweakRows
"keptAfterClear=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ',')"
# the features arrive after the AkariOS pick: they get the same pick, the keep-list stays unchecked
"readingTitle=$($script:AppsParts.CapTable.Title.Text)"
Select-AkariApps { param($t) -not $t.Keep }
Complete-AkariFeatureRead @('App.StepsRecorder~~~~0.0.1.0', 'WMIC~~~~') @('WorkFolders-Client')
"titles=$($script:AppsParts.CapTable.Title.Text),$($script:AppsParts.FeatTable.Title.Text)"
"capName=$($script:AppRows['capability/App.StepsRecorder~~~~0.0.1.0'].Tweak.Name)"
"wmic=$($script:AppRows['capability/WMIC~~~~'].Tweak.Keep),$($script:AppRows['capability/WMIC~~~~'].Tweak.Risk)"
"lateSel=$((Get-AkariPlanItems $script:Sel | Where-Object { $_.Id -notlike 'appx/*' } | ForEach-Object { $_.Id } | Sort-Object) -join ',')"
# Downloads (Home tile): a fresh start, the Install cards alone, then Review; Back at the start goes Home
function Select-AkariPage($n) { $script:went = $n }
Enter-AkariFlow 'Downloads'
"dlStart=$script:Mode,$script:Step,$($script:Sel.Count)"
Show-AkariSteps
"dlParts=$($script:AppsParts.Tabs.Visibility),$($script:AppsParts.RemoveTables.Visibility),$($script:AppsParts.InstallTables.Visibility)"
"dlDots=$($StepDots.Children.Count)"; "dlNext=$($StepNext.Content),$($StepNext.IsEnabled)"
$e = $script:AppRows['inst']; $e.Control.IsChecked = $true; Step-AkariAppCheck 'inst'
"dlPicked=$($StepNext.Content),$($StepNext.IsEnabled)"
Step-AkariForward; "dlReview=$script:Step"
Step-AkariBack; "dlBack=$script:Step"
Step-AkariBack; "dlHome=$script:went"
Enter-AkariFlow 'Install AkariOS'; "guidedAgain=$script:Mode,$($script:Sel.Count)"
# Downloads opened from a Legacy page: Back at the start and Done lead back to that page
Set-AkariFlowExit 'Windows'; Enter-AkariFlow 'Downloads'; Show-AkariSteps
Step-AkariBack; "dlLegacyBack=$script:went"
$script:Step = 3; Reset-AkariSteps; "dlLegacyDone=$script:went,$script:Mode"
Set-AkariFlowExit 'Home'; Enter-AkariFlow 'Downloads'; $script:Step = 3; Reset-AkariSteps; "dlHomeDone=$script:went"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'lists the data file apps and the unknown installed one; Only installed hides the missing one' {
        $out.rows | Should Be '6'
        $out.visible | Should Be '5'
    }
    It 'Select recommended checks the installed Safe apps (Win11Debloat)' { $out.recommended | Should Be 'appx/Akari.Test.Safe' }
    It 'AkariOS checks every installed app but the keep-list (FR33THY)' {
        $out.removable | Should Be 'appx/Akari.Test.Extra,appx/Akari.Test.Opt,appx/Akari.Test.Safe'
        $out.status | Should Be '3 to remove, 0 to install'
    }
    It 'Clear selection empties the Selection' { $out.cleared | Should Be '0' }
    It 'a checked app is reviewed as Remove' { $out.review | Should Be 'Optional app:Remove' }
    It 'filters by Only installed and by search' {
        $out.allVisible | Should Be '6'
        $out.searched | Should Be '1'
    }
    It 'Install tab: its own table, no legend, the winget id as source, reviewed as Install' {
        $out.installTab | Should Be 'Collapsed,Visible,Collapsed'
        $out.source | Should Be 'winget: Akari.Test.Inst'
        $out.installReview | Should Be 'Inst app:Install'
        $out.bothStatus | Should Be '1 to remove, 1 to install'
        $out.afterClear | Should Be '1 to remove, 0 to install'
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
    It 'Downloads starts afresh and shows the Install cards alone, two steps' {
        $out.dlStart | Should Be 'Downloads,0,0'
        $out.dlParts | Should Be 'Collapsed,Collapsed,Visible'
        $out.dlDots | Should Be '2'
        $out.dlNext | Should Be 'Review (0),False'
        $out.dlPicked | Should Be 'Review (1),True'
    }
    It 'Downloads goes from the apps straight to Review, and Back at the start goes Home' {
        $out.dlReview | Should Be '2'
        $out.dlBack | Should Be '0'
        $out.dlHome | Should Be 'Home'
    }
    It 'Install AkariOS after Downloads starts afresh on its chooser' { $out.guidedAgain | Should Be 'Choose,0' }
    It 'Downloads opened from Legacy goes back there on Back and Done; from Home, Home' {
        $out.dlLegacyBack | Should Be 'Windows'
        $out.dlLegacyDone | Should Be 'Windows,Choose'
        $out.dlHomeDone | Should Be 'Home'
    }
    It 'gives the features that arrive late the last quick select (FR33THY: all but the keep-list)' {
        $out.lateSel | Should Be 'capability/App.StepsRecorder~~~~0.0.1.0,feature/WorkFolders-Client'
    }
}
