$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# the drift check (X3): the rule, expected.json written by Invoke-AkariTweak, the drifted settings and their preset.
# Registry rows under a test key, expected.json and state.json under TestDrive:
Describe 'Test-AkariDrift' {
    foreach ($f in 'Log', 'Registry', 'State') { . "$Core\$f.ps1" }

    It 'Revert drifts when the State is not Default' {
        Test-AkariDrift 'Toggle' 'Revert' $null 'Default' $null | Should Be $false
        Test-AkariDrift 'Toggle' 'Revert' $null 'Optimized' $null | Should Be $true
        Test-AkariDrift 'Choice' 'Revert' $null 'Custom' 5 | Should Be $true
    }

    It 'Apply drifts when the State is not Optimized, or a Choice''s value is not the one set' {
        Test-AkariDrift 'Toggle' 'Apply' $null 'Optimized' $null | Should Be $false
        Test-AkariDrift 'Toggle' 'Apply' $null 'Custom' $null | Should Be $true
        Test-AkariDrift 'Toggle' 'Apply' $null 'Default' $null | Should Be $true
        Test-AkariDrift 'Choice' 'Apply' $null 'Optimized' 2 | Should Be $false
        Test-AkariDrift 'Choice' 'Apply' 3 'Custom' 3 | Should Be $false
        Test-AkariDrift 'Choice' 'Apply' 3 'Custom' '3' | Should Be $false
        Test-AkariDrift 'Choice' 'Apply' 3 'Optimized' 2 | Should Be $true
        Test-AkariDrift 'Choice' 'Apply' 3 'Default' $null | Should Be $true
    }

    It 'never counts Unknown' {
        Test-AkariDrift 'Toggle' 'Apply' $null 'Unknown' $null | Should Be $false
        Test-AkariDrift 'Choice' 'Revert' $null 'Unknown' $null | Should Be $false
    }
}

Describe 'expected.json and Get-AkariDrift' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $AkariTestKey = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $tog = ConvertTo-AkariTweak @{ Id = 'drift-tog'; Name = 'B toggle'
        Registry = @{ Path = $AkariTestKey; Name = 'T'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false
    $cho = ConvertTo-AkariTweak @{ Id = 'drift-cho'; Name = 'A choice'; Kind = 'Choice'; Recommended = 2; Default = 1; Choices = @(1, 2, 3)
        Registry = @{ Path = $AkariTestKey; Name = 'C'; Type = 'DWord' } } 'x' $false
    $act = ConvertTo-AkariTweak @{ Id = 'drift-act'; Name = 'Action'; Kind = 'Action'; Apply = { } } 'x' $false
    $all = @($tog, $cho, $act)

    try {
        It 'records nothing without $AkariExpectedPath' {
            $AkariExpectedPath = $null
            (Invoke-AkariTweak $tog Apply).Outcome | Should Be 'Applied'
            @((Get-AkariExpected).Keys).Count | Should Be 0
        }

        $AkariExpectedPath = "$TestDrive\expected.json"

        It 'records Applied, Already and Reverted Toggles and Choices (a Choice''s value), not Actions' {
            (Invoke-AkariTweak $tog Apply).Outcome | Should Be 'Already'
            (Invoke-AkariTweak $cho Apply 3).Outcome | Should Be 'Applied'
            (Invoke-AkariTweak $act Apply).Outcome | Should Be 'Applied'
            $e = Get-AkariExpected
            (@($e.Keys) | Sort-Object) -join ',' | Should Be 'drift-cho,drift-tog'
            $e['drift-tog'].Mode | Should Be 'Apply'
            $e['drift-tog'].Value | Should Be $null
            $e['drift-cho'].Value | Should Be 3
            [datetime]$e['drift-cho'].When | Should Not Be $null
            (Invoke-AkariTweak $cho Revert).Outcome | Should Be 'Reverted'
            (Get-AkariExpected)['drift-cho'].Mode | Should Be 'Revert'
            (Get-AkariExpected)['drift-cho'].Value | Should Be $null
        }

        It 'finds the settings that went back, by name' {
            [void](Invoke-AkariTweak $cho Apply 3)
            @(Get-AkariDrift $all).Count | Should Be 0
            Set-Reg $AkariTestKey 'T' 1
            Set-Reg $AkariTestKey 'C' 2
            $d = @(Get-AkariDrift $all)
            ($d | ForEach-Object { "$($_.Id)=$($_.Mode):$($_.Value):$($_.State)" }) -join ',' | Should Be 'drift-cho=Apply:3:Optimized,drift-tog=Apply::Default'
            # a Tweak no longer loaded is left out
            @(Get-AkariDrift @($tog)).Count | Should Be 1
        }

        It 'turns them into a preset Quick select resolves' {
            $d = @(
                @{ Id = 'drift-tog'; Mode = 'Apply'; Value = $null }
                @{ Id = 'drift-cho'; Mode = 'Apply'; Value = 3 }
                @{ Id = 'other'; Mode = 'Revert'; Value = $null }
            )
            . "$Core\Presets.ps1"
            $p = ConvertTo-AkariDriftPreset $d
            ($p.Entries | ForEach-Object { "$($_.Id):$($_.HasValue):$($_.Value)" }) -join ',' | Should Be 'drift-tog:False:,drift-cho:True:3,other:True:Default'
            $r = Resolve-AkariPreset $p $all
            ($r.Items | ForEach-Object { "$($_.Id):$($_.Mode):$($_.Value)" }) -join ',' | Should Be 'drift-tog:Apply:,drift-cho:Apply:3'
            $r.Unknown | Should Be 'other'
        }
    } finally {
        Remove-Item -LiteralPath (Resolve-AkariRegPath $AkariTestKey) -Recurse -Force -ErrorAction SilentlyContinue
    }
}
