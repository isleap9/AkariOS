$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'

# Runs in phases (Core\Phases.ps1): bcdedit, the restart and Safe Mode detection are mocked functions; run.json goes to
# TestDrive; RunOnce writes go to HKCU:\Software\AkariTest\<guid> (Resolve-AkariRegPath is mocked). Nothing restarts.

Describe 'Runs in phases' {
    $AkariStatePath = "$TestDrive\state.json"
    $AkariLogFile = "$TestDrive\akari.log"
    $AkariRunPath = "$TestDrive\run.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Presets', 'Phases') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$k\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$k\HKLM\$($Matches[1])" } else { $Path } }
    Mock Invoke-AkariBcdEdit { 0 }
    Mock Restart-AkariPC { }
    Mock Restart-AkariExplorer { }
    Mock Get-AkariUserSid { 'S-1-5-21-test' }
    $order = [System.Collections.Generic.List[string]]::new()
    $mk = { param([hashtable]$h) $h.Name = $h.Id; if (-not $h.Apply) { $h.Apply = [scriptblock]::Create("`$order.Add('$($h.Id)')") }
        if (-not $h.Revert -and $h.Kind -ne 'Action') { $h.Revert = [scriptblock]::Create("`$order.Add('$($h.Id)-r')") }
        if (-not $h.Detect -and $h.Kind -ne 'Action') { $h.Detect = { 'Default' } }; ConvertTo-AkariTweak $h 'x' $false }
    $a = & $mk @{ Id = 'a' }
    $b = & $mk @{ Id = 'b'; Reboot = $true }
    $sm = & $mk @{ Id = 'sm'; SafeMode = $true }
    $bad = & $mk @{ Id = 'bad'; Apply = { throw 'boom' } }
    $ddu = & $mk @{ Id = 'ddu'; Kind = 'Action'; Restarts = $true; Apply = { $order.Add('ddu') } }
    $all = @($a, $b, $sm, $bad, $ddu)
    # read back through the mocked Resolve-AkariRegPath
    $ro = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    function Phase($name, $boot, [string[]]$ids) { @{ Name = $name; Boot = $boot; Items = @($ids | Where-Object { $_ } | ForEach-Object { @{ Id = $_; Mode = 'Apply' } }) } }

    try {
        # one Context: Pester 3 empties TestDrive (run.json) at the end of each Context. Each It sets its own boot mode.
        Context 'a three-phase Run: normal, Safe Mode, normal' {
            It 'runs phase 1, sets Safe Mode and the resume for phase 2, restarts' {
                Mock Test-AkariSafeMode { $false }
                $order.Clear()
                $run = New-AkariRun 'T' @((Phase 'one' 'Normal' 'a'), (Phase 'two' 'SafeMode' 'sm'), (Phase 'three' 'Normal' 'b'))
                $res = @(Start-AkariPhases $run $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Restarting'
                ($order -join ',') | Should Be 'a'
                Assert-MockCalled Invoke-AkariBcdEdit -Exactly 1 -Scope It -ParameterFilter { $Arguments -eq '/set {current} safeboot minimal' }
                Assert-MockCalled Restart-AkariPC -Exactly 1 -Scope It
                Get-AkariRegValue $ro '*!akari-resume' | Should Match 'Akari\.ps1" -Resume$'
                $saved = Get-AkariRun
                $saved.Next | Should Be 1
                $saved.Sid | Should Be 'S-1-5-21-test'
                @($saved.Outcomes).Count | Should Be 1
                $LogQueue.ToArray() -join "`n" | Should Match 'Restarting into Safe Mode for: two'
            }

            It 'resumed in Safe Mode: runs phase 2 there, then sets a normal boot and the resume for phase 3, restarts' {
                Mock Test-AkariSafeMode { $true }
                $order.Clear()
                $res = @(Start-AkariPhases (Get-AkariRun) $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Restarting'
                ($order -join ',') | Should Be 'sm'
                Assert-MockCalled Invoke-AkariBcdEdit -Exactly 1 -Scope It -ParameterFilter { $Arguments -eq '/deletevalue {current} safeboot' }
                Get-AkariRegValue $ro '!akari-resume' | Should Not BeNullOrEmpty
                Get-AkariRegValue $ro '*!akari-resume' | Should Be $null
                (Get-AkariRun).Next | Should Be 2
            }

            It 'resumed in normal mode: runs phase 3, clears the Run, restarts once for its restart-needing change' {
                Mock Test-AkariSafeMode { $false }
                $order.Clear()
                $res = @(Start-AkariPhases (Get-AkariRun) $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Restarting'
                ($order -join ',') | Should Be 'b'
                Test-Path $AkariRunPath | Should Be $false
                Get-AkariRegValue $ro '!akari-resume' | Should Be $null
                Assert-MockCalled Restart-AkariPC -Exactly 1 -Scope It
                $LogQueue.ToArray() -join "`n" | Should Match 'All phases done'
            }
        }

        Context 'started in the wrong boot mode' {
            Mock Test-AkariSafeMode { $false }
            It 'restarts into Safe Mode first, running nothing' {
                $order.Clear()
                $res = @(Start-AkariPhases (New-AkariRun 'T' @((Phase 'sm' 'SafeMode' 'sm'))) $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Restarting'
                $order.Count | Should Be 0
                (Get-AkariRun).Next | Should Be 0
                Get-AkariRegValue $ro '*!akari-resume' | Should Not BeNullOrEmpty
                $LogQueue.ToArray() -join "`n" | Should Match 'Restarting into Safe Mode for: sm'
                # the GUI writes queued lines to akari.log itself: not twice
                "$(Get-Content $AkariLogFile -Raw -ErrorAction SilentlyContinue)" | Should Not Match 'Restarting into Safe Mode for: sm'
                Clear-AkariRun
            }
        }

        Context 'in the console (-Resume: no LogQueue)' {
            Mock Test-AkariSafeMode { $false }
            $LogQueue = $null
            It 'writes the restart to akari.log once' {
                $res = @(Start-AkariPhases (New-AkariRun 'T' @((Phase 'console' 'SafeMode' 'sm'))) $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Restarting'
                @(Get-Content $AkariLogFile | Where-Object { $_ -match 'Restarting into Safe Mode for: console' }).Count | Should Be 1
                Clear-AkariRun
            }
        }

        Context 'a failure in Safe Mode' {
            Mock Test-AkariSafeMode { $true }
            It 'stops the Run, turns Safe Mode off, resumes nothing' {
                $res = @(Start-AkariPhases (New-AkariRun 'T' @((Phase 'sm' 'SafeMode' 'bad'), (Phase 'after' 'Normal' 'a'))) $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Stopped'
                ($res | Where-Object { $_.Outcome -eq 'Failed' }).Id | Should Be 'bad'
                Test-Path $AkariRunPath | Should Be $false
                Get-AkariRegValue $ro '!akari-resume' | Should Be $null
                Assert-MockCalled Invoke-AkariBcdEdit -Scope It -ParameterFilter { $Arguments -eq '/deletevalue {current} safeboot' }
                $LogQueue.ToArray() -join "`n" | Should Match 'Stopped in Safe Mode'
            }
        }

        Context 'a change that restarts the PC itself' {
            Mock Test-AkariSafeMode { $true }
            It 'sets up the next phase before it runs, then stops (Akari restarts if it did not)' {
                $order.Clear()
                $res = @(Start-AkariPhases (New-AkariRun 'T' @((Phase 'sm' 'SafeMode' 'ddu', 'sm'), (Phase 'after' 'Normal' 'a'))) $all 'C:\A\Akari.ps1')
                $res[-1] | Should Be 'Restarting'
                ($order -join ',') | Should Be 'sm,ddu'
                Get-AkariRegValue $ro '!akari-resume' | Should Not BeNullOrEmpty
                (Get-AkariRun).Next | Should Be 1
                Assert-MockCalled Restart-AkariPC -Exactly 1 -Scope It
                Clear-AkariRun
            }
        }

        Context 'Safe Mode Tweaks in a normal phase' {
            Mock Test-AkariSafeMode { $false }
            It 'get a Safe Mode phase of their own, and a normal one back' {
                $run = New-AkariRun 'T' @((Phase 'one' 'Normal' 'a', 'sm'))
                Split-AkariSafeModePhases $run $all
                ($run.Phases | ForEach-Object { "$($_.Boot):$(($_.Items | ForEach-Object { $_.Id }) -join '+')" }) -join ' ' | Should Be 'Normal:a SafeMode:sm Normal:'
            }
        }

        Context 'Invoke-AkariPlan with a Safe Mode Tweak, in normal mode' {
            Mock Test-AkariSafeMode { $false }
            It 'runs the rest now, then sets up Safe Mode for it and restarts' {
                $order.Clear()
                $o = @(Invoke-AkariPlan @(@{ Id = 'sm'; Mode = 'Apply' }, @{ Id = 'a'; Mode = 'Apply' }) $all)
                ($order -join ',') | Should Be 'a'
                ($o | ForEach-Object { "$($_.Id):$($_.Outcome):$($_.Reboot)" }) -join ' ' | Should Be 'a:Applied:False sm:Applied:True'
                $saved = Get-AkariRun
                ($saved.Phases | ForEach-Object { $_.Boot }) -join ',' | Should Be 'SafeMode,Normal'
                $saved.Phases[0].Items[0].Id | Should Be 'sm'
                Assert-MockCalled Invoke-AkariBcdEdit -Exactly 1 -Scope It -ParameterFilter { $Arguments -eq '/set {current} safeboot minimal' }
                Assert-MockCalled Restart-AkariPC -Exactly 1 -Scope It
                Clear-AkariRun
            }
        }

        It 'saves and reads a Run back (Choice values kept)' {
            $run = New-AkariRun 'T' @(@{ Name = 'p'; Boot = 'Normal'; Items = @(@{ Id = 'c'; Mode = 'Apply'; Value = 40 }, @{ Id = 'd'; Mode = 'Revert' }) })
            Save-AkariRun $run
            $r = Get-AkariRun
            $r.Phases[0].Items[0].Value | Should Be 40
            $r.Phases[0].Items[1].ContainsKey('Value') | Should Be $false
            $r.Phases[0].Items[1].Mode | Should Be 'Revert'
            Clear-AkariRun
        }

        It 'sums up a Run' {
            $q = [Collections.Concurrent.ConcurrentQueue[string]]::new(); $LogQueue = $q
            Write-AkariRunSummary @((New-AkariOutcome 'a' 'Apply' 'Applied'), (New-AkariOutcome 'b' 'Apply' 'Failed' $false 'boom'), (New-AkariOutcome 'c' 'Apply' 'Applied'))
            ($q.ToArray() -join '|') | Should Be 'Done: 2 applied, 1 failed|  Failed: b: boom'
        }
    } finally {
        Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Presets with Phases' {
    $AkariPresetDir = "$TestDrive\none"
    $AkariLogFile = "$TestDrive\akari.log"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Presets', 'Phases', 'Appx') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    Mock Get-AkariUserSid { 'S-1-5-21-test' }
    $f = "$TestDrive\p.json"
    Set-Content $f '{ "Name": "P", "Phases": [ { "Name": "one", "Boot": "Normal", "Tweaks": ["a"] }, { "Name": "two", "Boot": "SafeMode", "Tweaks": [] }, { "Name": "three", "Tweaks": [ { "c": 40 }, "b" ] } ] }'
    $mk = { param($id) ConvertTo-AkariTweak @{ Id = $id; Name = $id; Apply = { }; Revert = { }; Detect = { 'Default' } } 'x' $false }
    $tw = @((& $mk 'a'), (& $mk 'b'), (ConvertTo-AkariTweak @{ Id = 'c'; Name = 'c'; Kind = 'Choice'; Registry = @{ Path = 'HKCU:\X'; Name = 'c'; Type = 'DWord' }; Choices = @(@{ Value = 40 }); Recommended = 1; Default = 0 } 'x' $false))

    It 'reads the phases and every phase''s entries in order' {
        $p = Read-AkariPreset $f
        ($p.Phases | ForEach-Object { "$($_.Name):$($_.Boot)" }) -join ' ' | Should Be 'one:Normal two:SafeMode three:Normal'
        ($p.Entries | ForEach-Object { "$($_.Id)@$($_.Phase)" }) -join ' ' | Should Be 'a@0 c@2 b@2'
    }
    It 'makes one Run phase per preset phase (empty ones too), items without their phase index' {
        $p = Read-AkariPreset $f
        $ph = @(Get-AkariPresetPhases $p (Resolve-AkariPreset $p $tw).Items)
        ($ph | ForEach-Object { "$($_.Boot):$(($_.Items | ForEach-Object { $_.Id }) -join '+')" }) -join ' ' | Should Be 'Normal:a SafeMode: Normal:c+b'
        $ph[2].Items[0].Value | Should Be 40
        $ph[2].Items[0].ContainsKey('Phase') | Should Be $false
    }
    It 'reverts in one phase' {
        $p = Read-AkariPreset $f
        $ph = @(Get-AkariPresetPhases $p (Resolve-AkariPreset $p $tw -Revert).Items -Revert)
        $ph.Count | Should Be 1
        ($ph[0].Items | ForEach-Object { "$($_.Id):$($_.Mode)" }) -join ' ' | Should Be 'b:Revert c:Revert a:Revert'
    }
    It 'a preset without Phases is one Normal phase' {
        Set-Content "$TestDrive\flat.json" '{ "Name": "F", "Tweaks": ["a", "b"] }'
        $p = Read-AkariPreset "$TestDrive\flat.json"
        $ph = @(Get-AkariPresetPhases $p (Resolve-AkariPreset $p $tw).Items)
        $ph.Count | Should Be 1
        $ph[0].Boot | Should Be 'Normal'
    }

    Context 'the AkariOS preset' {
        $loaded = Get-AkariTweaks (Join-Path $Root 'Tweaks')
        $p = Find-AkariPreset 'AkariOS' (Join-Path $Root 'Presets')
        It 'has a preparation phase, a Safe Mode phase and a normal one' {
            ($p.Phases | ForEach-Object { $_.Boot }) -join ',' | Should Be 'Normal,SafeMode,Normal'
        }
        It 'puts every SafeMode Tweak it names in the Safe Mode phase, and DDU''s preparation before it' {
            $safe = @($loaded.Tweaks | Where-Object { $_.SafeMode } | ForEach-Object { $_.Id })
            @($p.Entries | Where-Object { $_.Id -in $safe -and $_.Phase -ne 1 } | ForEach-Object { $_.Id }) -join ',' | Should Be ''
            ($p.Entries | Where-Object { $_.Id -eq 'oneclick-ddu-prepare' }).Phase | Should Be 0
            ($p.Entries | Where-Object { $_.Id -eq 'install-7-zip' }).Phase | Should Be 0
            ($p.Entries | Where-Object { $_.Id -eq 'oneclick-ddu-clean' }).Phase | Should Be 1
        }
        It 'ends with the restore point of the finished setup' {
            @($p.Entries)[-1].Id | Should Be 'oneclick-restore-point'
        }
        It 'builds a Run with the Entries on this PC (wildcards read once)' {
            Mock Get-AkariAppxInstalled { 'Microsoft.BingNews' }
            Mock Get-AkariCapabilitiesInstalled { }
            Mock Get-AkariFeaturesEnabled { }
            $r = New-AkariPresetRun $p $loaded
            @($r.Run.Phases).Count | Should Be 3
            @($r.Run.Phases[2].Items | Where-Object { $_.Id -eq 'appx/Microsoft.BingNews' }).Count | Should Be 1
            @($r.Tweaks | Where-Object { $_.Id -eq 'appx/Microsoft.BingNews' }).Count | Should Be 1
            $r.Unknown -join ',' | Should Be ''
        }
    }
}
