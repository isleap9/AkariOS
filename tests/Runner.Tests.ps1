$Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'

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

        It 'logs a native tool''s stderr and keeps going: Applied, not Failed' {
            $env:AKARI_TEST_FILE = "$TestDrive\native.txt"
            $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
            # harmless: cmd echoes to stderr, like reg.exe or powercfg do
            $t = ConvertTo-AkariTweak @{ Id = 'native'; Name = 'Native'; Kind = 'Action'; Apply = { cmd /c "echo akari-stderr 1>&2"; Set-Content $env:AKARI_TEST_FILE 'after' } } 'x' $false
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            Get-Content $env:AKARI_TEST_FILE | Should Be 'after'
            @($LogQueue.ToArray()) -join "`n" | Should Match 'akari-stderr'
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

        It 'runs a Choice with blocks: Value reads it, Apply gets $AkariValue, Revert = Default' {
            $env:AKARI_TEST_FILE = "$TestDrive\choice.txt"
            Set-Content $env:AKARI_TEST_FILE 'Std'
            $b = ConvertTo-AkariTweak @{ Id = 'chb'; Name = 'ChB'; Kind = 'Choice'; Recommended = 'Off'; Default = 'Std'
                Choices = @(@{ Value = 'Off' }, @{ Value = 'Light' }, @{ Value = 'Std' })
                Value = { $v = Get-Content $env:AKARI_TEST_FILE; if ($v -in 'Off', 'Light', 'Std') { $v } else { $null } }
                Apply = { Set-Content $env:AKARI_TEST_FILE $AkariValue }; Revert = { Set-Content $env:AKARI_TEST_FILE 'Std' } } 'x' $false
            Get-AkariState $b | Should Be 'Default'
            (Invoke-AkariTweak $b Apply).Outcome | Should Be 'Applied'
            Get-AkariChoiceValue $b | Should Be 'Off'
            Get-AkariState $b | Should Be 'Optimized'
            (Invoke-AkariTweak $b Apply 'Light').Outcome | Should Be 'Applied'
            Get-AkariState $b | Should Be 'Custom'
            (Invoke-AkariTweak $b Apply 'Light').Outcome | Should Be 'Already'
            (Invoke-AkariTweak $b Revert).Outcome | Should Be 'Reverted'
            Get-AkariState $b | Should Be 'Default'
            Set-Content $env:AKARI_TEST_FILE 'hand-edited'
            Get-AkariState $b | Should Be 'Custom'
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

Describe 'Requires and Explorer in a Run' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $w11 = ConvertTo-AkariTweak @{ Id = 'w11'; Name = 'W11'; Requires = 'Win11'; Explorer = $true
        Registry = @{ Path = $k; Name = 'W'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false
    $plain = ConvertTo-AkariTweak @{ Id = 'plain'; Name = 'Plain'; Explorer = $true
        Registry = @{ Path = $k; Name = 'P'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false
    $quiet = ConvertTo-AkariTweak @{ Id = 'quiet'; Name = 'Quiet'
        Registry = @{ Path = $k; Name = 'Q'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false
    # Explorer is never really restarted in a test
    Mock Restart-AkariExplorer { }

    try {
        Context 'on Windows 10' {
            Mock Get-AkariOSBuild { 19045 }
            It 'Skips a Win11 Tweak either way, with the reason, and changes nothing' {
                $o = @(Invoke-AkariPlan @(@{ Id = 'w11'; Mode = 'Apply' }, @{ Id = 'w11'; Mode = 'Revert' }) @($w11))
                ($o | ForEach-Object { "$($_.Outcome):$($_.Message)" }) -join ',' | Should Be 'Skipped:needs Win11,Skipped:needs Win11'
                Get-AkariRegValue $k 'W' | Should BeNullOrEmpty
                Assert-MockCalled Restart-AkariExplorer -Exactly 0 -Scope It
            }
        }

        Context 'on Windows 11' {
            Mock Get-AkariOSBuild { 26100 }
            It 'runs it, and restarts Explorer once for two Explorer Tweaks' {
                $o = @(Invoke-AkariPlan @(@{ Id = 'w11'; Mode = 'Apply' }, @{ Id = 'plain'; Mode = 'Apply' }, @{ Id = 'quiet'; Mode = 'Apply' }) @($w11, $plain, $quiet))
                ($o | ForEach-Object { $_.Outcome }) -join ',' | Should Be 'Applied,Applied,Applied'
                Assert-MockCalled Restart-AkariExplorer -Exactly 1 -Scope It
            }
            It 'does not restart Explorer when nothing changed (Already)' {
                $o = @(Invoke-AkariPlan @(@{ Id = 'w11'; Mode = 'Apply' }, @{ Id = 'plain'; Mode = 'Apply' }) @($w11, $plain))
                ($o | ForEach-Object { $_.Outcome }) -join ',' | Should Be 'Already,Already'
                Assert-MockCalled Restart-AkariExplorer -Exactly 0 -Scope It
            }
            It 'restarts it for a Revert too, but not for a Tweak without Explorer' {
                [void](Invoke-AkariPlan @(@{ Id = 'quiet'; Mode = 'Revert' }) @($quiet))
                Assert-MockCalled Restart-AkariExplorer -Exactly 0 -Scope It
                [void](Invoke-AkariPlan @(@{ Id = 'plain'; Mode = 'Revert' }) @($plain))
                Assert-MockCalled Restart-AkariExplorer -Exactly 1 -Scope It
            }
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Changes that restart the PC run last' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System') { . "$Core\$f.ps1" }
    . (Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'UI\Selection.ps1')
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $order = [System.Collections.Generic.List[string]]::new()
    Mock Restart-AkariExplorer { $order.Add('explorer') }
    # legacy-style bodies: the restart lines are never reached (the tweak records itself and returns first)
    $mk = { param($id, $body, $explorer) ConvertTo-AkariTweak @{ Id = $id; Name = $id; Explorer = $explorer
        Apply = [scriptblock]::Create("`$order.Add('$id'); return`n$body"); Revert = [scriptblock]::Create("`$order.Add('$id-r'); return`n$body"); Detect = { $false } } 'x' $true }
    $safe = & $mk 'safe' "cmd /c `"bcdedit /set {current} safeboot minimal >nul 2>&1`"`nshutdown -r -t 00" $false
    $boot = & $mk 'boot' 'Restart-Computer -Force' $false
    $a = & $mk 'a' "Write-Output 'no restart'" $true
    $b = & $mk 'b' "cmd /c reg add HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\x /f" $false

    It 'knows which blocks restart (bcdedit safeboot, shutdown /r, Restart-Computer), not a SafeBoot registry path' {
        Test-AkariRestarts $safe 'Apply' | Should Be $true
        Test-AkariRestarts $boot 'Revert' | Should Be $true
        Test-AkariRestarts $b 'Apply' | Should Be $false
        # a one-file SafeMode Tweak doesn't restart by itself: Invoke-AkariPlan takes it to Safe Mode (Core\Phases.ps1)
        Test-AkariRestarts (ConvertTo-AkariTweak @{ Id = 'sm'; Name = 'sm'; SafeMode = $true; Apply = { } } 'x' $false) 'Apply' | Should Be $false
    }

    It 'runs every other change first, in order, then Explorer, then the restarting one' {
        $order.Clear()
        $o = @(Invoke-AkariPlan @(@{ Id = 'safe'; Mode = 'Apply' }, @{ Id = 'a'; Mode = 'Apply' }, @{ Id = 'b'; Mode = 'Apply' }) @($safe, $a, $b))
        ($order -join ',') | Should Be 'a,b,explorer,safe'
        ($o | ForEach-Object { $_.Id }) -join ',' | Should Be 'a,b,safe'
    }

    It 'runs only the first of two changes that restart the PC, and reports the other Skipped' {
        $order.Clear()
        $o = @(Invoke-AkariPlan @(@{ Id = 'boot'; Mode = 'Apply' }, @{ Id = 'safe'; Mode = 'Apply' }) @($safe, $boot))
        ($order -join ',') | Should Be 'boot'
        ($o | ForEach-Object { "$($_.Id):$($_.Outcome)" }) -join ',' | Should Be 'boot:Applied,safe:Skipped'
        $o[1].Message | Should Match 'after this restart'
    }

    It 'tells Review about it' {
        $sel = New-AkariSelection
        Set-AkariPending $sel $safe 'Default' 'Optimized'
        Set-AkariPending $sel $a 'Default' 'Optimized'
        Get-AkariRestartNote $sel @($safe, $a) | Should Match '^safe restarts the PC.*runs last'
        Set-AkariPending $sel $boot 'Default' 'Optimized'
        Get-AkariRestartNote $sel @($safe, $a, $boot) | Should Match 'Only safe runs now'
        Get-AkariRestartNote (New-AkariSelection) @($safe) | Should BeNullOrEmpty
    }
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
