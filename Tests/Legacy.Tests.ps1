$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'

Describe 'Import-AkariLegacyTweaks' {
    . "$Core\Loader.ps1"; . "$Core\Legacy.ps1"
    $list = @(Import-AkariLegacyTweaks (Join-Path $PSScriptRoot 'Fixtures\Legacy'))

    It 'loads every Add-Tweak call in file order' {
        ($list | ForEach-Object { $_.Id }) -join ',' | Should Be 'legacy-toggle,legacy-group'
    }

    It 'puts the old page name in Section and marks them Legacy' {
        $list[0].Section | Should Be 'Windows'
        $list[1].Section | Should Be 'Advanced'
        $list[0].Legacy | Should Be $true
        $list[0].Kind | Should Be 'Toggle'
    }

    It 'keeps Group actions with their Block' {
        $list[1].Actions[0].Block | Should BeOfType [scriptblock]
    }
}

Describe 'Akari.ps1' {
    It 'parses' {
        $errs = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'Akari.ps1'), [ref]$null, [ref]$errs)
        @($errs).Count | Should Be 0
    }
}
