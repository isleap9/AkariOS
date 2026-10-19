$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

Describe 'Invoke-AkariTweak' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()   # keeps test output quiet
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $reg = ConvertTo-AkariTweak @{ Id = 'reg'; Name = 'Reg'; Reboot = $true
        Registry = @{ Path = $k; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false

    try {
        It 'Applies a registry Toggle and flags the reboot' {
            $o = Invoke-AkariTweak $reg Apply
            $o.Outcome | Should Be 'Applied'
            $o.Reboot | Should Be $true
            Get-AkariRegValue $k 'A' | Should Be 0
        }

        It 'reports Already when the State matches, with no reboot' {
            $o = Invoke-AkariTweak $reg Apply
            $o.Outcome | Should Be 'Already'
            $o.Reboot | Should Be $false
        }

        It 'Reverts to the Default' {
            (Invoke-AkariTweak $reg Revert).Outcome | Should Be 'Reverted'
            Get-AkariRegValue $k 'A' | Should Be 1
        }

        It 'runs Apply / Revert script blocks and remembers them when there is no Detect' {
            $AkariStatePath = "$TestDrive\state.json"
            $env:AKARI_TEST_FILE = "$TestDrive\flag.txt"
            $t = ConvertTo-AkariTweak @{ Id = 'custom'; Name = 'Custom'
                Apply = { Set-Content $env:AKARI_TEST_FILE 'on' }; Revert = { Set-Content $env:AKARI_TEST_FILE 'off' } } 'x' $false
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            Get-Content $env:AKARI_TEST_FILE | Should Be 'on'
            Get-AkariRememberedState 'custom' | Should Be $true
            (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
            Get-Content $env:AKARI_TEST_FILE | Should Be 'off'
        }

        It 'reports Failed with the error when Apply throws' {
            $t = ConvertTo-AkariTweak @{ Id = 'boom'; Name = 'Boom'; Detect = { $false }; Apply = { throw 'disk on fire' }; Revert = { } } 'x' $false
            $o = Invoke-AkariTweak $t Apply
            $o.Outcome | Should Be 'Failed'
            $o.Message | Should Match 'disk on fire'
        }

        It 'reports Failed when a cmdlet in Apply writes a non-terminating error' {
            $t = ConvertTo-AkariTweak @{ Id = 'soft'; Name = 'Soft'; Detect = { $false }; Apply = { Get-Item 'HKCU:\Software\AkariTest\does-not-exist' }; Revert = { } } 'x' $false
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Failed'
        }

        It 'Skips Revert on an Action' {
            $t = ConvertTo-AkariTweak @{ Id = 'act'; Name = 'Act'; Kind = 'Action'; Apply = { } } 'x' $false
            $o = Invoke-AkariTweak $t Revert
            $o.Outcome | Should Be 'Skipped'
            $o.Message | Should Be 'Action has no Revert'
        }

        It 'sets a Choice to Recommended, then back to Default' {
            $c = ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Kind = 'Choice'; Recommended = 0x26; Default = 2
                Registry = @{ Path = $k; Name = 'P'; Type = 'DWord' }; Choices = @(@{ Value = 0x26 }) } 'x' $false
            (Invoke-AkariTweak $c Apply).Outcome | Should Be 'Applied'
            Get-AkariRegValue $k 'P' | Should Be 0x26
            (Invoke-AkariTweak $c Revert).Outcome | Should Be 'Reverted'
            Get-AkariRegValue $k 'P' | Should Be 2
        }

        $c3 = ConvertTo-AkariTweak @{ Id = 'ch3'; Name = 'Ch3'; Kind = 'Choice'; Recommended = 0x26; Default = 2
            Registry = @{ Path = $k; Name = 'V'; Type = 'DWord' }; Choices = @(@{ Value = 0x26 }, @{ Value = 3 }) } 'x' $false

        It 'applies a Choice to an explicit Value' {
            $o = Invoke-AkariTweak $c3 Apply 3
            $o.Outcome | Should Be 'Applied'
            Get-AkariRegValue $k 'V' | Should Be 3
        }

        It 'is Already when the Choice holds that Value' {
            (Invoke-AkariTweak $c3 Apply 3).Outcome | Should Be 'Already'
        }

        It 'fails a Value on a Toggle' {
            $o = Invoke-AkariTweak $reg Apply 5
            $o.Outcome | Should Be 'Failed'
            $o.Message | Should Match 'only for Choices'
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Invoke-AkariRun' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $list = @(
        ConvertTo-AkariTweak @{ Id = 'boom'; Name = 'Boom'; Detect = { $false }; Apply = { throw 'nope' }; Revert = { } } 'x' $false
        ConvertTo-AkariTweak @{ Id = 'good'; Name = 'Good'; Registry = @{ Path = $k; Name = 'G'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false
    )

    try {
        It 'keeps going past unknown and failing ids, in the order given' {
            $o = @(Invoke-AkariRun @('missing', 'boom', 'good') Apply $list)
            ($o | ForEach-Object { $_.Outcome }) -join ',' | Should Be 'Failed,Failed,Applied'
            $o[0].Message | Should Be 'Unknown tweak id'
            $o[2].Id | Should Be 'good'
        }

        It 'runs a plan in order with mixed modes' {
            $o = @(Invoke-AkariPlan @(@{ Id = 'good'; Mode = 'Revert' }, @{ Id = 'good'; Mode = 'Apply' }) $list)
            ($o | ForEach-Object { "$($_.Mode):$($_.Outcome)" }) -join ',' | Should Be 'Revert:Reverted,Apply:Applied'
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Start-AkariJob' {
    foreach ($f in 'Log', 'Registry', 'Runner') { . "$Core\$f.ps1" }
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"

    try {
        It 'runs code in a background runspace with Core loaded and logs to the queue' {
            $q = [Collections.Concurrent.ConcurrentQueue[string]]::new()
            $j = Start-AkariJob "Write-Host 'from job'; Set-Reg '$k' 'J' 3" $q $Core
            $j.Handle.AsyncWaitHandle.WaitOne(15000) | Should Be $true
            $j.Ps.EndInvoke($j.Handle); $j.Ps.Dispose(); $j.Rs.Dispose()
            @($q.ToArray()) -contains 'from job' | Should Be $true
            Get-AkariRegValue $k 'J' | Should Be 3
        }

        It 'hands results back through Shared' {
            $q = [Collections.Concurrent.ConcurrentQueue[string]]::new()
            $s = [hashtable]::Synchronized(@{})
            $j = Start-AkariJob '$AkariShared.X = 42' $q $Core $s
            $j.Handle.AsyncWaitHandle.WaitOne(20000) | Should Be $true
            $j.Ps.EndInvoke($j.Handle); $j.Ps.Dispose(); $j.Rs.Dispose()
            $s.X | Should Be 42
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}
