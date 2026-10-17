$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

Describe 'Get-AkariState with Detect' {
    . "$Core\Registry.ps1"; . "$Core\Loader.ps1"; . "$Core\State.ps1"
    function New-Toggle([scriptblock]$Detect) { ConvertTo-AkariTweak @{ Id = 't'; Detect = $Detect } 'x' $false }

    It 'is Optimized when Detect returns true' { Get-AkariState (New-Toggle { $true }) | Should Be 'Optimized' }
    It 'is Default when Detect returns false' { Get-AkariState (New-Toggle { $false }) | Should Be 'Default' }
    It 'passes a State name through' { Get-AkariState (New-Toggle { 'Custom' }) | Should Be 'Custom' }
    It 'is Unknown when Detect throws (e.g. no admin)' { Get-AkariState (New-Toggle { throw 'no admin' }) | Should Be 'Unknown' }
}

Describe 'Get-AkariState from Registry data' {
    . "$Core\Registry.ps1"; . "$Core\Loader.ps1"; . "$Core\State.ps1"
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $choice = ConvertTo-AkariTweak @{
        Id = 'c'; Kind = 'Choice'; Recommended = 0x26; Default = 2
        Registry = @{ Path = $k; Name = 'P'; Type = 'DWord' }
        Choices = @(@{ Value = 0x26 }, @{ Value = 0x28 })
    } 'x' $false
    $toggle = ConvertTo-AkariTweak @{ Id = 't'; Registry = @{ Path = $k; Name = 'T'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false

    try {
        It 'Choice with no value set is Unknown' { Get-AkariState $choice | Should Be 'Unknown' }
        It 'Choice at its Default is Default' { Set-Reg $k 'P' 2; Get-AkariState $choice | Should Be 'Default' }
        It 'Choice at Recommended is Optimized' { Set-Reg $k 'P' 0x26; Get-AkariState $choice | Should Be 'Optimized' }
        It 'Choice at another value is Custom' { Set-Reg $k 'P' 0x18; Get-AkariState $choice | Should Be 'Custom' }
        It 'registry Toggle uses its entries' { Set-Reg $k 'T' 0; Get-AkariState $toggle | Should Be 'Optimized' }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Get-AkariState from what Akari last applied' {
    $AkariStatePath = "$TestDrive\state.json"
    . "$Core\Registry.ps1"; . "$Core\Loader.ps1"; . "$Core\State.ps1"
    $t = ConvertTo-AkariTweak @{ Id = 'no-detect'; Apply = { }; Revert = { } } 'x' $false

    It 'is Unknown before Akari ran it' { Get-AkariState $t | Should Be 'Unknown' }
    It 'is Optimized after a remembered Apply' { Set-AkariRememberedState 'no-detect' $true; Get-AkariState $t | Should Be 'Optimized' }
    It 'is Default after a remembered Revert' { Set-AkariRememberedState 'no-detect' $false; Get-AkariState $t | Should Be 'Default' }
    It 'keeps other ids' {
        Set-AkariRememberedState 'other' $true
        Get-AkariRememberedState 'no-detect' | Should Be $false
    }
    It 'treats a corrupt state.json as empty' {
        Set-Content $AkariStatePath '{ not json'
        Get-AkariState $t | Should Be 'Unknown'
    }
}
