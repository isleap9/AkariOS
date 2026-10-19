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

Describe 'DWord 0xFFFFFFFF' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"

    try {
        It 'writes DWord 0xFFFFFFFF' {
            { Set-Reg $k 'V' 4294967295 'DWord' } | Should Not Throw
            $raw = (Get-Item $k).GetValue('V')
            [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$raw), 0) | Should Be 4294967295
        }

        It 'reads a 0xFFFFFFFF Choice as Optimized' {
            $c = ConvertTo-AkariTweak @{ Id = 'max'; Name = 'Max'; Kind = 'Choice'; Recommended = 4294967295; Default = 3670016
                Registry = @{ Path = $k; Name = 'M'; Type = 'DWord' }; Choices = @(@{ Value = 3670016 }, @{ Value = 4294967295 }) } 'x' $false
            (Invoke-AkariTweak $c Apply).Outcome | Should Be 'Applied'
            Get-AkariState $c | Should Be 'Optimized'
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Real tweak files' {
    foreach ($f in 'Registry', 'Loader') { . "$Core\$f.ps1" }
    $root = Join-Path (Split-Path $PSScriptRoot) 'Tweaks'

    It 'loads SvcHostSplitThreshold as a Choice' {
        $t = Import-AkariTweakFile "$root\Advanced\Tuning\SvcHostSplitThreshold.ps1" $root
        $t.Kind | Should Be 'Choice'
        $t.Recommended | Should Be 4294967295
    }
}
