$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

Describe 'Resolve-AkariRegPath' {
    . "$Core\Registry.ps1"

    It 'maps HKCU to the real user hive' {
        $script:AkariUserSid = 'S-1-5-21-1-2-3-1001'
        try {
            Resolve-AkariRegPath 'HKCU:\Software\X' | Should Be 'Registry::HKEY_USERS\S-1-5-21-1-2-3-1001\Software\X'
            Resolve-AkariRegPath 'HKEY_CURRENT_USER\Software\X' | Should Be 'Registry::HKEY_USERS\S-1-5-21-1-2-3-1001\Software\X'
        } finally { $script:AkariUserSid = $null }
    }

    It 'leaves other hives alone' {
        Resolve-AkariRegPath 'HKLM:\SOFTWARE\X' | Should Be 'HKLM:\SOFTWARE\X'
    }
}

Describe 'Set-Reg and Get-AkariRegValue' {
    . "$Core\Registry.ps1"
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"

    try {
        It 'round-trips a DWord through the detected user hive' {
            Set-Reg $k 'A' 1
            Get-AkariRegValue $k 'A' | Should Be 1
        }

        It 'keeps DWords above 2^31 unsigned' {
            Set-Reg $k 'Big' 4294967295
            Get-AkariRegValue $k 'Big' | Should Be 4294967295
        }

        It 'returns null for a missing value or key' {
            Get-AkariRegValue $k 'Nope' | Should BeNullOrEmpty
            Get-AkariRegValue "$k\NoKey" 'A' | Should BeNullOrEmpty
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Registry entries: State, Apply, Revert' {
    . "$Core\Registry.ps1"
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $e = @(
        @{ Path = $k; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = $k; Name = 'B'; Type = 'DWord'; Value = 0; Default = $null }
    )

    try {
        It 'is Custom while a value with a real Default is missing' {
            Get-AkariRegistryState $e | Should Be 'Custom'
        }

        It 'is Default when values match stock Windows (absent counts for a null Default)' {
            Set-Reg $k 'A' 1
            Get-AkariRegistryState $e | Should Be 'Default'
        }

        It 'is Optimized after Apply' {
            Invoke-AkariRegistry $e Apply
            Get-AkariRegistryState $e | Should Be 'Optimized'
        }

        It 'is Custom after a hand edit' {
            Set-Reg $k 'A' 7
            Get-AkariRegistryState $e | Should Be 'Custom'
        }

        It 'Revert restores Defaults and deletes values Windows does not set' {
            Invoke-AkariRegistry $e Revert
            Get-AkariRegistryState $e | Should Be 'Default'
            Get-AkariRegValue $k 'A' | Should Be 1
            Get-AkariRegValue $k 'B' | Should BeNullOrEmpty
        }

        It 'picks the per-OS Default for this build' {
            $win11 = [Environment]::OSVersion.Version.Build -ge 22000
            $os = @(@{ Path = $k; Name = 'C'; Type = 'DWord'; Value = 0; Default = @{ Win10 = 10; Win11 = 11 } })
            Invoke-AkariRegistry $os Revert
            Get-AkariRegValue $k 'C' | Should Be $(if ($win11) { 11 } else { 10 })
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}
