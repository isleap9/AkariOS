$Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'

Describe 'Test-AkariRequirement' {
    foreach ($f in 'Log', 'Loader', 'System') { . "$Core\$f.ps1" }
    $t = { param($r) [pscustomobject]@{ Requires = [string[]]@($r) } }

    Context 'Windows 11 laptop' {
        Mock Get-AkariOSBuild { 22631 }
        Mock Get-AkariChassis { 'Laptop' }
        It 'meets Win11 and Laptop, not Win10 or Desktop' {
            Test-AkariRequirement (& $t 'Win11') | Should BeNullOrEmpty
            Test-AkariRequirement (& $t 'Laptop') | Should BeNullOrEmpty
            Test-AkariRequirement (& $t 'Win10') | Should Be 'needs Win10'
            Test-AkariRequirement (& $t 'Desktop') | Should Be 'needs Desktop'
        }
        It 'needs every value of a list' {
            Test-AkariRequirement (& $t @('Win11', 'Desktop')) | Should Be 'needs Desktop'
            Test-AkariRequirement (& $t @('Win11', 'Laptop')) | Should BeNullOrEmpty
        }
    }

    Context 'Windows 10 desktop' {
        Mock Get-AkariOSBuild { 19045 }
        Mock Get-AkariChassis { 'Desktop' }
        It 'meets Win10 and Desktop' {
            Test-AkariRequirement (& $t 'Win10') | Should BeNullOrEmpty
            Test-AkariRequirement (& $t 'Desktop') | Should BeNullOrEmpty
            Test-AkariRequirement (& $t 'Win11') | Should Be 'needs Win11'
        }
    }

    Context 'Windows Home' {
        Mock Get-AkariEdition { 'CoreSingleLanguage' }
        It 'meets Home, not Pro' {
            Test-AkariRequirement (& $t 'Home') | Should BeNullOrEmpty
            Test-AkariRequirement (& $t 'Pro') | Should Be 'needs Pro'
        }
    }

    Context 'Windows Pro' {
        Mock Get-AkariEdition { 'Professional' }
        It 'meets Pro, not Home' {
            Test-AkariRequirement (& $t 'Home') | Should Be 'needs Home'
            Test-AkariRequirement (& $t 'Pro') | Should BeNullOrEmpty
        }
    }

    Context 'Windows Enterprise' {
        Mock Get-AkariEdition { 'Enterprise' }
        It 'meets Pro (Pro or higher)' { Test-AkariRequirement (& $t 'Pro') | Should BeNullOrEmpty }
    }

    It 'has nothing to meet without Requires' { Test-AkariRequirement ([pscustomobject]@{ Requires = $null }) | Should BeNullOrEmpty }
}

Describe 'Test-AkariVirtualName (Mica off on a VM)' {
    . "$Core\System.ps1"
    It 'knows the hypervisors firmware names' {
        Test-AkariVirtualName 'Microsoft Corporation' 'Virtual Machine' | Should Be $true
        Test-AkariVirtualName 'VMware, Inc.' 'VMware20,1' | Should Be $true
        Test-AkariVirtualName 'innotek GmbH' 'VirtualBox' | Should Be $true
        Test-AkariVirtualName 'QEMU' 'Standard PC (Q35 + ICH9, 2009)' | Should Be $true
        Test-AkariVirtualName 'Xen' 'HVM domU' | Should Be $true
    }
    It 'leaves real PCs alone' {
        Test-AkariVirtualName 'Microsoft Corporation' 'Surface Laptop 5' | Should Be $false
        Test-AkariVirtualName 'ASUS' 'ROG STRIX B650E-F GAMING WIFI' | Should Be $false
        Test-AkariVirtualName 'Dell Inc.' 'XPS 15 9530' | Should Be $false
        Test-AkariVirtualName '' '' | Should Be $false
    }
}

Describe 'Restart-AkariExplorer' {
    foreach ($f in 'Log', 'System') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    # never the real Explorer: every process call is mocked
    Mock Stop-Process { }
    Mock Start-Process { }
    Mock Start-Sleep { }

    Context 'Windows starts the shell again' {
        Mock Get-Process { [pscustomobject]@{ Name = 'explorer' } }
        It 'stops Explorer and leaves the restart to Windows' {
            Restart-AkariExplorer
            Assert-MockCalled Stop-Process -Exactly 1 -ParameterFilter { $Name -eq 'explorer' }
            Assert-MockCalled Start-Process -Exactly 0
        }
    }

    Context 'the shell does not come back' {
        Mock Get-Process { }
        It 'starts Explorer itself' {
            Restart-AkariExplorer
            Assert-MockCalled Start-Process -Exactly 1 -ParameterFilter { $FilePath -like '*explorer.exe' }
        }
    }
}

Describe 'Invoke-AkariPowerCfg' {
    . "$Core\System.ps1"
    It 'returns powercfg''s output (read-only /list)' {
        (Invoke-AkariPowerCfg '/list') -join "`n" | Should Match '[0-9a-f]{8}-[0-9a-f]{4}-'
    }
}
