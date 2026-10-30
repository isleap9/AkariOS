$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# Every Tweak ported from ZOICWARE (its file names ZOICWARE as the source): Advanced only, outside the AkariOS setup,
# a Default on every row, and a full Apply / Revert round trip. Both hives go to HKCU:\Software\AkariTest\<guid>.
Describe 'ZOICWARE ports' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Trusted') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Restart-AkariExplorer { }
    # no real powercfg, and never a real scheduled task (an Action runs once here, against this mock)
    Mock Invoke-AkariPowerCfg { }
    Mock Remove-AkariScheduledTasks { 3 }
    # TrustedInstaller writes go to the test key as admin (never a real Run-Trusted)
    Mock Invoke-AkariRegistryTrusted { Invoke-AkariRegistry $Entries $Mode }
    # a print verb Windows has (context-remove-print only touches the ones that exist)
    New-Item -Path "$tk\HKLM\SOFTWARE\Classes\batfile\shell\print" -Force | Out-Null
    $files = @(Get-ChildItem $Tw -Recurse -Filter *.ps1 | Where-Object { $_.DirectoryName -notmatch '\\Files$' -and (Get-Content $_.FullName -TotalCount 3) -match 'ZOICWARE' })

    try {
        It 'finds the ports (guard)' { $files.Count -ge 65 | Should Be $true }
        It 'redirects both hives (guard)' { Resolve-AkariRegPath 'HKLM:\SOFTWARE\X' | Should Be "$tk\HKLM\SOFTWARE\X" }
        foreach ($f in $files) {
            $t = Import-AkariTweakFile $f.FullName $Tw
            It "$($t.Id): Advanced only, not in the AkariOS setup, a Default on every row" {
                $t.Guided | Should Be $false
                [bool]$t.AkariOS | Should Be $false
                @($t.Registry | Where-Object { $_ -and -not $_.ContainsKey('Default') }).Count | Should Be 0
            }
            if ($t.Kind -eq 'Action') {
                It "$($t.Id): an Action that asks first and runs through mocked Core helpers" {
                    $t.Confirm | Should Not BeNullOrEmpty
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Skipped'
                }
                continue
            }
            It "$($t.Id): Apply makes it Optimized, Revert puts the Windows default back" {
                # start from the Windows default (a deleted key is Optimized while the test hive lacks it)
                Invoke-AkariTweak $t Revert | Out-Null
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }
        It 'removes every scheduled task but ZOICWARE''s two' {
            $t = Import-AkariTweakFile "$Tw\Advanced\System\RemoveScheduledTasks.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            Assert-MockCalled Remove-AkariScheduledTasks -Scope It -Exactly 1 -ParameterFilter { ($Keep -join ',') -eq 'SvcRestartTask,MsCtfMonitor' }
        }
        It 'hides Personalize and Display as TrustedInstaller' {
            foreach ($n in 'Personalize', 'Display') {
                $t = Import-AkariTweakFile "$Tw\Customize\Context menu\Remove$n.ps1" $Tw
                Invoke-AkariTweak $t Apply | Out-Null
            }
            Assert-MockCalled Invoke-AkariRegistryTrusted -Scope It -Exactly 2 -ParameterFilter { $Mode -eq 'Apply' -and $Entries[0].Name -eq 'ProgrammaticAccessOnly' }
        }
        It 'hides Print only on the print verbs that exist' {
            $t = Import-AkariTweakFile "$Tw\Customize\Context menu\RemovePrint.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            Test-Path "$tk\HKLM\SOFTWARE\Classes\txtfile\shell\print" | Should Be $false
            Get-AkariRegValue 'HKLM:\SOFTWARE\Classes\batfile\shell\print' 'ProgrammaticAccessOnly' | Should Be ''
            Invoke-AkariTweak $t Revert | Out-Null
            Test-Path "$tk\HKLM\SOFTWARE\Classes\batfile\shell\print" | Should Be $true
        }
        It 'sets the power mode overlay through powercfg' {
            $t = Import-AkariTweakFile "$Tw\Optimize\Power\PowerMode.ps1" $Tw
            Invoke-AkariTweak $t Revert | Out-Null
            Invoke-AkariTweak $t Apply | Out-Null
            Assert-MockCalled Invoke-AkariPowerCfg -Scope It -ParameterFilter { ($Arguments -join ' ') -eq '/overlaysetactive OVERLAY_SCHEME_MAX' }
        }
    } finally {
        if (Test-Path $tk) { Remove-Item $tk -Recurse -Force }
    }
}
