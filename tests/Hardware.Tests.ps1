$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# Hardware tweaks (5 Graphics and 7 Hardware port), against HKCU:\Software\AkariTest\<guid> only. Both hives are
# redirected by mocking Resolve-AkariRegPath; the GPU list, downloads, shortcuts and processes are mocked
# (AGENTS.md rule 12).

Describe 'Get-AkariGpus and GPU Requires' {
    foreach ($f in 'Log', 'Registry', 'System') { . "$Core\$f.ps1" }
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    try {
        $AkariGpuClass = $tk
        New-Item "$tk\0000" -Force | Out-Null; Set-ItemProperty "$tk\0000" -Name ProviderName -Value 'NVIDIA'; Set-ItemProperty "$tk\0000" -Name DriverDesc -Value 'NVIDIA GeForce RTX 5070'
        New-Item "$tk\0001" -Force | Out-Null; Set-ItemProperty "$tk\0001" -Name ProviderName -Value 'Advanced Micro Devices, Inc.'; Set-ItemProperty "$tk\0001" -Name DriverDesc -Value 'AMD Radeon(TM) Graphics'
        New-Item "$tk\Configuration" -Force | Out-Null
        It 'lists the adapter keys with their vendor, not Configuration' {
            $g = @(Get-AkariGpus)
            $g.Count | Should Be 2
            $g[0].Vendor | Should Be 'NVIDIA'
            $g[1].Vendor | Should Be 'AMD'
            $g[0].Path | Should Be "$tk\0000"
        }
        It 'meets NVIDIA / AMD and not Intel' {
            Test-AkariRequirement @{ Requires = 'NVIDIA' } | Should Be $null
            Test-AkariRequirement @{ Requires = 'AMD' } | Should Be $null
            Test-AkariRequirement @{ Requires = 'Intel' } | Should Be 'needs Intel'
        }
    } finally { Remove-Item $tk -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Hardware tweaks' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    $class = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    Mock Get-AkariGpus {
        [pscustomobject]@{ Path = "$class\0000"; Name = 'NVIDIA GeForce'; Vendor = 'NVIDIA' }
        [pscustomobject]@{ Path = "$class\0001"; Name = 'AMD Radeon'; Vendor = 'AMD' }
        [pscustomobject]@{ Path = "$class\0002"; Name = 'Intel Arc'; Vendor = 'Intel' }
    }
    Mock Get-AkariGpuDevices { 'PCI\VEN_10DE&DEV_2F04\4&1' }
    Mock Start-Process { }
    Mock Stop-Process { }
    Mock Start-Sleep { }
    Mock Save-AkariFile { $OutFile }
    Mock New-AkariShortcut { }
    Mock Unblock-File { }

    try {
        It 'redirects both hives (guard)' {
            Resolve-AkariRegPath "$class\0000" | Should Be "$tk\HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
        }

        Context 'Per-GPU Toggles' {
            New-Item (Resolve-AkariRegPath "$class\0001\UMD") -Force | Out-Null
            foreach ($rel in 'Graphics\Hdcp.ps1', 'Graphics\P0State.ps1', 'Graphics\AmdUlps.ps1', 'Graphics\MsiMode.ps1', 'Graphics\IntelSettings.ps1', 'Graphics\AmdSettings.ps1', 'Graphics\NvidiaSettings.ps1', 'Input\BackgroundPolling.ps1') {
                $t = Load "Hardware\$rel"
                It "$($t.Id) round-trips to the Default" {
                    if ($t.Id -eq 'graphics-amd-ulps-off') { Set-Reg "$class\0001" 'EnableUlps' 1 }
                    Get-AkariState $t | Should Be 'Default'
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Get-AkariState $t | Should Be 'Default'
                }
            }
        }

        Context 'Values land on the right vendor''s key' {
            It 'HDCP and P0 only on NVIDIA, ULPS only on AMD, MSI under the device''s Enum key' {
                [void](Invoke-AkariTweak (Load 'Hardware\Graphics\Hdcp.ps1') Apply)
                [void](Invoke-AkariTweak (Load 'Hardware\Graphics\AmdUlps.ps1') Apply)
                [void](Invoke-AkariTweak (Load 'Hardware\Graphics\MsiMode.ps1') Apply)
                Get-AkariRegValue "$class\0000" 'RMHdcpKeyglobZero' | Should Be 1
                Get-AkariRegValue "$class\0001" 'RMHdcpKeyglobZero' | Should Be $null
                Get-AkariRegValue "$class\0001" 'EnableUlps' | Should Be 0
                Get-AkariRegValue "$class\0000" 'EnableUlps' | Should Be $null
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_10DE&DEV_2F04\4&1\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties' 'MSISupported' | Should Be 1
            }
            It 'AMD settings write the binary UMD values only where the driver made the key' {
                [void](Invoke-AkariTweak (Load 'Hardware\Graphics\AmdSettings.ps1') Apply)
                (Get-AkariRegValue "$class\0001\UMD" 'VSyncControl') -join ',' | Should Be '48,0'
                Test-Path -LiteralPath (Resolve-AkariRegPath "$class\0001\power_v1") | Should Be $false
            }
        }

        Context 'NVIDIA settings: Profile Inspector' {
            It 'downloads Profile Inspector when missing and imports the shipped profile; Revert imports the default one' {
                $realX86 = ${env:ProgramFiles(x86)}
                [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', "$TestDrive\x86", 'Process')
                try {
                    $t = Load 'Hardware\Graphics\NvidiaSettings.ps1'
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Assert-MockCalled Save-AkariFile -Scope It -ParameterFilter { $Name -eq 'inspector.exe' -and $OutFile -like "$TestDrive*" }
                    Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $ArgumentList -like '*-silentImport*nvidia-base-profile.nip*' }
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $ArgumentList -like '*nvidia-default-profile.nip*' }
                } finally { [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $realX86, 'Process') }
            }
            It 'ships both profiles' {
                Test-Path (Join-Path $Tw 'Hardware\Graphics\Files\nvidia-base-profile.nip') | Should Be $true
                [xml](Get-Content (Join-Path $Tw 'Hardware\Graphics\Files\nvidia-base-profile.nip') -Raw) | Should Not Be $null
                Test-Path (Join-Path $Tw 'Hardware\Graphics\Files\nvidia-default-profile.nip') | Should Be $true
            }
        }
    } finally {
        Remove-Item $tk -Recurse -Force -ErrorAction SilentlyContinue
    }
}
