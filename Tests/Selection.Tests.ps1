$Root = Split-Path $PSScriptRoot

Describe 'Selection' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    . "$Root\UI\Selection.ps1"
    $tog = ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Risk = 'Safe' } 'x' $false
    $adv = ConvertTo-AkariTweak @{ Id = 'adv'; Name = 'Adv'; Risk = 'Advanced' } 'x' $false
    $act = ConvertTo-AkariTweak @{ Id = 'act'; Name = 'Act'; Kind = 'Action'; Risk = 'Safe' } 'x' $false
    $ch = ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Kind = 'Choice'; Risk = 'Safe'; Recommended = 0x26; Default = 2
        Choices = @(@{ Value = 0x26; Label = '0x26 short' }, @{ Value = 0x28; Label = '0x28 short, fixed' }, @{ Value = 0x18; Label = '0x18 long'; Risk = 'Caution' }) } 'x' $false

    It 'Toggle Default to Optimized is an Apply' {
        $s = New-AkariSelection
        Set-AkariPending $s $tog 'Default' 'Optimized'
        $p = @(Get-AkariPlanItems $s)
        $p.Count | Should Be 1
        $p[0].Mode | Should Be 'Apply'
        $p[0].ContainsKey('Value') | Should Be $false
    }

    It 'flipping back to the State removes the change' {
        $s = New-AkariSelection
        Set-AkariPending $s $tog 'Default' 'Optimized'
        Set-AkariPending $s $tog 'Default' 'Default'
        $s.Count | Should Be 0
    }

    It 'None removes the change' {
        $s = New-AkariSelection
        Set-AkariPending $s $tog 'Unknown' 'Default'
        Set-AkariPending $s $tog 'Unknown' 'None'
        $s.Count | Should Be 0
    }

    It 'Choice Recommended is an Apply without Value' {
        $s = New-AkariSelection
        Set-AkariPending $s $ch 'Default' 0x26 2
        $p = @(Get-AkariPlanItems $s)[0]
        $p.Mode | Should Be 'Apply'
        $p.ContainsKey('Value') | Should Be $false
    }

    It 'Choice other value is an Apply with Value and a labelled To' {
        $s = New-AkariSelection
        Set-AkariPending $s $ch 'Default' 0x28 2
        (@(Get-AkariPlanItems $s)[0]).Value | Should Be 0x28
        $r = @(Get-AkariReviewItems $s)[0]
        "$($r.From) -> $($r.To)" | Should Be 'Default -> 0x28 short, fixed'
    }

    It 'Choice Default is a Revert' {
        $s = New-AkariSelection
        Set-AkariPending $s $ch 'Optimized' 2 0x26
        (@(Get-AkariPlanItems $s)[0]).Mode | Should Be 'Revert'
    }

    It 'Choice set to its current value is no change' {
        $s = New-AkariSelection
        Set-AkariPending $s $ch 'Custom' 0x28 0x28
        $s.Count | Should Be 0
    }

    It 'Action is Run' {
        $s = New-AkariSelection
        Set-AkariPending $s $act 'Unknown' 'Optimized'
        (@(Get-AkariReviewItems $s)[0]).To | Should Be 'Run'
        Set-AkariPending $s $act 'Unknown' 'None'
        $s.Count | Should Be 0
    }

    It 'Review follows selection order' {
        $s = New-AkariSelection
        Set-AkariPending $s $ch 'Default' 0x28 2
        Set-AkariPending $s $tog 'Default' 'Optimized'
        (@(Get-AkariReviewItems $s) | ForEach-Object { $_.Id }) -join ',' | Should Be 'ch,tog'
    }

    It 'Advanced needs a confirmation, Safe does not' {
        Get-AkariConfirmText $adv 'Optimized' | Should Not BeNullOrEmpty
        Get-AkariConfirmText $adv 'Default' | Should BeNullOrEmpty
        Get-AkariConfirmText $tog 'Optimized' | Should BeNullOrEmpty
    }

    It 'a Choice value riskier than the Tweak needs a confirmation' {
        Get-AkariConfirmText $ch 0x18 | Should Match 'Caution'
        Get-AkariConfirmText $ch 0x28 | Should BeNullOrEmpty
    }

    It 'Confirm text is used when the Tweak has one' {
        $c = ConvertTo-AkariTweak @{ Id = 'c'; Name = 'C'; Risk = 'Safe'; Confirm = 'Sure?' } 'x' $false
        Get-AkariConfirmText $c 'Optimized' | Should Be 'Sure?'
    }

    It 'a checked box is Optimized' {
        Get-AkariCheckTarget $true 'None' | Should Be 'Optimized'
        Get-AkariCheckTarget $true 'Optimized' | Should Be 'Optimized'
    }

    It 'unchecking a box that started checked is Default (Revert)' { Get-AkariCheckTarget $false 'Optimized' | Should Be 'Default' }

    It 'a box that started unchecked and is unchecked is no change' { Get-AkariCheckTarget $false 'None' | Should Be 'None' }
}
